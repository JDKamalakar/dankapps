pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets

Item {
    id: root

    anchors.fill: parent

    readonly property string densityMode: SettingsData.density || "comfortable"
    readonly property bool isSpacious: densityMode === "spacious"
    readonly property bool isCompact: densityMode === "compact" || densityMode === "dense"
    readonly property real panelPad: isSpacious ? Theme.spacingXL : (isCompact ? Theme.spacingM : Theme.spacingL)
    readonly property real panelGap: isSpacious ? Theme.spacingXL : (isCompact ? Theme.spacingM : Theme.spacingL)

    readonly property real minuteProgress: (ClockService.stopwatchElapsedMs % 60000) / 60000
    readonly property string fullFormatted: ClockService.formatStopwatch(ClockService.stopwatchElapsedMs)
    readonly property int dotIdx: fullFormatted.indexOf(".")
    readonly property string mainDigits: dotIdx >= 0 ? fullFormatted.substring(0, dotIdx) : fullFormatted
    readonly property string centiDigits: dotIdx >= 0 ? fullFormatted.substring(dotIdx) : ".00"
    readonly property bool hasElapsed: ClockService.stopwatchElapsedMs > 0

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.panelPad
        spacing: root.panelGap

        // LEFT PANEL (~70% width, full height): Full Stopwatch Card
        Rectangle {
            id: heroStopwatchCard
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property real cardPad: root.isSpacious ? Theme.spacingXL : (root.isCompact ? Theme.spacingM : Theme.spacingL)
            readonly property real dialWidthAvail: Math.max(110, width - cardPad * 2 - Theme.spacingM * 2)
            readonly property real dialHeightAvail: Math.max(110, height - cardPad * 2 - 34 - 42 - (root.isCompact ? Theme.spacingS : Theme.spacingM) * 2)
            readonly property real computedDialSize: Math.min(540, Math.min(dialWidthAvail, dialHeightAvail))

            radius: Theme.cornerRadiusXL
            color: swHeroHover.hovered ? Theme.surfaceContainerHighest : ClockMetrics.rowColor
            border.width: Theme.layerOutlineWidth
            border.color: ClockService.stopwatchRunning
                ? Theme.primary
                : (swHeroHover.hovered ? Theme.outline : Theme.outlineMedium)

            Behavior on color {
                enabled: Theme.animationsEnabled
                ColorAnimation { duration: ClockMetrics.fadeDuration }
            }
            Behavior on border.color {
                enabled: Theme.animationsEnabled
                ColorAnimation { duration: ClockMetrics.fadeDuration }
            }

            HoverHandler { id: swHeroHover }

            // Click anywhere on the card/dial to Start or Pause
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: ClockService.toggleStopwatch()
            }

            Item {
                anchors.fill: parent
                anchors.margins: heroStopwatchCard.cardPad

                // Top Header: Status Badge + Title
                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 30
                    spacing: Theme.spacingS

                    DBadge {
                        text: ClockService.stopwatchRunning ? "RUNNING" : (root.hasElapsed ? "PAUSED" : "READY")
                        color: ClockService.stopwatchRunning ? Theme.primary : Theme.secondaryContainer
                        textColor: ClockService.stopwatchRunning ? Theme.onPrimary : Theme.onSecondaryContainer
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: "Stopwatch"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Theme.fontWeightBold
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Center Ring Gauge
                ClockRingDial {
                    anchors.centerIn: parent
                    dialSize: heroStopwatchCard.computedDialSize
                    blobSize: Math.round(heroStopwatchCard.computedDialSize * 0.84)
                    progress: root.minuteProgress
                    ringColor: Theme.primary
                    active: ClockService.stopwatchRunning
                    animated: false
                    clickable: true
                    tooltipText: ClockService.stopwatchRunning ? "Click to pause" : (root.hasElapsed ? "Click to resume" : "Click to start")
                    onClicked: ClockService.toggleStopwatch()

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter

                        NumericText {
                            text: root.mainDigits
                            font.pixelSize: root.mainDigits.length > 5 ? Theme.fontSizeXXLarge : Theme.fontSizeDisplay
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            anchors.baseline: parent.bottom
                        }

                        NumericText {
                            text: root.centiDigits
                            font.pixelSize: root.mainDigits.length > 5 ? Theme.fontSizeXLarge : Theme.fontSizeXXLarge
                            font.weight: Font.Bold
                            color: Theme.primary
                            anchors.baseline: parent.bottom
                        }
                    }

                    NumericText {
                        visible: ClockService.stopwatchLaps.length > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Lap " + (ClockService.stopwatchLaps.length + 1) + "  •  " + ClockService.formatStopwatch(ClockService.currentLapElapsedMs)
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                    }
                }

                // Bottom Controls: Custom Group Button (Start/Pause + Lap/Reset)
                Row {
                    id: swControlsGroup
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    height: 36
                    spacing: 2
                    z: 2

                    readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                    readonly property real innerR: Theme.groupedListInnerRadius ?? 4
                    readonly property bool showSecondary: ClockService.stopwatchRunning || root.hasElapsed

                    // First: Start / Pause
                    Rectangle {
                        width: spRow.implicitWidth + Theme.spacingM * 2
                        height: parent.height
                        topLeftRadius: parent.outerR
                        bottomLeftRadius: parent.outerR
                        topRightRadius: (ClockService.stopwatchRunning || spMouse.pressed || spMouse.containsMouse || !swControlsGroup.showSecondary) ? parent.outerR : parent.innerR
                        bottomRightRadius: (ClockService.stopwatchRunning || spMouse.pressed || spMouse.containsMouse || !swControlsGroup.showSecondary) ? parent.outerR : parent.innerR
                        color: (ClockService.stopwatchRunning || spMouse.containsMouse) ? Theme.withAlpha(Theme.primary, 0.22) : Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: (ClockService.stopwatchRunning || spMouse.containsMouse) ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                        scale: spMouse.pressed ? 0.95 : (spMouse.containsMouse ? 1.03 : 1.0)
                        clip: true

                        Behavior on topRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on bottomRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                        DRipple { id: spRipple; anchors.fill: parent; rippleColor: Theme.primary }

                        Row {
                            id: spRow
                            anchors.centerIn: parent
                            spacing: 5

                            DIcon {
                                name: ClockService.stopwatchRunning ? "pause" : "play_arrow"
                                size: 16
                                color: (ClockService.stopwatchRunning || spMouse.containsMouse) ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: ClockService.stopwatchRunning ? "Pause" : (root.hasElapsed ? "Resume" : "Start")
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: (ClockService.stopwatchRunning || spMouse.containsMouse) ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: spMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => spRipple.trigger(mouse.x, mouse.y)
                            onClicked: ClockService.toggleStopwatch()
                        }
                    }

                    // Second: Lap (when running) / Reset (when paused with elapsed)
                    Rectangle {
                        width: swControlsGroup.showSecondary ? (secRow.implicitWidth + Theme.spacingM * 2) : 0
                        height: parent.height
                        opacity: swControlsGroup.showSecondary ? 1 : 0
                        enabled: swControlsGroup.showSecondary
                        topLeftRadius: (secMouse.pressed || secMouse.containsMouse) ? parent.outerR : parent.innerR
                        bottomLeftRadius: (secMouse.pressed || secMouse.containsMouse) ? parent.outerR : parent.innerR
                        topRightRadius: parent.outerR
                        bottomRightRadius: parent.outerR
                        color: secMouse.containsMouse
                            ? Theme.withAlpha(ClockService.stopwatchRunning ? Theme.primary : Theme.error, 0.2)
                            : Theme.surfaceContainerHigh
                        border.width: swControlsGroup.showSecondary ? 1 : 0
                        border.color: secMouse.containsMouse
                            ? (ClockService.stopwatchRunning ? Theme.primary : Theme.error)
                            : (Theme.outlineMedium ?? Theme.outlineVariant)
                        scale: secMouse.pressed ? 0.95 : (secMouse.containsMouse ? 1.03 : 1.0)
                        clip: true

                        Behavior on topLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on bottomLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on width { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150 } }
                        Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                        DRipple { id: secRipple; anchors.fill: parent; rippleColor: ClockService.stopwatchRunning ? Theme.primary : Theme.error }

                        Row {
                            id: secRow
                            anchors.centerIn: parent
                            spacing: 5

                            DIcon {
                                name: ClockService.stopwatchRunning ? "flag" : "restart_alt"
                                size: 16
                                color: secMouse.containsMouse
                                    ? (ClockService.stopwatchRunning ? Theme.primary : Theme.error)
                                    : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: ClockService.stopwatchRunning ? "Lap" : "Reset"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: secMouse.containsMouse
                                    ? (ClockService.stopwatchRunning ? Theme.primary : Theme.error)
                                    : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: secMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => secRipple.trigger(mouse.x, mouse.y)
                            onClicked: {
                                if (ClockService.stopwatchRunning)
                                    ClockService.lapStopwatch();
                                else
                                    ClockService.resetStopwatch();
                            }
                        }
                    }
                }
            }
        }

        // RIGHT PANEL (30% of horizontal width): Lap Splits
        DFlickable {
            id: rightFlickable
            Layout.preferredWidth: Math.max(240, Math.round(root.width * 0.30))
            Layout.minimumWidth: 220
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: rightCol.implicitHeight + Theme.spacingXL

            Column {
                id: rightCol
                x: 4
                width: Math.max(0, rightFlickable.width - 8)
                spacing: 0

                ClockSectionLabel {
                    width: parent.width
                    iconName: "flag"
                    text: ClockService.stopwatchLaps.length > 0 ? `Lap Splits (${ClockService.stopwatchLaps.length})` : "Lap Splits"
                }

                ClockEmptyState {
                    visible: ClockService.stopwatchLaps.length === 0
                    cardHeight: 150
                    iconName: "flag"
                    iconSize: Theme.iconSizeLarge
                    title: "No Laps Recorded"
                    titlePixelSize: Theme.fontSizeMedium
                    subtitle: "Press Lap while running to record split times."
                }

                Column {
                    visible: ClockService.stopwatchLaps.length > 0
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: ClockService.stopwatchLaps

                        Rectangle {
                            id: lapCard
                            required property var modelData
                            required property int index

                            readonly property bool isFastest: modelData.lapNumber === ClockService.fastestLapNumber
                            readonly property bool isSlowest: modelData.lapNumber === ClockService.slowestLapNumber
                            readonly property bool isFirst: index === 0
                            readonly property bool isLast: index === ClockService.stopwatchLaps.length - 1
                            readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                            readonly property real innerR: Theme.groupedListInnerRadius ?? 4

                            width: parent.width
                            height: root.isSpacious ? 68 : (root.isCompact ? 54 : 60)
                            topLeftRadius: lapHover.hovered ? Theme.cornerRadiusXL : (isFirst ? outerR : innerR)
                            topRightRadius: lapHover.hovered ? Theme.cornerRadiusXL : (isFirst ? outerR : innerR)
                            bottomLeftRadius: lapHover.hovered ? Theme.cornerRadiusXL : (isLast ? outerR : innerR)
                            bottomRightRadius: lapHover.hovered ? Theme.cornerRadiusXL : (isLast ? outerR : innerR)
                            color: lapHover.hovered ? Theme.foregroundColor(Theme.surfaceContainerHigh, true) : Theme.foregroundColor(Theme.surfaceContainerLow, true)
                            border.width: 1
                            border.color: lapHover.hovered
                                ? (isFastest ? Theme.success : (isSlowest ? Theme.error : Theme.primary))
                                : (Theme.outlineMedium ?? Theme.outlineVariant)

                            Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: ClockMetrics.fadeDuration } }

                            HoverHandler { id: lapHover }

                            Item {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingM

                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingS

                                    DIcon {
                                        name: lapCard.isFastest ? "emoji_events" : (lapCard.isSlowest ? "trending_down" : "flag")
                                        size: Theme.iconSizeSmall
                                        color: lapCard.isFastest ? Theme.success : (lapCard.isSlowest ? Theme.error : Theme.primary)
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        StyledText {
                                            text: `Lap #${String(lapCard.modelData.lapNumber).padStart(2, "0")}`
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.DemiBold
                                            color: Theme.surfaceText
                                        }

                                        StyledText {
                                            visible: lapCard.isFastest || lapCard.isSlowest
                                            text: lapCard.isFastest ? "Fastest" : "Slowest"
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            font.weight: Font.Medium
                                            color: lapCard.isFastest ? Theme.success : Theme.error
                                        }
                                    }
                                }

                                Column {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    NumericText {
                                        anchors.right: parent.right
                                        text: "+" + ClockService.formatStopwatch(lapCard.modelData.lapMs)
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        color: lapCard.isFastest ? Theme.success : (lapCard.isSlowest ? Theme.error : Theme.surfaceText)
                                    }

                                    NumericText {
                                        anchors.right: parent.right
                                        text: ClockService.formatStopwatch(lapCard.modelData.totalMs)
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
