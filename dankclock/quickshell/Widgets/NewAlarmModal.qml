import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets
import qs.Widgets

FloatingWindow {
    id: newAlarmModal

    property int draftHour: 7
    property int draftMinute: 0
    property string draftLabel: "Alarm"
    property var draftDays: ["Mon", "Tue", "Wed", "Thu", "Fri"]
    property string draftSoundId: "classic"
    property int draftSnoozeMin: 10
    property int draftVolume: 100
    property bool draftDeleteAfter: true
    property bool editingTimeText: false
    property bool minuteMode: false
    property bool draggingDial: false

    readonly property bool is24Hour: SettingsData.use24HourClock
    readonly property bool isPm: draftHour >= 12
    readonly property real dialSize: Math.min(256, Math.max(200, leftPanel.width - Theme.spacingXL * 2))
    readonly property real outerRingRadius: dialSize * Style.clockOuterRingRatio
    readonly property real innerRingRadius: dialSize * Style.clockInnerRingRatio
    readonly property real numberSize: Style.clockHandleSize
    readonly property real handAngle: minuteMode ? draftMinute * 6 : (draftHour % 12) * 30
    readonly property real handLength: (!minuteMode && is24Hour && (draftHour === 0 || draftHour > 12)) ? innerRingRadius : outerRingRadius

    readonly property var dayItems: [
        { key: "Sun", letter: "S" },
        { key: "Mon", letter: "M" },
        { key: "Tue", letter: "T" },
        { key: "Wed", letter: "W" },
        { key: "Thu", letter: "T" },
        { key: "Fri", letter: "F" },
        { key: "Sat", letter: "S" }
    ]

    readonly property var repeatPresets: [
        { label: "Weekdays", days: ["Mon", "Tue", "Wed", "Thu", "Fri"] },
        { label: "Weekends", days: ["Sat", "Sun"] },
        { label: "Every day", days: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] },
        { label: "One-time", days: [] }
    ]

    readonly property var timeParts: ClockService.formatClockParts(draftHour, draftMinute)
    readonly property string scheduleSummary: ClockService.formatAlarmSchedule(draftDays)

    function pad2(v) {
        return (v < 10 ? "0" : "") + v;
    }

    function resetDraft() {
        const now = ClockService.now || new Date();
        draftHour = now.getHours();
        draftMinute = now.getMinutes();
        draftLabel = "Alarm";
        draftDays = ["Mon", "Tue", "Wed", "Thu", "Fri"];
        draftSoundId = "classic";
        draftSnoozeMin = SettingsData.defaultSnoozeMin || 10;
        draftVolume = 100;
        draftDeleteAfter = SettingsData.alwaysDeleteOneTimeAlarms;
        editingTimeText = false;
        minuteMode = false;
        draggingDial = false;
        labelField.text = "";
    }

    function show() {
        resetDraft();
        visible = true;
    }

    function hide() {
        editingTimeText = false;
        ClockService.stopSound();
        visible = false;
        ClockService.newAlarmModalOpen = false;
    }

    function applyDialPoint(x, y) {
        const dx = x - dialSize / 2;
        const dy = y - dialSize / 2;
        const angle = (Math.atan2(dy, dx) * 180 / Math.PI + 90 + 360) % 360;
        if (minuteMode) {
            draftMinute = (Math.round(angle / 6) % 60 + 60) % 60;
            return;
        }
        const step = Math.round(angle / 30) % 12;
        if (!is24Hour) {
            draftHour = isPm ? (step === 0 ? 12 : step + 12) : (step === 0 ? 0 : step);
            return;
        }
        const dist = Math.sqrt(dx * dx + dy * dy);
        const inner = dist < (outerRingRadius + innerRingRadius) / 2;
        draftHour = inner ? (step === 0 ? 0 : step + 12) : (step === 0 ? 12 : step);
    }

    function beginTimeEdit() {
        editingTimeText = true;
        timeTextInput.text = timeParts.timeText;
        timeTextInput.forceActiveFocus();
        timeTextInput.selectAll();
    }

    function commitTimeEdit() {
        if (!editingTimeText)
            return;
        const raw = (timeTextInput.text || "").trim().toLowerCase();
        editingTimeText = false;
        if (!raw)
            return;

        const hasPm = raw.indexOf("p") >= 0;
        const hasAm = raw.indexOf("a") >= 0;
        const cleaned = raw.replace(/[^0-9:]/g, "");
        let h = -1;
        let m = 0;

        if (cleaned.indexOf(":") >= 0) {
            const parts = cleaned.split(":");
            h = parseInt(parts[0], 10);
            m = parts.length > 1 && parts[1] !== "" ? parseInt(parts[1], 10) : 0;
        } else if (cleaned.length <= 2) {
            h = parseInt(cleaned, 10);
            m = 0;
        } else if (cleaned.length === 3) {
            h = parseInt(cleaned.slice(0, 1), 10);
            m = parseInt(cleaned.slice(1), 10);
        } else {
            h = parseInt(cleaned.slice(0, 2), 10);
            m = parseInt(cleaned.slice(2, 4), 10);
        }

        if (isNaN(h) || isNaN(m))
            return;

        m = Math.max(0, Math.min(59, m));
        if (is24Hour && !hasAm && !hasPm) {
            h = Math.max(0, Math.min(23, h));
        } else {
            if (h > 12 && h <= 23 && !hasAm && !hasPm) {
                // Allow direct 24h entry even in 12h mode
            } else {
                h = Math.max(1, Math.min(12, h));
                const nextPm = hasPm ? true : (hasAm ? false : isPm);
                if (nextPm && h < 12)
                    h += 12;
                else if (!nextPm && h === 12)
                    h = 0;
            }
        }
        draftHour = h;
        draftMinute = m;
    }

    function submitAlarm() {
        if (editingTimeText)
            commitTimeEdit();
        ClockService.stopSound();
        ClockService.createAlarm({
            hour: draftHour,
            minute: draftMinute,
            label: labelField.text.trim() || draftLabel || "Alarm",
            enabled: true,
            days: draftDays,
            soundId: draftSoundId,
            snoozeMin: draftSnoozeMin,
            volume: draftVolume,
            deleteAfterGoesOff: draftDeleteAfter
        });
    }

    onClosed: hide()

    Timer {
        id: outsideClickTimer
        interval: 80
        onTriggered: {
            if (newAlarmModal.visible && !rootFocusScope.activeFocus && !soundDropdown.menuOpen)
                newAlarmModal.hide();
        }
    }

    Timer {
        id: advanceMinuteTimer
        interval: 220
        onTriggered: newAlarmModal.minuteMode = true
    }

    WindowBlur {
        targetWindow: newAlarmModal
        blurEnabled: Theme.translucentWindows
        blurWidth: newAlarmModal.width
        blurHeight: newAlarmModal.height
    }

    title: "New Alarm"
    minimumSize: Qt.size(SettingsMetrics.windowMinWidth, SettingsMetrics.windowMinHeight)
    implicitWidth: screen ? Math.min(SettingsMetrics.windowWidth, screen.width - Theme.spacingXL * 2) : SettingsMetrics.windowWidth
    implicitHeight: screen ? Math.min(SettingsMetrics.windowHeight, screen.height - Theme.spacingXL * 2) : SettingsMetrics.windowHeight
    color: Theme.windowSurface
    surfaceFormat.opaque: false
    visible: false

    Connections {
        target: ClockService
        function onNewAlarmModalOpenChanged() {
            if (ClockService.newAlarmModalOpen)
                newAlarmModal.show();
            else
                newAlarmModal.hide();
        }
    }

    FocusScope {
        id: rootFocusScope
        anchors.fill: parent
        focus: true

        onActiveFocusChanged: {
            if (newAlarmModal.visible && !activeFocus)
                outsideClickTimer.restart();
            else
                outsideClickTimer.stop();
        }

        readonly property bool isFloatingWindowSurface: true
        readonly property color surfaceColor: newAlarmModal.color

        LayoutMirroring.enabled: I18n.isRtl
        LayoutMirroring.childrenInherit: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (newAlarmModal.editingTimeText)
                    newAlarmModal.editingTimeText = false;
                else
                    newAlarmModal.hide();
                event.accepted = true;
            }
        }

        Column {
            anchors.fill: parent
            topPadding: header.integrated ? 0 : header.height
            spacing: 0

            Item {
                width: parent.width
                height: parent.height - parent.topPadding
                clip: true

                // Left Panel: Visual Clock + Time Text Field
                Item {
                    id: leftPanel
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(300, Math.min(360, parent.width * 0.36))

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        anchors.rightMargin: 0
                        radius: Theme.cornerRadiusXL
                        color: SettingsMetrics.paneColor
                        border.width: Theme.layerOutlineWidth ?? 1
                        border.color: Theme.outlineMedium
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        anchors.rightMargin: 0
                        anchors.leftMargin: Theme.spacingM + Theme.spacingM
                        anchors.topMargin: Theme.spacingXL
                        anchors.bottomMargin: Theme.spacingXL
                        spacing: Theme.spacingL

                        Item { Layout.fillHeight: true }

                        // Hour / Minute Mode Selector + AM/PM
                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Theme.spacingS

                            DButtonGroup {
                                size: "small"
                                selectionMode: "single"
                                checkEnabled: false
                                minButtonWidth: 64
                                buttonPadding: Theme.spacingS
                                model: ["Hour", "Minute"]
                                currentIndex: newAlarmModal.minuteMode ? 1 : 0
                                onSelectionChanged: (idx, sel) => {
                                    if (sel)
                                        newAlarmModal.minuteMode = (idx === 1);
                                }
                            }

                            DButtonGroup {
                                visible: !newAlarmModal.is24Hour
                                size: "small"
                                selectionMode: "single"
                                checkEnabled: false
                                minButtonWidth: 40
                                buttonPadding: Theme.spacingXS
                                model: ["AM", "PM"]
                                currentIndex: newAlarmModal.isPm ? 1 : 0
                                onSelectionChanged: (idx, sel) => {
                                    if (!sel)
                                        return;
                                    const base = newAlarmModal.draftHour % 12;
                                    newAlarmModal.draftHour = idx === 1 ? base + 12 : base;
                                }
                            }
                        }

                        // Interactive Visual Clock Face
                        Rectangle {
                            id: clockFace
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: newAlarmModal.dialSize
                            Layout.preferredHeight: newAlarmModal.dialSize
                            radius: width / 2
                            color: Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: Theme.outlineMedium ?? Theme.outlineVariant

                            Item {
                                id: clockHand
                                x: newAlarmModal.dialSize / 2 - width / 2
                                y: newAlarmModal.dialSize / 2
                                width: Style.clockHandWidth
                                height: newAlarmModal.handLength
                                transformOrigin: Item.Top
                                rotation: newAlarmModal.handAngle + 180

                                Behavior on rotation {
                                    enabled: Theme.animationsEnabled && !newAlarmModal.draggingDial
                                    RotationAnimation {
                                        direction: RotationAnimation.Shortest
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on height {
                                    enabled: Theme.animationsEnabled && !newAlarmModal.draggingDial
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.primary
                                    radius: width / 2
                                }

                                Rectangle {
                                    width: newAlarmModal.numberSize
                                    height: newAlarmModal.numberSize
                                    radius: width / 2
                                    color: Theme.primary
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.bottom
                                }
                            }

                            Rectangle {
                                width: Style.clockCenterSize
                                height: Style.clockCenterSize
                                radius: width / 2
                                anchors.centerIn: parent
                                color: Theme.primary
                            }

                            Repeater {
                                model: newAlarmModal.minuteMode ? 12 : (newAlarmModal.is24Hour ? 24 : 12)

                                Item {
                                    required property int index
                                    readonly property bool innerRing: !newAlarmModal.minuteMode && newAlarmModal.is24Hour && index >= 12
                                    readonly property int step: index % 12
                                    readonly property int value: newAlarmModal.minuteMode ? step * 5 : (innerRing ? (step === 0 ? 0 : step + 12) : (step === 0 ? 12 : step))
                                    readonly property bool selected: newAlarmModal.minuteMode
                                        ? (newAlarmModal.draftMinute === value)
                                        : (newAlarmModal.is24Hour ? newAlarmModal.draftHour === value : (newAlarmModal.draftHour % 12) === (value % 12))
                                    readonly property real ringRadius: innerRing ? newAlarmModal.innerRingRadius : newAlarmModal.outerRingRadius
                                    readonly property real angle: (step * 30 - 90) * Math.PI / 180

                                    width: newAlarmModal.numberSize
                                    height: newAlarmModal.numberSize
                                    x: newAlarmModal.dialSize / 2 + ringRadius * Math.cos(angle) - width / 2
                                    y: newAlarmModal.dialSize / 2 + ringRadius * Math.sin(angle) - height / 2

                                    NumericText {
                                        anchors.centerIn: parent
                                        text: newAlarmModal.minuteMode || parent.innerRing ? newAlarmModal.pad2(parent.value) : parent.value
                                        reserveText: "00"
                                        isMonospace: false
                                        font.pixelSize: parent.innerRing ? Theme.fontSizeSmall : Theme.fontSizeMedium
                                        font.weight: parent.selected ? Font.Bold : Font.Medium
                                        color: parent.selected ? Theme.onPrimary : Theme.surfaceText
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => {
                                    newAlarmModal.draggingDial = true;
                                    newAlarmModal.applyDialPoint(mouse.x, mouse.y);
                                }
                                onPositionChanged: mouse => {
                                    if (!pressed)
                                        return;
                                    newAlarmModal.applyDialPoint(mouse.x, mouse.y);
                                }
                                onReleased: {
                                    newAlarmModal.draggingDial = false;
                                    if (!newAlarmModal.minuteMode)
                                        advanceMinuteTimer.restart();
                                }
                            }
                        }

                        // Clickable Time Text Field Below Clock for Keyboard Input
                        Rectangle {
                            id: timePill
                            Layout.fillWidth: true
                            Layout.leftMargin: Theme.spacingS
                            Layout.rightMargin: Theme.spacingS
                            Layout.preferredHeight: 62
                            radius: Theme.groupedListOuterRadius ?? 16
                            color: newAlarmModal.editingTimeText
                                ? Theme.surfaceContainerLowest
                                : (timePillMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.16) : Theme.surfaceContainerHigh)
                            border.width: 1
                            border.color: (newAlarmModal.editingTimeText || timePillMouse.containsMouse) ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                            Row {
                                id: timeDisplayRow
                                visible: !newAlarmModal.editingTimeText
                                anchors.centerIn: parent
                                spacing: 6

                                DIcon {
                                    name: "keyboard"
                                    size: Theme.iconSizeSmall
                                    color: timePillMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                NumericText {
                                    text: newAlarmModal.timeParts.timeText
                                    font.pixelSize: Theme.fontSizeDisplay
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    visible: newAlarmModal.timeParts.meridiem !== ""
                                    text: newAlarmModal.timeParts.meridiem
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Theme.fontWeightBold
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            TextInput {
                                id: timeTextInput
                                visible: newAlarmModal.editingTimeText
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingM
                                horizontalAlignment: TextInput.AlignHCenter
                                verticalAlignment: TextInput.AlignVCenter
                                font.pixelSize: Theme.fontSizeDisplay
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                                selectionColor: Theme.withAlpha(Theme.primary, 0.3)
                                selectedTextColor: Theme.surfaceText
                                selectByMouse: true
                                clip: true
                                onActiveFocusChanged: {
                                    if (!activeFocus && newAlarmModal.editingTimeText)
                                        newAlarmModal.commitTimeEdit();
                                }
                                Keys.onReturnPressed: newAlarmModal.commitTimeEdit()
                                Keys.onEnterPressed: newAlarmModal.commitTimeEdit()
                                Keys.onEscapePressed: event => {
                                    newAlarmModal.editingTimeText = false;
                                    event.accepted = true;
                                }
                            }

                            MouseArea {
                                id: timePillMouse
                                anchors.fill: parent
                                enabled: !newAlarmModal.editingTimeText
                                hoverEnabled: true
                                cursorShape: newAlarmModal.editingTimeText ? Qt.IBeamCursor : Qt.PointingHandCursor
                                onClicked: newAlarmModal.beginTimeEdit()
                            }

                            DTooltipHost {
                                target: timePill
                                hoverArea: timePillMouse
                                text: newAlarmModal.editingTimeText ? "" : "Click to type custom time"
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                // Right Panel: Settings-style Pane with All Other Details
                FocusScope {
                    id: contentScope
                    anchors.left: leftPanel.right
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingM
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingM
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.spacingM

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.cornerRadiusXL
                        color: SettingsMetrics.paneColor
                        border.width: Theme.layerOutlineWidth ?? 1
                        border.color: Theme.outlineMedium
                        clip: true
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: SettingsMetrics.panePadding
                        spacing: Theme.spacingM

                        SettingsPage {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            // Label & Schedule Card
                            SettingsCard {
                                title: "Label & Schedule"
                                iconName: "event_repeat"

                                SettingsRow {
                                    iconName: "label"
                                    title: "Alarm label"
                                    subtitle: "Name shown on the alarm card and notification"

                                    DTextField {
                                        id: labelField
                                        width: 240
                                        placeholderText: "Alarm"
                                        Keys.onReturnPressed: newAlarmModal.submitAlarm()
                                        Keys.onEnterPressed: newAlarmModal.submitAlarm()
                                    }
                                }

                                SettingsRow {
                                    iconName: "calendar_today"
                                    title: "Repeat days"
                                    subtitle: newAlarmModal.scheduleSummary

                                    body: Column {
                                        width: parent.width
                                        spacing: Theme.spacingS

                                        Row {
                                            id: modalDaysGroup
                                            width: parent.width
                                            height: 36
                                            spacing: 2

                                            Repeater {
                                                model: newAlarmModal.dayItems

                                                Rectangle {
                                                    id: dayBtn
                                                    required property var modelData
                                                    required property int index

                                                    readonly property bool isSelected: newAlarmModal.draftDays.indexOf(modelData.key) >= 0
                                                    readonly property bool isFirst: index === 0
                                                    readonly property bool isLast: index === newAlarmModal.dayItems.length - 1
                                                    readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                                                    readonly property real innerR: Theme.groupedListInnerRadius ?? 4

                                                    width: Math.floor((modalDaysGroup.width - modalDaysGroup.spacing * 6) / 7)
                                                    height: modalDaysGroup.height
                                                    topLeftRadius: (isSelected || dMouse.containsMouse) ? outerR : (isFirst ? outerR : innerR)
                                                    bottomLeftRadius: (isSelected || dMouse.containsMouse) ? outerR : (isFirst ? outerR : innerR)
                                                    topRightRadius: (isSelected || dMouse.containsMouse) ? outerR : (isLast ? outerR : innerR)
                                                    bottomRightRadius: (isSelected || dMouse.containsMouse) ? outerR : (isLast ? outerR : innerR)
                                                    color: (isSelected || dMouse.containsMouse) ? Theme.withAlpha(Theme.primary, 0.2) : Theme.surfaceContainerHigh
                                                    border.width: 1
                                                    border.color: (isSelected || dMouse.containsMouse) ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                                                    scale: dMouse.pressed ? 0.94 : (dMouse.containsMouse ? 1.04 : 1.0)
                                                    clip: true

                                                    Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                                    DRipple { id: dRipple; anchors.fill: parent; rippleColor: Theme.primary }

                                                    StyledText {
                                                        anchors.centerIn: parent
                                                        text: dayBtn.modelData.letter
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        font.weight: dayBtn.isSelected ? Font.Bold : Font.Medium
                                                        color: (dayBtn.isSelected || dMouse.containsMouse) ? Theme.primary : Theme.surfaceText
                                                    }

                                                    MouseArea {
                                                        id: dMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onPressed: mouse => dRipple.trigger(mouse.x, mouse.y)
                                                        onClicked: {
                                                            const cur = newAlarmModal.draftDays.slice();
                                                            const pos = cur.indexOf(dayBtn.modelData.key);
                                                            if (pos >= 0)
                                                                cur.splice(pos, 1);
                                                            else
                                                                cur.push(dayBtn.modelData.key);
                                                            newAlarmModal.draftDays = ClockService.weekDays.filter(d => cur.indexOf(d) >= 0);
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Row {
                                            id: modalPresetsGroup
                                            width: parent.width
                                            height: 34
                                            spacing: 2

                                            Repeater {
                                                model: newAlarmModal.repeatPresets

                                                Rectangle {
                                                    id: presetBtn
                                                    required property var modelData
                                                    required property int index

                                                    readonly property bool active: modelData.label === newAlarmModal.scheduleSummary
                                                    readonly property bool isFirst: index === 0
                                                    readonly property bool isLast: index === newAlarmModal.repeatPresets.length - 1
                                                    readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                                                    readonly property real innerR: Theme.groupedListInnerRadius ?? 4

                                                    width: Math.floor((modalPresetsGroup.width - modalPresetsGroup.spacing * (newAlarmModal.repeatPresets.length - 1)) / newAlarmModal.repeatPresets.length)
                                                    height: modalPresetsGroup.height
                                                    topLeftRadius: (active || pMouse.containsMouse) ? outerR : (isFirst ? outerR : innerR)
                                                    bottomLeftRadius: (active || pMouse.containsMouse) ? outerR : (isFirst ? outerR : innerR)
                                                    topRightRadius: (active || pMouse.containsMouse) ? outerR : (isLast ? outerR : innerR)
                                                    bottomRightRadius: (active || pMouse.containsMouse) ? outerR : (isLast ? outerR : innerR)
                                                    color: (active || pMouse.containsMouse) ? Theme.withAlpha(Theme.primary, 0.2) : Theme.surfaceContainerHigh
                                                    border.width: 1
                                                    border.color: (active || pMouse.containsMouse) ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                                                    scale: pMouse.pressed ? 0.95 : (pMouse.containsMouse ? 1.03 : 1.0)
                                                    clip: true

                                                    Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                                    DRipple { id: pRipple; anchors.fill: parent; rippleColor: Theme.primary }

                                                    StyledText {
                                                        anchors.centerIn: parent
                                                        text: presetBtn.modelData.label
                                                        font.pixelSize: Theme.fontSizeSmall - 1
                                                        font.weight: presetBtn.active ? Font.DemiBold : Font.Medium
                                                        color: (presetBtn.active || pMouse.containsMouse) ? Theme.primary : Theme.surfaceText
                                                    }

                                                    MouseArea {
                                                        id: pMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onPressed: mouse => pRipple.trigger(mouse.x, mouse.y)
                                                        onClicked: newAlarmModal.draftDays = presetBtn.modelData.days.slice()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Sound & Behavior Card
                            SettingsCard {
                                title: "Sound & Behavior"
                                iconName: "tune"

                                SettingsRow {
                                    iconName: "music_note"
                                    title: "Alarm sound"
                                    subtitle: "Ringtone played when this alarm goes off"

                                    Row {
                                        spacing: Theme.spacingXS

                                        DIconButton {
                                            iconName: "volume_up"
                                            variant: "standard"
                                            size: "s"
                                            tooltipText: "Preview sound"
                                            anchors.verticalCenter: parent.verticalCenter
                                            onClicked: ClockService.previewAlarmSound(newAlarmModal.draftSoundId, newAlarmModal.draftVolume)
                                        }

                                        DDropdown {
                                            id: soundDropdown
                                            width: 180
                                            anchors.verticalCenter: parent.verticalCenter
                                            enableFuzzySearch: ClockService.alarmSounds.length > ClockService.defaultAlarmSounds.length
                                            options: ClockService.alarmSounds.map(s => s.name)
                                            optionValues: ClockService.alarmSounds.map(s => s.id)
                                            optionIcons: ClockService.alarmSounds.map(s => s.icon || "music_note")
                                            currentValue: newAlarmModal.draftSoundId
                                            onMenuOpenChanged: {
                                                if (!menuOpen && newAlarmModal.visible && !rootFocusScope.activeFocus)
                                                    outsideClickTimer.restart();
                                            }
                                            onValueChanged: val => {
                                                if (val) {
                                                    newAlarmModal.draftSoundId = val;
                                                    ClockService.previewAlarmSound(val, newAlarmModal.draftVolume);
                                                }
                                            }
                                        }
                                    }
                                }

                                SettingsButtonGroupRow {
                                    iconName: "snooze"
                                    text: "Snooze duration"
                                    description: "Minutes before the alarm rings again when snoozed"
                                    model: ClockService.snoozeOptions.map(m => `${m}m`)
                                    currentIndex: Math.max(0, ClockService.snoozeOptions.indexOf(newAlarmModal.draftSnoozeMin))
                                    onSelectionChanged: (idx, sel) => {
                                        if (sel && idx >= 0 && idx < ClockService.snoozeOptions.length)
                                            newAlarmModal.draftSnoozeMin = ClockService.snoozeOptions[idx];
                                    }
                                }

                                SettingsSliderRow {
                                    iconName: "volume_up"
                                    text: "Alarm volume"
                                    description: `Playback level (${newAlarmModal.draftVolume}%)`
                                    minimum: 0
                                    maximum: 100
                                    step: 5
                                    unit: "%"
                                    value: newAlarmModal.draftVolume
                                    onSliderValueChanged: v => newAlarmModal.draftVolume = v
                                }

                                SettingsToggleRow {
                                    visible: newAlarmModal.draftDays.length === 0
                                    iconName: "auto_delete"
                                    text: "Delete after goes off"
                                    description: "Remove this one-time alarm automatically after it rings"
                                    checked: newAlarmModal.draftDeleteAfter
                                    onToggled: chk => newAlarmModal.draftDeleteAfter = chk
                                }
                            }
                        }

                        // Footer Actions (Full-width custom grouped buttons with icons)
                        Row {
                            Layout.fillWidth: true
                            height: Theme.buttonHeightM + 4
                            spacing: Theme.spacingXS

                            readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                            readonly property real innerR: Theme.groupedListInnerRadius ?? 4
                            readonly property real btnW: Math.floor((width - spacing) / 2)

                            Rectangle {
                                width: parent.btnW
                                height: parent.height
                                topLeftRadius: parent.outerR
                                bottomLeftRadius: parent.outerR
                                topRightRadius: cancelMouse.containsMouse ? parent.outerR : parent.innerR
                                bottomRightRadius: cancelMouse.containsMouse ? parent.outerR : parent.innerR
                                color: cancelMouse.containsMouse ? Theme.withAlpha(Theme.error, 0.28) : Theme.withAlpha(Theme.error, 0.16)
                                border.width: 1
                                border.color: Theme.error
                                scale: cancelMouse.pressed ? 0.98 : (cancelMouse.containsMouse ? 1.01 : 1.0)
                                clip: true

                                Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                DRipple { id: cancelRipple; anchors.fill: parent; rippleColor: Theme.error }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    DIcon {
                                        name: "close"
                                        size: 18
                                        color: Theme.error
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: "Cancel"
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.error
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: cancelMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: mouse => cancelRipple.trigger(mouse.x, mouse.y)
                                    onClicked: newAlarmModal.hide()
                                }
                            }

                            Rectangle {
                                width: parent.width - parent.btnW - parent.spacing
                                height: parent.height
                                topLeftRadius: createMouse.containsMouse ? parent.outerR : parent.innerR
                                bottomLeftRadius: createMouse.containsMouse ? parent.outerR : parent.innerR
                                topRightRadius: parent.outerR
                                bottomRightRadius: parent.outerR
                                color: createMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.28) : Theme.withAlpha(Theme.primary, 0.18)
                                border.width: 1
                                border.color: Theme.primary
                                scale: createMouse.pressed ? 0.98 : (createMouse.containsMouse ? 1.01 : 1.0)
                                clip: true

                                Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                DRipple { id: createRipple; anchors.fill: parent; rippleColor: Theme.primary }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    DIcon {
                                        name: "add_alarm"
                                        size: 18
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: "Create Alarm"
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.DemiBold
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: createMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: mouse => createRipple.trigger(mouse.x, mouse.y)
                                    onClicked: newAlarmModal.submitAlarm()
                                }
                            }
                        }
                    }
                }
            }
        }

        DWindowHeader {
            id: header
            readonly property bool integrated: true
            anchors.right: parent.right
            width: buttonsReserve
            controls: windowControls
            title: ""
            onCloseRequested: newAlarmModal.hide()
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: newAlarmModal
    }
}
