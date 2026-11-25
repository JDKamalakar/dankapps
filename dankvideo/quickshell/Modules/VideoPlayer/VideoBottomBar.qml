import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets

Rectangle {
    id: root

    // Density layout: adjust controls width to cover almost entire width of the screen, proportional to density
    readonly property real densityScale: Theme.densityLevel < 0 ? 0.85 : (Theme.densityLevel > 0 ? 1.15 : 1.0)
    readonly property real basePadH: 20 + Theme.densityStepS * 2
    readonly property real basePadV: 10 + Theme.densityStepS

    // Density layout width:
    // spacious: parent.width - 48 (covers screen almost completely)
    // comfortable: Math.min(parent.width - 48, Math.max(760, parent.width * 0.88))
    // compact: Math.min(parent.width - 48, Math.max(620, parent.width * 0.72))
    // dense: Math.min(parent.width - 48, 560)
    readonly property real controlsWidth: {
        const fullW = parent.width - 48;
        switch (SettingsData.density) {
        case "spacious": return fullW;
        case "compact": return Math.min(fullW, Math.max(620, parent.width * 0.72));
        case "dense": return Math.min(fullW, 560);
        default: return Math.min(fullW, Math.max(760, parent.width * 0.88));
        }
    }

    height: Math.round(92 * densityScale)
    width: Math.max(380, controlsWidth)
    radius: Style.cornerRadiusXL
    color: Theme.foregroundColor(Theme.surfaceContainerHigh, true)
    border.color: M3E.stroke(Style.outlineVariant, M3E.strokeCard)
    border.width: 1

    Behavior on width {
        DAnim {
            duration: Style.shortDuration
            easing.bezierCurve: Style.expressiveCurves.standard
        }
    }

    ElevationShadow {
        anchors.fill: parent
        z: -1
        targetRadius: parent.radius
        targetColor: parent.color
        level: Style.elevationLevel2
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: root.basePadV + 2
        anchors.bottomMargin: root.basePadV
        anchors.leftMargin: root.basePadH
        anchors.rightMargin: root.basePadH
        spacing: 4 + Theme.densityStepXS

        // Scrubber / Seek Bar (M3WaveProgress without dot)
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            StyledText {
                text: VideoService.formatTime(VideoService.position)
                font.family: Theme.monoFontFamily
                font.pixelSize: Style.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Item {
                id: trackArea
                Layout.fillWidth: true
                height: 24

                M3WaveProgress {
                    id: waveProgress
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 20
                    value: VideoService.duration > 0 ? Math.max(0, Math.min(1, VideoService.position / VideoService.duration)) : 0
                    isPlaying: VideoService.isPlaying
                    lineWidth: seekMouse.containsMouse || seekMouse.drag.active ? 4.0 : 3.0
                    wavelength: 22
                    amp: 2.2
                    fillColor: Theme.primary
                    playheadColor: Theme.primary
                    trackColor: Theme.surfaceContainerHighest
                    actualProgressColor: Theme.withAlpha(Theme.primary, 0.40)
                }

                MouseArea {
                    id: seekMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    function updateSeek(mouse) {
                        if (trackArea.width > 0 && VideoService.duration > 0) {
                            const ratio = Math.max(0, Math.min(1, mouse.x / trackArea.width));
                            VideoService.position = ratio * VideoService.duration;
                        }
                    }

                    onPressed: mouse => updateSeek(mouse)
                    onPositionChanged: mouse => {
                        if (pressed) {
                            updateSeek(mouse);
                        }
                    }
                }
            }

            StyledText {
                text: VideoService.formatTime(VideoService.duration)
                font.family: Theme.monoFontFamily
                font.pixelSize: Style.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceVariantText
            }
        }

        // Control Buttons
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.buttonHeightS

            // Left cluster: Volume - Icon by default, expands to pill with slider + percentage on hover
            Item {
                id: volumeCluster
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: volumeHoverArea.containsMouse || volSlider.visualFocus ? 190 : Style.iconButtonSize
                height: Style.buttonHeightS
                clip: false

                Behavior on width {
                    DAnim {
                        duration: Style.shortDuration
                        easing.bezierCurve: Style.expressiveCurves.standard
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: volumeHoverArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                    border.color: volumeHoverArea.containsMouse ? Theme.withAlpha(Theme.outlineVariant, 0.3) : "transparent"
                    border.width: 1

                    Behavior on color {
                        DColorAnim { duration: Theme.shortDuration }
                    }
                    Behavior on border.color {
                        DColorAnim { duration: Theme.shortDuration }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 8
                        spacing: 6

                        DActionButton {
                            id: volIconBtn
                            iconName: VideoService.isMuted || VideoService.volume === 0 ? "volume_off" : (VideoService.volume < 0.5 ? "volume_down" : "volume_up")
                            iconSize: Style.iconSize
                            buttonSize: Style.buttonHeightS - 4
                            iconColor: Theme.surfaceText
                            tooltipText: VideoService.isMuted ? "Unmute" : "Mute"
                            tooltipSide: "top"
                            onClicked: VideoService.toggleMute()
                        }

                        // Slider appears on hover
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            visible: volumeCluster.width > Style.iconButtonSize + 40
                            opacity: visible ? 1.0 : 0.0

                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }

                            DSlider {
                                id: volSlider
                                anchors.fill: parent
                                minimum: 0
                                maximum: 100
                                value: VideoService.isMuted ? 0 : Math.round(VideoService.volume * 100)
                                size: "s"
                                showValue: false
                                fillColor: Theme.primary
                                trackColor: Theme.surfaceContainerLow
                                onSliderValueChanged: newValue => {
                                    VideoService.setVolume(newValue / 100);
                                }
                            }
                        }

                        // Percentage indicator
                        StyledText {
                            visible: volumeCluster.width > Style.iconButtonSize + 40
                            opacity: visible ? 1.0 : 0.0
                            text: (VideoService.isMuted ? "0" : Math.round(VideoService.volume * 100)) + "%"
                            font.family: Theme.monoFontFamily
                            font.pixelSize: Style.fontSizeSmall - 1
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                MouseArea {
                    id: volumeHoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }

            // Playback cluster (strictly centered)
            RowLayout {
                anchors.centerIn: parent
                spacing: Style.spacingS + Theme.densityStepXS

                // Step Back 10s
                DActionButton {
                    iconName: "replay_10"
                    iconSize: Style.iconSizeMedium
                    buttonSize: Style.buttonHeightS
                    iconColor: Theme.surfaceText
                    tooltipText: "Back 10s (Left)"
                    tooltipSide: "top"
                    onClicked: VideoService.seekRelative(-10000)
                }

                // Prev Video
                DActionButton {
                    iconName: "skip_previous"
                    iconSize: Style.iconSize
                    buttonSize: Style.buttonHeightS
                    iconColor: Theme.surfaceText
                    tooltipText: "Previous Video (PageUp)"
                    tooltipSide: "top"
                    visible: VideoService.fileList.length > 1
                    onClicked: VideoService.prevVideo()
                }

                // Play / Pause main button — M3E shape-morphing button
                Rectangle {
                    width: Style.buttonHeightS
                    height: Style.buttonHeightS
                    radius: playMouse.pressed ? M3E.pressRadiusS : (VideoService.isPlaying && !playMouse.containsMouse ? M3E.pressRadiusM : height / 2)
                    scale: playMouse.pressed ? M3E.iconBtnPressScale : (playMouse.containsMouse ? 1.05 : 1.0)
                    color: playMouse.containsMouse ? Theme.primaryContainer : Theme.primary
                    Layout.alignment: Qt.AlignVCenter

                    Behavior on radius {
                        DAnim {
                            duration: M3E.spatialFastMs
                            easing.bezierCurve: M3E.curveFastSpatial
                        }
                    }

                    Behavior on scale {
                        DAnim {
                            duration: M3E.spatialFastMs
                            easing.bezierCurve: M3E.curveFastSpatial
                        }
                    }

                    Behavior on color {
                        DColorAnim {
                            duration: M3E.effectsFastMs
                            easing.bezierCurve: M3E.curveFastEffects
                        }
                    }

                    DIcon {
                        anchors.centerIn: parent
                        name: VideoService.isPlaying ? "pause" : "play_arrow"
                        size: Style.iconSize
                        filled: true
                        color: playMouse.containsMouse ? Theme.onPrimaryContainer : Theme.onPrimary
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: VideoService.togglePlay()
                    }
                }

                // Next Video
                DActionButton {
                    iconName: "skip_next"
                    iconSize: Style.iconSize
                    buttonSize: Style.buttonHeightS
                    iconColor: Theme.surfaceText
                    tooltipText: "Next Video (PageDown)"
                    tooltipSide: "top"
                    visible: VideoService.fileList.length > 1
                    onClicked: VideoService.nextVideo()
                }

                // Forward 10s
                DActionButton {
                    iconName: "forward_10"
                    iconSize: Style.iconSizeMedium
                    buttonSize: Style.buttonHeightS
                    iconColor: Theme.surfaceText
                    tooltipText: "Forward 10s (Right)"
                    tooltipSide: "top"
                    onClicked: VideoService.seekRelative(10000)
                }
            }

            // Right cluster: Speed indicator label + dropdown button without scroll
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                DDropdown {
                    id: speedDropdown
                    showLabel: true
                    dropdownWidth: 88
                    popupWidth: 104
                    maxPopupHeight: 600 // Large enough to fit all 11 speed items without scroll
                    openUpwards: true
                    options: ["0.25x", "0.5x", "0.75x", "1.0x", "1.25x", "1.5x", "1.75x", "2.0x", "2.5x", "3.0x", "4.0x"]
                    optionValues: ["0.25", "0.5", "0.75", "1.0", "1.25", "1.5", "1.75", "2.0", "2.5", "3.0", "4.0"]
                    currentValue: {
                        const r = VideoService.playbackRate;
                        if (r === 0.25) return "0.25";
                        if (r === 0.5) return "0.5";
                        if (r === 0.75) return "0.75";
                        if (r === 1.25) return "1.25";
                        if (r === 1.5) return "1.5";
                        if (r === 1.75) return "1.75";
                        if (r === 2.0) return "2.0";
                        if (r === 2.5) return "2.5";
                        if (r === 3.0) return "3.0";
                        if (r === 4.0) return "4.0";
                        return "1.0";
                    }
                    onValueChanged: val => {
                        const parsed = parseFloat(val);
                        if (!isNaN(parsed) && parsed > 0) {
                            VideoService.playbackRate = parsed;
                        }
                    }
                }
            }
        }
    }
}
