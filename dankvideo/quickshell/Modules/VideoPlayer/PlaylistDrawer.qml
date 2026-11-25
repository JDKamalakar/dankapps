import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets

Rectangle {
    id: root

    property bool open: VideoService.playlistDrawerOpen

    width: 380
    topLeftRadius: Theme.cornerRadiusXL
    bottomLeftRadius: Theme.cornerRadiusXL
    topRightRadius: 0
    bottomRightRadius: 0
    color: Theme.foregroundColor(Theme.surfaceContainerHigh, true)
    border.color: Theme.withAlpha(Theme.outlineVariant, 0.25)
    border.width: 1
    clip: true

    ElevationShadow {
        anchors.fill: parent
        z: -1
        targetRadius: Theme.cornerRadiusXL
        targetColor: parent.color
        level: Style.elevationLevel3
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        acceptedButtons: Qt.AllButtons
        onWheel: event => event.accepted = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingM

        // Header with title and controls
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            DIcon {
                name: "playlist_play"
                size: Style.iconSizeMedium
                color: Theme.primary
            }

            StyledText {
                Layout.fillWidth: true
                text: "Playlist (" + VideoService.effectivePlaylist.length + ")"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.surfaceText
            }

            // Shuffle Button
            DActionButton {
                iconName: "shuffle"
                buttonSize: Style.buttonHeightXS
                iconSize: Style.iconSizeSmall
                iconColor: VideoService.playlistShuffled ? Theme.primary : Theme.surfaceVariantText
                backgroundColor: VideoService.playlistShuffled ? Theme.primaryContainer : "transparent"
                tooltipText: VideoService.playlistShuffled ? "Shuffle: On" : "Shuffle: Off"
                tooltipSide: "bottom"
                onClicked: VideoService.toggleShufflePlaylist()
            }

            // Loop Playlist Button
            DActionButton {
                iconName: VideoService.playlistLoopMode === 2 ? "repeat_one" : "repeat"
                buttonSize: Style.buttonHeightXS
                iconSize: Style.iconSizeSmall
                iconColor: VideoService.playlistLoopMode > 0 ? Theme.primary : Theme.surfaceVariantText
                backgroundColor: VideoService.playlistLoopMode > 0 ? Theme.primaryContainer : "transparent"
                tooltipText: VideoService.playlistLoopMode === 2 ? "Loop: Single" : (VideoService.playlistLoopMode === 1 ? "Loop: All" : "Loop: Off")
                tooltipSide: "bottom"
                onClicked: VideoService.cycleLoopMode()
            }

            // Sort button
            DActionButton {
                iconName: "sort_by_alpha"
                buttonSize: Style.buttonHeightXS
                iconSize: Style.iconSizeSmall
                iconColor: Theme.surfaceVariantText
                tooltipText: "Sort A-Z"
                tooltipSide: "bottom"
                onClicked: VideoService.sortPlaylistAlphabetically()
            }

            // Close drawer button
            DActionButton {
                iconName: "close"
                buttonSize: Style.buttonHeightXS
                iconSize: Style.iconSizeSmall
                iconColor: Theme.surfaceVariantText
                tooltipText: "Close Playlist (Esc)"
                tooltipSide: "bottom"
                onClicked: VideoService.playlistDrawerOpen = false
            }
        }

        // Search / Filter inside playlist
        Rectangle {
            Layout.fillWidth: true
            height: 32
            radius: 16
            color: plSearchInput.activeFocus ? Theme.surfaceContainerHighest : Theme.surfaceContainer
            border.color: plSearchInput.activeFocus ? Theme.primary : Theme.withAlpha(Theme.outlineVariant, 0.25)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                DIcon {
                    name: "search"
                    size: 16
                    color: plSearchInput.activeFocus ? Theme.primary : Theme.surfaceVariantText
                }

                TextInput {
                    id: plSearchInput
                    Layout.fillWidth: true
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    property string searchQuery: ""
                    onTextChanged: searchQuery = text.trim().toLowerCase()

                    StyledText {
                        anchors.fill: parent
                        text: "Filter in playlist..."
                        color: Theme.withAlpha(Theme.surfaceVariantText, 0.6)
                        font.pixelSize: Theme.fontSizeSmall
                        verticalAlignment: Text.AlignVCenter
                        visible: !plSearchInput.text && !plSearchInput.activeFocus
                    }
                }

                DIconButton {
                    visible: !!plSearchInput.text
                    iconName: "close"
                    size: "xs"
                    variant: "standard"
                    onClicked: plSearchInput.text = ""
                }
            }
        }

        // List of videos
        ListView {
            id: playlistView
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4
            clip: true

            readonly property var playlistItems: {
                let items = VideoService.effectivePlaylist;
                const q = plSearchInput.searchQuery;
                if (q) {
                    items = items.filter(it => it.fileName.toLowerCase().indexOf(q) !== -1);
                }
                return items;
            }

            model: playlistItems

            delegate: Rectangle {
                id: rowItem
                required property var modelData
                required property int index

                width: playlistView.width
                height: 48
                radius: Theme.cornerRadiusSmall
                readonly property bool isCurrent: modelData.path === VideoService.currentFilePath
                readonly property bool isSkippedAlways: VideoService.isAlwaysSkipped(modelData.path)
                readonly property bool isSkippedOnce: VideoService.isSkippedOnce(modelData.path)

                color: isCurrent ? Theme.primaryContainer : (itemHover.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerLow)
                border.color: isCurrent ? Theme.primary : Theme.withAlpha(Theme.outlineVariant, 0.15)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    DIcon {
                        name: isCurrent ? (VideoService.isPlaying ? "play_arrow" : "pause") : (isSkippedAlways ? "block" : (isSkippedOnce ? "skip_next" : "movie"))
                        size: 20
                        color: isCurrent ? Theme.primary : (isSkippedAlways || isSkippedOnce ? Theme.surfaceVariantText : Theme.surfaceText)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.fileName
                            elide: Text.ElideMiddle
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: isCurrent ? Font.DemiBold : Font.Normal
                            color: isCurrent ? Theme.onPrimaryContainer : (isSkippedAlways ? Theme.surfaceVariantText : Theme.surfaceText)
                        }

                        StyledText {
                            text: isSkippedAlways ? "Skipped always in playlist" : (isSkippedOnce ? "Skipped next time" : (isCurrent ? "Now Playing" : ""))
                            visible: !!text
                            font.pixelSize: Theme.fontSizeSmall - 2
                            color: isCurrent ? Theme.primary : Theme.surfaceVariantText
                        }
                    }

                    // Skip Once button
                    DIconButton {
                        iconName: "redo"
                        size: "xs"
                        variant: "standard"
                        tooltipText: isSkippedOnce ? "Un-skip once" : "Skip once in playlist"
                        iconColor: isSkippedOnce ? Theme.primary : Theme.surfaceVariantText
                        onClicked: VideoService.toggleSkipOnce(modelData.path)
                    }

                    // Skip Always button
                    DIconButton {
                        iconName: isSkippedAlways ? "visibility_off" : "visibility"
                        size: "xs"
                        variant: "standard"
                        tooltipText: isSkippedAlways ? "Include always" : "Skip always in playlist"
                        iconColor: isSkippedAlways ? Theme.error : Theme.surfaceVariantText
                        onClicked: VideoService.toggleSkipAlways(modelData.path)
                    }
                }

                MouseArea {
                    id: itemHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: {
                        VideoService.playFromPlaylist(modelData.path);
                    }
                }
            }
        }
    }
}
