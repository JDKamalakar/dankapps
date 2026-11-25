import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets
import qs.Services

DuxFloatingWindow {
    id: win

    title: "Game Hub - Harmony"
    width: 1200
    height: 780
    color: Theme.windowSurface
    surfaceFormat.opaque: false

    WindowBlur {
        targetWindow: win
        blurEnabled: Theme.translucentWindows
        blurWidth: win.width
        blurHeight: win.height
    }

    property var widgetRoot: null
    readonly property var gameList: widgetRoot ? widgetRoot.gameList : []
    readonly property bool isScanning: widgetRoot ? widgetRoot.isScanning : false
    readonly property int totalCount: widgetRoot ? widgetRoot.totalGamesCount : 0
    readonly property bool isFetchingMeta: widgetRoot ? widgetRoot.isFetchingMeta : false
    readonly property real metaProgressFraction: widgetRoot ? widgetRoot.metaProgressFraction : 0
    readonly property string metaCurrentTitle: widgetRoot ? widgetRoot.metaCurrentTitle : ""
    readonly property int metaProgressDone: widgetRoot ? widgetRoot.metaProgressDone : 0
    readonly property int metaProgressTotal: widgetRoot ? widgetRoot.metaProgressTotal : 0
    readonly property string metaPhase: widgetRoot ? widgetRoot.metaPhase : ""
    readonly property string metaPhaseLabel: widgetRoot ? widgetRoot.metaPhaseLabel : "Fetch Metadata"

    property bool showSettingsOverlay: false
    property var selectedGame: null
    property string activeNavCategory: "All"

    // Fullscreen photo viewer overlay properties
    property bool showPhotoViewer: false
    property var fullscreenPhotoList: []
    property int fullscreenPhotoIndex: 0

    onVisibleChanged: {
        if (visible && mainGridView) {
            Qt.callLater(mainGridView.ensureFocused);
        }
    }

    onShowSettingsOverlayChanged: {
        if (!showSettingsOverlay) {
            // Unload or clear active focus from settings modal and restore focus to main game grid
            if (mainGridView) {
                mainGridView.ensureFocused();
            } else {
                win.forceActiveFocus();
            }
        }
    }

    function collapseHub() {
        if (hubContainer.isExpanded) hubContainer.isExpanded = false;
    }
    function tuckFilterBar() {
        if (!filterBarContainer.isTucked) filterBarContainer.isTucked = true;
    }

    function openMetadataEditor(game) {
        if (metaEditorOverlay) metaEditorOverlay.openForGame(game);
    }

    // Keyboard Shortcuts
    Shortcut {
        sequence: "Escape"
        enabled: win.visible
        onActivated: {
            if (mainGridView && mainGridView.isContextMenuOpen) {
                mainGridView.closeContextMenu();
            } else if (metaEditorOverlay && metaEditorOverlay.visible) {
                metaEditorOverlay.close();
            } else if (win.selectedGame !== null) {
                win.selectedGame = null;
            } else if (win.showSettingsOverlay) {
                win.showSettingsOverlay = false;
            }
        }
    }

    Shortcut {
        sequences: [StandardKey.Find, "Ctrl+F"]
        enabled: win.visible && !win.showSettingsOverlay && win.selectedGame === null
        onActivated: searchInputWin.forceActiveFocus()
    }

    // Window-level Arrow Key navigation for Grid (active when search box is not focused)
    readonly property bool canGridNavigate: win.visible && !win.showSettingsOverlay && win.selectedGame === null && !searchInputWin.activeFocus && (!metaEditorOverlay || !metaEditorOverlay.visible)

    Shortcut {
        sequence: "Left"
        enabled: win.canGridNavigate
        onActivated: if (mainGridView) mainGridView.moveLeft()
    }

    Shortcut {
        sequence: "Right"
        enabled: win.canGridNavigate
        onActivated: if (mainGridView) mainGridView.moveRight()
    }

    Shortcut {
        sequence: "Up"
        enabled: win.canGridNavigate
        onActivated: if (mainGridView) mainGridView.moveUp()
    }

    Shortcut {
        sequence: "Down"
        enabled: win.canGridNavigate
        onActivated: if (mainGridView) mainGridView.moveDown()
    }

    Shortcut {
        sequence: "Return"
        enabled: win.canGridNavigate
        onActivated: if (mainGridView) mainGridView.activateCurrent()
    }

    Shortcut {
        sequence: "Enter"
        enabled: win.canGridNavigate
        onActivated: if (mainGridView) mainGridView.activateCurrent()
    }

    function safeParseInt(val, fallback) {
        if (val === undefined || val === null || val === "") return fallback;
        let parsed = parseInt(val);
        return isNaN(parsed) ? fallback : parsed;
    }

    property string themeMode: PluginService.loadPluginData("fullscreenGameHub", "windowThemeMode", "dark")
    property int autoHideDelaySec: PluginService.loadPluginData("fullscreenGameHub", "autoHideDelay", 1)
    property int gridCardsPerRow: Math.max(4, Math.min(10, safeParseInt(PluginService.loadPluginData("fullscreenGameHub", "gridCardsPerRow", 6), 6)))
    property int gridCornerRadius: Math.max(0, Math.min(32, safeParseInt(PluginService.loadPluginData("fullscreenGameHub", "gridCornerRadius", 16), 16)))
    property int gridCardGap: Math.max(4, Math.min(28, safeParseInt(PluginService.loadPluginData("fullscreenGameHub", "gridCardGap", 12), 12)))
    property bool gridShowTitle: {
        let v = PluginService.loadPluginData("fullscreenGameHub", "gridShowTitle", true);
        return v === true || v === "true";
    }

    // Controller: Home button launches hub (requires controllerHomeEnabled setting)
    property bool controllerHomeEnabled: {
        let v = PluginService.loadPluginData("fullscreenGameHub", "controllerHomeEnabled", false);
        return v === true || v === "true";
    }

    property bool windowTransparency: {
        let val = PluginService.loadPluginData("fullscreenGameHub", "windowTransparency", false);
        return val === true || val === "true";
    }

    // Detail view layout mode: "side_by_side" or "fullscreen"
    property string detailPositionMode: PluginService.loadPluginData("fullscreenGameHub", "detailPositionMode", "side_by_side")
    // Side-by-side detail width percentage: 30, 50, or 70
    property int detailSideSize: Math.max(30, Math.min(70, safeParseInt(PluginService.loadPluginData("fullscreenGameHub", "detailSideSize", 50), 50)))
    readonly property bool isFullPageDetailActive: win.selectedGame !== null && win.detailPositionMode === "fullscreen"

    // React to global var changes (fired by Settings when user changes theme, delay, or grid)
    PluginGlobalVar {
        varName: "windowThemeMode"
        onValueChanged: (val) => {
            if (val !== undefined && val !== null && val !== "") {
                win.themeMode = val;
            }
        }
    }

    PluginGlobalVar {
        varName: "windowTransparency"
        onValueChanged: (val) => {
            if (val !== undefined && val !== null) {
                win.windowTransparency = val === true || val === "true";
            }
        }
    }

    PluginGlobalVar {
        varName: "detailPositionMode"
        onValueChanged: (val) => {
            if (val !== undefined && val !== null && val !== "") {
                win.detailPositionMode = val;
            }
        }
    }

    PluginGlobalVar {
        varName: "detailSideSize"
        onValueChanged: (val) => {
            if (val !== undefined && val !== null) {
                win.detailSideSize = Math.max(30, Math.min(70, safeParseInt(val, 50)));
            }
        }
    }

    PluginGlobalVar {
        varName: "autoHideDelay"
        onValueChanged: (val) => {
            if (val !== undefined && val !== null) {
                win.autoHideDelaySec = Math.max(1, safeParseInt(val, 1));
            }
        }
    }

    PluginGlobalVar {
        varName: "gridCardsPerRow"
        onValueChanged: (val) => {
            if (val !== undefined && val !== null) {
                win.gridCardsPerRow = Math.max(4, Math.min(10, safeParseInt(val, 6)));
            }
        }
    }

    PluginGlobalVar {
        varName: "gridCornerRadius"
        onValueChanged: (val) => {
            if (val !== undefined && val !== null) {
                win.gridCornerRadius = Math.max(0, Math.min(32, safeParseInt(val, 16)));
            }
        }
    }

    PluginGlobalVar {
        varName: "gridCardGap"
        onValueChanged: (val) => {
            if (val !== undefined && val !== null) {
                win.gridCardGap = Math.max(4, Math.min(28, safeParseInt(val, 12)));
            }
        }
    }

    PluginGlobalVar {
        varName: "gridShowTitle"
        onValueChanged: (val) => {
            if (val !== undefined && val !== null) {
                win.gridShowTitle = val === true || val === "true";
            }
        }
    }

    PluginGlobalVar {
        varName: "controllerHomeEnabled"
        onValueChanged: (val) => {
            if (val !== undefined && val !== null) {
                win.controllerHomeEnabled = val === true || val === "true";
            }
        }
    }

    Connections {
        target: PluginService
        ignoreUnknownSignals: true
        function onPluginDataChanged(pId) {
            if (pId === "fullscreenGameHub") {
                win.themeMode = PluginService.loadPluginData("fullscreenGameHub", "windowThemeMode", "dark");
                let wt = PluginService.loadPluginData("fullscreenGameHub", "windowTransparency", false);
                win.windowTransparency = wt === true || wt === "true";
                win.detailPositionMode = PluginService.loadPluginData("fullscreenGameHub", "detailPositionMode", "side_by_side");
                win.detailSideSize = Math.max(30, Math.min(70, safeParseInt(PluginService.loadPluginData("fullscreenGameHub", "detailSideSize", 50), 50)));
                win.autoHideDelaySec = PluginService.loadPluginData("fullscreenGameHub", "autoHideDelay", 1);
                win.gridCardsPerRow = Math.max(4, Math.min(10, safeParseInt(PluginService.loadPluginData("fullscreenGameHub", "gridCardsPerRow", 6), 6)));
                win.gridCornerRadius = Math.max(0, Math.min(32, safeParseInt(PluginService.loadPluginData("fullscreenGameHub", "gridCornerRadius", 16), 16)));
                win.gridCardGap = Math.max(4, Math.min(28, safeParseInt(PluginService.loadPluginData("fullscreenGameHub", "gridCardGap", 12), 12)));
                let gt = PluginService.loadPluginData("fullscreenGameHub", "gridShowTitle", true);
                win.gridShowTitle = gt === true || gt === "true";
                let cv = PluginService.loadPluginData("fullscreenGameHub", "controllerHomeEnabled", false);
                win.controllerHomeEnabled = cv === true || cv === "true";
            }
        }
        function onGlobalVarChanged(pId, varName) {
            if (pId === "fullscreenGameHub") {
                if (varName === "windowThemeMode") {
                    win.themeMode = PluginService.loadPluginData("fullscreenGameHub", "windowThemeMode", "dark");
                } else if (varName === "windowTransparency") {
                    let wt = PluginService.loadPluginData("fullscreenGameHub", "windowTransparency", false);
                    win.windowTransparency = wt === true || wt === "true";
                } else if (varName === "detailPositionMode") {
                    win.detailPositionMode = PluginService.loadPluginData("fullscreenGameHub", "detailPositionMode", "side_by_side");
                } else if (varName === "detailSideSize") {
                    win.detailSideSize = Math.max(30, Math.min(70, safeParseInt(PluginService.loadPluginData("fullscreenGameHub", "detailSideSize", 50), 50)));
                } else if (varName === "autoHideDelay") {
                    win.autoHideDelaySec = PluginService.loadPluginData("fullscreenGameHub", "autoHideDelay", 1);
                } else if (varName === "gridCardsPerRow") {
                    win.gridCardsPerRow = Math.max(4, Math.min(10, safeParseInt(PluginService.loadPluginData("fullscreenGameHub", "gridCardsPerRow", 6), 6)));
                } else if (varName === "gridCornerRadius") {
                    win.gridCornerRadius = Math.max(0, Math.min(32, safeParseInt(PluginService.loadPluginData("fullscreenGameHub", "gridCornerRadius", 16), 16)));
                } else if (varName === "gridCardGap") {
                    win.gridCardGap = Math.max(4, Math.min(28, safeParseInt(PluginService.loadPluginData("fullscreenGameHub", "gridCardGap", 12), 12)));
                } else if (varName === "gridShowTitle") {
                    let gt = PluginService.loadPluginData("fullscreenGameHub", "gridShowTitle", true);
                    win.gridShowTitle = gt === true || gt === "true";
                } else if (varName === "controllerHomeEnabled") {
                    let cv = PluginService.loadPluginData("fullscreenGameHub", "controllerHomeEnabled", false);
                    win.controllerHomeEnabled = cv === true || cv === "true";
                }
            }
        }
    }

    // Dynamic Theme Palette Constants
    // isLight is a binding: re-evaluates whenever themeMode or Theme.isLightMode changes
    readonly property bool isLight: {
        if (themeMode === "light") return true;
        if (themeMode === "dark") return false;
        // system: follow the shell theme
        return (typeof Theme !== "undefined" && Theme.isLightMode === true);
    }
    readonly property color cBgSolid: Theme.surfaceContainer
    readonly property color cBg: Theme.windowSurface
    readonly property color cSidebar: Theme.foregroundColor(Theme.surfaceContainerHigh, true)
    readonly property color cCardBg: Theme.foregroundColor(Theme.surfaceContainer, true)
    readonly property color cCardHover: Theme.surfaceContainerHighest
    readonly property color cAccent: Theme.primary
    readonly property color cTextMain: Theme.surfaceText
    readonly property color cTextSub: Theme.surfaceVariantText
    readonly property color cBorderSub: Theme.withAlpha(Theme.outlineVariant, 0.25)

    // Window floating state detection (in tiled mode on Niri, match is-floating=false)
    readonly property bool isFloatingWindow: {
        if (typeof CompositorService !== "undefined" && CompositorService.isNiri && typeof NiriService !== "undefined" && NiriService.windows) {
            const currentWin = (NiriService.windows || []).find(w => w.title === win.title);
            if (currentWin) {
                return currentWin.is_floating === true;
            }
        }
        return false;
    }

    function getPlatformIcon(launcher) {
        if (!launcher) return "";
        let l = launcher.toString().toLowerCase();
        if (l === "steam") return "assets/icons/Steam_logo.svg";
        if (l === "epic" || l === "epic games" || l.includes("epic")) return "assets/icons/Epic_Games_logo.svg";
        if (l === "gog" || l.includes("gog")) return "assets/icons/GOG_logo.svg";
        if (l === "ea" || l.includes("electronic arts")) return "assets/icons/Electronic-Arts-Logo.svg";
        if (l === "ubisoft" || l.includes("ubisoft")) return "assets/icons/Ubisoft_logo.svg";
        if (l.includes("playstation")) return "assets/icons/Playstation_logo.svg";
        if (l.includes("xbox")) return "assets/icons/Xbox_logo.svg";
        if (l.includes("prime") || l.includes("amazon")) return "assets/icons/Prime_gaming_logo.svg";
        if (l.includes("luna")) return "assets/icons/Amazon_Luna_logo.svg";
        if (l.includes("rockstar")) return "assets/icons/Rockstar_Games_Logo.svg";
        return "";
    }

    function getPlatformMaterialIcon(launcher) {
        if (!launcher) return "extension";
        let l = launcher.toString().toLowerCase();
        if (l === "all") return "grid_view";
        if (l === "installed") return "check_circle";
        if (l === "steam") return "sports_esports";
        if (l.includes("epic")) return "flash_on";
        if (l.includes("gog")) return "star";
        if (l === "bottles") return "local_bar";
        if (l === "lutris") return "extension";
        if (l.includes("ea")) return "sports_esports";
        if (l.includes("ubisoft")) return "gamepad";
        return "extension";
    }

    // Main Backdrop
    Rectangle {
        anchors.fill: parent
        color: win.cBg

        // Click outside on background: instantly tuck filter bar & collapse hub container
        MouseArea {
            anchors.fill: parent
            z: 0
            onClicked: {
                if (!filterBarContainer.isTucked) filterBarContainer.isTucked = true;
                if (hubContainer.isExpanded) hubContainer.isExpanded = false;
                if (mainGridView) mainGridView.ensureFocused();
            }
        }

        // ── LEFT SEGMENTED SIDEBAR ────────────────────────────────────────
        MouseArea {
            anchors.fill: parent
            z: 45
            visible: SettingsData.sidebarFloating && gameHubSidebar._floatingRevealed
            onPressed: mouse => {
                gameHubSidebar._floatingRevealed = false;
                mouse.accepted = false;
            }
        }

        Item {
            id: gameHubSidebar
            property bool _floatingRevealed: true
            readonly property bool _isHidden: SettingsData.sidebarFloating && !_floatingRevealed
            z: 50
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: win.isFullPageDetailActive ? 0 : (SettingsData.sidebarFloating ? (_isHidden ? 16 : gameHubNav.railWidth + Theme.spacingM * 2 + Theme.spacingS) : gameHubNav.railWidth)
            visible: !win.isFullPageDetailActive
            clip: true

            Behavior on width { enabled: Theme.animationsEnabled; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            HoverHandler {
                id: gameHubSidebarHover
                onHoveredChanged: {
                    if (hovered) {
                        gameHubSidebar._floatingRevealed = true;
                        gameHubHideTimer.stop();
                    } else if (SettingsData.sidebarFloating) {
                        gameHubHideTimer.restart();
                    }
                }
            }

            Timer {
                id: gameHubHideTimer
                interval: SettingsData.sidebarAutoHideMs || 1500
                onTriggered: {
                    if (SettingsData.sidebarFloating && !gameHubSidebarHover.hovered)
                        gameHubSidebar._floatingRevealed = false;
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
                opacity: gameHubSidebar._isHidden ? 0 : 1
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
                id: gameHubSidebarCol
                opacity: gameHubSidebar._isHidden ? 0 : 1
                Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                anchors.fill: parent
                anchors.topMargin: Theme.spacingM + (SettingsData.sidebarFloating ? 12 : 0)
                anchors.bottomMargin: Theme.spacingM + (SettingsData.sidebarFloating ? 12 : 0)
                anchors.leftMargin: SettingsData.sidebarFloating ? Theme.spacingL : Theme.spacingM
                anchors.rightMargin: SettingsData.sidebarFloating ? Theme.spacingL : 0
                spacing: Theme.spacingS

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: SettingsData.sidebarCentered ? Math.max(0, (gameHubSidebarCol.height - gameHubNav.implicitHeight - gameHubBottomNav.implicitHeight - Theme.spacingS * 2) / 2) : 0
                    Behavior on Layout.preferredHeight {
                        enabled: Theme.animationsEnabled
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                }

                AppSidebarRail {
                    id: gameHubNav
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    readonly property var categories: ["All", "Favorites", "Installed", "Steam", "Epic", "Ubisoft", "EA", "Prime", "Bottles"]
                    model: [
                        { icon: "sports_esports", text: "All Games" },
                        { icon: "favorite", text: "Favorites" },
                        { icon: "download_done", text: "Installed" },
                        { icon: "videogame_asset", text: "Steam" },
                        { icon: "bolt", text: "Epic" },
                        { icon: "shield", text: "Ubisoft" },
                        { icon: "sports", text: "EA" },
                        { icon: "workspace_premium", text: "Prime" },
                        { icon: "wine_bar", text: "Bottles" }
                    ]
                    currentIndex: categories.indexOf(win.activeNavCategory)
                    onActivated: index => {
                        win.activeNavCategory = categories[index] || "All";
                        if (widgetRoot) {
                            widgetRoot.activeLauncherFilter = win.activeNavCategory;
                            widgetRoot.filterGames();
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                AppSidebarRail {
                    id: gameHubBottomNav
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    model: [{ icon: "settings", text: "Settings" }]
                    currentIndex: PluginService.settingsOpen ? 0 : -1
                    onActivated: PluginService.settingsOpen = true
                }
            }
        }

        // ── MAIN HARMONY CONTENT AREA ──────────────────────────────────────
        ColumnLayout {
            anchors.left: (gameHubSidebar.visible && !SettingsData.sidebarFloating) ? gameHubSidebar.right : parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 0

            // ── TOP HARMONY HEADER TOOLBAR ────────────────────────────────
            Rectangle {
                id: topHarmonyHeader
                Layout.fillWidth: true
                height: win.isFullPageDetailActive ? 0 : 64
                visible: height > 0
                opacity: win.isFullPageDetailActive ? 0.0 : 1.0
                clip: true
                color: "transparent"

                Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 200 } }

                // Subtle bottom separator
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: win.cBorderSub
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 0
                    anchors.rightMargin: 4
                    spacing: 16

                    // Search Box (Playnite style input)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 420
                        height: 38
                        radius: 10
                        color: win.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(255, 255, 255, 0.05)
                        border.width: 1
                        border.color: searchInputWin.activeFocus ? win.cAccent : win.cBorderSub

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            DIcon {
                                name: "search"
                                size: 16
                                color: win.cTextSub
                            }

                            TextField {
                                id: searchInputWin
                                Layout.fillWidth: true
                                placeholderText: "Search library (Ctrl+F)..."
                                placeholderTextColor: win.cTextSub
                                color: win.cTextMain
                                font.pixelSize: Theme.fontSizeSmall
                                background: null
                                selectByMouse: true
                                onTextChanged: {
                                    if (win.widgetRoot) {
                                        win.widgetRoot.searchQuery = text;
                                        win.widgetRoot.filterGames();
                                    }
                                }

                                Keys.onPressed: (event) => {
                                    if (event.key === Qt.Key_Down || event.key === Qt.Key_Up || event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                                        event.accepted = true;
                                        searchInputWin.focus = false;
                                        if (mainGridView) {
                                            mainGridView.ensureFocused();
                                            if (event.key === Qt.Key_Down) mainGridView.moveDown();
                                            else if (event.key === Qt.Key_Up) mainGridView.moveUp();
                                            else if (event.key === Qt.Key_Left) mainGridView.moveLeft();
                                            else if (event.key === Qt.Key_Right) mainGridView.moveRight();
                                        }
                                    } else if (event.key === Qt.Key_Escape) {
                                        event.accepted = true;
                                        searchInputWin.focus = false;
                                        if (mainGridView) mainGridView.ensureFocused();
                                    }
                                }
                            }

                            DIcon {
                                name: "cancel"
                                size: 14
                                color: win.cTextSub
                                visible: searchInputWin.text.length > 0
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        searchInputWin.text = "";
                                        if (win.widgetRoot) {
                                            win.widgetRoot.searchQuery = "";
                                            win.widgetRoot.filterGames();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Top Toolbar Interactive Fetch Metadata & Status Pill
                    Rectangle {
                        id: topStatusPill
                        height: 32
                        implicitWidth: topStatusRow.implicitWidth + 18
                        radius: 16
                        color: topStatusMA.containsMouse
                            ? (win.isLight ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.15) : Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.22))
                            : (win.isFetchingMeta
                                ? (win.isLight ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.10) : Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.14))
                                : (win.isLight ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(255, 255, 255, 0.04)))
                        border.width: 1
                        border.color: (topStatusMA.containsMouse || win.isFetchingMeta)
                            ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.5)
                            : (win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.08))

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            id: topStatusRow
                            anchors.centerIn: parent
                            spacing: 6

                            DIcon {
                                name: win.isFetchingMeta ? "auto_awesome" : (win.isScanning ? "refresh" : "sports_esports")
                                size: 15
                                color: (win.isFetchingMeta || topStatusMA.containsMouse) ? win.cAccent : win.cTextSub
                                Layout.alignment: Qt.AlignVCenter
                                RotationAnimation on rotation {
                                    from: 0; to: 360; duration: 2000
                                    loops: Animation.Infinite
                                    running: win.isFetchingMeta || win.isScanning
                                    onRunningChanged: if (!running) rotation = 0
                                }
                            }

                            StyledText {
                                text: win.isFetchingMeta
                                    ? ((win.metaPhaseLabel !== "" ? win.metaPhaseLabel : "Metadata") + " " + win.metaProgressDone + " / " + win.metaProgressTotal)
                                    : (win.isScanning
                                        ? "Syncing games..."
                                        : (topStatusMA.containsMouse ? "Fetch Metadata" : (win.gameList.length + " / " + win.totalCount + " Games")))
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: topStatusMA.containsMouse ? Font.Medium : Font.Normal
                                color: (win.isFetchingMeta || topStatusMA.containsMouse) ? win.cAccent : win.cTextSub
                            }
                        }

                        MouseArea {
                            id: topStatusMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (win.widgetRoot) {
                                    win.widgetRoot._debugLog("topStatusPill clicked! isFetchingMeta=" + win.isFetchingMeta);
                                }
                                if (win.isFetchingMeta) {
                                    // Clicking while fetching cancels current phase
                                    if (win.widgetRoot) win.widgetRoot.cancelCurrentPhase();
                                } else {
                                    // Trigger fetch metadata
                                    if (win.widgetRoot) win.widgetRoot.fetchMetadata(true);
                                }
                            }
                        }
                    }

                    // Close Window Button (only displayed in floating mode, never in tiled mode)
                    Rectangle {
                        width: 34; height: 34; radius: 8
                        visible: win.isFloatingWindow
                        color: maCloseWin.containsMouse
                            ? Qt.rgba(239, 68, 68, 0.2)
                            : (win.isLight ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(255, 255, 255, 0.04))
                        border.width: 1
                        border.color: maCloseWin.containsMouse ? "#ef4444" : win.cBorderSub

                        DIcon {
                            name: "close"
                            size: 16
                            color: maCloseWin.containsMouse ? "#ef4444" : win.cTextMain
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: maCloseWin
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.visible = false
                        }
                    }
                }
            }

            // ── MAIN CONTENT VIEW (Animated Grid & Detail Container) ────
            Rectangle {
                id: contentContainerCard
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 16
                Layout.bottomMargin: 16

                Behavior on Layout.topMargin { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on Layout.bottomMargin { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                radius: (typeof Theme !== "undefined" && Theme.cornerRadiusLarge) ? Theme.cornerRadiusLarge : 18
                color: {
                    if (typeof Theme !== "undefined" && Theme.foregroundColor && Theme.cardSurface) {
                        return Theme.foregroundColor(Theme.cardSurface, true);
                    }
                    return win.isLight ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.65);
                }
                border.width: 1
                border.color: (typeof Theme !== "undefined" && Theme.outlineMedium) ? Theme.outlineMedium : win.cBorderSub
                clip: true

                readonly property bool hasDetail: win.selectedGame !== null
                readonly property bool isSideBySide: win.detailPositionMode !== "fullscreen"
                readonly property real sideFraction: {
                    if (!hasDetail || !isSideBySide) return 0.0;
                    return (win.detailSideSize || 50) / 100.0;
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: 10

                    // 1. GRID CONTAINER (Animates width when side-by-side detail opens, stays put when fullscreen)
                    Item {
                        id: gridWrapper
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        width: {
                            if (!contentContainerCard.hasDetail) return parent.width;
                            if (contentContainerCard.isSideBySide) {
                                return Math.max(260, parent.width * (1.0 - contentContainerCard.sideFraction) - 6);
                            }
                            return parent.width; // full screen detail covers on top
                        }
                        clip: true

                        Behavior on width {
                            NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                        }

                        GameHubGridView {
                            id: mainGridView
                            anchors.fill: parent
                            win: win
                            enabled: !contentContainerCard.hasDetail
                            visible: !contentContainerCard.hasDetail || contentContainerCard.isSideBySide
                        }
                    }

                    // 2. SIDE-BY-SIDE DETAIL PANE (Animates width from 0 to 30%/50%/70%)
                    Rectangle {
                        id: sideDetailPane
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        width: (contentContainerCard.hasDetail && contentContainerCard.isSideBySide)
                            ? Math.max(300, parent.width * contentContainerCard.sideFraction)
                            : 0
                        visible: width > 10
                        radius: 14
                        color: win.isLight ? Qt.rgba(0.98, 0.99, 1.0, 0.95) : Qt.rgba(0.08, 0.10, 0.14, 0.95)
                        border.width: 1
                        border.color: (typeof Theme !== "undefined" && Theme.outlineVariant) ? Theme.outlineVariant : win.cBorderSub
                        clip: true

                        Behavior on width {
                            NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                        }

                        GameHubDetailView {
                            anchors.fill: parent
                            win: win
                            onCloseRequested: win.selectedGame = null
                        }
                    }

                    // 3. FULLSCREEN DETAIL PANE (Complete overlay with sliding/fade animation)
                    Rectangle {
                        id: fullDetailPane
                        anchors.fill: parent
                        anchors.margins: -10 // Expand to match contentContainerCard inner boundaries cleanly
                        visible: opacity > 0.001
                        radius: contentContainerCard.radius
                        color: win.isLight ? Qt.rgba(0.98, 0.99, 1.0, 0.98) : Qt.rgba(0.08, 0.10, 0.14, 0.98)
                        border.width: 1
                        border.color: (typeof Theme !== "undefined" && Theme.outlineVariant) ? Theme.outlineVariant : win.cBorderSub
                        clip: true

                        property bool active: contentContainerCard.hasDetail && !contentContainerCard.isSideBySide
                        opacity: active ? 1.0 : 0.0
                        scale: active ? 1.0 : 0.96

                        Behavior on opacity {
                            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                        }

                        GameHubDetailView {
                            anchors.fill: parent
                            win: win
                            onCloseRequested: win.selectedGame = null
                        }
                    }
                }
            }
        }

        // ── AUTO-TUCKING PLATFORM FILTER BAR (Left Floating Bar) ──────────
        // Only platform filters; auto tucks into a small Android-style pill bar after inactivity
        Item {
            id: filterBarContainer
            visible: false
            anchors.left: parent.left
            anchors.leftMargin: isTucked ? -48 : 14
            anchors.top: parent.top
            anchors.topMargin: 80
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            width: 56
            z: 220

            property bool isTucked: false

            Behavior on anchors.leftMargin { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            Timer {
                id: tuckTimer
                interval: Math.max(500, win.autoHideDelaySec * 1000)
                repeat: false
                running: !filterBarContainer.isTucked
                onTriggered: {
                    if (!filterBarMA.containsMouse) {
                        filterBarContainer.isTucked = true;
                    }
                }
            }

            // The main translucent floating filter pill card
            Rectangle {
                id: filterCard
                anchors.fill: parent
                radius: 18
                color: win.isLight ? Qt.rgba(0.96, 0.97, 0.99, 0.88) : Qt.rgba(0.08, 0.10, 0.13, 0.88)
                border.width: 1
                border.color: win.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(255, 255, 255, 0.14)

                // Category Platform Icons List
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                    Column {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            id: catRepeater
                            model: {
                                let set = new Set(["All", "Installed"]);
                                let counts = { "All": 0, "Installed": 0 };
                                if (win.widgetRoot && win.widgetRoot.rawGamesList) {
                                    for (let i = 0; i < win.widgetRoot.rawGamesList.length; i++) {
                                        let item = win.widgetRoot.rawGamesList[i];
                                        let tag = item.launcher;
                                        if (tag) {
                                            set.add(tag);
                                            counts[tag] = (counts[tag] || 0) + 1;
                                        }
                                        counts["All"]++;
                                        if (!item.uninstalled) counts["Installed"]++;
                                    }
                                }
                                let arr = Array.from(set);
                                if (win.widgetRoot && win.widgetRoot._hideEmptyCategories) {
                                    arr = arr.filter(cat => (counts[cat] || 0) > 0);
                                }
                                return arr;
                            }

                            delegate: Item {
                                id: catIconItem
                                width: parent.width
                                height: 42

                                readonly property bool isActive: win.widgetRoot && win.widgetRoot.activeLauncherFilter === modelData
                                readonly property bool isHovered: iconMA.containsMouse
                                readonly property string pIconPath: win.getPlatformIcon(modelData)
                                readonly property bool hasSvg: pIconPath !== ""

                                // Diamond / Squarish indicator shape on hover / active
                                Rectangle {
                                    id: diamondBox
                                    anchors.centerIn: parent
                                    width: (isHovered || isActive) ? 38 : 34
                                    height: (isHovered || isActive) ? 38 : 34
                                    radius: isHovered ? 8 : (isActive ? 10 : 8)

                                    color: isActive
                                        ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.24)
                                        : (isHovered
                                            ? (win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.12))
                                            : "transparent")

                                    border.width: (isHovered || isActive) ? 1.5 : 0
                                    border.color: isActive
                                        ? win.cAccent
                                        : (isHovered
                                            ? (win.isLight ? Qt.rgba(0, 0, 0, 0.2) : Qt.rgba(255, 255, 255, 0.25))
                                            : "transparent")

                                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                    Behavior on radius { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Image {
                                        source: catIconItem.hasSvg ? catIconItem.pIconPath : ""
                                        width: 18; height: 18
                                        fillMode: Image.PreserveAspectFit
                                        anchors.centerIn: parent
                                        visible: catIconItem.hasSvg
                                    }

                                    DIcon {
                                        name: win.getPlatformMaterialIcon(modelData)
                                        size: 18
                                        color: catIconItem.isActive ? win.cAccent : (catIconItem.isHovered ? win.cTextMain : win.cTextSub)
                                        anchors.centerIn: parent
                                        visible: !catIconItem.hasSvg
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }
                                }

                                // Tooltip for category (shown when hovered, diamond / squarish indicator)
                                Rectangle {
                                    id: catTooltip
                                    anchors.left: catIconItem.right
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: catIconItem.verticalCenter
                                    height: 28
                                    width: tipRow.implicitWidth + 16
                                    radius: 7
                                    z: 500
                                    visible: catIconItem.isHovered

                                    color: win.isLight ? Qt.rgba(0.12, 0.14, 0.18, 0.94) : Qt.rgba(0.05, 0.06, 0.08, 0.94)
                                    border.width: 1
                                    border.color: win.isLight ? Qt.rgba(255, 255, 255, 0.2) : Qt.rgba(255, 255, 255, 0.15)

                                    Row {
                                        id: tipRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        StyledText {
                                            text: modelData
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            font.weight: Font.Medium
                                            color: "#FFFFFF"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Rectangle {
                                            height: 16; radius: 8
                                            width: tipCount.implicitWidth + 8
                                            color: Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.3)
                                            anchors.verticalCenter: parent.verticalCenter
                                            StyledText {
                                                id: tipCount
                                                text: {
                                                    if (!win.widgetRoot || !win.widgetRoot.rawGamesList) return "0";
                                                    if (modelData === "All") return win.widgetRoot.rawGamesList.length.toString();
                                                    if (modelData === "Installed") {
                                                        let c = 0;
                                                        for (let i = 0; i < win.widgetRoot.rawGamesList.length; i++) {
                                                            if (!win.widgetRoot.rawGamesList[i].uninstalled) c++;
                                                        }
                                                        return c.toString();
                                                    }
                                                    let c = 0;
                                                    for (let i = 0; i < win.widgetRoot.rawGamesList.length; i++) {
                                                        if (win.widgetRoot.rawGamesList[i].launcher === modelData) c++;
                                                    }
                                                    return c.toString();
                                                }
                                                font.pixelSize: Theme.fontSizeSmall - 3
                                                font.bold: true
                                                color: win.cAccent
                                                anchors.centerIn: parent
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: iconMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        tuckTimer.restart();
                                        if (win.widgetRoot) {
                                            win.widgetRoot.activeLauncherFilter = modelData;
                                            win.widgetRoot.filterGames();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Android-style edge handle / nav pill bar on the right side of the filter card
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 4
                    height: 38
                    radius: 2
                    color: filterBarContainer.isTucked
                        ? (filterBarMA.containsMouse ? win.cAccent : Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.7))
                        : (win.isLight ? Qt.rgba(0, 0, 0, 0.15) : Qt.rgba(255, 255, 255, 0.2))
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            // Mouse Area to detect hover / wake from tucked mode
            MouseArea {
                id: filterBarMA
                anchors.fill: parent
                hoverEnabled: true
                z: -1
                onEntered: {
                    filterBarContainer.isTucked = false;
                    tuckTimer.stop();
                }
                onExited: {
                    tuckTimer.restart();
                }
                onClicked: {
                    if (filterBarContainer.isTucked) {
                        filterBarContainer.isTucked = false;
                        tuckTimer.restart();
                    }
                }
            }
        }

        // ── HOVER BACK BUTTON (Appears next to hub button when hovering in detail mode) ──
        Rectangle {
            id: hoverBackBtn
            anchors.left: hubContainer.right
            anchors.leftMargin: 8
            anchors.top: hubContainer.top
            anchors.topMargin: 5
            width: 38
            height: 38
            radius: 19
            z: 251

            readonly property bool shouldShow: win.selectedGame !== null && hubCollapsedMA.containsMouse
            opacity: shouldShow ? 1.0 : 0.0
            scale: shouldShow ? 1.0 : 0.85
            visible: opacity > 0.01

            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            color: hoverBackBtnMA.containsMouse
                ? (win.isLight ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(0, 0, 0, 0.75))
                : (win.isLight ? Qt.rgba(255, 255, 255, 0.90) : Qt.rgba(0, 0, 0, 0.60))
            border.width: 1
            border.color: hoverBackBtnMA.containsMouse ? win.cAccent : (win.isLight ? Qt.rgba(0,0,0,0.12) : Qt.rgba(255,255,255,0.20))

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            DIcon {
                name: "arrow_back"
                size: 18
                color: hoverBackBtnMA.containsMouse ? win.cAccent : (win.isLight ? "#111827" : "#ffffff")
                anchors.centerIn: parent
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            MouseArea {
                id: hoverBackBtnMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    win.selectedGame = null;
                }
            }
        }

        // ── FULLSCREEN DISMISS OVERLAY (When GameHub is expanded) ──────────
        // Instantly collapses the GameHub popup and tucks filter bar on clicking anywhere outside
        MouseArea {
            id: outsideDismissMA
            anchors.fill: parent
            z: 240
            visible: hubContainer.isExpanded
            onClicked: {
                hubContainer.isExpanded = false;
                filterBarContainer.isTucked = true;
            }
        }

        // ── FLOATING GAMEHUB LOGO & EXPANDABLE CONTAINER (Never Hides) ──────
        // Never hides; on click expands its own container to house GameHub name, stats & options
        // Uses segmented look (first, mid, last) without separators; first item is always active pill
        Item {
            id: hubContainer
            visible: false // Floating bar commented out for future use
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.top: parent.top
            anchors.topMargin: 14
            width: isExpanded ? 270 : 48
            height: isExpanded ? (hubExpandedCol.implicitHeight + 16) : 48
            z: 250

            property bool isExpanded: false

            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

            // Main Translucent Glassmorphic Container
            Rectangle {
                id: hubMainCard
                anchors.fill: parent
                radius: hubContainer.isExpanded ? 18 : 14
                color: win.isLight ? Qt.rgba(0.96, 0.97, 0.99, 0.94) : Qt.rgba(0.08, 0.10, 0.14, 0.94)
                border.width: 1
                border.color: (hubContainer.isExpanded || hubCollapsedMA.containsMouse)
                    ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.6)
                    : (win.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(255, 255, 255, 0.14))
                clip: true

                Behavior on radius { NumberAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                // ── COLLAPSED VIEW: GameHub Floating Icon or Back Button in Details ────────
                Item {
                    anchors.fill: parent
                    visible: !hubContainer.isExpanded
                    opacity: !hubContainer.isExpanded ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    readonly property bool inDetailMode: win.selectedGame !== null
                    readonly property bool showBackButton: inDetailMode && hubCollapsedMA.containsMouse

                    DIcon {
                        name: parent.showBackButton ? "arrow_back" : "sports_esports"
                        size: parent.showBackButton ? 20 : 22
                        color: parent.showBackButton ? "#ffffff" : win.cAccent
                        anchors.centerIn: parent

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: hubCollapsedMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (parent.showBackButton || parent.inDetailMode) {
                                win.selectedGame = null;
                            } else {
                                hubContainer.isExpanded = true;
                            }
                        }
                    }
                }

                // ── EXPANDED VIEW: 3 Segmented Entries (First, Mid, Last) ───
                ColumnLayout {
                    id: hubExpandedCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 8
                    spacing: 4
                    visible: hubContainer.isExpanded
                    opacity: hubContainer.isExpanded ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    // 1. FIRST ITEM: GameHub Title & Stats (Always stays active -> Pill shape)
                    Rectangle {
                        id: hubFirstSeg
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        radius: 23 // Always active => full pill shape (height / 2)

                        color: hubFirstMA.containsMouse
                            ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.32)
                            : Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.22)
                        border.width: 1
                        border.color: win.cAccent

                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 12
                            spacing: 10

                            // Circular icon badge inside pill
                            Rectangle {
                                width: 32; height: 32
                                radius: 16
                                color: Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.35)
                                Layout.alignment: Qt.AlignVCenter

                                DIcon {
                                    name: "sports_esports"
                                    size: 18
                                    color: win.cAccent
                                    anchors.centerIn: parent
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    text: "GAME HUB"
                                    font.bold: true
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.letterSpacing: 0.6
                                    color: win.cTextMain
                                }
                                StyledText {
                                    text: win.totalCount + " Games in Library"
                                    font.pixelSize: Theme.fontSizeSmall - 3
                                    color: win.cTextSub
                                }
                            }

                            DIcon {
                                name: "expand_less"
                                size: 18
                                color: win.cAccent
                            }
                        }

                        MouseArea {
                            id: hubFirstMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: hubContainer.isExpanded = false
                        }
                    }

                    // 2. MID ITEM: Hub Settings Option (Segmented mid corners -> expands to pill on hover)
                    Rectangle {
                        id: hubMidSeg
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        property bool isHovered: hubMidMA.containsMouse

                        radius: isHovered ? 21 : 8
                        Behavior on radius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                        color: isHovered
                            ? (win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.12))
                            : (win.isLight ? Qt.rgba(0, 0, 0, 0.02) : Qt.rgba(255, 255, 255, 0.03))
                        border.width: 1
                        border.color: isHovered ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.5) : "transparent"

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            spacing: 10

                            Rectangle {
                                width: 26; height: 26
                                radius: 13
                                color: hubMidSeg.isHovered
                                    ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.25)
                                    : Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.12)
                                Layout.alignment: Qt.AlignVCenter

                                DIcon {
                                    name: "settings"
                                    size: 15
                                    color: win.cAccent
                                    anchors.centerIn: parent
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: "Hub Settings"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: win.cTextMain
                            }

                            DIcon {
                                name: "chevron_right"
                                size: 16
                                color: win.cTextSub
                            }
                        }

                        MouseArea {
                            id: hubMidMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                hubContainer.isExpanded = false;
                                PluginService.settingsOpen = true;
                            }
                        }
                    }

                    // 2.5 METADATA BUTTON (Transforms into active progress button when fetching)
                    Rectangle {
                        id: hubFetchMeta
                        Layout.fillWidth: true
                        Layout.preferredHeight: win.isFetchingMeta ? 48 : 42
                        property bool isHovered: hubFetchMetaMA.containsMouse

                        radius: (isHovered || win.isFetchingMeta) ? 21 : 8
                        Behavior on radius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        color: win.isFetchingMeta
                            ? (win.isLight ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.12) : Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.16))
                            : (isHovered
                                ? (win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.12))
                                : (win.isLight ? Qt.rgba(0, 0, 0, 0.02) : Qt.rgba(255, 255, 255, 0.03)))
                        border.width: 1
                        border.color: win.isFetchingMeta
                            ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.6)
                            : (isHovered ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.5) : "transparent")

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        clip: true

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            spacing: 10

                            Rectangle {
                                width: 26; height: 26
                                radius: 13
                                color: (hubFetchMeta.isHovered || win.isFetchingMeta)
                                    ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.25)
                                    : Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.12)
                                Layout.alignment: Qt.AlignVCenter

                                DIcon {
                                    name: "auto_awesome"
                                    size: 15
                                    color: win.cAccent
                                    anchors.centerIn: parent
                                    RotationAnimation on rotation {
                                        from: 0; to: 360; duration: 2000
                                        loops: Animation.Infinite
                                        running: win.isFetchingMeta
                                        onRunningChanged: if (!running) rotation = 0
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 1

                                // Single-line title container with marquee scrolling
                                Item {
                                    id: metaTitleBox
                                    Layout.fillWidth: true
                                    height: 18
                                    clip: true

                                    StyledText {
                                        id: metaTitleTxt
                                        text: win.isFetchingMeta
                                            ? (win.metaProgressTotal > 0
                                                ? (win.metaPhaseLabel + ": " + win.metaCurrentTitle)
                                                : (win.metaPhaseLabel + "..."))
                                            : "Fetch Metadata"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Medium
                                        color: win.cTextMain
                                        wrapMode: Text.NoWrap
                                        anchors.verticalCenter: parent.verticalCenter

                                        readonly property bool isLong: contentWidth > metaTitleBox.width
                                        property real scrollOffset: 0
                                        x: isLong ? -scrollOffset : 0

                                        onTextChanged: {
                                            scrollOffset = 0;
                                            marqueeAnim.restart();
                                        }

                                        SequentialAnimation {
                                            id: marqueeAnim
                                            running: metaTitleTxt.isLong && win.isFetchingMeta
                                            loops: Animation.Infinite

                                            PauseAnimation { duration: 1600 }
                                            NumberAnimation {
                                                target: metaTitleTxt
                                                property: "scrollOffset"
                                                from: 0
                                                to: Math.max(0, metaTitleTxt.contentWidth - metaTitleBox.width + 12)
                                                duration: Math.max(1200, (metaTitleTxt.contentWidth - metaTitleBox.width) * 35)
                                                easing.type: Easing.Linear
                                            }
                                            PauseAnimation { duration: 1600 }
                                            NumberAnimation {
                                                target: metaTitleTxt
                                                property: "scrollOffset"
                                                to: 0
                                                duration: 200
                                                easing.type: Easing.OutQuad
                                            }
                                        }
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: win.isFetchingMeta && win.metaProgressTotal > 0
                                    text: win.metaProgressDone + " / " + win.metaProgressTotal + " (" + Math.round(win.metaProgressFraction * 100) + "%)"
                                    font.pixelSize: Theme.fontSizeSmall - 3
                                    color: win.cAccent
                                }
                            }
                        }

                        // Internal progress bar track (contained inside pill with margin and rounded ends)
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.bottomMargin: 4
                            height: 3
                            radius: 1.5
                            color: win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.08)
                            visible: win.isFetchingMeta

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: parent.width * Math.min(1.0, Math.max(0.0, win.metaProgressFraction))
                                radius: 1.5
                                color: win.cAccent
                                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            }
                        }

                        MouseArea {
                            id: hubFetchMetaMA
                            anchors.fill: parent
                            enabled: !win.isFetchingMeta
                            hoverEnabled: !win.isFetchingMeta
                            cursorShape: win.isFetchingMeta ? Qt.ArrowCursor : Qt.PointingHandCursor
                            z: 10
                            onClicked: {
                                if (win.widgetRoot) {
                                    win.widgetRoot._debugLog("hubFetchMeta button clicked! isFetchingMeta=" + win.isFetchingMeta);
                                    win.widgetRoot.fetchMetadata(true);
                                }
                            }
                        }

                        // Small cancel × button — only visible while fetching
                        Rectangle {
                            id: cancelPhaseBtn
                            width: 24; height: 24; radius: 12
                            visible: win.isFetchingMeta
                            z: 20
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: cancelPhasMA.containsMouse
                                ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.40)
                                : Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.18)
                            border.width: 1
                            border.color: Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.6)
                            Behavior on color { ColorAnimation { duration: 120 } }

                            DIcon {
                                name: "close"
                                size: 12
                                color: win.cAccent
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                id: cancelPhasMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (win.widgetRoot) win.widgetRoot.cancelCurrentPhase();
                                }
                            }
                        }
                    }

                    // 3. LAST ITEM: Sync/Rescan Library Option (Segmented bottom corners -> expands to pill on hover)
                    Rectangle {
                        id: hubLastSeg
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        property bool isHovered: hubLastMA.containsMouse

                        radius: isHovered ? 21 : 14
                        Behavior on radius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                        color: isHovered
                            ? (win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.12))
                            : (win.isLight ? Qt.rgba(0, 0, 0, 0.02) : Qt.rgba(255, 255, 255, 0.03))
                        border.width: 1
                        border.color: isHovered ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.5) : "transparent"

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            spacing: 10

                            Rectangle {
                                width: 26; height: 26
                                radius: 13
                                color: hubLastSeg.isHovered
                                    ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.25)
                                    : Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.12)
                                Layout.alignment: Qt.AlignVCenter

                                DIcon {
                                    name: "refresh"
                                    size: 15
                                    color: win.cAccent
                                    anchors.centerIn: parent
                                    RotationAnimation on rotation {
                                        from: 0; to: 360; duration: 900; loops: Animation.Infinite
                                        running: win.isScanning
                                        onRunningChanged: if (!running) rotation = 0
                                    }
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: win.isScanning ? "Scanning games..." : "Sync Game Libraries"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: win.cTextMain
                            }
                        }

                        MouseArea {
                            id: hubLastMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (win.widgetRoot) win.widgetRoot.scanAllGames();
                            }
                        }
                    }
                }
            }
        }

        // ── SETTINGS OVERLAY PANEL ────────────────────────────────────────
        // Uses direct PluginService calls (PluginSettings context not available in FloatingWindow)
        Rectangle {
            id: settingsOverlayWin
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55)
            visible: win.showSettingsOverlay
            z: 300

            // Blur simulation layer: adds visual depth
            Rectangle {
                anchors.fill: parent
                color: win.isLight ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0.05, 0.08, 0.14, 0.12)
                opacity: 0.5
            }

            function ps_load(key, def) { return PluginService.loadPluginData("fullscreenGameHub", key, def); }
            function ps_save(key, val) {
                PluginService.savePluginData("fullscreenGameHub", key, val);
                PluginService.setGlobalVar("fullscreenGameHub", key, val);
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    win.showSettingsOverlay = false;
                    win.themeMode = settingsOverlayWin.ps_load("windowThemeMode", "dark");
                    let wt = settingsOverlayWin.ps_load("windowTransparency", false);
                    win.windowTransparency = wt === true || wt === "true";
                    if (win.widgetRoot) { win.widgetRoot.reloadSettings(); win.widgetRoot.scanAllGames(); }
                }
            }

            // Settings Modal Card (matching dux-files / dfiles SettingsModal two-column layout)
            Rectangle {
                id: settingsDialogCard
                width: Math.min(1060, parent.width - 48)
                height: Math.min(680, parent.height - 48)
                anchors.centerIn: parent
                radius: (typeof Theme !== "undefined" && Theme.cornerRadiusLarge) ? Theme.cornerRadiusLarge : 20
                color: win.isLight ? Qt.rgba(0.95, 0.96, 0.98, 0.92) : Qt.rgba(0.09, 0.11, 0.15, 0.92)
                opacity: 0.97
                border.width: 1
                border.color: (typeof Theme !== "undefined" && Theme.outlineMedium) ? Theme.outlineMedium : (win.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(255, 255, 255, 0.14))
                clip: true

                property int currentTab: 0
                property string searchQuery: ""

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Modal Header with Title, Icon and Close Button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 56
                        color: win.isLight ? Qt.rgba(0, 0, 0, 0.02) : Qt.rgba(255, 255, 255, 0.02)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: (typeof Theme !== "undefined" && Theme.outlineVariant) ? Theme.outlineVariant : win.cBorderSub
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 16
                            spacing: 12

                            Rectangle {
                                width: 34; height: 34; radius: 17
                                color: Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.16)
                                Layout.alignment: Qt.AlignVCenter

                                DIcon {
                                    name: "settings"
                                    size: 18
                                    color: win.cAccent
                                    anchors.centerIn: parent
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    text: "Game Hub Settings"
                                    font.bold: true
                                    font.pixelSize: Theme.fontSizeLarge
                                    color: win.cTextMain
                                }

                                StyledText {
                                    text: "Configure library scanners, Steam integration, grid layout, theme, and metadata"
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: win.cTextSub
                                }
                            }

                            Rectangle {
                                id: closeBtn
                                width: 32; height: 32; radius: 16
                                color: closeBtnMA.containsMouse ? (win.isLight ? Qt.rgba(0,0,0,0.08) : Qt.rgba(255,255,255,0.12)) : "transparent"
                                border.width: 1
                                border.color: closeBtnMA.containsMouse ? (win.isLight ? Qt.rgba(0,0,0,0.15) : Qt.rgba(255,255,255,0.2)) : "transparent"

                                Behavior on color { ColorAnimation { duration: 120 } }

                                DIcon {
                                    name: "close"
                                    size: 18
                                    color: closeBtnMA.containsMouse ? win.cAccent : win.cTextSub
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    id: closeBtnMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        win.showSettingsOverlay = false;
                                        win.themeMode = settingsOverlayWin.ps_load("windowThemeMode", "dark");
                                        let wt = settingsOverlayWin.ps_load("windowTransparency", false);
                                        win.windowTransparency = wt === true || wt === "true";
                                        if (win.widgetRoot) { win.widgetRoot.reloadSettings(); win.widgetRoot.scanAllGames(); }
                                    }
                                }
                            }
                        }
                    }

                    // Two-Pane Content Body
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 0

                        // ── LEFT SIDEBAR (dux-files SettingsSidebar style) ─────────────
                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 280
                            color: win.isLight ? Qt.rgba(0, 0, 0, 0.02) : Qt.rgba(0, 0, 0, 0.20)

                            // Vertical divider separating sidebar from content
                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 1
                                color: (typeof Theme !== "undefined" && Theme.outlineVariant) ? Theme.outlineVariant : win.cBorderSub
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                // Search input inside sidebar
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 38
                                    radius: (typeof Theme !== "undefined" && Theme.cornerRadiusSmall) ? Theme.cornerRadiusSmall : 10
                                    color: win.isLight ? Qt.rgba(1, 1, 1, 0.8) : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                                    border.width: 1
                                    border.color: settingsSearchInput.activeFocus ? win.cAccent : win.cBorderSub

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 8

                                        DIcon {
                                            name: "search"
                                            size: 16
                                            color: win.cTextSub
                                        }

                                        TextField {
                                            id: settingsSearchInput
                                            Layout.fillWidth: true
                                            placeholderText: "Search settings..."
                                            placeholderTextColor: win.cTextSub
                                            color: win.cTextMain
                                            font.pixelSize: Theme.fontSizeSmall
                                            background: null
                                            text: settingsDialogCard.searchQuery
                                            onTextChanged: {
                                                settingsDialogCard.searchQuery = text;
                                                if (text !== "") {
                                                    settingsDialogCard.currentTab = -1; // show all matching sections
                                                } else if (settingsDialogCard.currentTab === -1) {
                                                    settingsDialogCard.currentTab = 0;
                                                }
                                            }
                                        }

                                        DIcon {
                                            name: "cancel"
                                            size: 14
                                            color: win.cTextSub
                                            visible: settingsSearchInput.text.length > 0
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: settingsSearchInput.text = ""
                                            }
                                        }
                                    }
                                }

                                // Category Sidebar Items list
                                ScrollView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                                    Column {
                                        width: parent.width
                                        spacing: 4

                                        readonly property var groups: [
                                            [
                                                { index: 0, label: "Scanners & Sources", hint: "Steam, Lutris, Heroic, Bottles", icon: "sports_esports" },
                                                { index: 1, label: "Steam Web API", hint: "API key, SteamID64 sync", icon: "cloud" },
                                                { index: 2, label: "Grid View Layout", hint: "Cards per row, spacing, presentation", icon: "grid_view" }
                                            ],
                                            [
                                                { index: 3, label: "Appearance & Theme", hint: "Theme mode, transparency & corner radius", icon: "palette" },
                                                { index: 4, label: "Behavior & Pill", hint: "Bar pill, game launch actions", icon: "tune" }
                                            ],
                                            [
                                                { index: 5, label: "Metadata Providers", hint: "RAWG, IGDB, SteamGridDB", icon: "auto_awesome" },
                                                { index: 6, label: "IPC Commands", hint: "Shortcuts, hotkeys & CLI", icon: "terminal" }
                                            ]
                                        ]

                                        Repeater {
                                            model: parent.groups

                                            Column {
                                                id: groupCol
                                                required property var modelData
                                                width: parent.width
                                                spacing: (typeof Theme !== "undefined" && Theme.groupedListGap) ? Theme.groupedListGap : 2

                                                Repeater {
                                                    model: groupCol.modelData

                                                    Rectangle {
                                                        id: navItem
                                                        required property var modelData
                                                        required property int index
                                                        width: parent.width
                                                        height: 52

                                                        readonly property bool isSelected: settingsDialogCard.currentTab === modelData.index
                                                        readonly property bool isHovered: navItemMA.containsMouse
                                                        readonly property bool isFirstInGroup: index === 0
                                                        readonly property bool isLastInGroup: index === groupCol.modelData.length - 1

                                                        readonly property real topR: isFirstInGroup
                                                            ? ((typeof Theme !== "undefined" && Theme.groupedListOuterRadius) ? Theme.groupedListOuterRadius : 12)
                                                            : ((typeof Theme !== "undefined" && Theme.groupedListInnerRadius) ? Theme.groupedListInnerRadius : 4)
                                                        readonly property real botR: isLastInGroup
                                                            ? ((typeof Theme !== "undefined" && Theme.groupedListOuterRadius) ? Theme.groupedListOuterRadius : 12)
                                                            : ((typeof Theme !== "undefined" && Theme.groupedListInnerRadius) ? Theme.groupedListInnerRadius : 4)

                                                        topLeftRadius: topR
                                                        topRightRadius: topR
                                                        bottomLeftRadius: botR
                                                        bottomRightRadius: botR

                                                        color: {
                                                            if (isSelected) {
                                                                return win.isLight ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.20) : Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.22);
                                                            }
                                                            if (isHovered) {
                                                                return win.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(255, 255, 255, 0.07);
                                                            }
                                                            return (typeof Theme !== "undefined" && Theme.foregroundColor && Theme.cardSurface)
                                                                ? Theme.foregroundColor(Theme.cardSurface, true)
                                                                : (win.isLight ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.4));
                                                        }

                                                        border.width: isSelected ? 1.5 : (typeof Theme !== "undefined" && Theme.layerOutlineWidth ? Theme.layerOutlineWidth : 1)
                                                        border.color: isSelected
                                                            ? win.cAccent
                                                            : ((typeof Theme !== "undefined" && Theme.outlineMedium) ? Theme.outlineMedium : win.cBorderSub)

                                                        Behavior on color { ColorAnimation { duration: 150 } }
                                                        Behavior on border.color { ColorAnimation { duration: 150 } }

                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.leftMargin: 12
                                                            anchors.rightMargin: 12
                                                            spacing: 12

                                                            Rectangle {
                                                                width: 32; height: 32; radius: 16
                                                                color: navItem.isSelected
                                                                    ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.30)
                                                                    : (win.isLight ? Qt.rgba(0,0,0,0.06) : Qt.rgba(255,255,255,0.08))
                                                                Layout.alignment: Qt.AlignVCenter

                                                                DIcon {
                                                                    name: navItem.modelData.icon
                                                                    size: 16
                                                                    color: navItem.isSelected ? win.cAccent : win.cTextSub
                                                                    anchors.centerIn: parent
                                                                }
                                                            }

                                                            ColumnLayout {
                                                                Layout.fillWidth: true
                                                                spacing: 1
                                                                Layout.alignment: Qt.AlignVCenter

                                                                StyledText {
                                                                    text: navItem.modelData.label
                                                                    font.pixelSize: Theme.fontSizeMedium - 1
                                                                    font.weight: navItem.isSelected ? Font.DemiBold : Font.Normal
                                                                    color: navItem.isSelected ? win.cAccent : win.cTextMain
                                                                    elide: Text.ElideRight
                                                                }

                                                                StyledText {
                                                                    text: navItem.modelData.hint
                                                                    font.pixelSize: Theme.fontSizeSmall - 2
                                                                    color: win.cTextSub
                                                                    elide: Text.ElideRight
                                                                }
                                                            }
                                                        }

                                                        MouseArea {
                                                            id: navItemMA
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                settingsSearchInput.text = "";
                                                                settingsDialogCard.searchQuery = "";
                                                                settingsDialogCard.currentTab = navItem.modelData.index;
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── RIGHT CONTENT PANE (Settings Cards) ─────────────────────────
                        ScrollView {
                            id: settingsScrollView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: availableWidth
                            contentHeight: settingsLoader.item ? Math.max(settingsLoader.item.implicitHeight, settingsLoader.item.height) : 600
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                            Item {
                                width: settingsScrollView.availableWidth
                                implicitHeight: settingsLoader.item ? settingsLoader.item.implicitHeight + 32 : 600

                                Loader {
                                    id: settingsLoader
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 20
                                    active: win.showSettingsOverlay
                                    source: "GameHubSettings.qml"
                                    onLoaded: {
                                        if (item) {
                                            item.hideIpcCommands = false;
                                            item.activeSectionIndex = Qt.binding(() => settingsDialogCard.currentTab);
                                            item.searchQuery = Qt.binding(() => settingsDialogCard.searchQuery);
                                            if (typeof PluginService !== "undefined")
                                                item.pluginService = PluginService;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── CONTROLLER HANDLER (HOME button → show/toggle hub) ──────────────
    ControllerHandler {
        id: controllerHandler
        enabled: win.controllerHomeEnabled
        onLaunchRequested: {
            win.visible = !win.visible;
        }
    }

    // ── RUNNING GAME DETECTION PROCESS ──────────────────────────────────
    // Launched per game when a game is started; prints the game id on match
    Process {
        id: runningGameDetector
        onStdoutChanged: {
            var out = stdout ? stdout.trim() : "";
            if (out !== "") {
                win.openDetailForGame(out);
            }
        }
    }

    function openDetailForGame(gameId) {
        if (!win.widgetRoot || !win.widgetRoot.rawGamesList) return;
        for (var i = 0; i < win.widgetRoot.rawGamesList.length; i++) {
            var g = win.widgetRoot.rawGamesList[i];
            if (g && (g.id === gameId || g.title === gameId)) {
                win.selectedGame = g;
                win.visible = true;
                return;
            }
        }
    }

    function startGameDetection(gameId, execName) {
        if (!execName || execName === "") return;
        try {
            runningGameDetector.command = [
                "/bin/bash",
                Qt.resolvedUrl("detect_running_game.sh").toString().replace("file://", ""),
                execName,
                gameId
            ];
            runningGameDetector.running = true;
        } catch(e) {
            console.log("GameHub: startGameDetection error:", e);
        }
    }

    // ── METADATA EDITOR POPUP MODAL ──
    GameHubMetadataEditor {
        id: metaEditorOverlay
        win: win
    }

    // ── FULLSCREEN PHOTO VIEWER MODAL OVERLAY ─────────────────────────
    Rectangle {
        id: photoViewerOverlay
        anchors.fill: parent
        z: 400
        visible: win.showPhotoViewer
        color: Qt.rgba(0, 0, 0, 0.95)
        opacity: visible ? 1.0 : 0.0
        radius: 12
        clip: true

        Behavior on opacity { NumberAnimation { duration: 200 } }

        // Esc key closes preview first (before any other handler)
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                win.showPhotoViewer = false;
                event.accepted = true;
            }
        }

        Component.onCompleted: forceActiveFocus()
        onVisibleChanged: { if (visible) forceActiveFocus(); }

        MouseArea {
            anchors.fill: parent
            onClicked: win.showPhotoViewer = false
        }

        Image {
            id: photoViewerMainImage
            anchors.fill: parent
            anchors.margins: 48
            fillMode: Image.PreserveAspectFit
            source: (win.fullscreenPhotoList && win.fullscreenPhotoList.length > win.fullscreenPhotoIndex && win.fullscreenPhotoIndex >= 0)
                ? win.fullscreenPhotoList[win.fullscreenPhotoIndex]
                : ""
            asynchronous: true
        }

        // Close Button (Top-Right)
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 20
            width: 44
            height: 44
            radius: 22
            color: closePhotoMA.containsMouse ? Qt.rgba(255, 255, 255, 0.25) : Qt.rgba(0, 0, 0, 0.5)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.2)

            DIcon {
                name: "close"
                size: 24
                color: "#ffffff"
                anchors.centerIn: parent
            }

            MouseArea {
                id: closePhotoMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: win.showPhotoViewer = false
            }
        }

        // Previous Button
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 20
            width: 48
            height: 48
            radius: 24
            visible: win.fullscreenPhotoList && win.fullscreenPhotoList.length > 1
            color: prevPhotoMA.containsMouse ? Qt.rgba(255, 255, 255, 0.25) : Qt.rgba(0, 0, 0, 0.5)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.2)

            DIcon {
                name: "chevron_left"
                size: 28
                color: "#ffffff"
                anchors.centerIn: parent
            }

            MouseArea {
                id: prevPhotoMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (win.fullscreenPhotoIndex > 0) {
                        win.fullscreenPhotoIndex--;
                    } else if (win.fullscreenPhotoList) {
                        win.fullscreenPhotoIndex = win.fullscreenPhotoList.length - 1;
                    }
                }
            }
        }

        // Next Button
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 20
            width: 48
            height: 48
            radius: 24
            visible: win.fullscreenPhotoList && win.fullscreenPhotoList.length > 1
            color: nextPhotoMA.containsMouse ? Qt.rgba(255, 255, 255, 0.25) : Qt.rgba(0, 0, 0, 0.5)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.2)

            DIcon {
                name: "chevron_right"
                size: 28
                color: "#ffffff"
                anchors.centerIn: parent
            }

            MouseArea {
                id: nextPhotoMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (win.fullscreenPhotoList && win.fullscreenPhotoIndex < win.fullscreenPhotoList.length - 1) {
                        win.fullscreenPhotoIndex++;
                    } else {
                        win.fullscreenPhotoIndex = 0;
                    }
                }
            }
        }

        // Indicator Pill
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 24
            height: 28
            width: photoCounterTxt.implicitWidth + 24
            radius: 14
            color: Qt.rgba(0, 0, 0, 0.6)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.15)
            visible: win.fullscreenPhotoList && win.fullscreenPhotoList.length > 0

            StyledText {
                id: photoCounterTxt
                text: ((win.fullscreenPhotoIndex + 1) + " / " + (win.fullscreenPhotoList ? win.fullscreenPhotoList.length : 0))
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                color: "#ffffff"
                anchors.centerIn: parent
            }
        }
    }
}
