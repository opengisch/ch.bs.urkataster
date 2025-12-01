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

        # timeslider toolbar
        self._timeslider_toolbar = self.iface.addToolBar(self.tr("Urkataster Timeslider"))
        self._timeslider_toolbar.setObjectName("UrkatasterTimesliderToolbar")
        self._timeslider_toolbar.setToolTip(self.tr("Urkataster Timeslider"))

        # timeslider widget
        self._timeslider = TimesliderWidget()
        self._feature_updater = FeatureUpdater(self.iface)
        self._timeslider_action = self._timeslider_toolbar.addWidget(self._timeslider)
        self._timeslider_action.setToolTip(self.tr("Urkataster Timeslider"))
        self._timeslider.trigger_update.connect(self._feature_updater.filter_layers)
        self._timeslider.trigger_clear.connect(self._feature_updater.clear_filters)

    def unload(self):
        
        self._timeslider_toolbar.removeAction(self._timeslider_action)
        del self._timeslider_action
        del self._feature_updater
        del self._timeslider
        del self._timeslider_toolbar

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
