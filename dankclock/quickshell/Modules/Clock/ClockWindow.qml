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
        { tabIndex: 0, icon: "alarm", text: "Alarms" },
        { tabIndex: 1, icon: "public", text: "World Clock" },
        {
            tabIndex: 2,
            icon: "notifications",
            text: "Reminders",
            badgeCount: ClockService.activeReminderCount
        },
        {
            tabIndex: 3,
            icon: "hourglass_empty",
            text: "Timers",
            badgeCount: ClockService.runningTimerCount
        },
        {
            tabIndex: 4,
            icon: "psychology",
            text: "Pomodoro",
            badgeCount: ClockService.pomodoroRunning ? 1 : 0
        },
        {
            tabIndex: 5,
            icon: "timer",
            text: "Stopwatch",
            badgeCount: ClockService.stopwatchRunning ? 1 : 0
        }
    ]

    title: `${ClockService.currentTabIndex === 6 ? "Settings" : ((navDestinations.find(d => d.tabIndex === ClockService.currentTabIndex)?.text) ?? "Clock")} — DUX Clock`
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
            if (ClockService.citySheetOpen || ClockService.timePickerOpen || ClockService.editingLabelAlarmIndex >= 0 || ClockService.settingsOpen || ClockService.newAlarmModalOpen || ClockService.newTimerModalOpen)
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
                    currentIndex: ClockService.currentTabIndex < 6 ? window.navDestinations.findIndex(d => d.tabIndex === ClockService.currentTabIndex) : -1
                    onActivated: index => {
                        const item = window.navDestinations[index];
                        if (item)
                            ClockService.currentTabIndex = item.tabIndex;
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
            anchors.right: vacationSheet.left
            anchors.rightMargin: Theme.spacingM
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spacingM
            radius: Theme.cornerRadiusXL
            color: ClockMetrics.paneColor
            border.width: Theme.layerOutlineWidth
            border.color: Theme.outlineMedium
            clip: true

            // Modernized Vacation Mode Header Banner (shown across all modes when active)
            Item {
                id: globalVacationBanner
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: ClockService.isVacationActive ? 96 : 0
                opacity: ClockService.isVacationActive ? 1.0 : 0.0
                clip: true
                z: 10

                Behavior on height { enabled: Theme.animationsEnabled; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    radius: Theme.cornerRadiusL
                    color: Theme.withAlpha(Theme.primary, 0.14)
                    border.color: Theme.withAlpha(Theme.primary, 0.4)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Item {
                            Layout.preferredWidth: 76
                            Layout.preferredHeight: 68

                            AnimatedImage {
                                anchors.fill: parent
                                visible: ClockService.vacationThemes[ClockService.vacationThemeIndex].isGif
                                source: (ClockService.isVacationActive && visible) ? Qt.resolvedUrl("../../assets/vacation/" + ClockService.vacationThemes[ClockService.vacationThemeIndex].file) : ""
                                fillMode: Image.PreserveAspectFit
                                playing: ClockService.isVacationActive
                            }

                            Image {
                                anchors.fill: parent
                                visible: !ClockService.vacationThemes[ClockService.vacationThemeIndex].isGif
                                source: (ClockService.isVacationActive && visible) ? Qt.resolvedUrl("../../assets/vacation/" + ClockService.vacationThemes[ClockService.vacationThemeIndex].file) : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                text: {
                                    const endStr = (ClockService.vacation && ClockService.vacation.endDate) ? ClockService.vacation.endDate : "";
                                    const formatted = endStr ? Qt.formatDate(new Date(endStr + "T12:00:00"), "dd / MMM / yy") : "";
                                    return formatted ? ("Vacation Mode • Till " + formatted) : "Vacation Mode";
                                }
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.DemiBold
                                color: Theme.primary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: "All alarms are silenced during your vacation"
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: Theme.surfaceVariantText
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Row {
                            spacing: 2
                            readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                            readonly property real innerR: Theme.groupedListInnerRadius ?? 4

                            Rectangle {
                                width: cfgRow.implicitWidth + Theme.spacingM * 2
                                height: 34
                                topLeftRadius: parent.outerR
                                bottomLeftRadius: parent.outerR
                                topRightRadius: cfgMouse.containsMouse ? parent.outerR : parent.innerR
                                bottomRightRadius: cfgMouse.containsMouse ? parent.outerR : parent.innerR
                                color: (ClockService.vacationSheetOpen || cfgMouse.containsMouse) ? Theme.withAlpha(Theme.primary, 0.2) : Theme.surfaceContainerHigh
                                border.width: 1
                                border.color: (ClockService.vacationSheetOpen || cfgMouse.containsMouse) ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                                scale: cfgMouse.pressed ? 0.95 : (cfgMouse.containsMouse ? 1.04 : 1.0)
                                clip: true

                                Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                DRipple { id: cfgRipple; anchors.fill: parent; rippleColor: Theme.primary }

                                Row {
                                    id: cfgRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    DIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: ClockService.vacationSheetOpen ? "visibility_off" : "tune"
                                        size: 16
                                        color: (ClockService.vacationSheetOpen || cfgMouse.containsMouse) ? Theme.primary : Theme.surfaceText
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: ClockService.vacationSheetOpen ? "Hide" : "Configure"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Medium
                                        color: (ClockService.vacationSheetOpen || cfgMouse.containsMouse) ? Theme.primary : Theme.surfaceText
                                    }
                                }

                                MouseArea {
                                    id: cfgMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: mouse => cfgRipple.trigger(mouse.x, mouse.y)
                                    onClicked: ClockService.vacationSheetOpen = !ClockService.vacationSheetOpen
                                }
                            }

                            Rectangle {
                                width: offRow.implicitWidth + Theme.spacingM * 2
                                height: 34
                                topLeftRadius: offMouse.containsMouse ? parent.outerR : parent.innerR
                                bottomLeftRadius: offMouse.containsMouse ? parent.outerR : parent.innerR
                                topRightRadius: parent.outerR
                                bottomRightRadius: parent.outerR
                                color: offMouse.containsMouse ? Theme.withAlpha(Theme.error, 0.22) : Theme.withAlpha(Theme.error, 0.12)
                                border.width: 1
                                border.color: offMouse.containsMouse ? Theme.error : Theme.withAlpha(Theme.error, 0.45)
                                scale: offMouse.pressed ? 0.95 : (offMouse.containsMouse ? 1.04 : 1.0)
                                clip: true

                                Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                DRipple { id: offRipple; anchors.fill: parent; rippleColor: Theme.error }

                                Row {
                                    id: offRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    DIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: "power_settings_new"
                                        size: 16
                                        color: Theme.error
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Turn Off"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Medium
                                        color: Theme.error
                                    }
                                }

                                MouseArea {
                                    id: offMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: mouse => offRipple.trigger(mouse.x, mouse.y)
                                    onClicked: ClockService.disableVacationMode()
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: tabContentStack
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: globalVacationBanner.bottom
                anchors.bottom: parent.bottom

                Connections {
                    target: ClockService
                    function onCurrentTabIndexChanged() {
                        tabContentStack.opacity = 0.0;
                        tabContentStack.y = 14;
                        tabAnimTimer.restart();
                    }
                }

                Timer {
                    id: tabAnimTimer
                    interval: 16
                    onTriggered: {
                        tabContentStack.opacity = 1.0;
                        tabContentStack.y = 0;
                    }
                }

                Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: Theme.animationsEnabled; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

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

        // Vacation Mode Configuration Sheet
        // Outside-click dismisses the Vacation side pane
        MouseArea {
            anchors.fill: parent
            z: 40
            visible: ClockService.vacationSheetOpen
            onPressed: mouse => {
                if (mouse.x < vacationSheet.x && mouse.y > (header.height + globalVacationBanner.height + Theme.spacingM)) {
                    ClockService.vacationSheetOpen = false;
                }
                mouse.accepted = false;
            }
        }

        ClockVacationSheet {
            id: vacationSheet
            anchors.top: header.bottom
            anchors.topMargin: Theme.spacingM
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spacingM
            anchors.right: parent.right
            anchors.rightMargin: width > 0 ? Theme.spacingM : 0
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
