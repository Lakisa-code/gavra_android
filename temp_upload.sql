-- ==========================================
-- DIGITALNI DISPEÄŒER - SQL LOGIKA (V1.0)
-- ==========================================

-- 1. POMOÄ†NA FUNKCIJA: Dobavljanje imena dana (pon, uto...) iz datuma
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

-- 2. POMOÄ†NA FUNKCIJA: Provera slobodnih mesta
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

    -- 2. Prebroj putnike koji veÄ‡ ZAUZIMAJU mesto kod dispeÄera u tabeli SEAT_REQUESTS
    -- RaÄunamo one koji su PENDING (Äekaju obradu), MANUAL (Äekaju admina) ili APPROVED/CONFIRMED
    SELECT COALESCE(SUM(sr.broj_mesta), 0) INTO zauzeto_val
    FROM seat_requests sr
    WHERE sr.datum = target_datum
      AND sr.grad = UPPER(target_grad)
      AND sr.zeljeno_vreme::time = target_vreme
      AND sr.status IN ('pending', 'manual', 'approved', 'confirmed');

    RETURN max_mesta_val - zauzeto_val;
END;
$$ LANGUAGE plpgsql;

-- 3. GLAVNA FUNKCIJA: Obrada pojedinaÄnog zahteva
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
    is_bc_student_guaranteed boolean;
BEGIN
    -- 1. Dohvati podatke o zahtevu i putniku
    SELECT * INTO req_record FROM seat_requests s WHERE s.id = req_id;
    IF NOT FOUND OR req_record.status != 'pending' THEN RETURN; END IF;

    SELECT * INTO putnik_record FROM registrovani_putnici r WHERE r.id = req_record.putnik_id;
    IF NOT FOUND THEN RETURN; END IF;

    -- 2. BC LOGIKA ZA UÄŒENIKE (Garantovano mesto sa Äekanjem 5 min)
    is_bc_student_guaranteed := (
        lower(putnik_record.tip) = 'ucenik' 
        AND upper(req_record.grad) = 'BC' 
        AND req_record.datum = (CURRENT_DATE + 1)
        AND EXTRACT(HOUR FROM req_record.created_at) < 16
    );

    -- 3. PROVERA KAPACITETA
    -- UÄenici BC (pre 16h) ne proveravaju kapacitet - garantovano mesto
    IF is_bc_student_guaranteed THEN
        ima_mesta := true;
    ELSE
        slobodno_mesta := proveri_slobodna_mesta(req_record.grad, req_record.zeljeno_vreme, req_record.datum);
        ima_mesta := (slobodno_mesta >= req_record.broj_mesta);
    END IF;

    -- 4. ODREÄIVANJE NOVOG STATUSA I LOGIÄŒNIH ALTERNATIVA
    IF ima_mesta THEN
        novi_status := 'approved';
    ELSE
        novi_status := 'rejected';
        
        -- PronaÄ‘i PRVI slobodan termin PRE Å¾eljenog vremena
        SELECT vreme INTO v_alt_1
        FROM kapacitet_polazaka 
        WHERE grad = UPPER(req_record.grad) 
          AND aktivan = true 
          AND proveri_slobodna_mesta(req_record.grad, vreme, req_record.datum) >= req_record.broj_mesta
          AND vreme < req_record.zeljeno_vreme
        ORDER BY vreme DESC
        LIMIT 1;
        
        -- PronaÄ‘i PRVI slobodan termin POSLE Å¾eljenog vremena
        SELECT vreme INTO v_alt_2
        FROM kapacitet_polazaka 
        WHERE grad = UPPER(req_record.grad) 
          AND aktivan = true 
          AND proveri_slobodna_mesta(req_record.grad, vreme, req_record.datum) >= req_record.broj_mesta
          AND vreme > req_record.zeljeno_vreme
        ORDER BY vreme ASC
        LIMIT 1;
    END IF;

    -- 5. AÅ½URIRAJ SEAT_REQUESTS
    UPDATE seat_requests 
    SET status = novi_status, 
        alternative_vreme_1 = v_alt_1,
        alternative_vreme_2 = v_alt_2,
        processed_at = now(),
        updated_at = now()
    WHERE id = req_id;
END;
$$ LANGUAGE plpgsql;

-- 4. PERIODIÄŒNA FUNKCIJA: Koju Ä‡e aplikacija ili mini-cron pozivati
CREATE OR REPLACE FUNCTION dispecer_cron_obrada()
RETURNS jsonb AS $$
DECLARE
    v_req record;
    processed_records jsonb := '[]'::jsonb;
    current_req_data jsonb;
