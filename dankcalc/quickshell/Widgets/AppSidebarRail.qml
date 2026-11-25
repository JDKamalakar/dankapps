import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Common
import qs.DCommon.Widgets

ColumnLayout {
    id: root

    property var model: []
    property int currentIndex: -1
    signal activated(int index)

    readonly property string effectiveStyle: SettingsData.sidebarStyle || "beside"
    readonly property real railWidth: effectiveStyle === "icons_only" ? 68 : (effectiveStyle === "below" ? Style.navigationRailWidth : 184)

    spacing: 2

    Repeater {
        model: root.model

        delegate: Rectangle {
            id: navItem

            required property var modelData
            required property int index

            readonly property bool active: index === root.currentIndex
            readonly property bool isFirstInGroup: index === 0
            readonly property bool isLastInGroup: index === (root.model ? root.model.length - 1 : 0)
            readonly property string itemText: (modelData && modelData.text) ? modelData.text : ""
            readonly property string itemIcon: (modelData && modelData.icon) ? modelData.icon : ""
            readonly property int badgeCount: (modelData && modelData.badgeCount !== undefined) ? modelData.badgeCount : 0

            readonly property real baseOuterRadius: Theme.groupedListOuterRadius ?? 16
            readonly property real baseInnerRadius: Theme.groupedListInnerRadius ?? 4
            readonly property real hoverRadius: baseOuterRadius + 3 * (SettingsData.radiusStrength !== undefined ? SettingsData.radiusStrength / 50.0 : 1.0)
            readonly property real topRadius: (active || itemMouse.containsMouse) ? hoverRadius : (itemMouse.pressed ? (Theme.cornerRadiusS ?? 8) : (isFirstInGroup ? baseOuterRadius : baseInnerRadius))
            readonly property real bottomRadius: (active || itemMouse.containsMouse) ? hoverRadius : (itemMouse.pressed ? (Theme.cornerRadiusS ?? 8) : (isLastInGroup ? baseOuterRadius : baseInnerRadius))

            Layout.fillWidth: true
            Layout.preferredHeight: root.effectiveStyle === "below" ? 58 : 44

            topLeftRadius: topRadius
            topRightRadius: topRadius
            bottomLeftRadius: bottomRadius
            bottomRightRadius: bottomRadius

            border.width: 1
            border.color: (active || itemMouse.containsMouse) ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

            color: active ? SettingsMetrics.selectedRowColor : SettingsMetrics.sidebarRowColor

            Behavior on topLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on topRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on bottomLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on bottomRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on border.color { enabled: Theme.animationsEnabled; ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

            // State layer
            Rectangle {
                anchors.fill: parent
                topLeftRadius: navItem.topRadius
                topRightRadius: navItem.topRadius
                bottomLeftRadius: navItem.bottomRadius
                bottomRightRadius: navItem.bottomRadius
                color: Theme.surfaceText
                opacity: itemMouse.pressed ? Theme.stateLayerPressed : (itemMouse.containsMouse ? Theme.stateLayerHover : 0)
                Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: 120 } }
            }

            // Icons Only layout
            Item {
                anchors.fill: parent
                visible: root.effectiveStyle === "icons_only"

                DIcon {
                    anchors.centerIn: parent
                    name: navItem.itemIcon
                    size: Theme.iconSizeMedium
                    color: navItem.active ? Theme.primary : Theme.surfaceText
                }

                Rectangle {
                    visible: navItem.badgeCount > 0
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 4
                    width: Math.max(16, badgeTextOnly.implicitWidth + 6)
                    height: 16
                    radius: 8
                    color: Theme.primary

                    StyledText {
                        id: badgeTextOnly
                        anchors.centerIn: parent
                        text: navItem.badgeCount > 99 ? "99+" : String(navItem.badgeCount)
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Theme.onPrimary
                    }
                }
            }

            // Below Icons layout
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 8
                spacing: 2
                visible: root.effectiveStyle === "below"

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 24
                    implicitHeight: 24

                    DIcon {
                        anchors.centerIn: parent
                        name: navItem.itemIcon
                        size: Theme.iconSizeSmall + 2
                        color: navItem.active ? Theme.primary : Theme.surfaceText
                    }

                    Rectangle {
                        visible: navItem.badgeCount > 0
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: -4
                        anchors.rightMargin: -8
                        width: Math.max(15, badgeTextBelow.implicitWidth + 5)
                        height: 15
                        radius: 7.5
                        color: Theme.primary

                        StyledText {
                            id: badgeTextBelow
                            anchors.centerIn: parent
                            text: navItem.badgeCount > 99 ? "99+" : String(navItem.badgeCount)
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: Theme.onPrimary
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: navItem.itemText
                    font.pixelSize: Theme.fontSizeSmall - 1
                    font.weight: navItem.active ? Font.DemiBold : Font.Medium
                    color: navItem.active ? Theme.primary : Theme.surfaceText
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }

            // Next to Icons layout (default, matches SettingsSidebarItem)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                spacing: Theme.spacingS
                visible: root.effectiveStyle === "beside"

                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: Theme.cornerRadiusS
                    color: navItem.active ? Theme.withAlpha(Theme.primary, Theme.tonalTintAlpha) : "transparent"

                    DIcon {
                        anchors.centerIn: parent
                        name: navItem.itemIcon
                        size: Theme.iconSizeSmall + 2
                        color: navItem.active ? Theme.primary : Theme.surfaceText
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: navItem.itemText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: navItem.active ? Font.DemiBold : Font.Medium
                    color: navItem.active ? Theme.primary : Theme.surfaceText
                    elide: Text.ElideRight
                }

                Rectangle {
                    visible: navItem.badgeCount > 0
                    Layout.preferredWidth: Math.max(20, badgeTextBeside.implicitWidth + 10)
                    Layout.preferredHeight: 20
                    radius: 10
                    color: Theme.withAlpha(Theme.primary, Theme.tonalTintAlpha)

                    StyledText {
                        id: badgeTextBeside
                        anchors.centerIn: parent
                        text: navItem.badgeCount > 99 ? "99+" : String(navItem.badgeCount)
                        font.pixelSize: Theme.fontSizeSmall - 1
                        font.weight: Font.Bold
                        color: Theme.primary
                    }
                }
            }

            DTooltipHost {
                anchors.fill: parent
                enabled: root.effectiveStyle === "icons_only"
                text: navItem.itemText
            }

            MouseArea {
                id: itemMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activated(navItem.index)
            }
        }
    }
}
