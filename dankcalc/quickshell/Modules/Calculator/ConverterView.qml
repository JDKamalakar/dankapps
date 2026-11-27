import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets
import "UnitConverterLogic.js" as ConvLogic

Item {
    id: root

    readonly property bool isLandscape: width >= 540 && width > height * 1.05

    GridLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        anchors.bottomMargin: Theme.spacingM
        columns: root.isLandscape ? 3 : 1
        columnSpacing: 4
        rowSpacing: Theme.spacingS

        // ── LEFT / TOP PANE: DISPLAY + UNIT SELECTORS ───────────────────────
        Rectangle {
            id: leftPane
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: root.isLandscape
                ? Math.floor(parent.width * (CalculatorService.historyOpen ? 0.28 : 0.50))
                : -1
            radius: Theme.cornerRadiusXL
            topRightRadius: CalculatorService.historyOpen ? (Theme.cornerRadiusS ?? 8) : Theme.cornerRadiusXL
            bottomRightRadius: CalculatorService.historyOpen ? (Theme.cornerRadiusS ?? 8) : Theme.cornerRadiusXL
            color: Theme.foregroundColor(Theme.surfaceContainerLow, true)
            border.width: 1
            border.color: Theme.outlineMedium ?? Theme.outlineVariant
            clip: true

            Behavior on Layout.preferredWidth {
                DAnim {
                    duration: Theme.mediumDuration
                    easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                // Top Bar: Category Selector on Left, History Button on Right
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingS

                    Rectangle {
                        id: convCatBtn
                        visible: CalculatorService.converterCategory !== "currency"
                        width: convCatRow.implicitWidth + Theme.spacingM * 2
                        height: 32
                        radius: (CalculatorService.categoryMenuOpen || convCatMouse.pressed || convCatMouse.containsMouse) ? height / 2 : (Theme.cornerRadiusS ?? 8)
                        color: (CalculatorService.categoryMenuOpen || convCatMouse.containsMouse) ? Theme.withAlpha(Theme.primary, 0.2) : Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                        border.width: 1
                        border.color: (CalculatorService.categoryMenuOpen || convCatMouse.containsMouse) ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                        scale: convCatMouse.pressed ? 0.96 : 1.0

                        Behavior on radius { DAnim { duration: Theme.shortDuration; easing.bezierCurve: Theme.expressiveCurves.standard } }
                        Behavior on scale { DAnim { duration: Theme.shortDuration; easing.bezierCurve: Theme.expressiveCurves.fastSpatial } }
                        Behavior on color { DColorAnim { duration: Theme.shortDuration } }

                        Row {
                            id: convCatRow
                            anchors.centerIn: parent
                            spacing: 4
                            DIcon { name: ConvLogic.getCategory(CalculatorService.converterCategory).icon; size: 15; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            StyledText { text: ConvLogic.getCategory(CalculatorService.converterCategory).name; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                            DIcon { name: "arrow_drop_down"; size: 15; color: Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }
                        }

                        MouseArea {
                            id: convCatMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const pt = convCatBtn.mapToItem(null, 0, convCatBtn.height + 6);
                                CalculatorService.categoryMenuPos = Qt.point(pt.x, pt.y);
                                CalculatorService.categoryMenuOpen = !CalculatorService.categoryMenuOpen;
                            }
                        }
                    }

                    // Currency Mode: Live Exchange Rate & Refresh Chips (Flow grid, segmented first/mid/last)
                    Flow {
                        visible: CalculatorService.converterCategory === "currency"
                        Layout.fillWidth: true
                        spacing: 4

                        readonly property real outerR: 16
                        readonly property real innerR: Theme.cornerRadiusS ?? 8

                        Rectangle {
                            id: ratePillBtn
                            width: ratePillRow.implicitWidth + Theme.spacingM * 2
                            height: 32
                            topLeftRadius: parent.outerR
                            bottomLeftRadius: parent.outerR
                            topRightRadius: CalculatorService.extraCurrencies.length > 0 ? parent.innerR : parent.outerR
                            bottomRightRadius: CalculatorService.extraCurrencies.length > 0 ? parent.innerR : parent.outerR
                            color: ratePillMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.2) : Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                            border.width: 1
                            border.color: ratePillMouse.containsMouse ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                            Row {
                                id: ratePillRow
                                anchors.centerIn: parent
                                spacing: 6
                                DIcon { name: "refresh"; size: 14; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                StyledText {
                                    text: "1 " + CalculatorService.converterFromUnit + " = " + ConvLogic.convert("currency", "1", CalculatorService.converterFromUnit, CalculatorService.converterToUnit) + " " + CalculatorService.converterToUnit
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: ratePillMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: CalculatorService.refreshCurrencyRates()
                            }
                        }

                        // Extra Currency Rate Chips
                        Repeater {
                            model: CalculatorService.converterCategory === "currency" ? CalculatorService.extraCurrencies : []
                            delegate: Rectangle {
                                required property string modelData
                                required property int index
                                readonly property bool isLast: index === CalculatorService.extraCurrencies.length - 1
                                height: 32
                                width: extraRateRow.implicitWidth + Theme.spacingM * 2
                                topLeftRadius: parent.innerR
                                bottomLeftRadius: parent.innerR
                                topRightRadius: isLast ? parent.outerR : parent.innerR
                                bottomRightRadius: isLast ? parent.outerR : parent.innerR
                                color: extraRateMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.2) : Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                                border.width: 1
                                border.color: extraRateMouse.containsMouse ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                                Row {
                                    id: extraRateRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    DIcon { name: "refresh"; size: 14; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                    StyledText {
                                        text: "1 " + CalculatorService.converterFromUnit + " = " + ConvLogic.convert("currency", "1", CalculatorService.converterFromUnit, modelData) + " " + modelData
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: extraRateMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: CalculatorService.refreshCurrencyRates()
                                }
                            }
                        }
                    }

                    Item {
                        visible: CalculatorService.converterCategory !== "currency"
                        Layout.fillWidth: true
                    }

                    // Currency Mode: Add Extra Currency (+) Pill
                    Rectangle {
                        id: addCurrBtn
                        visible: CalculatorService.converterCategory === "currency"
                        width: 32
                        height: 32
                        radius: (addCurrMouse.pressed || addCurrMouse.containsMouse) ? height / 2 : (Theme.cornerRadiusS ?? 8)
                        color: addCurrMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.2) : Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                        border.width: 1
                        border.color: addCurrMouse.containsMouse ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                        DIcon { anchors.centerIn: parent; name: "add"; size: 16; color: Theme.primary }

                        MouseArea {
                            id: addCurrMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const pt = addCurrBtn.mapToItem(null, 0, addCurrBtn.height + 6);
                                CalculatorService.unitPickerRect = Qt.rect(pt.x, pt.y, 220, addCurrBtn.height);
                                CalculatorService.converterPickerTarget = CalculatorService.converterPickerTarget === "extra" ? "" : "extra";
                            }
                        }
                    }

                    Rectangle {
                        id: convHistBtn
                        visible: !CalculatorService.historyOpen
                        width: convHistRow.implicitWidth + Theme.spacingM * 2
                        height: 32
                        radius: (convHistMouse.pressed || convHistMouse.containsMouse) ? height / 2 : (Theme.cornerRadiusS ?? 8)
                        color: (CalculatorService.historyOpen || convHistMouse.containsMouse) ? Theme.withAlpha(Theme.primary, 0.2) : Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                        border.width: 1
                        border.color: (CalculatorService.historyOpen || convHistMouse.containsMouse) ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                        scale: convHistMouse.pressed ? 0.96 : 1.0

                        Behavior on radius { DAnim { duration: Theme.shortDuration; easing.bezierCurve: Theme.expressiveCurves.standard } }
                        Behavior on scale { DAnim { duration: Theme.shortDuration; easing.bezierCurve: Theme.expressiveCurves.fastSpatial } }
                        Behavior on color { DColorAnim { duration: Theme.shortDuration } }

                        Row {
                            id: convHistRow
                            anchors.centerIn: parent
                            spacing: 4
                            DIcon { name: "history"; size: 15; color: convHistMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }
                            StyledText { text: "History"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: convHistMouse.containsMouse ? Theme.primary : Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                        }

                        MouseArea {
                            id: convHistMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: CalculatorService.historyOpen = !CalculatorService.historyOpen
                        }
                    }
                }

                // ── VALUE & UNIT CONVERSION DISPLAY AREA ─────────────────────────
                Item {
                    id: displayArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: root.isLandscape ? 90 : 120

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        spacing: 2

                        readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                        readonly property real innerR: Theme.groupedListInnerRadius ?? 4

                        // Extra Currencies (Top, Currency x -> Currency 2)
                        Repeater {
                            model: CalculatorService.converterCategory === "currency" ? CalculatorService.extraCurrencies.slice().reverse() : []
                            delegate: Rectangle {
                                id: extraCard
                                required property string modelData
                                required property int index
                                readonly property bool isFirstExtra: index === 0
                                readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                                readonly property real innerR: Theme.groupedListInnerRadius ?? 4

                                Layout.fillWidth: true
                                Layout.preferredHeight: extraValCol.implicitHeight + Theme.spacingS * 2
                                topLeftRadius: extraMouse.containsMouse ? Theme.cornerRadiusXL : (isFirstExtra ? outerR : innerR)
                                topRightRadius: extraMouse.containsMouse ? Theme.cornerRadiusXL : (isFirstExtra ? outerR : innerR)
                                bottomLeftRadius: extraMouse.containsMouse ? Theme.cornerRadiusXL : innerR
                                bottomRightRadius: extraMouse.containsMouse ? Theme.cornerRadiusXL : innerR
                                color: extraMouse.containsMouse ? Theme.foregroundColor(Theme.surfaceContainerHighest, true) : Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                                border.width: 1
                                border.color: extraMouse.containsMouse ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                                Behavior on color { DColorAnim { duration: Theme.shortDuration } }

                                Component.onCompleted: {
                                    if (!Theme.reduceMotion) extraAppearAnim.restart();
                                }
                                ParallelAnimation {
                                    id: extraAppearAnim
                                    NumberAnimation { target: extraCard; property: "opacity"; from: 0.0; to: 1.0; duration: Theme.shortDuration; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: extraCard; property: "scale"; from: 0.94; to: 1.0; duration: Theme.shortDuration; easing.type: Easing.OutCubic }
                                }

                                MouseArea {
                                    id: extraMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: CalculatorService.copyToClipboard(ConvLogic.convert("currency", CalculatorService.converterFromValue, CalculatorService.converterFromUnit, extraCard.modelData))
                                }

                                DIconButton {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Theme.spacingS
                                    iconName: "close"
                                    size: "xs"
                                    variant: "standard"
                                    onClicked: CalculatorService.removeExtraCurrency(extraCard.modelData)
                                }

                                ColumnLayout {
                                    id: extraValCol
                                    anchors.fill: parent
                                    anchors.topMargin: Theme.spacingS
                                    anchors.bottomMargin: Theme.spacingS
                                    anchors.leftMargin: Theme.spacingM + 32
                                    anchors.rightMargin: Theme.spacingL
                                    spacing: 2

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: ConvLogic.convert("currency", CalculatorService.converterFromValue, CalculatorService.converterFromUnit, extraCard.modelData)
                                        font.pixelSize: Math.max(22, Math.min(36, displayArea.width * 0.09))
                                        font.weight: Font.Bold
                                        color: extraMouse.containsMouse ? Theme.primary : Theme.surfaceText
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideLeft
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: ConvLogic.getUnitName("currency", extraCard.modelData)
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.SemiBold
                                        color: Theme.primary
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }

                        // Middle: "To" Value & Unit (Currency 1 - Click to copy)
                        Rectangle {
                            id: toValueRow
                            Layout.fillWidth: true
                            Layout.preferredHeight: toValCol.implicitHeight + Theme.spacingM * 2
                            topLeftRadius: toCardMouse.containsMouse ? Theme.cornerRadiusXL : ((CalculatorService.converterCategory === "currency" && CalculatorService.extraCurrencies.length > 0) ? parent.innerR : parent.outerR)
                            topRightRadius: toCardMouse.containsMouse ? Theme.cornerRadiusXL : ((CalculatorService.converterCategory === "currency" && CalculatorService.extraCurrencies.length > 0) ? parent.innerR : parent.outerR)
                            bottomLeftRadius: toCardMouse.containsMouse ? Theme.cornerRadiusXL : parent.innerR
                            bottomRightRadius: toCardMouse.containsMouse ? Theme.cornerRadiusXL : parent.innerR
                            color: toCardMouse.containsMouse ? Theme.foregroundColor(Theme.surfaceContainerHighest, true) : Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                            border.width: 1
                            border.color: toCardMouse.containsMouse ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                            Behavior on color { DColorAnim { duration: Theme.shortDuration } }

                            MouseArea {
                                id: toCardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton
                                onClicked: CalculatorService.copyConverterResult()
                            }

                            ColumnLayout {
                                id: toValCol
                                anchors.fill: parent
                                anchors.topMargin: Theme.spacingM
                                anchors.bottomMargin: Theme.spacingM
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingL
                                spacing: 2

                                StyledText {
                                    Layout.fillWidth: true
                                    text: CalculatorService.converterToValue
                                    font.pixelSize: Math.max(28, Math.min(50, displayArea.width * 0.12))
                                    font.weight: Font.Bold
                                    color: toCardMouse.containsMouse ? Theme.primary : Theme.surfaceText
                                    horizontalAlignment: Text.AlignRight
                                    elide: Text.ElideLeft

                                    Behavior on color {
                                        DColorAnim {
                                            duration: M3E.effectsFastMs
                                            easing.bezierCurve: M3E.curveFastEffects
                                        }
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: ConvLogic.getUnitName(CalculatorService.converterCategory, CalculatorService.converterToUnit)
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.SemiBold
                                    color: Theme.primary
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }

                        // Bottom Segment: "From" Value & Unit (Secondary / Input)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: fromValCol.implicitHeight + Theme.spacingS * 2
                            topLeftRadius: parent.innerR
                            topRightRadius: parent.innerR
                            bottomLeftRadius: parent.outerR
                            bottomRightRadius: parent.outerR
                            color: Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                            border.width: 1
                            border.color: Theme.outlineMedium ?? Theme.outlineVariant

                            ColumnLayout {
                                id: fromValCol
                                anchors.fill: parent
                                anchors.topMargin: Theme.spacingS
                                anchors.bottomMargin: Theme.spacingS
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingL
                                spacing: 2

                                StyledText {
                                    Layout.fillWidth: true
                                    text: CalculatorService.converterFromValue
                                    font.pixelSize: Math.max(20, Math.min(32, displayArea.width * 0.08))
                                    font.weight: Font.Normal
                                    color: Theme.surfaceText
                                    horizontalAlignment: Text.AlignRight
                                    elide: Text.ElideLeft
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: ConvLogic.getUnitName(CalculatorService.converterCategory, CalculatorService.converterFromUnit)
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceVariantText
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }

            // ── PILL UNIT SELECTOR & SWAP BUTTON ─────────────────────────────
            // Default (2-unit/currency) horizontal row
            Item {
                visible: !(CalculatorService.converterCategory === "currency" && CalculatorService.extraCurrencies.length > 0)
                Layout.fillWidth: true
                implicitHeight: Style.buttonHeightS

            RowLayout {
                anchors.fill: parent
                spacing: 4

                readonly property real outerR: height / 2
                readonly property real innerR: Theme.cornerRadiusS ?? 8

                // "From" Unit Grouped Button
                Rectangle {
                    id: fromUnitButton
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.buttonHeightS
                    readonly property bool isPill: fromUnitMouse.containsMouse || fromUnitMouse.pressed || CalculatorService.converterPickerTarget === "from"
                    topLeftRadius: parent.outerR
                    bottomLeftRadius: parent.outerR
                    topRightRadius: isPill ? parent.outerR : parent.innerR
                    bottomRightRadius: isPill ? parent.outerR : parent.innerR
                    color: fromUnitMouse.containsMouse || CalculatorService.converterPickerTarget === "from"
                           ? Theme.surfaceContainerHighest
                           : Theme.surfaceContainerHigh
                    border.color: CalculatorService.converterPickerTarget === "from"
                                  ? M3E.stroke(Theme.primary, M3E.strokeControl)
                                  : M3E.stroke(Theme.outlineVariant, M3E.strokeControl)
                    border.width: 1

                    scale: fromUnitMouse.pressed ? 0.97 : 1.0
                    Behavior on scale {
                        DAnim {
                            duration: M3E.spatialFastMs
                            easing.bezierCurve: M3E.curveFastSpatial
                        }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM

                        StyledText {
                            Layout.fillWidth: true
                            text: ConvLogic.getUnitFullName(CalculatorService.converterCategory, CalculatorService.converterFromUnit)
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight

                            onTextChanged: {
                                if (!Theme.reduceMotion) unitTextAnim.restart();
                            }
                            SequentialAnimation on opacity {
                                id: unitTextAnim
                                running: false
                                NumberAnimation { from: 0.25; to: 1.0; duration: Theme.shortDuration; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    MouseArea {
                        id: fromUnitMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const pt = fromUnitButton.mapToItem(null, 0, 0);
                            CalculatorService.unitPickerRect = Qt.rect(pt.x, pt.y, fromUnitButton.width, fromUnitButton.height);
                            CalculatorService.converterPickerTarget = CalculatorService.converterPickerTarget === "from" ? "" : "from";
                        }
                    }
                }

                // Swap Units Button (Icon button with swap_horiz)
                Rectangle {
                    id: swapBtn
                    property real swapRotation: 0
                    implicitWidth: Style.buttonHeightS
                    implicitHeight: Style.buttonHeightS
                    radius: height / 2
                    color: swapMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                    border.color: M3E.stroke(Theme.outlineVariant, M3E.strokeControl)
                    border.width: 1

                    scale: swapMouse.pressed ? 0.92 : 1.0
                    Behavior on scale {
                        DAnim {
                            duration: M3E.spatialFastMs
                            easing.bezierCurve: M3E.curveFastSpatial
                        }
                    }

                    DIcon {
                        anchors.centerIn: parent
                        name: "swap_horiz"
                        size: Style.iconSizeSmall
                        color: Theme.primary
                        rotation: swapBtn.swapRotation

                        Behavior on rotation {
                            DAnim {
                                duration: Theme.mediumDuration
                                easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                            }
                        }
                    }

                    MouseArea {
                        id: swapMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            swapBtn.swapRotation += 180;
                            CalculatorService.swapConverterUnits();
                        }
                    }
                }

                // "To" Unit Grouped Button
                Rectangle {
                    id: toUnitButton
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.buttonHeightS
                    readonly property bool isPill: toUnitMouse.containsMouse || toUnitMouse.pressed || CalculatorService.converterPickerTarget === "to"
                    topLeftRadius: isPill ? parent.outerR : parent.innerR
                    bottomLeftRadius: isPill ? parent.outerR : parent.innerR
                    topRightRadius: parent.outerR
                    bottomRightRadius: parent.outerR
                    color: toUnitMouse.containsMouse || CalculatorService.converterPickerTarget === "to"
                           ? Theme.surfaceContainerHighest
                           : Theme.surfaceContainerHigh
                    border.color: CalculatorService.converterPickerTarget === "to"
                                  ? M3E.stroke(Theme.primary, M3E.strokeControl)
                                  : M3E.stroke(Theme.outlineVariant, M3E.strokeControl)
                    border.width: 1

                    scale: toUnitMouse.pressed ? 0.97 : 1.0
                    Behavior on scale {
                        DAnim {
                            duration: M3E.spatialFastMs
                            easing.bezierCurve: M3E.curveFastSpatial
                        }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM

                        StyledText {
                            Layout.fillWidth: true
                            text: ConvLogic.getUnitFullName(CalculatorService.converterCategory, CalculatorService.converterToUnit)
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight

                            onTextChanged: {
                                if (!Theme.reduceMotion) toUnitTextAnim.restart();
                            }
                            SequentialAnimation on opacity {
                                id: toUnitTextAnim
                                running: false
                                NumberAnimation { from: 0.25; to: 1.0; duration: Theme.shortDuration; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    MouseArea {
                        id: toUnitMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const pt = toUnitButton.mapToItem(null, 0, 0);
                            CalculatorService.unitPickerRect = Qt.rect(pt.x, pt.y, toUnitButton.width, toUnitButton.height);
                            CalculatorService.converterPickerTarget = CalculatorService.converterPickerTarget === "to" ? "" : "to";
                        }
                    }
                }
            }
            }

            // Multi-currency (>2 currencies) stacked controls:
            // Converting currencies row (segmented) -> Switch button -> Typing currency (bottom-most)
            ColumnLayout {
                visible: CalculatorService.converterCategory === "currency" && CalculatorService.extraCurrencies.length > 0
                Layout.fillWidth: true
                spacing: Theme.spacingXS

                // 1. Row for the converting currencies (segmented group)
                RowLayout {
                    id: multiToRow
                    Layout.fillWidth: true
                    spacing: 4

                    readonly property real outerR: Style.buttonHeightS / 2
                    readonly property real innerR: Theme.cornerRadiusS ?? 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.buttonHeightS
                        topLeftRadius: multiToRow.outerR
                        bottomLeftRadius: multiToRow.outerR
                        topRightRadius: multiToRow.innerR
                        bottomRightRadius: multiToRow.innerR
                        color: Theme.surfaceContainerHigh
                        border.color: M3E.stroke(Theme.outlineVariant, M3E.strokeControl)
                        border.width: 1

                        StyledText {
                            anchors.centerIn: parent
                            text: CalculatorService.converterToUnit
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const pt = parent.mapToItem(null, 0, 0);
                                CalculatorService.unitPickerRect = Qt.rect(pt.x, pt.y, parent.width, parent.height);
                                CalculatorService.converterPickerTarget = "to";
                            }
                        }
                    }

                    Repeater {
                        model: CalculatorService.extraCurrencies
                        delegate: Rectangle {
                            required property string modelData
                            required property int index
                            readonly property bool isLast: index === CalculatorService.extraCurrencies.length - 1
                            Layout.fillWidth: true
                            Layout.preferredHeight: Style.buttonHeightS
                            topLeftRadius: multiToRow.innerR
                            bottomLeftRadius: multiToRow.innerR
                            topRightRadius: isLast ? multiToRow.outerR : multiToRow.innerR
                            bottomRightRadius: isLast ? multiToRow.outerR : multiToRow.innerR
                            color: Theme.surfaceContainerHigh
                            border.color: M3E.stroke(Theme.outlineVariant, M3E.strokeControl)
                            border.width: 1

                            StyledText {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const pt = parent.mapToItem(null, 0, 0);
                                    CalculatorService.unitPickerRect = Qt.rect(pt.x, pt.y, parent.width, parent.height);
                                    CalculatorService.converterPickerTarget = "extra";
                                }
                            }
                        }
                    }
                }

                // 2. Multiple angled swap buttons (funnel going down, center straight)
                RowLayout {
                    id: multiSwapRow
                    Layout.fillWidth: true
                    spacing: 4
                    readonly property real centerIdx: CalculatorService.extraCurrencies.length / 2.0

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: Style.buttonHeightS

                        Rectangle {
                            anchors.centerIn: parent
                            implicitWidth: Style.buttonHeightS
                            implicitHeight: Style.buttonHeightS
                            radius: height / 2
                            color: mainSwapMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                            border.color: M3E.stroke(Theme.outlineVariant, M3E.strokeControl)
                            border.width: 1

                            DIcon {
                                anchors.centerIn: parent
                                name: "swap_vert"
                                size: Style.iconSizeSmall
                                color: Theme.primary
                                rotation: (0 === multiSwapRow.centerIdx ? 0 : (0 < multiSwapRow.centerIdx ? -30 : 30)) + swapBtn.swapRotation
                                Behavior on rotation {
                                    DAnim {
                                        duration: Theme.mediumDuration
                                        easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                                    }
                                }
                            }

                            MouseArea {
                                id: mainSwapMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    swapBtn.swapRotation += 180;
                                    CalculatorService.swapConverterUnits();
                                }
                            }
                        }
                    }

                    Repeater {
                        model: CalculatorService.extraCurrencies
                        delegate: Item {
                            required property string modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: Style.buttonHeightS

                            Rectangle {
                                id: extraSwapBtn
                                property real extraSwapRotation: 0
                                anchors.centerIn: parent
                                implicitWidth: Style.buttonHeightS
                                implicitHeight: Style.buttonHeightS
                                radius: height / 2
                                color: extraSwapMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                border.color: M3E.stroke(Theme.outlineVariant, M3E.strokeControl)
                                border.width: 1

                                DIcon {
                                    anchors.centerIn: parent
                                    name: "swap_vert"
                                    size: Style.iconSizeSmall
                                    color: Theme.primary
                                    rotation: (((index + 1) === multiSwapRow.centerIdx ? 0 : ((index + 1) < multiSwapRow.centerIdx ? -30 : 30))) + extraSwapBtn.extraSwapRotation
                                    Behavior on rotation {
                                        DAnim {
                                            duration: Theme.mediumDuration
                                            easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                                        }
                                    }
                                }

                                MouseArea {
                                    id: extraSwapMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        extraSwapBtn.extraSwapRotation += 180;
                                        const targetCurr = modelData;
                                        const oldFrom = CalculatorService.converterFromUnit;
                                        const nextExtra = CalculatorService.extraCurrencies.slice();
                                        nextExtra[index] = oldFrom;
                                        CalculatorService.setConverterFromUnit(targetCurr);
                                        CalculatorService.extraCurrencies = nextExtra;
                                    }
                                }
                            }
                        }
                    }
                }

                // 3. Bottom-most: Currency we are typing
                Rectangle {
                    id: multiFromBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.buttonHeightS
                    radius: height / 2
                    color: multiFromMouse.containsMouse || CalculatorService.converterPickerTarget === "from"
                           ? Theme.surfaceContainerHighest
                           : Theme.surfaceContainerHigh
                    border.color: CalculatorService.converterPickerTarget === "from"
                                  ? M3E.stroke(Theme.primary, M3E.strokeControl)
                                  : M3E.stroke(Theme.outlineVariant, M3E.strokeControl)
                    border.width: 1

                    StyledText {
                        anchors.centerIn: parent
                        text: ConvLogic.getUnitFullName(CalculatorService.converterCategory, CalculatorService.converterFromUnit)
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: multiFromMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const pt = multiFromBtn.mapToItem(null, 0, 0);
                            CalculatorService.unitPickerRect = Qt.rect(pt.x, pt.y, multiFromBtn.width, multiFromBtn.height);
                            CalculatorService.converterPickerTarget = CalculatorService.converterPickerTarget === "from" ? "" : "from";
                        }
                    }
                }
            }
            }
        }

        // ── MIDDLE: INLINE HISTORY SLIDEOUT (LANDSCAPE) ──────────────────────
        HistoryPanel {
            id: convInlineHistoryPanel
            inlineMode: true
            Layout.fillWidth: false
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: (root.isLandscape && CalculatorService.historyOpen)
                ? Math.floor(parent.width * 0.22)
                : 0

            Behavior on Layout.preferredWidth {
                DAnim {
                    duration: Theme.mediumDuration
                    easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                }
            }
        }

        // ── 3-COLUMN CONVERTER KEYPAD ───────────────────────────────────────
        Item {
            Layout.fillWidth: !root.isLandscape
            Layout.fillHeight: root.isLandscape
            Layout.preferredWidth: root.isLandscape ? Math.floor(parent.width * 0.50) : -1
            Layout.preferredHeight: root.isLandscape ? -1 : Math.max(220, root.height * 0.52)

            GridLayout {
                id: converterGrid
                anchors.fill: parent
                columns: 3
                columnSpacing: Math.max(8, Math.min(14, converterGrid.width * 0.025))
                rowSpacing: Math.max(8, Math.min(14, converterGrid.height * 0.025))

                // Row 1: AC, ±, ⌫
                CalculatorButton {
                    text: "AC"
                    backgroundColor: Theme.tertiaryContainer
                    textColor: Theme.onTertiaryContainer
                    fontWeight: Font.Medium
                    onClicked: CalculatorService.clearConverter()
                }

                CalculatorButton {
                    text: "±"
                    backgroundColor: Theme.primaryContainer
                    textColor: Theme.onPrimaryContainer
                    fontWeight: Font.Medium
                    onClicked: CalculatorService.toggleConverterSign()
                }

                CalculatorButton {
                    iconName: "backspace"
                    backgroundColor: Theme.secondaryContainer
                    textColor: Theme.onSecondaryContainer
                    onClicked: CalculatorService.backspaceConverter()
                }

                // Row 2: 7, 8, 9
                CalculatorButton {
                    text: "7"
                    onClicked: CalculatorService.appendConverterDigit("7")
                }
                CalculatorButton {
                    text: "8"
                    onClicked: CalculatorService.appendConverterDigit("8")
                }
                CalculatorButton {
                    text: "9"
                    onClicked: CalculatorService.appendConverterDigit("9")
                }

                // Row 3: 4, 5, 6
                CalculatorButton {
                    text: "4"
                    onClicked: CalculatorService.appendConverterDigit("4")
                }
                CalculatorButton {
                    text: "5"
                    onClicked: CalculatorService.appendConverterDigit("5")
                }
                CalculatorButton {
                    text: "6"
                    onClicked: CalculatorService.appendConverterDigit("6")
                }

                // Row 4: 1, 2, 3
                CalculatorButton {
                    text: "1"
                    onClicked: CalculatorService.appendConverterDigit("1")
                }
                CalculatorButton {
                    text: "2"
                    onClicked: CalculatorService.appendConverterDigit("2")
                }
                CalculatorButton {
                    text: "3"
                    onClicked: CalculatorService.appendConverterDigit("3")
                }

                // Row 5: ., 0, 00
                CalculatorButton {
                    text: "."
                    fontWeight: Font.Medium
                    onClicked: CalculatorService.appendConverterDecimal()
                }
                CalculatorButton {
                    text: "0"
                    onClicked: CalculatorService.appendConverterDigit("0")
                }
                CalculatorButton {
                    text: "00"
                    backgroundColor: Theme.surfaceContainerHighest
                    textColor: Theme.surfaceText
                    onClicked: {
                        CalculatorService.appendConverterDigit("0");
                        CalculatorService.appendConverterDigit("0");
                    }
                }
            }
        }
    }

    UnitPickerSheet {
        id: unitPicker
        fromButton: fromUnitButton
        toButton: toUnitButton
    }
}
