import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Common
import qs.DCommon.Widgets

FloatingWindow {
    id: root

    property bool opened: false
    property string dateFilter: "all"
    property string sortOrder: "newest"
    property int gridItemSize: 184
    property bool groupByDate: false

    signal dateFilterSelected(string val)
    signal sortOrderSelected(string val)
    signal itemSizeSelected(int val)
    signal groupByDateToggled(bool val)
    signal resetRequested()

    function open() {
        opened = true;
        visible = true;
        focusRoot.forceActiveFocus();
    }

    function close() {
        opened = false;
        visible = false;
    }

    title: "Filter & Sort Settings"
    implicitWidth: 880
    implicitHeight: Math.min(680, cardContent.implicitHeight + 48)
    minimumSize: Qt.size(880, implicitHeight)
    maximumSize: Qt.size(880, implicitHeight)
    color: Theme.windowSurface
    surfaceFormat.opaque: false
    visible: false

    onClosed: opened = false

    WindowBlur {
        targetWindow: root
        blurEnabled: Theme.translucentWindows
        blurWidth: root.width
        blurHeight: root.height
    }

    FocusScope {
        id: focusRoot
        anchors.fill: parent
        focus: true
        onActiveFocusChanged: {
            if (!activeFocus && root.opened) {
                root.close();
            }
        }

        Keys.onEscapePressed: event => {
            root.close();
            event.accepted = true;
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.windowRadius
            color: Theme.foregroundColor(Theme.surfaceContainerHigh, true)
            border.color: M3E.stroke(Theme.outlineVariant, M3E.strokeCard)
            border.width: Style.outlineWidth

            ColumnLayout {
                id: cardContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 20
                spacing: Theme.spacingM

                RowLayout {
                    Layout.fillWidth: true

                    DIcon {
                        name: "filter_list"
                        size: Style.iconSizeMedium
                        color: Theme.primary
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: "Filter & Sort"
                        font.pixelSize: Theme.fontSizeLarge + 2
                        font.weight: Theme.fontWeightBold
                        color: Theme.surfaceText
                    }

                    DButton {
                        text: "Reset"
                        iconName: "restart_alt"
                        buttonHeight: Style.buttonHeightXS
                        backgroundColor: Theme.surfaceContainerHighest
                        textColor: Theme.surfaceText
                        onClicked: root.resetRequested()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    SettingsCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        title: "Filter"
                        iconName: "filter_alt"

                        SettingsButtonGroupRow {
                            iconName: "calendar_today"
                            text: "Date added"
                            model: ["All", "Today", "7d", "30d"]
                            currentIndex: {
                                switch (root.dateFilter) {
                                case "today": return 1;
                                case "7d": return 2;
                                case "30d": return 3;
                                default: return 0;
                                }
                            }
                            onSelectionChanged: (idx, sel) => {
                                if (!sel) return;
                                const opts = ["all", "today", "7d", "30d"];
                                root.dateFilterSelected(opts[idx]);
                            }
                        }
                    }

                    SettingsCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        title: "Sort & Layout"
                        iconName: "sort"

                        SettingsButtonGroupRow {
                            iconName: "swap_vert"
                            text: "Sort order"
                            model: ["Newest", "Oldest", "A-Z", "Z-A"]
                            currentIndex: {
                                switch (root.sortOrder) {
                                case "oldest": return 1;
                                case "az": return 2;
                                case "za": return 3;
                                default: return 0;
                                }
                            }
                            onSelectionChanged: (idx, sel) => {
                                if (!sel) return;
                                const opts = ["newest", "oldest", "az", "za"];
                                root.sortOrderSelected(opts[idx]);
                            }
                        }

                        SettingsSliderRow {
                            iconName: "photo_size_select_large"
                            text: "Thumbnail size"
                            description: root.gridItemSize + " px"
                            minimum: 120
                            maximum: 280
                            step: 16
                            value: root.gridItemSize
                            onSliderValueChanged: v => root.itemSizeSelected(v)
                        }

                        SettingsToggleRow {
                            iconName: "date_range"
                            text: "Group by date"
                            checked: root.groupByDate
                            onToggled: val => root.groupByDateToggled(val)
                        }
                    }
                }
            }
        }
    }
}
