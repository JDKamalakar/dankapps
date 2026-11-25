import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Services
import QtQuick.Controls

PluginComponent {
    id: root

    popoutWidth: 480
    popoutHeight: 600


    // --- Standalone Fullscreen Window (Loaded on-demand to guarantee strictly 1 instance) ---
    Loader {
        id: windowLoader
        active: false
        sourceComponent: Component {
            GameHubWindow {
                id: ghWin
                widgetRoot: root
                onVisibleChanged: {
                    if (!visible && typeof PluginService !== "undefined" && PluginService.setGlobalVar) {
                        PluginService.setGlobalVar("fullscreenGameHub", "windowOpenState", false);
                    }
                }
            }
        }
    }
    readonly property var gameHubWindow: windowLoader.item

    IpcHandler {
        target: "fullscreenGameHub"

        function open(): string {
            root.openFullscreenApp();
            return "GAME_HUB_OPEN_SUCCESS";
        }

        function close(): string {
            if (windowLoader.active && windowLoader.item) {
                windowLoader.item.visible = false;
            }
            windowLoader.active = false;
            return "GAME_HUB_CLOSE_SUCCESS";
        }

        function toggle(): string {
            if (windowLoader.active && windowLoader.item && windowLoader.item.visible) {
                return close();
            } else {
                return open();
            }
        }

        function rescan(): string {
            root.scanAllGames();
            return "GAME_HUB_RESCAN_SUCCESS";
        }

        function openSettings(): string {
            root.openFullscreenApp();
            if (gameHubWindow) {
                gameHubWindow.showSettingsOverlay = true;
            }
            return "GAME_HUB_SETTINGS_OPEN_SUCCESS";
        }

        function refreshMetadata(): string {
            console.log("GameHub IPC: refreshMetadata invoked");
            root.fetchMetadata(true);
            return "GAME_HUB_META_FETCH_STARTED";
        }
    }

    // --- Control Center Support ---
    ccWidgetIcon: "sports_esports"
    ccWidgetPrimaryText: "Game Hub"
    ccWidgetSecondaryText: root.isFetchingMeta
        ? ("Metadata " + root.metaProgressDone + "/" + root.metaProgressTotal + " — " + root.metaCurrentTitle)
        : (root.rawGamesList.length > 0 ? (root.rawGamesList.length + " Games Available") : "Scanning games...")
    ccWidgetIsActive: root.rawGamesList.length > 0
    ccDetailHeight: 520
    onCcWidgetExpanded: root.scanAllGames()
    onCcWidgetToggled: root.scanAllGames()

    ccDetailContent: Component {
        ScrollView {
            id: ccScrollView
            anchors.fill: parent
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            Loader {
                width: ccScrollView.availableWidth
                height: root.ccDetailHeight
                asynchronous: true
                sourceComponent: gameHubContent
                readonly property bool inCC: true
            }
        }
    }

    Component.onCompleted: {
        console.log("DMS Game Launcher & Hub Plugin Loaded");
        root.reloadGamesFromFile();
        root.scanAllGames();
    }

    // --- State Management ---
    property var rawGamesList: []
    property var gameList: []
    property bool isScanning: false
    property string activeLauncherFilter: "All"
    property string searchQuery: ""
    property string filterTag: "All"
    property string filterPublisher: "All"
    property string filterDeveloper: "All"
    property int filterMinMetascore: 0
    property var filterHealthTags: []
    property int filterMinYear: 0
    property int filterMaxYear: 0

    // Metadata fetch progress — shared across all phases
    property bool isFetchingMeta: false
    property string metaPhase: ""          // "metadata" | "covers" | "backgrounds" | "trailers"
    property int metaProgressDone: 0
    property int metaProgressTotal: 0
    property string metaCurrentTitle: ""
    readonly property real metaProgressFraction: metaProgressTotal > 0 ? (metaProgressDone / metaProgressTotal) : 0

    // Human-readable label for current phase
    readonly property string metaPhaseLabel: {
        switch (root.metaPhase) {
            case "metadata":    return "Fetching metadata";
            case "covers":      return "Downloading covers";
            case "backgrounds": return "Downloading backgrounds";
            case "media":       return "Downloading media";
            case "trailers":    return "Downloading trailers";
            default:            return "Fetching metadata";
        }
    }

    // Temp file for sharing scan results with the metadata process
    readonly property string _tmpGamesFile: "/tmp/dms_gamehub_games.json"

    // Calculated game counts
    readonly property int totalGamesCount: root.rawGamesList.length
    readonly property int installedGamesCount: {
        let count = 0;
        for (let i = 0; i < root.rawGamesList.length; i++) {
            if (!root.rawGamesList[i].uninstalled) count++;
        }
        return count;
    }

    PluginGlobalVar {
        varName: "windowOpenState"
        onValueChanged: (val) => {
            if (val === true || val === "true") {
                if (windowLoader.active && gameHubWindow) {
                    if (!gameHubWindow.visible) {
                        gameHubWindow.themeMode = PluginService.loadPluginData("fullscreenGameHub", "windowThemeMode", "dark");
                        gameHubWindow.visible = true;
                    }
                    if (typeof gameHubWindow.requestActivate === "function") {
                        gameHubWindow.requestActivate();
                    }
                }
            } else if (val === false || val === "false") {
                if (windowLoader.active && gameHubWindow && gameHubWindow.visible) {
                    gameHubWindow.visible = false;
                }
            }
        }
    }
    // Settings persistence listener bindings
    property bool _scanSteam: PluginService.loadPluginData("fullscreenGameHub", "scanSteam", true)
    property bool _scanLutris: PluginService.loadPluginData("fullscreenGameHub", "scanLutris", true)
    property bool _scanHeroic: PluginService.loadPluginData("fullscreenGameHub", "scanHeroic", true)
    property bool _scanBottles: PluginService.loadPluginData("fullscreenGameHub", "scanBottles", true)
    property bool _includeUninstalled: PluginService.loadPluginData("fullscreenGameHub", "includeUninstalled", true)
    property bool _hideLaunchers: PluginService.loadPluginData("fullscreenGameHub", "hideLaunchers", false)
    property bool _hideDuplicates: PluginService.loadPluginData("fullscreenGameHub", "hideDuplicates", false)
    property bool _hideDLC: PluginService.loadPluginData("fullscreenGameHub", "hideDLC", false)
    property bool _fetchDLC: PluginService.loadPluginData("fullscreenGameHub", "fetchDLC", false)
    property bool _hideEmptyCategories: PluginService.loadPluginData("fullscreenGameHub", "hideEmptyCategories", false)
    property bool _autoPlayTrailer: PluginService.loadPluginData("fullscreenGameHub", "autoPlayTrailer", false)
    property string _steamApiKey: PluginService.loadPluginData("fullscreenGameHub", "steamApiKey", "")
    property string _steamId: PluginService.loadPluginData("fullscreenGameHub", "steamId", "")
    property bool _showStatsInPill: PluginService.loadPluginData("fullscreenGameHub", "showStatsInPill", true)
    property string _pillCountMode: PluginService.loadPluginData("fullscreenGameHub", "pillCountMode", "total")
    property bool _autoCloseOnLaunch: PluginService.loadPluginData("fullscreenGameHub", "autoCloseOnLaunch", false)

    // Metadata provider settings
    property bool _metadataEnabled: PluginService.loadPluginData("fullscreenGameHub", "metadataEnabled", true)
    property bool _metadataAutoFetch: PluginService.loadPluginData("fullscreenGameHub", "metadataAutoFetch", true)
    property bool _metadataDownloadCovers: PluginService.loadPluginData("fullscreenGameHub", "metadataDownloadCovers", true)
    property bool _metadataDownloadBackgrounds: PluginService.loadPluginData("fullscreenGameHub", "metadataDownloadBackgrounds", true)
    property bool _metadataDownloadMedia: PluginService.loadPluginData("fullscreenGameHub", "metadataDownloadMedia", true)
    property bool _metadataDownloadTrailers: PluginService.loadPluginData("fullscreenGameHub", "metadataDownloadTrailers", true)
    property string _rawgKey: PluginService.loadPluginData("fullscreenGameHub", "rawgKey", "")
    property bool _fetchTriggeredManually: false

    function reloadSettings() {
        _scanSteam = PluginService.loadPluginData("fullscreenGameHub", "scanSteam", true);
        _scanLutris = PluginService.loadPluginData("fullscreenGameHub", "scanLutris", true);
        _scanHeroic = PluginService.loadPluginData("fullscreenGameHub", "scanHeroic", true);
        _scanBottles = PluginService.loadPluginData("fullscreenGameHub", "scanBottles", true);
        _includeUninstalled = PluginService.loadPluginData("fullscreenGameHub", "includeUninstalled", true);
        _hideLaunchers = PluginService.loadPluginData("fullscreenGameHub", "hideLaunchers", false);
        _steamApiKey = PluginService.loadPluginData("fullscreenGameHub", "steamApiKey", "");
        _steamId = PluginService.loadPluginData("fullscreenGameHub", "steamId", "");
        _showStatsInPill = PluginService.loadPluginData("fullscreenGameHub", "showStatsInPill", true);
        _pillCountMode = PluginService.loadPluginData("fullscreenGameHub", "pillCountMode", "total");
        _autoCloseOnLaunch = PluginService.loadPluginData("fullscreenGameHub", "autoCloseOnLaunch", false);
        _metadataEnabled = PluginService.loadPluginData("fullscreenGameHub", "metadataEnabled", true);
        _metadataAutoFetch = PluginService.loadPluginData("fullscreenGameHub", "metadataAutoFetch", true);
        _metadataDownloadCovers = PluginService.loadPluginData("fullscreenGameHub", "metadataDownloadCovers", true);
        _metadataDownloadBackgrounds = PluginService.loadPluginData("fullscreenGameHub", "metadataDownloadBackgrounds", true);
        _metadataDownloadMedia = PluginService.loadPluginData("fullscreenGameHub", "metadataDownloadMedia", true);
        _metadataDownloadTrailers = PluginService.loadPluginData("fullscreenGameHub", "metadataDownloadTrailers", true);
        _rawgKey = PluginService.loadPluginData("fullscreenGameHub", "rawgKey", "");
        filterGames();
    }

    PluginGlobalVar { varName: "scanSteam"; onValueChanged: (val) => { root._scanSteam = val; root.scanAllGames() } }
    PluginGlobalVar { varName: "scanLutris"; onValueChanged: (val) => { root._scanLutris = val; root.scanAllGames() } }
    PluginGlobalVar { varName: "scanHeroic"; onValueChanged: (val) => { root._scanHeroic = val; root.scanAllGames() } }
    PluginGlobalVar { varName: "scanBottles"; onValueChanged: (val) => { root._scanBottles = val; root.scanAllGames() } }
    PluginGlobalVar { varName: "includeUninstalled"; onValueChanged: (val) => { root._includeUninstalled = val; root.filterGames() } }
    PluginGlobalVar { varName: "hideLaunchers"; onValueChanged: (val) => { root._hideLaunchers = val; root.filterGames() } }
    PluginGlobalVar { varName: "hideDuplicates"; onValueChanged: (val) => { root._hideDuplicates = val; root.filterGames() } }
    PluginGlobalVar { varName: "hideDLC"; onValueChanged: (val) => { root._hideDLC = val; root.filterGames() } }
    PluginGlobalVar { varName: "fetchDLC"; onValueChanged: (val) => { root._fetchDLC = val; root.scanAllGames() } }
    PluginGlobalVar { varName: "hideEmptyCategories"; onValueChanged: (val) => { root._hideEmptyCategories = val; root.filterGames() } }
    PluginGlobalVar { varName: "autoPlayTrailer"; onValueChanged: (val) => { root._autoPlayTrailer = val } }
    PluginGlobalVar { varName: "steamApiKey"; onValueChanged: (val) => { root._steamApiKey = val; root.scanAllGames() } }
    PluginGlobalVar { varName: "steamId"; onValueChanged: (val) => { root._steamId = val; root.scanAllGames() } }
    PluginGlobalVar { varName: "showStatsInPill"; onValueChanged: (val) => { root._showStatsInPill = val } }
    PluginGlobalVar { varName: "pillCountMode"; onValueChanged: (val) => { root._pillCountMode = val } }
    PluginGlobalVar { varName: "autoCloseOnLaunch"; onValueChanged: (val) => { root._autoCloseOnLaunch = val } }
    PluginGlobalVar { varName: "windowThemeMode"; onValueChanged: (val) => { if (gameHubWindow) gameHubWindow.themeMode = val } }
    PluginGlobalVar { varName: "metadataEnabled"; onValueChanged: (val) => { root._metadataEnabled = val } }
    PluginGlobalVar { varName: "metadataAutoFetch"; onValueChanged: (val) => { root._metadataAutoFetch = val } }
    PluginGlobalVar { varName: "metadataDownloadCovers"; onValueChanged: (val) => { root._metadataDownloadCovers = val } }
    PluginGlobalVar { varName: "metadataDownloadBackgrounds"; onValueChanged: (val) => { root._metadataDownloadBackgrounds = val } }
    PluginGlobalVar { varName: "metadataDownloadMedia"; onValueChanged: (val) => { root._metadataDownloadMedia = val } }
    PluginGlobalVar { varName: "metadataDownloadTrailers"; onValueChanged: (val) => { root._metadataDownloadTrailers = val } }
    PluginGlobalVar { varName: "rawgKey"; onValueChanged: (val) => { root._rawgKey = val } }
    PluginGlobalVar { varName: "refreshMetadata"; onValueChanged: (val) => { if (val) root.fetchMetadata(true); } }

    function filterGames() {
        // Fade out grid before updating
        root.gridOpacity = 0.0;
        let result = [];
        let query = root.searchQuery.trim().toLowerCase();
        let filter = root.activeLauncherFilter;
        let launcherAppNames = ["steam", "lutris", "heroic games launcher", "bottles", "ea app", "ubisoft connect", "epic games launcher", "gog galaxy"];
        let seenTitles = new Set();

        for (let i = 0; i < root.rawGamesList.length; i++) {
            let g = root.rawGamesList[i];
            let l_lower = (g.launcher || "").toLowerCase();
            let gTitleLower = (g.title || "").toLowerCase().trim();

            if (l_lower.includes("steam") && !root._scanSteam) continue;
            if (l_lower.includes("lutris") && !root._scanLutris) continue;
            if (l_lower.includes("heroic") && !root._scanHeroic) continue;
            if (l_lower.includes("bottle") && !root._scanBottles) continue;

            if (root._hideLaunchers && launcherAppNames.includes(gTitleLower)) continue;
            if (root._hideDLC && (g.isDLC || gTitleLower.includes(" dlc") || gTitleLower.includes(" expansion") || gTitleLower.includes(" season pass") || gTitleLower.includes(" soundtrack"))) continue;

            if (root._hideDuplicates) {
                if (seenTitles.has(gTitleLower)) continue;
                seenTitles.add(gTitleLower);
            }

            if (g.uninstalled && !root._includeUninstalled && filter !== "Installed") continue;

            if (filter === "Installed" && g.uninstalled) continue;
            if (filter !== "All" && filter !== "Installed" && g.launcher !== filter) continue;
            if (query !== "" && !g.title.toLowerCase().includes(query)) continue;

            // Advanced metadata filters (Tags, Publisher, Developer, Metascore, Missing metadata)
            if (root.filterTag && root.filterTag !== "" && root.filterTag !== "All") {
                let gGenres = g.genres || [];
                let gMissing = g.missingTags || [];
                let matchTag = false;
                if (Array.isArray(gGenres) && gGenres.some(x => x.toLowerCase() === root.filterTag.toLowerCase())) matchTag = true;
                if (Array.isArray(gMissing) && gMissing.some(x => x.toLowerCase() === root.filterTag.toLowerCase())) matchTag = true;
                if (!matchTag) continue;
            }
            if (root.filterHealthTags && root.filterHealthTags.length > 0) {
                let gMissing = g.missingTags || [];
                let allMatch = true;
                for (let h = 0; h < root.filterHealthTags.length; h++) {
                    let reqTag = root.filterHealthTags[h];
                    if (!gMissing.some(m => m.toLowerCase() === reqTag.toLowerCase())) {
                        allMatch = false;
                        break;
                    }
                }
                if (!allMatch) continue;
            }
            if (root.filterPublisher && root.filterPublisher !== "" && root.filterPublisher !== "All") {
                if (!(g.publisher || "").toLowerCase().includes(root.filterPublisher.toLowerCase())) continue;
            }
            if (root.filterDeveloper && root.filterDeveloper !== "" && root.filterDeveloper !== "All") {
                if (!(g.developer || "").toLowerCase().includes(root.filterDeveloper.toLowerCase())) continue;
            }
            if (root.filterMinMetascore > 0) {
                let score = parseInt(g.metascore) || 0;
                if (score < root.filterMinMetascore) continue;
            }
            if (root.filterMinYear > 0 || root.filterMaxYear > 0) {
                let releaseYear = 0;
                let rDate = (g.releaseDate || "").toString();
                let m = rDate.match(/\b(19\d\d|20\d\d)\b/);
                if (m) releaseYear = parseInt(m[1]);
                if (root.filterMinYear > 0 && (releaseYear === 0 || releaseYear < root.filterMinYear)) continue;
                if (root.filterMaxYear > 0 && (releaseYear === 0 || releaseYear > root.filterMaxYear)) continue;
            }

            result.push(g);
        }

        result.sort((a, b) => a.title.localeCompare(b.title));
        root.gameList = result;
        // Fade grid back in
        Qt.callLater(function() { root.gridOpacity = 1.0; });
    }

    property bool _pendingMetaFetch: false
    property bool _phaseCancelled: false
    property real gridOpacity: 1.0

    function scanAllGames() {
        if (scannerProcess.running) return;
        root.isScanning = true;
        scannerProcess.command = ["python3", "-c", getScannerPyScript()];
        scannerProcess.running = true;
    }

    function fetchMetadata(isManual) {
        console.log("GameHub: fetchMetadata called, isManual=" + isManual + " games=" + root.rawGamesList.length + " fetching=" + root.isFetchingMeta);
        _debugLog("fetchMetadata called, isManual = " + isManual + ", rawGamesList = " + root.rawGamesList.length + ", isFetchingMeta = " + root.isFetchingMeta + ", metaPhaseProcess.running = " + metaPhaseProcess.running);
        if (root.isFetchingMeta && !metaPhaseProcess.running) {
            root.isFetchingMeta = false;
        }
        if (root.isFetchingMeta && isManual) {
            console.log("GameHub: Manual fetch clicked while active - restarting...");
            if (metaPhaseProcess.running) {
                metaPhaseProcess.running = false;
            }
            phaseStartTimer.stop();
            root.isFetchingMeta = false;
        } else if (root.isFetchingMeta) {
            return;
        }

        if (isManual === true) {
            root._metadataEnabled = true;
            root._manualMetaEnabled = true;
            root._metadataDownloadCovers = root._metadataDownloadCovers;
            root._metadataDownloadBackgrounds = root._metadataDownloadBackgrounds;
            root._metadataDownloadMedia = root._metadataDownloadMedia;
            root._metadataDownloadTrailers = root._metadataDownloadTrailers;
        } else if (!root._metadataEnabled) {
            _debugLog("metadataEnabled is false, aborting fetch");
            return;
        }

        // If game list is currently empty, try reading directly from /tmp first
        if (root.rawGamesList.length === 0) {
            root.reloadGamesFromFile();
        }

        // If still empty, scan games first and auto-trigger fetch on completion
        if (root.rawGamesList.length === 0) {
            _debugLog("rawGamesList is empty, queuing _pendingMetaFetch and running scanAllGames()");
            root._pendingMetaFetch = true;
            root._fetchTriggeredManually = !!isManual;
            root.scanAllGames();
            return;
        }

        root._pendingMetaFetch = false;
        root._fetchTriggeredManually = isManual === true;
        root._phaseCancelled = false;
        root._manualMetaEnabled = isManual === true;
        root.isFetchingMeta = true;
        root.metaPhase = "metadata";
        root.metaProgressDone = 0;
        root.metaProgressTotal = 0;
        root.metaCurrentTitle = "Starting...";
        console.log("GameHub: Starting metadata pipeline, isManual=" + isManual + " manualEnabled=" + root._manualMetaEnabled);
        _runPhase("metadata");
    }

    // Cancel only whichever phase process is currently running and move to next phase
    function cancelCurrentPhase() {
        if (!root.isFetchingMeta) return;
        // Kill currently running phase process
        if (metaPhaseProcess.running) {
            metaPhaseProcess.running = false;
        }
        root.reloadGamesFromFile();
        // Advance to next phase in sequence
        _advanceToNextPhase();
    }

    readonly property string _pluginDir: {
        if (typeof PluginService !== "undefined" && PluginService && PluginService.getPluginPath) {
            let p = PluginService.getPluginPath("fullscreenGameHub");
            if (p) return p;
        }
        let urlStr = Qt.resolvedUrl(".").toString();
        if (urlStr.startsWith("file://")) urlStr = urlStr.substring(7);
        if (urlStr.endsWith("/")) urlStr = urlStr.substring(0, urlStr.length - 1);
        return urlStr || "/home/JD/Downloads/Projects/DMS-Fullscreen_Game_Hub";
    }

    // Declared here so the Timer can reference the pending phase name
    property string _pendingPhase: ""
    property bool _manualMetaEnabled: false

    // Deferred process start timer — avoids same-cycle Quickshell Process race conditions
    Timer {
        id: phaseStartTimer
        interval: 80
        repeat: false
        onTriggered: {
            console.log("GameHub: phaseStartTimer fired for phase: " + root._pendingPhase);
            if (!root.isFetchingMeta || !root._pendingPhase) return;
            try {
                metaPhaseProcess.running = true;
                console.log("GameHub: metaPhaseProcess.running = true for " + root._pendingPhase);
            } catch(err) {
                console.log("GameHub: ERROR setting metaPhaseProcess.running: " + err);
                root._finishFetch();
            }
        }
    }

    function _runPhase(phase) {
        // Allow run if metadata is enabled OR if this was a manual trigger
        if (!root._metadataEnabled && !root._manualMetaEnabled) { _finishFetch(); return; }
        root.metaPhase = phase;
        root._pendingPhase = phase;
        root.metaProgressDone = 0;
        root.metaProgressTotal = 0;
        root.metaCurrentTitle = "Loading " + phase + "...";
        console.log("GameHub: _runPhase called for: " + phase);

        // Stop any running process first
        try {
            if (metaPhaseProcess.running) {
                metaPhaseProcess.running = false;
            }
        } catch(e) { console.log("GameHub: error stopping old process: " + e); }

        // Build command — call python3 directly (avoids bash pipe issues with Quickshell stdout)
        metaPhaseProcess.command = [
            "python3", "-u",
            root._pluginDir + "/Extension/metadata_enricher.py",
            root._tmpGamesFile,
            root._pluginDir,
            root._rawgKey || "",
            phase
        ];

        // Use a timer to start in next event cycle, letting previous process terminate cleanly
        phaseStartTimer.restart();
    }

    function _onPhaseFinished() {
        _debugLog("Phase completed: " + root.metaPhase);
        root.reloadGamesFromFile();
        _advanceToNextPhase();
    }

    // Advance to next enabled phase in sequence:
    // metadata -> covers -> backgrounds -> media -> trailers (manual only)
    function _advanceToNextPhase() {
        let cur = root.metaPhase;
        let canCovers = root._metadataDownloadCovers;
        let canBg     = root._metadataDownloadBackgrounds;
        let canMedia  = root._metadataDownloadMedia;
        let canTrail  = root._metadataDownloadTrailers && root._fetchTriggeredManually;
        console.log("GameHub: Phase completed: " + cur + ". Next checks -> covers: " + canCovers + ", bg: " + canBg + ", media: " + canMedia + ", trailers: " + canTrail);

        if (cur === "metadata") {
            if (canCovers) {
                _runPhase("covers");
            } else if (canBg) {
                _runPhase("backgrounds");
            } else if (canMedia) {
                _runPhase("media");
            } else if (canTrail) {
                _runPhase("trailers");
            } else {
                _finishFetch();
            }
        } else if (cur === "covers") {
            if (canBg) {
                _runPhase("backgrounds");
            } else if (canMedia) {
                _runPhase("media");
            } else if (canTrail) {
                _runPhase("trailers");
            } else {
                _finishFetch();
            }
        } else if (cur === "backgrounds") {
            if (canMedia) {
                _runPhase("media");
            } else if (canTrail) {
                _runPhase("trailers");
            } else {
                _finishFetch();
            }
        } else if (cur === "media") {
            if (canTrail) {
                _runPhase("trailers");
            } else {
                _finishFetch();
            }
        } else {
            _finishFetch();
        }
    }

    function _finishFetch() {
        root.isFetchingMeta = false;
        root.metaPhase = "";
        root.metaCurrentTitle = "";
    }

    function getScannerPyScript() {
        return `
import json, os, sys, glob, re, sqlite3, urllib.request

_PLUGIN_DIR = "${root._pluginDir}"
_TMP_FILE = "${root._tmpGamesFile}"
_META_ENABLED = ${root._metadataEnabled ? "True" : "False"}
_META_AUTO_FETCH = ${root._metadataAutoFetch ? "True" : "False"}

steam_api_key = "${root._steamApiKey}".strip()
steam_id_cfg = "${root._steamId}".strip()
scan_steam = ${root._scanSteam ? "True" : "False"}
scan_lutris = ${root._scanLutris ? "True" : "False"}
scan_heroic = ${root._scanHeroic ? "True" : "False"}
scan_bottles = ${root._scanBottles ? "True" : "False"}

def parse_title(val):
 if isinstance(val, dict):
  return val.get("en-US") or val.get("en") or val.get("*") or (list(val.values())[0] if val else "")
 return str(val) if val else ""

def extract_img(obj):
 if not obj: return ""
 if isinstance(obj, str):
  if obj.startswith("/") and os.path.exists(obj): return "file://" + obj
  return obj
 if isinstance(obj, dict):
  for k in ["art_cover", "art_square", "cover", "cover_url", "image", "art", "icon", "thumbnail", "square", "url", "box_art", "logo", "banner"]:
   v = obj.get(k)
   if v:
    res = extract_img(v)
    if res: return res
  val = list(obj.values())
  return extract_img(val[0]) if val else ""
 if isinstance(obj, list) and obj:
  return extract_img(obj[0])
 return ""

def get_lutris_cover(slug, appid="", service=""):
 if not slug: return ""
 paths = [
  "~/.local/share/lutris/coverart",
  "~/.cache/lutris/coverart",
  "~/.local/share/lutris/banners",
  "~/.cache/lutris/banners",
  "~/.var/app/net.lutris.Lutris/data/lutris/coverart",
  "~/.var/app/net.lutris.Lutris/cache/lutris/coverart",
  "~/.var/app/net.lutris.Lutris/data/lutris/banners",
  "~/.var/app/net.lutris.Lutris/cache/lutris/banners"
 ]
 for p in paths:
  exp = os.path.expanduser(p)
  for target in [slug, f"{service}-{slug}", f"{slug}-cover", appid]:
   if not target: continue
   for ext in [".jpg", ".png", ".jpeg", ".webp"]:
    f = os.path.join(exp, str(target) + ext)
    if os.path.exists(f): return "file://" + f
 return f"https://lutris.net/media/games/cover/{slug}.jpg"

def map_service_name(svc, text_context="", default_val="Lutris"):
 combined = (str(svc) + " " + str(text_context)).lower()
 if any(k in combined for k in ["origin", "ea_desktop", "eadesktop", "ea app", " ea ", "ea_", "ea-"]): return "EA"
 if any(k in combined for k in ["uplay", "ubisoft", " ubi ", "ubi_"]): return "Ubisoft"
 if any(k in combined for k in ["gog", "gog_"]): return "GOG"
 if any(k in combined for k in ["egs", "epic", "legendary"]): return "Epic"
 if any(k in combined for k in ["amazon", "nile"]): return "Amazon"
 if any(k in combined for k in ["steam"]): return "Steam"
 if any(k in combined for k in ["bottles"]): return "Bottles"
 if any(k in combined for k in ["heroic"]): return "Heroic"
 return default_val

def is_ignored(n):
 n = str(n).lower().strip()
 if not n or n == "[redacted]": return True
 for t in ["proton", "steamworks", "steam runtime", "steam linux runtime", "steam controller", "steamtinkerlaunch", "valvetestapp", "steamvr", " soldier", " sniper", " medic", "steam client", "steam deck", "pressure vessel"]:
  if t in n: return True
 return False

games = []; seen = {}
def add(t, l, c, i="sports_esports", un=False, img="", appid="", prov=""):
 l_str = str(l).lower()
 if "steam" in l_str and not scan_steam: return
 if "lutris" in l_str and not scan_lutris: return
 if "heroic" in l_str and not scan_heroic: return
 if "bottle" in l_str and not scan_bottles: return
 title_str = parse_title(t).strip()
 if not title_str or is_ignored(title_str): return
 key = (title_str.lower(), str(l))
 if key in seen:
  if un and not games[seen[key]]["uninstalled"]: return
  games[seen[key]]["coverUrl"] = games[seen[key]]["coverUrl"] or img
  if prov and not games[seen[key]].get("provider"): games[seen[key]]["provider"] = str(prov)
  return
 seen[key] = len(games)
 entry = {"title": title_str, "launcher": str(l), "cmd": str(c), "icon": str(i), "appIcon": "", "coverUrl": str(img), "uninstalled": bool(un)}
 if prov: entry["provider"] = str(prov)
 games.append(entry)

steam_dirs = [os.path.expanduser(p) for p in ["~/.local/share/Steam", "~/.steam/steam", "~/.steam/root", "~/.var/app/com.valvesoftware.Steam/data/Steam", "~/.var/app/com.valvesoftware.Steam/.local/share/Steam"]]
app_map = {}

# 1. Scan Local Steam Configs
for base in steam_dirs:
 for lc in glob.glob(os.path.join(base, "userdata", "*", "config", "localconfig.vdf")):
  try:
   content = open(lc, errors="ignore").read()
   block = re.search(r'"apps"\\s*\\{([^}]*(?:\\{[^}]*\\}[^}]*)*)\\}', content, re.DOTALL)
   if block:
    for m in re.finditer(r'"(\\d+)"\\s*\\{[^}]*"name"\\s*"([^"]+)"', block.group(1)):
     if m.group(1) not in app_map: app_map[m.group(1)] = m.group(2)
  except: pass

s_folders = set()
for base in steam_dirs:
 s_folders.add(os.path.join(base, "steamapps"))
 vdf = os.path.join(base, "steamapps", "libraryfolders.vdf")
 if os.path.exists(vdf):
  try:
   c = open(vdf, errors="ignore").read()
   for p in re.findall(r'"path"\\s+"([^"]+)"', c): s_folders.add(os.path.join(p.replace("\\\\\\\\", "/").replace("\\\\", "/"), "steamapps"))
  except: pass

# 2. Local Installed Steam Manifests
for d in s_folders:
 if os.path.exists(d):
  for a in glob.glob(os.path.join(d, "appmanifest_*.acf")):
   try:
    c = open(a, errors="ignore").read()
    app = re.search(r'"appid"\\s+"(\\d+)"', c); nm = re.search(r'"name"\\s+"([^"]+)"', c)
    if app and nm and app.group(1) not in ["228980", "1493710"]:
     appid = app.group(1); name = nm.group(1)
     if appid not in app_map: app_map[appid] = name
     cover = "https://cdn.cloudflare.steamstatic.com/steam/apps/" + appid + "/library_600x900_2x.jpg"
     add(name, "Steam", "steam steam://rungameid/" + appid, "sports_esports", False, cover, appid)
   except: pass

# 3. Steam Library Cache
for base in steam_dirs:
 lc_dir = os.path.join(base, "appcache", "librarycache")
 if os.path.exists(lc_dir):
  for g_file in glob.glob(os.path.join(lc_dir, "*_library_600x900.jpg")):
   m = re.search(r"(\\d+)_library_600x900\\.jpg", g_file)
   if m:
    appid = m.group(1)
    if appid not in ["228980", "228990", "1493710"]:
     name = app_map.get(appid, "Steam App " + appid)
     cover = "https://cdn.cloudflare.steamstatic.com/steam/apps/" + appid + "/library_600x900_2x.jpg"
     add(name, "Steam", "steam steam://rungameid/" + appid, "sports_esports", True, cover, appid)

# 4. Steam Online Profile & Web API Sync
target_steam_id = steam_id_cfg
if not target_steam_id:
 for base in steam_dirs:
  l_vdf = os.path.join(base, "config", "loginusers.vdf")
  if os.path.exists(l_vdf):
   try:
    content = open(l_vdf, errors="ignore").read()
    m = re.search(r'"(7656119\\d+)"', content)
    if m: target_steam_id = m.group(1); break
   except: pass

if steam_api_key and target_steam_id:
 try:
  api_url = f"https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key={steam_api_key}&steamid={target_steam_id}&include_appinfo=true&format=json"
  req = urllib.request.Request(api_url, headers={"User-Agent": "DMS-GameHub/1.0"})
  with urllib.request.urlopen(req, timeout=5) as resp:
   api_data = json.loads(resp.read().decode())
   g_list = api_data.get("response", {}).get("games", [])
   for g in g_list:
    aid = str(g.get("appid", ""))
    gnm = g.get("name", "")
    if aid and gnm and aid not in ["228980", "1493710"]:
     g_cover = f"https://cdn.cloudflare.steamstatic.com/steam/apps/{aid}/library_600x900_2x.jpg"
     add(gnm, "Steam", f"steam steam://rungameid/{aid}", "sports_esports", True, g_cover, aid)
 except: pass
elif target_steam_id:
 try:
  xml_url = f"https://steamcommunity.com/profiles/{target_steam_id}/games?xml=1"
  req = urllib.request.Request(xml_url, headers={"User-Agent": "Mozilla/5.0"})
  with urllib.request.urlopen(req, timeout=4) as resp:
   xml_text = resp.read().decode("utf-8", errors="ignore")
   for m in re.finditer(r"<appID>(\\d+)</appID>\\s*<name><!\\[CDATA\\[(.*?)\\]\\]></name>", xml_text):
    aid = m.group(1); gnm = m.group(2)
    if aid and gnm and aid not in ["228980", "1493710"]:
     g_cover = f"https://cdn.cloudflare.steamstatic.com/steam/apps/{aid}/library_600x900_2x.jpg"
     add(gnm, "Steam", f"steam steam://rungameid/{aid}", "sports_esports", True, g_cover, aid)
 except: pass

# 5. Lutris Games
lutris_db_paths = [
 os.path.expanduser(p) for p in [
  "~/.local/share/lutris/pga.db",
  "~/.var/app/net.lutris.Lutris/data/lutris/pga.db",
  "~/.config/lutris/pga.db"
 ]
]

for db in lutris_db_paths:
 if os.path.exists(db):
  try:
   conn = sqlite3.connect(db); cur = conn.cursor()
   try:
    for row in cur.execute("SELECT name, slug, service, installed, appid, id FROM games"):
     nm, slug, svc, inst, appid, gid = row[0], row[1], row[2], row[3], row[4], row[5]
     if nm:
      service_tag = map_service_name(svc, f"{nm} {slug}", "Lutris")
      cmd = f"steam steam://rungameid/{appid}" if (svc == "steam" and appid) else (f"lutris lutris:rungame/{slug}" if slug else f"lutris lutris:rungame-id/{gid}")
      cover = (f"https://cdn.cloudflare.steamstatic.com/steam/apps/{appid}/library_600x900_2x.jpg" if (svc == "steam" and appid) else "") or get_lutris_cover(slug, appid, svc)
      add(nm, service_tag, cmd, "extension", not bool(inst), cover, prov="Lutris")
   except: pass
   try:
    for row in cur.execute("SELECT name, slug, service, appid FROM service_games"):
     nm, slug, svc, appid = row[0], row[1], row[2], row[3]
     if nm:
      service_tag = map_service_name(svc, f"{nm} {slug}", "Lutris")
      cmd = f"lutris lutris:rungame/{slug}" if slug else f"lutris lutris:rungame-id/{slug}"
      cover = (f"https://cdn.cloudflare.steamstatic.com/steam/apps/{appid}/library_600x900_2x.jpg" if (svc == "steam" and appid) else "") or get_lutris_cover(slug, appid, svc)
      add(nm, service_tag, cmd, "extension", True, cover, prov="Lutris")
   except: pass
  except: pass

lutris_svc_dirs = [
 os.path.expanduser(p) for p in [
  "~/.cache/lutris/service-games",
  "~/.local/share/lutris/service-games",
  "~/.config/lutris/service-games",
  "~/.var/app/net.lutris.Lutris/cache/lutris/service-games",
  "~/.var/app/net.lutris.Lutris/data/lutris/service-games"
 ]
]

for sdir in lutris_svc_dirs:
 if os.path.exists(sdir):
  for sf in glob.glob(os.path.join(sdir, "*.json")):
   svc_name = os.path.splitext(os.path.basename(sf))[0]
   try:
    d = json.load(open(sf, errors="ignore"))
    items = d if isinstance(d, list) else (d.get("games", []) if isinstance(d, dict) else [])
    for it in items:
     if isinstance(it, dict):
      nm = it.get("name") or it.get("title")
      slug = it.get("slug") or it.get("appid") or it.get("id") or nm
      service_tag = map_service_name(svc_name, f"{nm} {slug}", "Lutris")
      img = extract_img(it) or get_lutris_cover(slug, "", svc_name)
      if nm: add(nm, service_tag, f"lutris lutris:rungame/{slug}", "extension", True, img, prov="Lutris")
   except: pass

lutris_yml_dirs = [os.path.expanduser(p) for p in ["~/.config/lutris/games", "~/.local/share/lutris/games", "~/.var/app/net.lutris.Lutris/config/lutris/games", "~/.var/app/net.lutris.Lutris/data/lutris/games"]]
for ldir in lutris_yml_dirs:
 if os.path.exists(ldir):
  for yfile in glob.glob(os.path.join(ldir, "*.yml")):
   try:
    content = open(yfile, errors="ignore").read()
    name_m = re.search(r"^name:\\s*(.+)$", content, re.MULTILINE)
    slug_m = re.search(r"^slug:\\s*(.+)$", content, re.MULTILINE)
    runner_m = re.search(r"^runner:\\s*(.+)$", content, re.MULTILINE)
    if name_m:
     g_name = name_m.group(1).strip().strip("'").strip('"')
     g_slug = slug_m.group(1).strip().strip("'").strip('"') if slug_m else os.path.splitext(os.path.basename(yfile))[0]
     g_runner = runner_m.group(1).strip().strip("'").strip('"') if runner_m else "lutris"
     service_tag = map_service_name(g_runner, f"{g_name} {g_slug} {content}", "Lutris")
     cover = get_lutris_cover(g_slug, "", g_runner)
     add(g_name, service_tag, f"lutris lutris:rungame/{g_slug}", "extension", False, cover, prov="Lutris")
   except: pass

# 6. Heroic Games Launcher
for hd in ["~/.config/heroic", "~/.var/app/com.heroicgameslauncher.hgl/config/heroic"]:
 hexp = os.path.expanduser(hd)
 if os.path.exists(hexp):
  for root_d, dirs_d, files_f in os.walk(hexp):
   for f in files_f:
    if f.endswith(".json") and any(k in f for k in ["installed", "library", "gog", "legendary", "sideload", "store", "nile", "ubisoft"]):
     fp = os.path.join(root_d, f)
     try:
      d = json.load(open(fp, errors="ignore"))
      items = d.get("installed", []) or d.get("library", []) if isinstance(d, dict) else (d if isinstance(d, list) else [])
      for it in items:
       if isinstance(it, dict):
        t = it.get("title") or it.get("name") or it.get("appName")
        an = it.get("appName") or it.get("app_name") or it.get("id") or t
        is_inst = bool(it.get("is_installed") or it.get("installed") or "installed.json" in fp)
        store = it.get("runner") or it.get("store") or ("gog" if "gog" in f else ("legendary" if "legendary" in f else ("nile" if "nile" in f else ("ubisoft" if "ubisoft" in f else "Heroic"))))
        service_tag = map_service_name(store, "Heroic")
        add(t, service_tag, "heroic --launch " + str(parse_title(an)), "star", not is_inst, extract_img(it), prov="Heroic")
     except: pass

# 7. Bottles / Wine
for b_path in ["~/.local/share/bottles/bottles", "~/.var/app/com.usebottles.bottles/data/bottles/bottles"]:
 b_dir = os.path.expanduser(b_path)
 if os.path.exists(b_dir):
  for b in os.listdir(b_dir): add("Bottle: " + b, "Bottles", "flatpak run com.usebottles.bottles -b " + b, "local_bar", False, prov="Bottles")

# 7.5 Epic Games Launcher (Standalone / Flatpak / Wine)
epic_manifests = [
 os.path.expanduser(p) for p in [
  "~/.config/Epic/EpicGamesLauncher/Data/Manifests",
  "~/.local/share/EpicGamesLauncher/Saved/Config",
  "~/.var/app/com.epicgames.Launcher/data/Epic/EpicGamesLauncher/Data/Manifests"
 ]
]
for ed in epic_manifests:
 if os.path.exists(ed):
  for item_f in glob.glob(os.path.join(ed, "*.item")):
   try:
    data = json.load(open(item_f, errors="ignore"))
    t = data.get("DisplayName") or data.get("AppName")
    an = data.get("AppName") or t
    if t:
     cmd = f"flatpak run com.epicgames.Launcher -com.epicgames.launcher://apps/{an}?action=launch"
     add(t, "Epic Games", cmd, "flash_on", False, "", an, prov="Epic Games")
   except: pass

# 8. Enrich with existing local covers, backgrounds and metadata cache
_ext_data = os.path.join(_PLUGIN_DIR, "Extension Data")
_cov_dir = os.path.join(_ext_data, "covers")
_bg_dir = os.path.join(_ext_data, "backgrounds")
_meta_json = os.path.join(_ext_data, "metadata.json")
_cache = {}
if os.path.exists(_meta_json):
 try:
  with open(_meta_json, "r", encoding="utf-8") as _mf:
   _cache = json.load(_mf) or {}
 except: pass

for g in games:
 t = g.get("title", "")
 ckey = re.sub(r"[^a-z0-9 ]", "", t.lower().strip()).strip()
 slug = re.sub(r"[^a-z0-9_-]", "_", ckey.lower())[:80]
 # Check existing downloaded cover
 if os.path.exists(_cov_dir):
  for cf in glob.glob(os.path.join(_cov_dir, slug + ".*")):
   if os.path.getsize(cf) > 1000:
    g["coverUrl"] = "file://" + os.path.abspath(cf)
    break
 # Check existing downloaded background
 if os.path.exists(_bg_dir):
  for bf in glob.glob(os.path.join(_bg_dir, slug + ".*")):
   if os.path.getsize(bf) > 1000:
    g["backgroundUrl"] = "file://" + os.path.abspath(bf)
    break
 # Attach cached fields if present
 if ckey in _cache:
  cm = _cache[ckey]
  for k in ["description", "genres", "releaseDate", "publisher", "developer", "rating", "screenshots", "trailers", "metascore", "metaSource"]:
   if cm.get(k) and not g.get(k): g[k] = cm[k]
  if not g.get("backgroundUrl") and cm.get("background"):
   g["backgroundUrl"] = cm["background"]

 m_tags = []
 if not g.get("trailers") or len(g.get("trailers")) == 0:
  m_tags.append("Missing Trailer")
 if not g.get("coverUrl") or g.get("coverUrl") == "fallback":
  m_tags.append("Missing Cover")
 if not g.get("backgroundUrl"):
  m_tags.append("Missing Background")
 if not g.get("description"):
  m_tags.append("Missing Description")
 g["missingTags"] = m_tags

# Write raw games list to stdout AND save to temp file for metadata process
try:
 with open(_TMP_FILE, "w", encoding="utf-8") as _tf:
  json.dump(games, _tf, ensure_ascii=False)
except Exception:
 pass

print(f"SCAN_COMPLETE:{len(games)}")
`;
    }

    Process {
        id: scannerProcess
        stdout: SplitParser {
            onRead: function(data) {
                let s = data.trim();
                if (s.startsWith("SCAN_COMPLETE:")) {
                    console.log("GameHub scanner finished: " + s);
                    root.reloadGamesFromFile();
                }
            }
        }
        onExited: {
            root.isScanning = false;
            root.reloadGamesFromFile();
            if (root._pendingMetaFetch) {
                let manual = root._fetchTriggeredManually;
                root._pendingMetaFetch = false;
                Qt.callLater(function() { root.fetchMetadata(manual); });
            } else if (root._metadataEnabled && root._metadataAutoFetch) {
                Qt.callLater(function() { root.fetchMetadata(false); });
            }
        }
    }

    // Single phase process — used for all 4 phases sequentially
    // Kill it via metaPhaseProcess.running = false to cancel the current phase
    Process {
        id: metaPhaseProcess
        stdout: SplitParser {
            onRead: function(line) {
                let s = line.trim();
                if (!s) return;
                if (s === "RELOAD") {
                    // Mid-run reload: refresh grid immediately so new covers/data appear
                    root.reloadGamesFromFile();
                } else if (s.startsWith("PROGRESS:")) {
                    // PROGRESS:<phase>:<done>:<total>:<title>
                    let parts = s.split(":");
                    if (parts.length >= 5) {
                        root.metaPhase         = parts[1];
                        root.metaProgressDone  = parseInt(parts[2]) || 0;
                        root.metaProgressTotal = parseInt(parts[3]) || 0;
                        root.metaCurrentTitle  = parts.slice(4).join(":");
                    }
                }
            }
        }
        stderr: SplitParser {
            onRead: function(line) {
                let s = line.trim();
                if (s) {
                    console.log("GameHub Enricher stderr: " + s);
                    root._debugLog("Enricher stderr: " + s);
                }
            }
        }
        onExited: function(exitCode) {
            root._debugLog("metaPhaseProcess onExited with code: " + exitCode + ", isFetchingMeta=" + root.isFetchingMeta);
            if (root.isFetchingMeta) {
                root._onPhaseFinished();
            }
        }
    }

    // Kept for compatibility — old single-process fetch (now unused)
    Process { id: metadataFetchProcess }

    property var _debugQueue: []
    property bool _debugWriting: false

    Process {
        id: debugFileProcess
        onExited: {
            root._debugWriting = false;
            root._flushDebugLog();
        }
    }

    function _flushDebugLog() {
        if (root._debugWriting || root._debugQueue.length === 0) return;
        let batch = root._debugQueue.splice(0, 10);
        root._debugWriting = true;
        let escaped = batch.map(function(item) {
            return "echo " + JSON.stringify(item) + " >> /tmp/gamehub_debug.log";
        }).join(" && ");
        try {
            debugFileProcess.command = ["bash", "-c", escaped];
            debugFileProcess.running = true;
        } catch(e) {
            root._debugWriting = false;
        }
    }

    function _debugLog(msg) {
        console.log("GameHub: " + msg);
        let entry = new Date().toISOString() + " " + msg;
        root._debugQueue.push(entry);
        root._flushDebugLog();
    }

    function reloadGamesFromFile() {
        gamesFileView.reload();
        try {
            let content = gamesFileView.text();
            if (content) {
                let parsed = JSON.parse(content);
                if (Array.isArray(parsed) && parsed.length > 0) {
                    for (let i = 0; i < parsed.length; i++) {
                        let g = parsed[i];
                        let m_tags = [];
                        if (!g.trailers || g.trailers.length === 0) m_tags.push("Missing Trailer");
                        if (!g.coverUrl || g.coverUrl === "fallback") m_tags.push("Missing Cover");
                        if (!g.backgroundUrl) m_tags.push("Missing Background");
                        if (!g.description) m_tags.push("Missing Description");
                        g.missingTags = m_tags;
                    }
                    root.rawGamesList = parsed;
                    root.filterGames();
                    _debugLog("Refreshed " + parsed.length + " games directly via reloadGamesFromFile()");
                }
            }
        } catch(e) {
            _debugLog("reloadGamesFromFile parse error: " + e);
        }
    }

    FileView {
        id: gamesFileView
        path: root._tmpGamesFile
        watchChanges: true
        onLoaded: {
            try {
                let content = text();
                if (!content) return;
                let parsed = JSON.parse(content);
                if (Array.isArray(parsed) && parsed.length > 0) {
                    for (let i = 0; i < parsed.length; i++) {
                        let g = parsed[i];
                        let m_tags = [];
                        if (!g.trailers || g.trailers.length === 0) m_tags.push("Missing Trailer");
                        if (!g.coverUrl || g.coverUrl === "fallback") m_tags.push("Missing Cover");
                        if (!g.backgroundUrl) m_tags.push("Missing Background");
                        if (!g.description) m_tags.push("Missing Description");
                        g.missingTags = m_tags;
                    }
                    root.rawGamesList = parsed;
                    root.filterGames();
                }
            } catch(e) {
                console.log("Error loading games via FileView: " + e);
            }
        }
        onLoadFailed: error => console.log("GameHub: failed to read games JSON: " + error)
    }


    Process {
        id: launcherProcess
        running: false
        onExited: {
            if (root._autoCloseOnLaunch && root.popoutOpen) {
                root.popoutOpen = false;
            }
        }
    }

    function launchGame(target) {
        if (!target) return;
        let cmd = "";
        if (typeof target === "string") {
            cmd = target;
        } else if (typeof target === "object") {
            if (target.cmd) {
                cmd = target.cmd;
            } else if (target.launcher && target.launcher.toLowerCase().includes("steam")) {
                let aid = target.appId || target.appid;
                cmd = aid ? ("steam steam://rungameid/" + aid) : "steam";
            } else if (target.launcher && target.launcher.toLowerCase().includes("heroic")) {
                cmd = target.title ? ("heroic --launch \"" + target.title + "\"") : "heroic";
            } else if (target.launcher && target.launcher.toLowerCase().includes("lutris")) {
                cmd = target.slug ? ("lutris lutris:rungame/" + target.slug) : "lutris";
            } else if (target.launcher && target.launcher.toLowerCase().includes("bottle")) {
                cmd = "flatpak run com.usebottles.bottles";
            }
        }
        if (!cmd) return;
        console.log("GameHub: Launching command: " + cmd);
        launcherProcess.command = ["bash", "-c", cmd + " &"];
        launcherProcess.running = true;
    }

    function openGamePage(game) {
        if (!game) return;
        let l = (game.launcher || "").toLowerCase();
        let cmd = (game.cmd || "").toLowerCase();
        let aid = game.appId || game.appid || "";

        if (l.includes("steam") || cmd.includes("steam://")) {
            let m = (game.cmd || "").match(/rungameid\/(\d+)/);
            if (m && m[1]) aid = m[1];
            if (aid) {
                Qt.openUrlExternally("https://store.steampowered.com/app/" + aid);
                return;
            }
        }
        if (l.includes("heroic") || cmd.includes("heroic")) {
            launcherProcess.command = ["bash", "-c", "flatpak run com.heroicgameslauncher.hgl & heroic &"];
            launcherProcess.running = true;
            return;
        }
        if (l.includes("lutris") || cmd.includes("lutris")) {
            let slug = game.slug || "";
            if (slug) {
                Qt.openUrlExternally("https://lutris.net/games/" + slug);
            } else {
                launcherProcess.command = ["bash", "-c", "lutris &"];
                launcherProcess.running = true;
            }
            return;
        }
        if (l.includes("bottle") || cmd.includes("bottle")) {
            launcherProcess.command = ["bash", "-c", "flatpak run com.usebottles.bottles &"];
            launcherProcess.running = true;
            return;
        }
        if (game.cmd) {
            root.launchGame(game);
        }
    }

    function deleteGame(game) {
        if (!game) return;
        let cmd = "";
        let l = (game.launcher || "").toLowerCase();
        let title = game.title || "";
        let aid = game.appId || game.appid || "";

        if (l.includes("steam")) {
            if (aid) {
                cmd = "steam steam://uninstall/" + aid;
            } else {
                cmd = "steam";
            }
        } else if (l.includes("heroic")) {
            cmd = "heroic --uninstall \"" + title + "\"";
        } else if (l.includes("lutris")) {
            let slug = game.slug || "";
            cmd = slug ? ("lutris lutris:uninstall/" + slug) : "lutris";
        } else if (l.includes("bottle")) {
            cmd = "flatpak run com.usebottles.bottles";
        }
        if (cmd) {
            console.log("GameHub: Uninstalling game via provider: " + cmd);
            launcherProcess.command = ["bash", "-c", cmd + " &"];
            launcherProcess.running = true;
        }
    }

    function ensureNiriRules() {
        let openOnGames = PluginService.loadPluginData("fullscreenGameHub", "openOnWorkspaceGames", false);
        let niriProc = Qt.createQmlObject('import Quickshell.Io; Process {}', root, "niriProc_" + Date.now());
        let script = `
import os
home = os.path.expanduser("~")
niri_cfg = os.path.join(home, ".config/niri/config.kdl")
dms_dir = os.path.join(home, ".config/niri/dms")
rule_file = os.path.join(dms_dir, "gamehub.kdl")

if os.path.exists(niri_cfg):
    os.makedirs(dms_dir, exist_ok=True)
    ws_line = '        open-on-workspace "Games"\\n' if ` + (openOnGames ? "True" : "False") + ` else ''
    rule_content = f'''// DMS Fullscreen Game Hub - Tiling & Sizing Rules
window-rule {
        match title="^Game Hub.*"
        open-floating false
{ws_line}        default-column-width { proportion 1.0; }
        default-window-height { proportion 1.0; }
}
'''
    with open(rule_file, "w") as f:
        f.write(rule_content)
    try:
        cfg_text = open(niri_cfg, "r", errors="ignore").read()
        if 'include "dms/gamehub.kdl"' not in cfg_text:
            with open(niri_cfg, "a") as f:
                f.write('\\ninclude "dms/gamehub.kdl"\\n')
    except Exception:
        pass
`;
        niriProc.command = ["python3", "-c", script];
        niriProc.running = true;
    }

    function ensureDesktopLauncher() {
        let deskProc = Qt.createQmlObject('import Quickshell.Io; Process {}', root, "deskProc_" + Date.now());
        let script = `
import os
home = os.path.expanduser("~")
apps_dir = os.path.join(home, ".local/share/applications")
os.makedirs(apps_dir, exist_ok=True)
desktop_path = os.path.join(apps_dir, "dms-gamehub.desktop")
desktop_content = """[Desktop Entry]
Type=Application
Name=Game Hub
GenericName=Game Launcher
Comment=Unified Game Launcher & Fullscreen Hub for Linux
Exec=dms ipc call fullscreenGameHub open
Icon=applications-games
Terminal=false
Categories=Game;Launcher;
StartupNotify=true
"""
if not os.path.exists(desktop_path):
    with open(desktop_path, "w") as f:
        f.write(desktop_content)
`;
        deskProc.command = ["python3", "-c", script];
        deskProc.running = true;
    }

    function openFullscreenApp() {
        // Auto-check and setup niri rules & desktop entry
        ensureNiriRules();
        ensureDesktopLauncher();

        // Ensure this widget instance loads and manages the single window
        if (!windowLoader.active) {
            windowLoader.active = true;
        }

        Qt.callLater(function() {
            if (gameHubWindow) {
                gameHubWindow.themeMode = PluginService.loadPluginData("fullscreenGameHub", "windowThemeMode", "dark");
                gameHubWindow.visible = true;
                if (typeof gameHubWindow.requestActivate === "function") {
                    gameHubWindow.requestActivate();
                }
                if (typeof gameHubWindow.raise === "function") {
                    gameHubWindow.raise();
                }
            }
        });

        // Broadcast single-instance open state
        if (typeof PluginService !== "undefined" && PluginService && PluginService.setGlobalVar) {
            PluginService.setGlobalVar("fullscreenGameHub", "windowOpenState", true);
        }
    }

    // --- Bar Pill Components ---
    horizontalBarPill: Component {
        RowLayout {
            spacing: 6; anchors.verticalCenter: parent.verticalCenter
            DIcon {
                name: "sports_esports"
                size: Theme.iconSize - 4
                color: root.rawGamesList.length > 0 ? Theme.primary : Theme.surfaceVariantText
                Layout.alignment: Qt.AlignVCenter
            }
            StyledText {
                text: root._showStatsInPill ? (root.totalGamesCount + " Games") : "Game Hub"
                font.pixelSize: Theme.fontSizeSmall - 1
                font.weight: Font.Medium
                color: Theme.widgetTextColor || Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        ColumnLayout {
            spacing: 2
            anchors.horizontalCenter: parent.horizontalCenter
            DIcon {
                name: "sports_esports"
                size: 18
                color: root.rawGamesList.length > 0 ? Theme.primary : Theme.surfaceVariantText
                Layout.alignment: Qt.AlignHCenter
            }
            StyledText {
                text: root.totalGamesCount.toString()
                font.pixelSize: 9
                font.weight: Font.Bold
                color: Theme.widgetTextColor || Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popoutWrapper
            headerText: ""
            showCloseButton: false

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight
                height: root.popoutHeight

                Loader {
                    anchors.fill: parent
                    sourceComponent: gameHubContent
                }
            }
        }
    }


    Component {
        id: gameHubContent

        Item {
            id: hubRoot
            implicitWidth: root.popoutWidth
            implicitHeight: root.popoutHeight
            width: parent ? parent.width : root.popoutWidth
            height: parent ? parent.height : root.popoutHeight


            // ── FIXED HEADER ──────────────────────────────────────────────
            StyledRect {
                id: fixedHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: headerCol.implicitHeight + 16
                color: Theme.withAlpha(Theme.surface, 0.96)
                z: 10

                ColumnLayout {
                    id: headerCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // Title bar
                    StyledRect {
                        Layout.fillWidth: true; height: 54
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                        border.width: 1
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)

                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 10
                            Rectangle {
                                width: 34; height: 34; radius: 17
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                                border.width: 1
                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                                DIcon { name: "sports_esports"; size: 18; color: Theme.primary; anchors.centerIn: parent }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 1
                                StyledText {
                                    text: "Game Hub"; font.bold: true; font.pixelSize: Theme.fontSizeLarge
                                    color: Theme.surfaceText; elide: Text.ElideRight; Layout.fillWidth: true
                                }
                                StyledText {
                                    text: root.isScanning
                                        ? "Scanning libraries..."
                                        : (root.isFetchingMeta
                                            ? ("Fetching metadata: " + root.metaCurrentTitle)
                                            : (root.rawGamesList.length + " games available"))
                                    font.pixelSize: Theme.fontSizeSmall - 1; color: Theme.primary; opacity: 0.8
                                    elide: Text.ElideRight; Layout.fillWidth: true
                                }
                            }

                            // Fullscreen Window Button
                            Rectangle {
                                width: 30; height: 30; radius: 15
                                color: maFullscreen.containsMouse
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                                    : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                                border.width: 1
                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                                DIcon {
                                    name: "open_in_full"; size: 15; color: Theme.primary; anchors.centerIn: parent
                                }
                                MouseArea {
                                    id: maFullscreen
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.openFullscreenApp();
                                        if (typeof root.closePopout === "function") {
                                            root.closePopout();
                                        }
                                        if (typeof popoutWrapper !== "undefined" && popoutWrapper && typeof popoutWrapper.closePopout === "function") {
                                            popoutWrapper.closePopout();
                                        }
                                    }
                                }
                            }

                            // Refresh Metadata Button
                            Rectangle {
                                id: metaRefreshBtn
                                width: 30; height: 30; radius: 15
                                visible: !root.isScanning
                                color: maMetaRefresh.containsMouse
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                                    : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                                border.width: 1
                                border.color: root.isFetchingMeta
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
                                    : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                // Animated glow ring while fetching
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 30; height: 30; radius: 15
                                    color: "transparent"
                                    border.width: 2
                                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.0)
                                    visible: root.isFetchingMeta
                                    SequentialAnimation on border.color {
                                        loops: Animation.Infinite
                                        running: root.isFetchingMeta
                                        ColorAnimation { to: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.7); duration: 700 }
                                        ColorAnimation { to: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.0); duration: 700 }
                                    }
                                }

                                DIcon {
                                    name: "auto_awesome"
                                    size: 15
                                    color: root.isFetchingMeta ? Theme.primary : Theme.surfaceVariantText
                                    anchors.centerIn: parent
                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    RotationAnimation on rotation {
                                        from: 0; to: 360; duration: 2000
                                        loops: Animation.Infinite
                                        running: root.isFetchingMeta
                                        onRunningChanged: if (!running) rotation = 0
                                    }
                                }
                                MouseArea {
                                    id: maMetaRefresh
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!root.isFetchingMeta) root.fetchMetadata(true);
                                    }
                                }

                                // Tooltip
                                StyledText {
                                    anchors.right: parent.left
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.isFetchingMeta ? "Fetching..." : "Refresh Metadata"
                                    font.pixelSize: Theme.fontSizeSmall - 2
                                    color: Theme.surfaceVariantText
                                    visible: maMetaRefresh.containsMouse || root.isFetchingMeta
                                }
                            }

                            // Refresh Library Button
                            Rectangle {
                                width: 30; height: 30; radius: 15
                                color: maScan.containsMouse
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                                    : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                                border.width: 1
                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                                DIcon {
                                    name: "refresh"; size: 15; color: Theme.primary; anchors.centerIn: parent
                                    RotationAnimation on rotation {
                                        from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: root.isScanning
                                        onRunningChanged: if (!running) rotation = 0
                                    }
                                }
                                MouseArea {
                                    id: maScan
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.scanAllGames()
                                }
                            }
                        }
                    }

                    // Search Bar
                    StyledRect {
                        Layout.fillWidth: true; height: 38
                        radius: 19
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.6)
                        border.width: 1
                        border.color: searchInput.activeFocus ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.1)

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                            DIcon { name: "search"; size: 16; color: Theme.surfaceVariantText }
                            TextField {
                                id: searchInput
                                Layout.fillWidth: true
                                placeholderText: "Search game library..."
                                placeholderTextColor: Theme.surfaceVariantText
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeSmall
                                background: null
                                onTextChanged: { root.searchQuery = text; root.filterGames(); }
                            }
                            DIcon {
                                name: "cancel"; size: 14; color: Theme.surfaceVariantText
                                visible: searchInput.text.length > 0
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { searchInput.text = ""; root.searchQuery = ""; root.filterGames(); }
                                }
                            }
                        }
                    }
                }
            }

            // ── ALIGNED FILTER CHIPS CONTAINER (Matches Cards Grid Left Edge) ─
            Item {
                id: filterBarWidget
                anchors.top: fixedHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 6
                height: 32

                ScrollView {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    clip: true
                    contentWidth: filterRow.implicitWidth
                    ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                    ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                    Row {
                        id: filterRow
                        spacing: 6

                        Repeater {
                            model: {
                                let list = ["All", "Installed"];
                                if (root.rawGamesList && root.rawGamesList.length > 0) {
                                    for (let i = 0; i < root.rawGamesList.length; i++) {
                                        let tag = root.rawGamesList[i].launcher;
                                        if (tag && list.indexOf(tag) === -1) {
                                            list.push(tag);
                                        }
                                    }
                                } else {
                                    // Default launcher categories so popup never displays empty
                                    let defaults = ["steam", "lutris", "heroic", "bottles"];
                                    for (let j = 0; j < defaults.length; j++) {
                                        if (list.indexOf(defaults[j]) === -1) list.push(defaults[j]);
                                    }
                                }
                                return list;
                            }

                            delegate: StyledRect {
                                height: 26
                                radius: 13
                                width: chipLbl.implicitWidth + 20
                                color: root.activeLauncherFilter === modelData
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                                    : Qt.rgba(Theme.surfaceContainerHigh.r, Theme.surfaceContainerHigh.g, Theme.surfaceContainerHigh.b, 0.5)
                                border.width: 1
                                border.color: root.activeLauncherFilter === modelData
                                    ? Theme.primary
                                    : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.1)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                StyledText {
                                    id: chipLbl
                                    text: modelData
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    font.weight: root.activeLauncherFilter === modelData ? Font.SemiBold : Font.Normal
                                    color: root.activeLauncherFilter === modelData ? Theme.primary : Theme.surfaceText
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.activeLauncherFilter = modelData;
                                        root.filterGames();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── MAIN CONTENT AREA ──────────────────────────────────────────
            Item {
                anchors.top: filterBarWidget.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: 8

                // Loading State
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    visible: root.isScanning && root.gameList.length === 0

                    DIcon {
                        name: "refresh"; size: 36; color: Theme.primary
                        anchors.horizontalCenter: parent.horizontalCenter
                        RotationAnimation on rotation {
                            from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: parent.visible
                        }
                    }
                    StyledText { text: "Scanning game libraries..."; font.pixelSize: Theme.fontSizeMedium; color: Theme.surfaceText }
                }

                // Empty State
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: !root.isScanning && root.gameList.length === 0

                    DIcon { name: "sports_esports"; size: 40; color: Theme.surfaceVariantText; anchors.horizontalCenter: parent.horizontalCenter }
                    StyledText { text: "No games found matching filter"; font.pixelSize: Theme.fontSizeMedium; color: Theme.surfaceVariantText }
                }

                // Games Grid
                GridView {
                    id: gameGrid
                    cellWidth: 145
                    cellHeight: 215
                    opacity: root.gridOpacity
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
                    width: Math.max(cellWidth, Math.floor(parent.width / cellWidth) * cellWidth)

                    height: parent.height
                    anchors.horizontalCenter: parent.horizontalCenter
                    clip: true
                    visible: root.gameList.length > 0

                    model: root.gameList

                    delegate: Item {
                        width: gameGrid.cellWidth
                        height: gameGrid.cellHeight

                        readonly property var gData: modelData
                        readonly property bool isHovered: cardMA.containsMouse

                        // CLEAN ROUNDED ELEVATED GAME CARD
                        Rectangle {
                            id: gameCardBoxPopout
                            anchors.fill: parent
                            anchors.margins: 6
                            radius: 16
                            clip: true
                            color: isHovered
                                ? Theme.withAlpha(Theme.surfaceContainerHigh, 0.98)
                                : Theme.withAlpha(Theme.surfaceContainerHigh, 0.85)
                            border.width: isHovered ? 2 : 1
                            border.color: isHovered
                                ? Theme.primary
                                : Theme.withAlpha(Theme.surfaceText, 0.12)

                            scale: isHovered ? 1.025 : 1.0
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                            Behavior on border.color { ColorAnimation { duration: 140 } }

                            // 1. Cover Image Area (Fills Top Area with 16px Rounded Top Corners)
                            Rectangle {
                                id: coverAreaPopout
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: footerAreaPopout.top
                                radius: 16
                                color: Theme.withAlpha(Theme.surfaceContainer, 0.9)
                                clip: true

                                // Square off bottom edge of cover area so only top corners are 16px rounded
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 16
                                    color: coverAreaPopout.color
                                }

                                Image {
                                    id: cardCover
                                    anchors.fill: parent
                                    source: gData.coverUrl || ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: status === Image.Ready

                                    scale: isHovered ? 1.04 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 180 } }
                                }

                                // Fallback Cover Graphic
                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.withAlpha(Theme.primary, 0.1)
                                    visible: !cardCover.visible
                                    DIcon {
                                        name: gData.icon || "sports_esports"
                                        size: 38
                                        color: Theme.primary
                                        anchors.centerIn: parent
                                    }
                                }

                                // Platform Badge (Top-Left)
                                Rectangle {
                                    anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 6
                                    height: 20; radius: 10
                                    width: platformRow.implicitWidth + 10
                                    color: Theme.withAlpha(Theme.surface, 0.88)
                                    border.width: 1
                                    border.color: Theme.withAlpha(Theme.surfaceText, 0.12)

                                    Row {
                                        id: platformRow
                                        anchors.centerIn: parent; spacing: 3
                                        DIcon {
                                            name: gData.launcher === "Steam" ? "sports_esports" : (gData.launcher === "GOG" ? "star" : (gData.launcher === "Epic" ? "flash_on" : (gData.launcher === "EA" ? "sports_esports" : (gData.launcher === "Ubisoft" ? "gamepad" : (gData.launcher === "Bottles" ? "local_bar" : "extension")))))
                                            size: 11; color: Theme.primary
                                        }
                                        StyledText {
                                            text: gData.launcher
                                            font.pixelSize: 9; font.bold: true; color: Theme.surfaceText
                                        }
                                    }
                                }
                            }

                            // 2. Card Footer Details Box (Fixed Height at Bottom with 16px Rounded Bottom Corners)
                            Rectangle {
                                id: footerAreaPopout
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 48
                                radius: 16
                                color: Theme.withAlpha(Theme.surfaceContainer, 0.95)

                                // Square off top edge of footer so only bottom corners are 16px rounded
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 16
                                    color: footerAreaPopout.color
                                }

                                // Top Divider Line
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 1
                                    color: Theme.withAlpha(Theme.surfaceText, 0.12)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    anchors.topMargin: 4
                                    anchors.bottomMargin: 4
                                    spacing: 4

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: gData.title
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        font.bold: true
                                        color: isHovered ? Theme.primary : Theme.surfaceText
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                        wrapMode: Text.Wrap
                                    }

                                    Rectangle {
                                        width: 24; height: 24; radius: 12
                                        color: isHovered
                                            ? (gData.uninstalled ? Theme.withAlpha(Theme.secondary, 0.25) : Theme.withAlpha(Theme.primary, 0.25))
                                            : Theme.withAlpha(Theme.surfaceContainerHigh, 0.8)
                                        border.width: 1
                                        border.color: isHovered ? (gData.uninstalled ? Theme.secondary : Theme.primary) : Theme.withAlpha(Theme.surfaceText, 0.1)

                                        DIcon {
                                            name: gData.uninstalled ? "download" : "play_arrow"
                                            size: 14
                                            color: isHovered
                                                ? (gData.uninstalled ? Theme.secondary : Theme.primary)
                                                : Theme.surfaceVariantText
                                            anchors.centerIn: parent
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: cardMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (gData.cmd) {
                                        root.launchGame(gData.cmd);
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
