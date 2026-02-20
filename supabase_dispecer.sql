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

-- 1A. POMOĆNA FUNKCIJA: Pravila čekanja po gradu i tipu putnika
CREATE OR REPLACE FUNCTION get_cekanje_pravilo(
    p_tip text,
    p_grad text,
    p_datum date,
    p_created_at timestamptz
) RETURNS TABLE(
    minuta_cekanja integer,
    provera_kapaciteta boolean
) AS $$
BEGIN
    -- BC PRAVILA
    IF upper(p_grad) = 'BC' THEN
        -- Učenik (za sutra, pre 16h): 5 min, BEZ provere kapaciteta
        IF lower(p_tip) = 'ucenik' 
           AND p_datum = (CURRENT_DATE + 1)
           AND EXTRACT(HOUR FROM p_created_at) < 16
        THEN
            RETURN QUERY SELECT 5, false;
        -- Radnik: 5 min, SA proverom kapaciteta
        ELSIF lower(p_tip) = 'radnik' THEN
            RETURN QUERY SELECT 5, true;
        -- Učenik (posle 16h): čeka do 20h
        ELSIF lower(p_tip) = 'ucenik' 
              AND p_datum = (CURRENT_DATE + 1)
              AND EXTRACT(HOUR FROM p_created_at) >= 16
        THEN
            RETURN QUERY SELECT 0, true; -- Specijalni slučaj, obrađuje se u 20h
        ELSE
            -- Default BC: 5 min, provera kapaciteta
            RETURN QUERY SELECT 5, true;
        END IF;
    
    -- VS PRAVILA
    ELSIF upper(p_grad) = 'VS' THEN
        -- Radnik: 10 min, SA proverom kapaciteta
        IF lower(p_tip) = 'radnik' THEN
            RETURN QUERY SELECT 10, true;
        -- Učenik: 10 min, SA proverom kapaciteta
        ELSIF lower(p_tip) = 'ucenik' THEN
            RETURN QUERY SELECT 10, true;
        ELSE
            -- Default VS: 10 min, provera kapaciteta
            RETURN QUERY SELECT 10, true;
        END IF;
    
    -- DEFAULT (nepoznat grad)
    ELSE
        RETURN QUERY SELECT 5, true;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 2. POMOĆNA FUNKCIJA: Provera slobodnih mesta
CREATE OR REPLACE FUNCTION proveri_slobodna_mesta(target_grad text, target_vreme time, target_datum date)
RETURNS integer AS $$
DECLARE
    max_mesta_val integer;
    zauzeto_val integer;
BEGIN
    -- 1. Dohvati max mesta iz kapaciteta
    SELECT kp.max_mesta INTO max_mesta_val 
    FROM kapacitet_polazaka kp
    WHERE kp.grad = UPPER(target_grad) AND kp.vreme = target_vreme AND kp.aktivan = true;
    
    IF max_mesta_val IS NULL THEN max_mesta_val := 8; END IF;

    -- 2. Prebroj putnike koji već ZAUZIMAJU mesto kod dispečera u tabeli SEAT_REQUESTS
    -- Računamo one koji su PENDING (čekaju obradu), MANUAL (čekaju admina) ili APPROVED/CONFIRMED
    SELECT COALESCE(SUM(sr.broj_mesta), 0) INTO zauzeto_val
    FROM seat_requests sr
    WHERE sr.datum = target_datum
      AND sr.grad = UPPER(target_grad)
      AND sr.zeljeno_vreme::time = target_vreme
      AND sr.status IN ('pending', 'manual', 'approved', 'confirmed');

    RETURN max_mesta_val - zauzeto_val;
END;
$$ LANGUAGE plpgsql;

-- 3. GLAVNA FUNKCIJA: Obrada pojedinačnog zahteva (UNIVERZALNA za BC i VS)
CREATE OR REPLACE FUNCTION obradi_seat_request(req_id uuid)
RETURNS void AS $$
DECLARE
    req_record record;
    putnik_record record;
    ima_mesta boolean;
    slobodno_mesta integer;
    novi_status text;
    v_alt_1 time;
    v_alt_2 time;
