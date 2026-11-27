import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets
import "UnitConverterLogic.js" as ConvLogic

Item {
    id: root

    property Item fromButton: null
    property Item toButton: null

    readonly property bool isOpen: CalculatorService.converterPickerTarget !== ""
    property string activeTarget: "from"
    property int highlightedIndex: 0

    onIsOpenChanged: {
        if (isOpen) {
            unitSearchInput.text = "";
            highlightedIndex = 0;
            if (CalculatorService.converterCategory === "currency") {
                unitSearchInput.forceActiveFocus();
            }
        }
    }

    Connections {
        target: CalculatorService
        function onConverterPickerTargetChanged() {
            if (CalculatorService.converterPickerTarget !== "") {
                root.activeTarget = CalculatorService.converterPickerTarget;
            }
        }
    }

    readonly property bool isFrom: activeTarget === "from"
    readonly property var currentUnits: ConvLogic.getUnitsForCategory(CalculatorService.converterCategory)
    readonly property string selectedUnitId: isFrom ? CalculatorService.converterFromUnit : CalculatorService.converterToUnit
    readonly property string otherUnitId: isFrom ? CalculatorService.converterToUnit : CalculatorService.converterFromUnit

    readonly property Item targetButton: isFrom ? fromButton : toButton

    anchors.fill: parent
    visible: opacity > 0
    opacity: isOpen ? 1.0 : 0.0
    z: 100

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Easing.InOutQuad
        }
    }

    // Transparent backdrop to dismiss on click outside
    MouseArea {
        anchors.fill: parent
        onClicked: CalculatorService.converterPickerTarget = ""
    }

    Rectangle {
        id: dropdownCard

        readonly property point targetPos: root.targetButton
            ? root.targetButton.mapToItem(root, 0, root.targetButton.height + 4)
            : Qt.point(Theme.spacingM, 80)

        readonly property point localPos: root.mapFromItem(null, CalculatorService.unitPickerRect.x, CalculatorService.unitPickerRect.y)

        x: Math.max(Theme.spacingM, Math.min(localPos.x, root.width - width - Theme.spacingM))
        y: Math.max(Theme.spacingM, localPos.y - height - 6)
        width: Math.max(180, CalculatorService.unitPickerRect.width)
        height: Math.min(unitList.contentHeight + Theme.spacingS * 2, Math.min(280, root.height - Theme.spacingM * 2))
        radius: Theme.cornerRadiusSmall
        color: Theme.withAlpha(Theme.surfaceContainer, 0.85)
        border.color: M3E.stroke(Theme.outlineVariant, M3E.strokePopup)
        border.width: 1

        scale: root.isOpen ? 1.0 : 0.95
        transformOrigin: Item.TopLeft
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
            anchors.margins: Theme.spacingS
            spacing: Theme.spacingXS

            Rectangle {
                visible: CalculatorService.converterCategory === "currency"
                Layout.fillWidth: true
                implicitHeight: 34
                radius: height / 2
                color: Theme.foregroundColor(Theme.surfaceContainerHighest, true)
                border.width: 1
                border.color: unitSearchInput.activeFocus ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    spacing: Theme.spacingXS

                    DIcon {
                        name: "search"
                        size: 15
                        color: Theme.surfaceVariantText
                    }

                    TextInput {
                        id: unitSearchInput
                        Layout.fillWidth: true
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        clip: true
                        selectByMouse: true
                        onTextChanged: root.highlightedIndex = 0
                        Keys.onDownPressed: {
                            if (unitList.model && unitList.model.length > 0)
                                root.highlightedIndex = Math.min(unitList.model.length - 1, root.highlightedIndex + 1);
                        }
                        Keys.onUpPressed: {
                            if (unitList.model && unitList.model.length > 0)
                                root.highlightedIndex = Math.max(0, root.highlightedIndex - 1);
                        }
                        Keys.onReturnPressed: {
                            if (unitList.model && unitList.model.length > 0) {
                                const idx = Math.max(0, Math.min(unitList.model.length - 1, root.highlightedIndex));
                                const item = unitList.model[idx];
                                if (root.activeTarget === "extra") {
                                    CalculatorService.addExtraCurrency(item.id);
                                    CalculatorService.converterPickerTarget = "";
                                } else if (root.isFrom) {
                                    CalculatorService.setConverterFromUnit(item.id);
                                } else {
                                    CalculatorService.setConverterToUnit(item.id);
                                }
                            }
                        }
                        Keys.onEnterPressed: Keys.onReturnPressed(event)

                        StyledText {
                            anchors.fill: parent
                            visible: unitSearchInput.text === ""
                            text: "Search currency..."
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            ListView {
                id: unitList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: {
                    if (CalculatorService.converterCategory !== "currency") return root.currentUnits;
                    const q = unitSearchInput.text.trim().toLowerCase();
                    if (!q) return root.currentUnits;
                    return root.currentUnits.filter(u =>
                        (u.name && u.name.toLowerCase().includes(q)) ||
                        (u.desc && u.desc.toLowerCase().includes(q)) ||
                        (u.id && u.id.toLowerCase().includes(q))
                    );
                }
                spacing: 2

                delegate: Rectangle {
                    id: unitDelegate
                    required property var modelData
                    required property int index
                    readonly property bool isSelected: modelData.id === root.selectedUnitId
                    readonly property bool isOtherSelected: modelData.id === root.otherUnitId

                    width: unitList.width
                    height: Style.menuItemHeight
                    radius: Theme.cornerRadiusSmall
                    border.width: (CalculatorService.converterCategory === "currency" && index === root.highlightedIndex) ? 1 : 0
                    border.color: Theme.primary
                opacity: isOtherSelected ? 0.45 : 1.0
                color: isSelected
                       ? Theme.secondaryContainer
                       : (!isOtherSelected && delegateMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    spacing: Theme.spacingS

                    StyledText {
                        Layout.preferredWidth: 44
                        text: modelData.name
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: unitDelegate.isSelected ? Font.Bold : Font.Medium
                        color: unitDelegate.isSelected ? Theme.onSecondaryContainer : Theme.surfaceText
                    }

                    StyledText {
                        visible: modelData.desc !== undefined && modelData.desc !== ""
                        Layout.fillWidth: true
                        text: modelData.desc || ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: unitDelegate.isSelected ? Theme.onSecondaryContainer : Theme.surfaceVariantText
                        elide: Text.ElideRight
                    }

                    DIcon {
                        visible: unitDelegate.isSelected
                        name: "check"
                        size: Style.iconSizeSmall
                        color: Theme.onSecondaryContainer
                    }
                }

                MouseArea {
                    id: delegateMouse
                    anchors.fill: parent
                    enabled: !unitDelegate.isOtherSelected
                    hoverEnabled: enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (root.activeTarget === "extra") {
                            CalculatorService.addExtraCurrency(modelData.id);
                            CalculatorService.converterPickerTarget = "";
                        } else if (root.isFrom) {
                            CalculatorService.setConverterFromUnit(modelData.id);
                        } else {
                            CalculatorService.setConverterToUnit(modelData.id);
                        }
                    }
                }
            }
            }
        }
    }
}
