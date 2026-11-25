import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Common
import qs.DCommon.Widgets
import "."
import "UnitConverterLogic.js" as ConvLogic

FloatingWindow {
    id: window

    title: CalculatorService.settingsOpen
        ? "Settings — DUX Calculator"
        : (CalculatorService.currentMode === "converter" ? "Unit Converter — DUX Calculator" : "Calculator — DUX Calculator")
    minimumSize: Qt.size(380, 360)
    implicitWidth: 460
    implicitHeight: CalculatorService.currentMode === "converter" ? 560 : (scientificOpen ? 640 : 520)
    color: Theme.windowSurface
    surfaceFormat.opaque: false
    visible: true

    readonly property bool isLandscape: window.width >= 540 && window.width > window.height * 1.05
    property bool scientificOpen: SettingsData.scientificExpanded

    onScientificOpenChanged: {
        SettingsData.scientificExpanded = scientificOpen;
    }

    Item {
        id: rootContent
        anchors.fill: parent
        focus: true

        Component.onCompleted: forceActiveFocus()

        Connections {
            target: CalculatorService
            function onHistoryOpenChanged() {
                if (!CalculatorService.historyOpen) rootContent.forceActiveFocus();
            }
            function onMenuOpenChanged() {
                if (!CalculatorService.menuOpen) rootContent.forceActiveFocus();
            }
            function onCategoryMenuOpenChanged() {
                if (!CalculatorService.categoryMenuOpen) rootContent.forceActiveFocus();
            }
            function onConverterPickerTargetChanged() {
                if (CalculatorService.converterPickerTarget === "") rootContent.forceActiveFocus();
            }
            function onSettingsOpenChanged() {
                if (!CalculatorService.settingsOpen) rootContent.forceActiveFocus();
            }
        }

        // Keyboard navigation and math input
        Keys.onPressed: event => {
            if (event.modifiers & Qt.ControlModifier) {
                switch (event.key) {
                case Qt.Key_Comma:
                    CalculatorService.settingsOpen = !CalculatorService.settingsOpen;
                    event.accepted = true;
                    return;
                case Qt.Key_C:
                    if (CalculatorService.currentMode === "converter") {
                        CalculatorService.copyConverterResult();
                    } else {
                        CalculatorService.copyResult();
                    }
                    event.accepted = true;
                    return;
                case Qt.Key_V:
                    if (CalculatorService.currentMode === "converter") {
                        CalculatorService.pasteConverter();
                    } else {
                        CalculatorService.paste();
                    }
                    event.accepted = true;
                    return;
                case Qt.Key_H:
                    if (CalculatorService.currentMode === "calculator") {
                        CalculatorService.historyOpen = !CalculatorService.historyOpen;
                        event.accepted = true;
                    }
                    return;
                case Qt.Key_S:
                    if (CalculatorService.currentMode === "calculator") {
                        window.scientificOpen = !window.scientificOpen;
                        event.accepted = true;
                    }
                    return;
                }
            }

            // Converter Mode keyboard input
            if (CalculatorService.currentMode === "converter") {
                switch (event.key) {
                case Qt.Key_0:
                case Qt.Key_1:
                case Qt.Key_2:
                case Qt.Key_3:
                case Qt.Key_4:
                case Qt.Key_5:
                case Qt.Key_6:
                case Qt.Key_7:
                case Qt.Key_8:
                case Qt.Key_9:
                    CalculatorService.appendConverterDigit(event.text);
                    event.accepted = true;
                    return;
                case Qt.Key_Period:
                case Qt.Key_Comma:
                    CalculatorService.appendConverterDecimal();
                    event.accepted = true;
                    return;
                case Qt.Key_Backspace:
                    CalculatorService.backspaceConverter();
                    event.accepted = true;
                    return;
                case Qt.Key_Delete:
                    CalculatorService.clearConverter();
                    event.accepted = true;
                    return;
                case Qt.Key_Escape:
                    if (CalculatorService.settingsOpen) {
                        CalculatorService.settingsOpen = false;
                    } else if (CalculatorService.converterPickerTarget !== "") {
                        CalculatorService.converterPickerTarget = "";
                    } else if (CalculatorService.categoryMenuOpen) {
                        CalculatorService.categoryMenuOpen = false;
                    } else if (CalculatorService.menuOpen) {
                        CalculatorService.menuOpen = false;
                    }
                    event.accepted = true;
                    return;
                }
            }

            if (CalculatorService.settingsOpen) {
                if (event.key === Qt.Key_Escape) {
                    CalculatorService.settingsOpen = false;
                    event.accepted = true;
                }
                return;
            }

            // Standard Calculator keyboard input
            switch (event.key) {
            case Qt.Key_0:
            case Qt.Key_1:
            case Qt.Key_2:
            case Qt.Key_3:
            case Qt.Key_4:
            case Qt.Key_5:
            case Qt.Key_6:
            case Qt.Key_7:
            case Qt.Key_8:
            case Qt.Key_9:
                CalculatorService.appendDigit(event.text);
                event.accepted = true;
                break;
            case Qt.Key_Period:
            case Qt.Key_Comma:
                CalculatorService.appendDecimal();
                event.accepted = true;
                break;
            case Qt.Key_Plus:
                CalculatorService.appendOperator("+");
                event.accepted = true;
                break;
            case Qt.Key_Minus:
                CalculatorService.appendOperator("−");
                event.accepted = true;
                break;
            case Qt.Key_Asterisk:
                CalculatorService.appendOperator("×");
                event.accepted = true;
                break;
            case Qt.Key_Slash:
                CalculatorService.appendOperator("÷");
                event.accepted = true;
                break;
            case Qt.Key_Percent:
                CalculatorService.appendPercent();
                event.accepted = true;
                break;
            case Qt.Key_ParenLeft:
            case Qt.Key_ParenRight:
                CalculatorService.appendParenthesis();
                event.accepted = true;
                break;
            case Qt.Key_AsciiCircum:
                CalculatorService.appendScientific("pow");
                event.accepted = true;
                break;
            case Qt.Key_Exclam:
                CalculatorService.appendScientific("fact");
                event.accepted = true;
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Equal:
                CalculatorService.calculate();
                event.accepted = true;
                break;
            case Qt.Key_Backspace:
                CalculatorService.backspace();
                event.accepted = true;
                break;
            case Qt.Key_Delete:
                CalculatorService.clear();
                event.accepted = true;
                break;
            case Qt.Key_Tab:
                window.scientificOpen = !window.scientificOpen;
                event.accepted = true;
                break;
            case Qt.Key_Escape:
                if (CalculatorService.converterPickerTarget !== "") {
                    CalculatorService.converterPickerTarget = "";
                } else if (CalculatorService.categoryMenuOpen) {
                    CalculatorService.categoryMenuOpen = false;
                } else if (CalculatorService.menuOpen) {
                    CalculatorService.menuOpen = false;
                } else if (CalculatorService.historyOpen) {
                    CalculatorService.historyOpen = false;
                } else if (CalculatorService.expression !== "") {
                    CalculatorService.clear();
                }
                event.accepted = true;
                break;
            }
        }

        
    WindowBlur {
        targetWindow: window
        blurEnabled: Theme.translucentWindows
        blurWidth: window.width
        blurHeight: window.height
    }

    FloatingWindowControls {
            id: windowControls
            targetWindow: window
        }

        // Window background card
        Rectangle {
            id: windowFrame
            anchors.fill: parent
            radius: window.maximized ? 0 : Theme.windowRadius
            color: Theme.windowSurface
            border.color: M3E.stroke(Theme.outlineVariant, M3E.strokeCard)
            border.width: window.maximized ? 0 : 1

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    implicitHeight: header.implicitHeight

                    DWindowHeader {
                        id: header
                        anchors.fill: parent
                        controls: windowControls
                        title: CalculatorService.settingsOpen
                            ? "Settings"
                            : (CalculatorService.currentMode === "converter" ? "Unit Converter" : "Calculator")
                        onCloseRequested: Qt.quit()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    // Persistent Left Sidebar
                    Item {
                        id: calcSidebar
                        property bool _floatingRevealed: true
                        readonly property bool _isHidden: SettingsData.sidebarFloating && !_floatingRevealed
                        z: 50
                        clip: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: SettingsData.sidebarFloating ? 16 : calcPrimaryNav.railWidth
                        width: SettingsData.sidebarFloating ? (_isHidden ? 16 : calcPrimaryNav.railWidth + Theme.spacingM * 2 + Theme.spacingS) : calcPrimaryNav.railWidth

                        Behavior on width { enabled: Theme.animationsEnabled; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        HoverHandler {
                            id: calcSidebarHover
                            onHoveredChanged: {
                                if (hovered) {
                                    calcSidebar._floatingRevealed = true;
                                    calcHideTimer.stop();
                                } else if (SettingsData.sidebarFloating) {
                                    calcHideTimer.restart();
                                }
                            }
                        }

                        Timer {
                            id: calcHideTimer
                            interval: SettingsData.sidebarAutoHideMs || 1500
                            onTriggered: {
                                if (SettingsData.sidebarFloating && !calcSidebarHover.hovered)
                                    calcSidebar._floatingRevealed = false;
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 5
                            height: 48
                            radius: 2.5
                            color: Theme.primary
                            opacity: 0.75
                            visible: SettingsData.sidebarFloating
                            z: 5
                        }

                        Rectangle {
                            visible: SettingsData.sidebarFloating
                            opacity: calcSidebar._isHidden ? 0 : 1
                            Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            anchors.fill: parent
                            anchors.topMargin: Theme.spacingS
                            anchors.bottomMargin: Theme.spacingS
                            anchors.leftMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS
                            radius: Theme.groupedListOuterRadius ?? 16
                            color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.78)
                            border.color: Theme.outlineMedium ?? Theme.outlineVariant
                            border.width: 1
                            clip: true
                        }

                        ColumnLayout {
                            id: calcSidebarCol
                            opacity: calcSidebar._isHidden ? 0 : 1
                            Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            anchors.fill: parent
                            anchors.topMargin: Theme.spacingS + (SettingsData.sidebarFloating ? 12 : 0)
                            anchors.bottomMargin: Theme.spacingS + (SettingsData.sidebarFloating ? 12 : 0)
                            anchors.leftMargin: SettingsData.sidebarFloating ? Theme.spacingL : Theme.spacingM
                            anchors.rightMargin: SettingsData.sidebarFloating ? Theme.spacingL : Theme.spacingS
                            spacing: 0

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: SettingsData.sidebarCentered ? Math.max(0, (calcSidebarCol.height - calcPrimaryNav.implicitHeight - calcBottomNav.implicitHeight) / 2) : 0
                                Behavior on Layout.preferredHeight {
                                    enabled: Theme.animationsEnabled
                                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                                }
                            }

                            AppSidebarRail {
                                id: calcPrimaryNav
                                Layout.fillWidth: true
                                Layout.preferredHeight: implicitHeight
                                Layout.alignment: Qt.AlignTop
                                model: [
                                    { icon: "calculate", text: "Calculator" },
                                    { icon: "swap_horiz", text: "Converter" },
                                    { icon: "currency_exchange", text: "Currency" }
                                ]
                                currentIndex: CalculatorService.currentMode === "calculator" ? 0 : (CalculatorService.converterCategory === "currency" ? 2 : 1)
                                onActivated: index => {
                                    if (index === 0) {
                                        CalculatorService.setMode("calculator");
                                    } else if (index === 1) {
                                        CalculatorService.setMode("converter");
                                        if (CalculatorService.converterCategory === "currency")
                                            CalculatorService.setConverterCategory("length");
                                    } else if (index === 2) {
                                        CalculatorService.setMode("converter");
                                        CalculatorService.setConverterCategory("currency");
                                    }
                                    rootContent.forceActiveFocus();
                                }
                            }

                            Item { Layout.fillHeight: true }

                            AppSidebarRail {
                                id: calcBottomNav
                                Layout.fillWidth: true
                                Layout.preferredHeight: implicitHeight
                                model: [{ icon: "settings", text: "Settings" }]
                                currentIndex: CalculatorService.settingsOpen ? 0 : -1
                                onActivated: {
                                    CalculatorService.settingsOpen = true;
                                    rootContent.forceActiveFocus();
                                }
                            }
                        }
                    }

                    // Main Content Foreground Container
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: Theme.spacingXS
                        Layout.rightMargin: Theme.spacingM
                        Layout.topMargin: Theme.spacingXS
                        Layout.bottomMargin: Theme.spacingM
                        radius: Theme.cornerRadiusXL
                        color: Theme.foregroundColor(Theme.surfaceContainer, true)
                        border.width: 1
                        border.color: Theme.withAlpha(Theme.outlineVariant, 0.25)
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                        // Mode & Action Row
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: Style.buttonHeightS

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingM

                                // Calculator Mode: RAD / DEG Chip
                        Rectangle {
                            visible: CalculatorService.currentMode === "calculator"
                            implicitHeight: Style.buttonHeightXS
                            implicitWidth: radText.implicitWidth + Theme.spacingM * 2
                            radius: height / 2
                            color: radMouse.containsMouse
                                   ? Theme.surfaceContainerHighest
                                   : Theme.surfaceContainerHigh
                            border.color: M3E.stroke(Theme.outlineVariant, M3E.strokeControl)
                            border.width: 1

                            scale: radMouse.pressed ? 0.95 : 1.0
                            Behavior on scale {
                                DAnim {
                                    duration: M3E.spatialFastMs
                                    easing.bezierCurve: M3E.curveFastSpatial
                                }
                            }
                            Behavior on color {
                                DColorAnim { duration: Theme.shortDuration }
                            }

                            StyledText {
                                id: radText
                                anchors.centerIn: parent
                                text: CalculatorService.isRad ? "RAD" : "DEG"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                                color: Theme.primary
                            }

                            MouseArea {
                                id: radMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: CalculatorService.toggleRad()
                            }
                        }

                        // Converter Mode: Category Dropdown Button (Left-aligned next to Menu)
                        Rectangle {
                            visible: CalculatorService.currentMode === "converter"
                            implicitHeight: Style.buttonHeightXS
                            implicitWidth: catBtnRow.implicitWidth + Style.spacingL
                            radius: height / 2
                            color: catBtnMouse.containsMouse || CalculatorService.categoryMenuOpen
                                   ? Theme.surfaceContainerHighest
                                   : Theme.surfaceContainerHigh
                            border.color: M3E.stroke(Theme.outlineVariant, M3E.strokeControl)
                            border.width: 1

                            RowLayout {
                                id: catBtnRow
                                anchors.centerIn: parent
                                spacing: Style.spacingXS

                                DIcon {
                                    name: ConvLogic.getCategory(CalculatorService.converterCategory).icon
                                    size: Style.iconSizeSmall
                                    color: Theme.primary
                                }

                                StyledText {
                                    text: ConvLogic.getCategory(CalculatorService.converterCategory).name
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }

                                DIcon {
                                    name: "arrow_drop_down"
                                    size: Style.iconSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                            }

                            MouseArea {
                                id: catBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: CalculatorService.categoryMenuOpen = !CalculatorService.categoryMenuOpen
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Calculator Mode: History Button
                        DIconButton {
                            visible: CalculatorService.currentMode === "calculator"
                            iconName: "history"
                            size: "s"
                            variant: "standard"
                            tooltipText: "History"
                            onClicked: CalculatorService.historyOpen = !CalculatorService.historyOpen
                        }
                    }
                }

                // Standard Calculator Content
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0
                    visible: CalculatorService.currentMode === "calculator"

                    // Display Area
                    CalculatorDisplay {
                        Layout.fillWidth: true
                        Layout.preferredHeight: window.isLandscape
                            ? Math.max(64, Math.min(110, parent.height * 0.24))
                            : Math.max(54, Math.min(120, parent.height * 0.16))
                    }

                    // Scientific Drawer Toggle Row (Portrait only)
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: Style.iconSize
                        visible: !window.isLandscape

                        Rectangle {
                            anchors.centerIn: parent
                            width: Style.buttonHeightS
                            height: Style.iconSizeMedium
                            radius: height / 2
                            color: sciMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                            DIcon {
                                id: sciIcon
                                anchors.centerIn: parent
                                name: "expand_more"
                                size: Style.iconSizeMedium
                                color: Theme.surfaceVariantText
                                rotation: window.scientificOpen ? 180 : 0

                                Behavior on rotation {
                                    DAnim {
                                        duration: Theme.mediumDuration
                                        easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                                    }
                                }
                            }

                            MouseArea {
                                id: sciMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.scientificOpen = !window.scientificOpen
                            }
                        }
                    }

                    // Keypads Area (Stacked in Portrait, Side-by-side in Landscape)
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: window.isLandscape ? 2 : 1
                        columnSpacing: Theme.spacingS
                        rowSpacing: 0

                        // Scientific Keypad Drawer
                        ScientificDrawer {
                            Layout.fillWidth: true
                            Layout.fillHeight: window.isLandscape || window.scientificOpen
                            Layout.preferredWidth: window.isLandscape ? 3 : -1
                            Layout.preferredHeight: window.isLandscape ? -1 : (window.scientificOpen ? 3 : 0)
                            visible: window.isLandscape || window.scientificOpen
                            expanded: window.isLandscape || window.scientificOpen
                            landscape: window.isLandscape
                        }

                        // Main Keypad
                        CalculatorKeypad {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: window.isLandscape ? 4 : -1
                            Layout.preferredHeight: window.isLandscape ? -1 : 5
                            scientificOpen: window.scientificOpen
                            landscape: window.isLandscape
                        }
                    }
                }

                // Unit Converter Content
                ConverterView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: CalculatorService.currentMode === "converter"
                }
                        } // End ColumnLayout
                    } // End Main Content Foreground Container
                } // End RowLayout
            }
        }

        // Overlay Panels
        CategoryMenu {
            id: categoryMenu
        }

        HistoryPanel {
            id: historyPanel
        }

        // In-window toast notification pill
        Rectangle {
            id: inAppToast
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spacingL
            implicitWidth: toastRow.implicitWidth + Theme.spacingM * 2
            implicitHeight: Style.buttonHeightXS
            radius: height / 2
            color: Theme.inverseSurface
            visible: opacity > 0
            opacity: 0.0
            z: 999

            property string message: ""

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }

            RowLayout {
                id: toastRow
                anchors.centerIn: parent
                spacing: Theme.spacingS

                DIcon {
                    name: "check"
                    size: Style.iconSizeSmall
                    color: Theme.inverseOnSurface
                }

                StyledText {
                    text: inAppToast.message
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.inverseOnSurface
                }
            }

            Timer {
                id: toastTimer
                interval: 2000
                onTriggered: inAppToast.opacity = 0.0
            }

            Connections {
                target: CalculatorService
                function onToastRequested(msg) {
                    inAppToast.message = msg;
                    inAppToast.opacity = 1.0;
                    toastTimer.restart();
                }
            }
        }
    }
}
