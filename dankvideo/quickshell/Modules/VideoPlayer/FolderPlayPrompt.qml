import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets

FocusScope {
    id: root

    property bool open: VideoService.folderPlayPromptOpen
    property string targetFolder: VideoService.pendingFolderPromptPath
    property int totalVideos: VideoService.pendingFolderVideoCount

    anchors.fill: parent
    visible: opacity > 0
    opacity: open ? 1.0 : 0.0
    focus: open
    z: 100

    onOpenChanged: {
        if (open) forceActiveFocus();
    }

    Keys.onEscapePressed: event => {
        VideoService.confirmFolderPlay(false);
        event.accepted = true;
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Easing.InOutQuad
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, M3E.scrimModal)

        MouseArea {
            anchors.fill: parent
            onClicked: VideoService.confirmFolderPlay(false)
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(440, parent.width - 32)
        implicitHeight: contentCol.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadiusXL
        color: Theme.foregroundColor(Theme.surfaceContainerHigh, true)
        border.color: Theme.withAlpha(Theme.outlineVariant, 0.25)
        border.width: 1

        ElevationShadow {
            anchors.fill: parent
            z: -1
            targetRadius: parent.radius
            targetColor: parent.color
            level: Style.elevationLevel3
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM

                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: Theme.primaryContainer
                    Layout.alignment: Qt.AlignVCenter

                    DIcon {
                        anchors.centerIn: parent
                        name: "playlist_play"
                        size: 24
                        color: Theme.primary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: "Play Multiple Videos?"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.surfaceText
                    }

                    StyledText {
                        text: "This folder contains " + root.totalVideos + " video files."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: "Would you like to play all videos as a playlist or play only the selected video?"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                wrapMode: Text.WordWrap
            }

            // Custom Segmented Group Button (LiveChart style)
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacingS
                height: 44
                radius: height / 2
                color: Theme.surfaceContainerHighest
                border.color: Theme.withAlpha(Theme.outlineVariant, 0.25)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: height / 2
                        color: selMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                        Behavior on color { DColorAnim { duration: 150 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            DIcon {
                                name: "play_circle"
                                size: 18
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText {
                                text: "Play Selected"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: selMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: VideoService.confirmFolderPlay(false)
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: height / 2
                        color: allMouse.containsMouse ? Theme.primary : Theme.withAlpha(Theme.primary, 0.88)

                        Behavior on color { DColorAnim { duration: 150 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            DIcon {
                                name: "playlist_play"
                                size: 18
                                color: Theme.onPrimary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText {
                                text: "Play All"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                                color: Theme.onPrimary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: allMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: VideoService.confirmFolderPlay(true)
                        }
                    }
                }
            }
        }
    }
}
