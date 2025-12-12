SET search_path TO urkataster, public;

DO $$
DECLARE
    -- Extent Basel
    min_x NUMERIC := 2609932.1059; max_x NUMERIC := 2613270.6863;
    min_y NUMERIC := 1266920.9212; max_y NUMERIC := 1268424.5212;
    
    i INTEGER; j INTEGER;
    retry_count INTEGER;
    max_retries CONSTANT INTEGER := 50;
    collision_found BOOLEAN;
    
    ref_id UUID;
    cur_art TEXT; 
    
    -- Zeit Variablen (Ref = Referenzobjekt, Child = Geometrie/Attribute)
    ref_ver_start DATE; ref_ver_end DATE;
    ref_ges_start DATE; ref_ges_end DATE;
    
    child_ver_start DATE; child_ver_end DATE;
    child_ges_start DATE; child_ges_end DATE;
    
    total_days INTEGER;
    
    -- Geom
    rand_x NUMERIC; rand_y NUMERIC; rand_z NUMERIC;
    base_geom geometry; final_geom geometry;
    
    -- Counter
    children_created INTEGER; 
    
BEGIN
    -- Loop für 10.000 Objekte
    FOR i IN 1..10000 LOOP
        
        -- 1. Art bestimmen
        cur_art := (ARRAY['gebaeude', 'parzelle', 'adresse'])[floor(random()*3)+1];
        
        -- 2. Zeitrahmen für Referenzobjekt festlegen (Die äußerste Hülle)
        -- Start irgendwann zwischen 1600 und 2020
        ref_ver_start := date '1600-01-01' + (random() * (date '2020-01-01' - date '1600-01-01'))::integer;
        -- Das "Vermutlich Ende" ist max 100 Jahre nach Start
        ref_ver_end := LEAST(date '2099-12-31', ref_ver_start + (random() * 36500)::integer);
        
        -- Das gesicherte Zeitfenster des Referenzobjekts ist etwas kleiner als das vermutliche
        -- (z.B. Puffer von 0 bis 5 Jahren)
        ref_ges_start := LEAST(ref_ver_end, ref_ver_start + (random() * 365 * 5)::integer);
        ref_ges_end   := GREATEST(ref_ges_start, ref_ver_end - (random() * 365 * 5)::integer);

        -- Referenzobjekt erstellen
        INSERT INTO referenzobjekt (art, gesichert_ab, gesichert_bis, vermutlich_ab, vermutlich_bis, eid, created, modified, modified_by) 
        VALUES (cur_art, ref_ges_start, ref_ges_end, ref_ver_start, ref_ver_end, (random() * 100001)::int, now(), now(), 'generator_v2') 
        RETURNING id_referenzobjekt INTO ref_id;

        children_created := 0;

        -- 3. Kinder erstellen (Versuch, passende Slots im Referenz-Zeitraum zu finden)
        FOR j IN 1..(floor(random() * 2) + 1) LOOP -- 1 bis 2 Kinder pro Ref
            
            retry_count := 0;
            collision_found := TRUE;
            
            WHILE collision_found AND retry_count < max_retries LOOP
                retry_count := retry_count + 1;
                collision_found := FALSE;
                
                -- Koordinaten würfeln
                rand_x := min_x + (random() * (max_x - min_x));
                rand_y := min_y + (random() * (max_y - min_y));
                rand_z := 400 + (random() * 100); 

                -- ZEITBERECHNUNG KINDER
                -- Regel: Child Gesichert MUSS innerhalb Ref Gesichert liegen
                total_days := (ref_ges_end - ref_ges_start);
                IF total_days < 1 THEN total_days := 1; END IF;
                
                child_ges_start := ref_ges_start + (random() * (total_days / 2))::integer;
                child_ges_end   := LEAST(ref_ges_end, child_ges_start + (random() * (ref_ges_end - child_ges_start))::integer);
                
                -- Regel: Child Vermutlich umschließt Child Gesichert, muss aber in Ref Vermutlich liegen
                -- Wir gehen hier einfachheitshalber bis an die Grenzen des Referenzobjekts
                child_ver_start := GREATEST(ref_ver_start, child_ges_start - (random() * 365 * 2)::integer);
                child_ver_end   := LEAST(ref_ver_end, child_ges_end + (random() * 365 * 2)::integer);

                -- Geometrie erstellen
                IF cur_art = 'gebaeude' THEN
                    base_geom := ST_Buffer(ST_MakePoint(rand_x, rand_y), 5 + random()*10, 'quad_segs=2');
                    final_geom := ST_Multi(ST_SetSRID(ST_Force3D(base_geom, rand_z), 2056));
                    
                    -- Kollisionsprüfung NUR auf "gesichert" Zeitraum
                    PERFORM 1 FROM gebaeude_geometrie g
                    WHERE g.geom && final_geom 
                      AND ST_Intersects(g.geom, final_geom)
                      AND (g.gesichert_ab, g.gesichert_bis) OVERLAPS (child_ges_start, child_ges_end);
                    
                    IF FOUND THEN collision_found := TRUE; END IF;

                ELSIF cur_art = 'parzelle' THEN
                    base_geom := ST_Buffer(ST_MakePoint(rand_x, rand_y), 20 + random()*30, 'quad_segs=2');
                    final_geom := ST_Multi(ST_SetSRID(ST_Force3D(base_geom, rand_z), 2056));
                    
                    PERFORM 1 FROM parzelle_geometrie p
                    WHERE p.geom && final_geom 
                      AND ST_Intersects(p.geom, final_geom)
                      AND (p.gesichert_ab, p.gesichert_bis) OVERLAPS (child_ges_start, child_ges_end);
                      
                    IF FOUND THEN collision_found := TRUE; END IF;

                ELSIF cur_art = 'adresse' THEN
                    final_geom := ST_SetSRID(ST_MakePoint(rand_x, rand_y, rand_z), 2056);
                    PERFORM 1 FROM adresse_geometrie a
                    WHERE a.geom && final_geom 
                      AND ST_dwithin(a.geom, final_geom, 0.1)
                      AND (a.gesichert_ab, a.gesichert_bis) OVERLAPS (child_ges_start, child_ges_end);
                      
                    IF FOUND THEN collision_found := TRUE; END IF;
                END IF;
            END LOOP;

            -- Insert wenn Platz gefunden
            IF NOT collision_found THEN
                IF cur_art = 'gebaeude' THEN
                    INSERT INTO gebaeude_geometrie (fk_referenzobjekt, geom, gesichert_ab, gesichert_bis, vermutlich_ab, vermutlich_bis, modified_by)
                    VALUES (ref_id, final_geom, child_ges_start, child_ges_end, child_ver_start, child_ver_end, 'generator_v2');
                    
                    INSERT INTO gebaeude_attribute (fk_referenzobjekt, name, nutzung, flaeche, gesichert_ab, gesichert_bis, vermutlich_ab, vermutlich_bis, modified_by)
                    VALUES (ref_id, 'Haus ' || i || '-' || j, 'Wohnen', ST_Area(base_geom), child_ges_start, child_ges_end, child_ver_start, child_ver_end, 'generator_v2');

                ELSIF cur_art = 'parzelle' THEN
                    INSERT INTO parzelle_geometrie (fk_referenzobjekt, geom, gesichert_ab, gesichert_bis, vermutlich_ab, vermutlich_bis, modified_by)
                    VALUES (ref_id, final_geom, child_ges_start, child_ges_end, child_ver_start, child_ver_end, 'generator_v2');
                    
                    INSERT INTO parzelle_attribute (fk_referenzobjekt, nummer, ort, gesichert_ab, gesichert_bis, vermutlich_ab, vermutlich_bis, modified_by)
                    VALUES (ref_id, 'P-' || i || j, 'Basel', child_ges_start, child_ges_end, child_ver_start, child_ver_end, 'generator_v2');

                ELSIF cur_art = 'adresse' THEN
                    INSERT INTO adresse_geometrie (fk_referenzobjekt, geom, gesichert_ab, gesichert_bis, vermutlich_ab, vermutlich_bis, modified_by)
                    VALUES (ref_id, final_geom, child_ges_start, child_ges_end, child_ver_start, child_ver_end, 'generator_v2');
                    
                    INSERT INTO adresse_attribute (fk_referenzobjekt, bezeichnung, hausnummer, ort, gesichert_ab, gesichert_bis, vermutlich_ab, vermutlich_bis, modified_by)
                    VALUES (ref_id, 'Adr ' || i, j::text, 'Basel', child_ges_start, child_ges_end, child_ver_start, child_ver_end, 'generator_v2');
                END IF;
                
                children_created := children_created + 1;
            END IF;
            
        END LOOP;

        -- Cleanup leere Referenzobjekte
        IF children_created = 0 THEN
            DELETE FROM referenzobjekt WHERE id_referenzobjekt = ref_id;
        END IF;
        
        IF i % 1000 = 0 THEN
            RAISE NOTICE 'Fortschritt: % Objekte verarbeitet.', i;
        END IF;
        
    END LOOP;
END $$;