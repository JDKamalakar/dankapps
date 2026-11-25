import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Common
import qs.DCommon.Widgets

Item {
    id: root

    readonly property bool hasFavorites: ImageService.favoriteCount > 0
    readonly property var primaryItems: {
        const items = [{ text: "Timeline", icon: "timeline" }];
        if (hasFavorites) items.push({ text: "Favorites", icon: "favorite" });
        items.push({ text: "Albums", icon: "collections_bookmark" });
        return items;
    }
    readonly property var quickAccessItems: ImageService.quickAccessFolderAlbums.map(album => ({
                text: album.name,
                icon: "folder"
            }))
    readonly property real quickAccessHeadingHeight: quickAccessItems.length > 0 ? 24 : 0
    readonly property real quickAccessAvailableHeight: Math.max(0, height - primaryNavigation.implicitHeight - utilityNavigation.implicitHeight - quickAccessHeadingHeight - Theme.spacingM * 2 - Theme.spacingS * 4)
    readonly property var utilityItems: [
        {
            text: "Trash",
            icon: "delete",
            badgeCount: ImageService.trashCount
        },
        {
            text: "Settings",
            icon: "settings"
        }
    ]
    readonly property int primaryIndex: {
        if (ImageService.galleryTab === "albums")
            return hasFavorites ? 2 : 1;
        if (ImageService.galleryTab !== "gallery" && ImageService.galleryTab !== "timeline")
            return -1;
        if (ImageService.selectedCategory === "Favorites")
            return hasFavorites ? 1 : -1;
        return ImageService.selectedCategory === "All" || !ImageService.selectedCategory ? 0 : -1;
    }
    readonly property int quickAccessIndex: {
        if (ImageService.galleryTab !== "gallery" && ImageService.galleryTab !== "timeline")
            return -1;
        return ImageService.quickAccessFolderAlbums.findIndex(album => album.name === ImageService.selectedCategory);
    }
    readonly property int utilityIndex: ImageService.settingsOpen ? 1 : ImageService.galleryTab === "trash" ? 0 : -1

    property bool _floatingRevealed: true
    readonly property bool _isHidden: SettingsData.sidebarFloating && !_floatingRevealed
    z: 50

    implicitWidth: SettingsData.sidebarFloating ? (_isHidden ? 16 : primaryNavigation.railWidth + Theme.spacingM * 2 + Theme.spacingS) : primaryNavigation.railWidth
    width: implicitWidth
    clip: true

    Behavior on implicitWidth { enabled: Theme.animationsEnabled; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    HoverHandler {
        id: sidebarHover
        onHoveredChanged: {
            if (hovered) {
                root._floatingRevealed = true;
                hideTimer.stop();
            } else if (SettingsData.sidebarFloating) {
                hideTimer.restart();
            }
        }
    }

    Timer {
        id: hideTimer
        interval: SettingsData.sidebarAutoHideMs || 1500
        onTriggered: {
            if (SettingsData.sidebarFloating && !sidebarHover.hovered)
                root._floatingRevealed = false;
        }
    }

    // Edge reveal pill when floating
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 5
        height: 48
        radius: 2.5
        color: Theme.primary
        opacity: 0.75
        visible: SettingsData.sidebarFloating
        z: 5
    }

    Rectangle {
        visible: SettingsData.sidebarFloating
        opacity: root._isHidden ? 0 : 1
        Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        anchors.fill: parent
        anchors.topMargin: Theme.spacingM
        anchors.bottomMargin: Theme.spacingM
        anchors.leftMargin: Theme.spacingS
        anchors.rightMargin: Theme.spacingS
        radius: Theme.groupedListOuterRadius ?? 16
        color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.78)
        border.color: Theme.outlineMedium ?? Theme.outlineVariant
        border.width: 1
        clip: true
    }

    function activatePrimary(index) {
        if (index === primaryIndex)
            ImageService.requestScrollToTop();

        if (index === 0) {
            ImageService.selectedCategory = "All";
            ImageService.galleryTab = "gallery";
        } else if (hasFavorites && index === 1) {
            ImageService.selectedCategory = "Favorites";
            ImageService.galleryTab = "gallery";
        } else if (hasFavorites && index === 2) {
            ImageService.galleryTab = "albums";
        } else if (!hasFavorites && index === 1) {
            ImageService.galleryTab = "albums";
        }
    }

    function activateQuickAccess(index) {
        const album = ImageService.quickAccessFolderAlbums[index];
        if (!album)
            return;

        if (index === quickAccessIndex)
            ImageService.requestScrollToTop();
        ImageService.selectedCategory = album.name;
        ImageService.galleryTab = "gallery";
    }

    function activateUtility(index) {
        if (index === 0) {
            if (utilityIndex === 0)
                ImageService.requestScrollToTop();
            ImageService.galleryTab = "trash";
        } else if (index === 1) {
            ImageService.settingsOpen = !ImageService.settingsOpen;
        }
    }

    ColumnLayout {
        id: sidebarCol
        opacity: root._isHidden ? 0 : 1
        Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        anchors.fill: parent
        anchors.topMargin: Theme.spacingM + (SettingsData.sidebarFloating ? 12 : 0)
        anchors.bottomMargin: Theme.spacingM + (SettingsData.sidebarFloating ? 12 : 0)
        anchors.leftMargin: SettingsData.sidebarFloating ? Theme.spacingL : Theme.spacingM
        anchors.rightMargin: SettingsData.sidebarFloating ? Theme.spacingL : 0
        spacing: Theme.spacingS

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: SettingsData.sidebarCentered ? Math.max(0, (sidebarCol.height - primaryNavigation.implicitHeight - (quickAccessHeading.visible ? quickAccessHeading.height + quickAccessFlick.height + Theme.spacingS * 2 : 0) - utilityNavigation.implicitHeight - Theme.spacingS * 2) / 2) : 0
            Behavior on Layout.preferredHeight {
                enabled: Theme.animationsEnabled
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }

        AppSidebarRail {
            id: primaryNavigation

            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            model: root.primaryItems
            currentIndex: root.primaryIndex
            onActivated: index => root.activatePrimary(index)
        }

        Item {
            id: quickAccessHeading

            Layout.fillWidth: true
            Layout.preferredHeight: root.quickAccessHeadingHeight
            visible: SettingsData.showQuickAccessInSidebar && root.quickAccessItems.length > 0

            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingS
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                visible: (SettingsData.sidebarStyle || "beside") !== "icons_only"
                text: "Quick access"
                font.pixelSize: Theme.fontSizeSmall - 1
                font.weight: Theme.fontWeightBold
                color: Theme.surfaceVariantText
                horizontalAlignment: (SettingsData.sidebarStyle || "beside") === "below" ? Text.AlignHCenter : Text.AlignLeft
                elide: Text.ElideRight
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - Theme.spacingM * 2
                height: 1
                visible: (SettingsData.sidebarStyle || "beside") === "icons_only"
                color: Theme.outlineVariant
                opacity: 0.5
            }
        }

        Flickable {
            id: quickAccessFlick
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(quickAccessNavigation.implicitHeight, root.quickAccessAvailableHeight)
            Layout.maximumHeight: root.quickAccessAvailableHeight
            contentWidth: width
            contentHeight: quickAccessNavigation.implicitHeight
            clip: true
            visible: SettingsData.showQuickAccessInSidebar && root.quickAccessItems.length > 0

            AppSidebarRail {
                id: quickAccessNavigation
                width: parent.width
                model: root.quickAccessItems
                currentIndex: root.quickAccessIndex
                onActivated: index => root.activateQuickAccess(index)
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.minimumHeight: 0
        }

        AppSidebarRail {
            id: utilityNavigation

            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            model: root.utilityItems
            currentIndex: root.utilityIndex
            onActivated: index => root.activateUtility(index)
        }
    }
}
