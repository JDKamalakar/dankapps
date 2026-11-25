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

    onClosed: hideCleanup()

    function hideCleanup() {
        opened = false;
    }

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

                // Header
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
                        onClicked: {
                            ImageService.filterMediaType = "All";
                            ImageService.filterDateAdded = "All";
                            ImageService.filterSortOrder = "Newest first";
                            ImageService.filterIncludeHidden = false;
                            ImageService.galleryZoomLevel = 3;
                        }
                    }
                }

                SettingsCard {
                    Layout.fillWidth: true
                    title: "Filter"
                    iconName: "filter_alt"

                    SettingsButtonGroupRow {
                        iconName: "perm_media"
                        text: "Media type"
                        model: ["All", "Images", "GIFs"]
                        currentIndex: {
                            if (ImageService.filterMediaType === "Images" || ImageService.filterMediaType === "Images only") return 1;
                            if (ImageService.filterMediaType === "GIFs" || ImageService.filterMediaType === "GIFs / Animations") return 2;
                            return 0;
                        }
                        onSelectionChanged: (index, selected) => {
                            if (!selected) return;
                            if (index === 1) ImageService.filterMediaType = "Images";
                            else if (index === 2) ImageService.filterMediaType = "GIFs";
                            else ImageService.filterMediaType = "All";
                        }
                    }

                    SettingsButtonGroupRow {
                        iconName: "calendar_today"
                        text: "Date added"
                        model: ["All", "Today", "7d", "30d", "1y"]
                        currentIndex: {
                            if (ImageService.filterDateAdded === "Today") return 1;
                            if (ImageService.filterDateAdded === "7 days" || ImageService.filterDateAdded === "Last 7 days") return 2;
                            if (ImageService.filterDateAdded === "30 days" || ImageService.filterDateAdded === "Last 30 days") return 3;
                            if (ImageService.filterDateAdded === "1 year" || ImageService.filterDateAdded === "This year") return 4;
                            return 0;
                        }
                        onSelectionChanged: (index, selected) => {
                            if (!selected) return;
                            if (index === 1) ImageService.filterDateAdded = "Today";
                            else if (index === 2) ImageService.filterDateAdded = "7 days";
                            else if (index === 3) ImageService.filterDateAdded = "30 days";
                            else if (index === 4) ImageService.filterDateAdded = "1 year";
                            else ImageService.filterDateAdded = "All";
                        }
                    }

                    SettingsToggleRow {
                        iconName: "visibility"
                        text: "Include hidden files"
                        checked: ImageService.filterIncludeHidden
                        onToggled: val => ImageService.filterIncludeHidden = val
                    }
                }

                SettingsCard {
                    Layout.fillWidth: true
                    title: "Sort & Layout"
                    iconName: "sort"

                    SettingsButtonGroupRow {
                        iconName: "swap_vert"
                        text: "Sort order"
                        model: ["Newest", "Oldest", "A-Z", "Z-A"]
                        currentIndex: {
                            if (ImageService.filterSortOrder.indexOf("Oldest") !== -1) return 1;
                            if (ImageService.filterSortOrder.indexOf("A-Z") !== -1 && ImageService.filterSortOrder.indexOf("Z-A") === -1) return 2;
                            if (ImageService.filterSortOrder.indexOf("Z-A") !== -1) return 3;
                            return 0;
                        }
                        onSelectionChanged: (index, selected) => {
                            if (!selected) return;
                            if (index === 1) ImageService.filterSortOrder = "Oldest first";
                            else if (index === 2) ImageService.filterSortOrder = "Name (A-Z)";
                            else if (index === 3) ImageService.filterSortOrder = "Name (Z-A)";
                            else ImageService.filterSortOrder = "Newest first";
                        }
                    }

                    SettingsSliderRow {
                        iconName: "photo_size_select_large"
                        text: "Photo size"
                        description: {
                            const labels = ["Extra Small", "Small", "Medium", "Large", "Extra Large"];
                            return labels[Math.max(0, Math.min(4, (ImageService.galleryZoomLevel || 3) - 1))];
                        }
                        minimum: 1
                        maximum: 5
                        step: 1
                        value: ImageService.galleryZoomLevel || 3
                        onSliderValueChanged: v => ImageService.galleryZoomLevel = v
                    }
                }
            }
        }
    }
}
