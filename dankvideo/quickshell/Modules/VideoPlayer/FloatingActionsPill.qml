import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets

Rectangle {
    id: root

    implicitHeight: Style.buttonHeightM
    implicitWidth: contentRow.implicitWidth + Style.spacingL
    radius: height / 2
    color: Theme.foregroundColor(Theme.surfaceContainerHigh, true)
    border.color: Theme.withAlpha(Theme.outlineVariant, 0.28)
    border.width: Style.outlineWidth

    ElevationShadow {
        anchors.fill: parent
        z: -1
        targetRadius: parent.radius
        targetColor: parent.color
        level: Style.elevationLevel2
    }

    component ConnectedActionBtn: DActionButton {
        property int segIndex: 0
        property int segCount: 3
        property bool segActive: false
        readonly property real pillR: height / 2
        readonly property real leftR: M3E.leftRadius(segIndex, segCount, pillR, pressed, hovered, segActive, M3E.pressRadiusS)
        readonly property real rightR: M3E.rightRadius(segIndex, segCount, pillR, pressed, hovered, segActive, M3E.pressRadiusS)

        buttonSize: Style.buttonHeightS
        iconSize: Style.iconSizeMedium
        topLeftRadius: leftR
        bottomLeftRadius: leftR
        topRightRadius: rightR
        bottomRightRadius: rightR
        backgroundColor: segActive ? Theme.secondaryContainer : (hovered ? Theme.foregroundColor(Theme.surfaceContainerHighest, true) : "transparent")
        iconColor: segActive ? Theme.primary : Theme.surfaceText

        Behavior on topLeftRadius { DAnim { duration: M3E.spatialFastMs; easing.bezierCurve: M3E.curveFastSpatial } }
        Behavior on bottomLeftRadius { DAnim { duration: M3E.spatialFastMs; easing.bezierCurve: M3E.curveFastSpatial } }
        Behavior on topRightRadius { DAnim { duration: M3E.spatialFastMs; easing.bezierCurve: M3E.curveFastSpatial } }
        Behavior on bottomRightRadius { DAnim { duration: M3E.spatialFastMs; easing.bezierCurve: M3E.curveFastSpatial } }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: M3E.groupGap

        // Open Video Action
        ConnectedActionBtn {
            segIndex: 0
            segCount: 3
            iconName: "folder_open"
            tooltipText: "Open Video (O)"
            tooltipSide: "bottom"
            onClicked: VideoService.openFileDialog()
        }

        // Media Details / Inspector Toggle
        ConnectedActionBtn {
            segIndex: 1
            segCount: 3
            segActive: VideoService.inspectorOpen
            iconName: "info"
            iconFilled: VideoService.inspectorOpen
            tooltipText: "Media Details (I)"
            tooltipSide: "bottom"
            onClicked: VideoService.toggleInspector()
        }

        // Lock UI Action
        ConnectedActionBtn {
            segIndex: 2
            segCount: 3
            iconName: "lock_open"
            tooltipText: "Lock UI / Clean View (K)"
            tooltipSide: "bottom"
            onClicked: VideoService.toggleLockUI()
        }

        // Counter badge e.g. "2 / 5" if playlist has multiple files - Click opens Playlist Drawer
        Rectangle {
            id: counterBadge
            visible: VideoService.fileList.length > 1
            implicitHeight: Style.buttonHeightXS
            implicitWidth: counterRow.implicitWidth + Style.spacingM * 2
            radius: height / 2
            color: counterMouse.containsMouse || VideoService.playlistDrawerOpen ? Theme.primaryContainer : Theme.foregroundColor(Theme.surfaceContainerHighest, true)
            border.color: counterMouse.containsMouse || VideoService.playlistDrawerOpen ? Theme.primary : Theme.withAlpha(Theme.outlineVariant, 0.2)
            border.width: Style.outlineWidth
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: Style.spacingXS

            Behavior on color {
                DColorAnim { duration: Theme.shortDuration }
            }

            RowLayout {
                id: counterRow
                anchors.centerIn: parent
                spacing: 4

                DIcon {
                    name: "playlist_play"
                    size: 16
                    color: counterBadge.color === Theme.primaryContainer ? Theme.primary : Theme.surfaceVariantText
                }

                StyledText {
                    id: counterText
                    text: (VideoService.currentIndex + 1) + " / " + VideoService.fileList.length
                    font.pixelSize: Style.fontSizeSmall
                    font.weight: Font.Medium
                    color: counterBadge.color === Theme.primaryContainer ? Theme.primary : Theme.surfaceVariantText
                }
            }

            MouseArea {
                id: counterMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: VideoService.playlistDrawerOpen = !VideoService.playlistDrawerOpen
            }
        }
    }
}
