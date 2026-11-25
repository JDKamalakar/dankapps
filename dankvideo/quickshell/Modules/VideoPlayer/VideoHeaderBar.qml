import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets

Rectangle {
    id: root

    required property var windowControls
    property var targetWindow: null

    implicitHeight: Math.max(header.implicitHeight, (Theme.densityLevel < 0 ? 36 : (Theme.densityLevel > 0 ? 52 : 44)))
    color: Theme.foregroundColor(Theme.surfaceContainerHigh, true)
    border.color: Theme.withAlpha(Theme.outlineVariant, 0.25)
    border.width: 1

    DWindowHeader {
        id: header
        anchors.fill: parent
        controls: root.windowControls
        title: VideoService.currentFileName || "DUX Video Player"
        onCloseRequested: {
            if (SettingsData.closeBehavior === "quit") {
                Qt.quit();
            } else {
                root.targetWindow?.close();
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS + Theme.densityStepS

            DIconButton {
                iconName: "grid_view"
                size: Theme.densityLevel < 0 ? "xs" : "s"
                variant: "standard"
                tooltipText: "Library"
                Accessible.name: "Library"
                onClicked: VideoService.returnToGallery()
            }

            DIconButton {
                iconName: "settings"
                size: Theme.densityLevel < 0 ? "xs" : "s"
                variant: "standard"
                tooltipText: "Settings"
                Accessible.name: "Settings"
                onClicked: VideoService.settingsOpen = !VideoService.settingsOpen
            }
        }
    }
}
