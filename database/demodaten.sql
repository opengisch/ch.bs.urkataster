SET search_path TO urkataster, public;

DO $$
DECLARE
    -- Extent Winterthur
    min_x NUMERIC := 2609932.1059; max_x NUMERIC := 2613270.6863;
    min_y NUMERIC := 1266920.9212; max_y NUMERIC := 1268424.5212;
    
    i INTEGER; j INTEGER;
    
    ref_id UUID;
    cur_art TEXT; 
    
    -- Zeit
    ref_start DATE; ref_end DATE; geom_start DATE; geom_end DATE; span_days INTEGER;
    
    -- Geom
    rand_x NUMERIC; rand_y NUMERIC; rand_z NUMERIC;
    base_geom geometry; final_geom geometry;
    
    -- Counter für erfolgreiche Inserts
    children_created INTEGER; 
    
BEGIN
    FOR i IN 1..100000 LOOP
        
        -- Start einer "logischen" Transaktion pro Objekt
        -- (In PL/pgSQL ist der Block selbst eine Transaktion, Fehler rollen alles zurück)
        
        -- 1. Vorbereitung
        cur_art := (ARRAY['gebaeude', 'parzelle', 'adresse'])[floor(random()*3)+1];
        ref_start := date '1600-01-01' + (random() * (date '1880-12-31' - date '1600-01-01'))::integer;
        ref_end := LEAST(date '2025-12-31', ref_start + (random() * 36500)::integer);
        children_created := 0;

        -- 2. Referenzobjekt erstellen
        INSERT INTO referenzobjekt (art, gesichert_ab, gesichert_bis, vermutlich_ab, vermutlich_bis, created, modified, modified_by) 
        VALUES (cur_art, ref_start, ref_end, ref_start - 365, ref_end + 365, now(), now(), 'generator_strict') 
        RETURNING id_referenzobjekt INTO ref_id;

        -- 3. Kinder erstellen (Garantierte 1-3 Durchläufe)
        FOR j IN 1..(floor(random() * 3) + 1) LOOP
            
            rand_x := min_x + (random() * (max_x - min_x));
            rand_y := min_y + (random() * (max_y - min_y));
            rand_z := 400 + (random() * 100); 
            
            span_days := (ref_end - ref_start);
            geom_start := ref_start + (random() * (span_days / 2))::integer;
            geom_end := LEAST(ref_end, geom_start + (random() * (ref_end - geom_start))::integer);

            IF cur_art = 'gebaeude' THEN
                base_geom := ST_Buffer(ST_MakePoint(rand_x, rand_y), 5 + random()*10, 'quad_segs=2');
                final_geom := ST_Multi(ST_SetSRID(ST_Force3D(base_geom, rand_z), 2056));
                
                INSERT INTO gebaeude_geometrie (fk_referenzobjekt, geom, gesichert_ab, gesichert_bis, modified_by)
                VALUES (ref_id, final_geom, geom_start, geom_end, 'generator_strict');
                
                INSERT INTO gebaeude_attribute (fk_referenzobjekt, name, nutzung, flaeche, gesichert_ab, gesichert_bis, modified_by)
                VALUES (ref_id, 'Haus ' || i || '-' || j, 'Wohnen', ST_Area(base_geom), geom_start, geom_end, 'generator_strict');
                
                children_created := children_created + 1;

            ELSIF cur_art = 'parzelle' THEN
                base_geom := ST_Buffer(ST_MakePoint(rand_x, rand_y), 20 + random()*30, 'quad_segs=2');
                final_geom := ST_Multi(ST_SetSRID(ST_Force3D(base_geom, rand_z), 2056));
                
                INSERT INTO parzelle_geometrie (fk_referenzobjekt, geom, gesichert_ab, gesichert_bis, modified_by)
                VALUES (ref_id, final_geom, geom_start, geom_end, 'generator_strict');
                
                INSERT INTO parzelle_attribute (fk_referenzobjekt, nummer, ort, gesichert_ab, gesichert_bis, modified_by)
                VALUES (ref_id, 'P-' || i || j, 'Basel', geom_start, geom_end, 'generator_strict');

                children_created := children_created + 1;

            ELSIF cur_art = 'adresse' THEN
                final_geom := ST_SetSRID(ST_MakePoint(rand_x, rand_y, rand_z), 2056);
                
                INSERT INTO adresse_geometrie (fk_referenzobjekt, geom, gesichert_ab, gesichert_bis, modified_by)
                VALUES (ref_id, final_geom, geom_start, geom_end, 'generator_strict');
                
                INSERT INTO adresse_attribute (fk_referenzobjekt, bezeichnung, hausnummer, ort, gesichert_ab, gesichert_bis, modified_by)
                VALUES (ref_id, 'Adr ' || i, j::text, 'Basel', geom_start, geom_end, 'generator_strict');
                
                children_created := children_created + 1;
            END IF;
            
        END LOOP;

        -- 4. Sicherheitscheck: Wenn (aus absurden Gründen) keine Kinder da sind, Fehler werfen!
        -- Dies rollt das 'INSERT INTO referenzobjekt' automatisch zurück.
        IF children_created = 0 THEN
            RAISE EXCEPTION 'Referenzobjekt % wurde ohne Kinder erstellt! Rollback.', ref_id;
        END IF;
        
    END LOOP;
END $$;