import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Services

PluginSettings {
    id: root
    pluginId: "fullscreenGameHub"
    pluginService: typeof PluginService !== "undefined" ? PluginService : null

    implicitHeight: (typeof rootWrapper !== "undefined" && rootWrapper && rootWrapper.implicitHeight > 0) ? rootWrapper.implicitHeight : 800

    readonly property real outerR: (typeof Theme !== "undefined" && Theme.groupedListOuterRadius) ? Theme.groupedListOuterRadius : ((typeof Theme !== "undefined" && Theme.cornerRadius) ? Theme.cornerRadius : 14)
    readonly property real innerR: (typeof Theme !== "undefined" && Theme.groupedListInnerRadius) ? Theme.groupedListInnerRadius : 4

    property bool hideIpcCommands: false
    property int activeSectionIndex: -1 // -1 means show all (e.g. in standalone plugin settings), or 0..6 to show specific tab
    property string searchQuery: ""

    function loadValue(key, def) {
        if (typeof PluginService !== "undefined" && PluginService && PluginService.loadPluginData) {
            return PluginService.loadPluginData(root.pluginId, key, def);
        }
        return def;
    }

    function saveValue(key, val) {
        if (typeof PluginService !== "undefined" && PluginService && PluginService.savePluginData) {
            PluginService.savePluginData(root.pluginId, key, val);
            if (PluginService.setGlobalVar) {
                PluginService.setGlobalVar(root.pluginId, key, val);
            }
        }
    }

    property string pluginDir: {
        if (typeof PluginService !== "undefined" && PluginService && PluginService.getPluginPath) {
            let p = PluginService.getPluginPath(root.pluginId);
            if (p) return p;
        }
        let urlStr = Qt.resolvedUrl(".").toString();
        if (urlStr.startsWith("file://")) urlStr = urlStr.substring(7);
        if (urlStr.endsWith("/")) urlStr = urlStr.substring(0, urlStr.length - 1);
        return urlStr || "/home/JD/Downloads/Projects/DMS-Fullscreen_Game_Hub";
    }

    Process {
        id: settingsCmdProcess
    }

    function runShellCommand(cmd) {
        settingsCmdProcess.command = ["bash", "-c", cmd];
        settingsCmdProcess.running = true;
    }

    function toggleDesktopShortcut(enable) {
        let script = `
import os
home = os.path.expanduser("~")
apps_dir = os.path.join(home, ".local/share/applications")
desktop_path = os.path.join(apps_dir, "dms-gamehub.desktop")
if ${enable ? "True" : "False"}:
    os.makedirs(apps_dir, exist_ok=True)
    content = """[Desktop Entry]
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
    with open(desktop_path, "w") as f:
        f.write(content)
else:
    if os.path.exists(desktop_path):
        os.remove(desktop_path)
`;
        settingsCmdProcess.command = ["python3", "-c", script];
        settingsCmdProcess.running = true;
    }

    function toggleNiriRules(enable) {
        let openOnGames = root.loadValue("openOnWorkspaceGames", false);
        let script = `
import os
home = os.path.expanduser("~")
dms_dir = os.path.join(home, ".config/niri/dms")
rule_file = os.path.join(dms_dir, "gamehub.kdl")
niri_cfg = os.path.join(home, ".config/niri/config.kdl")
if ` + (enable ? "True" : "False") + `:
    os.makedirs(dms_dir, exist_ok=True)
    ws_line = '        open-on-workspace "Games"\\n' if ` + (openOnGames ? "True" : "False") + ` else ''
    rule_content = f"""// DMS Fullscreen Game Hub - Sizing & Workspace Rules
window-rule {{
        match title="^Game Hub.*"
        open-floating false
{ws_line}        default-column-width {{ proportion 1.0; }}
        default-window-height {{ proportion 1.0; }}
}}
"""
    with open(rule_file, "w") as f:
        f.write(rule_content)
    if os.path.exists(niri_cfg):
        try:
            cfg = open(niri_cfg, "r", errors="ignore").read()
            if 'include "dms/gamehub.kdl"' not in cfg:
                with open(niri_cfg, "a") as f:
                    f.write('\ninclude "dms/gamehub.kdl"\n')
        except: pass
else:
    if os.path.exists(rule_file):
        os.remove(rule_file)
`;
        settingsCmdProcess.command = ["python3", "-c", script];
        settingsCmdProcess.running = true;
    }

    Connections {
        target: PluginService
        ignoreUnknownSignals: true
        function onPluginDataChanged(pId) {
            if (pId === root.pluginId) {
                if (typeof rootWrapper !== "undefined" && rootWrapper && rootWrapper.loadValue) rootWrapper.loadValue();
            }
        }
        function onGlobalVarChanged(pId, varName) {
            if (pId === root.pluginId) {
                if (typeof rootWrapper !== "undefined" && rootWrapper && rootWrapper.loadValue) rootWrapper.loadValue();
            }
        }
    }

    // -------------------------------------------------------------------------
    // REUSABLE COMPONENTS
    // -------------------------------------------------------------------------

    component SectionHeader: Item {
        property string title: ""
        property string iconName: ""
        width: parent.width
        height: headerRow.implicitHeight + 2

        Row {
            id: headerRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS
            leftPadding: Theme.spacingS

            // Accent badge pill
            Rectangle {
                width: 3
                height: 16
                radius: 2
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            DIcon {
                name: iconName
                size: 15
                color: Theme.primary
                opacity: 0.85
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: title
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.primary
                opacity: 0.85
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // Container card that wraps a settings group with a header inside (DUX style)
    component SettingsSection: Rectangle {
        id: sectionCard
        width: parent.width
        implicitHeight: sectionCol.implicitHeight
        color: (typeof Theme !== "undefined" && Theme.foregroundColor && Theme.cardSurface)
            ? Theme.foregroundColor(Theme.cardSurface, true)
            : Theme.withAlpha(Theme.surfaceContainer, 0.45)
        radius: (typeof Theme !== "undefined" && Theme.groupedListOuterRadius) ? Theme.groupedListOuterRadius : root.outerR
        border.width: (typeof Theme !== "undefined" && Theme.layerOutlineWidth) ? Theme.layerOutlineWidth : 1
        border.color: (typeof Theme !== "undefined" && Theme.outlineMedium)
            ? Theme.outlineMedium
            : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)

        property string sectionTitle: ""
        property string sectionIcon: ""
        property alias content: contentSlot.data

        Column {
            id: sectionCol
            width: parent.width

            // Header band inside the card
            Item {
                width: parent.width
                height: sectionHeaderRow.implicitHeight + Theme.spacingS * 2

                // Separator removed per user request

                Row {
                    id: sectionHeaderRow
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    spacing: Theme.spacingS

                    Rectangle {
                        width: 3
                        height: 14
                        radius: 2
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DIcon {
                        name: sectionCard.sectionIcon
                        size: 14
                        color: Theme.primary
                        opacity: 0.8
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: sectionCard.sectionTitle
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: Theme.primary
                        opacity: 0.8
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Item {
                id: contentSlot
                width: parent.width
                implicitHeight: childrenRect.height
                clip: true
            }
        }
    }

    component SettingsToggleItem: Rectangle {
        id: toggleCard
        width: parent.width
        height: 56
        color: (typeof Theme !== "undefined" && Theme.foregroundColor && Theme.cardSurface) ? Theme.foregroundColor(Theme.cardSurface, true) : Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
        border.width: 1
        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

        property string iconName: ""
        property string title: ""
        property string description: ""
        property string settingKey: ""
        property bool defaultValue: false

        property bool isFirst: false
        property bool isLast: false
        property bool isSingle: false

        property alias checked: toggle.checked

        topLeftRadius: (isFirst || isSingle) ? root.outerR : root.innerR
        topRightRadius: (isFirst || isSingle) ? root.outerR : root.innerR
        bottomLeftRadius: (isLast || isSingle) ? root.outerR : root.innerR
        bottomRightRadius: (isLast || isSingle) ? root.outerR : root.innerR

        function loadValue() {
            if (root) {
                var loaded = root.loadValue(settingKey, defaultValue);
                checked = loaded === true || loaded === "true";
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            spacing: Theme.spacingM

            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: toggle.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: 150 } }

                DIcon {
                    name: toggleCard.iconName
                    size: 18
                    color: toggle.checked ? Theme.primary : Theme.surfaceVariantText
                    anchors.centerIn: parent
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                StyledText {
                    text: toggleCard.title
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }
                StyledText {
                    text: toggleCard.description
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            DToggle {
                id: toggle
                Layout.alignment: Qt.AlignVCenter
                Component.onCompleted: toggleCard.loadValue()
                onToggled: function (newChecked) {
                    root.saveValue(toggleCard.settingKey, newChecked);
                }
            }
        }
    }

    component SettingsSliderItem: Rectangle {
        id: sliderCard
        width: parent.width
        implicitHeight: sliderInnerCol.implicitHeight + Theme.spacingM * 2
        color: (typeof Theme !== "undefined" && Theme.foregroundColor && Theme.cardSurface) ? Theme.foregroundColor(Theme.cardSurface, true) : Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
        border.width: 1
        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

        property string iconName: ""
        property string title: ""
        property string description: ""
        property string settingKey: ""
        property int defaultValue: 0
        property int minimumValue: 0
        property int maximumValue: 100
        property string unit: "s"
        property bool sliderEnabled: true

        property bool isFirst: false
        property bool isLast: false
        property bool isSingle: false

        topLeftRadius: (isFirst || isSingle) ? root.outerR : root.innerR
        topRightRadius: (isFirst || isSingle) ? root.outerR : root.innerR
        bottomLeftRadius: (isLast || isSingle) ? root.outerR : root.innerR
        bottomRightRadius: (isLast || isSingle) ? root.outerR : root.innerR

        function loadValue() {
            slider.loadValue();
        }

        Column {
            id: sliderInnerCol
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            RowLayout {
                width: parent.width
                spacing: Theme.spacingM

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    Layout.alignment: Qt.AlignVCenter

                    DIcon {
                        name: sliderCard.iconName
                        size: 18
                        color: Theme.primary
                        anchors.centerIn: parent
                    }
                }

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2
                    StyledText {
                        text: sliderCard.title
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                    StyledText {
                        text: sliderCard.description
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: resetBtn
                    width: 32
                    height: 32
                    radius: 16
                    Layout.alignment: Qt.AlignVCenter
                    color: resetMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04)
                    border.color: resetMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                    border.width: 1
                    opacity: (slider.value !== sliderCard.defaultValue && sliderCard.sliderEnabled) ? (resetMa.containsMouse ? 1.0 : 0.9) : 0.0
                    visible: opacity > 0
                    scale: resetMa.pressed ? 0.9 : (resetMa.containsMouse ? 1.05 : 1.0)

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                    DRipple {
                        id: resetRip
                        anchors.fill: parent
                        cornerRadius: parent.radius
                        rippleColor: Theme.primary
                    }

                    DIcon {
                        id: resetIcon
                        name: "restart_alt"
                        size: 16
                        anchors.centerIn: parent
                        color: resetMa.containsMouse ? Theme.primary : Theme.surfaceVariantText
                        SequentialAnimation on rotation {
                            running: resetMa.containsMouse; loops: Animation.Infinite
                            NumberAnimation { to: 8; duration: 75 }
                            NumberAnimation { to: -8; duration: 150 }
                            NumberAnimation { to: 0; duration: 75 }
                            onRunningChanged: { if (!running) resetIcon.rotation = 0; }
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: resetMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: slider.value !== sliderCard.defaultValue && sliderCard.sliderEnabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            resetAnim.restart();
                            root.saveValue(sliderCard.settingKey, sliderCard.defaultValue);
                        }
                        onPressed: (m) => resetRip.trigger(m.x, m.y)
                    }
                }

                NumberAnimation {
                    id: resetAnim
                    target: slider
                    property: "value"
                    to: sliderCard.defaultValue
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            RowLayout {
                width: parent.width
                spacing: Theme.spacingM

                DSlider {
                    id: slider
                    property string settingKey: sliderCard.settingKey
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    minimum: sliderCard.minimumValue
                    maximum: sliderCard.maximumValue
                    step: 1
                    unit: sliderCard.unit
                    wheelEnabled: false
                    enabled: sliderCard.sliderEnabled
                    focus: false
                    activeFocusOnTab: false
                    Keys.enabled: false
                    function loadValue() {
                        if (root)
                            value = root.loadValue(settingKey, sliderCard.defaultValue);
                    }
                    Component.onCompleted: loadValue()
                    onSliderValueChanged: newValue => {
                        value = newValue;
                        root.saveValue(settingKey, newValue);
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: (wheel) => { wheel.accepted = true; }
                    }
                }
            }
        }
    }

    component SettingsInputFieldItem: Rectangle {
        id: fieldCard
        width: parent.width
        implicitHeight: fieldCol.implicitHeight + Theme.spacingM * 2
        color: (typeof Theme !== "undefined" && Theme.foregroundColor && Theme.cardSurface) ? Theme.foregroundColor(Theme.cardSurface, true) : Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
        border.width: 1
        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

        property string iconName: ""
        property string title: ""
        property string description: ""
        property string settingKey: ""
        property string defaultValue: ""
        property string placeholderText: ""
        property bool isPassword: false

        property bool isFirst: false
        property bool isLast: false
        property bool isSingle: false

        topLeftRadius: (isFirst || isSingle) ? root.outerR : root.innerR
        topRightRadius: (isFirst || isSingle) ? root.outerR : root.innerR
        bottomLeftRadius: (isLast || isSingle) ? root.outerR : root.innerR
        bottomRightRadius: (isLast || isSingle) ? root.outerR : root.innerR

        function loadValue() {
            textField.loadValue();
        }

        Column {
            id: fieldCol
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            RowLayout {
                width: parent.width
                spacing: Theme.spacingM

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    Layout.alignment: Qt.AlignVCenter

                    DIcon {
                        name: fieldCard.iconName
                        size: 18
                        color: Theme.primary
                        anchors.centerIn: parent
                    }
                }

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2
                    StyledText {
                        text: fieldCard.title
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                    StyledText {
                        text: fieldCard.description
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }

            DTextField {
                id: textField
                property string settingKey: fieldCard.settingKey
                width: parent.width
                placeholderText: fieldCard.placeholderText
                echoMode: fieldCard.isPassword ? TextInput.Password : TextInput.Normal
                text: fieldCard.defaultValue
                function loadValue() {
                    if (root)
                        text = root.loadValue(settingKey, fieldCard.defaultValue);
                }
                Component.onCompleted: loadValue()
                onEditingFinished: root.saveValue(settingKey, text)
            }
        }
    }

    component SettingsDropdownItem: Rectangle {
        id: dropCard
        width: parent.width
        implicitHeight: dropCol.implicitHeight + Theme.spacingM * 2
        color: (typeof Theme !== "undefined" && Theme.foregroundColor && Theme.cardSurface) ? Theme.foregroundColor(Theme.cardSurface, true) : Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
        border.width: 1
        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

        property string iconName: ""
        property string title: ""
        property string description: ""
        property string settingKey: ""
        property string defaultValue: ""
        property var optionList: [] // [{label: "", value: ""}]

        property bool isFirst: false
        property bool isLast: false
        property bool isSingle: false

        topLeftRadius: (isFirst || isSingle) ? root.outerR : root.innerR
        topRightRadius: (isFirst || isSingle) ? root.outerR : root.innerR
        bottomLeftRadius: (isLast || isSingle) ? root.outerR : root.innerR
        bottomRightRadius: (isLast || isSingle) ? root.outerR : root.innerR

        function loadValue() {
            dropdown.loadValue();
        }

        Column {
            id: dropCol
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingM

            RowLayout {
                width: parent.width
                spacing: Theme.spacingM

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    Layout.alignment: Qt.AlignVCenter

                    DIcon {
                        name: dropCard.iconName
                        size: 18
                        color: Theme.primary
                        anchors.centerIn: parent
                    }
                }

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2
                    StyledText {
                        text: dropCard.title
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                    StyledText {
                        text: dropCard.description
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }

            DDropdown {
                id: dropdown
                width: parent.width

                property string settingKey: dropCard.settingKey
                property string defaultValue: dropCard.defaultValue

                options: {
                    var arr = [];
                    for (var i = 0; i < dropCard.optionList.length; i++) {
                        arr.push(dropCard.optionList[i].label);
                    }
                    return arr;
                }

                function loadValue() {
                    if (root) {
                        var loadedVal = root.loadValue(settingKey, defaultValue);
                        for (var i = 0; i < dropCard.optionList.length; i++) {
                            if (dropCard.optionList[i].value === loadedVal) {
                                currentValue = dropCard.optionList[i].label;
                                break;
                            }
                        }
                    }
                }

                Component.onCompleted: loadValue()

                onValueChanged: newValue => {
                    for (var i = 0; i < dropCard.optionList.length; i++) {
                        if (dropCard.optionList[i].label === newValue) {
                            root.saveValue(settingKey, dropCard.optionList[i].value);
                            break;
                        }
                    }
                }
            }
        }
    }
    component SettingsSegmentItem: Rectangle {
        id: segCard
        width: parent.width
        height: 72
        color: (typeof Theme !== "undefined" && Theme.foregroundColor && Theme.cardSurface) ? Theme.foregroundColor(Theme.cardSurface, true) : Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
        border.width: 1
        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

        property string iconName: ""
        property string title: ""
        property string description: ""
        property string settingKey: ""
        property string defaultValue: ""
        property var segOptions: [] // [{label: "", value: "", icon: ""}]

        property bool isFirst: false
        property bool isLast: false
        property bool isSingle: false

        property string currentValue: defaultValue

        topLeftRadius: (isFirst || isSingle) ? root.outerR : root.innerR
        topRightRadius: (isFirst || isSingle) ? root.outerR : root.innerR
        bottomLeftRadius: (isLast || isSingle) ? root.outerR : root.innerR
        bottomRightRadius: (isLast || isSingle) ? root.outerR : root.innerR

        function loadValue() {
            if (root) {
                segCard.currentValue = root.loadValue(settingKey, defaultValue);
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            spacing: Theme.spacingM

            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                Layout.alignment: Qt.AlignVCenter

                DIcon {
                    name: segCard.iconName
                    size: 18
                    color: Theme.primary
                    anchors.centerIn: parent
                }
            }

            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 6

                StyledText {
                    text: segCard.title
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                // Segmented pill row
                RowLayout {
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: segCard.segOptions

                        delegate: Rectangle {
                            id: segBtn
                            Layout.fillWidth: true
                            height: 26

                            readonly property bool isSelected: segCard.currentValue === modelData.value
                            readonly property bool isSegFirst: index === 0
                            readonly property bool isSegLast: index === segCard.segOptions.length - 1

                            topLeftRadius:    isSegFirst  ? (root.innerR + 2) : 2
                            bottomLeftRadius: isSegFirst  ? (root.innerR + 2) : 2
                            topRightRadius:   isSegLast   ? (root.innerR + 2) : 2
                            bottomRightRadius:isSegLast   ? (root.innerR + 2) : 2

                            color: isSelected
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                                : (segBtnMA.containsMouse
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                    : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.4))

                            border.width: isSelected ? 1 : 0
                            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, isSelected ? 0.55 : 0)

                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4

                                DIcon {
                                    name: modelData.icon || ""
                                    size: 13
                                    color: segBtn.isSelected ? Theme.primary : Theme.surfaceVariantText
                                    visible: (modelData.icon || "") !== ""
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                StyledText {
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    font.weight: segBtn.isSelected ? Font.DemiBold : Font.Normal
                                    color: segBtn.isSelected ? Theme.primary : Theme.surfaceVariantText
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                            }

                            MouseArea {
                                id: segBtnMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    segCard.currentValue = modelData.value;
                                    root.saveValue(segCard.settingKey, modelData.value);
                                }
                            }
                        }
                    }
                }
            }
        }

        Component.onCompleted: loadValue()
    }

    Column {
        id: rootWrapper
        width: parent.width
        spacing: Theme.spacingL

        function loadValue() {
            var groups = [scannerGroup, steamApiGroup, gridGroup, appearanceGroup, behaviorGroup, metadataGroup];
            for (var g = 0; g < groups.length; g++) {
                var group = groups[g];
                for (var i = 0; i < group.children.length; i++) {
                    var item = group.children[i];
                    if (item && item.loadValue)
                        item.loadValue();
                }
            }
        }

        // ---------------------------------------------------------------------
        // 1. GAME SCANNERS & SOURCES
        // ---------------------------------------------------------------------
        Rectangle {
            id: sec1Card
            width: parent.width
            implicitHeight: sec1Col.implicitHeight
            visible: (root.activeSectionIndex === -1 || root.activeSectionIndex === 0) && (root.searchQuery === "" || "game scanners sources steam lutris heroic bottles".indexOf(root.searchQuery.toLowerCase()) !== -1)
            height: visible ? implicitHeight : 0
            color: Theme.withAlpha(Theme.surfaceContainer, 0.3)
            radius: root.outerR
            border.width: 1
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
            clip: true

            Column {
                id: sec1Col
                width: parent.width

                // Section header band
                Item {
                    width: parent.width
                    height: sec1HeaderRow.implicitHeight + Theme.spacingS * 2
                    // Separator line removed
                    Row {
                        id: sec1HeaderRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: Theme.spacingM
                        spacing: Theme.spacingS
                        Rectangle { width: 3; height: 14; radius: 2; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        DIcon { name: "sports_esports"; size: 14; color: Theme.primary; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Game Scanners & Sources"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.DemiBold; color: Theme.primary; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                Column {
                    id: scannerGroup
                    width: parent.width
                    spacing: 1

                    SettingsToggleItem {
                        iconName: "sports_esports"
                        title: "Steam Games Scanner"
                        description: "Scan Steam appmanifests and local library folders"
                        settingKey: "scanSteam"
                        defaultValue: true
                        isFirst: true
                        topLeftRadius: 0; topRightRadius: 0
                    }

                    SettingsToggleItem {
                        iconName: "extension"
                        title: "Lutris Scanner"
                        description: "Scan Lutris runner configurations & game YAMLs"
                        settingKey: "scanLutris"
                        defaultValue: true
                    }

                    SettingsToggleItem {
                        iconName: "star"
                        title: "Heroic Games Launcher"
                        description: "Scan installed GOG, Epic & Legendary games"
                        settingKey: "scanHeroic"
                        defaultValue: true
                    }

                    SettingsToggleItem {
                        iconName: "local_bar"
                        title: "Bottles / Wine Prefixes"
                        description: "Scan Bottles environment directories"
                        settingKey: "scanBottles"
                        defaultValue: true
                    }

                    SettingsToggleItem {
                        iconName: "cloud_download"
                        title: "Show Uninstalled / Library Games"
                        description: "Include uninstalled launcher library titles"
                        settingKey: "includeUninstalled"
                        defaultValue: true
                    }

                    SettingsToggleItem {
                        iconName: "visibility_off"
                        title: "Hide Main Launcher Apps"
                        description: "Hide launcher apps (Steam, Lutris, Heroic, Bottles) from the game list"
                        settingKey: "hideLaunchers"
                        defaultValue: false
                    }

                    SettingsToggleItem {
                        iconName: "content_copy"
                        title: "Hide Duplicate Titles"
                        description: "Deduplicate titles present across multiple stores/launchers"
                        settingKey: "hideDuplicates"
                        defaultValue: false
                    }

                    SettingsToggleItem {
                        iconName: "extension_off"
                        title: "Hide DLCs & Add-ons"
                        description: "Filter out DLC expansions, soundtracks, and bonus packs"
                        settingKey: "hideDLC"
                        defaultValue: false
                    }

                    SettingsToggleItem {
                        iconName: "filter_alt"
                        title: "Hide Empty Categories"
                        description: "Hide platform bar filters for stores with zero games"
                        settingKey: "hideEmptyCategories"
                        defaultValue: false
                        isLast: true
                        bottomLeftRadius: root.outerR; bottomRightRadius: root.outerR
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // 2. STEAM WEB API INTEGRATION
        // ---------------------------------------------------------------------
        Rectangle {
            id: sec2Card
            width: parent.width
            implicitHeight: sec2Col.implicitHeight
            visible: (root.activeSectionIndex === -1 || root.activeSectionIndex === 1) && (root.searchQuery === "" || "steam web api key account 64 id integration".indexOf(root.searchQuery.toLowerCase()) !== -1)
            height: visible ? implicitHeight : 0
            color: Theme.withAlpha(Theme.surfaceContainer, 0.3)
            radius: root.outerR
            border.width: 1
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
            clip: true

            Column {
                id: sec2Col
                width: parent.width

                Item {
                    width: parent.width
                    height: sec2HeaderRow.implicitHeight + Theme.spacingS * 2
                    // Separator line removed
                    Row {
                        id: sec2HeaderRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: Theme.spacingM
                        spacing: Theme.spacingS
                        Rectangle { width: 3; height: 14; radius: 2; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        DIcon { name: "cloud"; size: 14; color: Theme.primary; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Steam Web API Integration"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.DemiBold; color: Theme.primary; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                Column {
                    id: steamApiGroup
                    width: parent.width
                    spacing: 1

                    SettingsInputFieldItem {
                        iconName: "vpn_key"
                        title: "Steam Web API Key (Optional)"
                        description: "Used to fetch complete online Steam game library & metadata"
                        settingKey: "steamApiKey"
                        defaultValue: ""
                        placeholderText: "Enter 32-character Steam Web API Key"
                        isPassword: true
                        isFirst: true
                        topLeftRadius: 0; topRightRadius: 0
                    }

                    SettingsInputFieldItem {
                        iconName: "account_circle"
                        title: "Steam 64-bit ID (Optional)"
                        description: "Your SteamID64 (auto-detected from local Steam userdata if left empty)"
                        settingKey: "steamId"
                        defaultValue: ""
                        placeholderText: "e.g. 76561198000000000"
                        isLast: true
                        bottomLeftRadius: root.outerR; bottomRightRadius: root.outerR
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // 3. GRID VIEW CUSTOMIZATION
        // ---------------------------------------------------------------------
        Rectangle {
            id: sec3Card
            width: parent.width
            implicitHeight: sec3Col.implicitHeight
            visible: (root.activeSectionIndex === -1 || root.activeSectionIndex === 2) && (root.searchQuery === "" || "grid view cards per row spacing gap corner radius titles".indexOf(root.searchQuery.toLowerCase()) !== -1)
            height: visible ? implicitHeight : 0
            color: Theme.withAlpha(Theme.surfaceContainer, 0.3)
            radius: root.outerR
            border.width: 1
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
            clip: true

            Column {
                id: sec3Col
                width: parent.width

                Item {
                    width: parent.width
                    height: sec3HeaderRow.implicitHeight + Theme.spacingS * 2
                    // Separator line removed
                    Row {
                        id: sec3HeaderRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: Theme.spacingM
                        spacing: Theme.spacingS
                        Rectangle { width: 3; height: 14; radius: 2; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        DIcon { name: "grid_view"; size: 14; color: Theme.primary; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Grid View Customization"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.DemiBold; color: Theme.primary; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                Column {
                    id: gridGroup
                    width: parent.width
                    spacing: 1

                    SettingsSliderItem {
                        iconName: "view_column"
                        title: "Cards Per Row"
                        description: "Number of game cards displayed across each row (scales dynamically with window size)"
                        settingKey: "gridCardsPerRow"
                        defaultValue: 6
                        minimumValue: 4
                        maximumValue: 10
                        unit: " cards"
                        isFirst: true
                        topLeftRadius: 0; topRightRadius: 0
                    }

                    SettingsSliderItem {
                        iconName: "space_dashboard"
                        title: "Card Spacing / Gap"
                        description: "Spacing gap between cards in the grid (4 to 28px)"
                        settingKey: "gridCardGap"
                        defaultValue: 12
                        minimumValue: 4
                        maximumValue: 28
                        unit: "px"
                    }

                    SettingsToggleItem {
                        iconName: "title"
                        title: "Show Game Title on Cards"
                        description: "Display bottom game title footer. When disabled, cover artwork fills the entire card with fully rounded corners"
                        settingKey: "gridShowTitle"
                        defaultValue: true
                    }

                    SettingsSegmentItem {
                        iconName: "splitscreen"
                        title: "Game Details Presentation"
                        description: "Side-by-side splits the view with animated grid shrinking; Full Page smoothly expands cover & backdrop"
                        settingKey: "detailPositionMode"
                        defaultValue: "side_by_side"
                        segOptions: [
                            { label: "Side-by-Side", value: "side_by_side", icon: "vertical_split" },
                            { label: "Full Page", value: "fullscreen", icon: "fullscreen" }
                        ]
                    }

                    SettingsSegmentItem {
                        iconName: "view_sidebar"
                        title: "Side-by-Side Detail Width"
                        description: "Width percentage allocated to the game details panel when opening a game in side-by-side mode"
                        settingKey: "detailSideSize"
                        defaultValue: "50"
                        isLast: true
                        bottomLeftRadius: root.outerR; bottomRightRadius: root.outerR
                        segOptions: [
                            { label: "Compact (30%)", value: "30", icon: "view_compact" },
                            { label: "Balanced (50%)", value: "50", icon: "view_column" },
                            { label: "Expanded (70%)", value: "70", icon: "view_sidebar" }
                        ]
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // 4. APPEARANCE & THEME
        // ---------------------------------------------------------------------
        Rectangle {
            id: sec4Card
            width: parent.width
            implicitHeight: sec4Col.implicitHeight
            visible: (root.activeSectionIndex === -1 || root.activeSectionIndex === 3) && (root.searchQuery === "" || "appearance theme mode transparency light dark system".indexOf(root.searchQuery.toLowerCase()) !== -1)
            height: visible ? implicitHeight : 0
            color: Theme.withAlpha(Theme.surfaceContainer, 0.3)
            radius: root.outerR
            border.width: 1
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
            clip: true

            Column {
                id: sec4Col
                width: parent.width

                Item {
                    width: parent.width
                    height: sec4HeaderRow.implicitHeight + Theme.spacingS * 2
                    // Separator line removed
                    Row {
                        id: sec4HeaderRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: Theme.spacingM
                        spacing: Theme.spacingS
                        Rectangle { width: 3; height: 14; radius: 2; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                visible: false
                        DIcon { name: "palette"; size: 14; color: Theme.primary; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Appearance Preferences"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.DemiBold; color: Theme.primary; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                Column {
                    id: appearanceGroup
                    width: parent.width
                    spacing: 1

                    SettingsSegmentItem {
                        iconName: "palette"
                        title: "Window Theme Mode"
                        settingKey: "windowThemeMode"
                        defaultValue: "dark"
                        isFirst: true
                        topLeftRadius: 0; topRightRadius: 0
                        segOptions: [
                            { label: "System", value: "system", icon: "brightness_auto" },
                            { label: "Light",  value: "light",  icon: "light_mode" },
                            { label: "Dark",   value: "dark",   icon: "dark_mode" }
                        ]
                    }

                    SettingsToggleItem {
                        iconName: "opacity"
                        title: "Enable Window Transparency"
                        description: "Derive window backdrop translucency and blur styling directly from DankMaterialShell settings instead of a solid background"
                        settingKey: "windowTransparency"
                        defaultValue: false
                    }

                    SettingsSliderItem {
                        iconName: "rounded_corner"
                        title: "Cards & Media Corner Radius"
                        description: "Adjust rounded corner radius of game cards, detail panel covers, and screenshot previews (0 to 32px)"
                        settingKey: "gridCornerRadius"
                        defaultValue: 16
                        minimumValue: 0
                        maximumValue: 32
                        unit: "px"
                        isLast: true
                        bottomLeftRadius: root.outerR; bottomRightRadius: root.outerR
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // 5. BEHAVIOR & BAR WIDGET
        // ---------------------------------------------------------------------
        Rectangle {
            id: sec5Card
            width: parent.width
            implicitHeight: sec5Col.implicitHeight
            visible: (root.activeSectionIndex === -1 || root.activeSectionIndex === 4) && (root.searchQuery === "" || "behavior bar widget pill game count launch delay auto hide".indexOf(root.searchQuery.toLowerCase()) !== -1)
            height: visible ? implicitHeight : 0
            color: Theme.withAlpha(Theme.surfaceContainer, 0.3)
            radius: root.outerR
            border.width: 1
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
            clip: true

            Column {
                id: sec5Col
                width: parent.width

                Item {
                    width: parent.width
                    height: sec5HeaderRow.implicitHeight + Theme.spacingS * 2
                    // Separator line removed
                    Row {
                        id: sec5HeaderRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: Theme.spacingM
                        spacing: Theme.spacingS
                        Rectangle { width: 3; height: 14; radius: 2; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        DIcon { name: "tune"; size: 14; color: Theme.primary; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Behavior & Bar Widget"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.DemiBold; color: Theme.primary; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                Column {
                    id: behaviorGroup
                    width: parent.width
                    spacing: 1

                    SettingsToggleItem {
                        iconName: "analytics"
                        title: "Show Game Count in Bar Pill"
                        description: "Display game count on the DankBar widget pill"
                        settingKey: "showStatsInPill"
                        defaultValue: true
                        isFirst: true
                        topLeftRadius: 0; topRightRadius: 0
                    }

                    SettingsDropdownItem {
                        iconName: "pin"
                        title: "Bar Pill Count Mode"
                        description: "Choose whether the bar pill displays total count or only installed games count"
                        settingKey: "pillCountMode"
                        defaultValue: "total"
                        optionList: [
                            { label: "Total Games", value: "total" },
                            { label: "Installed Games Only", value: "installed" }
                        ]
                    }

                    SettingsToggleItem {
                        iconName: "close"
                        title: "Auto Close Hub on Game Launch"
                        description: "Close popout window when launching a game"
                        settingKey: "autoCloseOnLaunch"
                        defaultValue: false
                    }

                    SettingsSliderItem {
                        iconName: "timer"
                        title: "Filter Bar Auto-Hide Delay"
                        description: "Delay before the floating filter bar tucks itself into the edge"
                        settingKey: "autoHideDelay"
                        defaultValue: 1
                        minimumValue: 1
                        maximumValue: 10
                        unit: "s"
                    }

                    SettingsToggleItem {
                        iconName: "play_circle"
                        title: "Auto Play Game Trailer"
                        description: "Automatically stream game trailer in fullscreen detail mode when available"
                        settingKey: "autoPlayTrailer"
                        defaultValue: false
                    }

                    SettingsToggleItem {
                        iconName: "sports_esports"
                        title: "Controller Home Button Launches Hub"
                        description: "Press the gamepad Home/Guide button to show or toggle the Game Hub window (requires QtGamepad)"
                        settingKey: "controllerHomeEnabled"
                        defaultValue: false
                        isLast: true
                        bottomLeftRadius: root.outerR; bottomRightRadius: root.outerR
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // 6. METADATA PROVIDERS
        // ---------------------------------------------------------------------
        Rectangle {
            id: sec6Card
            width: parent.width
            implicitHeight: sec6Col.implicitHeight
            visible: (root.activeSectionIndex === -1 || root.activeSectionIndex === 5) && (root.searchQuery === "" || "metadata rawg igdb steamgriddb enrichment download covers posters banners".indexOf(root.searchQuery.toLowerCase()) !== -1)
            height: visible ? implicitHeight : 0
            color: Theme.withAlpha(Theme.surfaceContainer, 0.3)
            radius: root.outerR
            border.width: 1
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
            clip: true

            Column {
                id: sec6Col
                width: parent.width

                Item {
                    width: parent.width
                    height: sec6HeaderRow.implicitHeight + Theme.spacingS * 2
                    // Separator line removed
                    Row {
                        id: sec6HeaderRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: Theme.spacingM
                        spacing: Theme.spacingS
                        Rectangle { width: 3; height: 14; radius: 2; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        DIcon { name: "auto_awesome"; size: 14; color: Theme.primary; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Metadata Providers"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.DemiBold; color: Theme.primary; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                // Info banner inside the container
                Item {
                    width: parent.width
                    implicitHeight: infoBannerRow.implicitHeight + 16

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        anchors.topMargin: 0
                        anchors.bottomMargin: 0
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06)
                        radius: root.innerR
                    }

                    // Separator line removed

                    RowLayout {
                        id: infoBannerRow
                        anchors {
                            left: parent.left; right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: Theme.spacingM * 2; rightMargin: Theme.spacingM; topMargin: 8; bottomMargin: 8
                        }
                        spacing: Theme.spacingS

                        DIcon { name: "info"; size: 15; color: Theme.primary; opacity: 0.8; Layout.alignment: Qt.AlignTop }

                        StyledText {
                            Layout.fillWidth: true
                            text: "Automatically enriches your game library with cover art, descriptions, genres, release dates and age ratings — inspired by the Playnite PSN Universal metadata plugin. Data is fetched from PlayStation Store (Algolia) and RAWG.io, then cached locally in Extension Data/."
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                            opacity: 0.8
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Column {
                    id: metadataGroup
                    width: parent.width
                    spacing: 1

                    SettingsToggleItem {
                        iconName: "auto_awesome"
                        title: "Enable Metadata Enrichment"
                        description: "Fetch cover art, descriptions and details from online providers"
                        settingKey: "metadataEnabled"
                        defaultValue: true
                        isFirst: true
                        topLeftRadius: 0; topRightRadius: 0
                    }

                    SettingsToggleItem {
                        iconName: "sync"
                        title: "Auto-Fetch on Library Scan"
                        description: "Automatically fetch metadata whenever new games are discovered"
                        settingKey: "metadataAutoFetch"
                        defaultValue: true
                    }

                    SettingsToggleItem {
                        iconName: "image"
                        title: "Download Covers Locally"
                        description: "Save 600×900 vertical covers to Extension Data/covers/"
                        settingKey: "metadataDownloadCovers"
                        defaultValue: false
                    }

                    SettingsToggleItem {
                        iconName: "wallpaper"
                        title: "Download Backgrounds Locally"
                        description: "Save full-resolution 1920×1080 hero artworks to Extension Data/backgrounds/"
                        settingKey: "metadataDownloadBackgrounds"
                        defaultValue: false
                    }

                    SettingsToggleItem {
                        iconName: "collections"
                        title: "Download Media & Screenshots"
                        description: "Save gallery screenshots to Extension Data/media/"
                        settingKey: "metadataDownloadMedia"
                        defaultValue: false
                    }

                    SettingsToggleItem {
                        iconName: "movie"
                        title: "Download Trailers Locally"
                        description: "Save video trailers to Extension Data/trailers/ (only triggers on manual fetch)"
                        settingKey: "metadataDownloadTrailers"
                        defaultValue: false
                    }

                    SettingsSegmentItem {
                        iconName: "priority_high"
                        title: "Provider Priority"
                        settingKey: "metadataProviderPriority"
                        defaultValue: "psn"
                        segOptions: [
                            { label: "PSN First",  value: "psn",  icon: "sports_esports" },
                            { label: "RAWG First", value: "rawg", icon: "cloud" },
                            { label: "PSN Only",   value: "psn_only",  icon: "lock" },
                            { label: "RAWG Only",  value: "rawg_only", icon: "cloud_done" }
                        ]
                    }

                    SettingsInputFieldItem {
                        iconName: "vpn_key"
                        title: "RAWG API Key (Optional)"
                        description: "Free key from rawg.io — unlocks higher rate limits & game descriptions"
                        settingKey: "rawgKey"
                        defaultValue: ""
                        placeholderText: "Paste RAWG.io API key here (optional)"
                        isPassword: true
                        isLast: true
                    }
                }

                // Cache management row inside the container
                Item {
                    width: parent.width
                    height: cacheRow.implicitHeight + 20

                    // Separator line removed

                    RowLayout {
                        id: cacheRow
                        anchors {
                            fill: parent
                            leftMargin: Theme.spacingM; rightMargin: Theme.spacingM
                            topMargin: 10; bottomMargin: 10
                        }
                        spacing: Theme.spacingM

                        DIcon { name: "storage"; size: 18; color: Theme.primary; Layout.alignment: Qt.AlignVCenter }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            StyledText {
                                text: "Metadata Cache"
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: "Cached data lives in Extension Data/metadata.json — delete to force a full re-fetch"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        // Fetch metadata now button
                        Rectangle {
                            id: fetchMetaNowBtn
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: fetchMetaNowRow.implicitWidth + 20
                            Layout.alignment: Qt.AlignVCenter
                            property bool isHovered: fetchMetaNowMa.containsMouse

                            radius: isHovered ? (height / 2) : (root.innerR + 2)
                            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }

                            color: isHovered
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                                : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            border.width: 1
                            border.color: isHovered
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.60)
                                : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.30)
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            scale: fetchMetaNowMa.pressed ? 0.93 : (isHovered ? 1.02 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                            RowLayout {
                                id: fetchMetaNowRow
                                anchors.centerIn: parent
                                spacing: 5
                                DIcon { name: "auto_awesome"; size: 14; color: Theme.primary }
                                StyledText {
                                    text: "Fetch Metadata Now"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.primary
                                }
                            }

                            MouseArea {
                                id: fetchMetaNowMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (typeof PluginService !== "undefined" && PluginService && PluginService.setGlobalVar) {
                                        PluginService.setGlobalVar("fullscreenGameHub", "refreshMetadata", Date.now());
                                    }
                                    root.runShellCommand("dms ipc call fullscreenGameHub refreshMetadata 2>/dev/null || true");
                                    if (typeof ToastService !== "undefined" && ToastService) {
                                        ToastService.showInfo("Metadata enrichment pipeline started");
                                    }
                                }
                            }
                        }

                        // Clear cache button
                        Rectangle {
                            id: clearCacheBtn
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: clearCacheRow.implicitWidth + 20
                            Layout.alignment: Qt.AlignVCenter
                            property bool isHovered: clearCacheMa.containsMouse

                            radius: isHovered ? (height / 2) : (root.innerR + 2)
                            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }

                            color: isHovered
                                ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.22)
                                : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.10)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            border.width: 1
                            border.color: isHovered
                                ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.55)
                                : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.25)
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            scale: clearCacheMa.pressed ? 0.93 : (isHovered ? 1.02 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                            RowLayout {
                                id: clearCacheRow
                                anchors.centerIn: parent
                                spacing: 5
                                DIcon { name: "delete_sweep"; size: 14; color: Theme.error }
                                StyledText {
                                    text: "Clear Cache"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.error
                                }
                            }

                            MouseArea {
                                id: clearCacheMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.runShellCommand('rm -f "' + root.pluginDir + '/Extension Data/metadata.json"');
                                    if (typeof ToastService !== "undefined" && ToastService) {
                                        ToastService.showInfo("Metadata cache cleared — next scan will re-fetch");
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // 7. IPC COMMANDS & SHORTCUTS
        // ---------------------------------------------------------------------
        Rectangle {
            id: sec7Card
            width: parent.width
            implicitHeight: sec7Col.implicitHeight
            visible: !root.hideIpcCommands && (root.activeSectionIndex === -1 || root.activeSectionIndex === 6) && (root.searchQuery === "" || "ipc commands shortcuts hotkey cli terminal".indexOf(root.searchQuery.toLowerCase()) !== -1)
            height: visible ? implicitHeight : 0
            color: Theme.withAlpha(Theme.surfaceContainer, 0.3)
            radius: root.outerR
            border.width: 1
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
            clip: true

            Column {
                id: sec7Col
                width: parent.width

                Item {
                    width: parent.width
                    height: sec7HeaderRow.implicitHeight + Theme.spacingS * 2
                    // Separator line removed
                    Row {
                        id: sec7HeaderRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: Theme.spacingM
                        spacing: Theme.spacingS
                        Rectangle { width: 3; height: 14; radius: 2; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        DIcon { name: "keyboard_command_key"; size: 14; color: Theme.primary; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "IPC Commands & Shortcuts"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.DemiBold; color: Theme.primary; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                Column {
                    id: ipcInnerCol
                    width: parent.width - Theme.spacingM * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: Theme.spacingM
                    bottomPadding: Theme.spacingM
                    spacing: Theme.spacingM

                    // Shortcuts & Desktop Integration Toggles
                    Column {
                        width: parent.width
                        spacing: 1

                        SettingsToggleItem {
                            iconName: "app_shortcut"
                            title: "Desktop Application Entry"
                            description: "Add Game Hub (.desktop) to application launcher menu (~/.local/share/applications)"
                            settingKey: "enableDesktopShortcut"
                            defaultValue: true
                            isFirst: true
                            topLeftRadius: root.outerR; topRightRadius: root.outerR
                            bottomLeftRadius: root.innerR; bottomRightRadius: root.innerR
                            onCheckedChanged: root.toggleDesktopShortcut(checked)
                        }

                        SettingsToggleItem {
                            iconName: "picture_in_picture"
                            title: "Niri Window Rules (Auto-Float & Size)"
                            description: "Enable automatic floating window rules & 1200x780 dimensions in Niri config"
                            settingKey: "enableNiriRules"
                            defaultValue: true
                            isLast: true
                            topLeftRadius: root.innerR; topRightRadius: root.innerR
                            bottomLeftRadius: root.outerR; bottomRightRadius: root.outerR
                            onCheckedChanged: root.toggleNiriRules(checked)
                        }
                    }

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                text: "Control and trigger Fullscreen Game Hub via IPC, bar, or keybinds"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                width: parent.width
                                wrapMode: Text.WordWrap
                            }
                        }

                        Rectangle {
                            id: openHubBtn
                            Layout.preferredHeight: 34
                            Layout.preferredWidth: openHubRow.implicitWidth + 24
                            Layout.alignment: Qt.AlignVCenter
                            property bool isHovered: openHubMa.containsMouse

                            radius: isHovered ? (height / 2) : (Theme.cornerRadius || 12)
                            Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }

                            color: isHovered ? Theme.withAlpha(Theme.primary, 0.25) : Theme.withAlpha(Theme.primary, 0.15)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            border.width: 1
                            border.color: isHovered ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            scale: openHubMa.pressed ? 0.94 : (isHovered ? 1.02 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                            DRipple {
                                id: openHubRip
                                anchors.fill: parent
                                cornerRadius: parent.radius
                                rippleColor: Theme.primary
                            }

                            RowLayout {
                                id: openHubRow
                                anchors.centerIn: parent
                                spacing: 6

                                DIcon {
                                    name: "open_in_new"
                                    size: 16
                                    color: Theme.primary
                                }

                                StyledText {
                                    text: "Open Game Hub"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.primary
                                }
                            }

                            MouseArea {
                                id: openHubMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: (m) => openHubRip.trigger(m.x, m.y)
                                onClicked: {
                                    if (typeof PluginService !== "undefined" && PluginService && PluginService.setGlobalVar) {
                                        PluginService.setGlobalVar("fullscreenGameHub", "windowOpenState", true);
                                    }
                                    root.runShellCommand("dms ipc call fullscreenGameHub open 2>/dev/null || true");
                                    if (typeof ToastService !== "undefined" && ToastService) {
                                        ToastService.showInfo("Opened Game Hub");
                                    }
                                }
                            }
                        }
                    }

                    CopyBox {
                        label: "Open Hub Modal Command"
                        text: "dms ipc call fullscreenGameHub open"
                    }

                    CopyBox {
                        label: "Rescan Library Command"
                        text: "dms ipc call fullscreenGameHub rescan"
                    }

                    StyledText {
                        width: parent.width
                        text: "To trigger Fullscreen Game Hub with a keyboard shortcut (e.g., Mod+G), add this spawn command to your window manager bindings (e.g. Niri or Hyprland):"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primary
                        font.italic: true
                        wrapMode: Text.WordWrap
                    }

                    CopyBox {
                        label: "Niri Bind Configuration"
                        text: "Mod+G { spawn \"dms\" \"ipc\" \"call\" \"fullscreenGameHub\" \"open\"; }"
                    }
                }
            }
        }
    }
}
