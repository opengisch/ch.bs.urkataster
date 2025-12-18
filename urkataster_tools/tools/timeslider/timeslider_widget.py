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
from qgis.gui import QgsRangeSlider

class TimesliderWidget(QWidget):

    MIN_YEAR = 1600

    trigger_update = pyqtSignal(QDate,QDate, bool)
    trigger_clear = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)

        self.clear_button = QToolButton()
        self.clear_button.setIcon(QgsApplication.getThemeIcon("/console/iconClearConsole.svg"))

        self.nur_gesichert_checkbox = QCheckBox("Nur gesicherte Daten anzeigen")

        self.slider = QgsRangeSlider(Qt.Horizontal)
        self.start_date = QDate(self.MIN_YEAR, 1, 1)
        self.end_date = QDate.currentDate()
        self.slider.setMinimum(0)
        self.slider.setMaximum(self.start_date.daysTo(self.end_date))
        self.slider.setRange(0, self.start_date.daysTo(self.end_date))

        self.from_date_edit = QDateEdit()
        self.from_date_edit.setMinimumDate(self.start_date)
        self.from_date_edit.setCalendarPopup(True)
        self.from_date_edit.setDisplayFormat("dd. MMM yyyy")
        self.from_date_edit.setDate(self.start_date)
        self.to_date_edit = QDateEdit()
        self.to_date_edit.setMinimumDate(self.start_date)
        self.to_date_edit.setCalendarPopup(True)
        self.to_date_edit.setDisplayFormat("dd. MMM yyyy")
        self.to_date_edit.setDate(self.end_date)

        layout = QHBoxLayout(self)
        layout.addWidget(self.nur_gesichert_checkbox)
        layout.addWidget(self.from_date_edit)
        layout.addWidget(self.slider)
        layout.addWidget(self.to_date_edit)
        layout.addWidget(self.clear_button)

        self.slider.rangeChanged.connect(self._sync_dates_from_slider)
        self.from_date_edit.dateChanged.connect(self._sync_slider_from_from_date)
        self.to_date_edit.dateChanged.connect(self._sync_slider_from_to_date)

        self.scheduled_update_timer = QTimer()
        self.scheduled_update_timer.setSingleShot(True)
        self.scheduled_update_timer.timeout.connect(
            lambda: self.trigger_update.emit(self.start_date.addDays(self.slider.lowerValue()), self.start_date.addDays(self.slider.upperValue()), self.nur_gesichert_checkbox.isChecked())
        )
        self.slider.rangeChanged.connect(lambda: self.scheduled_update_timer.start(100)) # maybe needs 1000 ms delay
        self.from_date_edit.dateChanged.connect(lambda: self.scheduled_update_timer.start(100)) # maybe needs 1000 ms delay
        self.to_date_edit.dateChanged.connect(lambda: self.scheduled_update_timer.start(100)) # maybe needs 1000 ms delay
        self.nur_gesichert_checkbox.stateChanged.connect(lambda: self.scheduled_update_timer.start(100)) # maybe needs 1000 ms delay
        self.clear_button.clicked.connect(self._clear)

    def _sync_dates_from_slider(self, lower_val: int, upper_val: int)-> None:
        new_date = self.start_date.addDays(lower_val)
        if self.from_date_edit.date() != new_date:
            self.from_date_edit.blockSignals(True)
            self.from_date_edit.setDate(new_date)
            self.from_date_edit.blockSignals(False)
        new_date = self.start_date.addDays(upper_val)
        if self.to_date_edit.date() != new_date:
            self.to_date_edit.blockSignals(True)
            self.to_date_edit.setDate(new_date)
            self.to_date_edit.blockSignals(False)

    def _sync_slider_from_from_date(self, date: QDate)-> None:
        days = self.start_date.daysTo(date)
        if self.slider.lowerValue() != days:
            self.slider.blockSignals(True)
            self.slider.setLowerValue(days)
            self.slider.blockSignals(False)

    def _sync_slider_from_to_date(self, date: QDate)-> None:
        days = self.start_date.daysTo(date)
        if self.slider.upperValue() != days:
            self.slider.blockSignals(True)
            self.slider.setUpperValue(days)
            self.slider.blockSignals(False)

    def _clear(self)-> None:
        # reset values
        self.from_date_edit.blockSignals(True)
        self.to_date_edit.blockSignals(True)
        self.slider.blockSignals(True)
        self.slider.setLowerValue(0)
        self.slider.setUpperValue(self.start_date.daysTo(self.end_date))
        self.from_date_edit.setDate(self.start_date)
        self.to_date_edit.setDate(self.end_date)
        self.from_date_edit.blockSignals(False)
        self.to_date_edit.blockSignals(False)
        self.slider.blockSignals(False)
        # emit clear signal
        self.trigger_clear.emit()