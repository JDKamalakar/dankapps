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
            if (event.text && event.text.length === 1)
                CalculatorService.triggerKeyPressAnim(event.text);
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

                                // Calculator Mode: RAD / DEG Chip (moved into CalculatorDisplay)
                        Rectangle {
                            visible: false
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

                        // Converter Mode: Category Dropdown Button (moved into ConverterView)

                        Item { Layout.fillWidth: true }

                        // Calculator Mode: History Button (moved into CalculatorDisplay)
                        DIconButton {
                            visible: false
                            iconName: "history"
                            size: "s"
                            variant: "standard"
                            tooltipText: "History"
                            onClicked: CalculatorService.historyOpen = !CalculatorService.historyOpen
                        }
                    }
                }

                // Standard Calculator Content (60% Display Left / 40% Phone-style Keypad Right in Landscape)
                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: window.isLandscape ? 3 : 1
                    columnSpacing: 4
                    rowSpacing: Theme.spacingS
                    visible: CalculatorService.currentMode === "calculator"

                    // Left: Display / Calculations Area (shrinks when history slides out)
                    CalculatorDisplay {
                        Layout.fillWidth: true
                        Layout.fillHeight: window.isLandscape
                        Layout.leftMargin: Theme.spacingM
                        Layout.bottomMargin: Theme.spacingM
                        Layout.preferredWidth: window.isLandscape
                            ? Math.floor(parent.width * (CalculatorService.historyOpen ? 0.28 : 0.50))
                            : -1
                        Layout.preferredHeight: window.isLandscape
                            ? -1
                            : Math.max(120, Math.min(220, parent.height * 0.32))

                        Behavior on Layout.preferredWidth {
                            DAnim {
                                duration: Theme.mediumDuration
                                easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                            }
                        }
                    }

                    // Middle: Inline History Slideout (Landscape)
                    HistoryPanel {
                        id: inlineHistoryPanel
                        inlineMode: true
                        Layout.fillWidth: false
                        Layout.fillHeight: true
                        Layout.bottomMargin: Theme.spacingM
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: (window.isLandscape && CalculatorService.historyOpen)
                            ? Math.floor(parent.width * 0.22)
                            : 0

                        Behavior on Layout.preferredWidth {
                            DAnim {
                                duration: Theme.mediumDuration
                                easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                            }
                        }
                    }

                    // Right (50%): Phone-style Buttons Area (Scientific on top + Keypad below)
                    ColumnLayout {
                        Layout.fillWidth: !window.isLandscape
                        Layout.fillHeight: true
                        Layout.preferredWidth: window.isLandscape ? Math.floor(parent.width * 0.50) : -1
                        Layout.bottomMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        // Scientific Drawer Container (Full button-side width, expands scientific calc inside)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.rightMargin: window.isLandscape ? Theme.spacingM : 0
                            Layout.fillHeight: window.scientificOpen
                            Layout.preferredHeight: window.scientificOpen ? 3 : sciHeader.implicitHeight + Theme.spacingXS * 2
                            radius: Theme.cornerRadiusXL
                            color: Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                            border.width: 1
                            border.color: sciMouse.containsMouse ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                            clip: true

                            Behavior on Layout.preferredHeight {
                                DAnim {
                                    duration: Theme.mediumDuration
                                    easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingXS
                                spacing: Theme.spacingXS

                                // Full-width Arrow Toggle Row
                                Item {
                                    id: sciHeader
                                    Layout.fillWidth: true
                                    implicitHeight: Style.iconSizeMedium

                                    DIcon {
                                        id: sciIcon
                                        anchors.centerIn: parent
                                        name: "expand_more"
                                        size: Style.iconSizeMedium
                                        color: sciMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText
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

                                // Scientific Keypad Drawer (expands inside this container)
                                ScientificDrawer {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: window.scientificOpen
                                    visible: window.scientificOpen
                                    expanded: window.scientificOpen
                                    landscape: false
                                }
                            }
                        }

                        // Main Keypad (Bottom)
                        CalculatorKeypad {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredHeight: 5
                            scientificOpen: window.scientificOpen
                            landscape: false
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
            visible: !window.isLandscape && opacity > 0
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
