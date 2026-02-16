-- ==========================================
-- DIGITALNI DISPEČER - SQL LOGIKA (V1.0)
-- ==========================================

-- 1. POMOĆNA FUNKCIJA: Dobavljanje imena dana (pon, uto...) iz datuma
CREATE OR REPLACE FUNCTION get_dan_kratica(target_date date)
RETURNS text AS $$
BEGIN
    RETURN CASE EXTRACT(DOW FROM target_date)
        WHEN 1 THEN 'pon'
        WHEN 2 THEN 'uto'
        WHEN 3 THEN 'sre'
        WHEN 4 THEN 'cet'
        WHEN 5 THEN 'pet'
        WHEN 6 THEN 'sub'
        WHEN 0 THEN 'ned'
    END;
END;
$$ LANGUAGE plpgsql;

-- 2. POMOĆNA FUNKCIJA: Provera slobodnih mesta
CREATE OR REPLACE FUNCTION proveri_slobodna_mesta(target_grad text, target_vreme time, target_datum date)
RETURNS integer AS $$
DECLARE
    max_mesta_val integer;
    zauzeto_val integer;
    dan_kratica text;
    grad_key text;
    status_key text;
BEGIN
    dan_kratica := get_dan_kratica(target_datum);
    grad_key := lower(target_grad);
    -- Odredi sezonski ključ (bc2/vs2) ako je datum u zimskom periodu (Oktobar-Mart)
    IF EXTRACT(MONTH FROM target_datum) >= 10 OR EXTRACT(MONTH FROM target_datum) <= 3 THEN
        grad_key := grad_key || '2';
    END IF;
    status_key := grad_key || '_status';

    -- 1. Dohvati max mesta iz kapaciteta
    SELECT kp.max_mesta INTO max_mesta_val 
    FROM kapacitet_polazaka kp
    WHERE kp.grad = UPPER(target_grad) AND kp.vreme = target_vreme AND kp.aktivan = true;
    
    IF max_mesta_val IS NULL THEN max_mesta_val := 8; END IF;

    -- 2. Prebroj putnike koji već ZAUZIMAJU mesto kod dispečera
    -- Podržava i zimski red vožnje (bc2/vs2) sa fallback-om na letnji (bc/vs)
    SELECT COALESCE(SUM(rp.broj_mesta), 0) INTO zauzeto_val
    FROM registrovani_putnici rp
    WHERE rp.obrisan = false AND rp.aktivan = true
      AND (
        (
            -- Proveri zimski ključ ako postoji, inače letnji
            COALESCE(
                rp.polasci_po_danu->dan_kratica->>grad_key, -- npr 'bc2'
                CASE WHEN grad_key LIKE '%2' THEN rp.polasci_po_danu->dan_kratica->>lower(target_grad) ELSE NULL END -- fallback na 'bc'
            ) IN (target_vreme::text, to_char(target_vreme, 'HH24:MI'))
        )
      )
      -- Računaj sve, osim ako su eksplicitno obeleženi kao odbijeni ili otkazani
      AND (rp.polasci_po_danu->dan_kratica->>status_key IS NULL OR rp.polasci_po_danu->dan_kratica->>status_key != 'rejected')
      AND (rp.polasci_po_danu->dan_kratica->>(grad_key || '_otkazano') IS NULL);

    RETURN max_mesta_val - zauzeto_val;
END;
$$ LANGUAGE plpgsql;

-- 3. GLAVNA FUNKCIJA: Obrada pojedinačnog zahteva
CREATE OR REPLACE FUNCTION obradi_seat_request(req_id uuid)
RETURNS void AS $$
DECLARE
    req_record record;
    putnik_record record;
    dan_kratica text;
    ima_mesta boolean;
    slobodno_mesta integer;
    novi_status text;
    v_alternatives jsonb := '[]'::jsonb;
    json_key_status text;
    json_key_ceka text;
    json_key_vreme text;
    trenutni_polasci jsonb;
    current_polasci jsonb;
    dan_data jsonb;
    is_bc_student_guaranteed boolean;
    new_radni_dani text;