BEGIN
    -- PronaÄ‘i sve koji Äekaju obradu:
    -- 1. UÄenik (BC, pre 16h za sutra): Äekaju 5 minuta BEZ provere kapaciteta
    -- 2. Radnik (BC): Äekaju 5 minuta SA proverom kapaciteta
    -- 3. Dnevni putnik: NE obraÄ‘uje se automatski - Å¡alje se adminima (manual)
    -- 4. Ostali: Äekaju 5 minuta
    FOR v_req IN 
        SELECT sr.id 
        FROM seat_requests sr
        JOIN registrovani_putnici rp ON sr.putnik_id = rp.id
        WHERE sr.status = 'pending' 
          AND (
            -- ðŸŽ“ UÄŒENIK (BC, pre 16h, za sutra): Äeka 5 minuta
            (
                lower(rp.tip) = 'ucenik' 
                AND upper(sr.grad) = 'BC' 
                AND sr.datum = (CURRENT_DATE + 1)
                AND EXTRACT(HOUR FROM sr.created_at) < 16
                AND (EXTRACT(EPOCH FROM (now() - sr.created_at)) / 60 >= 5)
            )
            OR
            -- ðŸ‘· RADNIK (BC): Äeka 5 minuta
            (
                lower(rp.tip) = 'radnik' 
                AND upper(sr.grad) = 'BC' 
                AND (EXTRACT(EPOCH FROM (now() - sr.created_at)) / 60 >= 5)
            )
            OR
            -- ðŸŸ¢ OSTALI (ne-dnevni, ne BC uÄenik pre 16h, ne BC radnik): 5 minuta
            (
                lower(rp.tip) != 'dnevni'
                AND NOT (
                    lower(rp.tip) = 'ucenik' 
                    AND upper(sr.grad) = 'BC' 
                    AND sr.datum = (CURRENT_DATE + 1)
                    AND EXTRACT(HOUR FROM sr.created_at) < 16
                )
                AND NOT (
                    lower(rp.tip) = 'radnik' AND upper(sr.grad) = 'BC'
                )
                AND (EXTRACT(EPOCH FROM (now() - sr.created_at)) / 60 >= 5)
            )
            OR
            -- ðŸŸ¡ UÄŒENIK (BC, sutra, posle 16h) -> ObraÄ‘uje se u 20h ili kasnije
            (
                lower(rp.tip) = 'ucenik' 
                AND upper(sr.grad) = 'BC' 
                AND sr.datum = (CURRENT_DATE + 1)
                AND EXTRACT(HOUR FROM sr.created_at) >= 16
                AND EXTRACT(HOUR FROM now()) >= 20
            )
          )
          -- ISKLJUÄŒI DNEVNE: oni se ne obraÄ‘uju automatski, veÄ‡ idu na manual (admin)
          AND lower(rp.tip) != 'dnevni'
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
-- 5. POMOÄ†NA FUNKCIJA: Atomski update polaska (SADA RADI PREKO SEAT_REQUESTS)
-- ==========================================
CREATE OR REPLACE FUNCTION update_putnik_polazak_v2(
    p_id UUID,
    p_dan TEXT,
    p_grad TEXT,
    p_vreme TEXT,
    p_status TEXT DEFAULT NULL,
    p_ceka_od TEXT DEFAULT NULL, -- IgnoriÅ¡emo, koristimo created_at u seat_requests
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
    -- TraÅ¾imo sledeÄ‡i datum koji odgovara krativci dana, ukljuÄujuÄ‡i i danas ako joÅ¡ nije proÅ¡ao
    SELECT d INTO target_date
    FROM (
        SELECT CURRENT_DATE + i as d
        FROM generate_series(0, 7) i
    ) dates
    WHERE get_dan_kratica(d) = lower(p_dan)
    LIMIT 1;

    -- 2. OÄisti grad (bc2 -> BC, vs2 -> VS)
    grad_clean := UPPER(replace(p_grad, '2', ''));

    -- 3. Odredi status
    -- Ako je dnevni putnik -> automatski 'manual' (admin obraÄ‘uje)
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
    -- Prvo proveri da li veÄ‡ postoji zahtev za taj datum i taj smer (grad)
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
    grad_display := CASE WHEN NEW.grad = 'BC' THEN 'BeÄej' WHEN NEW.grad = 'VS' THEN 'VrÅ¡ac' ELSE NEW.grad END;

    IF NEW.status = 'approved' THEN
        notif_title := 'âœ… Mesto osigurano!';
        notif_body := putnik_ime || ', tvoj polazak u ' || NEW.zeljeno_vreme || ' (' || grad_display || ') je potvrÄ‘en! ðŸšŒ';
    ELSIF NEW.status = 'rejected' THEN
        IF NEW.alternatives IS NOT NULL AND jsonb_array_length(NEW.alternatives) > 0 THEN
            notif_title := 'ðŸ• Izaberite termin';
            notif_body := 'Trenutno nema mesta za ' || NEW.zeljeno_vreme || ', ali imamo slobodnih mesta u drugim terminima.';
        ELSE
            notif_title := 'âŒ Termin popunjen';
            notif_body := 'Izvinjavamo se, ali termin u ' || NEW.zeljeno_vreme || ' je pun.';
        END IF;
    ELSIF NEW.status = 'manual' THEN
        notif_title := 'ðŸ†• Novi zahtev (Dnevni)';
        notif_body := putnik_ime || ' Å¾eli ' || grad_display || ' u ' || NEW.zeljeno_vreme;
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

