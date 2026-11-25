import QtQuick
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets

Item {
    id: root

    property var flickable: null // kept for compatibility, unused with ListView virtualization
    property var imageItem: null
    property real tileSize: 160
    property real customWidth: -1
    property real customHeight: -1
    property bool isTrashMode: false
    property string thumbnailLayout: SettingsData.galleryThumbnailLayout
    property bool isFirstInGroup: false
    property bool isLastInGroup: false
    property int masonryColumn: -1
    property var navigationPaths: []

    width: customWidth > 0 ? customWidth : tileSize
    height: customHeight > 0 ? customHeight : (thumbnailLayout === "masonry"
        ? width / Math.max(0.25, Math.min(4, imageAspectRatio))
        : tileSize)

    readonly property bool isSelected: imageItem ? ImageService.isSelected(imageItem.path) : false
    readonly property bool isRangePreview: imageItem ? ImageService.isRangePreview(imageItem.path) : false
    readonly property bool isFav: imageItem ? ImageService.isFavorite(imageItem.path) : false
    readonly property bool isSelectionMode: ImageService.gallerySelectedCount > 0
    readonly property bool isCardHovered: cardHover.hovered
    readonly property bool isVideo: (imageItem && imageItem.isVideo) || (imageItem && ImageService.isVideoFile(imageItem.path))
    readonly property real imageAspectRatio: thumbImg.status === Image.Ready && thumbImg.implicitHeight > 0
        ? thumbImg.implicitWidth / thumbImg.implicitHeight
        : 1

    ClippingRectangle {
        id: card
        anchors.fill: parent
        topLeftRadius: root.isCardHovered ? Style.cornerRadiusXL : (root.isFirstInGroup ? Style.cornerRadiusM : (Style.cornerRadiusXS ?? 4))
        bottomLeftRadius: root.isCardHovered ? Style.cornerRadiusXL : (root.isFirstInGroup ? Style.cornerRadiusM : (Style.cornerRadiusXS ?? 4))
        topRightRadius: root.isCardHovered ? Style.cornerRadiusXL : (root.isLastInGroup ? Style.cornerRadiusM : (Style.cornerRadiusXS ?? 4))
        bottomRightRadius: root.isCardHovered ? Style.cornerRadiusXL : (root.isLastInGroup ? Style.cornerRadiusM : (Style.cornerRadiusXS ?? 4))
        color: root.isCardHovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
        border.width: 1
        border.color: root.isCardHovered ? Theme.primary : Theme.withAlpha(Theme.outlineVariant, 0.2)

        Behavior on topLeftRadius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on bottomLeftRadius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on topRightRadius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on bottomRightRadius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on color { DColorAnim { duration: Style.shortDuration } }
        Behavior on border.color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

        scale: root.isCardHovered ? 1.02 : 1.0
        transform: Translate {
            y: root.isCardHovered ? -3 : 0
            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        HoverHandler {
            id: cardHover
        }

        HoverHandler {
            id: rangeHover
            acceptedModifiers: Qt.ShiftModifier
            onHoveredChanged: {
                if (root.isTrashMode || !root.imageItem)
                    return;
                if (hovered)
                    ImageService.previewSelectionRange(root.imageItem.path, root.navigationPaths);
                else if (ImageService.rangePreviewTargetPath === root.imageItem.path)
                    ImageService.clearSelectionRangePreview();
            }
        }

        Image {
            id: thumbImg
            anchors.fill: parent
            fillMode: (root.customWidth > 0 || root.thumbnailLayout === "crop") ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            asynchronous: true
            cache: true
            readonly property int thumbTier: root.tileSize <= 128 ? 256 : (root.tileSize <= 256 ? 512 : 1024)
            source: {
                if (!root.imageItem) return ""
                if (root.isVideo) return root.imageItem.thumbnail ? ("file://" + root.imageItem.thumbnail) : ""
                if (thumbTier > 256) return "file://" + root.imageItem.path
                if (root.imageItem.thumbnail) return "file://" + root.imageItem.thumbnail
                return "file://" + root.imageItem.path
            }
            sourceSize.width: thumbTier
            sourceSize.height: thumbTier
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.surfaceContainerHighest
            visible: root.isVideo && thumbImg.status !== Image.Ready

            DIcon {
                anchors.centerIn: parent
                name: "movie"
                size: 36
                color: Theme.withAlpha(Theme.surfaceVariantText, 0.6)
            }
        }

        // Video Play Badge (Bottom-right)
        Rectangle {
            visible: root.isVideo
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

        // Selection Border & Highlight Tint Overlay
        Rectangle {
            id: selectionOverlay
            anchors.fill: parent
            radius: Style.cornerRadiusM
            color: root.isSelected
                ? Theme.withAlpha(Theme.primary, root.isCardHovered ? 0.22 : 0.16)
                : (root.isRangePreview ? Theme.withAlpha(Theme.primary, 0.12) : "transparent")
            border.color: root.isSelected
                ? Theme.primary
                : (root.isRangePreview ? Theme.withAlpha(Theme.primary, 0.6) : (root.isCardHovered ? Theme.withAlpha(Theme.surfaceText, 0.4) : "transparent"))
            border.width: root.isSelected ? 3 : (root.isRangePreview ? 2 : (root.isCardHovered ? 1 : 0))

            Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
            Behavior on border.color { ColorAnimation { duration: Theme.shortDuration } }
        }

        // Dark gradient overlay for icons visibility
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Style.buttonHeightS
            visible: root.isSelected || (!root.isTrashMode && root.isFav) || root.isSelectionMode
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.withAlpha(Theme.scrimColor, 0.55) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Selection Checkbox (Top-Left)
        Rectangle {
            id: selectBtn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: Style.spacingS
            width: Style.iconSize
            height: Style.iconSize
            radius: height / 2
            visible: root.isSelected || root.isSelectionMode
            color: root.isSelected
                ? (selectMouse.containsMouse ? Theme.primaryContainer : Theme.primary)
                : (selectMouse.containsMouse ? Theme.withAlpha(Theme.scrimColor, 0.6) : Theme.withAlpha(Theme.scrimColor, 0.35))
            border.color: root.isSelected
                ? Theme.primary
                : (selectMouse.containsMouse ? Theme.surfaceText : Theme.withAlpha(Theme.surfaceText, 0.8))
            border.width: root.isSelected ? 0 : 1.5
            scale: selectMouse.pressed ? 0.9 : (selectMouse.containsMouse ? 1.1 : 1.0)

            Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
            Behavior on border.color { ColorAnimation { duration: Theme.shortDuration } }
            Behavior on scale { NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }

            DIcon {
                anchors.centerIn: parent
                visible: root.isSelected
                name: "check"
                size: Style.iconSizeSmall
                color: root.isSelected && selectMouse.containsMouse ? Theme.onPrimaryContainer : Theme.primaryText
            }

            MouseArea {
                id: selectMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (!root.imageItem)
                        return;
                    if (!root.isTrashMode && (mouse.modifiers & Qt.ShiftModifier))
                        ImageService.selectRange(root.imageItem.path, root.navigationPaths);
                    else
                        ImageService.toggleSelect(root.imageItem.path);
                }
            }
        }

        // Top-Right Action Button: Restore (Trash mode) or Favorite Heart (Normal)
        Rectangle {
            id: actionBtn
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Style.spacingS
            width: Style.iconSize
            height: Style.iconSize
            radius: height / 2
            visible: !root.isTrashMode && root.isFav
            color: actionMouse.containsMouse ? Theme.withAlpha(Theme.scrimColor, 0.6) : Theme.withAlpha(Theme.scrimColor, 0.35)
            scale: actionMouse.pressed ? 0.9 : (actionMouse.containsMouse ? 1.1 : 1.0)

            Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
            Behavior on scale { NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }

            DIcon {
                anchors.centerIn: parent
                name: root.isTrashMode ? "restore" : "favorite"
                filled: !root.isTrashMode && root.isFav
                size: Style.iconSizeSmall
                color: root.isTrashMode
                    ? (actionMouse.containsMouse ? Theme.surfaceText : Theme.withAlpha(Theme.surfaceText, 0.8))
                    : (root.isFav
                        ? (actionMouse.containsMouse ? Qt.lighter(Theme.error, 1.2) : Theme.error)
                        : (actionMouse.containsMouse ? Theme.surfaceText : Theme.withAlpha(Theme.surfaceText, 0.8)))
            }

            MouseArea {
                id: actionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!root.imageItem) return
                    if (root.isTrashMode) {
                        ImageService.restoreFromTrash(root.imageItem)
                    } else {
                        ImageService.toggleFavorite(root.imageItem.path)
                    }
                }
            }
        }

        // Bottom-Right Video Indicator Badge
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: Style.spacingS
            width: 24
            height: 24
            radius: 12
            visible: root.isVideo
            color: Theme.withAlpha(Theme.scrimColor, 0.65)

            DIcon {
                anchors.centerIn: parent
                name: "play_arrow"
                size: 16
                color: "#FFFFFF"
                filled: true
            }
        }

        // Body Click to Open in Viewer or Toggle Selection
        MouseArea {
            id: thumbMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            z: -1
            onClicked: mouse => {
                if (root.imageItem) {
                    if (!root.isTrashMode && (mouse.modifiers & Qt.ShiftModifier))
                        ImageService.selectRange(root.imageItem.path, root.navigationPaths)
                    else if (root.isSelectionMode) ImageService.toggleSelect(root.imageItem.path)
                    else ImageService.openImageFromGallery(root.imageItem.path, root.imageItem.thumbnail || "", root.navigationPaths)
                }
            }
        }
    }
}
