import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets
import qs.Widgets

Item {
    id: root

    property int currentIndex: 0
    property string searchQuery: ""

    Loader {
        id: pageLoader
        anchors.fill: parent
        sourceComponent: {
            switch (root.currentIndex) {
            case 0:
                return appearancePage;
            case 1:
                return preferencesPage;
            case 2:
                return aboutPage;
            default:
                return appearancePage;
            }
        }

        opacity: 1.0
        Behavior on opacity {
            enabled: Theme.animationsEnabled
            NumberAnimation {
                duration: Theme.mediumDuration ?? 200
                easing.bezierCurve: Theme.expressiveCurves.expressiveSpatial ?? Theme.expressiveCurves.standard
            }
        }
        Behavior on y {
            enabled: Theme.animationsEnabled
            NumberAnimation {
                duration: Theme.mediumDuration ?? 200
                easing.bezierCurve: Theme.expressiveCurves.expressiveSpatial ?? Theme.expressiveCurves.standard
            }
        }
    }

    property int _prevIndex: 0

    onCurrentIndexChanged: {
        const goingDown = currentIndex > _prevIndex;
        _prevIndex = currentIndex;
        pageLoader.opacity = 0.0;
        pageLoader.y = goingDown ? 16 : -16;
        pageSwitchTimer.restart();
    }

    Timer {
        id: pageSwitchTimer
        interval: 20
        repeat: false
        onTriggered: {
            pageLoader.opacity = 1.0;
            pageLoader.y = 0;
        }
    }

    Component {
        id: appearancePage

        SettingsPage {
            SettingsAppearanceCard {}
        }
    }

    Component {
        id: preferencesPage

        SettingsPage {
            SettingsCard {
                title: "Time & Display"
                iconName: "schedule"

                SettingsToggleRow {
                    iconName: "schedule"
                    text: "24-Hour time"
                    description: "Display time using 24-hour format (e.g. 14:00) instead of 12-hour AM/PM"
                    checked: SettingsData.use24HourClock
                    onToggled: chk => SettingsData.use24HourClock = chk
                }

                SettingsToggleRow {
                    iconName: "more_time"
                    text: "Show seconds"
                    description: "Display seconds in the main clock and world clocks"
                    checked: SettingsData.showSeconds
                    onToggled: chk => SettingsData.showSeconds = chk
                }

                SettingsToggleRow {
                    iconName: "notifications"
                    text: "Show tray icon"
                    description: "Keep status icon in the system tray when running in background"
                    checked: SettingsData.showTrayIcon
                    onToggled: chk => SettingsData.showTrayIcon = chk
                }
            }

            SettingsCard {
                title: "Pomodoro Defaults"
                iconName: "timer"

                SettingsSliderRow {
                    iconName: "hourglass_top"
                    text: "Focus duration"
                    description: `${SettingsData.pomodoroFocusMinutes} minutes per focus session`
                    minimum: 5
                    maximum: 90
                    step: 5
                    unit: "m"
                    value: SettingsData.pomodoroFocusMinutes
                    onSliderValueChanged: v => SettingsData.pomodoroFocusMinutes = v
                }

                SettingsSliderRow {
                    iconName: "coffee"
                    text: "Short break"
                    description: `${SettingsData.pomodoroShortBreakMinutes} minutes rest between sessions`
                    minimum: 1
                    maximum: 30
                    step: 1
                    unit: "m"
                    value: SettingsData.pomodoroShortBreakMinutes
                    onSliderValueChanged: v => SettingsData.pomodoroShortBreakMinutes = v
                }

                SettingsSliderRow {
                    iconName: "weekend"
                    text: "Long break"
                    description: `${SettingsData.pomodoroLongBreakMinutes} minutes after ${SettingsData.pomodoroTargetCycles} cycles`
                    minimum: 5
                    maximum: 60
                    step: 5
                    unit: "m"
                    value: SettingsData.pomodoroLongBreakMinutes
                    onSliderValueChanged: v => SettingsData.pomodoroLongBreakMinutes = v
                }
            }

            SettingsCard {
                title: "Notifications (Beta)"
                iconName: "science"

                SettingsToggleRow {
                    iconName: "notifications_active"
                    text: "Enable desktop notifications"
                    description: "Send system notifications for timers, reminders, and Pomodoro sessions"
                    checked: SettingsData.enableNotifications
                    onToggled: chk => SettingsData.enableNotifications = chk
                }

                SettingsRow {
                    iconName: "alarm"
                    title: "Test alarm notification"
                    subtitle: "Send a sample alarm alert notification"

                    DButton {
                        text: "Test"
                        iconName: "notifications_active"
                        buttonHeight: Style.buttonHeightXS
                        onClicked: ClockService.testNotification("alarm")
                    }
                }

                SettingsRow {
                    iconName: "event_note"
                    title: "Test reminder notification"
                    subtitle: "Send a sample reminder notification"

                    DButton {
                        text: "Test"
                        iconName: "notifications_active"
                        buttonHeight: Style.buttonHeightXS
                        onClicked: ClockService.testNotification("reminder")
                    }
                }

                SettingsRow {
                    iconName: "hourglass_empty"
                    title: "Test timer notification"
                    subtitle: "Send a sample timer finished notification"

                    DButton {
                        text: "Test"
                        iconName: "notifications_active"
                        buttonHeight: Style.buttonHeightXS
                        onClicked: ClockService.testNotification("timer")
                    }
                }

                SettingsRow {
                    iconName: "psychology"
                    title: "Test Pomodoro notification"
                    subtitle: "Send a sample Pomodoro session notification"

                    DButton {
                        text: "Test"
                        iconName: "notifications_active"
                        buttonHeight: Style.buttonHeightXS
                        onClicked: ClockService.testNotification("pomodoro")
                    }
                }
            }
        }
    }

    Component {
        id: aboutPage

        SettingsPage {
            spacing: Theme.spacingL

            DHeroCard {
                brand: "DUX Clock"
                caption: "Part of the Dux Shell ecosystem."

                DButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Support Dux Labs"
                    iconName: "favorite"
                    backgroundColor: Theme.primary
                    textColor: Theme.onPrimary
                    onClicked: Qt.openUrlExternally("https://ko-fi.com/duxlabs")
                }
            }

            DCard {
                width: parent.width
                height: aboutText.implicitHeight + pad * 2
                pad: Theme.spacingL
                restRadius: Theme.groupedListOuterRadius
                color: SettingsMetrics.rowColor

                StyledText {
                    id: aboutText
                    width: parent.width
                    text: 'DUX Clock is a world clock, alarm, countdown timer, Pomodoro focus assistant, and stopwatch utility for the modern Linux desktop with a <a href="https://m3.material.io/" style="text-decoration:none; color:%1;">material 3 inspired</a> design, part of the Dux Shell ecosystem.<br /><br />Built with <a href="https://quickshell.org" style="text-decoration:none; color:%1;">Quickshell</a> and <a href="https://go.dev" style="text-decoration:none; color:%1;">Go</a>.'.arg(Theme.primary)
                    textFormat: Text.RichText
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    linkColor: Theme.primary
                    wrapMode: Text.WordWrap
                    onLinkActivated: url => Qt.openUrlExternally(url)
                }
            }

            SettingsGroup {
                width: parent.width

                Repeater {
                    model: [
                        { icon: "menu_book", accent: "blue", title: "Docs", subtitle: "duxlabs.dev/docs", url: "https://duxlabs.dev/docs" },
                        { icon: "code", accent: "purple", title: "GitHub", subtitle: "github.com/JD-Danklinux/dankapps", url: "https://github.com/JD-Danklinux/dankapps" },
                        { icon: "gavel", accent: "green", title: "License", subtitle: "MIT License", url: "https://github.com/JD-Danklinux/dankapps/blob/master/LICENSE" }
                    ]

                    SettingsRow {
                        id: aboutLinkRow
                        required property var modelData
                        required property int index

                        width: parent.width
                        iconName: modelData.icon
                        accent: modelData.accent
                        title: modelData.title
                        subtitle: modelData.subtitle
                        clickable: true
                        isFirstInGroup: index === 0
                        isLastInGroup: index === 2
                        onClicked: Qt.openUrlExternally(aboutLinkRow.modelData.url)

                        DIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "open_in_new"
                            size: Theme.iconSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                }
            }
        }
    }
}
