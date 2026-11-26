import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets
import qs.Widgets

FloatingWindow {
    id: newReminderModal

    property int draftHour: 9
    property int draftMinute: 0
    property string draftDate: ""
    property string draftRepeat: "none"
    property bool draftImportant: false
    property bool editingTimeText: false
    property bool editingDateText: false
    property bool minuteMode: false
    property bool draggingDial: false

    readonly property string formattedDateDisplay: {
        const parts = (draftDate || "").split("-");
        if (parts.length === 3) {
            const d = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
            if (!isNaN(d.getTime()))
                return Qt.formatDate(d, "dd / MMM / yy");
        }
        return Qt.formatDate(ClockService.now || new Date(), "dd / MMM / yy");
    }

    readonly property bool is24Hour: SettingsData.use24HourClock
    readonly property bool isPm: draftHour >= 12
    readonly property real dialSize: Math.min(236, Math.max(180, leftPanel.width - Theme.spacingXL * 2))
    readonly property real outerRingRadius: dialSize * Style.clockOuterRingRatio
    readonly property real innerRingRadius: dialSize * Style.clockInnerRingRatio
    readonly property real numberSize: Style.clockHandleSize
    readonly property real handAngle: minuteMode ? draftMinute * 6 : (draftHour % 12) * 30
    readonly property real handLength: (!minuteMode && is24Hour && (draftHour === 0 || draftHour > 12)) ? innerRingRadius : outerRingRadius

    readonly property var timeParts: ClockService.formatClockParts(draftHour, draftMinute)
    readonly property var repeatOptions: [
        { key: "none", label: "Once" },
        { key: "daily", label: "Daily" },
        { key: "weekdays", label: "Weekdays" },
        { key: "weekly", label: "Weekly" },
        { key: "monthly", label: "Monthly" }
    ]

    function _dateOffsetKey(days) {
        const d = new Date((ClockService.now || new Date()).getTime() + days * 86400000);
        return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    }

    function pad2(v) {
        return (v < 10 ? "0" : "") + v;
    }

    function loadDraft() {
        const idx = ClockService.editingReminderIndex;
        if (idx >= 0 && idx < ClockService.reminders.length) {
            const r = ClockService.reminders[idx];
            draftHour = r.hour;
            draftMinute = r.minute;
            draftDate = r.date || ClockService._todayDateKey();
            draftRepeat = r.repeat || "none";
            draftImportant = Boolean(r.important);
            titleField.text = r.title || "";
        } else {
            const now = ClockService.now || new Date();
            draftHour = now.getHours();
            draftMinute = now.getMinutes();
            draftDate = ClockService._todayDateKey();
            draftRepeat = "none";
            draftImportant = false;
            titleField.text = "";
        }
        draftDate = draftDate || ClockService._todayDateKey();
        editingTimeText = false;
        editingDateText = false;
        minuteMode = false;
        draggingDial = false;
    }

    function beginDateEdit() {
        editingDateText = true;
        dateTextInput.text = draftDate;
        dateTextInput.forceActiveFocus();
        dateTextInput.selectAll();
    }

    function commitDateEdit() {
        if (!editingDateText)
            return;
        const raw = (dateTextInput.text || "").trim();
        editingDateText = false;
        if (/^\d{4}-\d{2}-\d{2}$/.test(raw))
            draftDate = raw;
    }

    function show() {
        loadDraft();
        visible = true;
    }

    function hide() {
        editingTimeText = false;
        visible = false;
        ClockService.reminderEditSheetOpen = false;
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
        } else if (!(h > 12 && h <= 23 && !hasAm && !hasPm)) {
            h = Math.max(1, Math.min(12, h));
            const nextPm = hasPm ? true : (hasAm ? false : isPm);
            if (nextPm && h < 12)
                h += 12;
            else if (!nextPm && h === 12)
                h = 0;
        }
        draftHour = h;
        draftMinute = m;
    }

    function submitReminder() {
        if (editingTimeText)
            commitTimeEdit();
        if (editingDateText)
            commitDateEdit();
        const title = titleField.text.trim() || "Reminder";
        const dateKey = draftDate || ClockService._todayDateKey();
        const payload = {
            title: title,
            date: dateKey,
            hour: draftHour,
            minute: draftMinute,
            repeat: draftRepeat,
            important: draftImportant,
            enabled: true
        };
        if (ClockService.editingReminderIndex >= 0)
            ClockService.updateReminder(ClockService.editingReminderIndex, payload);
        else
            ClockService.addReminder(payload);
        hide();
    }

    onClosed: hide()

    Timer {
        id: advanceMinuteTimer
        interval: 220
        onTriggered: newReminderModal.minuteMode = true
    }

    Timer {
        id: outsideClickTimer
        interval: 80
        onTriggered: {
            if (newReminderModal.visible && !rootFocusScope.activeFocus && !calendarPopup.opened && !repeatDropdown.menuOpen)
                newReminderModal.hide();
        }
    }

    WindowBlur {
        targetWindow: newReminderModal
        blurEnabled: Theme.translucentWindows
        blurWidth: newReminderModal.width
        blurHeight: newReminderModal.height
    }

    title: ClockService.editingReminderIndex >= 0 ? "Edit Reminder" : "New Reminder"
    minimumSize: Qt.size(720, 500)
    implicitWidth: screen ? Math.min(920, screen.width - Theme.spacingXL * 2) : 920
    implicitHeight: screen ? Math.min(620, screen.height - Theme.spacingXL * 2) : 620
    color: Theme.windowSurface
    surfaceFormat.opaque: false
    visible: false

    Connections {
        target: ClockService
        function onReminderEditSheetOpenChanged() {
            if (ClockService.reminderEditSheetOpen)
                newReminderModal.show();
            else
                newReminderModal.hide();
        }
    }

    FocusScope {
        id: rootFocusScope
        anchors.fill: parent
        focus: true

        onActiveFocusChanged: {
            if (newReminderModal.visible && !activeFocus)
                outsideClickTimer.restart();
            else
                outsideClickTimer.stop();
        }

        readonly property bool isFloatingWindowSurface: true
        readonly property color surfaceColor: newReminderModal.color

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (calendarPopup.opened) {
                    calendarPopup.close();
                    rootFocusScope.forceActiveFocus();
                } else if (newReminderModal.editingTimeText) {
                    newReminderModal.editingTimeText = false;
                } else if (newReminderModal.editingDateText) {
                    newReminderModal.editingDateText = false;
                } else {
                    newReminderModal.hide();
                }
                event.accepted = true;
            }
        }

        Item {
            anchors.fill: parent

            // Left Panel: Visual Clock + Keyboard Time Input
            Item {
                id: leftPanel
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(280, Math.min(340, parent.width * 0.40))

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
                    spacing: Theme.spacingM

                    Item { Layout.fillHeight: true }

                    // Date Selector Above Clock (DD / MMM / YY pill + Calendar Popup)
                    Row {
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.spacingS
                        Layout.rightMargin: Theme.spacingS
                        spacing: Theme.spacingXS

                        Rectangle {
                            id: datePill
                            width: parent.width - calBtn.width - Theme.spacingXS
                            height: 40
                            radius: Theme.groupedListOuterRadius ?? 16
                            color: newReminderModal.editingDateText
                                ? Theme.surfaceContainerLowest
                                : (datePillMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.16) : Theme.surfaceContainerHigh)
                            border.width: 1
                            border.color: (newReminderModal.editingDateText || datePillMouse.containsMouse) ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                            anchors.verticalCenter: parent.verticalCenter

                            Row {
                                visible: !newReminderModal.editingDateText
                                anchors.centerIn: parent
                                spacing: 6

                                DIcon {
                                    name: "calendar_today"
                                    size: 15
                                    color: datePillMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: newReminderModal.formattedDateDisplay
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.DemiBold
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            TextInput {
                                id: dateTextInput
                                visible: newReminderModal.editingDateText
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingS
                                horizontalAlignment: TextInput.AlignHCenter
                                verticalAlignment: TextInput.AlignVCenter
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                                selectByMouse: true
                                clip: true
                                onActiveFocusChanged: {
                                    if (!activeFocus && newReminderModal.editingDateText)
                                        newReminderModal.commitDateEdit();
                                }
                                Keys.onReturnPressed: newReminderModal.commitDateEdit()
                                Keys.onEnterPressed: newReminderModal.commitDateEdit()
                                Keys.onEscapePressed: event => {
                                    newReminderModal.editingDateText = false;
                                    event.accepted = true;
                                }
                            }

                            MouseArea {
                                id: datePillMouse
                                anchors.fill: parent
                                enabled: !newReminderModal.editingDateText
                                hoverEnabled: true
                                cursorShape: newReminderModal.editingDateText ? Qt.IBeamCursor : Qt.PointingHandCursor
                                onClicked: newReminderModal.beginDateEdit()
                            }
                        }

                        DIconButton {
                            id: calBtn
                            iconName: "calendar_month"
                            variant: "tonal"
                            size: "s"
                            tooltipText: "Open calendar"
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: calendarPopup.open()
                        }
                    }

                    Popup {
                        id: calendarPopup
                        parent: Overlay.overlay
                        anchors.centerIn: parent
                        width: 316
                        height: 330
                        modal: true
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                        padding: Theme.spacingM
                        onClosed: rootFocusScope.forceActiveFocus()
                        background: Rectangle {
                            radius: Theme.cornerRadiusXL
                            color: Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: Theme.outlineMedium
                        }

                        property int viewYear: (ClockService.now || new Date()).getFullYear()
                        property int viewMonth: (ClockService.now || new Date()).getMonth()
                        property string pickerMode: "days" // "days" | "months" | "years"

                        Column {
                            anchors.fill: parent
                            spacing: Theme.spacingS

                            Row {
                                width: parent.width
                                height: 34
                                spacing: 4

                                DIconButton {
                                    iconName: "chevron_left"
                                    variant: "standard"
                                    size: "s"
                                    anchors.verticalCenter: parent.verticalCenter
                                    onClicked: {
                                        if (calendarPopup.viewMonth === 0) {
                                            calendarPopup.viewMonth = 11;
                                            calendarPopup.viewYear--;
                                        } else {
                                            calendarPopup.viewMonth--;
                                        }
                                    }
                                }

                                DButton {
                                    text: Qt.formatDate(new Date(calendarPopup.viewYear, calendarPopup.viewMonth, 1), "MMM")
                                    buttonHeight: Theme.buttonHeightXXS
                                    backgroundColor: calendarPopup.pickerMode === "months" ? Theme.primaryContainer : Theme.surfaceContainerHighest
                                    textColor: calendarPopup.pickerMode === "months" ? Theme.onPrimaryContainer : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                    onClicked: calendarPopup.pickerMode = (calendarPopup.pickerMode === "months" ? "days" : "months")
                                }

                                DButton {
                                    text: String(calendarPopup.viewYear)
                                    buttonHeight: Theme.buttonHeightXXS
                                    backgroundColor: calendarPopup.pickerMode === "years" ? Theme.primaryContainer : Theme.surfaceContainerHighest
                                    textColor: calendarPopup.pickerMode === "years" ? Theme.onPrimaryContainer : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                    onClicked: calendarPopup.pickerMode = (calendarPopup.pickerMode === "years" ? "days" : "years")
                                }

                                Item { width: Math.max(0, parent.width - 180); height: 1 }

                                DIconButton {
                                    iconName: "chevron_right"
                                    variant: "standard"
                                    size: "s"
                                    anchors.verticalCenter: parent.verticalCenter
                                    onClicked: {
                                        if (calendarPopup.viewMonth === 11) {
                                            calendarPopup.viewMonth = 0;
                                            calendarPopup.viewYear++;
                                        } else {
                                            calendarPopup.viewMonth++;
                                        }
                                    }
                                }
                            }

                            DMonthGrid {
                                visible: calendarPopup.pickerMode === "days"
                                width: parent.width
                                height: parent.height - 42
                                displayDate: new Date(calendarPopup.viewYear, calendarPopup.viewMonth, 1)
                                onDayClicked: date => {
                                    const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
                                    newReminderModal.draftDate = key;
                                    calendarPopup.pickerMode = "days";
                                    calendarPopup.close();
                                }
                            }

                            Grid {
                                visible: calendarPopup.pickerMode === "months"
                                width: parent.width
                                height: parent.height - 42
                                columns: 3
                                spacing: 4
                                Repeater {
                                    model: 12
                                    DButton {
                                        required property int index
                                        width: Math.floor((parent.width - 8) / 3)
                                        buttonHeight: 48
                                        text: Qt.formatDate(new Date(2026, index, 1), "MMM")
                                        backgroundColor: calendarPopup.viewMonth === index ? Theme.primaryContainer : Theme.surfaceContainer
                                        textColor: calendarPopup.viewMonth === index ? Theme.onPrimaryContainer : Theme.surfaceText
                                        onClicked: {
                                            calendarPopup.viewMonth = index;
                                            calendarPopup.pickerMode = "days";
                                        }
                                    }
                                }
                            }

                            Grid {
                                visible: calendarPopup.pickerMode === "years"
                                width: parent.width
                                height: parent.height - 42
                                columns: 3
                                spacing: 4
                                Repeater {
                                    model: 12
                                    DButton {
                                        required property int index
                                        readonly property int yr: (ClockService.now || new Date()).getFullYear() - 2 + index
                                        width: Math.floor((parent.width - 8) / 3)
                                        buttonHeight: 48
                                        text: String(yr)
                                        backgroundColor: calendarPopup.viewYear === yr ? Theme.primaryContainer : Theme.surfaceContainer
                                        textColor: calendarPopup.viewYear === yr ? Theme.onPrimaryContainer : Theme.surfaceText
                                        onClicked: {
                                            calendarPopup.viewYear = yr;
                                            calendarPopup.pickerMode = "days";
                                        }
                                    }
                                }
                            }
                        }
                    }

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
                            currentIndex: newReminderModal.minuteMode ? 1 : 0
                            onSelectionChanged: (idx, sel) => {
                                if (sel)
                                    newReminderModal.minuteMode = (idx === 1);
                            }
                        }

                        DButtonGroup {
                            visible: !newReminderModal.is24Hour
                            size: "small"
                            selectionMode: "single"
                            checkEnabled: false
                            minButtonWidth: 40
                            buttonPadding: Theme.spacingXS
                            model: ["AM", "PM"]
                            currentIndex: newReminderModal.isPm ? 1 : 0
                            onSelectionChanged: (idx, sel) => {
                                if (!sel)
                                    return;
                                const base = newReminderModal.draftHour % 12;
                                newReminderModal.draftHour = idx === 1 ? base + 12 : base;
                            }
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: newReminderModal.dialSize
                        Layout.preferredHeight: newReminderModal.dialSize
                        radius: width / 2
                        color: Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: Theme.outlineMedium ?? Theme.outlineVariant

                        Item {
                            x: newReminderModal.dialSize / 2 - width / 2
                            y: newReminderModal.dialSize / 2
                            width: Style.clockHandWidth
                            height: newReminderModal.handLength
                            transformOrigin: Item.Top
                            rotation: newReminderModal.handAngle + 180

                            Behavior on rotation {
                                enabled: Theme.animationsEnabled && !newReminderModal.draggingDial
                                RotationAnimation { direction: RotationAnimation.Shortest; duration: 180; easing.type: Easing.OutCubic }
                            }
                            Behavior on height {
                                enabled: Theme.animationsEnabled && !newReminderModal.draggingDial
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }

                            Rectangle { anchors.fill: parent; color: Theme.primary; radius: width / 2 }
                            Rectangle {
                                width: newReminderModal.numberSize
                                height: newReminderModal.numberSize
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
                            model: newReminderModal.minuteMode ? 12 : (newReminderModal.is24Hour ? 24 : 12)

                            Item {
                                required property int index
                                readonly property bool innerRing: !newReminderModal.minuteMode && newReminderModal.is24Hour && index >= 12
                                readonly property int step: index % 12
                                readonly property int value: newReminderModal.minuteMode ? step * 5 : (innerRing ? (step === 0 ? 0 : step + 12) : (step === 0 ? 12 : step))
                                readonly property bool selected: newReminderModal.minuteMode
                                    ? (newReminderModal.draftMinute === value)
                                    : (newReminderModal.is24Hour ? newReminderModal.draftHour === value : (newReminderModal.draftHour % 12) === (value % 12))
                                readonly property real ringRadius: innerRing ? newReminderModal.innerRingRadius : newReminderModal.outerRingRadius
                                readonly property real angle: (step * 30 - 90) * Math.PI / 180

                                width: newReminderModal.numberSize
                                height: newReminderModal.numberSize
                                x: newReminderModal.dialSize / 2 + ringRadius * Math.cos(angle) - width / 2
                                y: newReminderModal.dialSize / 2 + ringRadius * Math.sin(angle) - height / 2

                                NumericText {
                                    anchors.centerIn: parent
                                    text: newReminderModal.minuteMode || parent.innerRing ? newReminderModal.pad2(parent.value) : parent.value
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
                                newReminderModal.draggingDial = true;
                                newReminderModal.applyDialPoint(mouse.x, mouse.y);
                            }
                            onPositionChanged: mouse => {
                                if (!pressed)
                                    return;
                                newReminderModal.applyDialPoint(mouse.x, mouse.y);
                            }
                            onReleased: {
                                newReminderModal.draggingDial = false;
                                if (!newReminderModal.minuteMode)
                                    advanceMinuteTimer.restart();
                            }
                        }
                    }

                    Rectangle {
                        id: timePill
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.spacingS
                        Layout.rightMargin: Theme.spacingS
                        Layout.preferredHeight: 58
                        radius: Theme.groupedListOuterRadius ?? 16
                        color: newReminderModal.editingTimeText
                            ? Theme.surfaceContainerLowest
                            : (timePillMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.16) : Theme.surfaceContainerHigh)
                        border.width: 1
                        border.color: (newReminderModal.editingTimeText || timePillMouse.containsMouse) ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                        Row {
                            visible: !newReminderModal.editingTimeText
                            anchors.centerIn: parent
                            spacing: 6

                            DIcon {
                                name: "keyboard"
                                size: Theme.iconSizeSmall
                                color: timePillMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            NumericText {
                                text: newReminderModal.timeParts.timeText
                                font.pixelSize: Theme.fontSizeDisplay
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                visible: newReminderModal.timeParts.meridiem !== ""
                                text: newReminderModal.timeParts.meridiem
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeightBold
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        TextInput {
                            id: timeTextInput
                            visible: newReminderModal.editingTimeText
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingM
                            anchors.rightMargin: Theme.spacingM
                            horizontalAlignment: TextInput.AlignHCenter
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: Theme.fontSizeDisplay
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            selectByMouse: true
                            clip: true
                            onActiveFocusChanged: {
                                if (!activeFocus && newReminderModal.editingTimeText)
                                    newReminderModal.commitTimeEdit();
                            }
                            Keys.onReturnPressed: newReminderModal.commitTimeEdit()
                            Keys.onEnterPressed: newReminderModal.commitTimeEdit()
                            Keys.onEscapePressed: event => {
                                newReminderModal.editingTimeText = false;
                                event.accepted = true;
                            }
                        }

                        MouseArea {
                            id: timePillMouse
                            anchors.fill: parent
                            enabled: !newReminderModal.editingTimeText
                            hoverEnabled: true
                            cursorShape: newReminderModal.editingTimeText ? Qt.IBeamCursor : Qt.PointingHandCursor
                            onClicked: newReminderModal.beginTimeEdit()
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // Right Panel: Details + Grouped Footer Buttons
            FocusScope {
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
                            iconName: "notifications"

                            SettingsRow {
                                iconName: "edit_note"
                                title: "Title"
                                subtitle: "What should we remind you about?"

                                DTextField {
                                    id: titleField
                                    width: 220
                                    placeholderText: "e.g., Drink water"
                                    Keys.onReturnPressed: newReminderModal.submitReminder()
                                    Keys.onEnterPressed: newReminderModal.submitReminder()
                                }
                            }

                            SettingsRow {
                                iconName: "repeat"
                                title: "Repeat"
                                subtitle: "How often this reminder repeats"

                                DDropdown {
                                    id: repeatDropdown
                                    width: 170
                                    options: newReminderModal.repeatOptions.map(o => o.label)
                                    optionValues: newReminderModal.repeatOptions.map(o => o.key)
                                    currentValue: newReminderModal.draftRepeat
                                    onMenuOpenChanged: {
                                        if (!menuOpen && newReminderModal.visible && !rootFocusScope.activeFocus)
                                            outsideClickTimer.restart();
                                    }
                                    onValueChanged: val => {
                                        if (val)
                                            newReminderModal.draftRepeat = val;
                                    }
                                }
                            }

                            SettingsToggleRow {
                                iconName: "star"
                                text: "Important"
                                description: "Show in the Important reminders panel"
                                checked: newReminderModal.draftImportant
                                onToggled: chk => newReminderModal.draftImportant = chk
                            }
                        }
                    }

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
                            topRightRadius: (cancelMouse.pressed || cancelMouse.containsMouse) ? parent.outerR : parent.innerR
                            bottomRightRadius: (cancelMouse.pressed || cancelMouse.containsMouse) ? parent.outerR : parent.innerR
                            color: cancelMouse.containsMouse ? Theme.withAlpha(Theme.error, 0.28) : Theme.withAlpha(Theme.error, 0.16)
                            border.width: 1
                            border.color: Theme.error
                            scale: cancelMouse.pressed ? 0.98 : 1.0
                            clip: true

                            Behavior on topRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on bottomRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            DRipple { id: cancelRipple; anchors.fill: parent; rippleColor: Theme.error }

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS
                                DIcon { name: "close"; size: 18; color: Theme.error; anchors.verticalCenter: parent.verticalCenter }
                                StyledText { text: "Cancel"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.error; anchors.verticalCenter: parent.verticalCenter }
                            }

                            MouseArea {
                                id: cancelMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => cancelRipple.trigger(mouse.x, mouse.y)
                                onClicked: newReminderModal.hide()
                            }
                        }

                        Rectangle {
                            width: parent.width - parent.btnW - parent.spacing
                            height: parent.height
                            topLeftRadius: (saveMouse.pressed || saveMouse.containsMouse) ? parent.outerR : parent.innerR
                            bottomLeftRadius: (saveMouse.pressed || saveMouse.containsMouse) ? parent.outerR : parent.innerR
                            topRightRadius: parent.outerR
                            bottomRightRadius: parent.outerR
                            color: saveMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.28) : Theme.withAlpha(Theme.primary, 0.18)
                            border.width: 1
                            border.color: Theme.primary
                            scale: saveMouse.pressed ? 0.98 : 1.0
                            clip: true

                            Behavior on topLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on bottomLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            DRipple { id: saveRipple; anchors.fill: parent; rippleColor: Theme.primary }

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS
                                DIcon { name: "add_alert"; size: 18; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                StyledText { text: ClockService.editingReminderIndex >= 0 ? "Save" : "Add Reminder"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.DemiBold; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            }

                            MouseArea {
                                id: saveMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => saveRipple.trigger(mouse.x, mouse.y)
                                onClicked: newReminderModal.submitReminder()
                            }
                        }
                    }
                }
            }
        }
    }
}
