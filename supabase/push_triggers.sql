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
            'Authorization', 'Bearer ' || (SELECT value FROM server_secrets WHERE key = 'SUPABASE_ANON_KEY')
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
BEGIN
    -- Samo ako se status menja na 'approved', 'rejected' ili 'manual'
    IF (OLD.status = 'pending' AND NEW.status != 'pending') OR (NEW.status = 'manual') THEN
        
        -- Dohvati tokene za putnika
        SELECT jsonb_agg(jsonb_build_object('token', token, 'provider', provider))
        INTO v_tokens
        FROM push_tokens
        WHERE putnik_id = NEW.putnik_id;

        IF v_tokens IS NOT NULL THEN
            IF NEW.status = 'approved' THEN
                v_title := '✅ Mesto osigurano!';
                v_body := 'Vaš zahtev za ' || NEW.zeljeno_vreme || ' (' || NEW.grad || ') je odobren. Srećan put!';
                v_data := jsonb_build_object('type', 'seat_request_approved', 'id', NEW.id);
            ELSIF NEW.status = 'rejected' THEN
                IF NEW.alternatives IS NOT NULL AND jsonb_array_length(NEW.alternatives) > 0 THEN
                    v_title := '⚠️ Termin pun - Alternative?';
                    v_body := 'Termin u ' || NEW.zeljeno_vreme || ' je pun, ali imamo mesta u drugim terminima. Pogledaj profil!';
                    v_data := jsonb_build_object('type', 'seat_request_alternatives', 'id', NEW.id);
                ELSE
                    v_title := '❌ Termin popunjen';
                    v_body := 'Nažalost, u terminu ' || NEW.zeljeno_vreme || ' više nema slobodnih mesta.';
                    v_data := jsonb_build_object('type', 'seat_request_rejected', 'id', NEW.id);
                END IF;
            END IF;

            IF v_title IS NOT NULL THEN
                PERFORM notify_push(v_tokens, v_title, v_body, v_data);
            END IF;
        END IF;

        -- Ako je NOVI zahtev ili status postane 'manual', obavesti admine
        IF (NEW.status = 'manual') OR (TG_OP = 'INSERT' AND NEW.status = 'pending') THEN
            SELECT jsonb_agg(jsonb_build_object('token', token, 'provider', provider))
            INTO v_tokens
            FROM push_tokens
            WHERE user_id IN (SELECT ime FROM vozaci WHERE tip = 'admin' OR ime = 'Bojan');

            IF v_tokens IS NOT NULL THEN
                SELECT putnik_ime INTO v_putnik_ime FROM registrovani_putnici WHERE id = NEW.putnik_id;
                v_title := '🔔 Novi zahtev (' || NEW.grad || ')';
                v_body := v_putnik_ime || ' traži mesto za ' || NEW.zeljeno_vreme;
                v_data := jsonb_build_object('type', 'seat_request_manual', 'id', NEW.id);
                
                PERFORM notify_push(v_tokens, v_title, v_body, v_data);
            END IF;
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
