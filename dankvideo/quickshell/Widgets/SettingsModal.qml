import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets
import qs.Widgets

FloatingWindow {
    id: settingsModal

    property int currentTabIndex: 0
    property bool isCompactMode: width < SettingsMetrics.compactBreakpoint
    property bool menuVisible: false
    readonly property bool compactSearch: isCompactMode && menuVisible && content.searchQuery !== ""

    function show() {
        visible = true;
        if (!isCompactMode)
            sidebar.focusSearch();
    }

    function hide() {
        visible = false;
        sidebar.clearSearch();
        VideoService.settingsOpen = false;
    }

    onClosed: hide()

    WindowBlur {
        targetWindow: settingsModal
        blurEnabled: Theme.translucentWindows
        blurWidth: settingsModal.width
        blurHeight: settingsModal.height
    }

    title: "DUX Video Settings"
    minimumSize: Qt.size(SettingsMetrics.windowMinWidth, SettingsMetrics.windowMinHeight)
    implicitWidth: screen ? Math.min(SettingsMetrics.windowWidth, screen.width - Theme.spacingXL * 2) : SettingsMetrics.windowWidth
    implicitHeight: screen ? Math.min(SettingsMetrics.windowHeight, screen.height - Theme.spacingXL * 2) : SettingsMetrics.windowHeight
    color: Theme.windowSurface
    surfaceFormat.opaque: false
    visible: false
    

    onIsCompactModeChanged: menuVisible = false

    
    Connections {
        target: VideoService
        function onSettingsOpenChanged() {
            if (VideoService.settingsOpen) {
                settingsModal.show();
            } else {
                settingsModal.hide();
            }
        }
    }

FocusScope {
        anchors.fill: parent
        focus: true

        readonly property bool isFloatingWindowSurface: true
        readonly property color surfaceColor: settingsModal.color

        LayoutMirroring.enabled: I18n.isRtl
        LayoutMirroring.childrenInherit: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (!sidebar.clearSearch() && !sidebar.clearHighlight())
                    settingsModal.hide();
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
            topPadding: header.integrated ? 0 : header.height
            spacing: 0

            Item {
                width: parent.width
                height: parent.height - parent.topPadding
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
                    anchors.bottom: settingsModal.compactSearch ? undefined : parent.bottom
                    height: settingsModal.compactSearch ? implicitHeight : undefined
                    width: settingsModal.isCompactMode ? parent.width : implicitWidth
                    visible: settingsModal.isCompactMode ? settingsModal.menuVisible : true
                    fieldOnly: settingsModal.compactSearch
                    currentIndex: settingsModal.currentTabIndex
                    onTabSelected: index => {
                        settingsModal.currentTabIndex = index;
                        if (settingsModal.isCompactMode)
                            settingsModal.menuVisible = false;
                    }
                }

                FocusScope {
                    id: contentScope

                    anchors.left: settingsModal.isCompactMode ? (settingsModal.menuVisible && !settingsModal.compactSearch ? sidebar.right : parent.left) : sidebar.right
                    anchors.leftMargin: settingsModal.isCompactMode ? 0 : Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: settingsModal.isCompactMode ? 0 : Theme.spacingM
                    anchors.top: settingsModal.compactSearch ? sidebar.bottom : parent.top
                    anchors.topMargin: settingsModal.isCompactMode ? 0 : Theme.spacingM
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: settingsModal.isCompactMode ? 0 : Theme.spacingM

                    Rectangle {
                        anchors.fill: parent
                        radius: settingsModal.isCompactMode ? 0 : Theme.cornerRadiusXL
                        color: SettingsMetrics.paneColor
                        border.width: Theme.layerOutlineWidth ?? 1
                        border.color: Theme.outlineMedium
                        clip: true
                    }

                    SettingsContent {
                        id: content

                        anchors.fill: parent
                        anchors.margins: SettingsMetrics.panePadding
                        currentIndex: settingsModal.currentTabIndex
                        searchQuery: sidebar.query
                    }
                }
            }
        }

        DWindowHeader {
            id: header

            readonly property bool integrated: !settingsModal.isCompactMode
            readonly property bool ownsPageHeader: integrated && !compositorDecorated

            anchors.right: parent.right
            width: integrated ? buttonsReserve : parent.width
            visible: !integrated || ownsPageHeader
            controls: windowControls
            title: integrated ? "" : "Settings"
            onCloseRequested: settingsModal.hide()

            DActionButton {
                visible: settingsModal.isCompactMode
                iconName: "menu"
                buttonSize: Theme.buttonHeightXXS
                Accessible.name: "Menu"
                onClicked: settingsModal.menuVisible = !settingsModal.menuVisible
            }
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: settingsModal
    }
}
