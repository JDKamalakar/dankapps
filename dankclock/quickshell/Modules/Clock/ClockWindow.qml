pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Common
import qs.DCommon.Widgets
import "."

FloatingWindow {
    id: window

    signal hideRequested

    function requestClose() {
        if (SettingsData.closeBehavior === "quit") {
            ClockService.requestQuit();
        } else {
            window.hideRequested();
        }
    }

    readonly property var navDestinations: [
        { icon: "alarm", text: "Alarms" },
        { icon: "public", text: "Clock" },
        {
            icon: "notifications",
            text: "Reminders",
            badgeCount: ClockService.activeReminderCount
        },
        {
            icon: "hourglass_empty",
            text: "Timers",
            badgeCount: ClockService.runningTimerCount
        },
        {
            icon: "psychology",
            text: "Pomodoro",
            badgeCount: ClockService.pomodoroRunning ? 1 : 0
        },
        {
            icon: "timer",
            text: "Stopwatch",
            badgeCount: ClockService.stopwatchRunning ? 1 : 0
        }
    ]

    title: `${ClockService.currentTabIndex === 6 ? "Settings" : (navDestinations[ClockService.currentTabIndex]?.text ?? "Clock")} — DUX Clock`
    minimumSize: Qt.size(ClockMetrics.windowMinWidth, ClockMetrics.windowMinHeight)
    implicitWidth: ClockMetrics.windowWidth
    implicitHeight: ClockMetrics.windowHeight
    color: Theme.windowSurface
    surfaceFormat.opaque: false
    visible: true

    FloatingWindowControls {
        id: windowControls
        targetWindow: window
    }

    WindowBlur {
        targetWindow: window
        blurEnabled: Theme.translucentWindows
        blurWidth: window.width
        blurHeight: window.height
    }

    Rectangle {
        id: rootContent
        anchors.fill: parent
        color: Theme.windowSurface
        focus: true

        // Critical for DCommon widgets (Style.isFloatingWindow(item)) to use elevated card surfaces
        readonly property bool isFloatingWindowSurface: true

        Component.onCompleted: {
            forceActiveFocus();
        }

        Keys.onPressed: event => {
            if (ClockService.citySheetOpen || ClockService.timePickerOpen || ClockService.labelDialogOpen || ClockService.settingsOpen)
                return;

            if (event.modifiers & Qt.ControlModifier) {
                switch (event.key) {
                case Qt.Key_1:
                    ClockService.currentTabIndex = 0;
                    event.accepted = true;
                    return;
                case Qt.Key_2:
                    ClockService.currentTabIndex = 1;
                    event.accepted = true;
                    return;
                case Qt.Key_3:
                    ClockService.currentTabIndex = 2;
                    event.accepted = true;
                    return;
                case Qt.Key_4:
                    ClockService.currentTabIndex = 3;
                    event.accepted = true;
                    return;
                case Qt.Key_5:
                    ClockService.currentTabIndex = 4;
                    event.accepted = true;
                    return;
                case Qt.Key_6:
                    ClockService.currentTabIndex = 5;
                    event.accepted = true;
                    return;
                case Qt.Key_7:
                case Qt.Key_Comma:
                    ClockService.settingsOpen = true;
                    event.accepted = true;
                    return;
                case Qt.Key_Q:
                    ClockService.requestQuit();
                    event.accepted = true;
                    return;
                case Qt.Key_W:
                    window.requestClose();
                    event.accepted = true;
                    return;
                }
            }

            if (ClockService.currentTabIndex === 3 && !ClockService.timerSetupMode) {
                if (event.key === Qt.Key_Space) {
                    ClockService.toggleTimer(ClockService.activeTimerIndex);
                    event.accepted = true;
                } else if (event.key === Qt.Key_R) {
                    ClockService.resetTimer(ClockService.activeTimerIndex);
                    event.accepted = true;
                }
            } else if (ClockService.currentTabIndex === 4) {
                if (event.key === Qt.Key_Space) {
                    ClockService.togglePomodoro();
                    event.accepted = true;
                } else if (event.key === Qt.Key_R) {
                    ClockService.resetPomodoro();
                    event.accepted = true;
                } else if (event.key === Qt.Key_S) {
                    ClockService.skipPomodoroPhase();
                    event.accepted = true;
                }
            } else if (ClockService.currentTabIndex === 5) {
                if (event.key === Qt.Key_Space) {
                    ClockService.toggleStopwatch();
                    event.accepted = true;
                } else if (event.key === Qt.Key_L) {
                    ClockService.lapStopwatch();
                    event.accepted = true;
                } else if (event.key === Qt.Key_R) {
                    ClockService.resetStopwatch();
                    event.accepted = true;
                }
            }
        }

        DWindowHeader {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            z: 10
            controls: windowControls
            title: "DUX Clock"
            onCloseRequested: window.requestClose()
        }

        Item {
            id: sidebar
            z: 50
            property bool _floatingRevealed: true
            readonly property bool _isHidden: SettingsData.sidebarFloating && !_floatingRevealed
            anchors.left: parent.left
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            width: SettingsData.sidebarFloating ? (_isHidden ? 16 : clockPrimaryNav.railWidth + Theme.spacingM * 2 + Theme.spacingS) : clockPrimaryNav.railWidth

            Behavior on width { enabled: Theme.animationsEnabled; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            HoverHandler {
                id: clockSidebarHover
                onHoveredChanged: {
                    if (hovered) {
                        sidebar._floatingRevealed = true;
                        clockHideTimer.stop();
                    } else if (SettingsData.sidebarFloating) {
                        clockHideTimer.restart();
                    }
                }
            }

            Timer {
                id: clockHideTimer
                interval: SettingsData.sidebarAutoHideMs || 1500
                onTriggered: {
                    if (SettingsData.sidebarFloating && !clockSidebarHover.hovered)
                        sidebar._floatingRevealed = false;
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 5
                height: 48
                radius: 2.5
                color: Theme.primary
                opacity: 0.75
                visible: SettingsData.sidebarFloating
                z: 5
            }

            Rectangle {
                visible: SettingsData.sidebarFloating
                opacity: sidebar._isHidden ? 0 : 1
                Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                anchors.fill: parent
                anchors.topMargin: Theme.spacingM
                anchors.bottomMargin: Theme.spacingM
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                radius: Theme.groupedListOuterRadius ?? 16
                color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.78)
                border.color: Theme.outlineMedium ?? Theme.outlineVariant
                border.width: 1
                clip: true
            }

            ColumnLayout {
                id: clockSidebarCol
                opacity: sidebar._isHidden ? 0 : 1
                Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                anchors.fill: parent
                anchors.topMargin: Theme.spacingM + (SettingsData.sidebarFloating ? 12 : 0)
                anchors.bottomMargin: Theme.spacingM + (SettingsData.sidebarFloating ? 12 : 0)
                anchors.leftMargin: SettingsData.sidebarFloating ? Theme.spacingL : Theme.spacingM
                anchors.rightMargin: SettingsData.sidebarFloating ? Theme.spacingL : 0
                spacing: Theme.spacingS

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: SettingsData.sidebarCentered ? Math.max(0, (clockSidebarCol.height - clockPrimaryNav.implicitHeight - clockBottomNav.implicitHeight - Theme.spacingS * 2) / 2) : 0
                    Behavior on Layout.preferredHeight {
                        enabled: Theme.animationsEnabled
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                }

                AppSidebarRail {
                    id: clockPrimaryNav
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    Layout.alignment: Qt.AlignTop
                    model: window.navDestinations
                    currentIndex: ClockService.currentTabIndex < 6 ? ClockService.currentTabIndex : -1
                    onActivated: index => {
                        ClockService.currentTabIndex = index;
                        rootContent.forceActiveFocus();
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                AppSidebarRail {
                    id: clockBottomNav
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    model: [{ icon: "settings", text: "Settings" }]
                    currentIndex: ClockService.settingsOpen ? 0 : -1
                    onActivated: {
                        ClockService.settingsOpen = true;
                        rootContent.forceActiveFocus();
                    }
                }
            }
        }

        // Main M3E Content Container Card (Rounded container adjacent to sidebar)
        Rectangle {
            id: contentScope
            anchors.left: SettingsData.sidebarFloating ? parent.left : sidebar.right
            anchors.leftMargin: Theme.spacingXS
            anchors.top: header.bottom
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingM
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spacingM
            radius: Theme.cornerRadiusXL
            color: ClockMetrics.paneColor
            border.width: Theme.layerOutlineWidth
            border.color: Theme.outlineMedium
            clip: true

            AlarmView {
                anchors.fill: parent
                visible: ClockService.currentTabIndex === 0
                enabled: ClockService.stateReady
            }

            WorldClockView {
                anchors.fill: parent
                visible: ClockService.currentTabIndex === 1
                enabled: ClockService.stateReady
            }

            ReminderView {
                anchors.fill: parent
                visible: ClockService.currentTabIndex === 2
                enabled: ClockService.stateReady
            }

            TimerView {
                anchors.fill: parent
                visible: ClockService.currentTabIndex === 3
                enabled: ClockService.stateReady
            }

            PomodoroView {
                anchors.fill: parent
                visible: ClockService.currentTabIndex === 4
                enabled: ClockService.stateReady
            }

            StopwatchView {
                anchors.fill: parent
                visible: ClockService.currentTabIndex === 5
            }

            // Settings handled by top-level FloatingWindow SettingsModal
        }

        // Built-in DTimePicker Modal for Creating / Editing Alarms
        DTimePicker {
            id: alarmTimePicker
            is24Hour: SettingsData.use24HourClock
            title: ClockService.editingAlarmIndex >= 0 ? "Edit Alarm Time" : "New Alarm Time"
            onAccepted: (h, m) => {
                ClockService.commitTimePicker(h, m);
                rootContent.forceActiveFocus();
            }
            onRejected: {
                ClockService.timePickerOpen = false;
                ClockService.editingAlarmIndex = -1;
                rootContent.forceActiveFocus();
            }
        }

        Connections {
            target: ClockService
            function onTimePickerOpenChanged() {
                if (ClockService.timePickerOpen) {
                    if (ClockService.editingAlarmIndex >= 0 && ClockService.editingAlarmIndex < ClockService.alarms.length) {
                        const a = ClockService.alarms[ClockService.editingAlarmIndex];
                        alarmTimePicker.hour = a.hour;
                        alarmTimePicker.minute = a.minute;
                    } else {
                        alarmTimePicker.hour = ClockService.now.getHours();
                        alarmTimePicker.minute = ClockService.now.getMinutes();
                    }
                    alarmTimePicker.open();
                } else if (alarmTimePicker.opened) {
                    alarmTimePicker.close();
                }
            }
        }

        // Add World Clock City Bottom Sheet
        DBottomSheet {
            id: citySheet
            opened: ClockService.citySheetOpen
            title: "Add World Clock City"
            sheetHeight: 440
            onDismissRequested: {
                ClockService.citySheetOpen = false;
                citySearchInput.text = "";
                rootContent.forceActiveFocus();
            }

            DSearchField {
                id: citySearchInput
                width: parent.width
                placeholderText: "Search city or country..."
            }

            DListView {
                id: cityCatalogList
                width: parent.width
                height: 290
                spacing: Style.groupedListGap
                clip: true

                readonly property var filteredCities: {
                    const q = (citySearchInput.text || "").trim().toLowerCase();
                    return ClockService.cityCatalog.filter(c => {
                        if (!q)
                            return true;
                        return c.city.toLowerCase().indexOf(q) >= 0 || c.country.toLowerCase().indexOf(q) >= 0;
                    });
                }

                model: filteredCities

                delegate: ClockRow {
                    id: cityItem
                    required property var modelData
                    required property int index

                    width: cityCatalogList.width
                    clickable: true
                    iconName: "public"
                    accent: "blue"
                    title: modelData.city
                    subtitle: modelData.country
                    isFirstInGroup: index === 0
                    isLastInGroup: index === cityCatalogList.filteredCities.length - 1
                    onClicked: {
                        ClockService.addWorldClock(modelData);
                        ClockService.citySheetOpen = false;
                        citySearchInput.text = "";
                        rootContent.forceActiveFocus();
                    }

                    NumericText {
                        text: ClockService.getCityTimeInfo(cityItem.modelData, ClockService.now).timeText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // Alarm Label Edit Bottom Sheet
        DBottomSheet {
            id: labelSheet
            opened: ClockService.labelDialogOpen
            title: "Alarm Label"
            onDismissRequested: {
                ClockService.labelDialogOpen = false;
                rootContent.forceActiveFocus();
            }

            onOpenedChanged: {
                if (opened && ClockService.editingLabelAlarmIndex >= 0 && ClockService.editingLabelAlarmIndex < ClockService.alarms.length) {
                    alarmLabelField.text = ClockService.alarms[ClockService.editingLabelAlarmIndex].label || "";
                    alarmLabelField.forceActiveFocus();
                }
            }

            DTextField {
                id: alarmLabelField
                width: parent.width
                placeholderText: "Enter alarm label..."
                Keys.onReturnPressed: saveLabelBtn.clicked()
                Keys.onEnterPressed: saveLabelBtn.clicked()
            }

            Item {
                width: parent.width
                height: 44

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    DButton {
                        text: "Cancel"
                        buttonHeight: Theme.buttonHeightXS
                        backgroundColor: Theme.secondaryContainer
                        textColor: Theme.onSecondaryContainer
                        onClicked: ClockService.labelDialogOpen = false
                    }

                    DButton {
                        id: saveLabelBtn
                        text: "Save"
                        buttonHeight: Theme.buttonHeightXS
                        onClicked: {
                            ClockService.updateAlarmLabel(ClockService.editingLabelAlarmIndex, alarmLabelField.text);
                            ClockService.labelDialogOpen = false;
                            rootContent.forceActiveFocus();
                        }
                    }
                }
            }
        }

        // Vacation Mode Configuration Sheet
        ClockVacationSheet {
            id: vacationSheet
        }

        // Reminder Creation / Editing Sheet
        ClockReminderSheet {
            id: reminderSheet
        }

        // Dedicated TimePicker Modal for Reminder Time
        DTimePicker {
            id: reminderTimePicker
            is24Hour: SettingsData.use24HourClock
            title: "Select Reminder Time"
            z: 1100
            onAccepted: (h, m) => {
                ClockService.reminderTimePickerHour = h;
                ClockService.reminderTimePickerMinute = m;
                ClockService.reminderTimePickerOpen = false;
                rootContent.forceActiveFocus();
            }
            onRejected: {
                ClockService.reminderTimePickerOpen = false;
                rootContent.forceActiveFocus();
            }
        }

        Connections {
            target: ClockService
            function onReminderTimePickerOpenChanged() {
                if (ClockService.reminderTimePickerOpen) {
                    reminderTimePicker.hour = ClockService.reminderTimePickerHour;
                    reminderTimePicker.minute = ClockService.reminderTimePickerMinute;
                    reminderTimePicker.open();
                } else if (reminderTimePicker.opened) {
                    reminderTimePicker.close();
                }
            }
        }
    }
}
