import logging
import os
import shutil
import tempfile
import xml.etree.ElementTree as ET

from lksob_perimeter_manager.core.feature_toolbox import FeatureToolbox
from lksob_perimeter_manager.core.project_toolbox import ProjectToolbox
from lksob_perimeter_manager.core.schema_toolbox import SchemaPorter
from lksob_perimeter_manager.utils import utils
from qgis.core import QgsDataSourceUri, QgsProject
from qgis.testing import start_app, unittest

from tests.utils import count_entries, plugindata_path, testdata_path

start_app()


class TestAbwasser(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        """Run before all tests."""
        cls.basetestpath = tempfile.mkdtemp()

        # load project
        temp_projectpath = os.path.join(cls.basetestpath, "lksob_abwasser.qgz")
        shutil.copyfile(plugindata_path("qgis-projects/lksob_abwasser.qgz"), temp_projectpath)
        QgsProject.instance().read(temp_projectpath)

    def test_whole_workflow(self):

        # 0 get the perimeter
        perimeter_name = "Perimeter Bächliweg"
        perimeter_layer = QgsProject.instance().mapLayersByName(utils.PERIMETER_LAYER_NAME)[0]
        assert perimeter_layer.isValid()

        list(perimeter_layer.getFeatures())
        feature_toolbox = FeatureToolbox(QgsProject.instance(), perimeter_name, self.log_function)
        assert feature_toolbox.is_valid

        assert 10 == len(QgsProject.instance().mapLayersByName("Normschacht")[0])
        assert 1 == len(QgsProject.instance().mapLayersByName("Einleitstelle")[0])
        assert 14 == len(QgsProject.instance().mapLayersByName("Deckel")[0])
        assert 1 == len(QgsProject.instance().mapLayersByName("Versickerungsanlage")[0])
        assert 2 == len(QgsProject.instance().mapLayersByName("Spezialbauwerk")[0])
        assert 10 == len(QgsProject.instance().mapLayersByName("Kanal")[0])
        assert 11 == len(QgsProject.instance().mapLayersByName("Abwasserknoten")[0])
        assert 1 == len(QgsProject.instance().mapLayersByName("Virtueller Abwasserknoten")[0])
        assert 17 == len(QgsProject.instance().mapLayersByName("Haltungspunkt")[0])
        assert 8 == len(QgsProject.instance().mapLayersByName("Haltung")[0])
        assert 2 == len(QgsProject.instance().mapLayersByName("Rohrprofil")[0])
        assert 77 == len(QgsProject.instance().mapLayersByName("Metaattribute")[0])
        assert 0 == len(QgsProject.instance().mapLayersByName("SOB_Perimeter_BaseClass")[0])

        # 1 select intersected
        """
            Linking usecases:
            Haltungspunkt c1f496e9-651a-11ef-964f-005056bd189f ist Startpunkt von Haltung 1f28c00b-653b-11ef-964f-005056bd189f und Haltungspunkt 74a6fecc-6519-11ef-964f-005056bd189f ist Endpunkt. Startpunkt liegt ausserhalb des Perimeter-Polygons
            -> Make sure, dass Haltungspunkt c1f496e9-651a-11ef-964f-005056bd189f zuerst nicht selektiert ist, später aber gelinkt/unlinkt wird!
            Spezialbauwerk 70aaacdb-11e1-447c-939a-77d1788793a7 ist ausserhalb, Deckel db7efe9a-5c33-4b64-ade7-70079235678b gehört zu ihm und ist innerhalb
            -> Make sure, dass Spezialbauwerk 70aaacdb-11e1-447c-939a-77d1788793a7 zuerst nicht selektiert ist, später aber gelinkt/unlinkt wird!
            Vergleiche mit Spezialbauwerk im Perimeter-Polygon 81a3c579-58c8-4fbf-af78-ef36fe73e388
        """
        feature_toolbox.select_intersected()

        assert 7 == len(QgsProject.instance().mapLayersByName("Normschacht")[0].selectedFeatures())
        assert 1 == len(QgsProject.instance().mapLayersByName("Einleitstelle")[0].selectedFeatures())
        assert 10 == len(QgsProject.instance().mapLayersByName("Deckel")[0].selectedFeatures())
        assert 1 == len(QgsProject.instance().mapLayersByName("Versickerungsanlage")[0].selectedFeatures())
        assert 1 == len(QgsProject.instance().mapLayersByName("Spezialbauwerk")[0].selectedFeatures())
        assert 8 == len(QgsProject.instance().mapLayersByName("Kanal")[0].selectedFeatures())
        assert 8 == len(QgsProject.instance().mapLayersByName("Abwasserknoten")[0].selectedFeatures())
        assert 1 == len(QgsProject.instance().mapLayersByName("Virtueller Abwasserknoten")[0].selectedFeatures())
        assert 11 == len(QgsProject.instance().mapLayersByName("Haltungspunkt")[0].selectedFeatures())
        assert 6 == len(QgsProject.instance().mapLayersByName("Haltung")[0].selectedFeatures())
        assert 0 == len(QgsProject.instance().mapLayersByName("Rohrprofil")[0].selectedFeatures())

        # Haltungspunkt check
        layer = QgsProject.instance().mapLayersByName("Haltungspunkt")[0]
        # 74a6fecc-6519-11ef-964f-005056bd189f is selected (innerhalb)
        feature = list(layer.getFeatures("\"t_ili_tid\" = '74a6fecc-6519-11ef-964f-005056bd189f'"))[0]
        assert feature in layer.selectedFeatures()
        # c1f496e9-651a-11ef-964f-005056bd189f is not selected (ausserhalb aber abhängig)
        feature = list(layer.getFeatures("\"t_ili_tid\" = 'c1f496e9-651a-11ef-964f-005056bd189f'"))[0]
        assert feature not in layer.selectedFeatures()

        # Spezialbauwerk check
        layer = QgsProject.instance().mapLayersByName("Spezialbauwerk")[0]
        # 81a3c579-58c8-4fbf-af78-ef36fe73e388 is selected (innerhalb)
        feature = list(layer.getFeatures("\"t_ili_tid\" = '81a3c579-58c8-4fbf-af78-ef36fe73e388'"))[0]
        assert feature in layer.selectedFeatures()
        # 70aaacdb-11e1-447c-939a-77d1788793a7 is not selected (ausserhalb aber abhängig)
        feature = list(layer.getFeatures("\"t_ili_tid\" = '70aaacdb-11e1-447c-939a-77d1788793a7'"))[0]
        assert feature not in layer.selectedFeatures()

        # 2 link selected - insb. dependenciies
        feature_toolbox.join_selected()

        # check number of joined features according to the linking table
        linking_layer = QgsProject.instance().mapLayersByName("SOB_Perimeter_BaseClass")[0]
        assert 66 == len(linking_layer)
        # those are 5 more than selected:
        # 2 x Rohrprofil (where all are joined)
        # 2 x Additional Haltungspunkt - check one of them again below...
        # 1 x Additional Spezialbauwerk - check one of them again below...

        # Haltungspunkt check
        layer = QgsProject.instance().mapLayersByName("Haltungspunkt")[0]
        # 74a6fecc-6519-11ef-964f-005056bd189f is linked (innerhalb)
        feature = list(layer.getFeatures("\"t_ili_tid\" = '74a6fecc-6519-11ef-964f-005056bd189f'"))[0]
        links = list(linking_layer.getFeatures(f"\"baseclassref_haltungspunkt\" = '{feature.attribute('t_id')}'"))
        assert len(links) > 0

        # c1f496e9-651a-11ef-964f-005056bd189f is linked as well (ausserhalb aber abhängig)
        feature = list(layer.getFeatures("\"t_ili_tid\" = 'c1f496e9-651a-11ef-964f-005056bd189f'"))[0]
        links = list(linking_layer.getFeatures(f"\"baseclassref_haltungspunkt\" = '{feature.attribute('t_id')}'"))
        assert len(links) > 0

        # Spezialbauwerk check
        layer = QgsProject.instance().mapLayersByName("Spezialbauwerk")[0]
        # 81a3c579-58c8-4fbf-af78-ef36fe73e388 is linked (innerhalb)
        feature = list(layer.getFeatures("\"t_ili_tid\" = '81a3c579-58c8-4fbf-af78-ef36fe73e388'"))[0]
        links = list(linking_layer.getFeatures(f"\"baseclassref_spezialbauwerk\" = '{feature.attribute('t_id')}'"))
        assert len(links) > 0
        # 70aaacdb-11e1-447c-939a-77d1788793a7 is linked as well (ausserhalb aber abhängig)
        feature = list(layer.getFeatures("\"t_ili_tid\" = '70aaacdb-11e1-447c-939a-77d1788793a7'"))[0]
        links = list(linking_layer.getFeatures(f"\"baseclassref_spezialbauwerk\" = '{feature.attribute('t_id')}'"))
        assert len(links) > 0

        # 3 unlink selected
        feature_toolbox.unjoin_selected()

        # check number of joined features according to the linking table
        linking_layer = QgsProject.instance().mapLayersByName("SOB_Perimeter_BaseClass")[0]
        assert 0 == len(linking_layer)

        # ... and link again to continue
        feature_toolbox.join_selected()

        # check number of joined features according to the linking table
        linking_layer = QgsProject.instance().mapLayersByName("SOB_Perimeter_BaseClass")[0]
        assert 66 == len(linking_layer)

        # 4 recreate perimeter schema
        schema_porter = SchemaPorter(perimeter_layer.dataProvider(), perimeter_name, self.log_function)
        assert schema_porter.recreate_schema()
        assert schema_porter.main_to_perimeter()

        # 5 create and open perimeter project
        project_toolbox = ProjectToolbox(QgsProject.instance(), self.log_function)

        project_toolbox.create_perimeter_project(schema_porter.perimeter_schema_name, perimeter_name)

        number_of_layers = 0
        for layer in QgsProject.instance().mapLayers().values():
            assert (
                "p_lksob_abwasser_perimeter_ba_chliweg"
                == QgsDataSourceUri(layer.dataProvider().dataSourceUri()).schema()
            )
            number_of_layers += 1

        assert 46 == number_of_layers

        assert 9 == len(QgsProject.instance().mapLayersByName("Normschacht")[0])
        assert 1 == len(QgsProject.instance().mapLayersByName("Einleitstelle")[0])
        assert 13 == len(QgsProject.instance().mapLayersByName("Deckel")[0])
        assert 1 == len(QgsProject.instance().mapLayersByName("Versickerungsanlage")[0])
        assert 2 == len(QgsProject.instance().mapLayersByName("Spezialbauwerk")[0])
        assert 8 == len(QgsProject.instance().mapLayersByName("Kanal")[0])
        assert 10 == len(QgsProject.instance().mapLayersByName("Abwasserknoten")[0])
        assert 1 == len(QgsProject.instance().mapLayersByName("Virtueller Abwasserknoten")[0])
        assert 13 == len(QgsProject.instance().mapLayersByName("Haltungspunkt")[0])
        assert 6 == len(QgsProject.instance().mapLayersByName("Haltung")[0])
        assert 2 == len(QgsProject.instance().mapLayersByName("Rohrprofil")[0])
        assert 66 == len(QgsProject.instance().mapLayersByName("Metaattribute")[0])
        assert 66 == len(QgsProject.instance().mapLayersByName("SOB_Perimeter_BaseClass")[0])

        # needs to re-init the SchemaPorter
        perimeter_layer = QgsProject.instance().mapLayersByName(utils.PERIMETER_LAYER_NAME)[0]
        assert perimeter_layer.isValid()
        schema_porter = SchemaPorter(perimeter_layer.dataProvider(), perimeter_name, self.log_function)

        # 6 export data to xtf (compare with file)
        export_path = os.path.join(self.basetestpath, "tmp_lksob_abwasser_export.xtf")
        assert schema_porter.export_data(export_path, schema_porter.schema_name, "Baseset")

        # export compare not yet implemented (not super critical)
        # assert self._compare_dicts(self._xml_to_dict(testdata_path("xtf/abwasser_export.xtf")), self._xml_to_dict(export_path))

        # 6.5 lkmap export
        lkmap_export_path = os.path.join(self.basetestpath, "tmp_lkmap_abwasser_export.xtf")
        assert schema_porter.recreate_lkmap_schema()
        assert schema_porter.perimeter_to_lkmap()

        # 9 Normschacht + 1 Einleitstelle + 13 Deckel = 23 lkpunkt
        assert 23 == count_entries(schema_porter.lkmap_schema_name, "lkpunkt")
        # 6 Haltung = 6 lklinie
        assert 6 == count_entries(schema_porter.lkmap_schema_name, "lklinie")
        # 1 Versickerungsanlage + 2 Spezialbauwerk = 3 lkflaeche
        assert 3 == count_entries(schema_porter.lkmap_schema_name, "lkflaeche")
        # summe
        assert 32 == count_entries(schema_porter.lkmap_schema_name, "metaattribute")

        assert schema_porter.export_data(lkmap_export_path, schema_porter.lkmap_schema_name, "Baseset", True)

        # LK ZH Perimeter export
        assert schema_porter.lkmap_to_lkzhperimeter()
        lkmap_lkzh_perimeter_export_path = os.path.join(
            self.basetestpath, "tmp_lkmap_abwasser_export_lkzhperimeter.xtf"
        )
        assert schema_porter.export_data(
            lkmap_lkzh_perimeter_export_path, schema_porter.lkmap_schema_name, "LKZHPerimeter", True
        )

        # 7 import different data from xtf
        import_path = testdata_path("xtf/abwasser_import.xtf")
        assert schema_porter.import_data(import_path, schema_porter.schema_name, "Baseset", replace=True)

        QgsProject.instance().read(os.path.join(self.basetestpath, "p_lksob_abwasser_perimeter_ba_chliweg.qgz"))

        # project still exists - get number of features
        assert 7 == len(QgsProject.instance().mapLayersByName("Normschacht")[0])
        assert 1 == len(QgsProject.instance().mapLayersByName("Einleitstelle")[0])
        assert 10 == len(QgsProject.instance().mapLayersByName("Deckel")[0])
        assert 2 == len(QgsProject.instance().mapLayersByName("Versickerungsanlage")[0])
        assert 1 == len(QgsProject.instance().mapLayersByName("Spezialbauwerk")[0])
        assert 6 == len(QgsProject.instance().mapLayersByName("Kanal")[0])
        assert 8 == len(QgsProject.instance().mapLayersByName("Abwasserknoten")[0])
        assert 1 == len(QgsProject.instance().mapLayersByName("Virtueller Abwasserknoten")[0])
        assert 9 == len(QgsProject.instance().mapLayersByName("Haltungspunkt")[0])
        assert 4 == len(QgsProject.instance().mapLayersByName("Haltung")[0])
        assert 2 == len(QgsProject.instance().mapLayersByName("Rohrprofil")[0])
        assert 51 == len(QgsProject.instance().mapLayersByName("Metaattribute")[0])
        # here not every feature is linked, but in the perimeter schema the perimeter is not important. important is, that those features are linked in the main schema.
        assert 50 == len(QgsProject.instance().mapLayersByName("SOB_Perimeter_BaseClass")[0])

        # needs to re-init the SchemaPorter
        perimeter_layer = QgsProject.instance().mapLayersByName(utils.PERIMETER_LAYER_NAME)[0]
        assert perimeter_layer.isValid()
        schema_porter = SchemaPorter(perimeter_layer.dataProvider(), perimeter_name, self.log_function)

        # 8 migrate data to main schema
        assert schema_porter.perimeter_to_main()
        project_toolbox.open_main_project(schema_porter.schema_name, perimeter_name)

        # needs to re-init the SchemaPorter
        perimeter_layer = QgsProject.instance().mapLayersByName(utils.PERIMETER_LAYER_NAME)[0]
        assert perimeter_layer.isValid()
        schema_porter = SchemaPorter(perimeter_layer.dataProvider(), perimeter_name, self.log_function)

        number_of_layers = 0
        for layer in QgsProject.instance().mapLayers().values():
            if QgsDataSourceUri(layer.dataProvider().dataSourceUri()).schema() == "":
                assert layer.name() == "Landeskarte 1:10000"
                continue
            assert "lksob_abwasser" == QgsDataSourceUri(layer.dataProvider().dataSourceUri()).schema()
            number_of_layers += 1

        assert 45 == number_of_layers

        assert 8 == len(QgsProject.instance().mapLayersByName("Normschacht")[0])
        assert 1 == len(QgsProject.instance().mapLayersByName("Einleitstelle")[0])
        assert 11 == len(QgsProject.instance().mapLayersByName("Deckel")[0])
        assert 2 == len(QgsProject.instance().mapLayersByName("Versickerungsanlage")[0])
        assert 1 == len(QgsProject.instance().mapLayersByName("Spezialbauwerk")[0])
        assert 8 == len(QgsProject.instance().mapLayersByName("Kanal")[0])
        assert 9 == len(QgsProject.instance().mapLayersByName("Abwasserknoten")[0])
        assert 1 == len(QgsProject.instance().mapLayersByName("Virtueller Abwasserknoten")[0])
        assert 13 == len(QgsProject.instance().mapLayersByName("Haltungspunkt")[0])
        assert 6 == len(QgsProject.instance().mapLayersByName("Haltung")[0])
        assert 2 == len(QgsProject.instance().mapLayersByName("Rohrprofil")[0])
        assert 62 == len(QgsProject.instance().mapLayersByName("Metaattribute")[0])
        # new features are in the perimeter as well
        assert 51 == len(QgsProject.instance().mapLayersByName("SOB_Perimeter_BaseClass")[0])

    def _xml_to_dict(self, file_path):
        tree = ET.parse(file_path)
        root = tree.getroot()

        def recurse(element):
            return {element.tag: {child.tag: recurse(child) for child in element} or element.text}

        return recurse(root)

    def _compare_dicts(self, dict1, dict2):
        if dict1.keys() != dict2.keys():
            return False

        for key in dict1.keys():
            if isinstance(dict1[key], dict) and isinstance(dict2[key], dict):
                if not self._compare_dicts(dict1[key], dict2[key]):
                    return False
            elif dict1[key] != dict2[key]:
                return False

        return True

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
