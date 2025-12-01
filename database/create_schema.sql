-- 0. Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- 1. Recreate schema
DROP SCHEMA IF EXISTS urkataster CASCADE;
CREATE SCHEMA IF NOT EXISTS urkataster;
SET search_path TO urkataster, public;;

-- 2. Create Referenzobjekt
CREATE TABLE referenzobjekt (
    id_referenzobjekt UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    art TEXT,
    vermutlich_ab DATE,
    gesichert_ab DATE,
    gesichert_bis DATE,
    vermutlich_bis DATE,
    eid UUID,
    idkantonal INTEGER,
    sektionparzelle TEXT,
    indexparzelle INTEGER,
    created TIMESTAMPTZ,
    modified TIMESTAMPTZ,
    modified_by TEXT
);

-- 3. Create Geometry Tables

CREATE TABLE gebaeude_geometrie (
    id_gebaeude_geometrie UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fk_referenzobjekt UUID NOT NULL REFERENCES referenzobjekt(id_referenzobjekt) ON DELETE CASCADE,
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

CREATE TABLE parzelle_geometrie (
    id_parzelle_geometrie UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fk_referenzobjekt UUID NOT NULL  REFERENCES referenzobjekt(id_referenzobjekt) ON DELETE CASCADE,
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

CREATE TABLE adresse_geometrie (
    id_adresse_geometrie UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fk_referenzobjekt UUID NOT NULL  REFERENCES referenzobjekt(id_referenzobjekt) ON DELETE CASCADE,
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

-- 4. Attribute Tables

CREATE TABLE gebaeude_attribute (
    id_gebaeude_attribute UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fk_referenzobjekt UUID NOT NULL  REFERENCES referenzobjekt(id_referenzobjekt) ON DELETE CASCADE,
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

CREATE TABLE parzelle_attribute (
    id_parzelle_attribute UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fk_referenzobjekt UUID NOT NULL REFERENCES referenzobjekt(id_referenzobjekt) ON DELETE CASCADE,
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

CREATE TABLE adresse_attribute (
    id_adresse_attribute UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fk_referenzobjekt UUID NOT NULL REFERENCES referenzobjekt(id_referenzobjekt) ON DELETE CASCADE,
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

-- 5. Metadata Tables

CREATE TABLE quelldaten (
    id_quelldaten UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- FKs nullable, because it's not linked to all tables
    fk_gebaeude_geometrie UUID REFERENCES gebaeude_geometrie(id_gebaeude_geometrie) ON DELETE SET NULL,
    fk_adresse_geometrie UUID REFERENCES adresse_geometrie(id_adresse_geometrie) ON DELETE SET NULL,
    fk_parzelle_geometrie UUID REFERENCES parzelle_geometrie(id_parzelle_geometrie) ON DELETE SET NULL,
    fk_gebaeude_attribute UUID REFERENCES gebaeude_attribute(id_gebaeude_attribute) ON DELETE SET NULL,
    fk_parzelle_attribute UUID REFERENCES parzelle_attribute(id_parzelle_attribute) ON DELETE SET NULL,
    fk_adresse_attribute UUID REFERENCES adresse_attribute(id_adresse_attribute) ON DELETE SET NULL,
    name TEXT,
    beschreibung TEXT,
    pfad TEXT
);

CREATE TABLE vorgaenger (
    fk_vorgaenger_referenzobjekt UUID NOT NULL  REFERENCES referenzobjekt(id_referenzobjekt) ON DELETE CASCADE,
    fk_nachfolger_referenzobjekt UUID NOT NULL  REFERENCES referenzobjekt(id_referenzobjekt) ON DELETE CASCADE,
    PRIMARY KEY (fk_vorgaenger_referenzobjekt, fk_nachfolger_referenzobjekt),
    CHECK (fk_vorgaenger_referenzobjekt <> fk_nachfolger_referenzobjekt) -- prevent self-references
);

-- 6. Indizes

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
