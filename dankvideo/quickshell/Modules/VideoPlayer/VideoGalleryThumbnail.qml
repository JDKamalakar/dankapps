import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets

Item {
    id: root

    required property var modelData
    required property int index
    property real itemSize: 180
    property bool isFirstInGroup: index === 0
    property bool isLastInGroup: false

    width: itemSize
    height: itemSize

    readonly property string filePath: modelData.path || ""
    readonly property string fileName: modelData.name || ""
    readonly property string thumbnailPath: modelData.thumbnail || ""

    ClippingRectangle {
        id: card
        anchors.fill: parent
        topLeftRadius: thumbnailMouse.containsMouse ? Style.cornerRadiusXL : (root.isFirstInGroup ? Style.cornerRadiusM : (Style.cornerRadiusXS ?? 4))
        bottomLeftRadius: thumbnailMouse.containsMouse ? Style.cornerRadiusXL : (root.isFirstInGroup ? Style.cornerRadiusM : (Style.cornerRadiusXS ?? 4))
        topRightRadius: thumbnailMouse.containsMouse ? Style.cornerRadiusXL : (root.isLastInGroup ? Style.cornerRadiusM : (Style.cornerRadiusXS ?? 4))
        bottomRightRadius: thumbnailMouse.containsMouse ? Style.cornerRadiusXL : (root.isLastInGroup ? Style.cornerRadiusM : (Style.cornerRadiusXS ?? 4))
        color: thumbnailMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
        border.color: thumbnailMouse.containsMouse ? Theme.primary : Theme.withAlpha(Theme.outlineVariant, 0.2)
        border.width: 1
        Behavior on topLeftRadius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on bottomLeftRadius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on topRightRadius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on bottomRightRadius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        scale: thumbnailMouse.containsMouse ? 1.02 : 1.0
        transform: Translate {
            y: thumbnailMouse.containsMouse ? -3 : 0
            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

        // Thumbnail or Video Preview / Placeholder
        Item {
            anchors.fill: parent

            Image {
                id: thumbImg
                anchors.fill: parent
                source: root.thumbnailPath ? ("file://" + root.thumbnailPath) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                readonly property int thumbTier: root.itemSize <= 128 ? 256 : (root.itemSize <= 256 ? 512 : 1024)
                sourceSize.width: thumbTier
                sourceSize.height: thumbTier
                visible: status === Image.Ready
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.surfaceContainerHighest
                visible: !thumbImg.visible

                DIcon {
                    anchors.centerIn: parent
                    name: "movie"
                    size: 40
                    color: Theme.withAlpha(Theme.surfaceVariantText, 0.5)
                }
            }

            // Bottom gradient overlay for name readability (visible on hover)
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 48
                opacity: thumbnailMouse.containsMouse ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Theme.withAlpha("#000000", 0.75) }
                }
            }

            // Video Play Badge (Bottom-right)
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 6
                width: 26
                height: 26
                radius: 13
                color: Theme.withAlpha("#000000", 0.65)
                border.color: Theme.withAlpha("#ffffff", 0.2)
                border.width: 1

                DIcon {
                    anchors.centerIn: parent
                    name: "play_arrow"
                    size: 16
                    color: "#ffffff"
                }
            }

            // File Name Label (Bottom-left)
            StyledText {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: 36
                anchors.bottom: parent.bottom
                anchors.margins: 6
                text: root.fileName
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: "#ffffff"
                elide: Text.ElideMiddle
                maximumLineCount: 1
            }
        }

        MouseArea {
            id: thumbnailMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                VideoService.openVideoFromGallery(root.filePath);
            }
        }
    }
}
