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

    readonly property string phaseTitle: {
        switch (ClockService.pomodoroPhase) {
        case "shortBreak": return "Short Break";
        case "longBreak": return "Long Break";
        default: return "Focus Session";
        }
    }

    readonly property string phaseSubtitle: {
        switch (ClockService.pomodoroPhase) {
        case "shortBreak": return "Step away and recharge your mind";
        case "longBreak": return "Take a deep breath and relax";
        default: return "Eliminate distractions and stay in flow";
        }
    }

    readonly property color phaseColor: {
        switch (ClockService.pomodoroPhase) {
        case "shortBreak": return "#6ec78c";
        case "longBreak": return "#6ba5e7";
        default: return Theme.primary;
        }
    }

    readonly property int currentPhaseIdx: {
        switch (ClockService.pomodoroPhase) {
        case "shortBreak": return 1;
        case "longBreak": return 2;
        default: return 0;
        }
    }

    // Active step index (0 .. pomodoroTargetCycles * 2 - 1) across the full Pomodoro cycle
    readonly property int activeCycleStepIdx: {
        const n = Math.max(1, ClockService.pomodoroTargetCycles);
        const mod = ClockService.pomodoroCyclesCompleted % n;
        if (ClockService.pomodoroPhase === "longBreak")
            return n * 2 - 1;
        if (ClockService.pomodoroPhase === "shortBreak") {
            const breakIdx = mod > 0 ? mod - 1 : 0;
            return breakIdx * 2 + 1;
        }
        return mod * 2;
    }

    readonly property string timeDisplay: {
        const totalSec = Math.ceil(ClockService.pomodoroRemainingSeconds);
        const m = Math.floor(totalSec / 60);
        const s = totalSec % 60;
        return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
    }

    readonly property string densityMode: SettingsData.density || "comfortable"
    readonly property bool isSpacious: densityMode === "spacious"
    readonly property bool isCompact: densityMode === "compact" || densityMode === "dense"
    readonly property real panelPad: isSpacious ? Theme.spacingXL : (isCompact ? Theme.spacingM : Theme.spacingL)
    readonly property real panelGap: isSpacious ? Theme.spacingXL : (isCompact ? Theme.spacingM : Theme.spacingL)

    property string statsPeriod: "week" // "day" | "week" | "month"
    property int hoveredBarIdx: -1
    readonly property var focusStats: ClockService.getPomodoroStats(statsPeriod)

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.panelPad
        spacing: root.panelGap

        // LEFT PANEL (~70% width, full height): Main Pomodoro Card
        Rectangle {
            id: mainCard
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property real cardPad: root.isSpacious ? Theme.spacingXL : (root.isCompact ? Theme.spacingM : Theme.spacingL)
            readonly property real dialWidthAvail: Math.max(110, width - cardPad * 2 - Theme.spacingM * 2)
            readonly property real dialHeightAvail: Math.max(110, height - cardPad * 2 - 140)
            readonly property real computedDialSize: Math.min(540, Math.min(dialWidthAvail, dialHeightAvail))

            radius: Theme.cornerRadiusXL
            color: cardHover.hovered ? Theme.surfaceContainerHighest : ClockMetrics.rowColor
            border.width: Theme.layerOutlineWidth
            border.color: ClockService.pomodoroRunning
                ? root.phaseColor
                : (cardHover.hovered ? Theme.outline : Theme.outlineMedium)

            Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: ClockMetrics.fadeDuration } }
            Behavior on border.color { enabled: Theme.animationsEnabled; ColorAnimation { duration: ClockMetrics.fadeDuration } }

            HoverHandler { id: cardHover }

            Item {
                anchors.fill: parent
                anchors.margins: mainCard.cardPad

                // Phase Selection at top (Custom Grouped Buttons)
                Row {
                    id: phaseSelector
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    height: 36
                    spacing: 2

                    readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                    readonly property real innerR: Theme.groupedListInnerRadius ?? 4
                    readonly property var phases: [
                        { key: "focus", icon: "psychology", text: "Focus" },
                        { key: "shortBreak", icon: "coffee", text: "Short Break" },
                        { key: "longBreak", icon: "self_improvement", text: "Long Break" }
                    ]

                    Repeater {
                        model: phaseSelector.phases

                        Rectangle {
                            required property var modelData
                            required property int index

                            readonly property bool active: root.currentPhaseIdx === index
                            readonly property bool isFirst: index === 0
                            readonly property bool isLast: index === phaseSelector.phases.length - 1

                            width: pRow.implicitWidth + Theme.spacingM * 2
                            height: phaseSelector.height
                            topLeftRadius: (active || pMouse.pressed || pMouse.containsMouse) ? phaseSelector.outerR : (isFirst ? phaseSelector.outerR : phaseSelector.innerR)
                            bottomLeftRadius: (active || pMouse.pressed || pMouse.containsMouse) ? phaseSelector.outerR : (isFirst ? phaseSelector.outerR : phaseSelector.innerR)
                            topRightRadius: (active || pMouse.pressed || pMouse.containsMouse) ? phaseSelector.outerR : (isLast ? phaseSelector.outerR : phaseSelector.innerR)
                            bottomRightRadius: (active || pMouse.pressed || pMouse.containsMouse) ? phaseSelector.outerR : (isLast ? phaseSelector.outerR : phaseSelector.innerR)
                            color: (active || pMouse.containsMouse) ? Theme.withAlpha(root.phaseColor, 0.2) : Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: (active || pMouse.containsMouse) ? root.phaseColor : (Theme.outlineMedium ?? Theme.outlineVariant)
                            scale: pMouse.pressed ? 0.95 : 1.0
                            clip: true

                            Behavior on topLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on bottomLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on topRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on bottomRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            DRipple { id: pRipple; anchors.fill: parent; rippleColor: root.phaseColor }

                            Row {
                                id: pRow
                                anchors.centerIn: parent
                                spacing: 5
                                DIcon { name: modelData.icon; size: 16; color: (active || pMouse.containsMouse) ? root.phaseColor : Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }
                                StyledText { text: modelData.text; font.pixelSize: Theme.fontSizeSmall; font.weight: active ? Font.DemiBold : Font.Medium; color: (active || pMouse.containsMouse) ? root.phaseColor : Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                            }

                            MouseArea {
                                id: pMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => pRipple.trigger(mouse.x, mouse.y)
                                onClicked: ClockService.setPomodoroPhase(modelData.key)
                            }
                        }
                    }
                }

                // Dial & Timer Display
                ClockRingDial {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -10
                    dialSize: mainCard.computedDialSize
                    blobSize: Math.round(mainCard.computedDialSize * 0.84)
                    progress: ClockService.pomodoroProgress
                    ringColor: root.phaseColor
                    active: ClockService.pomodoroRunning
                    activeBlobAlpha: 0.20
                    idleBlobAlpha: 0.10
                    lobeAmount: 0.075
                    centerSpacing: 6
                    clickable: true
                    tooltipText: ClockService.pomodoroRunning ? "Click to pause session" : "Click to start session"
                    onClicked: ClockService.togglePomodoro()

                    NumericText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.timeDisplay
                        font.pixelSize: mainCard.computedDialSize < 160 ? Theme.fontSizeXXLarge : Theme.fontSizeDisplay
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.phaseTitle
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Theme.fontWeightBold
                        color: root.phaseColor
                    }
                }

                // Bottom Cycle + Custom Grouped Controls
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    spacing: Theme.spacingS

                    Row {
                        id: cyclePillGroup
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 32
                        spacing: 2

                        readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                        readonly property real innerR: Theme.groupedListInnerRadius ?? 4
                        readonly property int count: Math.max(1, ClockService.pomodoroTargetCycles) * 2

                        Repeater {
                            model: cyclePillGroup.count

                            Rectangle {
                                required property int index
                                readonly property bool isLongBreak: index === cyclePillGroup.count - 1
                                readonly property bool isFocus: index % 2 === 0
                                readonly property int focusNum: Math.floor(index / 2) + 1
                                readonly property string label: isLongBreak ? "Long Break" : (isFocus ? `Focus ${focusNum}` : "Break")
                                readonly property string iconName: isLongBreak ? "self_improvement" : (isFocus ? "psychology" : "coffee")
                                readonly property bool active: root.activeCycleStepIdx === index
                                readonly property bool isFirst: index === 0
                                readonly property bool isLast: index === cyclePillGroup.count - 1

                                width: active ? (cRow.implicitWidth + Theme.spacingM * 2) : 34
                                height: cyclePillGroup.height
                                topLeftRadius: (active || cMouse.pressed || cMouse.containsMouse) ? cyclePillGroup.outerR : (isFirst ? cyclePillGroup.outerR : cyclePillGroup.innerR)
                                bottomLeftRadius: (active || cMouse.pressed || cMouse.containsMouse) ? cyclePillGroup.outerR : (isFirst ? cyclePillGroup.outerR : cyclePillGroup.innerR)
                                topRightRadius: (active || cMouse.pressed || cMouse.containsMouse) ? cyclePillGroup.outerR : (isLast ? cyclePillGroup.outerR : cyclePillGroup.innerR)
                                bottomRightRadius: (active || cMouse.pressed || cMouse.containsMouse) ? cyclePillGroup.outerR : (isLast ? cyclePillGroup.outerR : cyclePillGroup.innerR)
                                color: (active || cMouse.containsMouse) ? Theme.withAlpha(root.phaseColor, 0.22) : Theme.surfaceContainerHigh
                                border.width: 1
                                border.color: (active || cMouse.containsMouse) ? root.phaseColor : (Theme.outlineMedium ?? Theme.outlineVariant)
                                scale: cMouse.pressed ? 0.94 : 1.0
                                clip: true

                                Behavior on width { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                Behavior on topLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                Behavior on bottomLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                Behavior on topRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                Behavior on bottomRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                DRipple { id: cRipple; anchors.fill: parent; rippleColor: root.phaseColor }

                                Row {
                                    id: cRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    DIcon { name: iconName; size: 15; color: (active || cMouse.containsMouse) ? root.phaseColor : Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }
                                    StyledText { visible: active; text: label; font.pixelSize: Theme.fontSizeSmall - 1; font.weight: Font.DemiBold; color: root.phaseColor; anchors.verticalCenter: parent.verticalCenter }
                                }

                                MouseArea {
                                    id: cMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: mouse => cRipple.trigger(mouse.x, mouse.y)
                                    onClicked: {
                                        if (index !== root.activeCycleStepIdx)
                                            ClockService.setPomodoroStep(index);
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 36
                        spacing: 2

                        readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                        readonly property real innerR: Theme.groupedListInnerRadius ?? 4

                        // Start / Pause
                        Rectangle {
                            width: spRow.implicitWidth + Theme.spacingM * 2
                            height: parent.height
                            topLeftRadius: parent.outerR
                            bottomLeftRadius: parent.outerR
                            topRightRadius: (ClockService.pomodoroRunning || spMouse.pressed || spMouse.containsMouse) ? parent.outerR : parent.innerR
                            bottomRightRadius: (ClockService.pomodoroRunning || spMouse.pressed || spMouse.containsMouse) ? parent.outerR : parent.innerR
                            color: (ClockService.pomodoroRunning || spMouse.containsMouse) ? Theme.withAlpha(root.phaseColor, 0.22) : Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: (ClockService.pomodoroRunning || spMouse.containsMouse) ? root.phaseColor : (Theme.outlineMedium ?? Theme.outlineVariant)
                            scale: spMouse.pressed ? 0.95 : 1.0
                            clip: true

                            Behavior on topRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on bottomRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            DRipple { id: spRipple; anchors.fill: parent; rippleColor: root.phaseColor }

                            Row {
                                id: spRow
                                anchors.centerIn: parent
                                spacing: 5
                                DIcon { name: ClockService.pomodoroRunning ? "pause" : "play_arrow"; size: 16; color: (ClockService.pomodoroRunning || spMouse.containsMouse) ? root.phaseColor : Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                                StyledText { text: ClockService.pomodoroRunning ? "Pause" : "Start"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: (ClockService.pomodoroRunning || spMouse.containsMouse) ? root.phaseColor : Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                            }

                            MouseArea {
                                id: spMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => spRipple.trigger(mouse.x, mouse.y)
                                onClicked: ClockService.togglePomodoro()
                            }
                        }

                        // Reset
                        Rectangle {
                            width: rstRow.implicitWidth + Theme.spacingM * 2
                            height: parent.height
                            topLeftRadius: (rstMouse.pressed || rstMouse.containsMouse) ? parent.outerR : parent.innerR
                            bottomLeftRadius: (rstMouse.pressed || rstMouse.containsMouse) ? parent.outerR : parent.innerR
                            topRightRadius: (rstMouse.pressed || rstMouse.containsMouse) ? parent.outerR : parent.innerR
                            bottomRightRadius: (rstMouse.pressed || rstMouse.containsMouse) ? parent.outerR : parent.innerR
                            color: rstMouse.containsMouse ? Theme.withAlpha(Theme.error, 0.2) : Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: rstMouse.containsMouse ? Theme.error : (Theme.outlineMedium ?? Theme.outlineVariant)
                            scale: rstMouse.pressed ? 0.95 : 1.0
                            clip: true

                            Behavior on topLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on bottomLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on topRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on bottomRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            DRipple { id: rstRipple; anchors.fill: parent; rippleColor: Theme.error }

                            Row {
                                id: rstRow
                                anchors.centerIn: parent
                                spacing: 5
                                DIcon { name: "replay"; size: 16; color: rstMouse.containsMouse ? Theme.error : Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                                StyledText { text: "Reset"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: rstMouse.containsMouse ? Theme.error : Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                            }

                            MouseArea {
                                id: rstMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => rstRipple.trigger(mouse.x, mouse.y)
                                onClicked: ClockService.resetPomodoro()
                            }
                        }

                        // Skip
                        Rectangle {
                            width: skipRow.implicitWidth + Theme.spacingM * 2
                            height: parent.height
                            topLeftRadius: (skipMouse.pressed || skipMouse.containsMouse) ? parent.outerR : parent.innerR
                            bottomLeftRadius: (skipMouse.pressed || skipMouse.containsMouse) ? parent.outerR : parent.innerR
                            topRightRadius: parent.outerR
                            bottomRightRadius: parent.outerR
                            color: skipMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.2) : Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: skipMouse.containsMouse ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                            scale: skipMouse.pressed ? 0.95 : 1.0
                            clip: true

                            Behavior on topLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on bottomLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            DRipple { id: skipRipple; anchors.fill: parent; rippleColor: Theme.primary }

                            Row {
                                id: skipRow
                                anchors.centerIn: parent
                                spacing: 5
                                DIcon { name: "skip_next"; size: 16; color: skipMouse.containsMouse ? Theme.primary : Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                                StyledText { text: "Skip"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: skipMouse.containsMouse ? Theme.primary : Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                            }

                            MouseArea {
                                id: skipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => skipRipple.trigger(mouse.x, mouse.y)
                                onClicked: ClockService.skipPomodoroPhase()
                            }
                        }
                    }
                }
            }
        }

        // RIGHT PANEL (30% width, full height): Focus Statistics
        DFlickable {
            id: rightFlickable
            Layout.preferredWidth: Math.max(260, Math.round(root.width * 0.30))
            Layout.minimumWidth: 240
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: statsCard.height + Theme.spacingXL

            // Focus Activity & Statistics Chart Card (Day / Week / Month)
            Rectangle {
                id: statsCard
                width: rightFlickable.width
                height: statsCol.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadiusXL
                color: statsHover.hovered ? Theme.foregroundColor(Theme.surfaceContainerHigh, true) : Theme.foregroundColor(Theme.surfaceContainerLow, true)
                border.width: 1
                border.color: statsHover.hovered ? Theme.outline : Theme.outlineVariant

                Behavior on color {
                    enabled: Theme.animationsEnabled
                    ColorAnimation { duration: ClockMetrics.fadeDuration }
                }
                Behavior on border.color {
                    enabled: Theme.animationsEnabled
                    ColorAnimation { duration: ClockMetrics.fadeDuration }
                }

                HoverHandler {
                    id: statsHover
                }

                Column {
                    id: statsCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    // Header Row: Title + Summary Badges + Day/Week/Month Selector
                    Item {
                        width: parent.width
                        height: 34

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DIcon {
                                name: "bar_chart"
                                size: Theme.chipIconSize
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: "Focus Statistics"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            DBadge {
                                text: `${root.focusStats.totalFormatted} • ${root.focusStats.totalSessions} sessions`
                                reserveText: "88h 88m • 88 sessions"
                                color: Theme.withAlpha(Theme.primary, 0.2)
                                textColor: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Segmented Day / Week / Month Selector (Custom Grouped Buttons)
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 30
                            spacing: 2

                            readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                            readonly property real innerR: Theme.groupedListInnerRadius ?? 4
                            readonly property var periods: [
                                { key: "day", label: "Day" },
                                { key: "week", label: "Week" },
                                { key: "month", label: "Month" }
                            ]

                            Repeater {
                                model: parent.periods

                                Rectangle {
                                    required property var modelData
                                    required property int index

                                    readonly property bool active: root.statsPeriod === modelData.key
                                    readonly property bool isFirst: index === 0
                                    readonly property bool isLast: index === 2

                                    width: stLbl.implicitWidth + Theme.spacingS * 2
                                    height: parent.height
                                    topLeftRadius: (active || stMouse.pressed || stMouse.containsMouse) ? parent.outerR : (isFirst ? parent.outerR : parent.innerR)
                                    bottomLeftRadius: (active || stMouse.pressed || stMouse.containsMouse) ? parent.outerR : (isFirst ? parent.outerR : parent.innerR)
                                    topRightRadius: (active || stMouse.pressed || stMouse.containsMouse) ? parent.outerR : (isLast ? parent.outerR : parent.innerR)
                                    bottomRightRadius: (active || stMouse.pressed || stMouse.containsMouse) ? parent.outerR : (isLast ? parent.outerR : parent.innerR)
                                    color: (active || stMouse.containsMouse) ? Theme.withAlpha(Theme.primary, 0.2) : Theme.surfaceContainerHigh
                                    border.width: 1
                                    border.color: (active || stMouse.containsMouse) ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                                    scale: stMouse.pressed ? 0.95 : 1.0
                                    clip: true

                                    DRipple { id: stRipple; anchors.fill: parent; rippleColor: Theme.primary }

                                    StyledText {
                                        id: stLbl
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        font.weight: active ? Font.DemiBold : Font.Medium
                                        color: (active || stMouse.containsMouse) ? Theme.primary : Theme.surfaceText
                                    }

                                    MouseArea {
                                        id: stMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onPressed: mouse => stRipple.trigger(mouse.x, mouse.y)
                                        onClicked: root.statsPeriod = modelData.key
                                    }
                                }
                            }
                        }
                    }

                    // KPI Strip (Total, Average, Peak)
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Repeater {
                            model: [
                                {
                                    icon: "timer",
                                    label: root.statsPeriod === "day" ? "Today Total" : (root.statsPeriod === "week" ? "Week Total" : "30-Day Total"),
                                    value: root.focusStats.totalFormatted
                                },
                                {
                                    icon: "trending_up",
                                    label: root.statsPeriod === "day" ? "Per 3h Block" : (root.statsPeriod === "week" ? "Daily Average" : "3-Day Average"),
                                    value: root.focusStats.avgFormatted
                                },
                                {
                                    icon: "emoji_events",
                                    label: "Peak Focus",
                                    value: root.focusStats.peakLabel
                                }
                            ]

                            Rectangle {
                                id: kpiCard
                                required property var modelData
                                width: Math.floor((parent.width - Theme.spacingM * 2) / 3)
                                height: 52
                                radius: Theme.cornerRadiusL
                                color: Theme.withAlpha(Theme.surfaceVariant, 0.22)

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingS

                                    Rectangle {
                                        width: 30
                                        height: 30
                                        radius: 15
                                        color: Theme.withAlpha(Theme.primary, 0.16)
                                        anchors.verticalCenter: parent.verticalCenter

                                        DIcon {
                                            anchors.centerIn: parent
                                            name: kpiCard.modelData.icon
                                            size: Theme.iconSizeSmall
                                            color: Theme.primary
                                        }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        StyledText {
                                            text: kpiCard.modelData.label
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }

                                        NumericText {
                                            text: kpiCard.modelData.value
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Bold
                                            color: Theme.surfaceText
                                            horizontalAlignment: Text.AlignLeft
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Interactive Vertical Bar Chart
                    Item {
                        id: chartArea
                        width: parent.width
                        height: 156

                        readonly property real plotTop: 22
                        readonly property real plotBottom: height - 24
                        readonly property real plotHeight: plotBottom - plotTop
                        readonly property real plotRightMargin: 42
                        readonly property real plotWidth: width - plotRightMargin

                        // Horizontal Guide Lines (100%, 50%, 0%) + Y-Axis Scale Labels
                        Repeater {
                            model: [1.0, 0.5, 0.0]

                            Item {
                                id: guideItem
                                required property real modelData
                                width: chartArea.width
                                y: chartArea.plotBottom - modelData * chartArea.plotHeight

                                Rectangle {
                                    width: chartArea.plotWidth
                                    height: 1
                                    color: Theme.withAlpha(Theme.outlineVariant, guideItem.modelData === 0 ? 0.65 : 0.32)
                                }

                                NumericText {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.top
                                    text: ClockService.formatFocusMinutes(Math.round(root.focusStats.scaleMax * guideItem.modelData))
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }

                        // Columns / Bars Row
                        Row {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            width: chartArea.plotWidth
                            height: parent.height

                            Repeater {
                                model: root.focusStats.bars

                                Item {
                                    id: barSlot
                                    required property var modelData
                                    required property int index

                                    readonly property int barCount: Math.max(1, root.focusStats.bars.length)
                                    width: chartArea.plotWidth / barCount
                                    height: chartArea.height

                                    readonly property real frac: root.focusStats.scaleMax > 0
                                        ? Math.max(0, Math.min(1, modelData.minutes / root.focusStats.scaleMax))
                                        : 0
                                    readonly property real barH: modelData.minutes > 0
                                        ? Math.max(8, Math.round(frac * chartArea.plotHeight))
                                        : 4
                                    readonly property bool isHovered: barMouse.containsMouse

                                    // Floating Value Pill above bar
                                    NumericText {
                                        visible: barSlot.modelData.minutes > 0 && (barSlot.isHovered || barSlot.modelData.isCurrent)
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: Math.max(0, chartArea.plotBottom - barSlot.barH - 18)
                                        text: ClockService.formatFocusMinutes(barSlot.modelData.minutes)
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        color: (barSlot.modelData.isCurrent || barSlot.isHovered) ? Theme.primary : Theme.surfaceVariantText
                                    }

                                    // Vertical Bar Pill
                                    Rectangle {
                                        id: barRect
                                        width: Math.min(32, Math.max(14, Math.floor(barSlot.width * 0.48)))
                                        height: barSlot.barH
                                        radius: Math.min(8, width / 2)
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: chartArea.plotBottom - height
                                        color: barSlot.modelData.minutes === 0
                                            ? Theme.withAlpha(Theme.surfaceVariant, 0.28)
                                            : ((barSlot.modelData.isCurrent || barSlot.isHovered)
                                                ? Theme.primary
                                                : Theme.withAlpha(Theme.primary, 0.48))

                                        Behavior on height {
                                            enabled: Theme.animationsEnabled
                                            NumberAnimation { duration: ClockMetrics.transitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: ClockMetrics.curveFastSpatial }
                                        }
                                        Behavior on color {
                                            enabled: Theme.animationsEnabled
                                            ColorAnimation { duration: ClockMetrics.fadeDuration }
                                        }
                                    }

                                    // X-Axis Label below bar
                                    StyledText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: chartArea.plotBottom + 6
                                        text: barSlot.modelData.label
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: (barSlot.modelData.isCurrent || barSlot.isHovered) ? Font.Bold : Font.Medium
                                        color: (barSlot.modelData.isCurrent || barSlot.isHovered) ? Theme.primary : Theme.surfaceVariantText
                                    }

                                    MouseArea {
                                        id: barMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    DTooltipHost {
                                        target: barSlot
                                        hoverArea: barMouse
                                        text: `${barSlot.modelData.sublabel}: ${ClockService.formatFocusMinutes(barSlot.modelData.minutes)}`
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
