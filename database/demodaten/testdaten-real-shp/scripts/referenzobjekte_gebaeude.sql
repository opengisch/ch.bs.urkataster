SET search_path TO urkataster, public;;

-- erstelle referenzobjekt pro geometrie und verknüpfe diese
WITH insert_referenzobjekt AS (
    INSERT INTO referenzobjekt (art, gesichert_ab, gesichert_bis, vermutlich_ab, vermutlich_bis, eid, created, modified, modified_by, bezeichnung) 
    SELECT 'gebaeude', g.gesichert_ab, g.gesichert_bis, g.vermutlich_ab, g.vermutlich_bis, random()*999999, NOW(), NOW(), 'import', g.id_gebaeude_geometrie -- für mapping
    FROM gebaeude_geometrie g
    RETURNING id_referenzobjekt, bezeichnung
)
UPDATE gebaeude_geometrie
SET fk_referenzobjekt = (SELECT id_referenzobjekt FROM insert_referenzobjekt  where bezeichnung = gebaeude_geometrie.id_gebaeude_geometrie::text LIMIT 1);

-- übernehme die referenzobjekte für überlappende geometrien (eher zufällig)
UPDATE gebaeude_geometrie taker
SET fk_referenzobjekt = giver.fk_referenzobjekt
FROM gebaeude_geometrie giver
WHERE taker.id_gebaeude_geometrie > giver.id_gebaeude_geometrie
  AND ST_Intersects(giver.geom, taker.geom);

-- lösche alle referenzobjekte ohne geometrien
DELETE FROM referenzobjekt
WHERE art='gebaeude' and id_referenzobjekt NOT IN (SELECT DISTINCT fk_referenzobjekt FROM gebaeude_geometrie);

-- setzt von bis gesichert für das referenzobjekt gemäss den geometrien
UPDATE referenzobjekt ro
SET 
    gesichert_ab = g.min_ab,
    gesichert_bis = g.max_bis
FROM (
    SELECT 
        fk_referenzobjekt,
        MIN(gesichert_ab) AS min_ab,
        MAX(gesichert_bis) AS max_bis
    FROM gebaeude_geometrie
    WHERE fk_referenzobjekt IS NOT NULL
    GROUP BY fk_referenzobjekt
) g
WHERE ro.id_referenzobjekt = g.fk_referenzobjekt;