BEGIN
    -- 1. Dohvati podatke o zahtevu i putniku
    SELECT * INTO req_record FROM seat_requests s WHERE s.id = req_id;
    IF NOT FOUND OR req_record.status != 'pending' THEN RETURN; END IF;

    SELECT * INTO putnik_record FROM registrovani_putnici r WHERE r.id = req_record.putnik_id;
    IF NOT FOUND THEN RETURN; END IF;

    dan_kratica := get_dan_kratica(req_record.datum);
    json_key_vreme := lower(req_record.grad);
    
    -- ❄️ ZIMSKI RED VOŽNJE PROVERA (Oktobar - Mart)
    IF EXTRACT(MONTH FROM req_record.datum) >= 10 OR EXTRACT(MONTH FROM req_record.datum) <= 3 THEN
        json_key_vreme := json_key_vreme || '2';
    END IF;

    json_key_status := json_key_vreme || '_status';
    json_key_ceka := json_key_vreme || '_ceka_od';

    -- 2. BC LOGIKA ZA UČENIKE (Garantovano mesto do 16h za sutra)
    is_bc_student_guaranteed := (
        lower(putnik_record.tip) = 'ucenik' 
        AND upper(req_record.grad) = 'BC' 
        AND req_record.datum = (CURRENT_DATE + 1)
        AND EXTRACT(HOUR FROM req_record.created_at) < 16
    );

    -- 3. PROVERA KAPACITETA
    IF is_bc_student_guaranteed THEN
        ima_mesta := true;
    ELSE
        slobodno_mesta := proveri_slobodna_mesta(req_record.grad, req_record.zeljeno_vreme, req_record.datum);
        ima_mesta := (slobodno_mesta >= req_record.broj_mesta);
    END IF;

    -- 4. ODREĐIVANJE NOVOG STATUSA I LOGIČNIH ALTERNATIVA
    IF ima_mesta THEN
        novi_status := 'approved';
    ELSE
        novi_status := 'rejected';
        
        -- Pronađi PRVI slobodan termin pre i PRVI slobodan termin posle (bez obzira na razliku u vremenu)
        SELECT jsonb_agg(to_char(vreme, 'HH24:MI')) INTO v_alternatives
        FROM (
            -- Prvi dostupni pre željenog vremena
            (SELECT vreme 
             FROM kapacitet_polazaka 
             WHERE grad = UPPER(req_record.grad) 
               AND aktivan = true 
               AND proveri_slobodna_mesta(req_record.grad, vreme, req_record.datum) >= req_record.broj_mesta
               AND vreme < req_record.zeljeno_vreme
             ORDER BY vreme DESC
             LIMIT 1)
            UNION ALL
            -- Prvi dostupni posle željenog vremena
            (SELECT vreme 
             FROM kapacitet_polazaka 
             WHERE grad = UPPER(req_record.grad) 
               AND aktivan = true 
               AND proveri_slobodna_mesta(req_record.grad, vreme, req_record.datum) >= req_record.broj_mesta
               AND vreme > req_record.zeljeno_vreme
             ORDER BY vreme ASC
             LIMIT 1)
        ) sub;
    END IF;

    -- 5. AŽURIRAJ SEAT_REQUESTS
    UPDATE seat_requests 
    SET status = novi_status, 
        alternatives = v_alternatives,
        processed_at = now(),
        updated_at = now()
    WHERE id = req_id;

    -- 6. AŽURIRAJ REGISTROVANI_PUTNICI (JSONB polje)
    trenutni_polasci := putnik_record.polasci_po_danu;
    dan_data := COALESCE(trenutni_polasci->dan_kratica, '{}'::jsonb);

    IF novi_status = 'approved' THEN
        dan_data := dan_data || jsonb_build_object(
            json_key_status, 'confirmed',
            json_key_vreme, req_record.zeljeno_vreme::text
        );
    ELSIF novi_status = 'rejected' THEN
        dan_data := dan_data || jsonb_build_object(json_key_status, 'rejected');
    END IF;

    current_polasci := jsonb_set(COALESCE(trenutni_polasci, '{}'::jsonb), ARRAY[dan_kratica], dan_data);

    -- Izračunaj radni_dani na osnovu novog stanja
    SELECT string_agg(key, ',') INTO new_radni_dani
    FROM (
        SELECT key
        FROM jsonb_each(current_polasci)
        WHERE (value->>'bc' IS NOT NULL AND value->>'bc' != '' AND value->>'bc' != 'null')
           OR (value->>'vs' IS NOT NULL AND value->>'vs' != '' AND value->>'vs' != 'null')
        ORDER BY CASE key
            WHEN 'pon' THEN 1 WHEN 'uto' THEN 2 WHEN 'sre' THEN 3 WHEN 'cet' THEN 4
            WHEN 'pet' THEN 5 WHEN 'sub' THEN 6 WHEN 'ned' THEN 7 ELSE 8 END
    ) sub;

    UPDATE registrovani_putnici 
    SET polasci_po_danu = current_polasci,
        radni_dani = COALESCE(new_radni_dani, ''),
        updated_at = now()
    WHERE id = putnik_record.id;
END;
$$ LANGUAGE plpgsql;

