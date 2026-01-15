# Source Code und SQL Scripts

Sämmlticher Source Coude und SQL Scripts, sowie technische Informationen und Notizen sind auf dem Github Repository https://github.com/opengisch/ch.bs.urkataster abgelegt und werden neben diesem Dokument als ZIP File publiziert.

## Plugin

Der Plugin Source Code liegt unter "urkataster_tools". Ebenso liegt dort auch das QGIS Projekt, das über das Plugin publiziert wird und im Plugin geöffnet werden kann.

## Datenbank

Infomationen zur Datenbank liegen unter "database". Das Datenmodell und die Funktionsweise der Triggerfunktionen zusätzlich aber folgend.

### Datenmodell

```mermaid
erDiagram
    %% --- HAUPTTABELLEN ---

    referenzobjekt {
        UUID id_referenzobjekt PK
        TEXT art
        TEXT bezeichnung
        TEXT eid
        INTEGER idkantonal
        TEXT sektionparzelle
        INTEGER indexparzelle
        DATE vermutlich_ab
        DATE gesichert_ab
        DATE gesichert_bis
        DATE vermutlich_bis
        MultPolygonZ polygongeom
        PointZ pointgeom
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
    referenzobjekt ||--o{ gebaeude_geometrie : "has"
    referenzobjekt ||--o{ adresse_geometrie : "has"
    referenzobjekt ||--o{ parzelle_geometrie : "has"
    referenzobjekt ||--o{ gebaeude_attribute : "has"
    referenzobjekt ||--o{ adresse_attribute : "has"
    referenzobjekt ||--o{ parzelle_attribute : "has"

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
### Triggerfunktion

#### 1. Datum

Wenn ein Feld vermutlich_ab, vermutlich_bis, gesichert_ab, gesichert_bis in...
- ... gebaeude_geometrie oder ...
- ... adresse_geometrie oder ...
- ... parzelle_geometrie oder ...
- ... gebaeude_attribute oder ...
- ... adresse_attribute oder ...
- ... parzelle_attribute ...

... angepasst (oder auch ein neues Objekt hinzugefügt) wird, dann passe auch den Parent referenzobjekt (fk_referenzobjekt) die gleichnamigen Datumswerte anhand Maximum und Minimum der Children an.

#### 2. Geometrien

Wenn ...
- ... gebaeude_geometrie oder ...
- ... parzelle_geometrie ...

... in Geometrie angepasst (oder auch ein neues Objekt hinzugefügt) wird, dann passe auch den Parent referenzobjekt in polygeom an, damit es alle Geometrien der Children als ST_Multi(ST_Union vereint.

Wenn ...
- ... adresse_geometrie ...

... in Geometrie angepasst (oder auch ein neues Objekt hinzugefügt) wird, dann passe auch den Parent referenzobjekt in pointgeom an, damit es alle Geometrien der Children als ST_Multi(ST_Union vereint.

#### 3. Referenzobjekt

Wenn ...
- ... referenzobjekt ...

... neu erstellt wird, kann es in unserer Lösung sein, dass bereits Child Objekte bestehen (zBs. aufgrund der Transaktion: RO Form öffnen, Geom erfassen, Geom schliessen (Trans Position 1), RO schliessen (Trans Positition 2)), deshalb soll es die Geometrien und Dates der Child-Objekte finden.