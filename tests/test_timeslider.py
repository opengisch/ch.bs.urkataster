import logging
import os
import shutil
import tempfile
from unittest.mock import MagicMock

from qgis.core import QgsApplication, QgsProject
from qgis.PyQt.QtCore import QDate, Qt
from qgis.testing import start_app, unittest

from tests.utils import plugindata_path
from urkataster_tools.tools.timeslider.feature_updater import FeatureUpdater
from urkataster_tools.tools.timeslider.timeslider_widget import TimesliderWidget

start_app()


class TestTimeslider(unittest.TestCase):

    GEB_GEOM_LAYERNAME = "Grundriss (Gebäude)"
    GEB_ATTR_LAYERNAME = "Attribute (Gebäude)"
    GEB_REFO_LAYERNAME = "Referenzobjekt (Gebäude)"

    @classmethod
    def setUpClass(cls):
        """Run before all tests."""
        cls.basetestpath = tempfile.mkdtemp()

        # load project
        temp_projectpath = os.path.join(cls.basetestpath, "urkataster.qgz")
        shutil.copyfile(plugindata_path("qgis-project/urkataster.qgz"), temp_projectpath)
        QgsProject.instance().read(temp_projectpath)

        cls.the_timeslider = TimesliderWidget(None, 0)  # delay is 0 to act immediately
        cls.the_feature_updater = FeatureUpdater(MagicMock())
        cls.the_timeslider.trigger_update.connect(cls.the_feature_updater.filter_layers)
        cls.the_timeslider.trigger_clear.connect(cls.the_feature_updater.clear_filters)

    def test_gebaeude_workflow(self):

        # status quo
        geom_layer = QgsProject.instance().mapLayersByName(TestTimeslider.GEB_GEOM_LAYERNAME)[0]
        assert 53 == len(geom_layer)
        expected_query = ""
        assert geom_layer.subsetString() == expected_query
        attr_layer = QgsProject.instance().mapLayersByName(TestTimeslider.GEB_ATTR_LAYERNAME)[0]
        assert 46 == len(attr_layer)
        expected_query = ""
        assert attr_layer.subsetString() == expected_query
        refo_layer = QgsProject.instance().mapLayersByName(TestTimeslider.GEB_REFO_LAYERNAME)[0]
        assert 46 == len(refo_layer)
        expected_query = "(art = 'gebaeude')"
        assert refo_layer.subsetString() == expected_query

        self.the_timeslider.nur_gesichert_checkbox.setCheckState(Qt.CheckState.Checked)
        self.the_timeslider.slider.setUpperValue(15000)
        assert self.the_timeslider.to_date_edit.date() == QDate(1641, 1, 25)

        QgsApplication.processEvents()
        geom_layer = QgsProject.instance().mapLayersByName(TestTimeslider.GEB_GEOM_LAYERNAME)[0]
        assert 1 == len(geom_layer)
        expected_query = "(gesichert_ab IS NULL OR gesichert_ab <= '1641-01-25') AND (gesichert_bis IS NULL OR '1600-01-01' <= gesichert_bis)"
        assert geom_layer.subsetString() == expected_query
        attr_layer = QgsProject.instance().mapLayersByName(TestTimeslider.GEB_ATTR_LAYERNAME)[0]
        assert 0 == len(attr_layer)
        expected_query = "(gesichert_ab IS NULL OR gesichert_ab <= '1641-01-25') AND (gesichert_bis IS NULL OR '1600-01-01' <= gesichert_bis)"
        assert attr_layer.subsetString() == expected_query
        refo_layer = QgsProject.instance().mapLayersByName(TestTimeslider.GEB_REFO_LAYERNAME)[0]
        assert 1 == len(refo_layer)
        expected_query = "(gesichert_ab IS NULL OR gesichert_ab <= '1641-01-25') AND (gesichert_bis IS NULL OR '1600-01-01' <= gesichert_bis) AND (art = 'gebaeude')"
        assert refo_layer.subsetString() == expected_query

        self.the_timeslider.to_date_edit.setDate(QDate(1775, 11, 11))
        self.the_timeslider.from_date_edit.setDate(QDate(1696, 6, 6))
        assert self.the_timeslider.slider.lowerValue() == 35221
        assert self.the_timeslider.slider.upperValue() == 64232

        QgsApplication.processEvents()
        geom_layer = QgsProject.instance().mapLayersByName(TestTimeslider.GEB_GEOM_LAYERNAME)[0]
        assert 4 == len(geom_layer)
        expected_query = "(gesichert_ab IS NULL OR gesichert_ab <= '1775-11-11') AND (gesichert_bis IS NULL OR '1696-06-06' <= gesichert_bis)"
        assert geom_layer.subsetString() == expected_query
        attr_layer = QgsProject.instance().mapLayersByName(TestTimeslider.GEB_ATTR_LAYERNAME)[0]
        assert 0 == len(attr_layer)
        expected_query = "(gesichert_ab IS NULL OR gesichert_ab <= '1775-11-11') AND (gesichert_bis IS NULL OR '1696-06-06' <= gesichert_bis)"
        assert attr_layer.subsetString() == expected_query
        refo_layer = QgsProject.instance().mapLayersByName(TestTimeslider.GEB_REFO_LAYERNAME)[0]
        assert 2 == len(refo_layer)
        expected_query = "(gesichert_ab IS NULL OR gesichert_ab <= '1775-11-11') AND (gesichert_bis IS NULL OR '1696-06-06' <= gesichert_bis) AND (art = 'gebaeude')"
        assert refo_layer.subsetString() == expected_query

        self.the_timeslider.to_date_edit.setDate(QDate(1983, 9, 27))
        self.the_timeslider.from_date_edit.setDate(QDate(1983, 9, 27))
        assert self.the_timeslider.slider.lowerValue() == 140157
        assert self.the_timeslider.slider.upperValue() == 140157

        QgsApplication.processEvents()
        geom_layer = QgsProject.instance().mapLayersByName(TestTimeslider.GEB_GEOM_LAYERNAME)[0]
        assert 35 == len(geom_layer)
        expected_query = "(gesichert_ab IS NULL OR gesichert_ab <= '1983-09-27') AND (gesichert_bis IS NULL OR '1983-09-27' <= gesichert_bis)"
        assert geom_layer.subsetString() == expected_query
        attr_layer = QgsProject.instance().mapLayersByName(TestTimeslider.GEB_ATTR_LAYERNAME)[0]
        assert 33 == len(attr_layer)
        expected_query = "(gesichert_ab IS NULL OR gesichert_ab <= '1983-09-27') AND (gesichert_bis IS NULL OR '1983-09-27' <= gesichert_bis)"
        assert attr_layer.subsetString() == expected_query
        refo_layer = QgsProject.instance().mapLayersByName(TestTimeslider.GEB_REFO_LAYERNAME)[0]
        assert 35 == len(refo_layer)
        expected_query = "(gesichert_ab IS NULL OR gesichert_ab <= '1983-09-27') AND (gesichert_bis IS NULL OR '1983-09-27' <= gesichert_bis) AND (art = 'gebaeude')"
        assert refo_layer.subsetString() == expected_query

        self.the_timeslider.nur_gesichert_checkbox.setCheckState(Qt.CheckState.Unchecked)

        QgsApplication.processEvents()
        geom_layer = QgsProject.instance().mapLayersByName(TestTimeslider.GEB_GEOM_LAYERNAME)[0]
        assert 52 == len(geom_layer)
        expected_query = "(vermutlich_ab IS NULL OR vermutlich_ab <= '1983-09-27') AND (vermutlich_bis IS NULL OR '1983-09-27' <= vermutlich_bis)"
        assert geom_layer.subsetString() == expected_query
        attr_layer = QgsProject.instance().mapLayersByName(TestTimeslider.GEB_ATTR_LAYERNAME)[0]
        assert 46 == len(attr_layer)
        expected_query = "(vermutlich_ab IS NULL OR vermutlich_ab <= '1983-09-27') AND (vermutlich_bis IS NULL OR '1983-09-27' <= vermutlich_bis)"
        assert attr_layer.subsetString() == expected_query
        refo_layer = QgsProject.instance().mapLayersByName(TestTimeslider.GEB_REFO_LAYERNAME)[0]
        assert 45 == len(refo_layer)
        expected_query = "(vermutlich_ab IS NULL OR vermutlich_ab <= '1983-09-27') AND (vermutlich_bis IS NULL OR '1983-09-27' <= vermutlich_bis) AND (art = 'gebaeude')"
        assert refo_layer.subsetString() == expected_query

    def log_function(self, text, progress, silent=False):
        self.print_info(text)

    def print_info(self, text):
        print(text)

    def print_error(self, text):
        logging.error(text)

    @classmethod
    def tearDownClass(cls):
        QgsProject.instance().clear()
        """Run after all tests."""
        shutil.rmtree(cls.basetestpath, True)