-- 4. PERIODIČNA FUNKCIJA: Koju će aplikacija ili mini-cron pozivati
CREATE OR REPLACE FUNCTION dispecer_cron_obrada()
RETURNS jsonb AS $$
DECLARE
    v_req record;
    processed_records jsonb := '[]'::jsonb;
    current_req_data jsonb;
BEGIN
    -- Pronađi sve koji čekaju obradu:
    -- 1. Radnik (BC): čekaju 2 minuta (brže nego pre)
    -- 2. Ostali: čekaju 5 minuta (brže nego pre)
    -- 3. Učenik (BC za sutra, posle 16h): čekaju do 20:00h
    FOR v_req IN 
        SELECT sr.id 
        FROM seat_requests sr
        JOIN registrovani_putnici rp ON sr.putnik_id = rp.id
        WHERE sr.status = 'pending' 
          AND (
            -- 👷 SLCUČAJ RADNIK (BC): čeka se 2 minuta
            (
                lower(rp.tip) = 'radnik' 
                AND upper(sr.grad) = 'BC' 
                AND (EXTRACT(EPOCH FROM (now() - sr.created_at)) / 60 >= 2)
            )
            OR
            -- 🟢 SLUČAJ OSTALI: standardnih 5 minuta
            (
                NOT (
                    lower(rp.tip) = 'radnik' AND upper(sr.grad) = 'BC'
                )
                AND NOT (
                    lower(rp.tip) = 'ucenik' 
                    AND upper(sr.grad) = 'BC' 
                    AND sr.datum = (CURRENT_DATE + 1)
                    AND EXTRACT(HOUR FROM sr.created_at) >= 16
                )
                AND (EXTRACT(EPOCH FROM (now() - sr.created_at)) / 60 >= 5)
            )
            OR
            -- 🟡 SLUČAJ B: Učenik (BC, sutra, posle 16h) -> Obrađuje se u 20h ili kasnije
            (
                lower(rp.tip) = 'ucenik' 
                AND upper(sr.grad) = 'BC' 
                AND sr.datum = (CURRENT_DATE + 1)
                AND EXTRACT(HOUR FROM sr.created_at) >= 16
                AND EXTRACT(HOUR FROM now()) >= 20
            )
          )
    LOOP
        PERFORM obradi_seat_request(v_req.id);
        
        SELECT jsonb_build_object(
            'id', s.id,
            'putnik_id', s.putnik_id,
            'zeljeno_vreme', s.zeljeno_vreme::text,
            'status', s.status,
            'grad', s.grad,
            'datum', s.datum::text,
            'ime_putnika', rp.putnik_ime,
            'alternatives', s.alternatives
        ) INTO current_req_data
        FROM seat_requests s
        JOIN registrovani_putnici rp ON s.putnik_id = rp.id
        WHERE s.id = v_req.id;

        processed_records := processed_records || jsonb_build_array(current_req_data);
    END LOOP;

    RETURN processed_records;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- 5. POMOĆNA FUNKCIJA: Atomski update polaska
-- ==========================================
CREATE OR REPLACE FUNCTION update_putnik_polazak_v2(
    p_id UUID,
    p_dan TEXT,
    p_grad TEXT,
    p_vreme TEXT,
    p_status TEXT DEFAULT NULL,
    p_ceka_od TEXT DEFAULT NULL,
    p_otkazano TEXT DEFAULT NULL,
    p_otkazano_vreme TEXT DEFAULT NULL,
    p_otkazao_vozac TEXT DEFAULT NULL
) RETURNS void AS $$
DECLARE
    current_data jsonb;
    dan_data jsonb;
    new_radni_dani text;
