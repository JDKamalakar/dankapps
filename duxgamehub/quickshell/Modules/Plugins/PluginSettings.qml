import QtQuick

Flickable {
    property var pluginService: null
    property string pluginId: ""
    property var defaultSettings: ({})

    contentWidth: width
    contentHeight: contentItem.childrenRect.height
    interactive: true
    clip: true
}
