import QtQuick
import qs.Common
import qs.DCommon.Widgets

Item {
    id: root

    readonly property bool isClockSectionLabel: true

    property string text: ""
    property string iconName: ""
    default property alias rightActions: rightSlot.data

    Accessible.role: Accessible.StaticText
    Accessible.name: text

    width: parent?.width ?? 0
    height: Math.max(labelRow.implicitHeight, rightSlot.implicitHeight) + ClockMetrics.sectionLabelTopGap + ClockMetrics.sectionLabelBottomGap

    Row {
        id: labelRow
        anchors.left: parent.left
        anchors.right: rightSlot.visible ? rightSlot.left : parent.right
        anchors.rightMargin: rightSlot.visible ? Theme.spacingM : 0
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: (ClockMetrics.sectionLabelTopGap - ClockMetrics.sectionLabelBottomGap) / 2
        spacing: Theme.spacingXS

        DIcon {
            visible: root.iconName !== ""
            name: root.iconName
            size: Theme.iconSizeSmall
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            id: label
            width: Math.max(0, labelRow.width - (root.iconName !== "" ? Theme.iconSizeSmall + labelRow.spacing : 0))
            text: root.text
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Theme.fontWeightMedium
            color: Theme.primary
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignLeft
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Row {
        id: rightSlot
        anchors.right: parent.right
        anchors.verticalCenter: labelRow.verticalCenter
        spacing: Theme.spacingS
        visible: children.length > 0
    }
}
