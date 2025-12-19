-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- Recreate schema
DROP SCHEMA IF EXISTS urkataster CASCADE;
CREATE SCHEMA IF NOT EXISTS urkataster;
SET search_path TO urkataster, public;

-- Create Referenzobjekt
CREATE TABLE referenzobjekt (
    id_referenzobjekt UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    art TEXT,
    bezeichnung TEXT, -- soll übergreiffender Name oder Nummer des betreffenden Objekts sein (z.B. Gebäudename, Parzellennummer, Adressbezeichnung) für alle Geometrien und Attribute
    eid TEXT, -- EGID, EGRID, EGAID
    idkantonal INTEGER, -- kantonale Gebäude, Parzelle, Eingangs Nummer
    sektionparzelle TEXT,
    indexparzelle INTEGER,
    vermutlich_ab DATE, -- calculated by child values via trigger function
    gesichert_ab DATE, -- calculated by child values via trigger function
    gesichert_bis DATE, -- calculated by child values via trigger function
    vermutlich_bis DATE, -- calculated by child values via trigger function
    polygongeom geometry(MultiPolygonZ, 2056), -- calculated by child values via trigger function
    pointgeom geometry(MultiPointZ, 2056), -- calculated by child values via trigger function
    created TIMESTAMPTZ,
    modified TIMESTAMPTZ,
    modified_by TEXT
);

-- ... annd Referenzobjekt Triggers

