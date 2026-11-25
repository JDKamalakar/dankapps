import QtQuick
import Quickshell
import qs.Common

FloatingWindow {
    id: win
    property alias windowWidth: win.implicitWidth
    property alias windowHeight: win.implicitHeight
    implicitWidth: 1200
    implicitHeight: 780
    color: Theme.windowSurface
}
