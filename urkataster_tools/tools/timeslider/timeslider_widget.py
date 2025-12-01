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
from qgis.PyQt.QtCore import Qt, QTimer, QDate, pyqtSignal
from qgis.PyQt.QtWidgets import QCheckBox, QWidget, QToolButton, QSlider, QHBoxLayout, QLabel, QDateEdit
from qgis.core import QgsProject, QgsMapLayer, QgsApplication

class TimesliderWidget(QWidget):

    trigger_update = pyqtSignal(QDate, bool)
    trigger_clear = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)


        self.clear_button = QToolButton()
        self.clear_button.setIcon(QgsApplication.getThemeIcon("/console/iconClearConsole.svg"))

        self.nur_gesichert_checkbox = QCheckBox("Nur gesicherte Daten anzeigen")

        self.slider = QSlider(Qt.Horizontal)
        self.start_date = QDate(1600, 1, 1)
        self.end_date = QDate.currentDate()
        self.slider.setRange(0, self.start_date.daysTo(self.end_date))

        self.date_edit = QDateEdit()
        self.date_edit.setMinimumDate(QDate(1600, 1, 1))
        self.date_edit.setCalendarPopup(True)
        self.date_edit.setDisplayFormat("dd. MMM yyyy")
        self.date_edit.setDate(QDate.currentDate())

        layout = QHBoxLayout(self)
        layout.addWidget(self.nur_gesichert_checkbox)
        layout.addWidget(self.slider)
        layout.addWidget(self.date_edit)
        layout.addWidget(self.clear_button)

        self.slider.valueChanged.connect(self._sync_date_from_slider)
        self.date_edit.dateChanged.connect(self._sync_slider_from_date)

        self.scheduled_update_timer = QTimer()
        self.scheduled_update_timer.setSingleShot(True)
        self.scheduled_update_timer.timeout.connect(
            lambda: self.trigger_update.emit(self.start_date.addDays(self.slider.value()), self.nur_gesichert_checkbox.isChecked())
        )
        self.slider.valueChanged.connect(lambda: self.scheduled_update_timer.start(100)) # maybe needs 1000 ms delay
        self.date_edit.dateChanged.connect(lambda: self.scheduled_update_timer.start(100)) # maybe needs 1000 ms delay
        self.nur_gesichert_checkbox.stateChanged.connect(lambda: self.scheduled_update_timer.start(100)) # maybe needs 1000 ms delay
        self.clear_button.clicked.connect(self._clear)

    def _sync_date_from_slider(self, val: int)-> None:
        new_date = self.start_date.addDays(val)
        if self.date_edit.date() != new_date:
            self.date_edit.blockSignals(True)
            self.date_edit.setDate(new_date)
            self.date_edit.blockSignals(False)

    def _sync_slider_from_date(self, date: QDate)-> None:
        days = self.start_date.daysTo(date)
        if self.slider.value() != days:
            self.slider.blockSignals(True)
            self.slider.setValue(days)
            self.slider.blockSignals(False)

    def _clear(self)-> None:
        # reset values
        self.date_edit.blockSignals(True)
        self.slider.blockSignals(True)
        self.slider.setValue(0)
        self.date_edit.setDate(self.start_date)
        self.date_edit.blockSignals(False)
        self.slider.blockSignals(False)
        # emit clear signal
        self.trigger_clear.emit()