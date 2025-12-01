# Datenbank

## Erstellen des Schemas

```bash
psql -h localhost -p 54322 -U docker -d gis -f create_schema.sql
```

## Erstelle Demodaten
```bash
psql -h localhost -p 54322 -U docker -d gis -f demodaten.sql
```

## Datenmodell

```mermaid
erDiagram 
    %% --- HAUPTTABELLEN ---

    referenzobjekt {
        UUID id_referenzobjekt PK
        TEXT art
        DATE vermutlich_ab
        DATE gesichert_ab
        DATE gesichert_bis
        DATE vermutlich_bis
        UUID eid
        INTEGER idkantonal
        TEXT sektionparzelle
        INTEGER indexparzelle
        TIMESTAMP created
        TIMESTAMP modified
        TEXT modified_by
    }

    %% --- GEOMETRIE-TABELLEN ---

    gebaeude_geometrie {
        UUID id_gebaeude_geometrie PK
        UUID fk_referenzobjekt FK
        MultiPolygonZ geometry
        TEXT quelle
        TEXT genauigkeit_raeumlich
        DATE vermutlich_ab
        DATE gesichert_ab
        DATE gesichert_bis
        DATE vermutlich_bis
        TIMESTAMP created
        TIMESTAMP modified
        TEXT modified_by
    }    
    
    gebaeude_attribute {
        UUID id_gebaeude_attribute PK
        UUID fk_referenzobjekt FK
        TEXT name
        TEXT nutzung
        INTEGER stockwerke
        NUMERIC hoehe
        NUMERIC flaeche
        NUMERIC volumen
        TEXT genauigkeit_thematisch
        DATE vermutlich_ab
        DATE gesichert_ab
        DATE gesichert_bis
        DATE vermutlich_bis
        TIMESTAMP created
        TIMESTAMP modified
        TEXT modified_by
    }

    parzelle_geometrie {
        UUID parzelle_id PK
        UUID fk_referenzobjekt FK
        MultiPolygonZ geometry
        TEXT quelle
        TEXT genauigkeit_raeumlich
        DATE vermutlich_ab
        DATE gesichert_ab
        DATE gesichert_bis
        DATE vermutlich_bis
        TIMESTAMP created
        TIMESTAMP modified
        TEXT modified_by
    }

    parzelle_attribute {
        UUID id_parzelle_attribute PK
        UUID fk_referenzobjekt FK
        TEXT nummer
        TEXT sektion
        TEXT parzellenindex
        TEXT ort
        TEXT genauigkeit_thematisch
        DATE vermutlich_ab
        DATE gesichert_ab
        DATE gesichert_bis
        DATE vermutlich_bis
        TIMESTAMP created
        TIMESTAMP modified
        TEXT modified_by
    }

    adresse_geometrie {
        UUID id_adresse PK
        UUID fk_referenzobjekt FK
        PointZ geometry
        TEXT quelle
        TEXT genauigkeit_raeumlich
        DATE vermutlich_ab
        DATE gesichert_ab
        DATE gesichert_bis
        DATE vermutlich_bis
        TIMESTAMP created
        TIMESTAMP modified
        TEXT modified_by
    }

    adresse_attribute {
        UUID id_adresse_attribute PK
        UUID fk_referenzobjekt FK
        TEXT adresssystem
        TEXT bezeichnung
        TEXT hausnummer
        TEXT ort
        TEXT plz
        TEXT genauigkeit_thematisch
        DATE vermutlich_ab
        DATE gesichert_ab
        DATE gesichert_bis
        DATE vermutlich_bis
        TIMESTAMP created
        TIMESTAMP modified
        TEXT modified_by
    }

    quelldaten {
        UUID id_quelldaten PK
        UUID fk_gebaeude_geometrie FK
        UUID fk_adresse_geometrie FK
        UUID fk_parzelle_geometrie FK
        UUID fk_gebaeude_attribute FK
        UUID fk_adresse_attribute FK
        UUID fk_parzelle_attribute FK
        TEXT name
        string name
        string beschreibung
        string pfad
    }

    vorgaenger {
        UUID fk_vorgaenger
        UUID fk_nachfolger
    }

    %% --- BEZIEHUNGEN ---
    
    %% Referenzobjekt besitzt Geometrien und Attribute
    referenzobjekt |o--o{ gebaeude_geometrie : "has"
    referenzobjekt |o--o{ adresse_geometrie : "has"
    referenzobjekt |o--o{ parzelle_geometrie : "has"
    referenzobjekt |o--o{ gebaeude_attribute : "has"
    referenzobjekt |o--o{ adresse_attribute : "has"
    referenzobjekt |o--o{ parzelle_attribute : "has"

    referenzobjekt }o--o{ vorgaenger : "has"
    referenzobjekt o|--o{ vorgaenger : "has"

    %% Quelldaten für Geometrien
    gebaeude_geometrie ||--o{ quelldaten : ""
    adresse_geometrie ||--o{ quelldaten : ""
    parzelle_geometrie ||--o{ quelldaten : ""
    gebaeude_attribute ||--o{ quelldaten : ""
    adresse_attribute ||--o{ quelldaten : ""
    parzelle_attribute ||--o{ quelldaten : ""
```
