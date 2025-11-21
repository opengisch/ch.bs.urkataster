# ch.bs.urkataster

## Datenmodell 

### Änderung der Kardinalität

Die Kardinalität ist im ERM des Konzepts zwischen den Geometrie- oder auch Attributobjekten zu Referenzobjekte ist 0..1 zu 1, währenddem in der Studie einerseits eine 1 zu n Beziehung beschrieben ist (6.4.1). Dies ist wird ebenso mit den Lebenszyklen impliziert (6.3.3) Bei Gebäude und auch Adressen "Solange sich die Lage der Adresse auf denselben Gebäudeeingang bezieht und sich nur geringfügig verändert, sollte das Referenzobjekt bestehen bleiben." Denn da sollen ja wohl noch beide Punkte erfasst bleiben. Bei Parzellen hingegen würde eine 1 zu 1 Beziehung funktionieren, da immer ein neues Referenzobjekt erstellt wird bei einer Änderung der Geometrie.

### Datenquellen (Raster)

Im Kickoff wurde entschieden, dass die Datenquellen (Raster) nicht im Urkataster abgespeichert werden und schon gar nicht die Geometrien davon abhängig sein sollen.

Vorgschlagen wird, dass dennoch optional Infos zu Quellen hinzugefügt werden können.

Heisst eine n zu n Beziehung zwischen Geometrie, wobei das zu einer Komplexität führt, die vermieden werden kann (zBs. beim Löschen einer Geometrie). Folglich würden wir Vorschlagen eine folgende Beziehung zu bauen:
```mermaid
erDiagram

direction LR
    geometrie {
        int id PK
        geometry geometrie
        int fk_referenzobjekt FK
        string genauigkeit
        date vermutlich_ab
        date gesichert_ab
        var etc
    }

    quelldaten {
        int id PK
        int fk_geometrie FK
        string name
        string beschreibung
        string pfad
        var etc
    }

    geometrie ||--o{ quelldaten : ""
```

## Workflows

### Plugin Workflow

#### 1. Starte mit Referenzobjekt

Erstellen des Referenzobjekts oder auch Aufbau auf einem bestehenden:

```mermaid
flowchart TD
    classDef objekt fill:#fff3e0,stroke:#01579b,stroke-width:2px,color:#000;
    classDef optional stroke-dasharray: 5 5;

    RoCreate("Erstellen eines Referenzobjekts"):::optional 
    --> RoDate("Setzen der Gültigkeitsdaten<br>(für das Referenzobjekt)"):::optional
    --> RO[Referenzobjekt]:::objekt 
    --> GeomAdd("Hinzufügen einer Geometrie<br>(für das Gebäude)")
    --> GeomDate("Setzen der Gültigkeitsdaten<br>(für die Geometrie)")
    --> Geometrie[Geometrie]:::objekt
    RO --> AttrCreate("Hinzufügen von Attributen<br>(Gebäudeattribute)")
    --> AttrDate("Hinzufügen von Gültigkeitsdaten<br>(für die Attribute)")
    --> Attribute[Gebäudeattribute]:::objekt
```

#### 2. Starte mit Geometrie

Erstellen einer Geometrie:

```mermaid
flowchart TD
    classDef objekt fill:#fff3e0,stroke:#01579b,stroke-width:2px,color:#000;
    classDef optional stroke-dasharray: 5 5;

    GeomAdd("Erstellen einer Geometrie<br>(für das Gebäude)")
    --> GeomDate("Setzen der Gültigkeitsdaten<br>(für die Geometrie)")
    --> Geometrie[Geometrie]:::objekt
    --> RoCreate("Erstellen eines Referenzobjekts)")
    --> RoDate("Setzen der Gültigkeitsdaten<br>(für das Referenzobjekt)"):::optional
    --> RO[Referenzobjekt]:::objekt 
    Geometrie --> RoSelect("Auswählen eines bestehenden Referenzobjekts)")
    --> RO
```

Weiter bei Bedarf bei 1.