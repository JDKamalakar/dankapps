pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    enum AnimationSpeed {
        None,
        Short,
        Medium,
        Long,
        Custom
    }

    enum TextRenderType {
        Qt,
        Native,
        Curve
    }

    enum TextRenderQuality {
        Default,
        Low,
        Normal,
        High,
        VeryHigh
    }

    property bool popoutElevationEnabled: true
    property int textRenderType: SettingsData.TextRenderType.Qt
    property int textRenderQuality: SettingsData.TextRenderQuality.Default

    readonly property string configDir: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME");
        const base = (xdg && xdg !== "") ? xdg : Quickshell.env("HOME") + "/.config";
        return base + "/dankview";
    }
    readonly property string settingsPath: configDir + "/ui-settings.json"

    // Theme configuration
    property alias themeMode: adapter.themeMode
    property alias colorSource: adapter.colorSource
    property alias presetTheme: adapter.presetTheme
    property alias customThemeFile: adapter.customThemeFile
    // 0 (square) … 100; 50 keeps the Material shape scale
    property alias radiusStrength: adapter.radiusStrength
    // base transition length in ms, 0 disables animations
    property alias animationDuration: adapter.animationDuration
    property alias reduceMotion: adapter.reduceMotion
    // 0 smooth, 1 balanced, 2 playful
    property alias springBounce: adapter.springBounce
    property alias enableRippleEffects: adapter.enableRippleEffects
    property alias density: adapter.density
    property alias motionDuration: adapter.motionDuration
    property alias fontSource: adapter.fontSource
    property alias fontFamily: adapter.fontFamily
    property alias monoFontFamily: adapter.monoFontFamily
    property alias displayFontFamily: adapter.displayFontFamily
    property alias windowTitleBars: adapter.windowTitleBars
    property alias floatingWindowTransparency: adapter.floatingWindowTransparency
    property alias floatingWindowForegroundLayers: adapter.floatingWindowForegroundLayers
    property alias floatingWindowForegroundTransparency: adapter.floatingWindowForegroundTransparency
    property alias blurEnabled: adapter.blurEnabled
    property alias settingsItemSeparation: adapter.settingsItemSeparation

    property alias fontWeight: adapter.fontWeight
    property alias fontScale: adapter.fontScale
    property alias focusRingEnabled: adapter.focusRingEnabled
    property alias focusRingWidth: adapter.focusRingWidth
    property alias focusRingColor: adapter.focusRingColor
    property alias sidebarCentered: adapter.sidebarCentered

    readonly property string sharedConfigDir: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME");
        const base = (xdg && xdg !== "") ? xdg : Quickshell.env("HOME") + "/.config";
        return base + "/DUX_Apps-JDK";
    }
    readonly property string sharedSettingsPath: sharedConfigDir + "/shared-appearance.json"
    property bool _syncingShared: false
    property string activeSettingsSearch: ""

    readonly property var _sharedKeys: [
        "themeMode", "colorSource", "presetTheme", "customThemeFile",
        "radiusStrength", "animationDuration", "reduceMotion", "springBounce",
        "enableRippleEffects", "density", "motionDuration", "fontSource",
        "fontFamily", "monoFontFamily", "displayFontFamily", "windowTitleBars",
        "floatingWindowTransparency", "floatingWindowForegroundLayers",
        "floatingWindowForegroundTransparency", "blurEnabled",
        "settingsItemSeparation", "fontWeight", "fontScale",
        "focusRingEnabled", "focusRingWidth", "focusRingColor", "sidebarCentered"
    ]

    function _applySharedToLocal() {
        if (!sharedFile._loaded) return;
        _syncingShared = true;
        for (let i = 0; i < _sharedKeys.length; i++) {
            const k = _sharedKeys[i];
            if (sharedAdapter[k] !== undefined && adapter[k] !== sharedAdapter[k]) {
                adapter[k] = sharedAdapter[k];
            }
        }
        _syncingShared = false;
    }

    function _pushLocalToShared() {
        if (_syncingShared || !settingsFile._loaded || !sharedFile._loaded) return;
        let changed = false;
        _syncingShared = true;
        for (let i = 0; i < _sharedKeys.length; i++) {
            const k = _sharedKeys[i];
            if (adapter[k] !== undefined && sharedAdapter[k] !== adapter[k]) {
                sharedAdapter[k] = adapter[k];
                changed = true;
            }
        }
        _syncingShared = false;
        if (changed) {
            sharedFile._selfWrite = true;
            sharedFile.writeAdapter();
        }
    }

    // Viewer preferences
    property alias autoHideControls: adapter.autoHideControls
    property alias showCheckerboard: adapter.showCheckerboard

    // Gallery preferences
    property alias galleryLandingPage: adapter.galleryLandingPage
    property alias galleryCropThumbnails: adapter.galleryCropThumbnails
    property alias galleryItemSize: adapter.galleryItemSize
    property alias galleryGridItemSize: adapter.galleryItemSize
    property alias galleryScanVideos: adapter.galleryScanVideos
    property alias filterIncludeHidden: adapter.filterIncludeHidden
    property alias showQuickAccessInSidebar: adapter.showQuickAccessInSidebar
    property string galleryThumbnailLayout: {
        const layout = adapter.galleryThumbnailLayout;
        if (layout === "crop" || layout === "fit" || layout === "masonry" || layout === "dynamic")
            return layout === "dynamic" ? "masonry" : layout;
        // Default to masonry (dynamic) if unset
        return "masonry";
    }

    function setGalleryThumbnailLayout(layout) {
        if (layout !== "crop" && layout !== "fit" && layout !== "masonry" && layout !== "dynamic" && layout !== "square")
            return;
        const normalized = (layout === "dynamic" || layout === "masonry") ? "masonry" : (layout === "square" ? "crop" : layout);
        adapter.galleryThumbnailLayout = normalized;
        adapter.galleryCropThumbnails = normalized === "crop";
    }

    Component.onCompleted: {
        Paths.mkdir(configDir);
        Paths.mkdir(sharedConfigDir);
    }

    FileView {
        id: settingsFile
        path: root.settingsPath
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        watchChanges: true
        printErrors: false

        property bool _loaded: false
        property bool _selfWrite: false

        onLoaded: _loaded = true
        onLoadFailed: _loaded = true
        onFileChanged: {
            if (_selfWrite) {
                _selfWrite = false;
                return;
            }
            reload();
        }
        onAdapterUpdated: {
            if (!_loaded)
                return;
            _selfWrite = true;
            writeAdapter();
            root._pushLocalToShared();
        }

        JsonAdapter {
            id: adapter
            property string themeMode: "auto"
            property string colorSource: "auto"
            property string presetTheme: "blue"
            property string customThemeFile: ""
            property int radiusStrength: 50
            property int animationDuration: 250
            property bool reduceMotion: false
            property int springBounce: 1
            property bool enableRippleEffects: true
    property string density: 'comfortable'
    property int motionDuration: 2
    property string fontSource: 'auto'
    property string fontFamily: ''
    property string monoFontFamily: ''
    property string displayFontFamily: ''
    property bool windowTitleBars: true
    property real floatingWindowTransparency: 1.0
    property bool floatingWindowForegroundLayers: true
    property real floatingWindowForegroundTransparency: 1.0
    property bool blurEnabled: false
    property bool settingsItemSeparation: true

            property int fontWeight: 400
            property real fontScale: 1.0
            property bool focusRingEnabled: true
            property real focusRingWidth: 1.5
            property string focusRingColor: "primary"
            property bool sidebarCentered: false
            property bool autoHideControls: true
            property bool showCheckerboard: true
            property string galleryLandingPage: "gallery"
            property bool galleryCropThumbnails: true
            property string galleryThumbnailLayout: ""
            property int galleryItemSize: 160
            property bool galleryScanVideos: false
            property bool filterIncludeHidden: false
            property bool showQuickAccessInSidebar: true
        }
    }

    FileView {
        id: sharedFile
        path: root.sharedSettingsPath
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        watchChanges: true
        printErrors: false

        property bool _loaded: false
        property bool _selfWrite: false

        onLoaded: {
            _loaded = true;
            root._applySharedToLocal();
        }
        onLoadFailed: {
            _loaded = true;
            root._pushLocalToShared();
        }
        onFileChanged: {
            if (_selfWrite) {
                _selfWrite = false;
                return;
            }
            reload();
        }

        JsonAdapter {
            id: sharedAdapter
            property string themeMode: "auto"
            property string colorSource: "auto"
            property string presetTheme: "blue"
            property string customThemeFile: ""
            property int radiusStrength: 50
            property int animationDuration: 250
            property bool reduceMotion: false
            property int springBounce: 1
            property bool enableRippleEffects: true
            property string density: "comfortable"
            property int motionDuration: 2
            property string fontSource: "auto"
            property string fontFamily: ""
            property string monoFontFamily: ""
            property string displayFontFamily: ""
            property bool windowTitleBars: true
            property real floatingWindowTransparency: 1.0
            property bool floatingWindowForegroundLayers: true
            property real floatingWindowForegroundTransparency: 1.0
            property bool blurEnabled: false
            property bool settingsItemSeparation: true
            property int fontWeight: 400
            property real fontScale: 1.0
            property bool focusRingEnabled: true
            property real focusRingWidth: 1.5
            property string focusRingColor: "primary"
            property bool sidebarCentered: false
        }
    }
}
