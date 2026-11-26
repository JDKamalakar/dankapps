import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets
import "UnitConverterLogic.js" as ConvLogic

Rectangle {
    id: root

    property bool open: CalculatorService.categoryMenuOpen
    readonly property var categories: ConvLogic.getCategoryList()

    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, M3E.scrimModal)
    visible: opacity > 0
    opacity: open ? 1.0 : 0.0
    z: 90

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Easing.InOutQuad
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: CalculatorService.categoryMenuOpen = false
    }

    Rectangle {
        id: menuCard
        x: Theme.spacingM + Style.buttonHeightS + Theme.spacingS
        y: 84
        width: 220
        height: Math.min(parent.height - 100, 360)
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        border.color: M3E.stroke(Theme.outlineVariant, M3E.strokePopup)
        border.width: 1

        scale: root.open ? 1.0 : 0.95
        Behavior on scale {
            DAnim {
                duration: Theme.shortDuration
                easing.bezierCurve: Theme.expressiveCurves.standardDecel
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 36
                radius: height / 2
                color: Theme.foregroundColor(Theme.surfaceContainerHighest, true)
                border.width: 1
                border.color: catSearchInput.activeFocus ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    spacing: Theme.spacingXS

                    DIcon {
                        name: "search"
                        size: 16
                        color: Theme.surfaceVariantText
                    }

                    TextInput {
                        id: catSearchInput
                        Layout.fillWidth: true
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        clip: true
                        selectByMouse: true

                        StyledText {
                            anchors.fill: parent
                            visible: catSearchInput.text === ""
                            text: "Search type..."
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            ListView {
                id: catList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: {
                    const q = catSearchInput.text.trim().toLowerCase();
                    if (!q) return root.categories;
                    return root.categories.filter(c =>
                        (c.name && c.name.toLowerCase().includes(q)) ||
                        (c.key && c.key.toLowerCase().includes(q))
                    );
                }
                spacing: 3

                delegate: Rectangle {
                    id: catDelegate
                    required property var modelData
                    width: catList.width
                    height: Style.menuItemHeight
                    radius: Theme.cornerRadiusSmall
                    color: modelData.key === CalculatorService.converterCategory
                           ? Theme.secondaryContainer
                           : delegateMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingS
                        anchors.rightMargin: Theme.spacingS
                        spacing: Theme.spacingS

                        DIcon {
                            name: modelData.icon
                            size: Style.chipIconSize
                            color: modelData.key === CalculatorService.converterCategory ? Theme.onSecondaryContainer : Theme.surfaceVariantText
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.name
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: modelData.key === CalculatorService.converterCategory ? Font.Medium : Font.Normal
                            color: modelData.key === CalculatorService.converterCategory ? Theme.onSecondaryContainer : Theme.surfaceText
                        }

                        DIcon {
                            visible: modelData.key === CalculatorService.converterCategory
                            name: "check"
                            size: Style.iconSizeSmall
                            color: Theme.onSecondaryContainer
                        }
                    }

                    MouseArea {
                        id: delegateMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            CalculatorService.setConverterCategory(modelData.key);
                            CalculatorService.categoryMenuOpen = false;
                        }
                    }
                }
            }
        }
    }
}
