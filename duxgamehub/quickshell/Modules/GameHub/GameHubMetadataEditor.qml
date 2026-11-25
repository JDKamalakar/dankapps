import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets
import qs.Services

Rectangle {
    id: editorOverlay
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.75)
    z: 350
    visible: false

    property var win: null
    property var gameData: null
    property string originalTitle: gameData ? (gameData.title || "") : ""

    // Editable properties
    property string editTitle: ""
    property string editDesc: ""
    property string editGenres: ""
    property string editReleaseDate: ""
    property string editDeveloper: ""
    property string editPublisher: ""
    property string editMetascore: ""
    property string editCoverUrl: ""
    property string editBackgroundUrl: ""

    // Online Search State
    property string searchQuery: ""
    property bool isSearching: false
    property var searchResults: []
    property var selectedSearchResult: null

    // Media Filter State: by default only show media >= required size
    // Cover requirement: >= 300x400 (or 600x900)
    // Background requirement: >= 1280x720 (or 1920x1080)
    property bool onlyHighResMedia: true

    function openForGame(g) {
        if (!g) return;
        gameData = g;
        originalTitle = g.title || "";
        editTitle = g.title || "";
        editDesc = g.description || "";
        editGenres = Array.isArray(g.genres) ? g.genres.join(", ") : (g.genres || "");
        editReleaseDate = g.releaseDate || "";
        editDeveloper = g.developer || "";
        editPublisher = g.publisher || "";
        editMetascore = (g.metascore !== undefined && g.metascore !== null) ? g.metascore.toString() : "";
        editCoverUrl = g.coverUrl || g.cover || "";
        editBackgroundUrl = g.backgroundUrl || "";

        searchQuery = editTitle;
        searchResults = [];
        selectedSearchResult = null;
        visible = true;
    }

    function close() {
        visible = false;
        if (searchProcess.running) searchProcess.running = false;
        if (saveProcess.running) saveProcess.running = false;
    }

    function executeSearch() {
        let q = searchQuery.trim();
        if (!q) return;
        isSearching = true;
        searchResults = [];
        selectedSearchResult = null;
        searchProcess.command = [
            "python3",
            (win && win.widgetRoot ? win.widgetRoot._pluginDir : "/home/Hatim/Downloads/JK/DMS-Fullscreen_Game_Hub") + "/Extension/metadata_search.py",
            "search",
            q
        ];
        searchProcess.running = true;
    }

    function applySearchResult(item) {
        if (!item) return;
        selectedSearchResult = item;
        editTitle = item.title || editTitle;
        if (item.description) editDesc = item.description;
        if (item.genres && item.genres.length > 0) editGenres = item.genres.join(", ");
        if (item.releaseDate) editReleaseDate = item.releaseDate;
        if (item.developer) editDeveloper = item.developer;
        if (item.publisher) editPublisher = item.publisher;
        if (item.metascore !== null && item.metascore !== undefined) editMetascore = item.metascore.toString();
        if (item.coverUrl) editCoverUrl = item.coverUrl;
        if (item.backgroundUrl) editBackgroundUrl = item.backgroundUrl;
    }

    function savePermanent() {
        let payload = {
            title: editTitle.trim(),
            description: editDesc.trim(),
            genres: editGenres.split(",").map(s => s.trim()).filter(s => s.length > 0),
            releaseDate: editReleaseDate.trim(),
            developer: editDeveloper.trim(),
            publisher: editPublisher.trim(),
            metascore: editMetascore.trim() ? parseInt(editMetascore) : null,
            coverUrl: editCoverUrl.trim(),
            backgroundUrl: editBackgroundUrl.trim(),
            source: selectedSearchResult ? (selectedSearchResult.source || "Manual Editor") : "Manual Editor"
        };

        if (selectedSearchResult) {
            if (selectedSearchResult.screenshots) payload.screenshots = selectedSearchResult.screenshots;
            if (selectedSearchResult.trailers) payload.trailers = selectedSearchResult.trailers;
        }

        let pDir = win && win.widgetRoot ? win.widgetRoot._pluginDir : "/home/Hatim/Downloads/JK/DMS-Fullscreen_Game_Hub";
        let gFile = win && win.widgetRoot ? win.widgetRoot._tmpGamesFile : "/tmp/dms_gamehub_games.json";

        saveProcess.command = [
            "python3",
            pDir + "/Extension/metadata_search.py",
            "save",
            originalTitle,
            JSON.stringify(payload),
            pDir,
            gFile
        ];
        saveProcess.running = true;
    }

    Process {
        id: searchProcess
        stdout: SplitParser {
            splitMarker: ""
            onRead: function(data) {
                editorOverlay.isSearching = false;
                try {
                    let parsed = JSON.parse(data.trim());
                    if (Array.isArray(parsed)) {
                        editorOverlay.searchResults = parsed;
                    }
                } catch(e) {
                    console.log("Error parsing search results:", e);
                }
            }
        }
        onExited: editorOverlay.isSearching = false
    }

    Process {
        id: saveProcess
        stdout: SplitParser {
            splitMarker: ""
            onRead: function(data) {
                try {
                    let res = JSON.parse(data.trim());
                    if (res && res.status === "SUCCESS") {
                        if (win && win.widgetRoot) {
                            win.widgetRoot.reloadGamesFromFile();
                        }
                        editorOverlay.close();
                    }
                } catch(e) {
                    console.log("Error saving metadata:", e);
                }
            }
        }
    }

    // Modal Background Click Dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: editorOverlay.close()
    }

    // Main Dialog Container
    Rectangle {
        id: dialogCard
        width: Math.min(1120, parent.width - 48)
        height: Math.min(720, parent.height - 48)
        anchors.centerIn: parent
        radius: 20
        color: win && win.isLight ? Qt.rgba(0.97, 0.98, 1.0, 0.96) : Qt.rgba(0.09, 0.11, 0.15, 0.96)
        border.width: 1
        border.color: win && win.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(255, 255, 255, 0.14)
        clip: true

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            // ── HEADER TOOLBAR ──────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 38; height: 38; radius: 19
                    color: Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.2)
                    Layout.alignment: Qt.AlignVCenter
                    DIcon {
                        name: "edit_note"
                        size: 22
                        color: win.cAccent
                        anchors.centerIn: parent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    StyledText {
                        text: "Metadata Editor & Media Fetcher"
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                        color: win.cTextMain
                    }
                    StyledText {
                        text: "Permanently modify game fields, search Steam/Wikipedia/PSN, and select high-res artwork"
                        font.pixelSize: Theme.fontSizeSmall - 2
                        color: win.cTextSub
                    }
                }

                // High-Res Media Toggle Filter
                Rectangle {
                    height: 32
                    radius: 16
                    width: toggleRow.implicitWidth + 20
                    color: editorOverlay.onlyHighResMedia
                        ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.2)
                        : (win.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(255, 255, 255, 0.06))
                    border.width: 1
                    border.color: editorOverlay.onlyHighResMedia ? win.cAccent : "transparent"

                    RowLayout {
                        id: toggleRow
                        anchors.centerIn: parent
                        spacing: 6
                        DIcon {
                            name: editorOverlay.onlyHighResMedia ? "high_quality" : "tune"
                            size: 15
                            color: editorOverlay.onlyHighResMedia ? win.cAccent : win.cTextSub
                        }
                        StyledText {
                            text: editorOverlay.onlyHighResMedia ? "Min High-Res (>=1080p/600p)" : "Show All Resolutions"
                            font.pixelSize: Theme.fontSizeSmall - 2
                            font.bold: editorOverlay.onlyHighResMedia
                            color: editorOverlay.onlyHighResMedia ? win.cAccent : win.cTextSub
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: editorOverlay.onlyHighResMedia = !editorOverlay.onlyHighResMedia
                    }
                }

                // Close Button
                Rectangle {
                    width: 32; height: 32; radius: 16
                    color: closeMA.containsMouse ? (win.isLight ? Qt.rgba(0,0,0,0.08) : Qt.rgba(255,255,255,0.12)) : "transparent"
                    DIcon {
                        name: "close"
                        size: 18
                        color: closeMA.containsMouse ? win.cAccent : win.cTextSub
                        anchors.centerIn: parent
                    }
                    MouseArea {
                        id: closeMA
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: editorOverlay.close()
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.08)
            }

            // ── BODY: TWO-PANEL SPLIT (Left: Manual Fields, Right: Online Search & Media Picker) ──
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16

                // ── LEFT PANEL: METADATA FORM ───────────────────────────
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 380
                    radius: 14
                    color: win.isLight ? Qt.rgba(0, 0, 0, 0.02) : Qt.rgba(255, 255, 255, 0.03)
                    border.width: 1
                    border.color: win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.06)
                    clip: true

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 12
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        ColumnLayout {
                            width: parent.width - 12
                            spacing: 10

                            StyledText {
                                text: "EDIT METADATA FIELDS"
                                font.pixelSize: Theme.fontSizeSmall - 3
                                font.bold: true
                                color: win.cAccent
                                font.letterSpacing: 0.8
                            }

                            // Title Field
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Title / Game Name"; font.pixelSize: Theme.fontSizeSmall - 2; color: win.cTextSub }
                                TextField {
                                    id: fldTitle
                                    Layout.fillWidth: true
                                    text: editorOverlay.editTitle
                                    color: win.cTextMain
                                    font.pixelSize: Theme.fontSizeSmall
                                    background: Rectangle {
                                        radius: 8
                                        color: win.isLight ? "#ffffff" : "#1a1d24"
                                        border.color: fldTitle.activeFocus ? win.cAccent : Qt.rgba(win.cTextSub.r, win.cTextSub.g, win.cTextSub.b, 0.25)
                                    }
                                    onTextChanged: editorOverlay.editTitle = text
                                }
                            }

                            // Developer & Publisher
                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    StyledText { text: "Developer"; font.pixelSize: Theme.fontSizeSmall - 2; color: win.cTextSub }
                                    TextField {
                                        id: fldDev; Layout.fillWidth: true; text: editorOverlay.editDeveloper
                                        color: win.cTextMain; font.pixelSize: Theme.fontSizeSmall
                                        background: Rectangle { radius: 8; color: win.isLight ? "#ffffff" : "#1a1d24"; border.color: fldDev.activeFocus ? win.cAccent : Qt.rgba(win.cTextSub.r, win.cTextSub.g, win.cTextSub.b, 0.25) }
                                        onTextChanged: editorOverlay.editDeveloper = text
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    StyledText { text: "Publisher"; font.pixelSize: Theme.fontSizeSmall - 2; color: win.cTextSub }
                                    TextField {
                                        id: fldPub; Layout.fillWidth: true; text: editorOverlay.editPublisher
                                        color: win.cTextMain; font.pixelSize: Theme.fontSizeSmall
                                        background: Rectangle { radius: 8; color: win.isLight ? "#ffffff" : "#1a1d24"; border.color: fldPub.activeFocus ? win.cAccent : Qt.rgba(win.cTextSub.r, win.cTextSub.g, win.cTextSub.b, 0.25) }
                                        onTextChanged: editorOverlay.editPublisher = text
                                    }
                                }
                            }

                            // Release Date & Metascore
                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    StyledText { text: "Release Date"; font.pixelSize: Theme.fontSizeSmall - 2; color: win.cTextSub }
                                    TextField {
                                        id: fldDate; Layout.fillWidth: true; text: editorOverlay.editReleaseDate
                                        color: win.cTextMain; font.pixelSize: Theme.fontSizeSmall
                                        background: Rectangle { radius: 8; color: win.isLight ? "#ffffff" : "#1a1d24"; border.color: fldDate.activeFocus ? win.cAccent : Qt.rgba(win.cTextSub.r, win.cTextSub.g, win.cTextSub.b, 0.25) }
                                        onTextChanged: editorOverlay.editReleaseDate = text
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    StyledText { text: "Metascore"; font.pixelSize: Theme.fontSizeSmall - 2; color: win.cTextSub }
                                    TextField {
                                        id: fldScore; Layout.fillWidth: true; text: editorOverlay.editMetascore
                                        color: win.cTextMain; font.pixelSize: Theme.fontSizeSmall
                                        background: Rectangle { radius: 8; color: win.isLight ? "#ffffff" : "#1a1d24"; border.color: fldScore.activeFocus ? win.cAccent : Qt.rgba(win.cTextSub.r, win.cTextSub.g, win.cTextSub.b, 0.25) }
                                        onTextChanged: editorOverlay.editMetascore = text
                                    }
                                }
                            }

                            // Genres
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Genres (comma-separated)"; font.pixelSize: Theme.fontSizeSmall - 2; color: win.cTextSub }
                                TextField {
                                    id: fldGenres; Layout.fillWidth: true; text: editorOverlay.editGenres
                                    color: win.cTextMain; font.pixelSize: Theme.fontSizeSmall
                                    background: Rectangle { radius: 8; color: win.isLight ? "#ffffff" : "#1a1d24"; border.color: fldGenres.activeFocus ? win.cAccent : Qt.rgba(win.cTextSub.r, win.cTextSub.g, win.cTextSub.b, 0.25) }
                                    onTextChanged: editorOverlay.editGenres = text
                                }
                            }

                            // Description
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Description"; font.pixelSize: Theme.fontSizeSmall - 2; color: win.cTextSub }
                                TextArea {
                                    id: fldDesc
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 80
                                    text: editorOverlay.editDesc
                                    color: win.cTextMain
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    wrapMode: Text.Wrap
                                    background: Rectangle {
                                        radius: 8
                                        color: win.isLight ? "#ffffff" : "#1a1d24"
                                        border.color: fldDesc.activeFocus ? win.cAccent : Qt.rgba(win.cTextSub.r, win.cTextSub.g, win.cTextSub.b, 0.25)
                                    }
                                    onTextChanged: editorOverlay.editDesc = text
                                }
                            }

                            // Cover Image URL
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Cover Image URL / Path"; font.pixelSize: Theme.fontSizeSmall - 2; color: win.cTextSub }
                                TextField {
                                    id: fldCover; Layout.fillWidth: true; text: editorOverlay.editCoverUrl
                                    color: win.cTextMain; font.pixelSize: Theme.fontSizeSmall - 2
                                    background: Rectangle { radius: 8; color: win.isLight ? "#ffffff" : "#1a1d24"; border.color: fldCover.activeFocus ? win.cAccent : Qt.rgba(win.cTextSub.r, win.cTextSub.g, win.cTextSub.b, 0.25) }
                                    onTextChanged: editorOverlay.editCoverUrl = text
                                }
                            }

                            // Background Image URL
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Hero Background URL / Path"; font.pixelSize: Theme.fontSizeSmall - 2; color: win.cTextSub }
                                TextField {
                                    id: fldBg; Layout.fillWidth: true; text: editorOverlay.editBackgroundUrl
                                    color: win.cTextMain; font.pixelSize: Theme.fontSizeSmall - 2
                                    background: Rectangle { radius: 8; color: win.isLight ? "#ffffff" : "#1a1d24"; border.color: fldBg.activeFocus ? win.cAccent : Qt.rgba(win.cTextSub.r, win.cTextSub.g, win.cTextSub.b, 0.25) }
                                    onTextChanged: editorOverlay.editBackgroundUrl = text
                                }
                            }
                        }
                    }
                }

                // ── RIGHT PANEL: ONLINE SOURCES SEARCH & MEDIA RESOLUTION SELECTOR ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    color: win.isLight ? Qt.rgba(0, 0, 0, 0.02) : Qt.rgba(255, 255, 255, 0.03)
                    border.width: 1
                    border.color: win.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.06)
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        // Search Bar Row (allows user to search with custom alias or alternative game name)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                height: 38
                                radius: 10
                                color: win.isLight ? "#ffffff" : "#161920"
                                border.width: 1
                                border.color: searchInputFld.activeFocus ? win.cAccent : Qt.rgba(win.cTextSub.r, win.cTextSub.g, win.cTextSub.b, 0.2)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    DIcon {
                                        name: "search"
                                        size: 16
                                        color: win.cAccent
                                    }

                                    TextField {
                                        id: searchInputFld
                                        Layout.fillWidth: true
                                        text: editorOverlay.searchQuery
                                        placeholderText: "Search Steam, PSN, IGDB, Wikipedia with any game name..."
                                        color: win.cTextMain
                                        font.pixelSize: Theme.fontSizeSmall
                                        background: null
                                        onTextChanged: editorOverlay.searchQuery = text
                                        onAccepted: editorOverlay.executeSearch()
                                    }

                                    DIcon {
                                        name: "close"
                                        size: 14
                                        color: win.cTextSub
                                        visible: searchInputFld.text.length > 0
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { searchInputFld.text = ""; editorOverlay.searchQuery = ""; }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 96; height: 38; radius: 10
                                color: searchBtnMA.containsMouse ? Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.3) : Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.18)
                                border.width: 1
                                border.color: win.cAccent

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    DIcon {
                                        name: editorOverlay.isSearching ? "refresh" : "travel_explore"
                                        size: 16
                                        color: win.cAccent
                                        RotationAnimation on rotation {
                                            from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: editorOverlay.isSearching
                                        }
                                    }
                                    StyledText {
                                        text: editorOverlay.isSearching ? "Searching..." : "Search"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.bold: true
                                        color: win.cAccent
                                    }
                                }

                                MouseArea {
                                    id: searchBtnMA
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: editorOverlay.executeSearch()
                                }
                            }
                        }

                        // Search Results List
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            // Loading
                            Column {
                                anchors.centerIn: parent
                                spacing: 8
                                visible: editorOverlay.isSearching
                                DIcon { name: "travel_explore"; size: 36; color: win.cAccent; anchors.horizontalCenter: parent.horizontalCenter }
                                StyledText { text: "Searching online metadata providers..."; font.pixelSize: Theme.fontSizeSmall; color: win.cTextSub }
                            }

                            // Empty / Initial prompt
                            Column {
                                anchors.centerIn: parent
                                spacing: 8
                                visible: !editorOverlay.isSearching && editorOverlay.searchResults.length === 0
                                DIcon { name: "dataset"; size: 40; color: win.cTextSub; anchors.horizontalCenter: parent.horizontalCenter }
                                StyledText {
                                    text: "Type a title above and click Search to find matching metadata"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: win.cTextSub
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            // Results list
                            ListView {
                                id: resultsList
                                anchors.fill: parent
                                visible: !editorOverlay.isSearching && editorOverlay.searchResults.length > 0
                                spacing: 10
                                clip: true
                                model: editorOverlay.searchResults

                                delegate: Rectangle {
                                    width: resultsList.width
                                    height: resCol.implicitHeight + 20
                                    radius: 12
                                    color: resMA.containsMouse ? (win.isLight ? "#ffffff" : "#222733") : (win.isLight ? Qt.rgba(1,1,1,0.6) : "#191c24")
                                    border.width: editorOverlay.selectedSearchResult === modelData ? 2 : 1
                                    border.color: editorOverlay.selectedSearchResult === modelData ? win.cAccent : (win.isLight ? Qt.rgba(0,0,0,0.08) : Qt.rgba(255,255,255,0.08))

                                    ColumnLayout {
                                        id: resCol
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 8

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            // Thumbnail
                                            Rectangle {
                                                width: 44; height: 60; radius: 6; clip: true; color: "#000"
                                                Image {
                                                    anchors.fill: parent
                                                    source: modelData.coverUrl || ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    visible: status === Image.Ready
                                                }
                                                DIcon {
                                                    name: "sports_esports"
                                                    size: 20
                                                    color: win.cTextSub
                                                    anchors.centerIn: parent
                                                    visible: !parent.children[0].visible
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    StyledText {
                                                        text: modelData.title || ""
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        font.bold: true
                                                        color: win.cTextMain
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideRight
                                                    }
                                                    Rectangle {
                                                        height: 20; radius: 4; width: srcTxt.implicitWidth + 10
                                                        color: Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.18)
                                                        StyledText {
                                                            id: srcTxt
                                                            text: modelData.source || "Steam"
                                                            font.pixelSize: 10
                                                            font.bold: true
                                                            color: win.cAccent
                                                            anchors.centerIn: parent
                                                        }
                                                    }
                                                }

                                                StyledText {
                                                    text: (modelData.releaseDate ? ("Released: " + modelData.releaseDate + " • ") : "") + (modelData.developer || modelData.publisher || "")
                                                    font.pixelSize: Theme.fontSizeSmall - 3
                                                    color: win.cTextSub
                                                    elide: Text.ElideRight
                                                }

                                                StyledText {
                                                    text: modelData.description || ""
                                                    font.pixelSize: Theme.fontSizeSmall - 3
                                                    color: win.cTextSub
                                                    maximumLineCount: 2
                                                    wrapMode: Text.Wrap
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }

                                            Rectangle {
                                                width: 78; height: 32; radius: 8
                                                color: applyBtnMA.containsMouse ? win.cAccent : Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.2)
                                                border.width: 1
                                                border.color: win.cAccent

                                                StyledText {
                                                    text: "Apply"
                                                    font.pixelSize: Theme.fontSizeSmall - 1
                                                    font.bold: true
                                                    color: applyBtnMA.containsMouse ? "#ffffff" : win.cAccent
                                                    anchors.centerIn: parent
                                                }

                                                MouseArea {
                                                    id: applyBtnMA
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: editorOverlay.applySearchResult(modelData)
                                                }
                                            }
                                        }

                                        // Available Artwork / Media Picker for this match
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 4
                                            visible: (modelData.covers && modelData.covers.length > 0) || (modelData.backgrounds && modelData.backgrounds.length > 0)

                                            StyledText {
                                                text: "SELECT ARTWORK & RESOLUTION:"
                                                font.pixelSize: 9
                                                font.bold: true
                                                color: win.cAccent
                                            }

                                            // Horizontal Media Strips (filtered by high resolution toggle)
                                            Row {
                                                spacing: 8
                                                Repeater {
                                                    model: {
                                                        let list = (modelData.covers || []).concat(modelData.backgrounds || []);
                                                        if (editorOverlay.onlyHighResMedia) {
                                                            return list.filter(m => m.isHighRes === true || (m.width >= 600 && m.height >= 400));
                                                        }
                                                        return list;
                                                    }

                                                    delegate: Rectangle {
                                                        width: 72; height: 50; radius: 6
                                                        clip: true
                                                        border.width: (editorOverlay.editCoverUrl === modelData.url || editorOverlay.editBackgroundUrl === modelData.url) ? 2 : 1
                                                        border.color: (editorOverlay.editCoverUrl === modelData.url || editorOverlay.editBackgroundUrl === modelData.url) ? win.cAccent : Qt.rgba(255,255,255,0.15)
                                                        color: "#000000"

                                                        Image {
                                                            anchors.fill: parent
                                                            source: modelData.url
                                                            fillMode: Image.PreserveAspectCrop
                                                        }

                                                        Rectangle {
                                                            anchors.bottom: parent.bottom
                                                            anchors.left: parent.left
                                                            anchors.right: parent.right
                                                            height: 14
                                                            color: Qt.rgba(0,0,0,0.75)
                                                            StyledText {
                                                                text: modelData.width + "x" + modelData.height
                                                                font.pixelSize: 8
                                                                color: modelData.isHighRes ? "#4ade80" : "#fbbf24"
                                                                anchors.centerIn: parent
                                                            }
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                if (modelData.width < modelData.height) {
                                                                    editorOverlay.editCoverUrl = modelData.url;
                                                                } else {
                                                                    editorOverlay.editBackgroundUrl = modelData.url;
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: resMA
                                        anchors.fill: parent
                                        z: -1
                                        onClicked: editorOverlay.applySearchResult(modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── FOOTER ACTIONS ──────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                StyledText {
                    Layout.fillWidth: true
                    text: "Changes are permanently written to Extension Data/metadata.json and applied to the library cache."
                    font.pixelSize: Theme.fontSizeSmall - 3
                    color: win.cTextSub
                }

                Rectangle {
                    width: 100; height: 38; radius: 10
                    color: cancelBtnMA.containsMouse ? (win.isLight ? Qt.rgba(0,0,0,0.08) : Qt.rgba(255,255,255,0.12)) : "transparent"
                    border.width: 1
                    border.color: win.isLight ? Qt.rgba(0,0,0,0.15) : Qt.rgba(255,255,255,0.15)

                    StyledText {
                        text: "Cancel"
                        font.pixelSize: Theme.fontSizeSmall
                        color: win.cTextMain
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: cancelBtnMA
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: editorOverlay.close()
                    }
                }

                Rectangle {
                    width: 150; height: 38; radius: 10
                    color: saveBtnMA.containsMouse ? win.cAccent : Qt.rgba(win.cAccent.r, win.cAccent.g, win.cAccent.b, 0.85)

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        DIcon {
                            name: saveProcess.running ? "refresh" : "save"
                            size: 16
                            color: "#ffffff"
                            RotationAnimation on rotation {
                                from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: saveProcess.running
                            }
                        }
                        StyledText {
                            text: saveProcess.running ? "Saving..." : "Save Metadata"
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            color: "#ffffff"
                        }
                    }

                    MouseArea {
                        id: saveBtnMA
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: editorOverlay.savePermanent()
                    }
                }
            }
        }
    }
}
