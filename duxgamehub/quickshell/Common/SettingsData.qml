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
        return base + "/dankcalc";
    }
    readonly property string settingsPath: configDir + "/ui-settings.json"

    // Theme configuration
    property alias themeMode: adapter.themeMode
    property alias colorSource: adapter.colorSource
    property alias presetTheme: adapter.presetTheme
    property alias customThemeFile: adapter.customThemeFile
    property alias radiusStrength: adapter.radiusStrength
    property alias animationDuration: adapter.animationDuration
    property alias reduceMotion: adapter.reduceMotion
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
    property alias sidebarStyle: adapter.sidebarStyle
    property alias sidebarFloating: adapter.sidebarFloating
    property alias sidebarAutoHideMs: adapter.sidebarAutoHideMs

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
        "focusRingEnabled", "focusRingWidth", "focusRingColor", "sidebarCentered", "sidebarStyle", "sidebarFloating", "sidebarAutoHideMs"
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

    // Calculator preferences
    property alias scientificExpanded: adapter.scientificExpanded
    property alias angleUnitRad: adapter.angleUnitRad

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
            property string sidebarStyle: "beside"
            property bool sidebarFloating: false
            property int sidebarAutoHideMs: 1500
            property bool scientificExpanded: false
            property bool angleUnitRad: true
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
            property string sidebarStyle: "beside"
            property bool sidebarFloating: false
            property int sidebarAutoHideMs: 1500
        }
    }
}
