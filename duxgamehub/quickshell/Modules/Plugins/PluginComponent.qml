import QtQuick

Item {
    property int popoutWidth: 480
    property int popoutHeight: 600
    property Component popoutContent: null
    property Component horizontalBarPill: null
    property Component verticalBarPill: null
    property string ccWidgetIcon: ""
    property string ccWidgetPrimaryText: ""
    property string ccWidgetSecondaryText: ""
    property bool ccWidgetIsActive: false
    property int ccDetailHeight: 520
    property Component ccDetailContent: null

    signal ccWidgetExpanded()
    signal ccWidgetToggled()
}
