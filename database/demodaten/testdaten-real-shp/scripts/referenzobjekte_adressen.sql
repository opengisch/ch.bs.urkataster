SET search_path TO urkataster, public;;

-- erstelle referenzobjekt pro geometrie und verknüpfe diese
WITH insert_referenzobjekt AS (
    INSERT INTO referenzobjekt (art, gesichert_ab, gesichert_bis, vermutlich_ab, vermutlich_bis, eid, created, modified, modified_by, bezeichnung) 
    SELECT 'adresse', g.gesichert_ab, g.gesichert_bis, g.vermutlich_ab, g.vermutlich_bis, random()*10000, NOW(), NOW(), 'import', g.id_adresse_geometrie -- für mapping
    FROM adresse_geometrie g
    RETURNING id_referenzobjekt, bezeichnung
)
UPDATE adresse_geometrie
SET fk_referenzobjekt = (SELECT id_referenzobjekt FROM insert_referenzobjekt where bezeichnung = adresse_geometrie.id_adresse_geometrie::text LIMIT 1);
