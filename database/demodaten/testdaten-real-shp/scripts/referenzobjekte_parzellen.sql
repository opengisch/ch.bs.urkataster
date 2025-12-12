SET search_path TO urkataster, public;;

-- erstelle referenzobjekt pro geometrie und verknüpfe diese
WITH insert_referenzobjekt AS (
    INSERT INTO referenzobjekt (art, gesichert_ab, gesichert_bis, vermutlich_ab, vermutlich_bis, eid, created, modified, modified_by, bezeichnung) 
    SELECT 'parzelle', g.gesichert_ab, g.gesichert_bis, g.vermutlich_ab, g.vermutlich_bis, g.quelle, NOW(), NOW(), 'import', g.id_parzelle_geometrie -- für mapping
    FROM parzelle_geometrie g
    RETURNING id_referenzobjekt, bezeichnung
)
UPDATE parzelle_geometrie
SET fk_referenzobjekt = (SELECT id_referenzobjekt FROM insert_referenzobjekt where bezeichnung = parzelle_geometrie.id_parzelle_geometrie::text LIMIT 1);
