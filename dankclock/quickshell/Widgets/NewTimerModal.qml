import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets
import qs.Widgets

FloatingWindow {
    id: newTimerModal

    property int draftHours: 0
    property int draftMinutes: 5
    property int draftSeconds: 0
    property bool editingTimeText: false

    readonly property int totalSeconds: draftHours * 3600 + draftMinutes * 60 + draftSeconds
    readonly property string formattedTime: {
        const h = String(draftHours).padStart(2, "0");
        const m = String(draftMinutes).padStart(2, "0");
        const s = String(draftSeconds).padStart(2, "0");
        return draftHours > 0 ? `${h}:${m}:${s}` : `${m}:${s}`;
    }

    readonly property var quickPresets: [
        { label: "1m", sec: 60 },
        { label: "3m", sec: 180 },
        { label: "5m", sec: 300 },
        { label: "10m", sec: 600 },
        { label: "15m", sec: 900 },
        { label: "25m", sec: 1500 },
        { label: "45m", sec: 2700 }
    ]

    function resetDraft() {
        draftHours = 0;
        draftMinutes = 5;
        draftSeconds = 0;
        editingTimeText = false;
        timerLabelField.text = "";
    }

    function show() {
        resetDraft();
        visible = true;
    }

    function hide() {
        editingTimeText = false;
        visible = false;
        ClockService.newTimerModalOpen = false;
    }

    function beginTimeEdit() {
        editingTimeText = true;
        timeTextInput.text = formattedTime;
        timeTextInput.forceActiveFocus();
        timeTextInput.selectAll();
    }

    function commitTimeEdit() {
        if (!editingTimeText)
            return;
        const raw = (timeTextInput.text || "").trim();
        editingTimeText = false;
        if (!raw)
            return;

        const cleaned = raw.replace(/[^0-9:]/g, "");
        let h = 0;
        let m = 0;
        let s = 0;

        if (cleaned.indexOf(":") >= 0) {
            const parts = cleaned.split(":").map(p => parseInt(p, 10) || 0);
            if (parts.length >= 3) {
                h = parts[0];
                m = parts[1];
                s = parts[2];
            } else if (parts.length === 2) {
                m = parts[0];
                s = parts[1];
            }
        } else {
            const num = parseInt(cleaned, 10);
            if (isNaN(num))
                return;
            if (cleaned.length <= 2) {
                m = num;
            } else if (cleaned.length <= 4) {
                m = Math.floor(num / 100);
                s = num % 100;
            } else {
                h = Math.floor(num / 10000);
                m = Math.floor((num % 10000) / 100);
                s = num % 100;
            }
        }

        draftHours = Math.max(0, Math.min(23, h));
        draftMinutes = Math.max(0, Math.min(59, m));
        draftSeconds = Math.max(0, Math.min(59, s));
    }

    function submitTimer() {
        if (editingTimeText)
            commitTimeEdit();
        if (totalSeconds <= 0)
            return;
        ClockService.createAndStartTimer(totalSeconds, timerLabelField.text);
    }

    onClosed: hide()

    Timer {
        id: outsideClickTimer
        interval: 80
        onTriggered: {
            if (newTimerModal.visible && !rootFocusScope.activeFocus)
                newTimerModal.hide();
        }
    }

    WindowBlur {
        targetWindow: newTimerModal
        blurEnabled: Theme.translucentWindows
        blurWidth: newTimerModal.width
        blurHeight: newTimerModal.height
    }

    title: "New Timer"
    minimumSize: Qt.size(640, 440)
    implicitWidth: screen ? Math.min(820, screen.width - Theme.spacingXL * 2) : 820
    implicitHeight: screen ? Math.min(540, screen.height - Theme.spacingXL * 2) : 540
    color: Theme.windowSurface
    surfaceFormat.opaque: false
    visible: false

    Connections {
        target: ClockService
        function onNewTimerModalOpenChanged() {
            if (ClockService.newTimerModalOpen)
                newTimerModal.show();
            else
                newTimerModal.hide();
        }
    }

    FocusScope {
        id: rootFocusScope
        anchors.fill: parent
        focus: true

        onActiveFocusChanged: {
            if (newTimerModal.visible && !activeFocus)
                outsideClickTimer.restart();
            else
                outsideClickTimer.stop();
        }

        readonly property bool isFloatingWindowSurface: true
        readonly property color surfaceColor: newTimerModal.color

        LayoutMirroring.enabled: I18n.isRtl
        LayoutMirroring.childrenInherit: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (newTimerModal.editingTimeText)
                    newTimerModal.editingTimeText = false;
                else
                    newTimerModal.hide();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (newTimerModal.totalSeconds > 0) {
                    newTimerModal.submitTimer();
                    event.accepted = true;
                }
            }
        }

        Column {
            anchors.fill: parent
            topPadding: 0
            spacing: 0

            Item {
                width: parent.width
                height: parent.height

                // Left Panel: Visual Duration Steppers + Keyboard Time Field
                Item {
                    id: leftPanel
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(280, Math.min(340, parent.width * 0.42))

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

                        // Visual Steppers (Hours / Minutes / Seconds)
                        Row {
                            id: stepperRow
                            Layout.fillWidth: true
                            Layout.leftMargin: Theme.spacingS
                            Layout.rightMargin: Theme.spacingS
                            spacing: Theme.spacingXS

                            readonly property real cardW: Math.floor((width - spacing * 2) / 3)

                            Repeater {
                                model: [
                                    { title: "HRS", value: newTimerModal.draftHours, max: 23, step: 1, key: "h" },
                                    { title: "MIN", value: newTimerModal.draftMinutes, max: 59, step: 1, key: "m" },
                                    { title: "SEC", value: newTimerModal.draftSeconds, max: 59, step: 5, key: "s" }
                                ]

                                Rectangle {
                                    id: sCard
                                    required property var modelData
                                    required property int index

                                    readonly property bool isFirst: index === 0
                                    readonly property bool isLast: index === 2
                                    readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                                    readonly property real innerR: Theme.groupedListInnerRadius ?? 4

                                    width: stepperRow.cardW
                                    height: 152
                                    topLeftRadius: sHover.hovered ? outerR : (isFirst ? outerR : innerR)
                                    bottomLeftRadius: sHover.hovered ? outerR : (isFirst ? outerR : innerR)
                                    topRightRadius: sHover.hovered ? outerR : (isLast ? outerR : innerR)
                                    bottomRightRadius: sHover.hovered ? outerR : (isLast ? outerR : innerR)
                                    color: sHover.hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                    border.width: 1
                                    border.color: sHover.hovered ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                                    HoverHandler { id: sHover }

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: Theme.spacingXS

                                        StyledText {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: sCard.modelData.title
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Bold
                                            color: Theme.primary
                                        }

                                        DNumberStepper {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: String(sCard.modelData.value).padStart(2, "0")
                                            textSize: Theme.fontSizeXLarge
                                            buttonSize: Theme.buttonHeightXS
                                            incrementEnabled: sCard.modelData.value <= sCard.modelData.max - sCard.modelData.step
                                            decrementEnabled: sCard.modelData.value > 0
                                            onIncrement: () => {
                                                if (sCard.modelData.key === "h")
                                                    newTimerModal.draftHours = Math.min(23, newTimerModal.draftHours + 1);
                                                else if (sCard.modelData.key === "m")
                                                    newTimerModal.draftMinutes = Math.min(59, newTimerModal.draftMinutes + 1);
                                                else
                                                    newTimerModal.draftSeconds = Math.min(59, newTimerModal.draftSeconds + 5);
                                            }
                                            onDecrement: () => {
                                                if (sCard.modelData.key === "h")
                                                    newTimerModal.draftHours = Math.max(0, newTimerModal.draftHours - 1);
                                                else if (sCard.modelData.key === "m")
                                                    newTimerModal.draftMinutes = Math.max(0, newTimerModal.draftMinutes - 1);
                                                else
                                                    newTimerModal.draftSeconds = Math.max(0, newTimerModal.draftSeconds - 5);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Clickable Time Text Field Below for Keyboard Input
                        Rectangle {
                            id: timePill
                            Layout.fillWidth: true
                            Layout.leftMargin: Theme.spacingS
                            Layout.rightMargin: Theme.spacingS
                            Layout.preferredHeight: 62
                            radius: Theme.groupedListOuterRadius ?? 16
                            color: newTimerModal.editingTimeText
                                ? Theme.surfaceContainerLowest
                                : (timePillMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.16) : Theme.surfaceContainerHigh)
                            border.width: 1
                            border.color: (newTimerModal.editingTimeText || timePillMouse.containsMouse) ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                            Row {
                                visible: !newTimerModal.editingTimeText
                                anchors.centerIn: parent
                                spacing: 6

                                DIcon {
                                    name: "keyboard"
                                    size: Theme.iconSizeSmall
                                    color: timePillMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                NumericText {
                                    text: newTimerModal.formattedTime
                                    font.pixelSize: Theme.fontSizeDisplay
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            TextInput {
                                id: timeTextInput
                                visible: newTimerModal.editingTimeText
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
                                    if (!activeFocus && newTimerModal.editingTimeText)
                                        newTimerModal.commitTimeEdit();
                                }
                                Keys.onReturnPressed: newTimerModal.commitTimeEdit()
                                Keys.onEnterPressed: newTimerModal.commitTimeEdit()
                                Keys.onEscapePressed: event => {
                                    newTimerModal.editingTimeText = false;
                                    event.accepted = true;
                                }
                            }

                            MouseArea {
                                id: timePillMouse
                                anchors.fill: parent
                                enabled: !newTimerModal.editingTimeText
                                hoverEnabled: true
                                cursorShape: newTimerModal.editingTimeText ? Qt.IBeamCursor : Qt.PointingHandCursor
                                onClicked: newTimerModal.beginTimeEdit()
                            }

                            DTooltipHost {
                                target: timePill
                                hoverArea: timePillMouse
                                text: newTimerModal.editingTimeText ? "" : "Click to type custom duration"
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                // Right Panel: Details + Quick Presets + Grouped Footer Buttons
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

                            SettingsCard {
                                title: "Details"
                                iconName: "tune"

                                SettingsRow {
                                    iconName: "label"
                                    title: "Timer label"
                                    subtitle: "Optional name for this timer"

                                    DTextField {
                                        id: timerLabelField
                                        width: 220
                                        placeholderText: "e.g., Boil Eggs"
                                        Keys.onReturnPressed: newTimerModal.submitTimer()
                                        Keys.onEnterPressed: newTimerModal.submitTimer()
                                    }
                                }
                            }

                            SettingsCard {
                                title: "Quick Presets"
                                iconName: "bolt"

                                SettingsRow {
                                    iconName: "schedule"
                                    title: "Preset durations"
                                    subtitle: "Tap to fill duration"

                                    body: Row {
                                        id: modalPresetsRow
                                        width: parent.width
                                        height: 36
                                        spacing: 2

                                        Repeater {
                                            model: newTimerModal.quickPresets

                                            Rectangle {
                                                id: mpBtn
                                                required property var modelData
                                                required property int index

                                                readonly property bool active: newTimerModal.totalSeconds === modelData.sec
                                                readonly property bool isFirst: index === 0
                                                readonly property bool isLast: index === newTimerModal.quickPresets.length - 1
                                                readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                                                readonly property real innerR: Theme.groupedListInnerRadius ?? 4

                                                width: Math.floor((modalPresetsRow.width - modalPresetsRow.spacing * (newTimerModal.quickPresets.length - 1)) / newTimerModal.quickPresets.length)
                                                height: modalPresetsRow.height
                                                topLeftRadius: (active || mpMouse.containsMouse) ? outerR : (isFirst ? outerR : innerR)
                                                bottomLeftRadius: (active || mpMouse.containsMouse) ? outerR : (isFirst ? outerR : innerR)
                                                topRightRadius: (active || mpMouse.containsMouse) ? outerR : (isLast ? outerR : innerR)
                                                bottomRightRadius: (active || mpMouse.containsMouse) ? outerR : (isLast ? outerR : innerR)
                                                color: (active || mpMouse.containsMouse) ? Theme.withAlpha(Theme.primary, 0.2) : Theme.surfaceContainerHigh
                                                border.width: 1
                                                border.color: (active || mpMouse.containsMouse) ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                                                scale: mpMouse.pressed ? 0.95 : (mpMouse.containsMouse ? 1.03 : 1.0)
                                                clip: true

                                                Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                                DRipple { id: mpRipple; anchors.fill: parent; rippleColor: Theme.primary }

                                                StyledText {
                                                    anchors.centerIn: parent
                                                    text: mpBtn.modelData.label
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    font.weight: mpBtn.active ? Font.DemiBold : Font.Medium
                                                    color: (mpBtn.active || mpMouse.containsMouse) ? Theme.primary : Theme.surfaceText
                                                }

                                                MouseArea {
                                                    id: mpMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onPressed: mouse => mpRipple.trigger(mouse.x, mouse.y)
                                                    onClicked: {
                                                        const s = mpBtn.modelData.sec;
                                                        newTimerModal.draftHours = Math.floor(s / 3600);
                                                        newTimerModal.draftMinutes = Math.floor((s % 3600) / 60);
                                                        newTimerModal.draftSeconds = s % 60;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Full-width custom grouped buttons with icons
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
                                    onClicked: newTimerModal.hide()
                                }
                            }

                            Rectangle {
                                width: parent.width - parent.btnW - parent.spacing
                                height: parent.height
                                enabled: newTimerModal.totalSeconds > 0
                                opacity: enabled ? 1.0 : 0.45
                                topLeftRadius: startMouse.containsMouse ? parent.outerR : parent.innerR
                                bottomLeftRadius: startMouse.containsMouse ? parent.outerR : parent.innerR
                                topRightRadius: parent.outerR
                                bottomRightRadius: parent.outerR
                                color: startMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.28) : Theme.withAlpha(Theme.primary, 0.18)
                                border.width: 1
                                border.color: Theme.primary
                                scale: startMouse.pressed ? 0.98 : (startMouse.containsMouse ? 1.01 : 1.0)
                                clip: true

                                Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                DRipple { id: startRipple; anchors.fill: parent; rippleColor: Theme.primary }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    DIcon {
                                        name: "play_arrow"
                                        size: 18
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: "Start Timer"
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.DemiBold
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: startMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: mouse => startRipple.trigger(mouse.x, mouse.y)
                                    onClicked: newTimerModal.submitTimer()
                                }
                            }
                        }
                    }
                }
            }
        }

        DWindowHeader {
            id: header
            anchors.right: parent.right
            width: buttonsReserve
            controls: windowControls
            title: ""
            onCloseRequested: newTimerModal.hide()
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: newTimerModal
    }
}
