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
                return calcPage;
            case 1:
                return appearancePage;
            case 2:
                return aboutPage;
            default:
                return calcPage;
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
        id: calcPage

        SettingsPage {
            SettingsCard {
                title: "Calculator"
                iconName: "calculate"

                SettingsButtonGroupRow {
                    iconName: "square_foot"
                    text: "Angle unit"
                    description: "Unit for trigonometric functions"
                    model: ["Rad", "Deg"]
                    currentIndex: SettingsData.angleUnitRad ? 0 : 1
                    onSelectionChanged: (idx, sel) => {
                        if (sel) SettingsData.angleUnitRad = (idx === 0);
                    }
                }

                SettingsToggleRow {
                    iconName: "function"
                    text: "Scientific keypad"
                    description: "Keep scientific functions expanded in portrait mode"
                    checked: SettingsData.scientificExpanded
                    onToggled: chk => SettingsData.scientificExpanded = chk
                }

                SettingsRow {
                    iconName: "history"
                    title: "Calculation history"
                    subtitle: CalculatorService.history.length > 0
                        ? CalculatorService.history.length + " saved expressions"
                        : "No saved expressions"

                    DButton {
                        text: "Clear"
                        buttonHeight: Style.buttonHeightXS
                        backgroundColor: Theme.surfaceContainerHighest
                        textColor: Theme.error
                        enabled: CalculatorService.history.length > 0
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: CalculatorService.clearHistory()
                    }
                }
            }
        }
    }

    Component {
        id: appearancePage

        SettingsPage {
            SettingsAppearanceCard {}
        }
    }

    Component {
        id: aboutPage

        SettingsPage {
            spacing: Theme.spacingL

            DHeroCard {
                brand: "DUX Calculator"
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
                    text: 'DUX Calculator is a Material 3 calculator and unit converter utility for the modern Linux desktop, part of the Dux Shell ecosystem.<br /><br />Built with <a href="https://quickshell.org" style="text-decoration:none; color:%1;">Quickshell</a> and <a href="https://go.dev" style="text-decoration:none; color:%1;">Go</a>.'.arg(Theme.primary)
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
                        { icon: "code", accent: "purple", title: "GitHub", subtitle: "github.com/JDKamalakar/dankapps", url: "https://github.com/JDKamalakar/dankapps" },
                        { icon: "gavel", accent: "green", title: "License", subtitle: "MIT License", url: "https://github.com/JDKamalakar/dankapps/blob/master/LICENSE" }
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
