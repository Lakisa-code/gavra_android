-- ==========================================
-- PUSH NOTIFIKACIJE - SQL TRIGGERS & FUNCTIONS
-- ==========================================

-- 1. FUNKCIJA: Slanje notifikacije putem Edge Funkcije
CREATE OR REPLACE FUNCTION notify_push(
    p_tokens jsonb,
    p_title text,
    p_body text,
    p_data jsonb DEFAULT '{}'::jsonb
) RETURNS void AS $$
BEGIN
    PERFORM net.http_post(
        url := (SELECT value FROM server_secrets WHERE key = 'SUPABASE_URL') || '/functions/v1/send-push-notification',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (SELECT value FROM server_secrets WHERE key = 'SUPABASE_SERVICE_ROLE_KEY')
        ),
        body := jsonb_build_object(
            'tokens', p_tokens,
            'title', p_title,
            'body', p_body,
            'data', p_data
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. FUNKCIJA: Automatizacija Seat Request Notifikacija
CREATE OR REPLACE FUNCTION notify_seat_request_update()
RETURNS trigger AS $$
DECLARE
    v_tokens jsonb;
    v_title text;
    v_body text;
    v_data jsonb;
    v_putnik_ime text;
    v_grad_display text;
BEGIN
    -- Samo ako se status mijenja
    IF (OLD.status = NEW.status) THEN RETURN NEW; END IF;

    v_grad_display := CASE WHEN NEW.grad = 'BC' THEN 'Bela Crkva' WHEN NEW.grad = 'VS' THEN 'Vršac' ELSE NEW.grad END;

    -- Dohvati tokene putnika
    SELECT jsonb_agg(jsonb_build_object('token', token, 'provider', provider))
    INTO v_tokens
    FROM push_tokens
    WHERE putnik_id = NEW.putnik_id;

    IF v_tokens IS NOT NULL AND jsonb_array_length(v_tokens) > 0 THEN
        IF NEW.status = 'approved' THEN
            v_title := '✅ Mesto osigurano!';
            v_body := 'Vaš zahtev za ' || to_char(NEW.zeljeno_vreme, 'HH24:MI') || ' (' || v_grad_display || ') je odobren. Srećan put!';
            v_data := jsonb_build_object('type', 'seat_request_approved', 'id', NEW.id, 'grad', NEW.grad);
        ELSIF NEW.status = 'rejected' THEN
            IF NEW.alternative_vreme_1 IS NOT NULL OR NEW.alternative_vreme_2 IS NOT NULL THEN
                v_title := '⚠️ Termin pun - Izaberi alternativu';
                v_body := 'Termin ' || to_char(NEW.zeljeno_vreme, 'HH24:MI') || ' je pun. Slobodna mesta: '
                    || COALESCE(to_char(NEW.alternative_vreme_1, 'HH24:MI'), '')
                    || CASE WHEN NEW.alternative_vreme_1 IS NOT NULL AND NEW.alternative_vreme_2 IS NOT NULL THEN ' i ' ELSE '' END
                    || COALESCE(to_char(NEW.alternative_vreme_2, 'HH24:MI'), '');
                v_data := jsonb_build_object(
                    'type', 'seat_request_alternatives',
                    'id', NEW.id,
                    'grad', NEW.grad,
                    'datum', to_char(NEW.datum, 'YYYY-MM-DD'),
                    'vreme', to_char(NEW.zeljeno_vreme, 'HH24:MI'),
                    'putnik_id', NEW.putnik_id,
                    'alternative_1', to_char(NEW.alternative_vreme_1, 'HH24:MI'),
                    'alternative_2', to_char(NEW.alternative_vreme_2, 'HH24:MI')
                );
            ELSE
                v_title := '❌ Termin popunjen';
                v_body := 'Nažalost, u terminu ' || to_char(NEW.zeljeno_vreme, 'HH24:MI') || ' više nema slobodnih mesta.';
                v_data := jsonb_build_object('type', 'seat_request_rejected', 'id', NEW.id, 'grad', NEW.grad);
            END IF;
        END IF;

        IF v_title IS NOT NULL THEN
            PERFORM notify_push(v_tokens, v_title, v_body, v_data);
        END IF;
    END IF;

    -- Za manual → obavijesti admina (Bojan)
    IF NEW.status = 'manual' THEN
        SELECT jsonb_agg(jsonb_build_object('token', token, 'provider', provider))
        INTO v_tokens
        FROM push_tokens
        WHERE user_id IN (SELECT ime FROM vozaci WHERE email = 'gavra.prevoz@gmail.com' OR ime = 'Bojan');

        IF v_tokens IS NOT NULL AND jsonb_array_length(v_tokens) > 0 THEN
            SELECT putnik_ime INTO v_putnik_ime FROM registrovani_putnici WHERE id = NEW.putnik_id;
            PERFORM notify_push(
                v_tokens,
                '🔔 Novi zahtev (' || v_grad_display || ')',
                v_putnik_ime || ' traži mesto za ' || to_char(NEW.zeljeno_vreme, 'HH24:MI'),
                jsonb_build_object('type', 'seat_request_manual', 'id', NEW.id, 'grad', NEW.grad)
            );
        END IF;
    END IF;

    -- Za otkazano → obavijesti sve vozače (osim onog koji je otkazao)
    IF NEW.status = 'otkazano' THEN
        SELECT jsonb_agg(jsonb_build_object('token', token, 'provider', provider))
        INTO v_tokens
        FROM push_tokens
        WHERE user_id IN (SELECT ime FROM vozaci)
          AND user_id IS DISTINCT FROM NEW.cancelled_by;

        IF v_tokens IS NOT NULL AND jsonb_array_length(v_tokens) > 0 THEN
            SELECT putnik_ime INTO v_putnik_ime FROM registrovani_putnici WHERE id = NEW.putnik_id;
            PERFORM notify_push(
                v_tokens,
                '🚫 Otkazivanje (' || v_grad_display || ')',
                COALESCE(v_putnik_ime, 'Putnik') || ' otkazao vožnju za ' || to_char(NEW.zeljeno_vreme, 'HH24:MI') || ' (' || to_char(NEW.datum, 'DD.MM.') || ')',
                jsonb_build_object('type', 'seat_request_otkazano', 'id', NEW.id, 'grad', NEW.grad)
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. TRIGGER: Aktiviraj na tabeli seat_requests
-- DROP TRIGGER IF EXISTS tr_seat_request_notification ON seat_requests;
-- CREATE TRIGGER tr_seat_request_notification
-- AFTER INSERT OR UPDATE ON seat_requests
-- FOR EACH ROW EXECUTE FUNCTION notify_seat_request_update();

-- ==========================================
-- 4. FUNKCIJA: Automatizovani Dnevni Popis (21:00h)
-- ==========================================
CREATE OR REPLACE FUNCTION trigger_daily_popis_reports() RETURNS void AS $$
DECLARE
    v_record RECORD;
    v_stats RECORD;
    v_tokens jsonb;
    v_admin_tokens jsonb;
    v_title text;
    v_body text;
    v_start_time TIMESTAMP WITH TIME ZONE;
    v_end_time TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Period: Od 21h juče do 21h danas
    v_end_time := (CURRENT_DATE || ' 21:00:00')::TIMESTAMP WITH TIME ZONE;
    v_start_time := v_end_time - INTERVAL '24 hours';

    -- Dohvati tokene za admine (jednom, van petlje)
    SELECT jsonb_agg(jsonb_build_object('token', token, 'provider', provider))
    INTO v_admin_tokens
    FROM push_tokens
    WHERE user_id IN (SELECT ime FROM vozaci WHERE email = 'gavra.prevoz@gmail.com' OR ime = 'Bojan');

    -- Iteriraj kroz sve vozače koji su imali akcije u tom periodu
    FOR v_record IN 
        SELECT DISTINCT log.vozac_id, v.ime 
        FROM voznje_log log
        JOIN vozaci v ON v.id = log.vozac_id
        WHERE log.created_at >= v_start_time AND log.created_at < v_end_time AND log.vozac_id IS NOT NULL
    LOOP
        -- Dohvati statistiku preko pomoćne funkcije
        SELECT * INTO v_stats FROM get_automated_popis_stats(v_record.vozac_id, v_start_time, v_end_time);
        
        -- Formiraj poruku
        v_title := '📊 Dnevni Popis - ' || v_record.ime;
        v_body := 'Pokupljeni: ' || v_stats.pokupljeni_putnici || E'\n' ||
                  'Dodati: ' || v_stats.dodati_putnici || E'\n' ||
                  'Otkazani: ' || v_stats.otkazani_putnici || E'\n' ||
                  'Pošiljke: ' || v_stats.broj_posiljki || E'\n' ||
                  'Dugovanja: ' || v_stats.broj_duznika || E'\n' ||
                  'Dnevne uplate: ' || v_stats.naplaceni_dnevni || E'\n' ||
                  'Mesečne uplate: ' || v_stats.naplaceni_mesecni || E'\n' ||
                  'UKUPNO: ' || v_stats.ukupan_pazar || ' RSD';
                  
        -- 1. Pošalji vozaču
        SELECT jsonb_agg(jsonb_build_object('token', token, 'provider', provider))
        INTO v_tokens
        FROM push_tokens
        WHERE vozac_id = v_record.vozac_id;
        
        IF v_tokens IS NOT NULL THEN
            PERFORM notify_push(v_tokens, v_title, v_body, jsonb_build_object(
                'type', 'automated_popis',
                'stats', jsonb_build_object(
                    'dodati_putnici', v_stats.dodati_putnici,
                    'otkazani_putnici', v_stats.otkazani_putnici,
                    'pokupljeni_putnici', v_stats.pokupljeni_putnici,
                    'naplaceni_dnevni', v_stats.naplaceni_dnevni,
                    'naplaceni_mesecni', v_stats.naplaceni_mesecni,
                    'ukupan_pazar', v_stats.ukupan_pazar,
                    'broj_duznika', v_stats.broj_duznika,
                    'broj_posiljki', v_stats.broj_posiljki
                )
            ));
        END IF;

        -- 2. Pošalji i adminu
        IF v_admin_tokens IS NOT NULL THEN
            PERFORM notify_push(v_admin_tokens, '📢 Popis: ' || v_record.ime, v_body, jsonb_build_object(
                'type', 'admin_popis_report',
                'vozac', v_record.ime,
                'stats', jsonb_build_object(
                    'dodati_putnici', v_stats.dodati_putnici,
                    'otkazani_putnici', v_stats.otkazani_putnici,
                    'pokupljeni_putnici', v_stats.pokupljeni_putnici,
                    'naplaceni_dnevni', v_stats.naplaceni_dnevni,
                    'naplaceni_mesecni', v_stats.naplaceni_mesecni,
                    'ukupan_pazar', v_stats.ukupan_pazar,
                    'broj_duznika', v_stats.broj_duznika,
                    'broj_posiljki', v_stats.broj_posiljki
                )
            ));
        END IF;

        -- 3. Automatsko čuvanje u daily_reports
        INSERT INTO daily_reports (
            vozac, 
            vozac_id, 
            datum, 
            ukupan_pazar, 
            pokupljeni_putnici, 
            otkazani_putnici, 
            naplaceni_dnevni, 
            naplaceni_mesecni, 
            dugovi_putnici
        )
        VALUES (
            v_record.ime, 
            v_record.vozac_id, 
            CURRENT_DATE, 
            v_stats.ukupan_pazar, 
            v_stats.pokupljeni_putnici::integer, 
            v_stats.otkazani_putnici::integer, 
            v_stats.naplaceni_dnevni::integer, 
            v_stats.naplaceni_mesecni::integer, 
            v_stats.broj_duznika::integer
        )
        ON CONFLICT (vozac, datum) DO UPDATE SET
            ukupan_pazar = EXCLUDED.ukupan_pazar,
            pokupljeni_putnici = EXCLUDED.pokupljeni_putnici,
            otkazani_putnici = EXCLUDED.otkazani_putnici,
            naplaceni_dnevni = EXCLUDED.naplaceni_dnevni,
            naplaceni_mesecni = EXCLUDED.naplaceni_mesecni,
            dugovi_putnici = EXCLUDED.dugovi_putnici,
            updated_at = NOW();
    END LOOP;
END;
$$ LANGUAGE plpgsql;