BEGIN
    -- 1. Dohvati podatke o zahtevu i putniku
    SELECT * INTO req_record FROM seat_requests s WHERE s.id = req_id;
    IF NOT FOUND OR req_record.status != 'pending' THEN RETURN; END IF;

    SELECT * INTO putnik_record FROM registrovani_putnici r WHERE r.id = req_record.putnik_id;
    IF NOT FOUND THEN RETURN; END IF;

    -- 2. PROVERA KAPACITETA prema pravilima (poziva se get_cekanje_pravilo)
    -- BC učenici (pre 16h za sutra) NE PROVERAVAJU kapacitet - garantovano mesto
    IF lower(putnik_record.tip) = 'ucenik' 
       AND upper(req_record.grad) = 'BC' 
       AND req_record.datum = (CURRENT_DATE + 1)
       AND EXTRACT(HOUR FROM req_record.created_at) < 16
    THEN
        ima_mesta := true;
    ELSE
        slobodno_mesta := proveri_slobodna_mesta(req_record.grad, req_record.zeljeno_vreme, req_record.datum);
        ima_mesta := (slobodno_mesta >= req_record.broj_mesta);
    END IF;

    -- 3. ODREĐIVANJE NOVOG STATUSA I LOGIČNIH ALTERNATIVA
    IF ima_mesta THEN
        novi_status := 'approved';
    ELSE
        novi_status := 'rejected';
        
        -- Pronađi PRVI slobodan termin PRE željenog vremena
        SELECT vreme INTO v_alt_1
        FROM kapacitet_polazaka 
        WHERE grad = UPPER(req_record.grad) 
          AND aktivan = true 
          AND proveri_slobodna_mesta(req_record.grad, vreme, req_record.datum) >= req_record.broj_mesta
          AND vreme < req_record.zeljeno_vreme
        ORDER BY vreme DESC
        LIMIT 1;
        
        -- Pronađi PRVI slobodan termin POSLE željenog vremena
        SELECT vreme INTO v_alt_2
        FROM kapacitet_polazaka 
        WHERE grad = UPPER(req_record.grad) 
          AND aktivan = true 
          AND proveri_slobodna_mesta(req_record.grad, vreme, req_record.datum) >= req_record.broj_mesta
          AND vreme > req_record.zeljeno_vreme
        ORDER BY vreme ASC
        LIMIT 1;
    END IF;

    -- 4. AŽURIRAJ SEAT_REQUESTS
    UPDATE seat_requests 
    SET status = novi_status, 
        alternative_vreme_1 = v_alt_1,
        alternative_vreme_2 = v_alt_2,
        processed_at = now(),
        updated_at = now()
    WHERE id = req_id;

    -- UKLONJENO: Ažuriranje radni_dani kolone u registrovani_putnici (kolona obrisana)
END;
$$ LANGUAGE plpgsql;

-- 4. PERIODIČNA FUNKCIJA: Koju će aplikacija ili mini-cron pozivati
CREATE OR REPLACE FUNCTION dispecer_cron_obrada()
RETURNS jsonb AS $$
DECLARE
    v_req record;
    processed_records jsonb := '[]'::jsonb;
    current_req_data jsonb;
    cekanje_pravilo record;
BEGIN
    -- Pronađi sve koji čekaju obradu prema pravilima čekanja
    -- Koristi get_cekanje_pravilo() da odredi vreme čekanja za svaki tip/grad
    FOR v_req IN 
        SELECT sr.id, sr.grad, sr.datum, sr.created_at, rp.tip
        FROM seat_requests sr
        JOIN registrovani_putnici rp ON sr.putnik_id = rp.id
        WHERE sr.status = 'pending' 
          AND lower(rp.tip) != 'dnevni' -- Dnevni putnici ne idu kroz auto-obradu
    LOOP
        -- Proveri pravilo čekanja za ovaj zahtev
        SELECT * INTO cekanje_pravilo 
        FROM get_cekanje_pravilo(
            v_req.tip, 
            v_req.grad, 
            v_req.datum, 
            v_req.created_at
        );
        
        -- Ako je vreme isteklo, obradi zahtev
        -- Specijalni slučaj: BC učenik posle 16h čeka do 20h
        IF (
            -- BC učenik posle 16h: obrađuje se u 20h
            (lower(v_req.tip) = 'ucenik' 
             AND upper(v_req.grad) = 'BC' 
             AND v_req.datum = (CURRENT_DATE + 1)
             AND EXTRACT(HOUR FROM v_req.created_at) >= 16
             AND EXTRACT(HOUR FROM now()) >= 20)
            OR
            -- Svi ostali: proveri da li je vreme čekanja isteklo
            ((EXTRACT(EPOCH FROM (now() - v_req.created_at)) / 60) >= cekanje_pravilo.minuta_cekanja
             AND NOT (lower(v_req.tip) = 'ucenik' 
                      AND upper(v_req.grad) = 'BC' 
                      AND v_req.datum = (CURRENT_DATE + 1)
                      AND EXTRACT(HOUR FROM v_req.created_at) >= 16))
        ) THEN
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
        END IF;
    END LOOP;

    RETURN processed_records;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- 5. POMOĆNA FUNKCIJA: Atomski update polaska (SADA RADI PREKO SEAT_REQUESTS)
