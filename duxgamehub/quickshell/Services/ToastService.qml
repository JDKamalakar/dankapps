pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    function showInfo(msg) {
        console.log("[GameHub]", msg);
    }

    function showError(msg) {
        console.warn("[GameHub Error]", msg);
    }

    function showWarning(msg) {
        console.warn("[GameHub Warning]", msg);
    }
}
