import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Widgets
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets

Item {
    id: gridRoot

    // Reference to parent window (GameHubWindow)
    property var win: null

    // Sizing for standard 2:3 vertical covers (e.g. 600x900)
    // Sized dynamically based on user-configured cardsPerRow (4 to 10), cardGap (4 to 28px), and available width
    readonly property int cardsPerRow: (win && win.gridCardsPerRow) ? Math.max(4, Math.min(10, win.gridCardsPerRow)) : 6
    readonly property int cardCornerRadius: (win && win.gridCornerRadius !== undefined) ? Math.max(0, Math.min(32, win.gridCornerRadius)) : 16
    readonly property int cardGap: (win && win.gridCardGap !== undefined) ? Math.max(4, Math.min(28, win.gridCardGap)) : 12
    readonly property bool showTitle: (win && win.gridShowTitle !== undefined) ? win.gridShowTitle : true

    // Dynamic symmetrical side margin: centers the cards row perfectly so left gap equals right gap
    readonly property real minSideMargin: 12
    readonly property real dynamicGridSideMargin: {
        let totalW = gridRoot.width;
        if (totalW <= 0) return 12;
        let cW = dynamicCellWidth;
        let rowContentW = cW * cardsPerRow;
        let remainder = totalW - rowContentW;
        return Math.max(minSideMargin, Math.floor(remainder / 2));
    }
    readonly property real gridSideMargin: dynamicGridSideMargin
    readonly property real availableGridWidth: Math.max(200, gridRoot.width - (minSideMargin * 2))
    readonly property int dynamicCellWidth: Math.max(120, Math.floor(availableGridWidth / cardsPerRow))
    readonly property int dynamicCardWidth: Math.max(100, dynamicCellWidth - cardGap)
    readonly property int dynamicCoverHeight: Math.round(dynamicCardWidth * 1.54)
    readonly property int dynamicFooterHeight: showTitle ? 52 : 0
    // dynamicCellHeight includes dynamicCoverHeight + dynamicFooterHeight + cardGap, plus 24px safety clearance for card lift (-6px), glow (-6px), and shadow
    readonly property int dynamicCellHeight: dynamicCoverHeight + dynamicFooterHeight + cardGap + 36

    property int cellWidth: dynamicCellWidth
    property int cellHeight: dynamicCellHeight

    // Keyboard navigation focus index (-1 = none active)
    property int keyboardFocusIndex: -1

    function resetKeyboardFocus() {
        keyboardFocusIndex = -1;
    }

    function ensureFocused() {
        if (!gameGridView.activeFocus) {
            gameGridView.forceActiveFocus();
        }
    }

    function moveLeft() {
        let total = (win && win.gameList) ? win.gameList.length : 0;
        if (total === 0) return;
        keyboardFocusIndex = Math.max(0, (keyboardFocusIndex <= 0 ? 0 : keyboardFocusIndex - 1));
        gameGridView.currentIndex = keyboardFocusIndex;
        gameGridView.positionViewAtIndex(keyboardFocusIndex, GridView.Contain);
        ensureFocused();
    }

    function moveRight() {
        let total = (win && win.gameList) ? win.gameList.length : 0;
        if (total === 0) return;
        keyboardFocusIndex = Math.min(total - 1, (keyboardFocusIndex < 0 ? 0 : keyboardFocusIndex + 1));
        gameGridView.currentIndex = keyboardFocusIndex;
        gameGridView.positionViewAtIndex(keyboardFocusIndex, GridView.Contain);
        ensureFocused();
    }

    function moveUp() {
        let total = (win && win.gameList) ? win.gameList.length : 0;
        if (total === 0) return;
        let cols = cardsPerRow;
        keyboardFocusIndex = Math.max(0, (keyboardFocusIndex < cols ? 0 : keyboardFocusIndex - cols));
        gameGridView.currentIndex = keyboardFocusIndex;
        gameGridView.positionViewAtIndex(keyboardFocusIndex, GridView.Contain);
        ensureFocused();
    }

    function moveDown() {
        let total = (win && win.gameList) ? win.gameList.length : 0;
        if (total === 0) return;
        let cols = cardsPerRow;
        keyboardFocusIndex = Math.min(total - 1, (keyboardFocusIndex < 0 ? 0 : keyboardFocusIndex + cols));
        gameGridView.currentIndex = keyboardFocusIndex;
        gameGridView.positionViewAtIndex(keyboardFocusIndex, GridView.Contain);
        ensureFocused();
    }

    function activateCurrent() {
        let total = (win && win.gameList) ? win.gameList.length : 0;
        if (keyboardFocusIndex >= 0 && keyboardFocusIndex < total) {
            let g = win.gameList[keyboardFocusIndex];
            if (win) {
                if (win.collapseHub) win.collapseHub();
                if (win.tuckFilterBar) win.tuckFilterBar();
                win.selectedGame = g;
            }
        }
    }

    Component.onCompleted: {
        Qt.callLater(ensureFocused);
    }

    // ── CONTEXT MENU STATE ──────────────────────────────────────────
    property bool isContextMenuOpen: contextMenuOverlay.visible
    property var contextGame: null
    property real contextMenuX: 0
    property real contextMenuY: 0

    function closeContextMenu() {
        contextMenuOverlay.visible = false;
        contextGame = null;
    }

    function openContextMenu(game, globalX, globalY) {
        if (!game) return;
        contextGame = game;
        // Map global coordinates into gridRoot space
        let local = gridRoot.mapFromItem(null, globalX, globalY);
        let menuW = 200;
        let menuH = 90;
        contextMenuX = Math.max(8, Math.min(local.x, gridRoot.width - menuW - 12));
        contextMenuY = Math.max(8, Math.min(local.y, gridRoot.height - menuH - 12));
        contextMenuOverlay.visible = true;
    }

    // Loading Indicator
    Column {
        anchors.centerIn: parent
        spacing: 12
        visible: win && win.isScanning && win.gameList.length === 0

        DIcon {
            name: "refresh"
            size: 40
            color: win ? win.cAccent : "#3b82f6"
            anchors.horizontalCenter: parent.horizontalCenter
            RotationAnimation on rotation {
                from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: parent.visible
            }
        }
        StyledText {
            text: "Scanning game libraries..."
            font.pixelSize: Theme.fontSizeMedium
            color: win ? win.cTextMain : "#ffffff"
        }
    }

    // Empty State
    Column {
        anchors.centerIn: parent
        spacing: 12
        visible: win && !win.isScanning && win.gameList.length === 0

        DIcon {
            name: "sports_esports"
            size: 48
            color: win ? win.cTextSub : "#9ca3af"
            anchors.horizontalCenter: parent.horizontalCenter
        }
        StyledText {
            text: "No games found in this view"
            font.pixelSize: Theme.fontSizeMedium
            color: win ? win.cTextSub : "#9ca3af"
        }
    }

    // HARMONY MODERN GAME GRID VIEW
    GridView {
        id: gameGridView
        anchors.fill: parent
        anchors.leftMargin: gridRoot.gridSideMargin
        anchors.rightMargin: gridRoot.gridSideMargin
        anchors.topMargin: 12
        anchors.bottomMargin: 24
        cellWidth: gridRoot.cellWidth
        cellHeight: gridRoot.cellHeight
        clip: false
        visible: win && win.gameList.length > 0
        focus: true
        activeFocusOnTab: true

        model: win ? win.gameList : []

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 220; easing.type: Easing.OutQuad }
            NumberAnimation { property: "scale"; from: 0.92; to: 1.0; duration: 220; easing.type: Easing.OutQuad }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 180; easing.type: Easing.InQuad }
            NumberAnimation { property: "scale"; from: 1.0; to: 0.92; duration: 180; easing.type: Easing.InQuad }
        }
        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: 250; easing.type: Easing.OutCubic }
        }
        populate: Transition {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 250; easing.type: Easing.OutQuad }
            NumberAnimation { property: "scale"; from: 0.94; to: 1.0; duration: 250; easing.type: Easing.OutQuad }
        }

        // Keyboard arrow navigation
        Keys.onLeftPressed: (event) => {
            let total = (win && win.gameList) ? win.gameList.length : 0;
            if (total === 0) return;
            gridRoot.keyboardFocusIndex = Math.max(0, (gridRoot.keyboardFocusIndex <= 0 ? 0 : gridRoot.keyboardFocusIndex - 1));
            gameGridView.currentIndex = gridRoot.keyboardFocusIndex;
            gameGridView.positionViewAtIndex(gridRoot.keyboardFocusIndex, GridView.Contain);
            event.accepted = true;
        }
        Keys.onRightPressed: (event) => {
            let total = (win && win.gameList) ? win.gameList.length : 0;
            if (total === 0) return;
            gridRoot.keyboardFocusIndex = Math.min(total - 1, (gridRoot.keyboardFocusIndex < 0 ? 0 : gridRoot.keyboardFocusIndex + 1));
            gameGridView.currentIndex = gridRoot.keyboardFocusIndex;
            gameGridView.positionViewAtIndex(gridRoot.keyboardFocusIndex, GridView.Contain);
            event.accepted = true;
        }
        Keys.onUpPressed: (event) => {
            let total = (win && win.gameList) ? win.gameList.length : 0;
            if (total === 0) return;
            let cols = gridRoot.cardsPerRow;
            gridRoot.keyboardFocusIndex = Math.max(0, (gridRoot.keyboardFocusIndex < cols ? 0 : gridRoot.keyboardFocusIndex - cols));
            gameGridView.currentIndex = gridRoot.keyboardFocusIndex;
            gameGridView.positionViewAtIndex(gridRoot.keyboardFocusIndex, GridView.Contain);
            event.accepted = true;
        }
        Keys.onDownPressed: (event) => {
            let total = (win && win.gameList) ? win.gameList.length : 0;
            if (total === 0) return;
            let cols = gridRoot.cardsPerRow;
            gridRoot.keyboardFocusIndex = Math.min(total - 1, (gridRoot.keyboardFocusIndex < 0 ? 0 : gridRoot.keyboardFocusIndex + cols));
            gameGridView.currentIndex = gridRoot.keyboardFocusIndex;
            gameGridView.positionViewAtIndex(gridRoot.keyboardFocusIndex, GridView.Contain);
            event.accepted = true;
        }
        Keys.onReturnPressed: (event) => {
            let total = (win && win.gameList) ? win.gameList.length : 0;
            if (gridRoot.keyboardFocusIndex >= 0 && gridRoot.keyboardFocusIndex < total) {
                let g = win.gameList[gridRoot.keyboardFocusIndex];
                if (win) {
                    if (win.collapseHub) win.collapseHub();
                    if (win.tuckFilterBar) win.tuckFilterBar();
                    win.selectedGame = g;
                }
                event.accepted = true;
            }
        }
        Keys.onEnterPressed: (event) => {
            let total = (win && win.gameList) ? win.gameList.length : 0;
            if (gridRoot.keyboardFocusIndex >= 0 && gridRoot.keyboardFocusIndex < total) {
                let g = win.gameList[gridRoot.keyboardFocusIndex];
                if (win) {
                    if (win.collapseHub) win.collapseHub();
                    if (win.tuckFilterBar) win.tuckFilterBar();
                    win.selectedGame = g;
                }
                event.accepted = true;
            }
        }

        delegate: Item {
            id: delegateRoot
            width: gameGridView.cellWidth
            height: gameGridView.cellHeight
            z: isHovered ? 100 : 1

            readonly property var gData: modelData
            readonly property bool isSelectedByKey: gridRoot.keyboardFocusIndex === index
            readonly property bool isHovered: cardMouseArea.containsMouse || isSelectedByKey
            readonly property real cardRadius: gridRoot.cardCornerRadius
            readonly property bool hasTitle: gridRoot.showTitle

            // Fade animation for filter transitions (opacity driven by filterGames logic)
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

            // ── VIBRANT AMBIENT RADIANT GLOW SELECTOR (Hover or Key Navigation) ──
            // Layered luminous aura behind the card providing a tight, sleek neon glow selector
            Rectangle {
                id: cardGlow
                anchors.fill: gameCardBox
                anchors.margins: isHovered ? -5 : 0
                radius: cardRadius > 0 ? (cardRadius + (isHovered ? 5 : 0)) : 0
                opacity: isHovered ? (win && win.isLight ? 0.70 : 0.85) : 0.0
                z: 0

                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop {
                        position: 0.0
                        color: win && win.cAccent ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.50) : Qt.rgba(0.23, 0.51, 0.96, 0.50)
                    }
                    GradientStop {
                        position: 0.5
                        color: win && win.cAccent ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.70) : Qt.rgba(0.23, 0.51, 0.96, 0.70)
                    }
                    GradientStop {
                        position: 1.0
                        color: win && win.cAccent ? Qt.rgba(Math.min(1.0, win.cAccent.r * 1.2), Math.min(1.0, win.cAccent.g * 0.95), Math.min(1.0, win.cAccent.b * 1.3), 0.90) : Qt.rgba(0.40, 0.25, 0.95, 0.90)
                    }
                }

                Behavior on opacity { NumberAnimation { duration: 180 } }
                Behavior on anchors.margins { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            // Outer soft dispersion bloom halo for smooth radiant ambient illumination
            Rectangle {
                id: cardGlowOuter
                anchors.fill: gameCardBox
                anchors.margins: isHovered ? -10 : 0
                radius: cardRadius > 0 ? (cardRadius + (isHovered ? 10 : 0)) : 0
                opacity: isHovered ? (win && win.isLight ? 0.35 : 0.50) : 0.0
                z: -1

                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop {
                        position: 0.0
                        color: win && win.cAccent ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.12) : Qt.rgba(0.23, 0.51, 0.96, 0.12)
                    }
                    GradientStop {
                        position: 0.65
                        color: win && win.cAccent ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.30) : Qt.rgba(0.23, 0.51, 0.96, 0.30)
                    }
                    GradientStop {
                        position: 1.0
                        color: win && win.cAccent ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.55) : Qt.rgba(0.23, 0.51, 0.96, 0.55)
                    }
                }

                Behavior on opacity { NumberAnimation { duration: 200 } }
                Behavior on anchors.margins { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }

            // ── PLAYNITE HARMONY PREMIUM GAME CARD ───────────────────────
            Rectangle {
                id: gameCardBox
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.floor(gridRoot.cardGap / 2) + 8
                width: gridRoot.dynamicCardWidth
                height: gridRoot.dynamicCoverHeight + gridRoot.dynamicFooterHeight + 4
                // Smooth physical 3D lift on hover / key focus: shifts card upward by 6px
                y: isHovered ? -6 : 0
                Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                z: 2
                clip: false

                radius: cardRadius
                color: isHovered
                    ? (win ? win.cCardHover : "#282d3a")
                    : (win ? win.cCardBg : "#1b1e26")

                border.width: 0

                Behavior on color { ColorAnimation { duration: 150 } }

                // ── 1. COVER IMAGE AREA (Clipped cleanly via ClippingRectangle) ──
                // If title is shown: top corners rounded with cardRadius, bottom edge squared off to meet footer
                // If title is not shown: ALL corners rounded with cardRadius, cover fills full card
                // If cardRadius == 0: perfectly sharp 90-degree square edges
                ClippingRectangle {
                    id: coverClipArea
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: hasTitle ? footerArea.top : parent.bottom
                    anchors.bottomMargin: hasTitle ? 0 : 1

                    topLeftRadius: cardRadius
                    topRightRadius: cardRadius
                    bottomLeftRadius: hasTitle ? 0 : Math.max(0, cardRadius - 1)
                    bottomRightRadius: hasTitle ? 0 : Math.max(0, cardRadius - 1)
                    color: win && win.isLight ? "#e5e7eb" : "#13161c"

                    Image {
                        id: gameCover
                        anchors.fill: parent
                        source: {
                            if (!gData) return "";
                            let c = gData.coverUrl || gData.cover || "";
                            if (!c || c === "fallback") return "";
                            if (c.startsWith("/")) return encodeURI("file://" + c);
                            if (c.startsWith("file://")) return encodeURI(c);
                            return c;
                        }
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize.width: 400
                        sourceSize.height: 600
                        visible: status === Image.Ready
                    }

                    // Fallback poster when image fails or hasn't loaded
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: gameCover.status !== Image.Ready
                        DIcon {
                            name: "sports_esports"
                            size: 38
                            color: win ? win.cTextSub : "#9ca3af"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        StyledText {
                            text: gData ? gData.title : ""
                            font.pixelSize: Theme.fontSizeSmall - 2
                            color: win ? win.cTextSub : "#9ca3af"
                            width: 150
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }

                    // Subtle inner vignette / bottom gradient on cover to smoothly transition to footer (or bottom edge)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: hasTitle ? 48 : 32
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: win && win.isLight ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(0, 0, 0, 0.65) }
                        }
                    }

                    // Floating Platform Indicator (Top-Left)
                    // Sleek translucent badge without heavy pill borders
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 8
                        height: 22
                        radius: 6
                        width: launcherBadgeRow.implicitWidth + 12
                        color: Qt.rgba(12, 15, 20, 0.70)
                        border.width: 0

                        readonly property string pIconPath: (win && gData) ? win.getPlatformIcon(gData.launcher) : ""
                        readonly property bool hasSvg: pIconPath !== ""
                        readonly property bool showPlatformIcon: gameGridView.cellWidth >= 140

                        Row {
                            id: launcherBadgeRow
                            anchors.centerIn: parent
                            spacing: 5

                            Image {
                                source: parent.parent.showPlatformIcon && parent.parent.hasSvg ? parent.parent.pIconPath : ""
                                width: 14; height: 14
                                fillMode: Image.PreserveAspectFit
                                anchors.verticalCenter: parent.verticalCenter
                                visible: parent.parent.showPlatformIcon && parent.parent.hasSvg
                            }

                            DIcon {
                                name: (win && gData) ? win.getPlatformMaterialIcon(gData.launcher) : "extension"
                                size: 13
                                color: win ? win.cAccent : "#3b82f6"
                                anchors.verticalCenter: parent.verticalCenter
                                visible: parent.parent.showPlatformIcon && !parent.parent.hasSvg
                            }

                            StyledText {
                                id: launcherTxt
                                text: gData ? gData.launcher : ""
                                font.pixelSize: Theme.fontSizeSmall - 3
                                font.bold: true
                                color: "#FFFFFF"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Uninstalled Indicator (Top-Right)
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 8
                        width: 24; height: 22
                        radius: 6
                        color: Qt.rgba(12, 15, 20, 0.70)
                        border.width: 0
                        visible: gData && gData.uninstalled
                        DIcon {
                            name: "cloud_download"
                            size: 13
                            color: "#9ca3af"
                            anchors.centerIn: parent
                        }
                    }
                }

                // ── 2. CARD FOOTER: Glassmorphic Bottom Title Surface ──
                // Visible only when hasTitle is true. Bottom corners rounded with cardRadius.
                Rectangle {
                    id: footerArea
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 52
                    visible: hasTitle
                    radius: cardRadius
                    color: isHovered
                        ? (win ? win.cCardHover : "#282d3a")
                        : (win ? win.cCardBg : "#1b1e26")
                    clip: true

                    // Square off top edge of footer so only bottom corners stay rounded
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: cardRadius
                        color: footerArea.color
                        visible: cardRadius > 0
                    }

                    // Separator line removed per user request

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        anchors.topMargin: 10
                        spacing: 2

                        StyledText {
                            text: gData ? gData.title : ""
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            color: win ? win.cTextMain : "#ffffff"
                            width: parent.width
                            elide: Text.ElideRight
                        }
                    }
                }

                // Subtle Resting Border Outline (z: 10)
                // Resting card border only; on hover/selection the glowing radiant aura serves as the selector
                Rectangle {
                    anchors.fill: parent
                    radius: cardRadius
                    color: "transparent"
                    z: 10
                    border.width: 1
                    border.color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.08)
                }

                // Card Click & Right Click Handler
                MouseArea {
                    id: cardMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            let gPos = mapToItem(null, mouse.x, mouse.y);
                            gridRoot.openContextMenu(gData, gPos.x, gPos.y);
                        } else {
                            if (gridRoot.isContextMenuOpen) {
                                gridRoot.closeContextMenu();
                            }
                            if (win) {
                                if (win.collapseHub) win.collapseHub();
                                if (win.tuckFilterBar) win.tuckFilterBar();
                                win.selectedGame = gData;
                            }
                        }
                    }
                }
            }
        }
    }

    // ── RIGHT-CLICK CONTEXT MENU POPUP ──────────────────────────────
    Item {
        id: contextMenuOverlay
        anchors.fill: parent
        z: 300
        visible: false

        // Outside click dismiss
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: gridRoot.closeContextMenu()
        }

        Rectangle {
            id: contextMenuCard
            x: gridRoot.contextMenuX
            y: gridRoot.contextMenuY
            width: 200
            height: menuCol.implicitHeight + 12
            radius: 12
            color: win && win.isLight ? Qt.rgba(0.97, 0.98, 1.0, 0.96) : Qt.rgba(0.10, 0.12, 0.17, 0.96)
            border.width: 1
            border.color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(255, 255, 255, 0.16)

            // Inner Shadow / Elevation outline
            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                radius: 13
                color: "transparent"
                border.width: 1
                border.color: win ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.3) : "transparent"
                z: -1
            }

            ColumnLayout {
                id: menuCol
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4

                // Option: Edit Metadata
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 8
                    color: editMetaMA.containsMouse
                        ? (win ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.18) : Qt.rgba(0.23, 0.51, 0.96, 0.18))
                        : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        DIcon {
                            name: "edit_note"
                            size: 18
                            color: editMetaMA.containsMouse ? (win ? win.cAccent : "#3b82f6") : (win ? win.cTextMain : "#ffffff")
                        }

                        StyledText {
                            text: "Edit Metadata"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: win ? win.cTextMain : "#ffffff"
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: editMetaMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let targetGame = gridRoot.contextGame;
                            gridRoot.closeContextMenu();
                            if (win && win.openMetadataEditor && targetGame) {
                                win.openMetadataEditor(targetGame);
                            }
                        }
                    }
                }

                // Option: Open Game Details
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 8
                    color: viewDetailsMA.containsMouse
                        ? (win && win.isLight ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(255, 255, 255, 0.08))
                        : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        DIcon {
                            name: "info"
                            size: 18
                            color: win ? win.cTextSub : "#9ca3af"
                        }

                        StyledText {
                            text: "Game Details"
                            font.pixelSize: Theme.fontSizeSmall
                            color: win ? win.cTextMain : "#ffffff"
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: viewDetailsMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let targetGame = gridRoot.contextGame;
                            gridRoot.closeContextMenu();
                            if (win && targetGame) {
                                if (win.collapseHub) win.collapseHub();
                                if (win.tuckFilterBar) win.tuckFilterBar();
                                win.selectedGame = targetGame;
                            }
                        }
                    }
                }
            }
        }
    }
}
