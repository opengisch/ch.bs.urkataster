"""
Metadata:
    Urkataster Tools Plugin
    Creation Date: 2025-12-01
    Copyright: (C) 2025 by OPENGIS.ch
    Contact: info@opengis.ch

License:
    This program is free software; you can redistribute it and/or modify
    it under the terms of the **GNU General Public License** as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.
"""

from qgis.core import QgsMapLayer, QgsProject
from qgis.PyQt.QtCore import QDate, QObject


class FeatureUpdater(QObject):

    VERMUTLICH_AB_FIELD = "vermutlich_ab"
    VERMUTLICH_BIS_FIELD = "vermutlich_bis"
    GESICHERT_AB_FIELD = "gesichert_ab"
    GESICHERT_BIS_FIELD = "gesichert_bis"

    def __init__(self, iface):
        super().__init__()
        self.iface = iface

    def filter_layers(self, filter_from_date: QDate, filter_to_date: QDate, gesichert: bool):
        """
        Filter all vector layers in the project based on the given date and gesichert flag.

        Args:
            date (QDate): The date to filter layers by.
            gesichert (bool): If True, use gesichert fields; otherwise, use vermutlich fields.
        """
        project_layers = QgsProject.instance().mapLayers().values()

        if not next(iter(project_layers), None):
            self.iface.messageBar().pushWarning("Urkataster Tools", "Es sind keine Layer im Projekt vorhanden.")
            return

        from_field = self.GESICHERT_AB_FIELD if gesichert else self.VERMUTLICH_AB_FIELD
        to_field = self.GESICHERT_BIS_FIELD if gesichert else self.VERMUTLICH_BIS_FIELD

        filter_from_date_str = filter_from_date.toString("yyyy-MM-dd")
        filter_to_date_str = filter_to_date.toString("yyyy-MM-dd")

        for layer in project_layers:
            if layer.type() == QgsMapLayer.VectorLayer:
                if layer.isEditable():
                    self.iface.messageBar().pushWarning(
                        "Urkataster Tools",
                        "Filter können nicht angewendet werden, solange ein Layer nicht im Bearbeitungsmodus ist.",
                    )
                    return
                if layer.fields().indexFromName(from_field) != -1 and layer.fields().indexFromName(to_field) != -1:
                    self._apply_filter(layer, filter_from_date_str, filter_to_date_str, from_field, to_field)
        self.iface.mainWindow().statusBar().showMessage(
            "Urkataster Layers Filter gesetzt auf {} bis {}".format(filter_from_date_str, filter_to_date_str)
        )

    def _apply_filter(self, layer, filter_from_date_str, filter_to_date_str, from_field, to_field):
        subset_string = "({from_date} IS NULL OR {from_date} <= '{filter_to_date}') AND ({to_date} IS NULL OR '{filter_from_date}' <= {to_date})".format(
            from_date=from_field,
            to_date=to_field,
            filter_from_date=filter_from_date_str,
            filter_to_date=filter_to_date_str,
        )
        # if it's a referenzobjekt layer, we filter as well for the art (type)
        if layer.name() == "Referenzobjekt (Gebäude)":
            subset_string += " AND (art = 'gebaeude')"
        elif layer.name() == "Referenzobjekt (Parzelle)":
            subset_string += " AND (art = 'parzelle')"
        elif layer.name() == "Referenzobjekt (Adresse)":
            subset_string += " AND (art = 'adresse')"
        layer.setSubsetString(subset_string)

    def clear_filters(self):
        """
        Filter all vector layers in the project based on the given date and gesichert flag.

        Args:
            date (QDate): The date to filter layers by.
            gesichert (bool): If True, use gesichert fields; otherwise, use vermutlich fields.
        """
        project_layers = QgsProject.instance().mapLayers().values()

        if not next(iter(project_layers), None):
            self.iface.messageBar().pushWarning("Urkataster Tools", "Es sind keine Layer im Projekt vorhanden.")
            return

        for layer in project_layers:
            if layer.type() == QgsMapLayer.VectorLayer:
                if layer.isEditable():
                    self.iface.messageBar().pushWarning(
                        "Urkataster Tools",
                        "Filter können nicht entfernt werden, solange ein Layer nicht im Bearbeitungsmodus ist.",
                    )
                    return
                if layer.name() == "Referenzobjekt (Gebäude)":
                    layer.setSubsetString("(art = 'gebaeude')")
                elif layer.name() == "Referenzobjekt (Parzelle)":
                    layer.setSubsetString(" (art = 'parzelle')")
                elif layer.name() == "Referenzobjekt (Adresse)":
                    layer.setSubsetString(" (art = 'adresse')")
                else:
                    layer.setSubsetString("")
        self.iface.mainWindow().statusBar().showMessage("Urkataster Layers Filter entfernt.")
