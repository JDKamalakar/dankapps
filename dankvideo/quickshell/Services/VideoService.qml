pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property var fileList: []
    property int currentIndex: 0
    readonly property string currentFilePath: fileList.length > 0 && currentIndex >= 0 && currentIndex < fileList.length ? fileList[currentIndex] : ""
    readonly property string currentFileName: {
        if (!currentFilePath) return "";
        const parts = currentFilePath.split("/");
        return parts[parts.length - 1];
    }

    property var currentMeta: ({})
    property bool inspectorOpen: false
    property bool playlistDrawerOpen: false
    property bool folderPlayPromptOpen: false
    property string pendingFolderPromptPath: ""
    property int pendingFolderVideoCount: 0
    property var pendingFolderAllVideos: []
    property bool settingsOpen: false
    property bool isFullscreen: Quickshell.env("DPLAY_FULLSCREEN") === "1"
    property bool uiLocked: false
    property string lastTrashedPath: ""

    // Playlist Controls & Skips
    property bool playlistShuffled: false
    property int playlistLoopMode: 0 // 0: off, 1: loop all, 2: loop one
    property var playlistOriginalOrder: []
    property var skippedAlwaysList: [] // persistently or session skipped
    property var skippedOnceList: [] // skipped on next iteration

    // In-app Playlists
    property var customPlaylists: ({})
    readonly property string customPlaylistsPath: (Quickshell.env("HOME") || "") + "/.config/dankvideo/playlists.json"

    readonly property var effectivePlaylist: {
        const list = [];
        for (let i = 0; i < root.fileList.length; i++) {
            const p = root.fileList[i];
            const name = p.split("/").pop();
            list.push({ path: p, fileName: name });
        }
        return list;
    }

    function isAlwaysSkipped(path) {
        return skippedAlwaysList.indexOf(path) !== -1;
    }

    function isSkippedOnce(path) {
        return skippedOnceList.indexOf(path) !== -1;
    }

    function toggleSkipAlways(path) {
        const list = skippedAlwaysList.slice();
        const idx = list.indexOf(path);
        if (idx !== -1) list.splice(idx, 1);
        else list.push(path);
        skippedAlwaysList = list;
    }

    function toggleSkipOnce(path) {
        const list = skippedOnceList.slice();
        const idx = list.indexOf(path);
        if (idx !== -1) list.splice(idx, 1);
        else list.push(path);
        skippedOnceList = list;
    }

    function toggleShufflePlaylist() {
        if (!playlistShuffled) {
            playlistOriginalOrder = root.fileList.slice();
            const curr = root.currentFilePath;
            const shuffled = root.fileList.slice();
            for (let i = shuffled.length - 1; i > 0; i--) {
                const j = Math.floor(Math.random() * (i + 1));
                const temp = shuffled[i];
                shuffled[i] = shuffled[j];
                shuffled[j] = temp;
            }
            root.fileList = shuffled;
            root.currentIndex = Math.max(0, shuffled.indexOf(curr));
            playlistShuffled = true;
        } else {
            const curr = root.currentFilePath;
            if (playlistOriginalOrder.length > 0) {
                root.fileList = playlistOriginalOrder.slice();
                root.currentIndex = Math.max(0, root.fileList.indexOf(curr));
            }
            playlistShuffled = false;
        }
    }

    function cycleLoopMode() {
        playlistLoopMode = (playlistLoopMode + 1) % 3;
    }

    function sortPlaylistAlphabetically() {
        const curr = root.currentFilePath;
        const sorted = root.fileList.slice().sort((a, b) => {
            const nameA = a.split("/").pop().toLowerCase();
            const nameB = b.split("/").pop().toLowerCase();
            return nameA.localeCompare(nameB);
        });
        root.fileList = sorted;
        root.currentIndex = Math.max(0, sorted.indexOf(curr));
    }

    function playFromPlaylist(path) {
        const idx = root.fileList.indexOf(path);
        if (idx >= 0) {
            root.currentIndex = idx;
            root.isPlaying = true;
        }
    }

    function createCustomPlaylist(name, filePaths) {
        if (!name) return;
        const pls = Object.assign({}, customPlaylists);
        pls[name] = Array.isArray(filePaths) ? filePaths : [];
        customPlaylists = pls;
        saveCustomPlaylists();
        showToast("Playlist created: " + name);
    }

    function addVideoToPlaylist(name, filePath) {
        if (!name || !filePath) return;
        const pls = Object.assign({}, customPlaylists);
        const list = Array.isArray(pls[name]) ? pls[name].slice() : [];
        if (list.indexOf(filePath) === -1) {
            list.push(filePath);
            pls[name] = list;
            customPlaylists = pls;
            saveCustomPlaylists();
            showToast("Added to " + name);
        }
    }

    function playVideoList(paths, startIndex) {
        if (!Array.isArray(paths) || paths.length === 0) return;
        root.fileList = paths.slice();
        root.currentIndex = Math.max(0, Math.min(paths.length - 1, startIndex || 0));
        root.galleryMode = false;
        root.isPlaying = true;
    }

    function playCustomPlaylist(name) {
        const list = customPlaylists[name];
        if (Array.isArray(list) && list.length > 0) {
            playVideoList(list, 0);
        }
    }

    function saveCustomPlaylists() {
        Quickshell.execDetached([
            "sh", "-c",
            'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"',
            "savePlaylists",
            root.customPlaylistsPath,
            JSON.stringify(root.customPlaylists, null, 2)
        ]);
    }
    
    // Playback state bindings (driven by VideoCanvas / MediaPlayer)
    property bool isPlaying: false
    property real position: 0 // in ms
    property real duration: 0 // in ms
    property real volume: 1.0
    property bool isMuted: false
    property real playbackRate: 1.0

    // Video Gallery State
    property bool galleryMode: currentFilePath === ""
    property var galleryData: null
    property bool isGalleryLoading: false
    property var libraryConfig: ({ addedFolders: [], removedFolders: [] })
    readonly property string libraryConfigPath: (Quickshell.env("HOME") || "") + "/.config/dankvideo/library.json"
    property string searchQuery: ""
    property string selectedCategory: "All"

    readonly property var watchedFolders: {
        const list = [];
        const added = (libraryConfig && Array.isArray(libraryConfig.addedFolders)) ? libraryConfig.addedFolders : [];
        for (let i = 0; i < added.length; i++) {
            if (added[i] && list.indexOf(added[i]) === -1) {
                list.push(added[i]);
            }
        }
        return list;
    }

    readonly property string dplayBin: Quickshell.env("DPLAY_BIN") || "dplay"

    onInspectorOpenChanged: {
        if (inspectorOpen && currentFilePath && (!currentMeta || currentMeta.filePath !== currentFilePath)) {
            fetchMetadata();
        }
    }

    onCurrentFilePathChanged: {
        currentMeta = ({});
        if (inspectorOpen && currentFilePath) {
            fetchMetadata();
        }
    }

    Component.onCompleted: {
        const initVid = Quickshell.env("DPLAY_INITIAL_VIDEO");
        if (initVid) {
            root.fileList = [initVid];
            root.currentIndex = 0;
            root.galleryMode = false;
            loadDirectoryFor(initVid);
        } else {
            root.galleryMode = true;
            loadGallery();
        }
    }

    FileView {
        id: libraryConfigFileView
        path: root.libraryConfigPath
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const text = libraryConfigFileView.text();
                if (text) {
                    const data = JSON.parse(text);
                    if (data && typeof data === "object") {
                        root.libraryConfig = {
                            addedFolders: Array.isArray(data.addedFolders) ? data.addedFolders : [],
                            removedFolders: Array.isArray(data.removedFolders) ? data.removedFolders : []
                        };
                    }
                }
            } catch (e) {
                console.warn("Failed to parse library.json:", e);
            }
            if (root.galleryMode) {
                root.loadGallery();
            }
        }
        onLoadFailed: {
            if (root.galleryMode && !galleryData && !isGalleryLoading) {
                root.loadGallery();
            }
        }
    }

    Process {
        id: saveLibraryProc
        running: false
        command: []
    }

    Timer {
        id: saveLibraryDebounce
        interval: 200
        repeat: false
        onTriggered: {
            if (!saveLibraryProc.running) {
                saveLibraryProc.command = [
                    "sh", "-c",
                    'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"',
                    "saveLibrary",
                    root.libraryConfigPath,
                    JSON.stringify(root.libraryConfig, null, 2)
                ];
                saveLibraryProc.running = true;
            }
        }
    }

    function saveLibraryConfig() {
        saveLibraryDebounce.restart();
    }

    function addWatchedFolder(folderPath) {
        if (!folderPath) return;
        const clean = folderPath.replace(/\/+$/, "");
        const added = (root.libraryConfig.addedFolders || []).slice();
        const removed = (root.libraryConfig.removedFolders || []).slice();

        const remIdx = removed.indexOf(clean);
        if (remIdx !== -1) removed.splice(remIdx, 1);

        if (added.indexOf(clean) === -1) {
            added.push(clean);
        }

        root.libraryConfig = {
            addedFolders: added,
            removedFolders: removed
        };
        saveLibraryConfig();
        showToast("Added folder to video library");
        rescan();
    }

    function removeWatchedFolder(folderPath) {
        if (!folderPath) return;
        const clean = folderPath.replace(/\/+$/, "");
        const added = (root.libraryConfig.addedFolders || []).slice();
        const removed = (root.libraryConfig.removedFolders || []).slice();

        const addIdx = added.indexOf(clean);
        if (addIdx !== -1) added.splice(addIdx, 1);

        if (removed.indexOf(clean) === -1) {
            removed.push(clean);
        }

        root.libraryConfig = {
            addedFolders: added,
            removedFolders: removed
        };
        saveLibraryConfig();
        showToast("Removed folder from library");
        rescan();
    }

    function rescan() {
        loadGallery();
    }

    Process {
        id: galleryProc
        running: false
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                root.isGalleryLoading = false;
                try {
                    const data = JSON.parse(text);
                    if (data) {
                        root.galleryData = data;
                    }
                } catch (e) {
                    console.warn("Failed to parse video gallery JSON:", e);
                }
            }
        }
        onExited: exitCode => {
            root.isGalleryLoading = false;
        }
    }

    function loadGallery() {
        if (galleryProc.running) return;
        root.isGalleryLoading = true;
        const cmd = [dplayBin, "-gallery"];
        const rem = (root.libraryConfig && Array.isArray(root.libraryConfig.removedFolders)) ? root.libraryConfig.removedFolders : [];
        if (rem.length > 0) {
            cmd.push("-exclude=" + rem.join(","));
        }
        const added = (root.libraryConfig && Array.isArray(root.libraryConfig.addedFolders)) ? root.libraryConfig.addedFolders : [];
        if (added.length > 0) {
            cmd.push("");
            for (let i = 0; i < added.length; i++) {
                cmd.push(added[i]);
            }
        }
        galleryProc.command = cmd;
        galleryProc.running = true;
    }

    function openVideoFromGallery(filePath) {
        if (!filePath) return;
        const playAll = SettingsData.libraryOpenBehavior === "all";
        if (playAll && galleryData && galleryData.allVideos) {
            const paths = galleryData.allVideos.map(v => v.path);
            root.fileList = paths;
            const idx = paths.indexOf(filePath);
            root.currentIndex = idx >= 0 ? idx : 0;
        } else {
            root.fileList = [filePath];
            root.currentIndex = 0;
        }
        root.galleryMode = false;
        root.isPlaying = true;
        loadDirectoryFor(filePath);
    }

    function returnToGallery() {
        root.isPlaying = false;
        root.galleryMode = true;
        if (!root.galleryData) {
            root.loadGallery();
        }
    }

    function loadDirectoryFor(filePath) {
        listProc.command = [dplayBin, "-list", filePath];
        listProc.running = true;
    }

    function fetchMetadata() {
        if (!currentFilePath) return;
        infoProc.command = [dplayBin, "-info", currentFilePath];
        infoProc.running = true;
    }

    Process {
        id: listProc
        running: false
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (data && data.files && data.files.length > 0) {
                        const current = root.currentFilePath;
                        const behavior = SettingsData.externalOpenFolderBehavior || "ask";
                        if (behavior === "ask" && data.files.length > 1) {
                            root.pendingFolderPromptPath = current || data.files[0];
                            root.pendingFolderVideoCount = data.files.length;
                            root.pendingFolderAllVideos = data.files;
                            root.isPlaying = false;
                            root.folderPlayPromptOpen = true;
                        } else if (behavior === "single") {
                            root.fileList = current ? [current] : [data.files[0]];
                            root.currentIndex = 0;
                        } else {
                            root.fileList = data.files;
                            let foundIdx = -1;
                            if (current) {
                                foundIdx = data.files.indexOf(current);
                            }
                            if (foundIdx >= 0) {
                                root.currentIndex = foundIdx;
                            } else if (data.currentIndex >= 0 && data.currentIndex < data.files.length) {
                                root.currentIndex = data.currentIndex;
                            } else {
                                root.currentIndex = 0;
                            }
                        }
                    }
                } catch (e) {
                    console.warn("Failed to parse video list JSON:", e);
                }
            }
        }
    }

    Process {
        id: infoProc
        running: false
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (data) {
                        root.currentMeta = data;
                    }
                } catch (e) {
                    console.warn("Failed to parse metadata JSON:", e);
                }
            }
        }
    }

    signal openFileDialogRequested()
    signal openAddFolderDialogRequested()

    function openAddFolderDialog() {
        openAddFolderDialogRequested();
    }

    Process {
        id: trashProc
        running: false
        command: []
        onExited: exitCode => {
            if (exitCode === 0) {
                root.showToast("Moved video to trash (U to undo)");
                removeCurrentFromList();
            } else {
                root.showToast("Failed to move video to trash", true);
            }
        }
    }

    Process {
        id: restoreProc
        running: false
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                const restoredPath = text.trim();
                if (restoredPath.length > 0) {
                    root.showToast("Restored video: " + restoredPath.split("/").pop());
                    root.loadDirectoryFor(restoredPath);
                } else {
                    root.showToast("No video to restore", true);
                }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.showToast("Failed to restore video", true);
            }
        }
    }

    Process {
        id: copyPathProc
        running: false
        command: []
        onExited: exitCode => {
            if (exitCode === 0) {
                root.showToast("File path copied to clipboard");
            } else {
                root.showToast("Failed to copy path", true);
            }
        }
    }

    function openFileDialog() {
        openFileDialogRequested();
    }

    function toggleLockUI() {
        uiLocked = !uiLocked;
        if (uiLocked) {
            inspectorOpen = false;
        }
    }

    function nextVideo() {
        if (fileList.length <= 1) return;
        let nextIdx = (currentIndex + 1) % fileList.length;
        // Check if next video is skipped
        let attempts = 0;
        while (attempts < fileList.length) {
            const nextPath = fileList[nextIdx];
            if (isAlwaysSkipped(nextPath)) {
                nextIdx = (nextIdx + 1) % fileList.length;
                attempts++;
                continue;
            }
            if (isSkippedOnce(nextPath)) {
                // remove from skippedOnce and advance
                toggleSkipOnce(nextPath);
                nextIdx = (nextIdx + 1) % fileList.length;
                attempts++;
                continue;
            }
            break;
        }
        currentIndex = nextIdx;
    }

    function prevVideo() {
        if (fileList.length <= 1) return;
        let prevIdx = (currentIndex - 1 + fileList.length) % fileList.length;
        let attempts = 0;
        while (attempts < fileList.length) {
            const prevPath = fileList[prevIdx];
            if (isAlwaysSkipped(prevPath)) {
                prevIdx = (prevIdx - 1 + fileList.length) % fileList.length;
                attempts++;
                continue;
            }
            break;
        }
        currentIndex = prevIdx;
    }

    function confirmFolderPlay(playAll) {
        folderPlayPromptOpen = false;
        if (playAll && pendingFolderAllVideos.length > 0) {
            fileList = pendingFolderAllVideos.slice();
            const idx = fileList.indexOf(pendingFolderPromptPath);
            currentIndex = idx >= 0 ? idx : 0;
        } else if (pendingFolderPromptPath) {
            fileList = [pendingFolderPromptPath];
            currentIndex = 0;
        }
        galleryMode = false;
        isPlaying = true;
    }

    function togglePlay() {
        isPlaying = !isPlaying;
    }

    function toggleMute() {
        isMuted = !isMuted;
    }

    function setVolume(v) {
        volume = Math.max(0.0, Math.min(1.0, v));
        if (volume > 0 && isMuted) {
            isMuted = false;
        }
    }

    function seekRelative(deltaMs) {
        const target = Math.max(0, Math.min(duration, position + deltaMs));
        position = target;
    }

    function toggleInspector() {
        inspectorOpen = !inspectorOpen;
    }

    function toggleFullscreen() {
        isFullscreen = !isFullscreen;
    }

    function copyPathToClipboard() {
        if (!currentFilePath) return;
        copyPathProc.command = ["dms", "cl", "copy", currentFilePath];
        copyPathProc.running = true;
    }

    function openContainingFolder() {
        if (!currentFilePath) return;
        const dir = currentMeta.directory || currentFilePath.substring(0, currentFilePath.lastIndexOf("/"));
        Quickshell.execDetached(["xdg-open", dir]);
    }

    function showToast(message, isError) {
        const method = isError ? "error" : "info";
        Quickshell.execDetached([
            "dms", "ipc", "call", "toast", method, message
        ]);
    }

    function moveToTrash() {
        if (!currentFilePath) return;
        lastTrashedPath = currentFilePath;
        trashProc.command = ["gio", "trash", currentFilePath];
        trashProc.running = true;
    }

    function undoTrash() {
        restoreProc.command = lastTrashedPath ? [dplayBin, "-restore", lastTrashedPath] : [dplayBin, "-restore"];
        restoreProc.running = true;
    }

    function removeCurrentFromList() {
        const list = root.fileList.slice();
        list.splice(root.currentIndex, 1);
        root.fileList = list;
        if (root.currentIndex >= list.length) {
            root.currentIndex = Math.max(0, list.length - 1);
        }
    }

    function formatTime(ms) {
        if (isNaN(ms) || ms < 0) return "0:00";
        const totalSecs = Math.floor(ms / 1000);
        const hours = Math.floor(totalSecs / 3600);
        const minutes = Math.floor((totalSecs % 3600) / 60);
        const seconds = totalSecs % 60;

        const secStr = seconds < 10 ? "0" + seconds : "" + seconds;
        if (hours > 0) {
            const minStr = minutes < 10 ? "0" + minutes : "" + minutes;
            return hours + ":" + minStr + ":" + secStr;
        }
        return minutes + ":" + secStr;
    }
}
