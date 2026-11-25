pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    signal pluginDataChanged(string pluginId, string key)

    property bool settingsOpen: false
    property var _store: ({})
    readonly property string _storePath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/duxgamehub/plugin_data.json"

    FileView {
        id: storeFile
        path: root._storePath
        blockLoading: true
        onLoaded: {
            try {
                const parsed = JSON.parse(text() || "{}");
                if (parsed && typeof parsed === "object")
                    root._store = parsed;
            } catch (e) {
                root._store = {};
            }
        }
    }

    function loadPluginData(pluginId, key, defVal) {
        const p = _store[pluginId];
        if (p && p.hasOwnProperty(key))
            return p[key];
        return defVal;
    }

    function savePluginData(pluginId, key, val) {
        const next = Object.assign({}, _store);
        if (!next[pluginId])
            next[pluginId] = {};
        else
            next[pluginId] = Object.assign({}, next[pluginId]);
        next[pluginId][key] = val;
        _store = next;
        storeFile.setText(JSON.stringify(_store, null, 2));
        pluginDataChanged(pluginId, key);
    }

    function setGlobalVar(pluginId, key, val) {
        savePluginData(pluginId, key, val);
    }

    function getPluginPath(pluginId) {
        const url = Qt.resolvedUrl("../Modules/GameHub").toString();
        return url.startsWith("file://") ? url.substring(7) : url;
    }
}
