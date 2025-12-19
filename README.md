# Urkataster Tools Plugin und QGIS Project

![urkataster-tools-image](urkataster_tools/images/urkataster-tools-icon.svg)

## Konzept

Konzept Daten, Dokumentationen und Überlegungen findest du im Ordner [concept](concept/README.md)

## Datenbank

Datenbank UML und Script zum erstellen, sowie ein Testdatendump und Shapefiles findest du in [database](database/README.md)

## Plugin

Das Plugin, das auch als ZIP gepackaged ist findest du in den Relases zum Downloaden. Der Sourcecode ist [hier](urkataster-tools/)

Das QGIS Projekt als Bestandteil des Plugins ist in  [urkataster-tools/data/qgis-project/](urkataster-tools/data/qgis-project/) abgelegt.

Tests betreffen das Plugin und werden bei Pull Requests und Releases automatisch gestartet.

## Infos for Devs

### Code style

Is enforced with pre-commit. To use, make:
```
pip install pre-commit
pre-commit install
```
And to run it over all the files (with infile changes):
```
pre-commit run --color=always --all-file
```
