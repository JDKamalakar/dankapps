import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets

Rectangle {
    id: root

    property bool open: CalculatorService.menuOpen

    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, M3E.scrimModal)
    visible: opacity > 0
    opacity: open ? 1.0 : 0.0

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Easing.InOutQuad
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: CalculatorService.menuOpen = false
    }

    Rectangle {
        id: menuCard
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 250
        topLeftRadius: 0
        bottomLeftRadius: 0
        topRightRadius: Theme.cornerRadiusXL
        bottomRightRadius: Theme.cornerRadiusXL
        color: Theme.foregroundColor(Theme.surfaceContainerHigh, true)
        border.color: Theme.withAlpha(Theme.outlineVariant, 0.25)
        border.width: 1
        clip: true

        ElevationShadow {
            anchors.fill: parent
            z: -1
            targetRadius: Theme.cornerRadiusXL
            targetColor: parent.color
            level: Style.elevationLevel3
        }

        transform: Translate {
            x: root.open ? 0 : -menuCard.width
            Behavior on x {
                DAnim {
                    duration: Theme.mediumDuration
                    easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: menuCol
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS

                DIcon {
                    name: "calculate"
                    size: Style.iconSizeMedium
                    color: Theme.primary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "DUX Calculator"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    color: Theme.surfaceText
                }

                DIconButton {
                    iconName: "close"
                    size: "xs"
                    variant: "standard"
                    tooltipText: "Close"
                    onClicked: CalculatorService.menuOpen = false
                }
            }

            StyledText {
                text: "Modes"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceVariantText
            }

            // Standard Calculator Option
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Style.menuItemHeight
                radius: Theme.cornerRadiusSmall
                color: CalculatorService.currentMode === "calculator"
                       ? Theme.secondaryContainer
                       : calcHover.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingS

                    DIcon {
                        name: "calculate"
                        size: Style.chipIconSize
                        color: CalculatorService.currentMode === "calculator" ? Theme.onSecondaryContainer : Theme.surfaceText
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: "Calculator"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: CalculatorService.currentMode === "calculator" ? Font.Medium : Font.Normal
                        color: CalculatorService.currentMode === "calculator" ? Theme.onSecondaryContainer : Theme.surfaceText
                    }

                    DIcon {
                        visible: CalculatorService.currentMode === "calculator"
                        name: "check"
                        size: Style.iconSizeSmall
                        color: Theme.onSecondaryContainer
                    }
                }

                MouseArea {
                    id: calcHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        CalculatorService.setMode("calculator");
                    }
                }
            }

            // Unit Converter Option
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Style.menuItemHeight
                radius: Theme.cornerRadiusSmall
                color: CalculatorService.currentMode === "converter"
                       ? Theme.secondaryContainer
                       : convHover.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingS

                    DIcon {
                        name: "swap_horiz"
                        size: Style.chipIconSize
                        color: CalculatorService.currentMode === "converter" ? Theme.onSecondaryContainer : Theme.surfaceText
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: "Unit Converter"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: CalculatorService.currentMode === "converter" ? Font.Medium : Font.Normal
                        color: CalculatorService.currentMode === "converter" ? Theme.onSecondaryContainer : Theme.surfaceText
                    }

                    DIcon {
                        visible: CalculatorService.currentMode === "converter"
                        name: "check"
                        size: Style.iconSizeSmall
                        color: Theme.onSecondaryContainer
                    }
                }

                MouseArea {
                    id: convHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        CalculatorService.setMode("converter");
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.outlineVariant
                opacity: 0.35
            }

            // Settings Option
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Style.menuItemHeight
                radius: Theme.cornerRadiusSmall
                color: settingsHover.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingS

                    DIcon {
                        name: "settings"
                        size: Style.chipIconSize
                        color: Theme.surfaceText
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: "Settings"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                    }
                }

                MouseArea {
                    id: settingsHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        CalculatorService.menuOpen = false;
                        CalculatorService.settingsOpen = true;
                    }
                }
            }
        }
    }
}
