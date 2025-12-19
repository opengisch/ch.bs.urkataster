import os

import psycopg2
import psycopg2.extras
import pytest


@pytest.mark.skip("This is a utility function, not a test function")
def testdata_path(path):
    basepath = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(basepath, "testdata", path)


@pytest.mark.skip("This is a utility function, not a test function")
def plugindata_path(path):
    basepath = os.path.dirname(os.path.abspath(__file__))
    pluginpath = os.path.join(basepath, os.pardir, "urkataster_tools")
    return os.path.join(pluginpath, "data", path)


@pytest.mark.skip("This is a utility function, not a test function")
def count_entries(schema, table):
    count = 0
    try:
        conn = psycopg2.connect(service="urkataster")
        cursor = conn.cursor()
        query = f"SELECT COUNT(*) FROM {schema}.{table};"
        cursor.execute(query)
        count = cursor.fetchone()[0]
        cursor.close()
        conn.close()
    except psycopg2.Error as err:
        print(err)
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
    return count
