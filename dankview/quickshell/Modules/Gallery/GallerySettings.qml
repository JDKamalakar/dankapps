import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets

FocusScope {
    id: root

    property bool opened: false
    signal closed()

    function open() {
        ImageService.settingsOpen = true
    }

    function close() {
        ImageService.settingsOpen = false
        closed()
    }

    readonly property bool active: opened || surface.opacity > 0
    visible: active

    anchors.fill: parent
    focus: true

    Keys.onEscapePressed: root.close()

    onOpenedChanged: {
        if (opened) {
            forceActiveFocus()
        }
    }

    // Modal Scrim
    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Style.scrimColor
        opacity: root.opened ? Style.scrimAlpha : 0
        visible: opacity > 0

        Behavior on opacity {
            enabled: Theme.animationsEnabled
            DAnim {
                duration: Style.expressiveDurations.expressiveEffects
                easing.bezierCurve: Style.expressiveCurves.expressiveEffects
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    // Surface Container
    Item {
        id: surface
        anchors.centerIn: parent
        width: Math.max(0, Math.min(SettingsMetrics.windowWidth, parent.width - 48))
        height: Math.max(0, Math.min(SettingsMetrics.windowHeight, parent.height - 48))
        scale: root.opened ? 1.0 : Style.popupEnterScale
        opacity: root.opened ? 1.0 : 0.0

        Behavior on scale {
            enabled: Theme.animationsEnabled
            DAnim {
                duration: Style.expressiveDurations.expressiveFastSpatial
                easing.bezierCurve: Style.expressiveCurves.expressiveFastSpatial
            }
        }

        Behavior on opacity {
            enabled: Theme.animationsEnabled
            DAnim {
                duration: Style.expressiveDurations.expressiveEffects
                easing.bezierCurve: Style.expressiveCurves.expressiveEffects
            }
        }

        ElevationShadow {
            anchors.fill: parent
            level: Style.elevationLevel3
            targetRadius: 16
            targetColor: Theme.windowSurface
            opacity: surface.opacity
        }

        // Window Surface
        Rectangle {
            id: windowSurface
            anchors.fill: parent
            radius: 16
            color: Theme.windowSurface
            border.color: Theme.outlineMedium
            border.width: Style.layerOutlineWidth
            clip: true

            Column {
                anchors.fill: parent
                spacing: 0

                // Header
                DWindowHeader {
                    id: header
                    width: parent.width
                    title: "Settings"
                    onCloseRequested: root.close()
                    controls: null
                    horizontalPadding: Theme.spacingM
                }

                // Split Layout: Sidebar + Main Content Area
                Item {
                    width: parent.width
                    height: parent.height - header.height

                    // Left Navigation Sidebar
                    SettingsSidebar {
                        id: sidebar
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: SettingsMetrics.sidebarWidth
                        currentIndex: content.currentIndex
                        onTabSelected: index => content.currentIndex = index
                    }

                    // Content Pane Area
                    Rectangle {
                        anchors.left: sidebar.right
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: Theme.spacingM
                        anchors.bottomMargin: Theme.spacingM
                        radius: 16
                        color: SettingsMetrics.paneColor
                        border.color: Theme.outlineMedium
                        border.width: Style.layerOutlineWidth

                        SettingsContent {
                            id: content
                            anchors.fill: parent
                            anchors.margins: SettingsMetrics.panePadding
                            currentIndex: 0
                            searchQuery: sidebar.query
                        }
                    }
                }
            }
        }
    }
}