-- ==========================================
CREATE OR REPLACE FUNCTION update_putnik_polazak_v2(
    p_id UUID,
    p_dan TEXT,
    p_grad TEXT,
    p_vreme TEXT,
    p_status TEXT DEFAULT NULL,
    p_ceka_od TEXT DEFAULT NULL, -- Ignorišemo, koristimo created_at u seat_requests
    p_otkazano TEXT DEFAULT NULL,
    p_otkazano_vreme TEXT DEFAULT NULL,
    p_otkazao_vozac TEXT DEFAULT NULL
) RETURNS void AS $$
DECLARE
    target_date date;
    grad_clean text;
    final_status text;
    existing_id uuid;
    p_broj_mesta integer;
    putnik_tip text;
BEGIN
    -- 0. Dohvati tip putnika
    SELECT tip INTO putnik_tip FROM registrovani_putnici WHERE id = p_id;
    
    -- 1. Odredi datum za p_dan (npr 'pon')
    -- Tražimo sledeći datum koji odgovara krativci dana, uključujući i danas ako još nije prošao
    SELECT d INTO target_date
    FROM (
        SELECT CURRENT_DATE + i as d
        FROM generate_series(0, 7) i
    ) dates
    WHERE get_dan_kratica(d) = lower(p_dan)
    LIMIT 1;

    -- 2. Očisti grad (bc2 -> BC, vs2 -> VS)
    grad_clean := UPPER(replace(p_grad, '2', ''));

    -- 3. Odredi status
    -- Ako je dnevni putnik -> automatski 'manual' (admin obrađuje)
    IF lower(putnik_tip) = 'dnevni' THEN
        final_status := 'manual';
    ELSE
        final_status := COALESCE(p_status, 'pending');
    END IF;
    
    IF p_vreme IS NULL OR p_vreme = '' OR p_vreme = 'null' THEN
        final_status := 'cancelled';
    END IF;

    -- 4. Dohvati broj mesta putnika
    SELECT broj_mesta INTO p_broj_mesta FROM registrovani_putnici WHERE id = p_id;
    IF p_broj_mesta IS NULL THEN p_broj_mesta := 1; END IF;

    -- 5. UPSERT u seat_requests za taj datum i putnika
    -- Prvo proveri da li već postoji zahtev za taj datum i taj smer (grad)
    SELECT id INTO existing_id 
    FROM seat_requests 
    WHERE putnik_id = p_id AND datum = target_date AND grad = grad_clean;

    IF existing_id IS NOT NULL THEN
        UPDATE seat_requests 
        SET zeljeno_vreme = CASE 
                WHEN p_vreme IS NULL OR p_vreme = '' OR p_vreme = 'null' THEN zeljeno_vreme 
                ELSE p_vreme::time 
            END,
            status = final_status,
            updated_at = now()
        WHERE id = existing_id;
    ELSE
        INSERT INTO seat_requests (putnik_id, grad, zeljeno_vreme, datum, status, broj_mesta, created_at, updated_at)
        VALUES (
            p_id, 
            grad_clean, 
            CASE WHEN p_vreme IS NULL OR p_vreme = '' OR p_vreme = 'null' THEN NULL ELSE p_vreme::time END, 
            target_date, 
            final_status, 
            p_broj_mesta, 
            now(), 
            now()
        );
    END IF;

    -- UKLONJENO: Ažuriranje radni_dani kolone (kolona obrisana)
    -- Samo ažuriraj updated_at
    UPDATE registrovani_putnici 
    SET updated_at = now()
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
