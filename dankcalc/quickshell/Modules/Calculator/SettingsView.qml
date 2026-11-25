import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets
import qs.Widgets

Item {
    id: root

    property int currentTabIndex: 0
    property bool isCompactMode: width < SettingsMetrics.compactBreakpoint
    property bool menuVisible: false
    readonly property bool compactSearch: isCompactMode && menuVisible && content.searchQuery !== ""

    FocusScope {
        anchors.fill: parent
        focus: true

        readonly property bool isFloatingWindowSurface: true
        readonly property color surfaceColor: Theme.windowSurface

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (!sidebar.clearSearch() && !sidebar.clearHighlight()) {
                    CalculatorService.settingsOpen = false;
                }
                event.accepted = true;
                return;
            }
            if (contentScope.activeFocus || !sidebar.visible)
                return;
            switch (event.key) {
            case Qt.Key_Down:
            case Qt.Key_J:
                sidebar.moveHighlight(1);
                break;
            case Qt.Key_Up:
            case Qt.Key_K:
                sidebar.moveHighlight(-1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (!sidebar.selectHighlighted())
                    return;
                break;
            default:
                return;
            }
            event.accepted = true;
        }

        Column {
            anchors.fill: parent
            spacing: 0

            // Header bar
            Item {
                width: parent.width
                height: Style.buttonHeightS + Theme.spacingS * 2

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    DIconButton {
                        iconName: "arrow_back"
                        size: "s"
                        variant: "standard"
                        tooltipText: "Back to Calculator"
                        onClicked: CalculatorService.settingsOpen = false
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Settings"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.DemiBold
                        color: Theme.surfaceText
                    }
                }

                DActionButton {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.isCompactMode
                    iconName: "menu"
                    buttonSize: Theme.buttonHeightXXS
                    Accessible.name: "Menu"
                    onClicked: root.menuVisible = !root.menuVisible
                }
            }

            // Main settings split container
            Item {
                width: parent.width
                height: parent.height - (Style.buttonHeightS + Theme.spacingS * 2)
                clip: true

                Rectangle {
                    anchors.fill: sidebar
                    color: SettingsMetrics.sidebarColor
                    visible: sidebar.visible && color.a > 0
                }

                SettingsSidebar {
                    id: sidebar
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: root.compactSearch ? undefined : parent.bottom
                    height: root.compactSearch ? implicitHeight : undefined
                    width: root.isCompactMode ? parent.width : implicitWidth
                    visible: root.isCompactMode ? root.menuVisible : true
                    fieldOnly: root.compactSearch
                    currentIndex: root.currentTabIndex
                    onTabSelected: index => {
                        root.currentTabIndex = index;
                        sidebar.clearSearch();
                        if (root.isCompactMode)
                            root.menuVisible = false;
                    }
                }

                FocusScope {
                    id: contentScope

                    anchors.left: root.isCompactMode ? (root.menuVisible && !root.compactSearch ? sidebar.right : parent.left) : sidebar.right
                    anchors.right: parent.right
                    anchors.top: root.compactSearch ? sidebar.bottom : parent.top
                    anchors.bottom: parent.bottom

                    Rectangle {
                        anchors.fill: parent
                        color: SettingsMetrics.paneColor

                        Rectangle {
                            anchors.left: parent.left
                            width: Theme.layerOutlineWidth
                            height: parent.height
                            color: Theme.outlineMedium
                            visible: width > 0 && !root.isCompactMode
                        }
                    }

                    SettingsContent {
                        id: content

                        anchors.fill: parent
                        anchors.leftMargin: SettingsMetrics.panePadding
                        anchors.rightMargin: SettingsMetrics.panePadding
                        currentIndex: root.currentTabIndex
                        searchQuery: sidebar.query
                    }
                }
            }
        }
    }
}
