import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets

Rectangle {
    id: root

    property string expression: CalculatorService.expression
    property string resultText: CalculatorService.liveResult

    implicitWidth: 360
    implicitHeight: 160
    topLeftRadius: Theme.cornerRadiusXL
    bottomLeftRadius: Theme.cornerRadiusXL
    topRightRadius: CalculatorService.historyOpen ? (Theme.cornerRadiusS ?? 8) : Theme.cornerRadiusXL
    bottomRightRadius: CalculatorService.historyOpen ? (Theme.cornerRadiusS ?? 8) : Theme.cornerRadiusXL
    color: Theme.foregroundColor(Theme.surfaceContainerLow, true)
    border.width: 1
    border.color: Theme.outlineMedium ?? Theme.outlineVariant
    clip: true

    readonly property real baseFontSize: Math.max(28, Math.min(52, height * 0.16))

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        // Top Bar: Custom RAD/DEG Button on Left, Custom History Button on Right
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4

            Rectangle {
                id: radBtn
                width: radRow.implicitWidth + Theme.spacingM * 2
                height: 32
                radius: (radMouse.pressed || radMouse.containsMouse) ? height / 2 : (Theme.cornerRadiusS ?? 8)
                color: (CalculatorService.isRad || radMouse.containsMouse) ? Theme.withAlpha(Theme.primary, 0.2) : Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                border.width: 1
                border.color: (CalculatorService.isRad || radMouse.containsMouse) ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                scale: radMouse.pressed ? 0.96 : 1.0
                clip: true

                Behavior on radius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                DRipple { id: radRipple; anchors.fill: parent; rippleColor: Theme.primary }

                Row {
                    id: radRow
                    anchors.centerIn: parent
                    spacing: 5
                    DIcon { name: "straighten"; size: 15; color: (CalculatorService.isRad || radMouse.containsMouse) ? Theme.primary : Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }
                    StyledText { text: CalculatorService.isRad ? "RAD" : "DEG"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.DemiBold; color: (CalculatorService.isRad || radMouse.containsMouse) ? Theme.primary : Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                    id: radMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => radRipple.trigger(mouse.x, mouse.y)
                    onClicked: SettingsData.angleUnitRad = !SettingsData.angleUnitRad
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                id: histBtn
                visible: !CalculatorService.historyOpen
                width: histRow.implicitWidth + Theme.spacingM * 2
                height: 32
                radius: (histMouse.pressed || histMouse.containsMouse) ? height / 2 : (Theme.cornerRadiusS ?? 8)
                color: (CalculatorService.historyOpen || histMouse.containsMouse) ? Theme.withAlpha(Theme.primary, 0.2) : Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                border.width: 1
                border.color: (CalculatorService.historyOpen || histMouse.containsMouse) ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                scale: histMouse.pressed ? 0.96 : 1.0
                clip: true

                Behavior on radius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                DRipple { id: histRipple; anchors.fill: parent; rippleColor: Theme.primary }

                Row {
                    id: histRow
                    anchors.centerIn: parent
                    spacing: 5
                    DIcon { name: "history"; size: 15; color: (CalculatorService.historyOpen || histMouse.containsMouse) ? Theme.primary : Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }
                    StyledText { text: "History"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: (CalculatorService.historyOpen || histMouse.containsMouse) ? Theme.primary : Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                    id: histMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => histRipple.trigger(mouse.x, mouse.y)
                    onClicked: CalculatorService.historyOpen = !CalculatorService.historyOpen
                }
            }
        }

        // Old Calculations in Segmented Container
        ListView {
            id: historyList
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            clip: true
            spacing: 2
            verticalLayoutDirection: ListView.BottomToTop
            model: CalculatorService.history

            delegate: Rectangle {
                required property var modelData
                required property int index

                readonly property bool isFirst: index === CalculatorService.history.length - 1
                readonly property bool isLast: index === 0
                readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                readonly property real innerR: Theme.groupedListInnerRadius ?? 4

                width: ListView.view.width
                height: histCol.implicitHeight + Theme.spacingS * 2
                topLeftRadius: histHover.hovered ? Theme.cornerRadiusXL : (isFirst ? outerR : innerR)
                topRightRadius: histHover.hovered ? Theme.cornerRadiusXL : (isFirst ? outerR : innerR)
                bottomLeftRadius: histHover.hovered ? Theme.cornerRadiusXL : (isLast ? outerR : innerR)
                bottomRightRadius: histHover.hovered ? Theme.cornerRadiusXL : (isLast ? outerR : innerR)
                color: histHover.hovered ? Theme.foregroundColor(Theme.surfaceContainerHighest, true) : Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                border.width: 1
                border.color: histHover.hovered ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: 150 } }

                HoverHandler { id: histHover }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CalculatorService.loadHistoryItem(modelData)
                }

                Column {
                    id: histCol
                    anchors.fill: parent
                    anchors.topMargin: Theme.spacingS
                    anchors.bottomMargin: Theme.spacingS
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingL
                    spacing: 2

                    StyledText {
                        width: parent.width
                        text: modelData.expression || ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                    }

                    StyledText {
                        width: parent.width
                        text: "= " + (modelData.result || "")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.surfaceText
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                    }
                }
            }
        }

        // Bottom-Right Separate Segmented Containers: Live Answer (Top) + Typing Equation (Bottom)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            spacing: 2

            readonly property real outerR: Theme.groupedListOuterRadius ?? 16
            readonly property real innerR: Theme.groupedListInnerRadius ?? 4

            // First Segment: Live Answer
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: mainResult.implicitHeight + Theme.spacingS * 2
                topLeftRadius: ansMouse.containsMouse ? Theme.cornerRadiusXL : parent.outerR
                topRightRadius: ansMouse.containsMouse ? Theme.cornerRadiusXL : parent.outerR
                bottomLeftRadius: ansMouse.containsMouse ? Theme.cornerRadiusXL : parent.innerR
                bottomRightRadius: ansMouse.containsMouse ? Theme.cornerRadiusXL : parent.innerR
                color: ansMouse.containsMouse ? Theme.foregroundColor(Theme.surfaceContainerHighest, true) : Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                border.width: 1
                border.color: ansMouse.containsMouse ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                Behavior on color { DColorAnim { duration: Theme.shortDuration } }

                MouseArea {
                    id: ansMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CalculatorService.copyResult()
                }

                StyledText {
                    id: mainResult
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingM
                    text: root.resultText !== "" ? root.resultText : "0"
                    font.pixelSize: text.length > 14 ? root.baseFontSize * 0.65 : text.length > 9 ? root.baseFontSize * 0.80 : root.baseFontSize
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                    wrapMode: Text.NoWrap

                    Behavior on font.pixelSize {
                        DAnim {
                            duration: Theme.shortDuration
                            easing.bezierCurve: Theme.expressiveCurves.standard
                        }
                    }
                }
            }

            // Last Segment: Typing numbers & equation
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: exprInput.implicitHeight + Theme.spacingS * 2
                topLeftRadius: exprMouse.containsMouse ? Theme.cornerRadiusXL : parent.innerR
                topRightRadius: exprMouse.containsMouse ? Theme.cornerRadiusXL : parent.innerR
                bottomLeftRadius: exprMouse.containsMouse ? Theme.cornerRadiusXL : parent.outerR
                bottomRightRadius: exprMouse.containsMouse ? Theme.cornerRadiusXL : parent.outerR
                color: exprMouse.containsMouse ? Theme.foregroundColor(Theme.surfaceContainerHighest, true) : Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                border.width: 1
                border.color: exprMouse.containsMouse ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                Behavior on color { DColorAnim { duration: Theme.shortDuration } }

                MouseArea {
                    id: exprMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.IBeamCursor
                    onClicked: exprInput.forceActiveFocus()
                }

                TextInput {
                    id: exprInput
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingM
                    text: root.expression
                    font.pixelSize: Math.max(14, Math.min(22, root.baseFontSize * 0.45))
                    color: Theme.primary
                    selectionColor: Theme.withAlpha(Theme.primary, 0.3)
                    selectedTextColor: Theme.surfaceText
                    horizontalAlignment: TextInput.AlignRight
                    selectByMouse: true
                    clip: true
                    onTextEdited: {
                        CalculatorService.expression = text;
                        CalculatorService.justEvaluated = false;
                        CalculatorService.updateLiveEval();
                    }
                    Keys.onPressed: event => {
                        if (event.text && event.text.length === 1)
                            CalculatorService.triggerKeyPressAnim(event.text);
                    }
                    Keys.onReturnPressed: CalculatorService.evaluate()
                    Keys.onEnterPressed: CalculatorService.evaluate()
                }

                StyledText {
                    visible: exprInput.text === "" && !exprInput.activeFocus
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: Theme.spacingM
                    text: "0"
                    font.pixelSize: exprInput.font.pixelSize
                    color: Theme.withAlpha(Theme.primary, 0.5)
                }
            }
        }
    }
}
