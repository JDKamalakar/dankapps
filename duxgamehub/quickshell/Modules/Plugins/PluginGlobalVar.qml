import QtQuick

QtObject {
    property string pluginId: ""
    property string varName: ""
    property var defaultValue: undefined
    property var value: defaultValue

    signal valueUpdated(var val)
}