BEGIN
    -- Zaključaj red za ažuriranje ( Race Condition prevention )
    SELECT polasci_po_danu INTO current_data 
    FROM registrovani_putnici 
    WHERE id = p_id FOR UPDATE;

    -- Inicijalizuj polasci_po_danu ako je null
    current_data := COALESCE(current_data, '{}'::jsonb);

    -- Inicijalizuj dan ako ne postoji
    dan_data := COALESCE(current_data->p_dan, '{"bc": null, "vs": null}'::jsonb);

    -- Sigurno postavljanje vrednosti (koristiteći || i jsonb_build_object koji ne puca na null)
    dan_data := dan_data || jsonb_build_object(
        p_grad, p_vreme,
        p_grad || '_status', p_status,
        p_grad || '_ceka_od', p_ceka_od,
        p_grad || '_otkazano', p_otkazano,
        p_grad || '_otkazano_vreme', p_otkazano_vreme,
        p_grad || '_otkazao_vozac', p_otkazao_vozac
    );

    -- Ukloni resolved_at ako status nije confirmed/approved
    IF p_status IS NULL OR (p_status != 'confirmed' AND p_status != 'approved') THEN
        dan_data := dan_data - (p_grad || '_resolved_at');
    END IF;

    -- Formiraj finalni JSON
    current_data := jsonb_set(current_data, ARRAY[p_dan], dan_data);

    -- Automatski izračunaj radni_dani string (podržava i zimski red vožnje bc2/vs2)
    SELECT string_agg(key, ',') INTO new_radni_dani
    FROM (
        SELECT key
        FROM jsonb_each(current_data)
        WHERE (value->>'bc' IS NOT NULL AND value->>'bc' != '' AND value->>'bc' != 'null')
           OR (value->>'vs' IS NOT NULL AND value->>'vs' != '' AND value->>'vs' != 'null')
           OR (value->>'bc2' IS NOT NULL AND value->>'bc2' != '' AND value->>'bc2' != 'null')
           OR (value->>'vs2' IS NOT NULL AND value->>'vs2' != '' AND value->>'vs2' != 'null')
        ORDER BY CASE key
            WHEN 'pon' THEN 1 WHEN 'uto' THEN 2 WHEN 'sre' THEN 3 WHEN 'cet' THEN 4
            WHEN 'pet' THEN 5 WHEN 'sub' THEN 6 WHEN 'ned' THEN 7 ELSE 8 END
    ) sub;

    -- Ažuriraj bazu sa svim podacima
    UPDATE registrovani_putnici 
    SET polasci_po_danu = current_data,
        radni_dani = COALESCE(new_radni_dani, ''),
        updated_at = now()
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- 6. TRIGGERI ZA NOTIFIKACIJE I SINHRONIZACIJU
-- ==========================================

CREATE OR REPLACE FUNCTION notify_seat_request_update()
RETURNS trigger AS $$
DECLARE
    payload jsonb;
    tokens jsonb;
    notif_title text;
    notif_body text;
    putnik_ime text;
    grad_display text;
BEGIN
    IF (OLD.status = NEW.status) THEN RETURN NEW; END IF;

    SELECT rp.putnik_ime INTO putnik_ime FROM registrovani_putnici rp WHERE rp.id = NEW.putnik_id;
    grad_display := CASE WHEN NEW.grad = 'BC' THEN 'Bečej' WHEN NEW.grad = 'VS' THEN 'Vršac' ELSE NEW.grad END;

    IF NEW.status = 'approved' THEN
        notif_title := '✅ Mesto osigurano!';
        notif_body := putnik_ime || ', tvoj polazak u ' || NEW.zeljeno_vreme || ' (' || grad_display || ') je potvrđen! 🚌';
    ELSIF NEW.status = 'rejected' THEN
        IF NEW.alternatives IS NOT NULL AND jsonb_array_length(NEW.alternatives) > 0 THEN
            notif_title := '🕐 Izaberite termin';
            notif_body := 'Trenutno nema mesta za ' || NEW.zeljeno_vreme || ', ali imamo slobodnih mesta u drugim terminima.';
        ELSE
            notif_title := '❌ Termin popunjen';
            notif_body := 'Izvinjavamo se, ali termin u ' || NEW.zeljeno_vreme || ' je pun.';
        END IF;
    ELSIF NEW.status = 'manual' THEN
        notif_title := '🆕 Novi zahtev (Dnevni)';
        notif_body := putnik_ime || ' želi ' || grad_display || ' u ' || NEW.zeljeno_vreme;
    ELSE
        RETURN NEW;
    END IF;

    IF NEW.status = 'manual' THEN
        SELECT jsonb_agg(jsonb_build_object('token', token, 'provider', provider))
        INTO tokens FROM push_tokens WHERE user_id = 'Bojan';
    ELSE
        SELECT jsonb_agg(jsonb_build_object('token', token, 'provider', provider))
        INTO tokens FROM push_tokens WHERE putnik_id = NEW.putnik_id;
    END IF;

    IF tokens IS NULL OR jsonb_array_length(tokens) = 0 THEN RETURN NEW; END IF;

    payload := jsonb_build_object(
        'tokens', tokens,
        'title', notif_title,
        'body', notif_body,
        'data', jsonb_build_object(
            'type', 'seat_request_' || NEW.status,
            'id', NEW.id,
            'grad', NEW.grad,
            'vreme', NEW.zeljeno_vreme
        )
    );

    PERFORM net.http_post(
        url := (SELECT value FROM server_secrets WHERE key = 'EDGE_FUNCTION_URL' LIMIT 1) || '/send-push-notification',
        headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || (SELECT value FROM server_secrets WHERE key = 'SUPABASE_SERVICE_ROLE_KEY' LIMIT 1)),
        body := payload
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
