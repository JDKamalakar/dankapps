import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets

Item {
    id: root

    property var windowControls: null
    property var targetWindow: null
    readonly property bool filterSortDialogOpen: filterDialog.opened

    function closeFilterSortDialog() {
        filterDialog.close()
    }

    focus: true
    Keys.onPressed: event => {
        if (!ImageService.galleryMode) return
        if (event.key === Qt.Key_Escape) {
            if (settingsDialog.opened) {
                settingsDialog.close()
                event.accepted = true
                return
            }
            if (filterDialog.opened) {
                filterDialog.close()
                event.accepted = true
                return
            }
            if (searchInput.activeFocus) {
                root.forceActiveFocus()
                event.accepted = true
                return
            }
        }
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) {
            ImageService.searchBarCollapsed = false
            searchInput.forceActiveFocus()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Slash && !searchInput.activeFocus) {
            ImageService.searchBarCollapsed = false
            searchInput.forceActiveFocus()
            event.accepted = true
            return
        }
    }

    Connections {
        target: ImageService
        function onSearchBarCollapsedChanged() {
            if (ImageService.searchBarCollapsed && searchInput.activeFocus) {
                root.forceActiveFocus()
            }
        }
    }

    // Left Sidebar Navigation (Timeline, Albums, Settings)
    GallerySidebar {
        id: sidebar
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        z: 25
    }

    // Main Content Card (Rounded container adjacent to sidebar, matching M3 / DankCalendar aesthetic)
    Rectangle {
        id: mainArea
        anchors.left: sidebar.right
        anchors.leftMargin: Style.spacingS
        anchors.right: parent.right
        anchors.rightMargin: Style.spacingM
        anchors.top: parent.top
        anchors.topMargin: Style.spacingS
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.spacingM
        radius: Style.cornerRadiusL
        color: Theme.foregroundColor(Theme.surfaceContainer, true)
        border.color: M3E.stroke(Theme.outlineVariant, M3E.strokeDivider)
        border.width: Style.outlineWidth
        clip: true

        // Floating M3E Search Bar + Segmented Action Buttons (Refresh -> Search -> Filter)
        Item {
            id: searchBarGroup
            readonly property int expandedSearchWidth: Math.min(380, mainArea.width - refreshPill.width - filterPill.width - 64)
            readonly property int collapsedSearchWidth: 48
            readonly property bool isCollapsed: ImageService.searchBarCollapsed && ImageService.searchQuery === ""
            property real pillGap: isCollapsed ? Math.max(2, Math.round(Theme.spacingXS * 0.5)) : Theme.spacingS
            readonly property real totalWidth: refreshPill.width + pillGap + (isCollapsed ? collapsedSearchWidth : expandedSearchWidth) + pillGap + filterPill.width

            Behavior on pillGap {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            // In-window backdrop blur behind floating search & pills
            ShaderEffectSource {
                id: searchBackdropSource
                sourceItem: contentContainer
                sourceRect: Qt.rect(searchBarGroup.x, searchBarGroup.y, searchBarGroup.width, searchBarGroup.height)
                visible: false
                live: true
            }

            MultiEffect {
                anchors.fill: parent
                source: searchBackdropSource
                blurEnabled: true
                blur: 0.65
                blurMax: 32
                visible: true
                z: -1
            }

            anchors.top: parent.top
            anchors.topMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: isCollapsed ? 16 : Math.max(16, Math.round((mainArea.width - totalWidth) / 2))
            width: totalWidth
            height: 48
            z: 30
            visible: ImageService.galleryTab !== "settings"

            Behavior on anchors.rightMargin {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }

            // 1. Refresh Button (First - Segmented First)
            Rectangle {
                id: refreshPill
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                height: 48
                readonly property bool isPillActive: ImageService.isGalleryLoading || rescanMouse.pressed || rescanMouse.containsMouse
                topLeftRadius: 24
                bottomLeftRadius: 24
                topRightRadius: isPillActive ? 24 : 6
                bottomRightRadius: isPillActive ? 24 : 6
                Behavior on topRightRadius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on bottomRightRadius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                color: isPillActive
                    ? Theme.withAlpha(Theme.primary, 0.2)
                    : Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                border.color: isPillActive ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                border.width: 1
                scale: rescanMouse.pressed ? 0.94 : (rescanMouse.containsMouse ? 1.08 : 1.0)

                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                DRipple {
                    id: refreshRipple
                    cornerRadius: 24
                    rippleColor: Theme.primary
                    anchors.fill: parent
                }

                DIcon {
                    anchors.centerIn: parent
                    name: "refresh"
                    size: 20
                    color: Theme.surfaceText
                    visible: !ImageService.isGalleryLoading
                }

                DLoadingIndicator {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    visible: ImageService.isGalleryLoading
                }

                DTooltipHost { anchors.fill: parent; text: "Rescan library" }

                MouseArea {
                    id: rescanMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ImageService.rescan()
                }
            }

            // 2. Search Pill (Middle)
            Rectangle {
                id: searchPill
                readonly property bool isCollapsed: searchBarGroup.isCollapsed

                anchors.left: refreshPill.right
                anchors.leftMargin: searchBarGroup.pillGap
                anchors.top: parent.top
                width: isCollapsed ? searchBarGroup.collapsedSearchWidth : searchBarGroup.expandedSearchWidth
                height: 48
                topLeftRadius: isCollapsed ? 6 : 24
                bottomLeftRadius: isCollapsed ? 6 : 24
                topRightRadius: isCollapsed ? 6 : 24
                bottomRightRadius: isCollapsed ? 6 : 24
                Behavior on topLeftRadius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on bottomLeftRadius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on topRightRadius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on bottomRightRadius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                color: Theme.foregroundColor(
                    searchInput.activeFocus ? Theme.surfaceContainerHighest : ((pillHover.hovered || (isCollapsed && collapsedMouse.containsMouse)) ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh),
                    true
                )
                border.color: searchInput.activeFocus ? Theme.primary : ((pillHover.hovered || (isCollapsed && collapsedMouse.containsMouse)) ? Theme.primary : M3E.stroke(Theme.outlineVariant, M3E.strokeSurface))
                border.width: searchInput.activeFocus ? 2 : 1
                clip: true

                Behavior on width {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color { DColorAnim { duration: M3E.effectsFastMs; easing.bezierCurve: M3E.curveFastEffects } }
                Behavior on border.color { DColorAnim { duration: M3E.effectsFastMs; easing.bezierCurve: M3E.curveFastEffects } }

                HoverHandler {
                    id: pillHover
                    enabled: !searchPill.isCollapsed
                    cursorShape: Qt.IBeamCursor
                }

                TapHandler {
                    enabled: !searchPill.isCollapsed
                    onTapped: searchInput.forceActiveFocus()
                }

                // Search icon container (Centered when collapsed, left icon when expanded)
                Item {
                    id: searchIconContainer
                    width: 48
                    height: 48
                    anchors.left: parent.left
                    anchors.top: parent.top

                    DIcon {
                        anchors.centerIn: parent
                        name: "search"
                        size: 20
                        color: searchInput.activeFocus ? Theme.primary : Theme.surfaceVariantText
                    }

                    // Dot indicator removed from searchbar (shown only on filter icon)
                    Rectangle {
                        visible: false
                        width: 7
                        height: 7
                        radius: 3.5
                        anchors.top: parent.top
                        anchors.topMargin: 9
                        anchors.right: parent.right
                        anchors.rightMargin: 9
                        color: Theme.primary
                    }
                }

                // Expanded content: TextInput, Clear button, Divider, Filter button
                Item {
                    id: expandedContent
                    anchors.left: searchIconContainer.right
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    opacity: searchPill.isCollapsed ? 0 : 1
                    visible: opacity > 0
                    clip: true

                    Behavior on opacity {
                        DAnim {
                            duration: M3E.effectsFastMs
                            easing.bezierCurve: M3E.curveFastEffects
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.rightMargin: 6
                        spacing: 6

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            TextInput {
                                id: searchInput
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                text: ImageService.searchQuery
                                font.pixelSize: Theme.fontSizeMedium
                                font.family: Style.fontFamily || Theme.fontFamily
                                font.weight: Style.fontWeight
                                color: Theme.surfaceText
                                selectByMouse: true
                                selectionColor: Theme.primary
                                selectedTextColor: Theme.onPrimary

                                HoverHandler {
                                    cursorShape: Qt.IBeamCursor
                                }

                                onTextEdited: ImageService.searchQuery = text

                                StyledText {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: !searchInput.text && !searchInput.inputMethodComposing
                                    text: ImageService.galleryTab === "albums" ? "Search albums..." : (ImageService.galleryTab === "trash" ? "Search trash..." : "Search photos")
                                    font.pixelSize: searchInput.font.pixelSize
                                    color: Theme.surfaceVariantText
                                }

                                Keys.onEscapePressed: {
                                    searchInput.text = ""
                                    ImageService.searchQuery = ""
                                    root.forceActiveFocus()
                                }
                            }
                        }

                        // Clear button
                        Rectangle {
                            visible: searchInput.text !== ""
                            width: 28
                            height: 28
                            radius: 14
                            color: clearMouse.containsMouse ? Theme.surfaceContainerLowest : "transparent"

                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }

                            DIcon {
                                anchors.centerIn: parent
                                name: "close"
                                size: 16
                                color: Theme.surfaceVariantText
                            }

                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchInput.text = ""
                                    ImageService.searchQuery = ""
                                    searchInput.forceActiveFocus()
                                }
                            }
                        }
                    }
                }

                // Click overlay to expand when collapsed
                MouseArea {
                    id: collapsedMouse
                    anchors.fill: parent
                    visible: searchPill.isCollapsed
                    enabled: searchPill.isCollapsed
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ImageService.searchBarCollapsed = false
                        searchInput.forceActiveFocus()
                    }
                }

                DTooltipHost {
                    anchors.fill: parent
                    text: "Search photos"
                    visible: searchPill.isCollapsed
                }
            }

            // 3. Filter Pill (Last - Segmented Last)
            Rectangle {
                id: filterPill
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 48
                width: 48
                readonly property bool isPillActive: filterDialog.opened || filterMouse.pressed || filterMouse.containsMouse
                topLeftRadius: isPillActive ? 24 : 6
                bottomLeftRadius: isPillActive ? 24 : 6
                topRightRadius: 24
                bottomRightRadius: 24
                Behavior on topLeftRadius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on bottomLeftRadius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                color: isPillActive ? Theme.withAlpha(Theme.primary, 0.2) : Theme.foregroundColor(Theme.surfaceContainerHigh, true)
                border.color: isPillActive ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                border.width: 1
                scale: filterMouse.pressed ? 0.94 : (filterMouse.containsMouse ? 1.08 : 1.0)

                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                DRipple {
                    id: filterRipple
                    cornerRadius: 24
                    rippleColor: Theme.primary
                    anchors.fill: parent
                }

                DIcon {
                    anchors.centerIn: parent
                    name: "filter_list"
                    size: 20
                    color: ImageService.hasActiveFilters ? Theme.primary : Theme.surfaceText
                }

                Rectangle {
                    visible: ImageService.hasActiveFilters
                    width: 7
                    height: 7
                    radius: 3.5
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    color: Theme.primary
                }

                DTooltipHost { anchors.fill: parent; text: "Filter & Sort" }

                MouseArea {
                    id: filterMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: filterDialog.open()
                }
            }
        }

        Item {
            id: contentContainer
            anchors.fill: parent
            z: 10

            GalleryTimeline {
                anchors.fill: parent
                visible: ImageService.galleryTab === "gallery" || ImageService.galleryTab === "timeline"
            }

            GalleryAlbums {
                anchors.fill: parent
                visible: ImageService.galleryTab === "albums"
            }

            GalleryTrash {
                anchors.fill: parent
                visible: ImageService.galleryTab === "trash"
            }

        }

        // Top-center floating refresh indicator (Android Chrome style)
        DLoadingIndicator {
            contained: true
            visible: ImageService.isGalleryLoading
            anchors.top: parent.top
            anchors.topMargin: Theme.spacingL
            anchors.horizontalCenter: parent.horizontalCenter
            z: 50
        }

        // Floating Contextual Actions Dock (Selection toolbar & Album edit actions)
        GalleryDock {
            id: dock
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            z: 30
        }
    }

    // Filter & Sort Floating Window
    FilterSortDialog {
        id: filterDialog
    }

        // Settings Modal Dialog
    // GallerySettings handled by top-level FloatingWindow SettingsModal
}