# -----------------------------------------------------------
#
# Urkataster Tools Plugin
# Copyright (C) 2025 david@OPENGIS.ch
#
# licensed under the terms of GNU GPL 2
#
# -----------------------------------------------------------


def classFactory(iface):
    from urkataster_tools.urkataster_tools_plugin import UrkatasterToolsPlugin

    return UrkatasterToolsPlugin(iface)
