import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Common
import qs.DCommon.Widgets

Item {
    id: root

    property var windowControls: null
    property var targetWindow: null

    property string currentSection: SettingsData.libraryDefaultTab || "all" // "all", "playlists", "folders"
    property string selectedFolderName: ""
    property var selectedPlaylistObj: null
    readonly property var quickAccessFolders: SettingsData.quickAccessFolders || []
    property bool includeHidden: SettingsData.videoIncludeHidden || false
    function toggleQuickAccessFolder(folderName) {
        const list = (SettingsData.quickAccessFolders || []).slice();
        const idx = list.indexOf(folderName);
        if (idx === -1) list.push(folderName);
        else list.splice(idx, 1);
        SettingsData.quickAccessFolders = list;
    }
    property string sortOrder: "newest" // "newest", "oldest", "az", "za"
    property string dateFilter: "all" // "all", "today", "7d", "30d"
    property int gridItemSize: 184
    property bool groupByDate: SettingsData.videoGroupByDate
    property bool filterPopupOpen: false
    property var viewStates: ({})

    readonly property string currentViewKey: {
        if (root.currentSection === "folders") return "folder:" + root.selectedFolderName;
        if (root.currentSection === "playlists") return "playlist:" + (root.selectedPlaylistObj ? root.selectedPlaylistObj.name : "");
        return "all";
    }

    onCurrentViewKeyChanged: {
        const st = viewStates[currentViewKey];
        if (st) {
            sortOrder = st.sortOrder || "newest";
            dateFilter = st.dateFilter || "all";
            gridItemSize = st.gridItemSize || 184;
        } else {
            sortOrder = "newest";
            dateFilter = "all";
            gridItemSize = 184;
        }
    }

    function _saveViewState() {
        const copy = Object.assign({}, viewStates);
        copy[currentViewKey] = { sortOrder: sortOrder, dateFilter: dateFilter, gridItemSize: gridItemSize };
        viewStates = copy;
        SettingsData.videoSortOrder = sortOrder;
        SettingsData.videoDateFilter = dateFilter;
        SettingsData.videoGridItemSize = gridItemSize;
    }

    onSortOrderChanged: _saveViewState()
    onDateFilterChanged: _saveViewState()
    onGridItemSizeChanged: _saveViewState()

    readonly property var filteredVideos: {
        const data = VideoService.galleryData;
        if (!data || !data.allVideos) return [];
        let list = data.allVideos.slice();

        if (root.currentSection === "folders" && root.selectedFolderName !== "") {
            list = list.filter(v => v.category === root.selectedFolderName);
        } else if (root.currentSection === "playlists" && root.selectedPlaylistObj) {
            const paths = root.selectedPlaylistObj.items || [];
            list = list.filter(v => paths.indexOf(v.path) !== -1);
        }

        if (!root.includeHidden) {
            list = list.filter(v => {
                const name = v.name || "";
                return !name.startsWith(".");
            });
        }

        if (root.dateFilter !== "all") {
            const nowSec = Math.floor(Date.now() / 1000);
            const cutoff = root.dateFilter === "today" ? (nowSec - 86400) : (root.dateFilter === "7d" ? (nowSec - 7 * 86400) : (nowSec - 30 * 86400));
            list = list.filter(v => (v.modTime || 0) >= cutoff);
        }

        const query = (VideoService.searchQuery || "").trim().toLowerCase();
        if (query) {
            list = list.filter(v => (v.name || "").toLowerCase().indexOf(query) !== -1 || (v.category || "").toLowerCase().indexOf(query) !== -1);
        }

        if (root.sortOrder === "oldest") {
            list.sort((a, b) => (a.modTime || 0) - (b.modTime || 0));
        } else if (root.sortOrder === "az") {
            list.sort((a, b) => (a.name || "").localeCompare(b.name || ""));
        } else if (root.sortOrder === "za") {
            list.sort((a, b) => (b.name || "").localeCompare(a.name || ""));
        } else {
            list.sort((a, b) => (b.modTime || 0) - (a.modTime || 0));
        }

        return list;
    }

    readonly property var groupedVideos: {
        if (!root.groupByDate) return [];
        const list = root.filteredVideos;
        const now = new Date();
        const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime() / 1000;
        const yesterdayStart = todayStart - 86400;
        const weekStart = todayStart - 7 * 86400;
        const groups = { "Today": [], "Yesterday": [], "This Week": [], "Earlier": [] };
        for (let i = 0; i < list.length; i++) {
            const v = list[i];
            const t = v.modTime || 0;
            if (t >= todayStart) groups["Today"].push(v);
            else if (t >= yesterdayStart) groups["Yesterday"].push(v);
            else if (t >= weekStart) groups["This Week"].push(v);
            else groups["Earlier"].push(v);
        }
        const res = [];
        const order = ["Today", "Yesterday", "This Week", "Earlier"];
        for (let j = 0; j < order.length; j++) {
            const k = order[j];
            if (groups[k].length > 0) res.push({ title: k, items: groups[k] });
        }
        return res;
    }

    // Top Header with Window Controls (matches ClockWindow / ImageViewerWindow)
    Rectangle {
        id: galleryHeader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        implicitHeight: headerContent.implicitHeight
        color: "transparent"
        z: 20

        DWindowHeader {
            id: headerContent
            anchors.fill: parent
            controls: root.windowControls
            title: "DUX Video"
            onCloseRequested: {
                if (SettingsData.closeBehavior === "quit") {
                    Qt.quit();
                } else {
                    root.targetWindow?.close();
                }
            }
        }
    }

    // Body: Left Sidebar Navigation + Main Content Card
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: galleryHeader.bottom
        anchors.bottom: parent.bottom

        // Unified Left Navigation Sidebar
        MouseArea {
            anchors.fill: parent
            z: 45
            visible: SettingsData.sidebarFloating && sidebar._floatingRevealed
            onPressed: mouse => {
                sidebar._floatingRevealed = false;
                mouse.accepted = false;
            }
        }

        Item {
            id: sidebar
            z: 50
            property bool _floatingRevealed: true
            readonly property bool _isHidden: SettingsData.sidebarFloating && !_floatingRevealed
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: SettingsData.sidebarFloating ? (_isHidden ? 16 : videoPrimaryNav.railWidth + Theme.spacingM * 2 + Theme.spacingS) : videoPrimaryNav.railWidth

            Behavior on width { enabled: Theme.animationsEnabled; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            HoverHandler {
                id: videoSidebarHover
                onHoveredChanged: {
                    if (hovered) {
                        sidebar._floatingRevealed = true;
                        videoHideTimer.stop();
                    } else if (SettingsData.sidebarFloating) {
                        videoHideTimer.restart();
                    }
                }
            }

            Timer {
                id: videoHideTimer
                interval: SettingsData.sidebarAutoHideMs || 1500
                onTriggered: {
                    if (SettingsData.sidebarFloating && !videoSidebarHover.hovered)
                        sidebar._floatingRevealed = false;
                }
            }

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
                opacity: sidebar._isHidden ? 0 : 1
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

            ColumnLayout {
                id: videoSidebarCol
                opacity: sidebar._isHidden ? 0 : 1
                Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                anchors.fill: parent
                anchors.topMargin: Theme.spacingM + (SettingsData.sidebarFloating ? 12 : 0)
                anchors.bottomMargin: Theme.spacingM + (SettingsData.sidebarFloating ? 12 : 0)
                anchors.leftMargin: SettingsData.sidebarFloating ? Theme.spacingL : Theme.spacingM
                anchors.rightMargin: SettingsData.sidebarFloating ? Theme.spacingL : 0
                spacing: Theme.spacingS

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: SettingsData.sidebarCentered ? Math.max(0, (videoSidebarCol.height - videoPrimaryNav.implicitHeight - videoBottomNav.implicitHeight - Theme.spacingS * 2) / 2) : 0
                    Behavior on Layout.preferredHeight {
                        enabled: Theme.animationsEnabled
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                }

                AppSidebarRail {
                    id: videoPrimaryNav
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    Layout.alignment: Qt.AlignTop
                    model: [
                        { icon: "movie", text: "All Videos" },
                        { icon: "playlist_play", text: "Playlists" },
                        { icon: "collections_bookmark", text: "Albums" }
                    ]
                    currentIndex: root.currentSection === "all" ? 0 : (root.currentSection === "playlists" ? 1 : 2)
                    onActivated: index => {
                        if (index === 0) {
                            root.currentSection = "all";
                            root.selectedFolderName = "";
                            root.selectedPlaylistObj = null;
                        } else if (index === 1) {
                            root.currentSection = "playlists";
                            root.selectedFolderName = "";
                        } else if (index === 2) {
                            root.currentSection = "folders";
                            root.selectedPlaylistObj = null;
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    visible: SettingsData.showFavoriteAlbumsInSidebar && root.quickAccessFolders.length > 0

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

                AppSidebarRail {
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    visible: SettingsData.showFavoriteAlbumsInSidebar && root.quickAccessFolders.length > 0
                    model: root.quickAccessFolders.map(name => ({ icon: "folder", text: name }))
                    currentIndex: root.currentSection === "folders" ? root.quickAccessFolders.indexOf(root.selectedFolderName) : -1
                    onActivated: index => {
                        const name = root.quickAccessFolders[index];
                        if (!name) return;
                        root.currentSection = "folders";
                        root.selectedPlaylistObj = null;
                        root.selectedFolderName = name;
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                // Settings Button Unified at Sidebar Bottom
                AppSidebarRail {
                    id: videoBottomNav
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    model: [{ icon: "settings", text: "Settings" }]
                    currentIndex: VideoService.settingsOpen ? 0 : -1
                    onActivated: {
                        VideoService.settingsOpen = true;
                    }
                }
            }
        }

        // Main Content Card
        Rectangle {
            id: mainContentCard
            anchors.left: SettingsData.sidebarFloating ? parent.left : sidebar.right
            anchors.leftMargin: Theme.spacingM
            anchors.top: parent.top
            anchors.topMargin: Theme.spacingM
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingM
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spacingM
            radius: Theme.cornerRadiusXL
            color: Theme.foregroundColor(Theme.surfaceContainer, true)
            border.width: Style.outlineWidth
            border.color: Theme.withAlpha(Theme.outlineVariant, 0.25)
            clip: true

            // Sub-header for playlists / folders navigation
            Rectangle {
                id: sectionHeaderBar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 48
                visible: (root.currentSection !== "all" && !(root.currentSection === "folders" && root.selectedFolderName === "")) || (root.selectedFolderName !== "" || root.selectedPlaylistObj !== null)
                color: Theme.surfaceContainerHigh
                topLeftRadius: Theme.cornerRadiusXL
                topRightRadius: Theme.cornerRadiusXL
                z: 10

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingM
                    spacing: Theme.spacingS

                    DIconButton {
                        visible: root.selectedFolderName !== "" || root.selectedPlaylistObj !== null
                        iconName: "arrow_back"
                        size: "s"
                        variant: "standard"
                        tooltipText: "Back"
                        onClicked: {
                            root.selectedFolderName = "";
                            root.selectedPlaylistObj = null;
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            if (root.selectedPlaylistObj) return "Playlist: " + root.selectedPlaylistObj.name;
                            if (root.selectedFolderName) return "Album: " + root.selectedFolderName;
                            if (root.currentSection === "playlists") return "Custom Playlists";
                            if (root.currentSection === "folders") return "Video Albums";
                            if (root.currentSection === "favorites") return "Favorites";
                            return "Videos";
                        }
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.surfaceText
                    }

                    // Create New Playlist button
                    DButton {
                        visible: root.currentSection === "playlists" && !root.selectedPlaylistObj
                        text: "New Playlist"
                        iconName: "playlist_add"
                        onClicked: newPlaylistDialog.open()
                    }

                    // Play all in this folder/playlist button
                    DButton {
                        visible: (root.selectedPlaylistObj || root.selectedFolderName) && root.filteredVideos.length > 0
                        text: "Play All"
                        iconName: "play_arrow"
                        onClicked: {
                            if (root.selectedPlaylistObj) {
                                VideoService.playCustomPlaylist(root.selectedPlaylistObj.name);
                            } else if (root.selectedFolderName) {
                                VideoService.playVideoList(root.filteredVideos.map(v => v.path), 0);
                            }
                        }
                    }
                }
            }

            // Sub-view: Playlists List (when no playlist selected)
            ListView {
                id: playlistsListView
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: sectionHeaderBar.bottom
                anchors.bottom: parent.bottom
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS
                clip: true
                visible: root.currentSection === "playlists" && !root.selectedPlaylistObj
                model: VideoService.customPlaylists

                delegate: Rectangle {
                    id: plDelegate
                    required property var modelData
                    required property int index
                    width: playlistsListView.width
                    height: 56
                    radius: Style.cornerRadiusM
                    color: plMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                    border.color: Theme.withAlpha(Theme.outlineVariant, 0.2)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        DIcon {
                            name: "playlist_play"
                            size: 24
                            color: Theme.primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                text: plDelegate.modelData.name || "Untitled Playlist"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: (plDelegate.modelData.items ? plDelegate.modelData.items.length : 0) + " videos"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }

                        DIconButton {
                            iconName: "play_arrow"
                            size: "s"
                            variant: "filled"
                            tooltipText: "Play all"
                            onClicked: VideoService.playCustomPlaylist(plDelegate.modelData)
                        }

                        DIconButton {
                            iconName: "delete"
                            size: "s"
                            variant: "standard"
                            tooltipText: "Delete playlist"
                            onClicked: VideoService.deleteCustomPlaylist(plDelegate.modelData.id)
                        }
                    }

                    MouseArea {
                        id: plMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedPlaylistObj = plDelegate.modelData
                    }
                }
            }

            // Sub-view: Albums List (when no album selected)
            Flickable {
                id: foldersGridView
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: Theme.spacingM
                topMargin: 72
                contentWidth: width
                contentHeight: albumsColumn.implicitHeight + Theme.spacingM
                clip: true
                visible: root.currentSection === "folders" && root.selectedFolderName === ""

                ColumnLayout {
                    id: albumsColumn
                    width: parent.width
                    spacing: Style.spacingXL

                    // Quick Access Section (only visible when non-empty)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.spacingM
                        visible: root.quickAccessFolders.length > 0

                        RowLayout {
                            spacing: Style.spacingS

                            DIcon {
                                name: "bolt"
                                size: Theme.iconSizeMedium
                                color: Theme.primary
                            }

                            StyledText {
                                text: "Quick Access"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Theme.fontWeightBold
                                color: Theme.surfaceText
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Style.spacingL

                            Repeater {
                                model: {
                                    const q = (VideoService.searchQuery || "").trim().toLowerCase();
                                    const list = root.quickAccessFolders || [];
                                    return q ? list.filter(c => c.toLowerCase().indexOf(q) !== -1) : list;
                                }
                                delegate: Item {
                                    id: qaFolderDelegate
                                    required property string modelData
                                    readonly property var albumVideos: {
                                        const all = (VideoService.galleryData && VideoService.galleryData.allVideos) ? VideoService.galleryData.allVideos : [];
                                        return all.filter(v => v.category === qaFolderDelegate.modelData);
                                    }
                                    width: 176
                                    height: 212

                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: Style.spacingS

                                        ClippingRectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 176
                                            radius: Style.cornerRadiusM
                                            color: Theme.surfaceContainerHigh
                                            border.color: qaFolderHover.hovered
                                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5)
                                                : M3E.stroke(Theme.outlineVariant, M3E.strokeControl)
                                            border.width: 1

                                            scale: qaFolderMouse.pressed ? M3E.tilePressScale : (qaFolderHover.hovered ? 1.02 : 1.0)
                                            Behavior on scale { DAnim { duration: M3E.spatialFastMs; easing.bezierCurve: M3E.curveFastSpatial } }

                                            HoverHandler { id: qaFolderHover }

                                            Grid {
                                                anchors.fill: parent
                                                columns: 2
                                                rows: 2
                                                spacing: 2
                                                readonly property real cellW: Math.floor((width - spacing) / 2)
                                                readonly property real cellH: Math.floor((height - spacing) / 2)

                                                Repeater {
                                                    model: 4
                                                    delegate: ClippingRectangle {
                                                        id: qaCellClip
                                                        width: parent.cellW
                                                        height: parent.cellH
                                                        radius: Style.cornerRadiusXS
                                                        color: Theme.surfaceContainerLowest
                                                        readonly property string thumbPath: {
                                                            const vids = qaFolderDelegate.albumVideos;
                                                            if (!vids || vids.length === 0) return "";
                                                            const v = index < vids.length ? vids[index] : vids[0];
                                                            return (v && v.thumbnail) ? v.thumbnail : "";
                                                        }
                                                        Image {
                                                            anchors.fill: parent
                                                            visible: qaCellClip.thumbPath !== ""
                                                            fillMode: Image.PreserveAspectCrop
                                                            asynchronous: true
                                                            cache: true
                                                            source: qaCellClip.thumbPath !== "" ? ("file://" + qaCellClip.thumbPath) : ""
                                                            sourceSize.width: 180
                                                            sourceSize.height: 180
                                                        }
                                                        DIcon {
                                                            anchors.centerIn: parent
                                                            visible: qaCellClip.thumbPath === ""
                                                            name: "movie"
                                                            size: Style.iconSize
                                                            color: Theme.surfaceVariantText
                                                        }
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: qaFolderMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.selectedFolderName = qaFolderDelegate.modelData
                                            }

                                            Rectangle {
                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.margins: 6
                                                width: 28
                                                height: 28
                                                radius: 14
                                                visible: qaFolderHover.hovered || true
                                                color: Theme.withAlpha(Theme.primary, 0.2)
                                                border.color: Theme.primary
                                                border.width: 1

                                                DIcon {
                                                    anchors.centerIn: parent
                                                    name: "keep"
                                                    size: 16
                                                    color: Theme.primary
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.toggleQuickAccessFolder(qaFolderDelegate.modelData)
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: qaFolderDelegate.modelData
                                                font.pixelSize: Theme.fontSizeMedium
                                                font.weight: Font.DemiBold
                                                color: Theme.surfaceText
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: qaFolderDelegate.albumVideos.length + " videos"
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                    }
                                }
                            }

                            // Empty album card with (+) to add folder
                            Item {
                                id: foldersAddCard
                                visible: false
                                width: 176
                                height: 176 + 36

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: Style.spacingS

                                    Rectangle {
                                        id: addPreviewBox
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 176
                                        radius: Style.cornerRadiusM
                                        color: addCardHover.hovered
                                            ? Theme.surfaceContainerHighest
                                            : Theme.surfaceContainerHigh
                                        border.color: addCardHover.hovered
                                            ? Theme.primary
                                            : M3E.stroke(Theme.outlineVariant, M3E.strokeControl)
                                        border.width: addCardHover.hovered ? Style.outlineWidth : 1

                                        scale: addCardMouse.pressed ? M3E.tilePressScale : (addCardHover.hovered ? 1.02 : 1.0)

                                        Behavior on scale { DAnim { duration: M3E.spatialFastMs; easing.bezierCurve: M3E.curveFastSpatial } }
                                        Behavior on color { DColorAnim { duration: M3E.effectsFastMs; easing.bezierCurve: M3E.curveFastEffects } }
                                        Behavior on border.color { DColorAnim { duration: M3E.effectsFastMs; easing.bezierCurve: M3E.curveFastEffects } }

                                        HoverHandler {
                                            id: addCardHover
                                        }

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 48
                                            height: 48
                                            radius: Style.cornerRadiusM
                                            color: addCardHover.hovered ? Theme.primaryContainer : Theme.surfaceContainerLowest
                                            border.color: addCardHover.hovered ? Theme.primary : M3E.stroke(Theme.outlineVariant, M3E.strokeControl)
                                            border.width: 1

                                            DIcon {
                                                anchors.centerIn: parent
                                                name: "add"
                                                size: 28
                                                color: addCardHover.hovered ? Theme.primary : Theme.surfaceVariantText
                                            }
                                        }

                                        MouseArea {
                                            id: addCardMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: VideoService.openAddFolderDialog()
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Style.spacingXXS

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: "Add Folder"
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Theme.fontWeightBold
                                            color: addCardHover.hovered ? Theme.primary : Theme.surfaceText
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: "Choose directory"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Folders Section
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.spacingM

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.spacingS

                            DIcon {
                                name: "folder"
                                size: Theme.iconSizeMedium
                                color: Theme.primary
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: "Folders"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Theme.fontWeightBold
                                color: Theme.surfaceText
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Style.spacingL

                            Repeater {
                                model: {
                                    const q = (VideoService.searchQuery || "").trim().toLowerCase();
                                    const list = (VideoService.galleryData && VideoService.galleryData.categories) ? VideoService.galleryData.categories.filter(c => c !== "All") : [];
                                    return q ? list.filter(c => c.toLowerCase().indexOf(q) !== -1) : list;
                                }

                                delegate: Item {
                                    id: folderDelegate
                                    required property string modelData
                                    readonly property var albumVideos: {
                                        const all = (VideoService.galleryData && VideoService.galleryData.allVideos) ? VideoService.galleryData.allVideos : [];
                                        return all.filter(v => v.category === folderDelegate.modelData);
                                    }
                                    width: 176
                                    height: 212

                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: Style.spacingS

                                        ClippingRectangle {
                                            id: albumPreviewBox
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 176
                                            radius: Style.cornerRadiusM
                                            color: Theme.surfaceContainerHigh
                                            border.color: folderHover.hovered
                                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5)
                                                : M3E.stroke(Theme.outlineVariant, M3E.strokeControl)
                                            border.width: 1

                                            scale: folderMouse.pressed ? M3E.tilePressScale : (folderHover.hovered ? 1.02 : 1.0)
                                            Behavior on scale { DAnim { duration: M3E.spatialFastMs; easing.bezierCurve: M3E.curveFastSpatial } }

                                            HoverHandler {
                                                id: folderHover
                                            }

                                            // 2x2 Grid of Previews
                                            Grid {
                                                anchors.fill: parent
                                                columns: 2
                                                rows: 2
                                                spacing: 2

                                                readonly property real cellW: Math.floor((width - spacing) / 2)
                                                readonly property real cellH: Math.floor((height - spacing) / 2)

                                                Repeater {
                                                    model: 4
                                                    delegate: ClippingRectangle {
                                                        id: videoCellClip
                                                        width: parent.cellW
                                                        height: parent.cellH
                                                        radius: Style.cornerRadiusXS
                                                        color: Theme.surfaceContainerLowest

                                                        readonly property string thumbPath: {
                                                            const vids = folderDelegate.albumVideos;
                                                            if (!vids || vids.length === 0) return "";
                                                            const v = index < vids.length ? vids[index] : vids[0];
                                                            return (v && v.thumbnail) ? v.thumbnail : "";
                                                        }

                                                        Image {
                                                            anchors.fill: parent
                                                            visible: videoCellClip.thumbPath !== ""
                                                            fillMode: Image.PreserveAspectCrop
                                                            asynchronous: true
                                                            cache: true
                                                            source: videoCellClip.thumbPath !== "" ? ("file://" + videoCellClip.thumbPath) : ""
                                                            sourceSize.width: 180
                                                            sourceSize.height: 180
                                                        }

                                                        DIcon {
                                                            anchors.centerIn: parent
                                                            visible: videoCellClip.thumbPath === ""
                                                            name: "movie"
                                                            size: Style.iconSize
                                                            color: Theme.surfaceVariantText
                                                        }
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: folderMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.selectedFolderName = folderDelegate.modelData
                                            }

                                            Rectangle {
                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.margins: 6
                                                width: 28
                                                height: 28
                                                radius: 14
                                                readonly property bool isPinned: root.quickAccessFolders.indexOf(folderDelegate.modelData) !== -1
                                                visible: folderHover.hovered || isPinned
                                                color: isPinned ? Theme.withAlpha(Theme.primary, 0.2) : Theme.withAlpha(Theme.surfaceContainerHighest, 0.85)
                                                border.color: isPinned ? Theme.primary : Theme.outlineVariant
                                                border.width: 1

                                                DIcon {
                                                    anchors.centerIn: parent
                                                    name: "keep"
                                                    size: 16
                                                    color: parent.isPinned ? Theme.primary : Theme.surfaceText
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.toggleQuickAccessFolder(folderDelegate.modelData)
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: folderDelegate.modelData
                                                font.pixelSize: Theme.fontSizeMedium
                                                font.weight: Font.DemiBold
                                                color: Theme.surfaceText
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: folderDelegate.albumVideos.length + " videos"
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                    }
                                }
                            }

                            // Empty album card with (+) to add folder
                            Item {
                                id: albumsAddCard
                                width: 176
                                height: 176 + 36

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: Style.spacingS

                                    Rectangle {
                                        id: albumsAddPreviewBox
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 176
                                        radius: Style.cornerRadiusM
                                        color: albumsAddCardHover.hovered
                                            ? Theme.surfaceContainerHighest
                                            : Theme.surfaceContainerHigh
                                        border.color: albumsAddCardHover.hovered
                                            ? Theme.primary
                                            : M3E.stroke(Theme.outlineVariant, M3E.strokeControl)
                                        border.width: albumsAddCardHover.hovered ? Style.outlineWidth : 1

                                        scale: addCardMouse.pressed ? M3E.tilePressScale : (albumsAddCardHover.hovered ? 1.02 : 1.0)

                                        Behavior on scale { DAnim { duration: M3E.spatialFastMs; easing.bezierCurve: M3E.curveFastSpatial } }
                                        Behavior on color { DColorAnim { duration: M3E.effectsFastMs; easing.bezierCurve: M3E.curveFastEffects } }
                                        Behavior on border.color { DColorAnim { duration: M3E.effectsFastMs; easing.bezierCurve: M3E.curveFastEffects } }

                                        HoverHandler {
                                            id: albumsAddCardHover
                                        }

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 48
                                            height: 48
                                            radius: Style.cornerRadiusM
                                            color: albumsAddCardHover.hovered ? Theme.primaryContainer : Theme.surfaceContainerLowest
                                            border.color: albumsAddCardHover.hovered ? Theme.primary : M3E.stroke(Theme.outlineVariant, M3E.strokeControl)
                                            border.width: 1

                                            DIcon {
                                                anchors.centerIn: parent
                                                name: "add"
                                                size: 28
                                                color: albumsAddCardHover.hovered ? Theme.primary : Theme.surfaceVariantText
                                            }
                                        }

                                        MouseArea {
                                            id: albumsAddCardMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: VideoService.openAddFolderDialog()
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Style.spacingXXS

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: "Add Folder"
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Theme.fontWeightBold
                                            color: addCardHover.hovered ? Theme.primary : Theme.surfaceText
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: "Choose directory"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Sub-view: Video Grid (visible in All, or when a folder/playlist is selected)
            Item {
                id: videoGridContainer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: (sectionHeaderBar.visible ? sectionHeaderBar.bottom : parent.top)
                anchors.bottom: parent.bottom
                visible: root.currentSection === "all" || root.selectedFolderName !== "" || root.selectedPlaylistObj !== null

                // Loading state
                Item {
                    anchors.centerIn: parent
                    visible: VideoService.isGalleryLoading && (!VideoService.galleryData || !VideoService.galleryData.allVideos || VideoService.galleryData.allVideos.length === 0)

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingM

                        DIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: "hourglass_empty"
                            size: 48
                            color: Theme.primary
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Scanning video library..."
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                        }
                    }
                }

                // Empty state
                Item {
                    anchors.centerIn: parent
                    visible: !VideoService.isGalleryLoading && root.filteredVideos.length === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingM
                        width: 320

                        DIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: "video_library"
                            size: 56
                            color: Theme.withAlpha(Theme.surfaceVariantText, 0.4)
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No videos found"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.DemiBold
                            color: Theme.surfaceText
                        }

                        StyledText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "Add folders to scan in Settings -> Library & folders, or open a video directly."
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Theme.spacingM

                            DButton {
                                text: "Open Video"
                                iconName: "folder_open"
                                onClicked: VideoService.openFileDialog()
                            }

                            DButton {
                                text: "Manage Folders"
                                iconName: "settings"
                                onClicked: VideoService.settingsOpen = true
                            }
                        }
                    }
                }
                // Top-center floating refresh indicator (Android Chrome style)
                DLoadingIndicator {
                    contained: true
                    visible: VideoService.isGalleryLoading
                    anchors.top: parent.top
                    anchors.topMargin: sectionHeaderBar.visible ? 120 : 72
                    anchors.horizontalCenter: parent.horizontalCenter
                    z: 20
                }

                // Video Grid View with equal left/right gaps
                GridView {
                    id: videoGridView
                    readonly property real gridGap: Theme.spacingM
                    readonly property real availW: Math.max(100, mainContentCard.width - Theme.spacingM * 2)
                    readonly property int cols: Math.max(1, Math.floor((availW + gridGap) / (root.gridItemSize + gridGap)))
                    readonly property real actualTileSize: (availW - (cols - 1) * gridGap) / cols

                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingM
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.spacingM
                    width: availW + gridGap
                    topMargin: root.currentSection === "all" ? 68 : 0
                    cellWidth: actualTileSize + gridGap
                    cellHeight: actualTileSize + gridGap
                    clip: true
                    maximumFlickVelocity: 4500
                    flickDeceleration: 2200
                    visible: !root.groupByDate && root.filteredVideos.length > 0
                    model: root.filteredVideos

                    Behavior on contentY {
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y * 1.8 : (event.angleDelta.y / 120) * 180;
                            const maxY = Math.max(0, videoGridView.contentHeight - videoGridView.height);
                            videoGridView.contentY = Math.max(0, Math.min(maxY, videoGridView.contentY - delta));
                            event.accepted = true;
                        }
                    }

                    delegate: VideoGalleryThumbnail {
                        itemSize: videoGridView.actualTileSize
                        isFirstInGroup: (index % Math.max(1, videoGridView.cols)) === 0
                        isLastInGroup: (index % Math.max(1, videoGridView.cols)) === Math.max(1, videoGridView.cols) - 1 || index === videoGridView.count - 1
                    }

                    displaced: Transition {
                        NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic }
                    }
                    move: Transition {
                        NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic }
                    }
                    add: Transition {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
                    }
                    remove: Transition {
                        NumberAnimation { property: "opacity"; to: 0; duration: 150; easing.type: Easing.OutCubic }
                    }
                }

                // Date-Grouped Video View
                DListView {
                    id: groupedVideoList
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: sectionHeaderBar.visible ? 124 : 76
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.spacingM
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingM
                    topMargin: 0
                    spacing: Theme.spacingL
                    clip: true
                    maximumFlickVelocity: 4500
                    flickDeceleration: 2200
                    visible: root.groupByDate && root.filteredVideos.length > 0
                    model: root.groupedVideos

                    delegate: Column {
                        id: grpCol
                        required property var modelData
                        width: groupedVideoList.width
                        height: implicitHeight
                        spacing: Theme.spacingS

                        StyledText {
                            text: grpCol.modelData.title
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.DemiBold
                            color: Theme.surfaceText
                        }

                        Grid {
                            width: parent.width
                            columns: videoGridView.cols
                            columnSpacing: videoGridView.gridGap
                            rowSpacing: videoGridView.gridGap

                            Repeater {
                                model: grpCol.modelData.items
                                delegate: VideoGalleryThumbnail {
                                    itemSize: videoGridView.actualTileSize
                                    isFirstInGroup: (index % Math.max(1, videoGridView.cols)) === 0
                                    isLastInGroup: (index % Math.max(1, videoGridView.cols)) === Math.max(1, videoGridView.cols) - 1 || index === grpCol.modelData.items.length - 1
                                }
                            }
                        }
                    }
                }
            }

            // Floating M3E Search Bar + Segmented Buttons (Refresh -> Search -> Filter | Open)
            Item {
                id: searchBarGroup
                    readonly property int expandedSearchWidth: Math.min(340, mainContentCard.width - refreshPill.width - filterPill.width - openFilePill.width - 64)
                    readonly property int collapsedSearchWidth: 48
                    readonly property bool isCollapsed: {
                        const cy = videoGridView.visible ? videoGridView.contentY
                            : (groupedVideosListView.visible ? groupedVideosListView.contentY
                            : (foldersGridView.visible ? foldersGridView.contentY : playlistsListView.contentY));
                        return cy > 24 && !searchBoxInput.activeFocus && VideoService.searchQuery === "";
                    }
                    property real pillGap: isCollapsed ? Math.max(2, Math.round(Theme.spacingXS * 0.5)) : Theme.spacingS
                    readonly property real totalWidth: refreshPill.width + pillGap + (isCollapsed ? collapsedSearchWidth : expandedSearchWidth) + pillGap + filterPill.width + pillGap + openFilePill.width

                    Behavior on pillGap {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }

                    // In-window backdrop blur behind floating search & pills
                    ShaderEffectSource {
                        id: vSearchBackdropSource
                        readonly property Item backdropItem: videoGridView.visible ? videoGridView : groupedVideoList
                        sourceItem: backdropItem
                        sourceRect: Qt.rect(searchBarGroup.x - backdropItem.x, searchBarGroup.y - backdropItem.y, searchBarGroup.width, searchBarGroup.height)
                        visible: false
                        live: true
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: vSearchBackdropSource
                        blurEnabled: true
                        blur: 1.0
                        blurMax: 64
                        visible: true
                        z: -1
                    }

                    anchors.top: parent.top
                    anchors.topMargin: sectionHeaderBar.visible ? 64 : 16
                    anchors.right: parent.right
                    anchors.rightMargin: isCollapsed ? 16 : Math.max(16, Math.round((mainContentCard.width - totalWidth) / 2))
                    width: totalWidth
                    height: 48
                    z: 30

                    Behavior on anchors.rightMargin {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutCubic
                        }
                    }

                    // 1. Refresh Button (First - Segmented First)
                    Rectangle {
                        id: refreshPill
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 48
                        height: 48
                        readonly property bool isPillActive: VideoService.isGalleryLoading || vRefreshMouse.pressed || vRefreshMouse.containsMouse
                        topLeftRadius: 24
                        bottomLeftRadius: 24
                        topRightRadius: isPillActive ? 24 : 6
                        bottomRightRadius: isPillActive ? 24 : 6
                        Behavior on topRightRadius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on bottomRightRadius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        color: isPillActive
                            ? Theme.withAlpha(Theme.primary, 0.25)
                            : Theme.withAlpha(Theme.surfaceContainerHigh, 0.48)
                        border.color: isPillActive ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                        border.width: 1
                        scale: vRefreshMouse.pressed ? 0.94 : (vRefreshMouse.containsMouse ? 1.08 : 1.0)

                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        DRipple {
                            cornerRadius: 24
                            rippleColor: Theme.primary
                            anchors.fill: parent
                        }

                        DIcon {
                            anchors.centerIn: parent
                            name: "refresh"
                            size: 20
                            color: Theme.surfaceText
                            visible: !VideoService.isGalleryLoading
                        }

                        DLoadingIndicator {
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            visible: VideoService.isGalleryLoading
                        }

                        DTooltipHost { anchors.fill: parent; text: "Rescan library" }

                        MouseArea {
                            id: vRefreshMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: VideoService.rescan()
                        }
                    }

                    // 2. Search Pill (Middle)
                    Rectangle {
                        id: searchPill
                        readonly property bool isCollapsed: searchBarGroup.isCollapsed

                        anchors.left: refreshPill.right
                        anchors.leftMargin: searchBarGroup.pillGap
                        anchors.top: parent.top
                        width: isCollapsed ? searchBarGroup.collapsedSearchWidth : searchBarGroup.expandedSearchWidth
                        height: 48
                        topLeftRadius: isCollapsed ? 6 : 24
                        bottomLeftRadius: isCollapsed ? 6 : 24
                        topRightRadius: isCollapsed ? 6 : 24
                        bottomRightRadius: isCollapsed ? 6 : 24
                        Behavior on topLeftRadius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on bottomLeftRadius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on topRightRadius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on bottomRightRadius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        color: searchBoxInput.activeFocus
                            ? Theme.withAlpha(Theme.surfaceContainerHighest, 0.62)
                            : ((isCollapsed && vCollapsedMouse.containsMouse) ? Theme.withAlpha(Theme.surfaceContainerHighest, 0.62) : Theme.withAlpha(Theme.surfaceContainerHigh, 0.48))
                        border.color: searchBoxInput.activeFocus ? Theme.primary : ((isCollapsed && vCollapsedMouse.containsMouse) ? Theme.primary : M3E.stroke(Theme.outlineVariant, M3E.strokeSurface))
                        border.width: searchBoxInput.activeFocus ? 2 : 1
                        clip: true

                        Behavior on width {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on color { DColorAnim { duration: M3E.effectsFastMs; easing.bezierCurve: M3E.curveFastEffects } }
                        Behavior on border.color { DColorAnim { duration: M3E.effectsFastMs; easing.bezierCurve: M3E.curveFastEffects } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 10
                            spacing: 6

                            DIcon {
                                name: "search"
                                size: 20
                                color: searchBoxInput.activeFocus ? Theme.primary : Theme.surfaceVariantText
                            }

                            TextInput {
                                id: searchBoxInput
                                Layout.fillWidth: true
                                verticalAlignment: TextInput.AlignVCenter
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                text: VideoService.searchQuery
                                opacity: searchPill.isCollapsed ? 0 : 1
                                visible: !searchPill.isCollapsed
                                onTextChanged: VideoService.searchQuery = text

                                StyledText {
                                    anchors.fill: parent
                                    text: "Search videos..."
                                    color: Theme.withAlpha(Theme.surfaceVariantText, 0.6)
                                    font.pixelSize: Theme.fontSizeMedium
                                    verticalAlignment: Text.AlignVCenter
                                    visible: !searchBoxInput.text && !searchBoxInput.activeFocus
                                }
                            }

                            DIconButton {
                                visible: !searchPill.isCollapsed && !!searchBoxInput.text
                                iconName: "close"
                                size: "xs"
                                variant: "standard"
                                onClicked: searchBoxInput.text = ""
                            }
                        }

                        MouseArea {
                            id: vCollapsedMouse
                            anchors.fill: parent
                            visible: searchPill.isCollapsed
                            enabled: searchPill.isCollapsed
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: searchBoxInput.forceActiveFocus()
                        }
                    }

                    // 3. Filter Button (Middle - Separate Container)
                    Rectangle {
                        id: filterPill
                        anchors.right: openFilePill.left
                        anchors.rightMargin: searchBarGroup.pillGap
                        anchors.verticalCenter: parent.verticalCenter
                        width: 48
                        height: 48
                        readonly property bool isPillActive: videoFilterDialog.opened || vFilterMouse.pressed || vFilterMouse.containsMouse
                        radius: isPillActive ? 24 : 6
                        Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        color: isPillActive ? Theme.withAlpha(Theme.primary, 0.25) : Theme.withAlpha(Theme.surfaceContainerHigh, 0.48)
                        border.color: isPillActive ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                        border.width: 1
                        scale: vFilterMouse.pressed ? 0.94 : (vFilterMouse.containsMouse ? 1.08 : 1.0)

                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        DRipple {
                            cornerRadius: 6
                            rippleColor: Theme.primary
                            anchors.fill: parent
                        }

                        DIcon {
                            anchors.centerIn: parent
                            name: "filter_list"
                            size: 20
                            color: (root.sortOrder !== "newest" || root.dateFilter !== "all" || root.groupByDate) ? Theme.primary : Theme.surfaceText
                        }

                        Rectangle {
                            visible: root.sortOrder !== "newest" || root.dateFilter !== "all"
                            width: 7
                            height: 7
                            radius: 3.5
                            anchors.top: parent.top
                            anchors.topMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            color: Theme.primary
                        }

                        DTooltipHost { anchors.fill: parent; text: "Filter & Sort" }

                        MouseArea {
                            id: vFilterMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: videoFilterDialog.open()
                        }
                    }

                    // 4. Open File Button (Last - Separate Container)
                    Rectangle {
                        id: openFilePill
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 48
                        height: 48
                        readonly property bool isPillActive: vOpenMouse.pressed || vOpenMouse.containsMouse
                        topLeftRadius: isPillActive ? 24 : 6
                        bottomLeftRadius: isPillActive ? 24 : 6
                        topRightRadius: 24
                        bottomRightRadius: 24
                        Behavior on topLeftRadius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on bottomLeftRadius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        color: vOpenMouse.containsMouse
                            ? Theme.withAlpha(Theme.primary, 0.25)
                            : Theme.withAlpha(Theme.surfaceContainerHigh, 0.48)
                        border.color: vOpenMouse.containsMouse ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                        border.width: 1
                        scale: vOpenMouse.pressed ? 0.94 : (vOpenMouse.containsMouse ? 1.08 : 1.0)

                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        DRipple {
                            cornerRadius: 24
                            rippleColor: Theme.primary
                            anchors.fill: parent
                        }

                        DIcon {
                            anchors.centerIn: parent
                            name: "folder_open"
                            size: 20
                            color: Theme.surfaceText
                        }

                        DTooltipHost { anchors.fill: parent; text: "Open file" }

                        MouseArea {
                            id: vOpenMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: VideoService.openFileDialog()
                        }
                }


        }
    }
    // Live Filter & Sort Floating Window (All Videos)
    VideoFilterSortDialog {
        id: videoFilterDialog
        dateFilter: root.dateFilter
        sortOrder: root.sortOrder
        gridItemSize: root.gridItemSize
        groupByDate: root.groupByDate
        includeHidden: root.includeHidden
        onIncludeHiddenToggled: val => root.includeHidden = val
        onDateFilterSelected: val => root.dateFilter = val
        onSortOrderSelected: val => root.sortOrder = val
        onItemSizeSelected: val => root.gridItemSize = val
        onGroupByDateToggled: val => SettingsData.videoGroupByDate = val
        onResetRequested: {
            root.dateFilter = "all";
            root.sortOrder = "newest";
            root.gridItemSize = 184;
            SettingsData.videoGroupByDate = false;
        }
    }

    // New Playlist Modal Dialog
    Rectangle {
        id: newPlaylistDialog
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.4)
        visible: false
        z: 100

        function open() {
            playlistNameInput.text = "";
            visible = true;
            playlistNameInput.forceActiveFocus();
        }

        function close() {
            visible = false;
        }

        MouseArea {
            anchors.fill: parent
            onClicked: newPlaylistDialog.close()
        }

        Rectangle {
            anchors.centerIn: parent
            width: 340
            implicitHeight: plCol.implicitHeight + Theme.spacingL * 2
            radius: Theme.cornerRadiusXL
            color: Theme.foregroundColor(Theme.surfaceContainerHigh, true)
            border.color: Theme.withAlpha(Theme.outlineVariant, 0.3)
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: plCol
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                StyledText {
                    text: "Create New Playlist"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                    color: Theme.surfaceText
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 20
                    color: Theme.surfaceContainerHighest
                    border.color: playlistNameInput.activeFocus ? Theme.primary : Theme.withAlpha(Theme.outlineVariant, 0.3)
                    border.width: 1

                    TextInput {
                        id: playlistNameInput
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        clip: true

                        StyledText {
                            anchors.fill: parent
                            text: "Playlist name..."
                            color: Theme.withAlpha(Theme.surfaceVariantText, 0.6)
                            font.pixelSize: Theme.fontSizeMedium
                            verticalAlignment: Text.AlignVCenter
                            visible: !playlistNameInput.text && !playlistNameInput.activeFocus
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    Item { Layout.fillWidth: true }

                    DButton {
                        text: "Cancel"
                        backgroundColor: "transparent"
                        textColor: Theme.primary
                        onClicked: newPlaylistDialog.close()
                    }

                    DButton {
                        text: "Create"
                        backgroundColor: Theme.primary
                        textColor: Theme.onPrimary
                        onClicked: {
                            const name = playlistNameInput.text.trim();
                            if (name) {
                                VideoService.createCustomPlaylist(name);
                                newPlaylistDialog.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
}
