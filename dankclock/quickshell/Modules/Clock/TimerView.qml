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

    readonly property bool hasTimers: ClockService.timers.length > 0
    readonly property string densityMode: SettingsData.density || "comfortable"
    readonly property bool isSpacious: densityMode === "spacious"
    readonly property bool isCompact: densityMode === "compact" || densityMode === "dense"
    readonly property real panelPad: isSpacious ? Theme.spacingXL : (isCompact ? Theme.spacingM : Theme.spacingL)
    readonly property real panelGap: isSpacious ? Theme.spacingXL : (isCompact ? Theme.spacingM : Theme.spacingL)

    readonly property int safeActiveIdx: Math.max(0, Math.min(ClockService.activeTimerIndex, ClockService.timers.length - 1))

    // Cached list of timer indices shown in the left countdown grid; only mutated when membership changes
    // so Repeater delegates are never recreated on every countdown tick (eliminates hover flicker).
    property var countdownIndices: [-1]

    function syncCountdownIndices() {
        const next = [];
        for (let i = 0; i < ClockService.timers.length; i++) {
            const t = ClockService.timers[i];
            if (t && (t.running || (t.finished && !t.finishedSettled) || t.started || (t.remainingMs > 0 && t.remainingMs < t.totalMs)))
                next.push(i);
        }
        if (next.length === 0) {
            if (ClockService.timers.length > 0)
                next.push(safeActiveIdx);
            else
                next.push(-1);
        }
        if (next.length === countdownIndices.length) {
            let same = true;
            for (let i = 0; i < next.length; i++) {
                if (next[i] !== countdownIndices[i]) {
                    same = false;
                    break;
                }
            }
            if (same)
                return;
        }
        countdownIndices = next;
    }

    Component.onCompleted: syncCountdownIndices()

    Connections {
        target: ClockService
        function onTimerTickRevisionChanged() {
            root.syncCountdownIndices();
        }
        function onTimersChanged() {
            root.syncCountdownIndices();
        }
        function onActiveTimerIndexChanged() {
            root.syncCountdownIndices();
        }
    }

    readonly property var quickPresets: [
        { label: "1 min", sec: 60 },
        { label: "3 min", sec: 180 },
        { label: "5 min", sec: 300 },
        { label: "10 min", sec: 600 },
        { label: "15 min", sec: 900 },
        { label: "25 min", sec: 1500 },
        { label: "45 min", sec: 2700 }
    ]

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.panelPad
        spacing: root.panelGap

        // LEFT PANEL (~70% width, full height): Dynamic Grid & Stack of Active Countdowns + Scroll Indicator
        Item {
            id: leftPanelWrap
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property int count: root.countdownIndices.length
            readonly property real cardGap: root.isSpacious ? Theme.spacingL : (root.isCompact ? Theme.spacingS : Theme.spacingM)
            readonly property int cols: count <= 1 ? 1 : (width >= 420 ? 2 : 1)
            readonly property int rows: Math.max(1, Math.ceil(count / cols))
            readonly property int visibleRows: Math.min(2, rows)
            readonly property real minCardH: root.isCompact ? 180 : 200
            readonly property real cardW: Math.floor((width - (cols - 1) * cardGap) / cols)
            readonly property real cardH: Math.max(minCardH, Math.floor((height - (visibleRows - 1) * cardGap) / visibleRows))
            readonly property bool hasMoreBelow: leftFlickable.contentHeight > leftFlickable.height + 4 && !leftFlickable.atYEnd

            DFlickable {
                id: leftFlickable
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: Math.max(height, leftPanelWrap.rows * leftPanelWrap.cardH + Math.max(0, leftPanelWrap.rows - 1) * leftPanelWrap.cardGap)

                Item {
                    id: leftGrid
                    width: leftFlickable.width
                    height: leftFlickable.contentHeight

                    Repeater {
                        model: root.countdownIndices.length

                        Rectangle {
                            id: countdownCard
                            required property int index

                            readonly property int tIdx: index < root.countdownIndices.length ? root.countdownIndices[index] : -1
                            readonly property var tObj: {
                                void ClockService.timerTickRevision;
                                return (tIdx >= 0 && tIdx < ClockService.timers.length) ? ClockService.timers[tIdx] : null;
                            }
                            readonly property bool tRunning: {
                                void ClockService.timerTickRevision;
                                return Boolean(tObj && tObj.running);
                            }
                            readonly property bool tFinished: {
                                void ClockService.timerTickRevision;
                                return Boolean(tObj && tObj.finished);
                            }
                            readonly property bool tStarted: {
                                void ClockService.timerTickRevision;
                                return Boolean(tObj && (tObj.started || (tObj.remainingMs > 0 && tObj.remainingMs < tObj.totalMs)));
                            }
                            readonly property double tTotalMs: {
                                void ClockService.timerTickRevision;
                                return tObj ? tObj.totalMs : 0;
                            }
                            readonly property double tRemainingMs: {
                                void ClockService.timerTickRevision;
                                return tObj ? tObj.remainingMs : 0;
                            }
                            readonly property real tProgress: (tObj && tTotalMs > 0) ? Math.max(0, Math.min(1, tRemainingMs / tTotalMs)) : 0
                            readonly property real cardPad: root.isSpacious ? Theme.spacingXL : (root.isCompact ? Theme.spacingM : Theme.spacingL)
                            readonly property real dialWidthAvail: Math.max(88, width - cardPad * 2 - Theme.spacingM * 2)
                            readonly property real dialHeightAvail: Math.max(88, height - cardPad * 2 - 34 - 42 - (root.isCompact ? Theme.spacingS : Theme.spacingM) * 2)
                            readonly property real computedDialSize: leftPanelWrap.count === 1
                                ? Math.min(540, Math.min(dialWidthAvail, dialHeightAvail))
                                : Math.min(dialWidthAvail, dialHeightAvail)
                            readonly property bool isLastOddSpan: (leftPanelWrap.cols === 2 && (root.countdownIndices.length % 2 === 1) && index === root.countdownIndices.length - 1)
                            readonly property int colIdx: index % leftPanelWrap.cols
                            readonly property int rowIdx: Math.floor(index / leftPanelWrap.cols)

                            property real enterOpacity: 0
                            property real enterScale: 0.92
                            Component.onCompleted: {
                                enterOpacity = 1;
                                enterScale = 1.0;
                            }

                            x: colIdx * (leftPanelWrap.cardW + leftPanelWrap.cardGap)
                            y: rowIdx * (leftPanelWrap.cardH + leftPanelWrap.cardGap)
                            width: isLastOddSpan ? leftGrid.width : leftPanelWrap.cardW
                            height: leftPanelWrap.cardH
                            opacity: enterOpacity
                            scale: enterScale
                            radius: Theme.cornerRadiusXL
                            color: heroHover.hovered ? Theme.surfaceContainerHighest : ClockMetrics.rowColor
                            border.width: Theme.layerOutlineWidth
                            border.color: tRunning
                                ? Theme.primary
                                : (heroHover.hovered ? Theme.outline : Theme.outlineMedium)

                            Behavior on enterOpacity {
                                enabled: Theme.animationsEnabled
                                NumberAnimation { duration: ClockMetrics.transitionDuration; easing.type: Easing.OutCubic }
                            }
                            Behavior on enterScale {
                                enabled: Theme.animationsEnabled
                                NumberAnimation { duration: ClockMetrics.transitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: ClockMetrics.curveFastSpatial }
                            }
                            Behavior on x {
                                enabled: Theme.animationsEnabled
                                NumberAnimation { duration: ClockMetrics.transitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: ClockMetrics.curveFastSpatial }
                            }
                            Behavior on y {
                                enabled: Theme.animationsEnabled
                                NumberAnimation { duration: ClockMetrics.transitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: ClockMetrics.curveFastSpatial }
                            }
                            Behavior on width {
                                enabled: Theme.animationsEnabled
                                NumberAnimation { duration: ClockMetrics.transitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: ClockMetrics.curveFastSpatial }
                            }
                            Behavior on height {
                                enabled: Theme.animationsEnabled
                                NumberAnimation { duration: ClockMetrics.transitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: ClockMetrics.curveFastSpatial }
                            }
                            Behavior on color {
                                enabled: Theme.animationsEnabled
                                ColorAnimation { duration: ClockMetrics.fadeDuration }
                            }
                            Behavior on border.color {
                                enabled: Theme.animationsEnabled
                                ColorAnimation { duration: ClockMetrics.fadeDuration }
                            }

                            HoverHandler { id: heroHover }

                            // Click anywhere on the countdown card/timer to Start or Pause
                            MouseArea {
                                id: cardToggleMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (countdownCard.tObj && countdownCard.tIdx >= 0)
                                        ClockService.toggleTimer(countdownCard.tIdx);
                                    else
                                        ClockService.newTimerModalOpen = true;
                                }
                            }

                            Item {
                                anchors.fill: parent
                                anchors.margins: countdownCard.cardPad

                                // Top Header: Status Badge + Label
                                Row {
                                    id: headerLeftRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    height: 30
                                    spacing: Theme.spacingS

                                    DBadge {
                                        id: headerStatusBadge
                                        visible: countdownCard.tObj !== null
                                        text: countdownCard.tFinished ? "FINISHED" : (countdownCard.tRunning ? "RUNNING" : (countdownCard.tStarted ? "PAUSED" : "READY"))
                                        color: countdownCard.tFinished ? Theme.errorContainer : (countdownCard.tRunning ? Theme.primary : Theme.secondaryContainer)
                                        textColor: countdownCard.tFinished ? Theme.onErrorContainer : (countdownCard.tRunning ? Theme.onPrimary : Theme.onSecondaryContainer)
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.max(0, headerLeftRow.width - (headerStatusBadge.visible ? headerStatusBadge.width + headerLeftRow.spacing : 0))
                                        text: countdownCard.tObj ? countdownCard.tObj.label : "No Timers"
                                        font.pixelSize: Theme.fontSizeLarge
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.surfaceText
                                        wrapMode: Text.NoWrap
                                        elide: Text.ElideRight
                                    }
                                }

                                // Center Ring Gauge (clicking pauses/starts via cardToggleMouse / dial)
                                ClockRingDial {
                                    anchors.centerIn: parent
                                    dialSize: countdownCard.computedDialSize
                                    blobSize: Math.round(countdownCard.computedDialSize * 0.84)
                                    progress: countdownCard.tProgress
                                    ringColor: countdownCard.tFinished ? Theme.error : Theme.primary
                                    active: countdownCard.tRunning
                                    clickable: true
                                    tooltipText: countdownCard.tObj
                                        ? (countdownCard.tRunning ? "Click to pause" : "Click to start")
                                        : "Create a timer"
                                    onClicked: {
                                        if (countdownCard.tObj && countdownCard.tIdx >= 0)
                                            ClockService.toggleTimer(countdownCard.tIdx);
                                        else
                                            ClockService.newTimerModalOpen = true;
                                    }

                                    NumericText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: countdownCard.tObj ? ClockService.formatDuration(countdownCard.tRemainingMs) : "00:00"
                                        font.pixelSize: countdownCard.computedDialSize < 150 ? Theme.fontSizeXXLarge : Theme.fontSizeDisplay
                                        font.weight: Font.Bold
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        visible: countdownCard.tObj !== null
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: countdownCard.tObj ? `Total ${ClockService.formatDuration(countdownCard.tTotalMs)}` : ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Theme.fontWeightMedium
                                        color: Theme.surfaceVariantText
                                    }
                                }

                                // Bottom Controls: Custom Group Button (Start/Pause, Reset, +1:00)
                                Row {
                                    id: countdownControlsGroup
                                    visible: countdownCard.tObj !== null
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    height: 36
                                    spacing: 2
                                    z: 2

                                    readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                                    readonly property real innerR: Theme.groupedListInnerRadius ?? 4

                                    // First: Start / Pause
                                    Rectangle {
                                        width: spRow.implicitWidth + Theme.spacingM * 2
                                        height: parent.height
                                        topLeftRadius: parent.outerR
                                        bottomLeftRadius: parent.outerR
                                        topRightRadius: (countdownCard.tRunning || spMouse.containsMouse) ? parent.outerR : parent.innerR
                                        bottomRightRadius: (countdownCard.tRunning || spMouse.containsMouse) ? parent.outerR : parent.innerR
                                        color: (countdownCard.tRunning || spMouse.containsMouse) ? Theme.withAlpha(Theme.primary, 0.22) : Theme.surfaceContainerHigh
                                        border.width: 1
                                        border.color: (countdownCard.tRunning || spMouse.containsMouse) ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                                        scale: spMouse.pressed ? 0.95 : (spMouse.containsMouse ? 1.03 : 1.0)
                                        clip: true

                                        Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                        DRipple { id: spRipple; anchors.fill: parent; rippleColor: Theme.primary }

                                        Row {
                                            id: spRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            DIcon {
                                                name: countdownCard.tRunning ? "pause" : "play_arrow"
                                                size: 16
                                                color: (countdownCard.tRunning || spMouse.containsMouse) ? Theme.primary : Theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            StyledText {
                                                text: countdownCard.tRunning ? "Pause" : "Start"
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: (countdownCard.tRunning || spMouse.containsMouse) ? Theme.primary : Theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: spMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onPressed: mouse => spRipple.trigger(mouse.x, mouse.y)
                                            onClicked: ClockService.toggleTimer(countdownCard.tIdx)
                                        }
                                    }

                                    // Middle: Reset (smoothly expands/collapses when timer starts or resets)
                                    Rectangle {
                                        readonly property bool showReset: countdownCard.tStarted || countdownCard.tRunning || countdownCard.tFinished
                                        width: showReset ? (rstRow.implicitWidth + Theme.spacingM * 2) : 0
                                        height: parent.height
                                        opacity: showReset ? 1 : 0
                                        enabled: showReset
                                        topLeftRadius: rstMouse.containsMouse ? parent.outerR : parent.innerR
                                        bottomLeftRadius: rstMouse.containsMouse ? parent.outerR : parent.innerR
                                        topRightRadius: rstMouse.containsMouse ? parent.outerR : parent.innerR
                                        bottomRightRadius: rstMouse.containsMouse ? parent.outerR : parent.innerR
                                        color: rstMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.2) : Theme.surfaceContainerHigh
                                        border.width: showReset ? 1 : 0
                                        border.color: rstMouse.containsMouse ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                                        scale: rstMouse.pressed ? 0.95 : (rstMouse.containsMouse ? 1.03 : 1.0)
                                        clip: true

                                        Behavior on width { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150 } }
                                        Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                        DRipple { id: rstRipple; anchors.fill: parent; rippleColor: Theme.primary }

                                        Row {
                                            id: rstRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            DIcon {
                                                name: "restart_alt"
                                                size: 16
                                                color: rstMouse.containsMouse ? Theme.primary : Theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            StyledText {
                                                text: "Reset"
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: rstMouse.containsMouse ? Theme.primary : Theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: rstMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onPressed: mouse => rstRipple.trigger(mouse.x, mouse.y)
                                            onClicked: ClockService.resetTimer(countdownCard.tIdx)
                                        }
                                    }

                                    // Last: +1:00
                                    Rectangle {
                                        width: addMinRow.implicitWidth + Theme.spacingM * 2
                                        height: parent.height
                                        topLeftRadius: addMinMouse.containsMouse ? parent.outerR : parent.innerR
                                        bottomLeftRadius: addMinMouse.containsMouse ? parent.outerR : parent.innerR
                                        topRightRadius: parent.outerR
                                        bottomRightRadius: parent.outerR
                                        color: addMinMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.2) : Theme.surfaceContainerHigh
                                        border.width: 1
                                        border.color: addMinMouse.containsMouse ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                                        scale: addMinMouse.pressed ? 0.95 : (addMinMouse.containsMouse ? 1.03 : 1.0)
                                        clip: true

                                        Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                        DRipple { id: addMinRipple; anchors.fill: parent; rippleColor: Theme.primary }

                                        Row {
                                            id: addMinRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            DIcon {
                                                name: "more_time"
                                                size: 16
                                                color: addMinMouse.containsMouse ? Theme.primary : Theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            StyledText {
                                                text: "+1:00"
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: addMinMouse.containsMouse ? Theme.primary : Theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: addMinMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onPressed: mouse => addMinRipple.trigger(mouse.x, mouse.y)
                                            onClicked: ClockService.addOneMinute(countdownCard.tIdx)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Bottom "More" Scroll Indicator (pill only, no gradient shadow)
            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 36
                visible: leftPanelWrap.hasMoreBelow

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.spacingXS
                    width: moreRow.implicitWidth + Theme.spacingM * 2
                    height: 28
                    radius: 14
                    color: moreMouse.containsMouse ? Theme.primaryContainer : Theme.surfaceContainerHighest
                    border.width: 1
                    border.color: moreMouse.containsMouse ? Theme.primary : Theme.outlineMedium

                    Row {
                        id: moreRow
                        anchors.centerIn: parent
                        spacing: 4

                        DIcon {
                            name: "keyboard_arrow_down"
                            size: 16
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "More countdowns"
                            font.pixelSize: Theme.fontSizeSmall - 1
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: moreMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            leftFlickable.contentY = Math.min(
                                leftFlickable.contentHeight - leftFlickable.height,
                                leftFlickable.contentY + leftPanelWrap.cardH + leftPanelWrap.cardGap
                            );
                        }
                    }
                }
            }
        }

        // RIGHT PANEL (30% of horizontal width): Presets Custom Grid + All Timers + Full-width Add Card
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
                spacing: root.isSpacious ? Theme.spacingL : (root.isCompact ? Theme.spacingS : Theme.spacingM)

                // Quick Start Presets Custom Grouped Grid
                Column {
                    width: parent.width
                    spacing: 0

                    ClockSectionLabel {
                        width: parent.width
                        iconName: "bolt"
                        text: "Quick Start Presets"
                    }

                    Item {
                        id: presetsGridWrap
                        width: parent.width
                        height: presetsCol.implicitHeight

                        readonly property int cols: 2
                        readonly property real btnH: root.isSpacious ? 42 : (root.isCompact ? 32 : 36)
                        readonly property real colW: Math.floor((width - 2) / cols)
                        readonly property int rows: Math.ceil(root.quickPresets.length / cols)

                        Column {
                            id: presetsCol
                            width: parent.width
                            spacing: 2

                            Repeater {
                                model: presetsGridWrap.rows

                                Row {
                                    id: presetRow
                                    required property int index
                                    readonly property int rowIdx: index
                                    readonly property bool isFirstRow: rowIdx === 0
                                    readonly property bool isLastRow: rowIdx === presetsGridWrap.rows - 1
                                    readonly property int startIdx: rowIdx * presetsGridWrap.cols
                                    readonly property int itemCount: Math.min(presetsGridWrap.cols, root.quickPresets.length - startIdx)

                                    width: parent.width
                                    height: presetsGridWrap.btnH
                                    spacing: 2

                                    Repeater {
                                        model: presetRow.itemCount

                                        Rectangle {
                                            id: presetBtn
                                            required property int index
                                            readonly property var presetData: root.quickPresets[presetRow.startIdx + index]
                                            readonly property bool isFirstCol: index === 0
                                            readonly property bool isLastCol: index === presetRow.itemCount - 1
                                            readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                                            readonly property real innerR: Theme.groupedListInnerRadius ?? 4

                                            width: presetRow.itemCount === 1 ? presetRow.width : (isLastCol ? presetRow.width - presetsGridWrap.colW - 2 : presetsGridWrap.colW)
                                            height: presetRow.height
                                            topLeftRadius: presetMouse.containsMouse ? outerR : ((presetRow.isFirstRow && isFirstCol) ? outerR : innerR)
                                            topRightRadius: presetMouse.containsMouse ? outerR : ((presetRow.isFirstRow && isLastCol) ? outerR : innerR)
                                            bottomLeftRadius: presetMouse.containsMouse ? outerR : ((presetRow.isLastRow && isFirstCol) ? outerR : innerR)
                                            bottomRightRadius: presetMouse.containsMouse ? outerR : ((presetRow.isLastRow && isLastCol) ? outerR : innerR)
                                            color: presetMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.2) : Theme.foregroundColor(Theme.surfaceContainerLow, true)
                                            border.width: 1
                                            border.color: presetMouse.containsMouse ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                                            scale: presetMouse.pressed ? 0.97 : 1.0
                                            clip: true

                                            Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                            DRipple { id: presetRipple; anchors.fill: parent; rippleColor: Theme.primary }

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 4

                                                DIcon {
                                                    name: "bolt"
                                                    size: 14
                                                    color: presetMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                StyledText {
                                                    text: presetBtn.presetData.label
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    font.weight: Font.Medium
                                                    color: presetMouse.containsMouse ? Theme.primary : Theme.surfaceText
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            MouseArea {
                                                id: presetMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onPressed: mouse => presetRipple.trigger(mouse.x, mouse.y)
                                                onClicked: ClockService.startPresetTimer(presetBtn.presetData.sec, presetBtn.presetData.label)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // All Timers Section (Grouped Stack + Hover-to-Delete + Full-width Add Card)
                Column {
                    width: parent.width
                    spacing: 0

                    ClockSectionLabel {
                        width: parent.width
                        iconName: "hourglass_empty"
                        text: `All Timers (${ClockService.timers.length})`
                    }

                    Column {
                        width: parent.width
                        spacing: root.isSpacious ? Theme.spacingM : (root.isCompact ? Theme.spacingXS : Theme.spacingS)

                        readonly property real cardHeight: root.isSpacious ? 96 : (root.isCompact ? 74 : 84)
                        readonly property real cardPad: root.isSpacious ? Theme.spacingM : (root.isCompact ? Theme.spacingS : Theme.spacingM)

                        Column {
                            visible: ClockService.timers.length > 0
                            width: parent.width
                            spacing: 2

                            Repeater {
                                model: ClockService.timers.length

                                Rectangle {
                                    id: timerCard
                                    required property int index

                                    readonly property var timerObj: {
                                        void ClockService.timerTickRevision;
                                        return ClockService.timers[index] || { id: 0, label: "Timer", totalMs: 0, remainingMs: 0, running: false, finished: false };
                                    }
                                    readonly property bool isCurrent: index === root.safeActiveIdx
                                    readonly property bool itemRunning: {
                                        void ClockService.timerTickRevision;
                                        return Boolean(timerObj.running);
                                    }
                                    readonly property bool itemFinished: {
                                        void ClockService.timerTickRevision;
                                        return Boolean(timerObj.finished);
                                    }
                                    readonly property bool itemFinishedSettled: {
                                        void ClockService.timerTickRevision;
                                        return Boolean(timerObj.finishedSettled);
                                    }
                                    readonly property bool itemStarted: {
                                        void ClockService.timerTickRevision;
                                        return Boolean(timerObj.started) || (timerObj.remainingMs > 0 && timerObj.remainingMs < timerObj.totalMs);
                                    }
                                    readonly property string countdownText: {
                                        void ClockService.timerTickRevision;
                                        return ClockService.formatDuration(timerObj.remainingMs);
                                    }
                                    readonly property bool isFirst: index === 0
                                    readonly property bool isLast: index === ClockService.timers.length - 1
                                    readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                                    readonly property real innerR: Theme.groupedListInnerRadius ?? 4
                                    readonly property real activeR: Theme.cornerRadiusXL
                                    readonly property bool separateRounded: itemRunning || (itemFinished && !itemFinishedSettled) || timerCardHover.hovered
                                    property real topCardRadius: separateRounded ? activeR : (isFirst ? outerR : innerR)
                                    property real bottomCardRadius: separateRounded ? activeR : (isLast ? outerR : innerR)

                                    width: parent.width
                                    height: parent.parent.cardHeight
                                    topLeftRadius: topCardRadius
                                    topRightRadius: topCardRadius
                                    bottomLeftRadius: bottomCardRadius
                                    bottomRightRadius: bottomCardRadius
                                    scale: timerCardMouse.pressed ? 0.98 : 1.0
                                    color: isCurrent
                                        ? (timerCardHover.hovered ? Theme.blend(Theme.secondaryContainer, Theme.primary, 0.18) : Theme.withAlpha(Theme.secondaryContainer, 0.72))
                                        : (timerCardHover.hovered ? Theme.foregroundColor(Theme.surfaceContainerHigh, true) : Theme.foregroundColor(Theme.surfaceContainerLow, true))
                                    border.width: (isCurrent || itemRunning || timerCardHover.hovered) ? 1.5 : 1
                                    border.color: itemRunning
                                        ? Theme.primary
                                        : (isCurrent ? Theme.primary : (timerCardHover.hovered ? Theme.outline : Theme.outlineVariant))

                                    Behavior on topCardRadius {
                                        enabled: Theme.animationsEnabled
                                        NumberAnimation { duration: ClockMetrics.transitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: ClockMetrics.curveFastSpatial }
                                    }
                                    Behavior on bottomCardRadius {
                                        enabled: Theme.animationsEnabled
                                        NumberAnimation { duration: ClockMetrics.transitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: ClockMetrics.curveFastSpatial }
                                    }
                                    Behavior on scale {
                                        enabled: Theme.animationsEnabled
                                        NumberAnimation { duration: ClockMetrics.transitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: ClockMetrics.curveFastSpatial }
                                    }
                                    Behavior on color {
                                        enabled: Theme.animationsEnabled
                                        ColorAnimation { duration: ClockMetrics.fadeDuration }
                                    }
                                    Behavior on border.color {
                                        enabled: Theme.animationsEnabled
                                        ColorAnimation { duration: ClockMetrics.fadeDuration }
                                    }

                                    HoverHandler { id: timerCardHover }

                                    MouseArea {
                                        id: timerCardMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ClockService.activeTimerIndex = timerCard.index
                                    }

                                    DTooltipHost {
                                        target: timerCard
                                        hoverArea: timerCardMouse
                                        text: "Click to focus on countdown"
                                    }

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: parent.parent.parent.cardPad
                                        spacing: root.isCompact ? Theme.spacingXXS : Theme.spacingXS

                                        Item {
                                            width: parent.width
                                            height: 20

                                            Row {
                                                anchors.left: parent.left
                                                anchors.right: statusBadge.left
                                                anchors.rightMargin: Theme.spacingXS
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 5

                                                DIcon {
                                                    name: timerCard.itemRunning ? "timelapse" : "hourglass_empty"
                                                    size: 14
                                                    color: timerCard.itemRunning ? Theme.primary : Theme.surfaceVariantText
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                StyledText {
                                                    text: timerCard.timerObj.label
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    font.weight: Font.DemiBold
                                                    color: Theme.surfaceText
                                                    wrapMode: Text.NoWrap
                                                    elide: Text.ElideRight
                                                    width: Math.max(0, parent.width - 20)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            StyledText {
                                                id: statusBadge
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: timerCard.itemFinished ? "Finished" : (timerCard.itemRunning ? "Running" : (timerCard.itemStarted ? "Paused" : "Ready"))
                                                font.pixelSize: Theme.fontSizeSmall - 1
                                                font.weight: Font.Medium
                                                color: timerCard.itemFinished ? Theme.error : (timerCard.itemRunning ? Theme.primary : Theme.surfaceVariantText)
                                            }
                                        }

                                        Item {
                                            width: parent.width
                                            height: 32

                                            NumericText {
                                                anchors.left: parent.left
                                                anchors.right: timerCardControls.left
                                                anchors.rightMargin: Theme.spacingXS
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: timerCard.countdownText
                                                font.pixelSize: Theme.fontSizeLarge
                                                font.weight: Font.Bold
                                                color: timerCard.itemRunning ? Theme.primary : Theme.surfaceText
                                                horizontalAlignment: Text.AlignLeft
                                                elide: Text.ElideRight
                                            }

                                            Row {
                                                id: timerCardControls
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 2

                                                DIconButton {
                                                    iconName: timerCard.itemRunning ? "pause" : "play_arrow"
                                                    variant: timerCard.itemRunning ? "filled" : "tonal"
                                                    size: "xs"
                                                    tooltipText: timerCard.itemRunning ? "Pause timer" : "Start timer"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    onClicked: ClockService.toggleTimer(timerCard.index)
                                                }

                                                Item {
                                                    readonly property bool showReset: timerCard.itemStarted || timerCard.itemRunning || timerCard.itemFinished
                                                    width: showReset ? resetTimerBtn.implicitWidth : 0
                                                    height: resetTimerBtn.implicitHeight
                                                    clip: true
                                                    opacity: showReset ? 1 : 0
                                                    enabled: showReset
                                                    anchors.verticalCenter: parent.verticalCenter

                                                    Behavior on width {
                                                        enabled: Theme.animationsEnabled
                                                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                                    }
                                                    Behavior on opacity {
                                                        enabled: Theme.animationsEnabled
                                                        NumberAnimation { duration: 150 }
                                                    }

                                                    DIconButton {
                                                        id: resetTimerBtn
                                                        iconName: "restart_alt"
                                                        variant: "standard"
                                                        size: "xs"
                                                        tooltipText: "Reset timer"
                                                        onClicked: ClockService.resetTimer(timerCard.index)
                                                    }
                                                }

                                                Item {
                                                    width: timerCardHover.hovered ? deleteTimerBtn.implicitWidth : 0
                                                    height: deleteTimerBtn.implicitHeight
                                                    clip: true
                                                    opacity: timerCardHover.hovered ? 1 : 0
                                                    anchors.verticalCenter: parent.verticalCenter

                                                    Behavior on width {
                                                        enabled: Theme.animationsEnabled
                                                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                                    }
                                                    Behavior on opacity {
                                                        enabled: Theme.animationsEnabled
                                                        NumberAnimation { duration: 150 }
                                                    }

                                                    DIconButton {
                                                        id: deleteTimerBtn
                                                        iconName: "delete_outline"
                                                        variant: "standard"
                                                        size: "xs"
                                                        iconColor: Theme.error
                                                        tooltipText: "Delete timer"
                                                        onClicked: ClockService.removeTimer(timerCard.index)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Full-width Add Timer Card (30% panel width) outside the regular timer grid
                        Rectangle {
                            id: addTimerCard
                            width: parent.width
                            height: parent.cardHeight
                            radius: Theme.cornerRadiusXL
                            scale: addTimerMouse.pressed ? 0.98 : 1.0
                            color: addTimerHover.hovered ? Theme.withAlpha(Theme.primary, 0.14) : Theme.foregroundColor(Theme.surfaceContainerLow, true)
                            border.width: addTimerHover.hovered ? 1.5 : 1
                            border.color: addTimerHover.hovered ? Theme.primary : Theme.outlineVariant

                            Behavior on scale {
                                enabled: Theme.animationsEnabled
                                NumberAnimation { duration: ClockMetrics.transitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: ClockMetrics.curveFastSpatial }
                            }
                            Behavior on color {
                                enabled: Theme.animationsEnabled
                                ColorAnimation { duration: ClockMetrics.fadeDuration }
                            }

                            HoverHandler { id: addTimerHover }

                            MouseArea {
                                id: addTimerMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ClockService.newTimerModalOpen = true
                            }

                            DTooltipHost {
                                target: addTimerCard
                                hoverArea: addTimerMouse
                                text: "Create a custom timer"
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: parent.parent.cardPad
                                spacing: root.isCompact ? Theme.spacingXXS : Theme.spacingXS

                                Item {
                                    width: parent.width
                                    height: 20

                                    Row {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 5

                                        DIcon {
                                            name: "more_time"
                                            size: 14
                                            color: addTimerHover.hovered ? Theme.primary : Theme.surfaceVariantText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: "New Timer"
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.DemiBold
                                            color: addTimerHover.hovered ? Theme.primary : Theme.surfaceText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    StyledText {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Add"
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        font.weight: Font.Medium
                                        color: Theme.primary
                                    }
                                }

                                Item {
                                    width: parent.width
                                    height: 32

                                    NumericText {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "00:00"
                                        font.pixelSize: Theme.fontSizeLarge
                                        font.weight: Font.Bold
                                        color: addTimerHover.hovered ? Theme.primary : Theme.surfaceVariantText
                                    }

                                    DIcon {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: "add"
                                        size: Theme.iconSizeSmall
                                        color: Theme.primary
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
