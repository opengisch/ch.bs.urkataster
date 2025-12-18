# Datenbank

## Erstellen des Schemas

```bash
psql -h localhost -p 54322 -U docker -d gis -f create_schema.sql
```

## Datenmodell

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

Wenn ein Feld vermutlich_ab, vermutlich_bis, gesichert_ab, gesichert_bis in...
... gebaeude_geometrie oder ...
... adresse_geometrie oder ...
... parzelle_geometrie oder ...
... gebaeude_attribute oder ...
... adresse_attribute oder ...
... parzelle_attribute ...
... angepasst (oder auch ein neues Objekt hinzugefügt) wird, dann passe auch den Parent referenzobjekt (fk_referenzobjekt) die gleichnamigen Datumswerte anhand Maximum und Minimum der Children an.

Wenn ...
... gebaeude_geometrie oder ...
... parzelle_geometrie ...
... in Geometrie angepasst (oder auch ein neues Objekt hinzugefügt) wird, dann passe auch den Parent referenzobjekt in polygeom an, damit es alle Geometrien der Children als ST_Multi(ST_Union vereint.

Wenn ...
... adresse_geometrie ...
... in Geometrie angepasst (oder auch ein neues Objekt hinzugefügt) wird, dann passe auch den Parent referenzobjekt in pointgeom an, damit es alle Geometrien der Children als ST_Multi(ST_Union vereint.

Wenn ...
... referenzobjekt ...
... neu erstellt wird, kann es in unserer Lösung sein, dass bereits Child Objekte bestehen (zBs. aufgrund der Transaktion: RO Form öffnen, Geom erfassen, Geom schliessen (Trans Position 1), RO schliessen (Trans Positition 2)), deshalb soll es die Geometrien und Dates der Child-Objekte finden

## Erstelle Demodaten

### Generated Data 

Erstellt einfach Random Daten irgendwo (für Lasttest evtl.)

```bash
psql -h localhost -p 54322 -U docker -d gis -f demodaten/demodaten-generated.sql
```

### Realdaten

Beispieldatensatz erhalten von Andreas in demodaten/testdaten-real-shp

Was ich gemacht habe um es zu importieren. Es gibt 3 Graphical Modelle im Projekt.

1. Fixe Dummy-Referenzobjekte erstellt für alle Typen (schreibe dummy in bezeichnung)
2. Die UUIDs in Modell statisch als FK eingetragen beim Refactor Algorithmus
3. Modelle ausgeführt
4. Script ausgeführt, um die Referenzobjekte zu erstellen anhand von Überschneidungen (für Gebäude)
    ```bash
    psql -h localhost -p 54322 -U docker -d gis -f demodaten/testdaten-real-shp/scripts/referenzobjekte_gebaeude.sql
    ```
5. Script ausgeführt, um die Referenzobjekte zu erstellen pro Adresse (auch wenn nicht optimal)
    ```bash
    psql -h localhost -p 54322 -U docker -d gis -f demodaten/testdaten-real-shp/scripts/referenzobjekte_gebaeude.sql
    ```
6. Script ausgeführt, um genau ein Referenzobjekt zu erstellen pro Parzelle und die ParzNr (die in quelle drin ist) übernommen
    ```bash
    psql -h localhost -p 54322 -U docker -d gis -f demodaten/testdaten-real-shp/scripts/referenzobjekte_parzellen.sql
    ```
7. Dummy-Referenzobjekte gelöscht
8. Da in quelle der parzelle_geometrien und in bezeichnung der referenzobjekte mapping info reingeschrieben wuren, kann das noch bereinigt werden

### Realdaten mit SQL Dump

Für erneutes erstellen, dump importieren.
```bash
psql -h localhost -p 54322 -U docker -d gis -f demodaten/testdaten-real-shp/dump/data-dump.sql
```