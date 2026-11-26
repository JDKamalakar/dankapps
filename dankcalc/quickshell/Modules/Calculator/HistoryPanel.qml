import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets

Rectangle {
    id: root

    property bool open: CalculatorService.historyOpen
    property bool inlineMode: false

    anchors.fill: inlineMode ? undefined : parent
    color: inlineMode ? "transparent" : Qt.rgba(0, 0, 0, M3E.scrimModal)
    visible: inlineMode ? (open || width > 1) : (opacity > 0)
    opacity: open ? 1.0 : 0.0
    clip: inlineMode

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Easing.InOutQuad
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.inlineMode
        onClicked: CalculatorService.historyOpen = false
    }

    Rectangle {
        id: panel
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.inlineMode ? parent.width : Math.max(260, Math.round(parent.width * 0.30))
        topLeftRadius: root.inlineMode ? (Theme.cornerRadiusS ?? 8) : Theme.cornerRadiusXL
        bottomLeftRadius: root.inlineMode ? (Theme.cornerRadiusS ?? 8) : Theme.cornerRadiusXL
        topRightRadius: root.inlineMode ? Theme.cornerRadiusXL : 0
        bottomRightRadius: root.inlineMode ? Theme.cornerRadiusXL : 0
        color: Theme.foregroundColor(Theme.surfaceContainerHigh, true)
        border.color: Theme.withAlpha(Theme.outlineVariant, 0.25)
        border.width: 1
        clip: true

        // Shadow removed per user request

        transform: Translate {
            x: root.open ? 0 : panel.width
            Behavior on x {
                DAnim {
                    duration: Theme.mediumDuration
                    easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                }
            }
        }

        MouseArea {
            // Prevent clicks inside panel from closing overlay
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            // Pill container for History + Clear buttons
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: headerButtonsRow.implicitHeight + Theme.spacingXS * 2
                radius: height / 2
                color: Theme.foregroundColor(Theme.surfaceContainerHighest, true)
                border.width: 1
                border.color: Theme.outlineMedium ?? Theme.outlineVariant

                RowLayout {
                    id: headerButtonsRow
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXS
                    spacing: Theme.spacingXS

                    // History pill button (moved from display when open)
                    Rectangle {
                        implicitWidth: histBtnRow.implicitWidth + Theme.spacingM * 2
                        implicitHeight: 28
                        radius: height / 2
                        color: histBtnMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.28) : Theme.withAlpha(Theme.primary, 0.18)
                        border.width: 1
                        border.color: Theme.primary

                        Row {
                            id: histBtnRow
                            anchors.centerIn: parent
                            spacing: 4
                            DIcon { name: "history"; size: 15; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            StyledText { text: "History"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        }

                        MouseArea {
                            id: histBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: CalculatorService.historyOpen = false
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Clear History pill button (matching History button UI)
                    Rectangle {
                        visible: CalculatorService.history.length > 0
                        implicitWidth: clearBtnRow.implicitWidth + Theme.spacingM * 2
                        implicitHeight: 28
                        radius: height / 2
                        color: clearBtnMouse.containsMouse ? Theme.withAlpha(Theme.error, 0.2) : Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                        border.width: 1
                        border.color: clearBtnMouse.containsMouse ? Theme.error : (Theme.outlineMedium ?? Theme.outlineVariant)

                        Row {
                            id: clearBtnRow
                            anchors.centerIn: parent
                            spacing: 4
                            DIcon { name: "delete_sweep"; size: 15; color: Theme.error; anchors.verticalCenter: parent.verticalCenter }
                            StyledText { text: "Clear"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.error; anchors.verticalCenter: parent.verticalCenter }
                        }

                        MouseArea {
                            id: clearBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: CalculatorService.clearHistory()
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                StyledText {
                    anchors.centerIn: parent
                    visible: CalculatorService.history.length === 0
                    text: "No history yet"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                }

                DListView {
                    anchors.fill: parent
                    visible: CalculatorService.history.length > 0
                    model: {
                        const list = CalculatorService.history;
                        const out = [];
                        const now = new Date();
                        const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
                        const yesterdayStart = todayStart - 86400000;
                        let currentGroup = "";
                        for (let i = 0; i < list.length; i++) {
                            const entry = list[i];
                            const ts = entry.timestamp || Date.now();
                            let label = "Older";
                            if (ts >= todayStart) label = "Today";
                            else if (ts >= yesterdayStart) label = "Yesterday";
                            else label = Qt.formatDate(new Date(ts), "MMM d, yyyy");

                            if (label !== currentGroup) {
                                currentGroup = label;
                                out.push({ isHeader: true, title: label });
                            }
                            const nextTs = (i + 1 < list.length) ? (list[i + 1].timestamp || Date.now()) : -1;
                            let nextLabel = "";
                            if (nextTs >= 0) {
                                if (nextTs >= todayStart) nextLabel = "Today";
                                else if (nextTs >= yesterdayStart) nextLabel = "Yesterday";
                                else nextLabel = Qt.formatDate(new Date(nextTs), "MMM d, yyyy");
                            }
                            const isFirstInGroup = out.length >= 1 && out[out.length - 1].isHeader;
                            const isLastInGroup = (nextLabel !== currentGroup);
                            out.push({ isHeader: false, item: entry, isFirstInGroup: isFirstInGroup, isLastInGroup: isLastInGroup });
                        }
                        return out;
                    }
                    spacing: 2
                    clip: true

                    delegate: Item {
                        required property var modelData
                        required property int index

                        width: parent ? parent.width : 0
                        implicitHeight: modelData.isHeader ? (dateHeader.implicitHeight + Theme.spacingS) : itemCard.implicitHeight

                        StyledText {
                            id: dateHeader
                            visible: modelData.isHeader
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: Theme.spacingXS
                            anchors.bottomMargin: Theme.spacingXXS
                            text: modelData.title || ""
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: Theme.surfaceVariantText
                        }

                        Rectangle {
                            id: itemCard
                            visible: !modelData.isHeader
                            anchors.fill: parent
                            readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                            readonly property real innerR: Theme.groupedListInnerRadius ?? 4

                            implicitHeight: itemCol.implicitHeight + Theme.spacingS * 2
                            topLeftRadius: itemMouse.containsMouse ? Theme.cornerRadiusXL : (modelData.isFirstInGroup ? outerR : innerR)
                            topRightRadius: itemMouse.containsMouse ? Theme.cornerRadiusXL : (modelData.isFirstInGroup ? outerR : innerR)
                            bottomLeftRadius: itemMouse.containsMouse ? Theme.cornerRadiusXL : (modelData.isLastInGroup ? outerR : innerR)
                            bottomRightRadius: itemMouse.containsMouse ? Theme.cornerRadiusXL : (modelData.isLastInGroup ? outerR : innerR)
                            color: itemMouse.containsMouse ? Theme.foregroundColor(Theme.surfaceContainerHighest, true) : Theme.foregroundColor(Theme.surfaceContainerLow, true)
                            border.width: 1
                            border.color: itemMouse.containsMouse ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                            Behavior on color { DColorAnim { duration: Theme.shortDuration } }

                            ColumnLayout {
                                id: itemCol
                                anchors.fill: parent
                                anchors.topMargin: Theme.spacingS
                                anchors.bottomMargin: Theme.spacingS
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingL
                                spacing: Theme.spacingXXS

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.item ? modelData.item.expression : ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    horizontalAlignment: Text.AlignRight
                                    elide: Text.ElideLeft
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: "= " + (modelData.item ? modelData.item.result : "")
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    horizontalAlignment: Text.AlignRight
                                    elide: Text.ElideLeft
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.item)
                                        CalculatorService.restoreHistoryItem(modelData.item);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
