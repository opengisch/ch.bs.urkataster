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

import logging
import logging.handlers
import os
import pathlib

from qgis.PyQt.QtCore import QDir, QFileInfo, QObject, Qt
from qgis.PyQt.QtGui import QIcon
from qgis.PyQt.QtWidgets import QAction

from qgis.core import QgsProject, QgsMapLayer, QgsApplication

from urkataster_tools.tools.timeslider.timeslider_widget import TimesliderWidget
from urkataster_tools.tools.timeslider.feature_updater import FeatureUpdater

class UrkatasterToolsPlugin(QObject):
    def __init__(self, iface):
        QObject.__init__(self)
        self.iface = iface
        self.plugin_dir = os.path.dirname(__file__)

    def initGui(self):
        self.logger = logging.getLogger("urkatastertools")
        self.logs_directory = "{}/logs".format(pathlib.Path(__file__).parent.absolute())
        self.init_logger()

        # toolbar
        self._urkataster_toolbar = self.iface.addToolBar("Urkataster Tools")
        self._urkataster_toolbar.setObjectName("UrkatasterToolbar")
        self._urkataster_toolbar.setToolTip("Tools zur Arbeit mit dem BS Urkataster")

        # open the urkataster project
        self._open_project_action = QAction(
            QgsApplication.getThemeIcon("/mIconQgsProjectFile.svg"),
            "Öffne das Urkataster Projekt",
            None,
        )
        self._open_project_action.triggered.connect( self._reopen_project() )
        self._urkataster_toolbar.addAction(self._open_project_action)

        # timeslider widget
        self._timeslider = TimesliderWidget()
        self._feature_updater = FeatureUpdater(self.iface)
        self._timeslider_action = self._urkataster_toolbar.addWidget(self._timeslider)
        self._timeslider.trigger_update.connect(self._feature_updater.filter_layers)
        self._timeslider.trigger_clear.connect(self._feature_updater.clear_filters)

    def unload(self):
        self._urkataster_toolbar.removeAction(self._open_project_action)
        self._urkataster_toolbar.removeAction(self._timeslider_action)
        del self._open_project_action
        del self._timeslider_action
        del self._feature_updater
        del self._timeslider
        del self._urkataster_toolbar

    def init_logger(self):
        directory = QDir(self.logs_directory)
        if not directory.exists():
            directory.mkpath(self.logs_directory)

        if directory.exists():
            logfile = QFileInfo(directory, "urkataster_tools_plugin.log")

            # Handler for files rotation, create one log per day
            rotationHandler = logging.handlers.TimedRotatingFileHandler(
                logfile.filePath(), when="midnight", backupCount=10
            )

            self.logger = logging.getLogger(__name__)
            self.logger.setLevel(logging.DEBUG)

            formatter = logging.Formatter("%(asctime)s %(levelname)-7s %(message)s")
            rotationHandler.setFormatter(formatter)
            self.logger.addHandler(rotationHandler)

        self.logger.info("Starting Urkataster tools plugin version")

    def _reopen_project(self, project_file):
        QgsProject.instance().clear()
        QgsProject.instance().read(os.path.join(self.plugin_dir, "data/qgis-projects/urkataster.qgz")) 
