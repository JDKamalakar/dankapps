import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets
import qs.Services

Item {
    id: detailRoot

    property var win: null
    property var game: win ? win.selectedGame : null
    readonly property bool isFullScreenMode: win ? (win.detailPositionMode === "fullscreen") : false

    property string activeTrailerUrl: ""
    property bool isPlayingTrailer: false

    signal closeRequested()
    signal launchRequested(var game)

    // Keyboard shortcuts within detail view
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
            closeRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (game) launchGame();
            event.accepted = true;
        }
    }

    // Helper to stop trailer playback and clear video source
    function stopTrailer() {
        if (detailRoot.isPlayingTrailer) {
            heroVideoPlayer.stop(); // triggers onStopped
            detailRoot.isPlayingTrailer = false;
            detailRoot.activeTrailerUrl = "";
        }
    }

    onCloseRequested: {
        stopTrailer();
    }

    Component.onDestruction: {
        stopTrailer();
    }

    function launchGame() {
        if (!game) return;
        // Start running-game detection before launch
        if (win && typeof win.startGameDetection === "function" && game.cmd) {
            let execParts = game.cmd.trim().split(/\s+/);
            let execName = execParts[0].split("/").pop();
            win.startGameDetection(game.id || game.title || "", execName);
        }
        if (win && win.widgetRoot && win.widgetRoot.launchGame) {
            win.widgetRoot.launchGame(game);
        } else if (game.cmd) {
            let cmdStr = game.cmd;
            let parts = cmdStr.trim().split(/\s+/);
            try {
                launcherProcess.command = parts;
                launcherProcess.running = true;
            } catch(e) {
                console.log("GameHub launch error: " + e);
            }
        }
    }

    function openGamePage() {
        if (!game) return;
        if (win && win.widgetRoot && win.widgetRoot.openGamePage) {
            win.widgetRoot.openGamePage(game);
        } else {
            launchGame();
        }
    }

    Process {
        id: launcherProcess
    }

    // =========================================================================
    // 1. FULLSCREEN PRESENTATION MODE (Matching Screenshot 2 - Hollow Knight)
    // =========================================================================
    Item {
        id: fullPageLayout
        anchors.fill: parent
        visible: detailRoot.isFullScreenMode

        // TOP SECTION: Unblurred, undimmed hero background artwork in full glory with rounded top corners
        ClippingRectangle {
            id: topHeroArea
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.round(parent.height * 0.70)
            topLeftRadius: (win && win.gridCornerRadius !== undefined) ? win.gridCornerRadius : 18
            topRightRadius: (win && win.gridCornerRadius !== undefined) ? win.gridCornerRadius : 18
            color: "transparent"
            clip: true

            Image {
                id: fullHeroBg
                anchors.fill: parent
                source: (detailRoot.game && detailRoot.game.backgroundUrl) ? detailRoot.game.backgroundUrl : ((detailRoot.game && detailRoot.game.coverUrl) ? detailRoot.game.coverUrl : "")
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // Full glory: 100% opacity, crisp, no blur, no dimming overlay
                opacity: detailRoot.isPlayingTrailer ? 0.0 : 1.0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 250 } }
            }

            Video {
                id: heroVideoPlayer
                anchors.fill: parent
                source: detailRoot.activeTrailerUrl
                fillMode: Video.PreserveAspectCrop
                visible: detailRoot.isPlayingTrailer
                loops: 1
                volume: 1.0

                onStopped: {
                    detailRoot.isPlayingTrailer = false;
                    detailRoot.activeTrailerUrl = "";
                }
            }

            // Bottom edge fade so it melts seamlessly into the bottom blurred dock
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 80
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: win && win.isLight ? Qt.rgba(0.92, 0.94, 0.98, 0.85) : Qt.rgba(0.06, 0.07, 0.10, 0.85) }
                }
            }

            // Top Navigation Row (Icon-Only Back Button + Asset Platform Icon + Metascore)
            RowLayout {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                spacing: 12
                z: 10

                // Back Button: ICON-ONLY circular pill button
                Rectangle {
                    width: 38
                    height: 38
                        radius: 19
                        color: fullBackMA.containsMouse
                        ? (win && win.isLight ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(0, 0, 0, 0.65))
                        : (win && win.isLight ? Qt.rgba(255, 255, 255, 0.75) : Qt.rgba(0, 0, 0, 0.45))
                        border.width: 1
                        border.color: fullBackMA.containsMouse ? (win ? win.cAccent : "#3b82f6") : (win && win.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(255, 255, 255, 0.2))

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    DIcon {
                        name: "arrow_back"
                        size: 18
                        color: fullBackMA.containsMouse ? (win ? win.cAccent : "#3b82f6") : (win && win.isLight ? "#111827" : "#ffffff")
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: fullBackMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: detailRoot.closeRequested()
                    }
                }

                Item { Layout.fillWidth: true }

                // Platform tag pill with official asset SVG icon
                Rectangle {
                    height: 34
                    implicitWidth: fullPlatRow.implicitWidth + 20
                        radius: 17
                        color: win && win.isLight ? Qt.rgba(255, 255, 255, 0.85) : Qt.rgba(0, 0, 0, 0.45)
                        border.width: 1
                        border.color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(255, 255, 255, 0.2)

                    readonly property string platSvg: (win && detailRoot.game) ? win.getPlatformIcon(detailRoot.game.launcher) : ""

                    Row {
                        id: fullPlatRow
                        anchors.centerIn: parent
                        spacing: 8

                        Image {
                            source: parent.parent.platSvg
                            width: 16
                            height: 16
                            fillMode: Image.PreserveAspectFit
                            visible: parent.parent.platSvg !== ""
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        DIcon {
                            name: (win && detailRoot.game) ? win.getPlatformMaterialIcon(detailRoot.game.launcher) : "sports_esports"
                            size: 15
                            color: win ? win.cAccent : "#3b82f6"
                            visible: parent.parent.platSvg === ""
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: (detailRoot.game && detailRoot.game.launcher) ? detailRoot.game.launcher.toUpperCase() : ""
                            font.pixelSize: Theme.fontSizeSmall - 2
                            font.bold: true
                            color: win && win.isLight ? "#111827" : "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Metascore Pill (hero badge retained)
                Rectangle {
                    visible: detailRoot.game && detailRoot.game.metascore !== undefined && detailRoot.game.metascore !== null && detailRoot.game.metascore !== ""
                    height: 34
                    implicitWidth: fullScoreRow.implicitWidth + 18
                        radius: (win && win.gridCornerRadius !== undefined) ? Math.min(10, win.gridCornerRadius) : 8
                        color: {
                        let score = parseInt(detailRoot.game ? detailRoot.game.metascore : 0);
                        if (score >= 75) return "#22c55e";
                        if (score >= 50) return "#eab308";
                        return "#ef4444";
                    }

                    Row {
                        id: fullScoreRow
                        anchors.centerIn: parent
                        spacing: 4

                        DIcon {
                            name: "star"
                            size: 14
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: (detailRoot.game && detailRoot.game.metascore) ? detailRoot.game.metascore.toString() : ""
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

        }

        // BOTTOM DOCK: Translucent blurred metadata & action panel with matching bottom rounded corners
        Rectangle {
            id: bottomDockCard
            anchors.top: topHeroArea.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            bottomLeftRadius: (win && win.gridCornerRadius !== undefined) ? win.gridCornerRadius : 18
            bottomRightRadius: (win && win.gridCornerRadius !== undefined) ? win.gridCornerRadius : 18
            color: Theme.foregroundColor(Theme.surfaceContainer, true)
            border.width: 1
            border.color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.08)
            clip: true

            // Bottom portion background continuation: clipped to bottom rounded corners, showing subtle 10% slice
            ClippingRectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.max(40, parent.height * 0.10)
                bottomLeftRadius: bottomDockCard.bottomLeftRadius
                bottomRightRadius: bottomDockCard.bottomRightRadius
                color: "transparent"
                clip: true

                Image {
                    anchors.fill: parent
                    source: (detailRoot.game && detailRoot.game.backgroundUrl) ? detailRoot.game.backgroundUrl : ((detailRoot.game && detailRoot.game.coverUrl) ? detailRoot.game.coverUrl : "")
                    fillMode: Image.PreserveAspectCrop
                    verticalAlignment: Image.AlignBottom
                    opacity: 0.18
                    asynchronous: true
                }
            }

            ScrollView {
                id: fullDetailScrollView
                anchors.fill: parent
                anchors.margins: 16
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    width: fullDetailScrollView.availableWidth
                    spacing: 16

                    // ── CONTAINER 1: METADATA & GAME OVERVIEW CARD ─────────────────────
                    Rectangle {
                        id: fullMetaOverviewCard
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        radius: (win && win.gridCornerRadius !== undefined) ? win.gridCornerRadius : 16
                        color: Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                        border.width: 1
                        border.color: (typeof Theme !== "undefined" && Theme.outlineMedium) ? Theme.outlineMedium : (win && win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.10))
                        implicitHeight: metaCardInnerRow.implicitHeight + 28
                        clip: true

                        RowLayout {
                        id: metaCardInnerRow
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 18

                        // 2:3 High-Res Cover Card (rounded corners from appearance settings)
                        ClippingRectangle {
                            id: fullCoverCard
                            Layout.preferredWidth: 150
                            Layout.preferredHeight: Math.round(150 * 1.50) // Strict 2:3 ratio
                            Layout.alignment: Qt.AlignTop
                            radius: (win && win.gridCornerRadius !== undefined) ? win.gridCornerRadius : 16
                            color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(255, 255, 255, 0.06)
                            border.width: 1
                            border.color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(255, 255, 255, 0.15)

                            Image {
                                anchors.fill: parent
                                source: (detailRoot.game && detailRoot.game.coverUrl) ? detailRoot.game.coverUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }

                            DIcon {
                                name: "sports_esports"
                                size: 48
                                color: win ? win.cAccent : "#3b82f6"
                                opacity: 0.45
                                anchors.centerIn: parent
                                visible: !detailRoot.game || !detailRoot.game.coverUrl
                            }
                        }

                        // Center Info & Metadata Column
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                DIcon { name: "info"; size: 15; color: win ? win.cAccent : "#3b82f6" }
                                StyledText {
                                    text: "Overview & Metadata"
                                    font.bold: true
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: win ? win.cAccent : "#3b82f6"
                                }
                            }

                            StyledText {
                                text: (detailRoot.game && detailRoot.game.title) ? detailRoot.game.title : "Game Details"
                                font.bold: true
                                font.pixelSize: Theme.fontSizeLarge
                                color: win ? win.cTextMain : "#ffffff"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // Genres Flow
                            Flow {
                                Layout.fillWidth: true
                                spacing: 6
                                visible: detailRoot.game && detailRoot.game.genres

                                Repeater {
                                    model: {
                                        if (!detailRoot.game || !detailRoot.game.genres) return [];
                                        if (Array.isArray(detailRoot.game.genres)) return detailRoot.game.genres;
                                        return detailRoot.game.genres.toString().split(",").map(s => s.trim()).filter(s => s.length > 0);
                                    }

                                    Rectangle {
                                        height: 22
                                        implicitWidth: fullGenreText.implicitWidth + 12
                                        radius: (win && win.gridCornerRadius !== undefined) ? Math.min(11, win.gridCornerRadius) : 11
                                        color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(255, 255, 255, 0.08)
                                        border.width: 1
                                        border.color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.12)

                                        StyledText {
                                            id: fullGenreText
                                            text: modelData
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            color: win ? win.cTextSub : "#cbd5e1"
                                            anchors.centerIn: parent
                                        }
                                    }
                                }
                            }

                            // Expanded Stats Grid
                            Rectangle {
                                Layout.fillWidth: true
                                radius: (win && win.gridCornerRadius !== undefined) ? Math.min(14, win.gridCornerRadius) : 12
                                color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.03) : Qt.rgba(255, 255, 255, 0.04)
                                border.width: 1
                                border.color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(255, 255, 255, 0.08)
                                implicitHeight: fullStatsGrid.implicitHeight + 18

                                readonly property bool hasProvider: true

                                GridLayout {
                                    id: fullStatsGrid
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    columns: parent.hasProvider ? 4 : 3
                                    rowSpacing: 8
                                    columnSpacing: 14

                                    Column {
                                        spacing: 2
                                        StyledText { text: "Time Played"; font.pixelSize: Theme.fontSizeSmall - 2; color: win ? win.cTextSub : "#9ca3af" }
                                        StyledText { text: "0h 0m"; font.bold: true; font.pixelSize: Theme.fontSizeSmall; color: win ? win.cTextMain : "#ffffff" }
                                    }
                                    Column {
                                        spacing: 2
                                        StyledText { text: "Status"; font.pixelSize: Theme.fontSizeSmall - 2; color: win ? win.cTextSub : "#9ca3af" }
                                        StyledText {
                                            text: (detailRoot.game && detailRoot.game.uninstalled) ? "Not Installed" : "Ready to Play"
                                            font.bold: true
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: (detailRoot.game && detailRoot.game.uninstalled) ? (win ? win.cTextSub : "#9ca3af") : "#22c55e"
                                        }
                                    }
                                    Column {
                                        spacing: 2
                                        StyledText { text: "Platform"; font.pixelSize: Theme.fontSizeSmall - 2; color: win ? win.cTextSub : "#9ca3af" }
                                        StyledText {
                                            text: (detailRoot.game && detailRoot.game.launcher) ? detailRoot.game.launcher : "PC"
                                            font.bold: true
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: win ? win.cTextMain : "#ffffff"
                                        }
                                    }
                                    Column {
                                        visible: parent.parent.hasProvider
                                        spacing: 2
                                        StyledText { text: "Provider"; font.pixelSize: Theme.fontSizeSmall - 2; color: win ? win.cTextSub : "#9ca3af" }
                                        StyledText {
                                            text: {
                                                if (detailRoot.game && detailRoot.game.provider) return detailRoot.game.provider;
                                                if (detailRoot.game && detailRoot.game.cmd) {
                                                    let c = detailRoot.game.cmd.toString().toLowerCase();
                                                    if (c.includes("heroic")) return "Heroic";
                                                    if (c.includes("lutris")) return "Lutris";
                                                    if (c.includes("bottles")) return "Bottles";
                                                    if (c.includes("steam")) return "Steam";
                                                }
                                                if (detailRoot.game && detailRoot.game.launcher) {
                                                    let l = detailRoot.game.launcher.toString().toLowerCase();
                                                    if (l.includes("steam")) return "Steam Store";
                                                    if (l.includes("heroic")) return "Heroic";
                                                    if (l.includes("lutris")) return "Lutris";
                                                    if (l.includes("bottle")) return "Bottles";
                                                    return detailRoot.game.launcher;
                                                }
                                                return "Direct Launcher";
                                            }
                                            font.bold: true
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: win ? win.cAccent : "#3b82f6"
                                        }
                                    }
                                    Column {
                                        spacing: 2
                                        StyledText { text: "Release Year"; font.pixelSize: Theme.fontSizeSmall - 2; color: win ? win.cTextSub : "#9ca3af" }
                                        StyledText {
                                            text: (detailRoot.game && detailRoot.game.releaseDate) ? detailRoot.game.releaseDate : "Unknown"
                                            font.bold: true
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: win ? win.cTextMain : "#ffffff"
                                        }
                                    }
                                    Column {
                                        spacing: 2
                                        StyledText { text: "Developer"; font.pixelSize: Theme.fontSizeSmall - 2; color: win ? win.cTextSub : "#9ca3af" }
                                        StyledText {
                                            text: (detailRoot.game && detailRoot.game.developer) ? detailRoot.game.developer : "Unknown"
                                            font.bold: true
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: win ? win.cTextMain : "#ffffff"
                                            elide: Text.ElideRight
                                        }
                                    }
                                    Column {
                                        spacing: 2
                                        StyledText { text: "Publisher"; font.pixelSize: Theme.fontSizeSmall - 2; color: win ? win.cTextSub : "#9ca3af" }
                                        StyledText {
                                            text: (detailRoot.game && detailRoot.game.publisher) ? detailRoot.game.publisher : "Unknown"
                                            font.bold: true
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: win ? win.cTextMain : "#ffffff"
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }

                            // Play & Action Button Row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Rectangle {
                                    id: fullPlayBtn
                                    Layout.preferredHeight: 38
                                    Layout.preferredWidth: fullPlayRow.implicitWidth + 28
                                    radius: (win && win.gridCornerRadius !== undefined) ? Math.min(12, win.gridCornerRadius) : 10
                                    color: fullPlayMA.containsMouse
                                        ? (win ? Qt.darker(win.cAccent, 1.1) : "#2563eb")
                                        : (win ? win.cAccent : "#3b82f6")
                                    scale: fullPlayMA.containsMouse ? 1.04 : (fullPlayMA.pressed ? 0.96 : 1.0)
                                    opacity: fullPlayMA.pressed ? 0.85 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Row {
                                        id: fullPlayRow
                                        anchors.centerIn: parent
                                        spacing: 8

                                        DIcon {
                                            name: (detailRoot.game && detailRoot.game.uninstalled) ? "cloud_download" : "play_arrow"
                                            size: 18
                                            color: "#ffffff"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: (detailRoot.game && detailRoot.game.uninstalled) ? "Install Game" : "Play Now"
                                            font.bold: true
                                            font.pixelSize: Theme.fontSizeMedium - 1
                                            color: "#ffffff"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: fullPlayMA
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: detailRoot.launchGame()
                                    }
                                }

                                Rectangle {
                                    height: 38
                                    width: 38
                                    radius: (win && win.gridCornerRadius !== undefined) ? Math.min(12, win.gridCornerRadius) : 10
                                    color: fullEditMA.containsMouse ? (win ? win.cAccent : "#3b82f6") : (win && win.isLight ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(255, 255, 255, 0.06))
                                    border.width: 1
                                    border.color: fullEditMA.containsMouse ? (win ? win.cAccent : "#3b82f6") : (win && win.isLight ? Qt.rgba(0, 0, 0, 0.1) : Qt.rgba(255, 255, 255, 0.12))

                                    DIcon {
                                        name: "edit"
                                        size: 16
                                        color: fullEditMA.containsMouse ? "#ffffff" : (win ? win.cTextSub : "#9ca3af")
                                        anchors.centerIn: parent
                                    }

                                    MouseArea {
                                        id: fullEditMA
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (win && win.openMetadataEditor && detailRoot.game) {
                                                win.openMetadataEditor(detailRoot.game);
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    height: 38
                                    width: 38
                                    radius: (win && win.gridCornerRadius !== undefined) ? Math.min(12, win.gridCornerRadius) : 10
                                    color: fullOpenMA.containsMouse ? (win && win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.12)) : (win && win.isLight ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(255, 255, 255, 0.06))
                                    border.width: 1
                                    border.color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.1) : Qt.rgba(255, 255, 255, 0.12)

                                    DIcon {
                                        name: "open_in_new"
                                        size: 16
                                        color: fullOpenMA.containsMouse ? (win ? win.cAccent : "#3b82f6") : (win ? win.cTextSub : "#9ca3af")
                                        anchors.centerIn: parent
                                    }

                                    MouseArea {
                                        id: fullOpenMA
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            detailRoot.openGamePage();
                                        }
                                    }
                                }

                                Rectangle {
                                    height: 38
                                    width: 38
                                    radius: (win && win.gridCornerRadius !== undefined) ? Math.min(12, win.gridCornerRadius) : 10
                                    visible: detailRoot.game && !detailRoot.game.uninstalled
                                    color: fullDeleteMA.containsMouse ? Qt.rgba(239, 68, 68, 0.18) : (win && win.isLight ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(255, 255, 255, 0.06))
                                    border.width: 1
                                    border.color: fullDeleteMA.containsMouse ? "#ef4444" : (win && win.isLight ? Qt.rgba(0, 0, 0, 0.1) : Qt.rgba(255, 255, 255, 0.12))

                                    DIcon {
                                        name: "delete"
                                        size: 16
                                        color: fullDeleteMA.containsMouse ? "#ef4444" : (win ? win.cTextSub : "#9ca3af")
                                        anchors.centerIn: parent
                                    }

                                    MouseArea {
                                        id: fullDeleteMA
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (win && win.widgetRoot && win.widgetRoot.deleteGame && detailRoot.game) {
                                                win.widgetRoot.deleteGame(detailRoot.game);
                                            }
                                        }
                                    }
                                }
                            }

                            // Short Description Snippet
                            StyledText {
                                text: (detailRoot.game && detailRoot.game.description) ? detailRoot.game.description : ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: win ? win.cTextSub : "#cbd5e1"
                                wrapMode: Text.WordWrap
                                lineHeight: 1.25
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                visible: text !== ""
                            }
                        }
                    }
                }

                    // ── CONTAINER 2: TRAILERS & VIDEO PREVIEWS CARD ───────────────────────
                    Rectangle {
                        id: fullTrailersCard
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        radius: (win && win.gridCornerRadius !== undefined) ? win.gridCornerRadius : 16
                        color: Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                        border.width: 1
                        border.color: (typeof Theme !== "undefined" && Theme.outlineMedium) ? Theme.outlineMedium : (win && win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.10))
                        implicitHeight: fullTrailerCol.implicitHeight + 24
                        visible: true
                        clip: true

                        ColumnLayout {
                        id: fullTrailerCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            DIcon { name: "smart_display"; size: 16; color: win ? win.cAccent : "#3b82f6" }
                            StyledText {
                                text: "Trailers & Video Previews"
                                font.bold: true
                                font.pixelSize: Theme.fontSizeSmall
                                color: win ? win.cAccent : "#3b82f6"
                            }
                            Item { Layout.fillWidth: true }
                            StyledText {
                                text: (detailRoot.game && detailRoot.game.trailers && detailRoot.game.trailers.length > 0) ? (detailRoot.game.trailers.length + " Available") : "Preview Image"
                                font.pixelSize: Theme.fontSizeSmall - 2
                                color: win ? win.cTextSub : "#9ca3af"
                            }
                        }

                        // Video Content when available
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14
                            visible: (detailRoot.game && detailRoot.game.trailers && detailRoot.game.trailers.length > 0)

                            ClippingRectangle {
                                id: fullPreviewCard
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.round(fullTrailerCol.width * 0.5625) // 16:9
                                radius: (win && win.gridCornerRadius !== undefined) ? win.gridCornerRadius : 14
                                color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(255, 255, 255, 0.06)
                                border.width: 1
                                border.color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(255, 255, 255, 0.15)

                                Image {
                                    anchors.fill: parent
                                    source: {
                                        if (detailRoot.game && detailRoot.game.trailers && detailRoot.game.trailers.length > 0) {
                                            let t = detailRoot.game.trailers[0];
                                            if (t.thumbnail) return t.thumbnail;
                                        }
                                        if (detailRoot.game && detailRoot.game.screenshots && detailRoot.game.screenshots.length > 0)
                                            return detailRoot.game.screenshots[0];
                                        if (detailRoot.game && detailRoot.game.backgroundUrl)
                                            return detailRoot.game.backgroundUrl;
                                        return "";
                                    }
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 52; height: 52; radius: 26
                                    color: fullPlayTrailerMA.containsMouse ? (win ? win.cAccent : "#3b82f6") : Qt.rgba(0, 0, 0, 0.7)
                                    border.width: 1.5
                                    border.color: "#ffffff"

                                    DIcon {
                                        name: "play_arrow"
                                        size: 28
                                        color: "#ffffff"
                                        anchors.centerIn: parent
                                    }

                                    MouseArea {
                                        id: fullPlayTrailerMA
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            // Animate thumbnail into preview area then start playback
                                            trailerStartAnim.start();
                                            if (detailRoot.game && detailRoot.game.trailers && detailRoot.game.trailers.length > 0) {
                                                let url = detailRoot.game.trailers[0].localVideo || detailRoot.game.trailers[0].url;
                                                if (url) {
                                                    if (url.startsWith("http://") || url.startsWith("https://") || url.startsWith("file://") || url.startsWith("/")) {
                                                        detailRoot.activeTrailerUrl = url;
                                                        detailRoot.isPlayingTrailer = true;
                                                        heroVideoPlayer.play();
                                                    } else {
                                                        Qt.openUrlExternally(url);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.right: parent.right
                                    anchors.margins: 8
                                    height: 22
                                    width: previewBadgeRow.implicitWidth + 12
                                    radius: 5
                                    color: Qt.rgba(0, 0, 0, 0.65)

                                    Row {
                                        id: previewBadgeRow
                                        anchors.centerIn: parent
                                        spacing: 4
                                        DIcon { name: "play_circle"; size: 12; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                                        StyledText { text: "HD Preview"; font.pixelSize: Theme.fontSizeSmall - 3; font.bold: true; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                }
                            }

                            SequentialAnimation {
                                 id: trailerStartAnim
                                 NumberAnimation {
                                     target: fullPreviewCard
                                     property: "scale"
                                     from: 1.0; to: 1.06
                                     duration: 80; easing.type: Easing.OutCubic
                                 }
                                 NumberAnimation {
                                     target: fullPreviewCard
                                     property: "scale"
                                     to: 1.0
                                     duration: 80; easing.type: Easing.InCubic
                                 }
                             }

                             ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 6

                                StyledText {
                                    text: (detailRoot.game && detailRoot.game.trailers && detailRoot.game.trailers.length > 0 && detailRoot.game.trailers[0].name)
                                        ? detailRoot.game.trailers[0].name
                                        : ((detailRoot.game && detailRoot.game.title ? detailRoot.game.title : "Game") + " Official Cinematic Trailer")
                                    font.bold: true
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: win ? win.cTextMain : "#ffffff"
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: "Watch gameplay clips, teaser teasers, and promotional trailers in full quality."
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: win ? win.cTextSub : "#9ca3af"
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        // Trailer Unavailable Fallback Card
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 180
                            radius: (win && win.gridCornerRadius !== undefined) ? win.gridCornerRadius : 14
                            color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(255, 255, 255, 0.04)
                            border.width: 1
                            border.color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.08)
                            visible: !(detailRoot.game && detailRoot.game.trailers && detailRoot.game.trailers.length > 0)

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                DIcon {
                                    name: "videocam_off"
                                    size: 36
                                    color: win ? win.cTextSub : "#9ca3af"
                                    opacity: 0.6
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                StyledText {
                                    text: "Trailer Unavailable"
                                    font.bold: true
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: win ? win.cTextSub : "#9ca3af"
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                StyledText {
                                    text: "No video preview found for this game"
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: win ? win.cTextSub : "#9ca3af"
                                    opacity: 0.75
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                }

                    // ── CONTAINER 3: MEDIA & SCREENSHOTS CARD ────────────────────────────
                    Rectangle {
                        id: fullMediaGalleryCard
                        Layout.fillWidth: true
                        radius: (win && win.gridCornerRadius !== undefined) ? win.gridCornerRadius : 16
                        color: Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                        border.width: 1
                        border.color: (typeof Theme !== "undefined" && Theme.outlineMedium) ? Theme.outlineMedium : (win && win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.10))
                        implicitHeight: fullMediaInnerCol.implicitHeight + 24
                        visible: detailRoot.game && detailRoot.game.screenshots && detailRoot.game.screenshots.length > 0
                        clip: true

                        ColumnLayout {
                            id: fullMediaInnerCol
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                DIcon { name: "photo_library"; size: 16; color: win ? win.cAccent : "#3b82f6" }
                                StyledText {
                                    text: "Media & Screenshots"
                                    font.bold: true
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: win ? win.cAccent : "#3b82f6"
                                }
                                Item { Layout.fillWidth: true }
                                StyledText {
                                    text: (detailRoot.game && detailRoot.game.screenshots) ? (detailRoot.game.screenshots.length + " Photos") : ""
                                    font.pixelSize: Theme.fontSizeSmall - 2
                                    color: win ? win.cTextSub : "#9ca3af"
                                }
                            }

                            ScrollView {
                                Layout.fillWidth: true
                                implicitHeight: 120
                                clip: true
                                ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                                ScrollBar.horizontal.policy: ScrollBar.AsNeeded

                                Row {
                                    spacing: 12

                                    Repeater {
                                        model: (detailRoot.game && detailRoot.game.screenshots) ? detailRoot.game.screenshots : []

                                        ClippingRectangle {
                                            width: 196
                                            height: 110 // 16:9 ratio thumbnail
                                            radius: (win && win.gridCornerRadius !== undefined) ? Math.min(12, win.gridCornerRadius) : 10
                                            color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(255, 255, 255, 0.06)
                                            border.width: 1
                                            border.color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.1) : Qt.rgba(255, 255, 255, 0.12)

                                            Image {
                                                anchors.fill: parent
                                                source: modelData
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (win) {
                                                        win.fullscreenPhotoList = detailRoot.game.screenshots || [];
                                                        win.fullscreenPhotoIndex = index;
                                                        win.showPhotoViewer = true;
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
            }
        }
    }

    // =========================================================================
    // 2. SIDE-BY-SIDE PRESENTATION MODE (Matching Screenshot 1 - Playnite / Epic)
    // =========================================================================
    Item {
        id: sideBySideLayout
        anchors.fill: parent
        visible: !detailRoot.isFullScreenMode

        // Backdrop Image + Blur/Gradient with clipped rounded corners
        ClippingRectangle {
            anchors.fill: parent
            radius: (win && win.gridCornerRadius !== undefined) ? win.gridCornerRadius : 16
            color: win && win.isLight ? Qt.rgba(0.95, 0.96, 0.98, 0.50) : Qt.rgba(0.08, 0.09, 0.12, 0.50)
            clip: true

            Image {
                id: sideBgHero
                anchors.fill: parent
                source: (detailRoot.game && detailRoot.game.backgroundUrl) ? detailRoot.game.backgroundUrl : ((detailRoot.game && detailRoot.game.coverUrl) ? detailRoot.game.coverUrl : "")
                fillMode: Image.PreserveAspectCrop
                opacity: win && win.isLight ? 0.18 : 0.24
                asynchronous: true
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: win && win.isLight ? Qt.rgba(0.95, 0.96, 0.98, 0.7) : Qt.rgba(0.06, 0.07, 0.10, 0.75) }
                    GradientStop { position: 0.5; color: win && win.isLight ? Qt.rgba(0.95, 0.96, 0.98, 0.92) : Qt.rgba(0.07, 0.08, 0.11, 0.92) }
                    GradientStop { position: 1.0; color: win && win.isLight ? Qt.rgba(0.95, 0.96, 0.98, 0.99) : Qt.rgba(0.07, 0.08, 0.11, 0.99) }
                }
            }
        }

        // Top Action Bar (Close pill + Platform tag + Edit Meta + Metascore)
        Item {
            id: sideTopBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 52
            z: 30

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                // Close Button (Icon-only circular button)
                Rectangle {
                    width: 34
                    height: 34
                        radius: 17
                        color: sideBackBtnMA.containsMouse ? (win && win.isLight ? Qt.rgba(0,0,0,0.08) : Qt.rgba(255,255,255,0.12)) : (win && win.isLight ? Qt.rgba(0,0,0,0.04) : Qt.rgba(255,255,255,0.06))
                        border.width: 1
                        border.color: sideBackBtnMA.containsMouse ? (win ? win.cAccent : "#3b82f6") : (win && win.isLight ? Qt.rgba(0,0,0,0.1) : Qt.rgba(255,255,255,0.1))

                    Behavior on color { ColorAnimation { duration: 120 } }

                    DIcon {
                        name: "close"
                        size: 16
                        color: sideBackBtnMA.containsMouse ? (win ? win.cAccent : "#3b82f6") : (win ? win.cTextMain : "#ffffff")
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: sideBackBtnMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: detailRoot.closeRequested()
                    }
                }

                Item { Layout.fillWidth: true }

                // Platform tag with official SVG icon if available
                Rectangle {
                    height: 30
                    implicitWidth: sidePlatRow.implicitWidth + 18
                        radius: 15
                        color: win && win.isLight ? Qt.rgba(0,0,0,0.06) : Qt.rgba(255,255,255,0.08)
                        border.width: 1
                        border.color: win && win.isLight ? Qt.rgba(0,0,0,0.08) : Qt.rgba(255,255,255,0.1)

                    readonly property string platSvg: (win && detailRoot.game) ? win.getPlatformIcon(detailRoot.game.launcher) : ""

                    Row {
                        id: sidePlatRow
                        anchors.centerIn: parent
                        spacing: 6

                        Image {
                            source: parent.parent.platSvg
                            width: 14
                            height: 14
                            fillMode: Image.PreserveAspectFit
                            visible: parent.parent.platSvg !== ""
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        DIcon {
                            name: (win && detailRoot.game) ? win.getPlatformMaterialIcon(detailRoot.game.launcher) : "sports_esports"
                            size: 13
                            color: win ? win.cAccent : "#3b82f6"
                            visible: parent.parent.platSvg === ""
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: (detailRoot.game && detailRoot.game.launcher) ? detailRoot.game.launcher.toUpperCase() : ""
                            font.pixelSize: Theme.fontSizeSmall - 2
                            font.bold: true
                            color: win ? win.cTextSub : "#9ca3af"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Edit Metadata Button
                Rectangle {
                    width: 32; height: 32; radius: 16
                        color: sideEditMetaMA.containsMouse ? (win && win.isLight ? Qt.rgba(0,0,0,0.08) : Qt.rgba(255,255,255,0.12)) : "transparent"
                        border.width: 1
                        border.color: sideEditMetaMA.containsMouse ? (win ? win.cAccent : "#3b82f6") : (win && win.isLight ? Qt.rgba(0,0,0,0.1) : Qt.rgba(255,255,255,0.1))

                    DIcon {
                        name: "edit"
                        size: 15
                        color: sideEditMetaMA.containsMouse ? (win ? win.cAccent : "#3b82f6") : (win ? win.cTextSub : "#9ca3af")
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: sideEditMetaMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (win && win.openMetadataEditor) {
                                win.openMetadataEditor(detailRoot.game);
                            }
                        }
                    }
                }
            }
        }

        // Scrollable Side Content
        ScrollView {
            id: sideScrollView
            anchors.top: sideTopBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: sideScrollView.availableWidth
                spacing: 16

                // Hero Cover + Main Header Row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 4
                    spacing: 16

                    // Game Cover with strict 2:3 ratio and user-defined corner radius
                    ClippingRectangle {
                        id: sideCoverCard
                        Layout.preferredWidth: detailRoot.width > 500 ? 160 : 130
                        Layout.preferredHeight: Math.round(sideCoverCard.Layout.preferredWidth * 1.50) // Strict 2:3 ratio
                        radius: (win && win.gridCornerRadius !== undefined) ? win.gridCornerRadius : 16
                        color: win && win.isLight ? Qt.rgba(0,0,0,0.06) : Qt.rgba(255,255,255,0.06)
                        border.width: 1
                        border.color: win && win.isLight ? Qt.rgba(0,0,0,0.12) : Qt.rgba(255,255,255,0.15)

                        Image {
                            anchors.fill: parent
                            source: (detailRoot.game && detailRoot.game.coverUrl) ? detailRoot.game.coverUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        DIcon {
                            name: "sports_esports"
                            size: 40
                            color: win ? win.cAccent : "#3b82f6"
                            opacity: 0.4
                            anchors.centerIn: parent
                            visible: !detailRoot.game || !detailRoot.game.coverUrl
                        }
                    }

                    // Info & Actions Column
                        ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 8

                        // Title
                        StyledText {
                            text: (detailRoot.game && detailRoot.game.title) ? detailRoot.game.title : "Game Details"
                            font.bold: true
                            font.pixelSize: Theme.fontSizeLarge
                            color: win ? win.cTextMain : "#ffffff"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        // Developer & Release Info subtitle
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: detailRoot.game && (detailRoot.game.developer || detailRoot.game.releaseDate)

                            StyledText {
                                text: {
                                    let parts = [];
                                    if (detailRoot.game && detailRoot.game.releaseDate) parts.push(detailRoot.game.releaseDate);
                                    if (detailRoot.game && detailRoot.game.developer) parts.push(detailRoot.game.developer);
                                    return parts.join(" • ");
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: win ? win.cTextSub : "#9ca3af"
                            }
                        }

                        // Genres
                        Flow {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: detailRoot.game && detailRoot.game.genres

                            Repeater {
                                model: {
                                    if (!detailRoot.game || !detailRoot.game.genres) return [];
                                    if (Array.isArray(detailRoot.game.genres)) return detailRoot.game.genres;
                                    return detailRoot.game.genres.toString().split(",").map(s => s.trim()).filter(s => s.length > 0);
                                }

                                Rectangle {
                                    height: 20
                                    implicitWidth: sideGenreText.implicitWidth + 10
                                    radius: 10
                                    color: win && win.isLight ? Qt.rgba(0,0,0,0.05) : Qt.rgba(255,255,255,0.08)
                                    border.width: 1
                                    border.color: win && win.isLight ? Qt.rgba(0,0,0,0.08) : Qt.rgba(255,255,255,0.12)

                                    StyledText {
                                        id: sideGenreText
                                        text: modelData
                                        font.pixelSize: Theme.fontSizeSmall - 3
                                        color: win ? win.cTextSub : "#cbd5e1"
                                        anchors.centerIn: parent
                                    }
                                }
                            }
                        }

                        Item { height: 4 }

                        // Play / Install & Provider Actions Row
                        RowLayout {
                            spacing: 8

                            Rectangle {
                                id: sidePlayBtn
                                height: 38
                                implicitWidth: sidePlayRow.implicitWidth + 24
                                radius: (win && win.gridCornerRadius !== undefined) ? Math.min(10, win.gridCornerRadius) : 8
                                color: sidePlayBtnMA.containsMouse
                                    ? (win ? Qt.darker(win.cAccent, 1.1) : "#2563eb")
                                    : (win ? win.cAccent : "#3b82f6")
                                scale: sidePlayBtnMA.containsMouse ? 1.04 : (sidePlayBtnMA.pressed ? 0.96 : 1.0)
                                opacity: sidePlayBtnMA.pressed ? 0.85 : 1.0
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Row {
                                    id: sidePlayRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    DIcon {
                                        name: (detailRoot.game && detailRoot.game.uninstalled) ? "cloud_download" : "play_arrow"
                                        size: 16
                                        color: "#ffffff"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: (detailRoot.game && detailRoot.game.uninstalled) ? "Install" : "Play"
                                        font.bold: true
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: "#ffffff"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: sidePlayBtnMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: detailRoot.launchGame()
                                }
                            }

                            // Open Provider Launcher
                            Rectangle {
                                height: 38
                                width: 38
                                radius: (win && win.gridCornerRadius !== undefined) ? Math.min(10, win.gridCornerRadius) : 8
                                color: sideOpenMA.containsMouse ? (win && win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.12)) : (win && win.isLight ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(255, 255, 255, 0.06))
                                border.width: 1
                                border.color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.1) : Qt.rgba(255, 255, 255, 0.12)

                                DIcon {
                                    name: "open_in_new"
                                    size: 16
                                    color: sideOpenMA.containsMouse ? (win ? win.cAccent : "#3b82f6") : (win ? win.cTextSub : "#9ca3af")
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    id: sideOpenMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: detailRoot.openGamePage()
                                }
                            }

                            // Delete / Uninstall via Provider
                            Rectangle {
                                height: 38
                                width: 38
                                radius: (win && win.gridCornerRadius !== undefined) ? Math.min(10, win.gridCornerRadius) : 8
                                visible: detailRoot.game && !detailRoot.game.uninstalled
                                color: sideDeleteMA.containsMouse ? Qt.rgba(239, 68, 68, 0.18) : (win && win.isLight ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(255, 255, 255, 0.06))
                                border.width: 1
                                border.color: sideDeleteMA.containsMouse ? "#ef4444" : (win && win.isLight ? Qt.rgba(0, 0, 0, 0.1) : Qt.rgba(255, 255, 255, 0.12))

                                DIcon {
                                    name: "delete"
                                    size: 16
                                    color: sideDeleteMA.containsMouse ? "#ef4444" : (win ? win.cTextSub : "#9ca3af")
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    id: sideDeleteMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (win && win.widgetRoot && win.widgetRoot.deleteGame && detailRoot.game) {
                                            win.widgetRoot.deleteGame(detailRoot.game);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Stats Tiles Grid
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                        radius: (win && win.gridCornerRadius !== undefined) ? Math.min(14, win.gridCornerRadius) : 12
                        color: win && win.isLight ? Qt.rgba(0,0,0,0.03) : Qt.rgba(255,255,255,0.04)
                        border.width: 1
                        border.color: win && win.isLight ? Qt.rgba(0,0,0,0.07) : Qt.rgba(255,255,255,0.08)
                        implicitHeight: sideStatsGrid.implicitHeight + 20
                        clip: true

                    GridLayout {
                        id: sideStatsGrid
                        anchors.fill: parent
                        anchors.margins: 10
                        columns: detailRoot.width > 550 ? 3 : 2
                        rowSpacing: 10
                        columnSpacing: 12

                        Column {
                            spacing: 2
                            StyledText { text: "Status"; font.pixelSize: Theme.fontSizeSmall - 2; color: win ? win.cTextSub : "#9ca3af" }
                            StyledText {
                                text: (detailRoot.game && detailRoot.game.uninstalled) ? "Not Installed" : "Ready to Play"
                                font.bold: true
                                font.pixelSize: Theme.fontSizeSmall
                                color: (detailRoot.game && detailRoot.game.uninstalled) ? (win ? win.cTextSub : "#9ca3af") : "#22c55e"
                            }
                        }

                        Column {
                            spacing: 2
                            StyledText { text: "Platform"; font.pixelSize: Theme.fontSizeSmall - 2; color: win ? win.cTextSub : "#9ca3af" }
                            StyledText {
                                text: (detailRoot.game && detailRoot.game.launcher) ? detailRoot.game.launcher : "PC"
                                font.bold: true
                                font.pixelSize: Theme.fontSizeSmall
                                color: win ? win.cTextMain : "#ffffff"
                            }
                        }

                        Column {
                            visible: true
                            spacing: 2
                            StyledText { text: "Provider"; font.pixelSize: Theme.fontSizeSmall - 2; color: win ? win.cTextSub : "#9ca3af" }
                            StyledText {
                                text: {
                                    if (detailRoot.game && detailRoot.game.provider) return detailRoot.game.provider;
                                    if (detailRoot.game && detailRoot.game.cmd) {
                                        let c = detailRoot.game.cmd.toString().toLowerCase();
                                        if (c.includes("heroic")) return "Heroic";
                                        if (c.includes("lutris")) return "Lutris";
                                        if (c.includes("bottles")) return "Bottles";
                                        if (c.includes("steam")) return "Steam";
                                    }
                                    if (detailRoot.game && detailRoot.game.launcher) {
                                        let l = detailRoot.game.launcher.toString().toLowerCase();
                                        if (l.includes("steam")) return "Steam Store";
                                        if (l.includes("heroic")) return "Heroic";
                                        if (l.includes("lutris")) return "Lutris";
                                        if (l.includes("bottle")) return "Bottles";
                                        return detailRoot.game.launcher;
                                    }
                                    return "Direct Launcher";
                                }
                                font.bold: true
                                font.pixelSize: Theme.fontSizeSmall
                                color: win ? win.cAccent : "#3b82f6"
                            }
                        }

                        Column {
                            spacing: 2
                            StyledText { text: "Release Year"; font.pixelSize: Theme.fontSizeSmall - 2; color: win ? win.cTextSub : "#9ca3af" }
                            StyledText {
                                text: (detailRoot.game && detailRoot.game.releaseDate) ? detailRoot.game.releaseDate : "Unknown"
                                font.bold: true
                                font.pixelSize: Theme.fontSizeSmall
                                color: win ? win.cTextMain : "#ffffff"
                            }
                        }

                        Column {
                            spacing: 2
                            StyledText { text: "Developer"; font.pixelSize: Theme.fontSizeSmall - 2; color: win ? win.cTextSub : "#9ca3af" }
                            StyledText {
                                text: (detailRoot.game && detailRoot.game.developer) ? detailRoot.game.developer : "Unknown"
                                font.bold: true
                                font.pixelSize: Theme.fontSizeSmall
                                color: win ? win.cTextMain : "#ffffff"
                                elide: Text.ElideRight
                            }
                        }

                        Column {
                            spacing: 2
                            StyledText { text: "Publisher"; font.pixelSize: Theme.fontSizeSmall - 2; color: win ? win.cTextSub : "#9ca3af" }
                            StyledText {
                                text: (detailRoot.game && detailRoot.game.publisher) ? detailRoot.game.publisher : "Unknown"
                                font.bold: true
                                font.pixelSize: Theme.fontSizeSmall
                                color: win ? win.cTextMain : "#ffffff"
                                elide: Text.ElideRight
                            }
                        }

                        Column {
                            spacing: 2
                            StyledText { text: "Critic Score"; font.pixelSize: Theme.fontSizeSmall - 2; color: win ? win.cTextSub : "#9ca3af" }
                            StyledText {
                                text: (detailRoot.game && detailRoot.game.metascore) ? (detailRoot.game.metascore + " / 100") : "Not Scored"
                                font.bold: true
                                font.pixelSize: Theme.fontSizeSmall
                                color: (detailRoot.game && detailRoot.game.metascore) ? (win ? win.cAccent : "#3b82f6") : (win ? win.cTextSub : "#9ca3af")
                            }
                        }
                    }
                }

                // ── CONTAINER 1b: ABOUT / DESCRIPTION CARD ──────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                        radius: (win && win.gridCornerRadius !== undefined) ? win.gridCornerRadius : 14
                        color: Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                        border.width: 1
                        border.color: (typeof Theme !== "undefined" && Theme.outlineMedium) ? Theme.outlineMedium : (win && win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.10))
                        implicitHeight: sideDescCol.implicitHeight + 24
                    visible: detailRoot.game && detailRoot.game.description
                        clip: true

                        ColumnLayout {
                        id: sideDescCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        RowLayout {
                            spacing: 6
                            DIcon { name: "description"; size: 15; color: win ? win.cAccent : "#3b82f6" }
                            StyledText { text: "About & Storyline"; font.bold: true; font.pixelSize: Theme.fontSizeSmall; color: win ? win.cAccent : "#3b82f6" }
                        }

                        StyledText {
                            text: (detailRoot.game && detailRoot.game.description) ? detailRoot.game.description : ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: win ? win.cTextSub : "#cbd5e1"
                            wrapMode: Text.WordWrap
                            lineHeight: 1.25
                            Layout.fillWidth: true
                        }
                    }
                }

                // ── CONTAINER 2: TRAILERS & VIDEO PREVIEWS CARD ───────────────────────
                Rectangle {
                    id: sideTrailersCard
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                        radius: (win && win.gridCornerRadius !== undefined) ? win.gridCornerRadius : 14
                        color: Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                        border.width: 1
                        border.color: (typeof Theme !== "undefined" && Theme.outlineMedium) ? Theme.outlineMedium : (win && win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.10))
                        implicitHeight: sideTrailerCol.implicitHeight + 24
                    visible: true
                        clip: true

                        ColumnLayout {
                        id: sideTrailerCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            spacing: 6
                            DIcon { name: "smart_display"; size: 15; color: win ? win.cAccent : "#3b82f6" }
                            StyledText { text: "Trailers & Previews"; font.bold: true; font.pixelSize: Theme.fontSizeSmall; color: win ? win.cAccent : "#3b82f6" }
                        }

                        readonly property bool hasTrailer: detailRoot.game && detailRoot.game.trailers && detailRoot.game.trailers.length > 0

                        ClippingRectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(200, Math.round((parent.width - 24) * 0.5625)) // 16:9 ratio
                            radius: (win && win.gridCornerRadius !== undefined) ? Math.min(12, win.gridCornerRadius) : 10
                            color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(255, 255, 255, 0.06)
                            border.width: 1
                            border.color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.1) : Qt.rgba(255, 255, 255, 0.12)
                            visible: sideTrailerCol.hasTrailer

                            Image {
                                anchors.fill: parent
                                source: (sideTrailerCol.hasTrailer && detailRoot.game.trailers[0].thumbnail) ? detailRoot.game.trailers[0].thumbnail : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 44; height: 44; radius: 22
                                color: sidePlayTrailerMA.containsMouse ? (win ? win.cAccent : "#3b82f6") : Qt.rgba(0, 0, 0, 0.7)
                                border.width: 1.5
                                border.color: "#ffffff"

                                DIcon {
                                    name: "play_arrow"
                                    size: 24
                                    color: "#ffffff"
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    id: sidePlayTrailerMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (sideTrailerCol.hasTrailer) {
                                            let url = detailRoot.game.trailers[0].url || detailRoot.game.trailers[0].localVideo;
                                            if (url) Qt.openUrlExternally(url);
                                        }
                                    }
                                }
                            }
                        }

                        // Side Trailer Unavailable Fallback Card
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            radius: (win && win.gridCornerRadius !== undefined) ? Math.min(12, win.gridCornerRadius) : 10
                            color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(255, 255, 255, 0.04)
                            border.width: 1
                            border.color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.08)
                            visible: !sideTrailerCol.hasTrailer

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                DIcon {
                                    name: "videocam_off"
                                    size: 28
                                    color: win ? win.cTextSub : "#9ca3af"
                                    opacity: 0.6
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                StyledText {
                                    text: "Trailer Unavailable"
                                    font.bold: true
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: win ? win.cTextSub : "#9ca3af"
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                }

                // ── CONTAINER 3: MEDIA & SCREENSHOTS GALLERY CARD ────────────────────
                Rectangle {
                    id: sideMediaGalleryCard
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                        radius: (win && win.gridCornerRadius !== undefined) ? win.gridCornerRadius : 14
                        color: Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                        border.width: 1
                        border.color: (typeof Theme !== "undefined" && Theme.outlineMedium) ? Theme.outlineMedium : (win && win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.10))
                        implicitHeight: sideMediaInnerCol.implicitHeight + 24
                    visible: detailRoot.game && detailRoot.game.screenshots && detailRoot.game.screenshots.length > 0
                        clip: true

                        ColumnLayout {
                        id: sideMediaInnerCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            spacing: 6
                            DIcon { name: "photo_library"; size: 15; color: win ? win.cAccent : "#3b82f6" }
                            StyledText { text: "Media & Screenshots"; font.bold: true; font.pixelSize: Theme.fontSizeSmall; color: win ? win.cAccent : "#3b82f6" }
                            Item { Layout.fillWidth: true }
                            StyledText {
                                text: (detailRoot.game && detailRoot.game.screenshots) ? (detailRoot.game.screenshots.length + " Photos") : ""
                                font.pixelSize: Theme.fontSizeSmall - 2
                                color: win ? win.cTextSub : "#9ca3af"
                            }
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            implicitHeight: 120
                            clip: true
                            ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                            ScrollBar.horizontal.policy: ScrollBar.AsNeeded

                            Row {
                                spacing: 10
                                Repeater {
                                    model: (detailRoot.game && detailRoot.game.screenshots) ? detailRoot.game.screenshots : []

                                    ClippingRectangle {
                                        width: 180
                                        height: 102
                                        radius: (win && win.gridCornerRadius !== undefined) ? Math.min(12, win.gridCornerRadius) : 10
                                        color: win && win.isLight ? Qt.rgba(0,0,0,0.05) : Qt.rgba(255,255,255,0.06)
                                        border.width: 1
                                        border.color: win && win.isLight ? Qt.rgba(0,0,0,0.1) : Qt.rgba(255,255,255,0.12)

                                        Image {
                                            anchors.fill: parent
                                            source: modelData
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item { height: 8 }
            }
        }
    }
}