-- on insert (falls schon Child Objekte bestehen)
CREATE OR REPLACE FUNCTION triggerfunction_collect_children_values_on_insert_referenzobjekt()
RETURNS TRIGGER AS $$
BEGIN
    -- for gebaeude
    IF (NEW.art = 'gebaeude') THEN
        -- get the dates
        WITH all_dates AS (
            SELECT vermutlich_ab, gesichert_ab, gesichert_bis, vermutlich_bis FROM urkataster.gebaeude_geometrie WHERE fk_referenzobjekt = NEW.id_referenzobjekt
            UNION ALL
            SELECT vermutlich_ab, gesichert_ab, gesichert_bis, vermutlich_bis FROM urkataster.gebaeude_attribute WHERE fk_referenzobjekt = NEW.id_referenzobjekt
        )
        SELECT
            MIN(vermutlich_ab), MIN(gesichert_ab), MAX(gesichert_bis), MAX(vermutlich_bis)
        INTO
            NEW.vermutlich_ab, NEW.gesichert_ab, NEW.gesichert_bis, NEW.vermutlich_bis
        FROM all_dates;

        -- get the geometries
        NEW.polygongeom := (
            SELECT public.ST_Multi(public.ST_Union(geom))::public.geometry(MultiPolygonZ, 2056)
            FROM urkataster.gebaeude_geometrie
            WHERE fk_referenzobjekt = NEW.id_referenzobjekt
        );
    END IF;

    -- for parzelle
    IF (NEW.art = 'parzelle') THEN
        -- get the dates
        WITH all_dates AS (
            SELECT vermutlich_ab, gesichert_ab, gesichert_bis, vermutlich_bis FROM urkataster.parzelle_geometrie WHERE fk_referenzobjekt = NEW.id_referenzobjekt
            UNION ALL
            SELECT vermutlich_ab, gesichert_ab, gesichert_bis, vermutlich_bis FROM urkataster.parzelle_attribute WHERE fk_referenzobjekt = NEW.id_referenzobjekt
        )
        SELECT
            MIN(vermutlich_ab), MIN(gesichert_ab), MAX(gesichert_bis), MAX(vermutlich_bis)
        INTO
            NEW.vermutlich_ab, NEW.gesichert_ab, NEW.gesichert_bis, NEW.vermutlich_bis
        FROM all_dates;

        -- get the geometries
        NEW.polygongeom := (
            SELECT public.ST_Multi(public.ST_Union(geom))::public.geometry(MultiPolygonZ, 2056)
            FROM urkataster.parzelle_geometrie
            WHERE fk_referenzobjekt = NEW.id_referenzobjekt
        );
    END IF;
    RETURN NEW;

    -- for adresse
    IF (NEW.art = 'adresse') THEN
        -- get the dates
        WITH all_dates AS (
            SELECT vermutlich_ab, gesichert_ab, gesichert_bis, vermutlich_bis FROM urkataster.adresse_geometrie WHERE fk_referenzobjekt = NEW.id_referenzobjekt
            UNION ALL
            SELECT vermutlich_ab, gesichert_ab, gesichert_bis, vermutlich_bis FROM urkataster.adresse_attribute WHERE fk_referenzobjekt = NEW.id_referenzobjekt
        )
        SELECT
            MIN(vermutlich_ab), MIN(gesichert_ab), MAX(gesichert_bis), MAX(vermutlich_bis)
        INTO
            NEW.vermutlich_ab, NEW.gesichert_ab, NEW.gesichert_bis, NEW.vermutlich_bis
        FROM all_dates;

        -- get the geometries
        NEW.polygongeom := (
            SELECT public.ST_Multi(public.ST_Union(geom))::public.geometry(MultiPointZ, 2056)
            FROM urkataster.adresse_geometrie
            WHERE fk_referenzobjekt = NEW.id_referenzobjekt
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_referenzobjekt_insert BEFORE INSERT ON urkataster.referenzobjekt FOR EACH ROW EXECUTE FUNCTION triggerfunction_collect_children_values_on_insert_referenzobjekt();

-- Create Gebaeude Tables

CREATE TABLE gebaeude_geometrie (
    id_gebaeude_geometrie UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fk_referenzobjekt UUID NOT NULL REFERENCES referenzobjekt(id_referenzobjekt) ON DELETE CASCADE  DEFERRABLE INITIALLY DEFERRED, -- das DEFERRABLE... stellt sicher, dass wir in Transaktionen mit mehreren Inserts keine FK Probleme bekommen (wenn Childs vor Parent erstellt werden in Relation Editors)
    geom geometry(MultiPolygonZ, 2056),
    quelle TEXT,
    genauigkeit_raeumlich TEXT,
    vermutlich_ab DATE,
    gesichert_ab DATE,
    gesichert_bis DATE,
    vermutlich_bis DATE,
    created TIMESTAMPTZ,
    modified TIMESTAMPTZ,
    modified_by TEXT
);

CREATE TABLE gebaeude_attribute (
    id_gebaeude_attribute UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fk_referenzobjekt UUID NOT NULL  REFERENCES referenzobjekt(id_referenzobjekt) ON DELETE CASCADE  DEFERRABLE INITIALLY DEFERRED, -- das DEFERRABLE... stellt sicher, dass wir in Transaktionen mit mehreren Inserts keine FK Probleme bekommen (wenn Childs vor Parent erstellt werden in Relation Editors)
    name TEXT,
    nutzung TEXT,
    stockwerke INTEGER,
    hoehe NUMERIC,
    flaeche NUMERIC,
    volumen NUMERIC,
    genauigkeit_thematisch TEXT,
    vermutlich_ab DATE,
    gesichert_ab DATE,
    gesichert_bis DATE,
    vermutlich_bis DATE,
    created TIMESTAMPTZ,
    modified TIMESTAMPTZ,
    modified_by TEXT
);

-- ... and Gebaeude Triggers

-- update on date change
CREATE OR REPLACE FUNCTION triggerfunction_update_dates_gebaeude() RETURNS TRIGGER AS $$
DECLARE
    v_affected_ids UUID[];
    v_id UUID;
BEGIN
    -- Don't do anything when it's an update and neither dates changed, nor it changed the parent
    IF (TG_OP = 'UPDATE') THEN
        IF (NEW.vermutlich_ab  IS NOT DISTINCT FROM OLD.vermutlich_ab) AND
           (NEW.gesichert_ab   IS NOT DISTINCT FROM OLD.gesichert_ab) AND
           (NEW.gesichert_bis  IS NOT DISTINCT FROM OLD.gesichert_bis) AND
           (NEW.vermutlich_bis IS NOT DISTINCT FROM OLD.vermutlich_bis) AND
           (NEW.fk_referenzobjekt = OLD.fk_referenzobjekt) THEN
            RETURN NULL;
        END IF;
    END IF;

    -- Get the affected ids
    IF (TG_OP = 'DELETE') THEN
        -- on delete it's the old fk that is affected
        v_affected_ids := ARRAY[OLD.fk_referenzobjekt];
    ELSIF (TG_OP = 'INSERT') THEN
        -- on insert it's the new fk that is affected
        v_affected_ids := ARRAY[NEW.fk_referenzobjekt];
    ELSE -- UPDATE
        -- on update it's the new one, except when the fk itself changed, then it's both
        IF (NEW.fk_referenzobjekt IS DISTINCT FROM OLD.fk_referenzobjekt) THEN
             v_affected_ids := ARRAY[OLD.fk_referenzobjekt, NEW.fk_referenzobjekt];
        ELSE
             v_affected_ids := ARRAY[NEW.fk_referenzobjekt];
        END IF;
    END IF;

    -- Now only update the affected ids (to save performance)
    FOREACH v_id IN ARRAY v_affected_ids
    LOOP
        WITH all_values AS (
            SELECT vermutlich_ab, gesichert_ab, gesichert_bis, vermutlich_bis FROM urkataster.gebaeude_geometrie WHERE fk_referenzobjekt = v_id
            UNION ALL
            SELECT vermutlich_ab, gesichert_ab, gesichert_bis, vermutlich_bis FROM urkataster.gebaeude_attribute WHERE fk_referenzobjekt = v_id
        )
        UPDATE urkataster.referenzobjekt SET
            vermutlich_ab = (SELECT MIN(vermutlich_ab) FROM all_values),
            gesichert_ab  = (SELECT MIN(gesichert_ab)  FROM all_values),
            gesichert_bis = (SELECT MAX(gesichert_bis) FROM all_values),
            vermutlich_bis= (SELECT MAX(vermutlich_bis)FROM all_values),
            modified = now(),
            modified_by = 'Childobjekt'
        WHERE id_referenzobjekt = v_id AND art = 'gebaeude';
    END LOOP;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_gebaeude_geometrie_dates AFTER INSERT OR UPDATE OR DELETE ON gebaeude_geometrie FOR EACH ROW EXECUTE FUNCTION triggerfunction_update_dates_gebaeude();
CREATE TRIGGER trigger_gebaeude_attribute_dates AFTER INSERT OR UPDATE OR DELETE ON gebaeude_attribute FOR EACH ROW EXECUTE FUNCTION triggerfunction_update_dates_gebaeude();

-- update on geom change

CREATE OR REPLACE FUNCTION trigger_update_poly_gebaeude() RETURNS TRIGGER AS $$
DECLARE
    v_affected_ids UUID[];
    v_id UUID;
BEGIN
    -- Don't do anything when it's an update and neither geometry changed, nor it changed the parent
    IF (TG_OP = 'UPDATE') THEN
        IF (NEW.geom = OLD.geom) AND (NEW.fk_referenzobjekt = OLD.fk_referenzobjekt) THEN
            RETURN NULL;
        END IF;
    END IF;

    -- Get the affected ids
    IF (TG_OP = 'DELETE') THEN
        -- on delete it's the old fk that is affected
        v_affected_ids := ARRAY[OLD.fk_referenzobjekt];
    ELSIF (TG_OP = 'INSERT') THEN
        -- on insert it's the new fk that is affected
        v_affected_ids := ARRAY[NEW.fk_referenzobjekt];
    ELSE -- UPDATE
        -- on update it's the new one, except when the fk itself changed, then it's both
        IF (NEW.fk_referenzobjekt IS DISTINCT FROM OLD.fk_referenzobjekt) THEN
             v_affected_ids := ARRAY[OLD.fk_referenzobjekt, NEW.fk_referenzobjekt];
        ELSE
             v_affected_ids := ARRAY[NEW.fk_referenzobjekt];
        END IF;
    END IF;

    -- Now only update the affected ids (to save performance)
    FOREACH v_id IN ARRAY v_affected_ids
    LOOP
        UPDATE urkataster.referenzobjekt SET
            polygongeom = (
                SELECT public.ST_Multi(public.ST_Union(geom))::public.geometry(MultiPolygonZ, 2056)
                FROM urkataster.gebaeude_geometrie WHERE fk_referenzobjekt = v_id
            ),
            modified = now(),
            modified_by = 'Childobjekt'
        WHERE id_referenzobjekt = v_id AND art = 'gebaeude';
    END LOOP;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_gebaeude_geometrie_geometry AFTER INSERT OR UPDATE OR DELETE ON gebaeude_geometrie FOR EACH ROW EXECUTE FUNCTION trigger_update_poly_gebaeude();

-- Create Parzelle Tables
CREATE TABLE parzelle_geometrie (
    id_parzelle_geometrie UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fk_referenzobjekt UUID NOT NULL  REFERENCES referenzobjekt(id_referenzobjekt) ON DELETE CASCADE  DEFERRABLE INITIALLY DEFERRED, -- das DEFERRABLE... stellt sicher, dass wir in Transaktionen mit mehreren Inserts keine FK Probleme bekommen (wenn Childs vor Parent erstellt werden in Relation Editors)
    geom geometry(MultiPolygonZ, 2056),
    quelle TEXT,
    genauigkeit_raeumlich TEXT,
    vermutlich_ab DATE,
    gesichert_ab DATE,
    gesichert_bis DATE,
    vermutlich_bis DATE,
    created TIMESTAMPTZ,
    modified TIMESTAMPTZ,
    modified_by TEXT
);

CREATE TABLE parzelle_attribute (
    id_parzelle_attribute UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fk_referenzobjekt UUID NOT NULL REFERENCES referenzobjekt(id_referenzobjekt) ON DELETE CASCADE  DEFERRABLE INITIALLY DEFERRED, -- das DEFERRABLE... stellt sicher, dass wir in Transaktionen mit mehreren Inserts keine FK Probleme bekommen (wenn Childs vor Parent erstellt werden in Relation Editors)
    nummer TEXT,
    sektion TEXT,
    parzellenindex TEXT,
    ort TEXT,
    genauigkeit_thematisch TEXT,
    vermutlich_ab DATE,
    gesichert_ab DATE,
    gesichert_bis DATE,
    vermutlich_bis DATE,
    created TIMESTAMPTZ,
    modified TIMESTAMPTZ,
    modified_by TEXT
);

-- ... and Parzelle Triggers

-- update on date change
CREATE OR REPLACE FUNCTION triggerfunction_update_dates_parzelle() RETURNS TRIGGER AS $$
DECLARE
    v_affected_ids UUID[];
    v_id UUID;
BEGIN
    -- Don't do anything when it's an update and neither dates changed, nor it changed the parent
    IF (TG_OP = 'UPDATE') THEN
        IF (NEW.vermutlich_ab  IS NOT DISTINCT FROM OLD.vermutlich_ab) AND
           (NEW.gesichert_ab   IS NOT DISTINCT FROM OLD.gesichert_ab) AND
           (NEW.gesichert_bis  IS NOT DISTINCT FROM OLD.gesichert_bis) AND
           (NEW.vermutlich_bis IS NOT DISTINCT FROM OLD.vermutlich_bis) AND
           (NEW.fk_referenzobjekt = OLD.fk_referenzobjekt) THEN
            RETURN NULL;
        END IF;
    END IF;

    -- Get the affected ids
    IF (TG_OP = 'DELETE') THEN
        -- on delete it's the old fk that is affected
        v_affected_ids := ARRAY[OLD.fk_referenzobjekt];
    ELSIF (TG_OP = 'INSERT') THEN
        -- on insert it's the new fk that is affected
        v_affected_ids := ARRAY[NEW.fk_referenzobjekt];
    ELSE -- UPDATE
        -- on update it's the new one, except when the fk itself changed, then it's both
        IF (NEW.fk_referenzobjekt IS DISTINCT FROM OLD.fk_referenzobjekt) THEN
             v_affected_ids := ARRAY[OLD.fk_referenzobjekt, NEW.fk_referenzobjekt];
        ELSE
             v_affected_ids := ARRAY[NEW.fk_referenzobjekt];
        END IF;
    END IF;

    -- Now only update the affected ids (to save performance)
    FOREACH v_id IN ARRAY v_affected_ids
    LOOP
        WITH all_values AS (
            SELECT vermutlich_ab, gesichert_ab, gesichert_bis, vermutlich_bis FROM urkataster.parzelle_geometrie WHERE fk_referenzobjekt = v_id
            UNION ALL
            SELECT vermutlich_ab, gesichert_ab, gesichert_bis, vermutlich_bis FROM urkataster.parzelle_attribute WHERE fk_referenzobjekt = v_id
        )
        UPDATE urkataster.referenzobjekt SET
            vermutlich_ab = (SELECT MIN(vermutlich_ab) FROM all_values),
            gesichert_ab  = (SELECT MIN(gesichert_ab)  FROM all_values),
            gesichert_bis = (SELECT MAX(gesichert_bis) FROM all_values),
            vermutlich_bis= (SELECT MAX(vermutlich_bis)FROM all_values),
            modified = now(),
            modified_by = 'Childobjekt'
        WHERE id_referenzobjekt = v_id AND art = 'parzelle';
    END LOOP;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_parzelle_geometrie_dates AFTER INSERT OR UPDATE OR DELETE ON parzelle_geometrie FOR EACH ROW EXECUTE FUNCTION triggerfunction_update_dates_parzelle();
CREATE TRIGGER trigger_parzelle_attribute_dates AFTER INSERT OR UPDATE OR DELETE ON parzelle_attribute FOR EACH ROW EXECUTE FUNCTION triggerfunction_update_dates_parzelle();

-- update on geom change

CREATE OR REPLACE FUNCTION trigger_update_poly_parzelle() RETURNS TRIGGER AS $$
DECLARE
    v_affected_ids UUID[];
    v_id UUID;
BEGIN
    -- Don't do anything when it's an update and neither geometry changed, nor it changed the parent
    IF (TG_OP = 'UPDATE') THEN
        IF (NEW.geom = OLD.geom) AND (NEW.fk_referenzobjekt = OLD.fk_referenzobjekt) THEN
            RETURN NULL;
        END IF;
    END IF;

    -- Get the affected ids
    IF (TG_OP = 'DELETE') THEN
        -- on delete it's the old fk that is affected
        v_affected_ids := ARRAY[OLD.fk_referenzobjekt];
    ELSIF (TG_OP = 'INSERT') THEN
        -- on insert it's the new fk that is affected
        v_affected_ids := ARRAY[NEW.fk_referenzobjekt];
    ELSE -- UPDATE
        -- on update it's the new one, except when the fk itself changed, then it's both
        IF (NEW.fk_referenzobjekt IS DISTINCT FROM OLD.fk_referenzobjekt) THEN
             v_affected_ids := ARRAY[OLD.fk_referenzobjekt, NEW.fk_referenzobjekt];
        ELSE
             v_affected_ids := ARRAY[NEW.fk_referenzobjekt];
        END IF;
    END IF;

    -- Now only update the affected ids (to save performance)
    FOREACH v_id IN ARRAY v_affected_ids
    LOOP
        UPDATE urkataster.referenzobjekt SET
            polygongeom = (
                SELECT public.ST_Multi(public.ST_Union(geom))::public.geometry(MultiPolygonZ, 2056)
                FROM urkataster.parzelle_geometrie WHERE fk_referenzobjekt = v_id
            ),
            modified = now(),
            modified_by = 'Childobjekt'
        WHERE id_referenzobjekt = v_id AND art = 'parzelle';
    END LOOP;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_parzelle_geometrie_geometry AFTER INSERT OR UPDATE OR DELETE ON parzelle_geometrie FOR EACH ROW EXECUTE FUNCTION trigger_update_poly_parzelle();

-- Adresse Tables
CREATE TABLE adresse_geometrie (
    id_adresse_geometrie UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fk_referenzobjekt UUID NOT NULL  REFERENCES referenzobjekt(id_referenzobjekt) ON DELETE CASCADE  DEFERRABLE INITIALLY DEFERRED, -- das DEFERRABLE... stellt sicher, dass wir in Transaktionen mit mehreren Inserts keine FK Probleme bekommen (wenn Childs vor Parent erstellt werden in Relation Editors)
    geom geometry(PointZ, 2056),
    quelle TEXT,
    genauigkeit_raeumlich TEXT,
    vermutlich_ab DATE,
    gesichert_ab DATE,
    gesichert_bis DATE,
    vermutlich_bis DATE,
    created TIMESTAMPTZ,
    modified TIMESTAMPTZ,
    modified_by TEXT
);

CREATE TABLE adresse_attribute (
    id_adresse_attribute UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fk_referenzobjekt UUID NOT NULL REFERENCES referenzobjekt(id_referenzobjekt) ON DELETE CASCADE  DEFERRABLE INITIALLY DEFERRED, -- das DEFERRABLE... stellt sicher, dass wir in Transaktionen mit mehreren Inserts keine FK Probleme bekommen (wenn Childs vor Parent erstellt werden in Relation Editors)
    adresssystem TEXT,
    bezeichnung TEXT,
    hausnummer TEXT,
    ort TEXT,
    plz TEXT,
    genauigkeit_thematisch TEXT,
    vermutlich_ab DATE,
    gesichert_ab DATE,
    gesichert_bis DATE,
    vermutlich_bis DATE,
    created TIMESTAMPTZ,
    modified TIMESTAMPTZ,
    modified_by TEXT
);

-- ... and Adresse Triggers

-- update on date change
CREATE OR REPLACE FUNCTION triggerfunction_update_dates_adresse() RETURNS TRIGGER AS $$
DECLARE
    v_affected_ids UUID[];
    v_id UUID;
BEGIN
    -- Don't do anything when it's an update and neither dates changed, nor it changed the parent
    IF (TG_OP = 'UPDATE') THEN
        IF (NEW.vermutlich_ab  IS NOT DISTINCT FROM OLD.vermutlich_ab) AND
           (NEW.gesichert_ab   IS NOT DISTINCT FROM OLD.gesichert_ab) AND
           (NEW.gesichert_bis  IS NOT DISTINCT FROM OLD.gesichert_bis) AND
           (NEW.vermutlich_bis IS NOT DISTINCT FROM OLD.vermutlich_bis) AND
           (NEW.fk_referenzobjekt = OLD.fk_referenzobjekt) THEN
            RETURN NULL;
        END IF;
    END IF;

    -- Get the affected ids
    IF (TG_OP = 'DELETE') THEN
        -- on delete it's the old fk that is affected
        v_affected_ids := ARRAY[OLD.fk_referenzobjekt];
    ELSIF (TG_OP = 'INSERT') THEN
        -- on insert it's the new fk that is affected
        v_affected_ids := ARRAY[NEW.fk_referenzobjekt];
    ELSE -- UPDATE
        -- on update it's the new one, except when the fk itself changed, then it's both
        IF (NEW.fk_referenzobjekt IS DISTINCT FROM OLD.fk_referenzobjekt) THEN
             v_affected_ids := ARRAY[OLD.fk_referenzobjekt, NEW.fk_referenzobjekt];
        ELSE
             v_affected_ids := ARRAY[NEW.fk_referenzobjekt];
        END IF;
    END IF;

    -- Now only update the affected ids (to save performance)
    FOREACH v_id IN ARRAY v_affected_ids
    LOOP
        WITH all_values AS (
            SELECT vermutlich_ab, gesichert_ab, gesichert_bis, vermutlich_bis FROM urkataster.parzelle_geometrie WHERE fk_referenzobjekt = v_id
            UNION ALL
            SELECT vermutlich_ab, gesichert_ab, gesichert_bis, vermutlich_bis FROM urkataster.parzelle_attribute WHERE fk_referenzobjekt = v_id
        )
        UPDATE urkataster.referenzobjekt SET
            vermutlich_ab = (SELECT MIN(vermutlich_ab) FROM all_values),
            gesichert_ab  = (SELECT MIN(gesichert_ab)  FROM all_values),
            gesichert_bis = (SELECT MAX(gesichert_bis) FROM all_values),
            vermutlich_bis= (SELECT MAX(vermutlich_bis)FROM all_values),
            modified = now(),
            modified_by = 'Childobjekt'
        WHERE id_referenzobjekt = v_id AND art = 'adresse';
    END LOOP;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_adresse_geometrie_dates AFTER INSERT OR UPDATE OR DELETE ON adresse_geometrie FOR EACH ROW EXECUTE FUNCTION triggerfunction_update_dates_adresse();
CREATE TRIGGER trigger_adresse_attribute_dates AFTER INSERT OR UPDATE OR DELETE ON adresse_attribute FOR EACH ROW EXECUTE FUNCTION triggerfunction_update_dates_adresse();

-- update on geom change

CREATE OR REPLACE FUNCTION trigger_update_poly_adresse() RETURNS TRIGGER AS $$
DECLARE
    v_affected_ids UUID[];
    v_id UUID;
BEGIN
    -- Don't do anything when it's an update and neither geometry changed, nor it changed the parent
    IF (TG_OP = 'UPDATE') THEN
        IF (NEW.geom = OLD.geom) AND (NEW.fk_referenzobjekt = OLD.fk_referenzobjekt) THEN
            RETURN NULL;
        END IF;
    END IF;

    -- Get the affected ids
    IF (TG_OP = 'DELETE') THEN
        -- on delete it's the old fk that is affected
        v_affected_ids := ARRAY[OLD.fk_referenzobjekt];
    ELSIF (TG_OP = 'INSERT') THEN
        -- on insert it's the new fk that is affected
        v_affected_ids := ARRAY[NEW.fk_referenzobjekt];
    ELSE -- UPDATE
        -- on update it's the new one, except when the fk itself changed, then it's both
        IF (NEW.fk_referenzobjekt IS DISTINCT FROM OLD.fk_referenzobjekt) THEN
             v_affected_ids := ARRAY[OLD.fk_referenzobjekt, NEW.fk_referenzobjekt];
        ELSE
             v_affected_ids := ARRAY[NEW.fk_referenzobjekt];
        END IF;
    END IF;

    -- Now only update the affected ids (to save performance)
    FOREACH v_id IN ARRAY v_affected_ids
    LOOP
        UPDATE urkataster.referenzobjekt SET
            pointgeom = (
                SELECT public.ST_Multi(public.ST_Union(geom))::public.geometry(MultiPointZ, 2056)
                FROM urkataster.adresse_geometrie WHERE fk_referenzobjekt = v_id
            ),
            modified = now(),
            modified_by = 'Childobjekt'
        WHERE id_referenzobjekt = v_id AND art = 'adresse';
    END LOOP;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_adresse_geometrie_geometry AFTER INSERT OR UPDATE OR DELETE ON adresse_geometrie FOR EACH ROW EXECUTE FUNCTION trigger_update_poly_adresse();

-- Metadata Tables

CREATE TABLE quelldaten (
    id_quelldaten UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- FKs nullable, because it's not linked to all tables
    fk_gebaeude_geometrie UUID NULL REFERENCES gebaeude_geometrie(id_gebaeude_geometrie) ON DELETE CASCADE  DEFERRABLE INITIALLY DEFERRED, -- das DEFERRABLE... stellt sicher, dass wir in Transaktionen mit mehreren Inserts keine FK Probleme bekommen (wenn Childs vor Parent erstellt werden in Relation Editors)
    fk_adresse_geometrie UUID NULL REFERENCES adresse_geometrie(id_adresse_geometrie) ON DELETE CASCADE  DEFERRABLE INITIALLY DEFERRED, -- das DEFERRABLE... stellt sicher, dass wir in Transaktionen mit mehreren Inserts keine FK Probleme bekommen (wenn Childs vor Parent erstellt werden in Relation Editors)
    fk_parzelle_geometrie UUID NULL REFERENCES parzelle_geometrie(id_parzelle_geometrie) ON DELETE CASCADE  DEFERRABLE INITIALLY DEFERRED, -- das DEFERRABLE... stellt sicher, dass wir in Transaktionen mit mehreren Inserts keine FK Probleme bekommen (wenn Childs vor Parent erstellt werden in Relation Editors)
    fk_gebaeude_attribute UUID NULL REFERENCES gebaeude_attribute(id_gebaeude_attribute) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED, -- das DEFERRABLE... stellt sicher, dass wir in Transaktionen mit mehreren Inserts keine FK Probleme bekommen (wenn Childs vor Parent erstellt werden in Relation Editors)
    fk_parzelle_attribute UUID NULL REFERENCES parzelle_attribute(id_parzelle_attribute) ON DELETE CASCADE  DEFERRABLE INITIALLY DEFERRED, -- das DEFERRABLE... stellt sicher, dass wir in Transaktionen mit mehreren Inserts keine FK Probleme bekommen (wenn Childs vor Parent erstellt werden in Relation Editors)
    fk_adresse_attribute UUID NULL REFERENCES adresse_attribute(id_adresse_attribute) ON DELETE CASCADE  DEFERRABLE INITIALLY DEFERRED, -- das DEFERRABLE... stellt sicher, dass wir in Transaktionen mit mehreren Inserts keine FK Probleme bekommen (wenn Childs vor Parent erstellt werden in Relation Editors)
    name TEXT,
    beschreibung TEXT,
    pfad TEXT
);

CREATE TABLE vorgaenger (
    fk_vorgaenger_referenzobjekt UUID NOT NULL  REFERENCES referenzobjekt(id_referenzobjekt) ON DELETE CASCADE  DEFERRABLE INITIALLY DEFERRED, -- das DEFERRABLE... stellt sicher, dass wir in Transaktionen mit mehreren Inserts keine FK Probleme bekommen (wenn Childs vor Parent erstellt werden in Relation Editors)
    fk_nachfolger_referenzobjekt UUID NOT NULL  REFERENCES referenzobjekt(id_referenzobjekt) ON DELETE CASCADE  DEFERRABLE INITIALLY DEFERRED, -- das DEFERRABLE... stellt sicher, dass wir in Transaktionen mit mehreren Inserts keine FK Probleme bekommen (wenn Childs vor Parent erstellt werden in Relation Editors)
    PRIMARY KEY (fk_vorgaenger_referenzobjekt, fk_nachfolger_referenzobjekt),
    CHECK (fk_vorgaenger_referenzobjekt <> fk_nachfolger_referenzobjekt) -- prevent self-references
);

-- Indizes

-- Spatial Indizes (GIST)
CREATE INDEX idx_gebaeude_geom ON gebaeude_geometrie USING GIST (geom);
CREATE INDEX idx_parzelle_geom ON parzelle_geometrie USING GIST (geom);
CREATE INDEX idx_adresse_geom ON adresse_geometrie USING GIST (geom);

-- FK Indizes
CREATE INDEX idx_gebaeude_geo_ref ON gebaeude_geometrie(fk_referenzobjekt);
CREATE INDEX idx_parzelle_geo_ref ON parzelle_geometrie(fk_referenzobjekt);
CREATE INDEX idx_adresse_geo_ref ON adresse_geometrie(fk_referenzobjekt);

CREATE INDEX idx_gebaeude_attr_ref ON gebaeude_attribute(fk_referenzobjekt);
CREATE INDEX idx_parzelle_attr_ref ON parzelle_attribute(fk_referenzobjekt);
CREATE INDEX idx_adresse_attr_ref ON adresse_attribute(fk_referenzobjekt);

CREATE INDEX idx_quelldaten_fk_geb_geo ON quelldaten(fk_gebaeude_geometrie);
CREATE INDEX idx_quelldaten_fk_par_geo ON quelldaten(fk_parzelle_geometrie);
CREATE INDEX idx_quelldaten_fk_adr_geo ON quelldaten(fk_adresse_geometrie);
CREATE INDEX idx_quelldaten_fk_geb_att ON quelldaten(fk_gebaeude_attribute);
CREATE INDEX idx_quelldaten_fk_par_att ON quelldaten(fk_parzelle_attribute);
CREATE INDEX idx_quelldaten_fk_adr_att ON quelldaten(fk_adresse_attribute);

CREATE INDEX idx_vorgaenger_fk_vor ON vorgaenger(fk_vorgaenger_referenzobjekt);
CREATE INDEX idx_vorgaenger_fk_nach ON vorgaenger(fk_nachfolger_referenzobjekt);
