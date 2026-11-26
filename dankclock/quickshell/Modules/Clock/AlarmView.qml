pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets

Item {
    id: root

    anchors.fill: parent

    // Drag preview state: the model is only reordered on release so delegates survive the gesture.
    property int draggingAlarmIndex: -1
    property int dropTargetAlarmIndex: -1

    // Slot an alarm is shown in while another alarm is being dragged over the grid.
    function previewSlot(i) {
        const from = draggingAlarmIndex;
        const to = dropTargetAlarmIndex;
        if (from < 0 || to < 0 || i === from)
            return i;
        if (from < to && i > from && i <= to)
            return i - 1;
        if (from > to && i >= to && i < from)
            return i + 1;
        return i;
    }

    readonly property var dayItems: [
        { key: "Sun", letter: "S" },
        { key: "Mon", letter: "M" },
        { key: "Tue", letter: "T" },
        { key: "Wed", letter: "W" },
        { key: "Thu", letter: "T" },
        { key: "Fri", letter: "F" },
        { key: "Sat", letter: "S" }
    ]

    readonly property var repeatPresets: [
        { label: "Weekdays", days: ["Mon", "Tue", "Wed", "Thu", "Fri"] },
        { label: "Weekends", days: ["Sat", "Sun"] },
        { label: "Every day", days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"] },
        { label: "One-time", days: [] }
    ]

    DFlickable {
        id: flickable
        anchors.fill: parent
        clip: true
        interactive: root.draggingAlarmIndex < 0
        contentWidth: width
        contentHeight: contentCol.height + ClockMetrics.pagePaddingV + Theme.spacingXL * 4

        Column {
            id: contentCol
            topPadding: (SettingsData.density === "spacious") ? Theme.spacingXL : ((SettingsData.density === "compact" || SettingsData.density === "dense") ? Theme.spacingS : Theme.spacingL)
            width: parent.width - ((SettingsData.density === "spacious") ? Theme.spacingXL * 2 : Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: gridContainer.gap

            // Vacation Mode Banner (moved to ClockWindow so it shows in all modes)
            DCard {
                id: vacationBanner
                visible: false
                width: parent.width
                height: vacationInner.implicitHeight + pad * 2
                pad: Theme.spacingM
                tone: "tertiary"
                clickable: true
                restRadius: Theme.cornerRadiusXL
                bodyRadius: ClockMetrics.cardRadius(focusTarget.pressed, focusTarget.hovered, false)
                onClicked: ClockService.vacationSheetOpen = true

                Row {
                    id: vacationInner
                    width: parent.width
                    spacing: Theme.spacingM

                    Rectangle {
                        width: 48
                        height: 48
                        radius: Theme.cornerRadiusXL
                        color: Theme.tertiary
                        anchors.verticalCenter: parent.verticalCenter

                        DIcon {
                            anchors.centerIn: parent
                            name: "beach_access"
                            size: Theme.iconSize
                            color: Theme.onTertiary
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        width: Math.max(0, parent.width - 48 - Theme.spacingM - (vacationActionsRow.visible ? vacationActionsRow.width + Theme.spacingM : 0))

                        Row {
                            spacing: Theme.spacingS
                            DBadge {
                                text: "VACATION MODE"
                                color: Theme.tertiary
                                textColor: Theme.onTertiary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText {
                                text: ClockService.formatVacationRange(ClockService.vacation)
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeightBold
                                color: vacationBanner.contentColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        StyledText {
                            text: "All alarms are silenced during your vacation"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Theme.fontWeightBold
                            color: vacationBanner.contentColor
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    Row {
                        id: vacationActionsRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        DButton {
                            text: "Adjust"
                            iconName: "edit"
                            buttonHeight: Theme.buttonHeightXS
                            backgroundColor: Theme.surfaceContainerHighest
                            textColor: Theme.surfaceText
                            onClicked: ClockService.vacationSheetOpen = true
                        }

                        DButton {
                            text: "Turn Off"
                            iconName: "close"
                            buttonHeight: Theme.buttonHeightXS
                            backgroundColor: Theme.errorContainer
                            textColor: Theme.onErrorContainer
                            onClicked: ClockService.disableVacationMode()
                        }
                    }
                }
            }

            // Incoming Alarm Notice Banner (Android Clock M3E Expressive Hero)
            DCard {
                id: incomingCard
                visible: ClockService.nextIncomingAlarm !== null
                width: parent.width
                height: incomingInner.implicitHeight + pad * 2
                pad: Theme.spacingM
                tone: "primary"
                clickable: true
                restRadius: Theme.cornerRadiusXL
                bodyRadius: ClockMetrics.cardRadius(focusTarget.pressed, focusTarget.hovered, false)
                onClicked: {
                    const inc = ClockService.nextIncomingAlarm;
                    if (inc)
                        ClockService.openEditAlarmPicker(inc.index);
                }

                Row {
                    id: incomingInner
                    width: parent.width
                    spacing: Theme.spacingM

                    Rectangle {
                        width: 48
                        height: 48
                        radius: Theme.cornerRadiusXL
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter

                        DIcon {
                            anchors.centerIn: parent
                            name: (ClockService.nextIncomingAlarm && ClockService.nextIncomingAlarm.alarm.soundId === "silent") ? "notifications_off" : "notifications_active"
                            size: Theme.iconSize
                            color: Theme.onPrimary
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        width: Math.max(0, parent.width - 48 - Theme.spacingM - (bannerActionsRow.visible ? bannerActionsRow.width + Theme.spacingM : 0))

                        Row {
                            spacing: Theme.spacingS
                            DBadge {
                                text: "NEXT ALARM"
                                color: Theme.primary
                                textColor: Theme.onPrimary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText {
                                readonly property var inc: ClockService.nextIncomingAlarm
                                text: inc ? inc.relativeText : ""
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeightBold
                                color: incomingCard.contentColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        StyledText {
                            readonly property var inc: ClockService.nextIncomingAlarm
                            text: inc ? `${inc.timeText}  •  ${inc.alarm.label || "Alarm"} (${inc.dayRelation})` : ""
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Theme.fontWeightBold
                            color: incomingCard.contentColor
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    Row {
                        id: bannerActionsRow
                        visible: ClockService.nextIncomingAlarm !== null
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        Rectangle {
                            id: skipNextBtn
                            width: skipNextRow.implicitWidth + Theme.spacingM * 2
                            height: 34
                            radius: skipNextMouse.containsMouse ? height / 2 : (Theme.cornerRadiusS ?? 8)
                            color: skipNextMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.2) : Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: skipNextMouse.containsMouse ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                            scale: skipNextMouse.pressed ? 0.95 : (skipNextMouse.containsMouse ? 1.04 : 1.0)
                            clip: true

                            Behavior on radius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: ClockMetrics.fadeDuration } }
                            Behavior on border.color { enabled: Theme.animationsEnabled; ColorAnimation { duration: ClockMetrics.fadeDuration } }

                            DRipple { id: skipNextRipple; anchors.fill: parent; rippleColor: Theme.primary }

                            Row {
                                id: skipNextRow
                                anchors.centerIn: parent
                                spacing: 6

                                DIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "event_busy"
                                    size: 16
                                    color: skipNextMouse.containsMouse ? Theme.primary : Theme.surfaceText
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Skip next"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: skipNextMouse.containsMouse ? Theme.primary : Theme.surfaceText
                                }
                            }

                            MouseArea {
                                id: skipNextMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => skipNextRipple.trigger(mouse.x, mouse.y)
                                onClicked: {
                                    const inc = ClockService.nextIncomingAlarm;
                                    if (inc)
                                        ClockService.skipAlarmOnce(inc.index);
                                }
                            }
                        }
                    }
                }
            }

            // Empty State
            ClockEmptyState {
                visible: ClockService.alarms.length === 0
                cardHeight: 220
                iconName: "alarm_off"
                iconSize: Theme.iconButtonSize
                title: "No Alarms Configured"
                subtitle: "Click New Alarm below to schedule a wake-up or reminder."
            }

            // Responsive Alarm Grid (Android Clock Expandable Cards with Progressive Disclosure)
            Item {
                id: gridContainer
                visible: ClockService.alarms.length > 0
                width: parent.width
                implicitHeight: alarmGrid.implicitHeight

                readonly property string densityMode: SettingsData.density || "comfortable"
                readonly property bool isSpacious: densityMode === "spacious"
                readonly property bool isCompact: densityMode === "compact" || densityMode === "dense"
                readonly property real minCardWidth: isSpacious ? 420 : (isCompact ? 300 : 360)
                readonly property real gap: isSpacious ? Theme.spacingL : (isCompact ? Theme.spacingS : Theme.spacingM)
                readonly property int columns: Math.max(1, Math.floor((width + gap) / (minCardWidth + gap)))
                readonly property real cardWidth: Math.floor((width - (columns - 1) * gap) / columns)

                Item {
                    id: alarmGrid
                    width: parent.width
                    property real spacing: gridContainer.gap
                    property real implicitHeight: 200
                    height: implicitHeight

                    onWidthChanged: relayoutTimer.restart()

                    Timer {
                        id: relayoutTimer
                        interval: 16
                        onTriggered: alarmGrid.relayout()
                    }

                    function relayout() {
                        const cols = Math.max(1, gridContainer.columns);
                        const cw = gridContainer.cardWidth;
                        const g = gridContainer.gap;
                        const colY = [];
                        const colItems = [];
                        for (let c = 0; c < cols; c++) {
                            colY.push(0);
                            colItems.push([]);
                        }

                        for (let i = 0; i < alarmRepeater.count; i++) {
                            const it = alarmRepeater.itemAt(i);
                            if (!it) continue;
                            let bestCol = 0;
                            for (let c = 1; c < cols; c++) {
                                if (colY[c] < colY[bestCol]) bestCol = c;
                            }
                            const nx = bestCol * (cw + g);
                            const ny = colY[bestCol];
                            if (Math.abs(it.x - nx) > 0.5) it.x = nx;
                            if (Math.abs(it.y - ny) > 0.5) it.y = ny;
                            colItems[bestCol].push(it);
                            colY[bestCol] += it.height + g;
                        }
                        for (let c = 0; c < cols; c++) {
                            const list = colItems[c];
                            for (let j = 0; j < list.length; j++) {
                                list[j].isFirstInCol = (j === 0);
                                list[j].isLastInCol = (j === list.length - 1);
                            }
                        }
                        let maxH = 0;
                        for (let c = 0; c < cols; c++) {
                            if (colY[c] > maxH) maxH = colY[c];
                        }
                        alarmGrid.implicitHeight = Math.max(0, maxH - g);
                    }

                    Repeater {
                        id: alarmRepeater
                        model: ClockService.alarms
                        onCountChanged: relayoutTimer.restart()

                        // Index of the slot whose resting rect contains the grid point, or -1.
                        function slotAt(px, py) {
                            for (let i = 0; i < count; i++) {
                                const it = itemAt(i);
                                if (it && px >= it.x && px < it.x + it.width + alarmGrid.spacing && py >= it.y && py < it.y + it.height + alarmGrid.spacing)
                                    return i;
                            }
                            return -1;
                        }

                        Rectangle {
                            id: alarmCard
                            required property int index

                            onHeightChanged: relayoutTimer.restart()
                            Component.onCompleted: relayoutTimer.restart()

                            Behavior on x { enabled: Theme.animationsEnabled && root.draggingAlarmIndex < 0; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                            Behavior on y { enabled: Theme.animationsEnabled && root.draggingAlarmIndex < 0; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                            readonly property var alarmObj: {
                                void ClockService.alarmRevision;
                                return ClockService.alarms[index] || {
                                    hour: 7,
                                    minute: 0,
                                    label: "Alarm",
                                    enabled: false,
                                    days: [],
                                    soundId: "classic",
                                    snoozeMin: 10,
                                    volume: 100,
                                    deleteAfterGoesOff: false,
                                    skippedDateKey: ""
                                };
                            }
                            readonly property bool isEnabled: {
                                void ClockService.alarmRevision;
                                return Boolean(alarmObj.enabled);
                            }
                            readonly property bool isExpanded: ClockService.expandedAlarmIndex === index
                            readonly property bool isEditingLabel: ClockService.editingLabelAlarmIndex === index
                            readonly property bool isEditingThis: (ClockService.timePickerOpen && ClockService.editingAlarmIndex === index)
                                || isEditingLabel
                            readonly property bool cardHovered: cardHover.hovered || isEditingThis
                            readonly property var timeParts: {
                                void ClockService.alarmRevision;
                                return ClockService.formatClockParts(alarmObj.hour, alarmObj.minute);
                            }
                            readonly property string hmText: timeParts.timeText
                            readonly property string ampmText: timeParts.meridiem
                            readonly property string labelStr: {
                                void ClockService.alarmRevision;
                                return alarmObj.label || "Alarm";
                            }
                            readonly property var alarmDays: {
                                void ClockService.alarmRevision;
                                return alarmObj.days || [];
                            }
                            readonly property string scheduleSummary: {
                                void ClockService.alarmRevision;
                                return ClockService.formatAlarmSchedule(alarmDays);
                            }
                            readonly property var nextInfo: {
                                void ClockService.alarmRevision;
                                void ClockService.now;
                                return ClockService.getAlarmNextInfo(index);
                            }
                            readonly property bool isSkippedNext: {
                                void ClockService.alarmRevision;
                                void ClockService.now;
                                return ClockService.isAlarmSkippedNext(index);
                            }
                            readonly property string soundId: {
                                void ClockService.alarmRevision;
                                return alarmObj.soundId || "classic";
                            }
                            readonly property var soundInfo: {
                                void ClockService.alarmRevision;
                                return ClockService.getSoundInfo(soundId);
                            }
                            readonly property int snoozeMin: {
                                void ClockService.alarmRevision;
                                return alarmObj.snoozeMin || 10;
                            }
                            readonly property int volume: {
                                void ClockService.alarmRevision;
                                return typeof alarmObj.volume === "number" ? alarmObj.volume : 100;
                            }
                            readonly property bool deleteAfterGoesOff: {
                                void ClockService.alarmRevision;
                                return Boolean(alarmObj.deleteAfterGoesOff);
                            }
                            readonly property string pauseStartDate: {
                                void ClockService.alarmRevision;
                                return alarmObj.pauseStartDate || "";
                            }
                            readonly property string pauseEndDate: {
                                void ClockService.alarmRevision;
                                return alarmObj.pauseEndDate || "";
                            }
                            readonly property bool isPausedRange: pauseStartDate !== "" && pauseEndDate !== "" && ClockService._todayDateKey() <= pauseEndDate
                            readonly property bool isBeingDragged: root.draggingAlarmIndex === index
                            property real dragDx: 0
                            property real dragDy: 0
                            property real shiftX: {
                                const s = root.previewSlot(index);
                                const a = s !== index ? alarmRepeater.itemAt(s) : null;
                                return a ? a.x - x : 0;
                            }
                            property real shiftY: {
                                const s = root.previewSlot(index);
                                const a = s !== index ? alarmRepeater.itemAt(s) : null;
                                return a ? a.y - y : 0;
                            }

                            Behavior on shiftX {
                                enabled: Theme.animationsEnabled
                                NumberAnimation { duration: ClockMetrics.transitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: ClockMetrics.curveFastSpatial }
                            }
                            Behavior on shiftY {
                                enabled: Theme.animationsEnabled
                                NumberAnimation { duration: ClockMetrics.transitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: ClockMetrics.curveFastSpatial }
                            }

                            transform: Translate {
                                x: alarmCard.isBeingDragged ? alarmCard.dragDx : alarmCard.shiftX
                                y: alarmCard.isBeingDragged ? alarmCard.dragDy : alarmCard.shiftY
                            }

                            property bool isFirstInCol: true
                            property bool isLastInCol: true
                            readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                            readonly property real innerR: Theme.groupedListInnerRadius ?? 4
                            readonly property real activeR: Theme.cornerRadiusXL
                            readonly property bool separateRounded: isEnabled || isExpanded || cardHovered || isBeingDragged
                            property real topCardRadius: timeTapArea.pressed ? Theme.cornerRadiusM : (separateRounded ? activeR : (isFirstInCol ? outerR : innerR))
                            property real bottomCardRadius: timeTapArea.pressed ? Theme.cornerRadiusM : (separateRounded ? activeR : (isLastInCol ? outerR : innerR))

                            readonly property real cardPad: gridContainer.isSpacious ? Theme.spacingXL : (gridContainer.isCompact ? Theme.spacingM : Theme.spacingL)
                            width: gridContainer.cardWidth
                            height: cardCol.implicitHeight + cardPad * 2
                            clip: true
                            scale: isBeingDragged ? 1.04 : (alarmCardDragArea.pressed && alarmCardDragArea.dragIntentEstablished ? 0.98 : 1.0)
                            z: isBeingDragged ? 100 : 1
                            topLeftRadius: topCardRadius
                            topRightRadius: topCardRadius
                            bottomLeftRadius: bottomCardRadius
                            bottomRightRadius: bottomCardRadius
                            color: {
                                if (isBeingDragged)
                                    return Theme.blend(Theme.surfaceContainerHighest, Theme.primary, Theme.stateLayerDrag);
                                if (isEnabled)
                                    return (cardHovered || isExpanded) ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh;
                                return (cardHovered || isExpanded) ? Theme.surfaceContainer : Theme.surfaceContainerLow;
                            }
                            border.width: isExpanded ? Theme.outlineWidthFocused : Theme.layerOutlineWidth
                            border.color: {
                                if (isExpanded)
                                    return Theme.withAlpha(Theme.primary, 0.65);
                                if (cardHovered)
                                    return isEnabled ? Theme.primary : Theme.outline;
                                return isEnabled ? Theme.outlineMedium : Theme.outlineLight;
                            }

                            Behavior on scale {
                                enabled: Theme.animationsEnabled
                                NumberAnimation {
                                    duration: ClockMetrics.transitionDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: ClockMetrics.curveFastSpatial
                                }
                            }

                            Behavior on height {
                                enabled: Theme.animationsEnabled
                                NumberAnimation {
                                    duration: ClockMetrics.transitionDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: ClockMetrics.curveFastSpatial
                                }
                            }

                            Behavior on topCardRadius {
                                enabled: Theme.animationsEnabled
                                NumberAnimation {
                                    duration: ClockMetrics.transitionDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: ClockMetrics.curveFastSpatial
                                }
                            }

                            Behavior on bottomCardRadius {
                                enabled: Theme.animationsEnabled
                                NumberAnimation {
                                    duration: ClockMetrics.transitionDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: ClockMetrics.curveFastSpatial
                                }
                            }

                            Behavior on color {
                                enabled: Theme.animationsEnabled
                                ColorAnimation {
                                    duration: ClockMetrics.fadeDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: ClockMetrics.curveEffects
                                }
                            }

                            Behavior on border.color {
                                enabled: Theme.animationsEnabled
                                ColorAnimation {
                                    duration: ClockMetrics.fadeDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: ClockMetrics.curveEffects
                                }
                            }

                            HoverHandler {
                                id: cardHover
                            }

                            // Hold-and-drag to reorder (deferred commit on release), or click to toggle expanded options
                            MouseArea {
                                id: alarmCardDragArea
                                anchors.fill: parent
                                preventStealing: dragIntentEstablished
                                cursorShape: dragIntentEstablished ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                readonly property real dragThreshold: 10
                                property point pressGridPos: Qt.point(0, 0)
                                property bool dragIntentEstablished: false

                                function beginDrag() {
                                    dragIntentEstablished = true;
                                    root.draggingAlarmIndex = alarmCard.index;
                                    root.dropTargetAlarmIndex = alarmCard.index;
                                }

                                function endDrag(commit) {
                                    const from = root.draggingAlarmIndex;
                                    const to = root.dropTargetAlarmIndex;
                                    alarmCard.dragDx = 0;
                                    alarmCard.dragDy = 0;
                                    dragIntentEstablished = false;
                                    root.draggingAlarmIndex = -1;
                                    root.dropTargetAlarmIndex = -1;
                                    if (commit && from >= 0 && to >= 0 && from !== to)
                                        Qt.callLater(() => ClockService.moveAlarm(from, to));
                                }

                                onPressAndHold: beginDrag()

                                onPressed: mouse => {
                                    if (ClockService.editingLabelAlarmIndex >= 0)
                                        alarmCard.forceActiveFocus();
                                    pressGridPos = mapToItem(alarmGrid, mouse.x, mouse.y);
                                    dragIntentEstablished = false;
                                }

                                onPositionChanged: mouse => {
                                    if (!pressed)
                                        return;
                                    // Grid coordinates include the card's Translate, so the delta never feeds back on itself.
                                    const p = mapToItem(alarmGrid, mouse.x, mouse.y);
                                    const dx = p.x - pressGridPos.x;
                                    const dy = p.y - pressGridPos.y;
                                    if (!dragIntentEstablished) {
                                        if (Math.abs(dx) <= dragThreshold && Math.abs(dy) <= dragThreshold)
                                            return;
                                        beginDrag();
                                    }
                                    alarmCard.dragDx = dx;
                                    alarmCard.dragDy = dy;
                                    const target = alarmRepeater.slotAt(p.x, p.y);
                                    if (target >= 0)
                                        root.dropTargetAlarmIndex = target;
                                }

                                onReleased: {
                                    const wasDrag = dragIntentEstablished;
                                    endDrag(true);
                                    if (!wasDrag)
                                        ClockService.expandedAlarmIndex = alarmCard.isExpanded ? -1 : alarmCard.index;
                                }

                                onCanceled: endDrag(false)
                            }

                            DTooltipHost {
                                target: alarmCard
                                hoverArea: alarmCardDragArea
                                text: "Hold and drag to reorder alarm • Click to customize"
                            }

                            Column {
                                id: cardCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: alarmCard.cardPad
                                spacing: gridContainer.isSpacious ? Theme.spacingM : (gridContainer.isCompact ? Theme.spacingXXS : Theme.spacingXS)

                                // Collapsed Row 1: Label Pill (Left) + Expand Chevron (Right)
                                Item {
                                    width: parent.width
                                    height: 28

                                    Rectangle {
                                        id: labelPill
                                        x: -Theme.spacingS
                                        width: alarmCard.isEditingLabel
                                            ? Math.max(80, parent.width - rightMetaRow.width - Theme.spacingS)
                                            : Math.min(parent.width - rightMetaRow.width - Theme.spacingS, labelInnerRow.implicitWidth + Theme.spacingS * 2)
                                        height: 28
                                        radius: 14
                                        color: alarmCard.isEditingLabel
                                            ? Theme.surfaceContainerLowest
                                            : (labelMouse.pressed
                                                ? Theme.withAlpha(Theme.primary, 0.22)
                                                : (labelMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, Theme.stateLayerHover) : "transparent"))
                                        border.width: alarmCard.isEditingLabel ? 1 : 0
                                        border.color: alarmCard.isEditingLabel ? Theme.primary : "transparent"

                                        Behavior on color {
                                            enabled: Theme.animationsEnabled
                                            ColorAnimation { duration: ClockMetrics.fadeDuration }
                                        }
                                    }

                                    Row {
                                        id: labelInnerRow
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        DIcon {
                                            name: "label"
                                            size: Theme.iconSizeSmall
                                            color: (alarmCard.isEditingLabel || labelMouse.containsMouse) ? Theme.primary : (alarmCard.isEnabled ? Theme.surfaceVariantText : Theme.withAlpha(Theme.surfaceVariantText, 0.5))
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            id: labelText
                                            visible: !alarmCard.isEditingLabel
                                            width: Math.min(alarmCard.width - rightMetaRow.width - Theme.spacingL * 2 - 44, implicitWidth)
                                            elide: Text.ElideRight
                                            text: alarmCard.labelStr
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Theme.fontWeightMedium
                                            color: labelMouse.containsMouse ? Theme.surfaceText : (alarmCard.isEnabled ? Theme.surfaceVariantText : Theme.withAlpha(Theme.surfaceVariantText, 0.6))
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        TextInput {
                                            id: labelInput
                                            visible: alarmCard.isEditingLabel
                                            width: Math.max(48, labelPill.width - Theme.spacingS * 2 - Theme.iconSizeSmall - 6)
                                            height: 24
                                            anchors.verticalCenter: parent.verticalCenter
                                            verticalAlignment: TextInput.AlignVCenter
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Theme.fontWeightMedium
                                            color: Theme.surfaceText
                                            selectionColor: Theme.withAlpha(Theme.primary, 0.3)
                                            selectedTextColor: Theme.surfaceText
                                            clip: true
                                            selectByMouse: true

                                            function commitEdit() {
                                                if (ClockService.editingLabelAlarmIndex !== alarmCard.index)
                                                    return;
                                                ClockService.updateAlarmLabel(alarmCard.index, text);
                                                ClockService.editingLabelAlarmIndex = -1;
                                            }

                                            function cancelEdit() {
                                                if (ClockService.editingLabelAlarmIndex !== alarmCard.index)
                                                    return;
                                                ClockService.editingLabelAlarmIndex = -1;
                                            }

                                            onActiveFocusChanged: {
                                                if (!activeFocus && alarmCard.isEditingLabel)
                                                    commitEdit();
                                            }

                                            Keys.onReturnPressed: commitEdit()
                                            Keys.onEnterPressed: commitEdit()
                                            Keys.onEscapePressed: event => {
                                                cancelEdit();
                                                event.accepted = true;
                                            }
                                        }

                                        DIcon {
                                            visible: !alarmCard.isEditingLabel && labelMouse.containsMouse
                                            name: "edit"
                                            size: Theme.iconSizeSmall
                                            color: Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: labelMouse
                                        anchors.fill: labelPill
                                        enabled: !alarmCard.isEditingLabel
                                        hoverEnabled: true
                                        cursorShape: alarmCard.isEditingLabel ? Qt.IBeamCursor : Qt.PointingHandCursor
                                        onClicked: {
                                            ClockService.editingLabelAlarmIndex = alarmCard.index;
                                            labelInput.text = alarmCard.labelStr;
                                            labelInput.forceActiveFocus();
                                            labelInput.selectAll();
                                        }
                                    }

                                    DTooltipHost {
                                        target: labelPill
                                        hoverArea: labelMouse
                                        text: alarmCard.isEditingLabel ? "" : "Edit alarm label"
                                    }

                                    // Right Meta: Silent indicator / Skipped indicator / Vacation indicator + Expand/Collapse Chevron
                                    Row {
                                        id: rightMetaRow
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        DIcon {
                                            visible: alarmCard.soundId === "silent"
                                            name: "notifications_off"
                                            size: 16
                                            color: alarmCard.isEnabled ? Theme.surfaceVariantText : Theme.withAlpha(Theme.surfaceVariantText, 0.5)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        DBadge {
                                            visible: ClockService.isVacationActive && alarmCard.isEnabled
                                            text: "Vacation"
                                            color: Theme.withAlpha(Theme.tertiary, 0.22)
                                            textColor: Theme.tertiary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        DBadge {
                                            visible: alarmCard.isPausedRange && !ClockService.isVacationActive
                                            text: "Paused"
                                            color: Theme.withAlpha(Theme.warning, 0.2)
                                            textColor: Theme.warning
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        DBadge {
                                            visible: alarmCard.isSkippedNext && !ClockService.isVacationActive
                                            text: "Skipped once"
                                            color: Theme.withAlpha(Theme.error, 0.18)
                                            textColor: Theme.error
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        DActionButton {
                                            id: expandBtn
                                            buttonSize: Theme.buttonHeightXXS
                                            iconName: "expand_more"
                                            iconSize: Theme.chipIconSize
                                            rotation: alarmCard.isExpanded ? 180 : 0
                                            Behavior on rotation { enabled: Theme.animationsEnabled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                            iconColor: alarmCard.isExpanded ? Theme.primary : Theme.surfaceVariantText
                                            backgroundColor: alarmCard.isExpanded
                                                ? Theme.withAlpha(Theme.primary, 0.16)
                                                : Theme.withAlpha(Theme.surfaceVariant, 0.25)
                                            tooltipText: alarmCard.isExpanded ? "Collapse options" : "Customize alarm"
                                            anchors.verticalCenter: parent.verticalCenter
                                            onClicked: ClockService.expandedAlarmIndex = alarmCard.isExpanded ? -1 : alarmCard.index
                                        }
                                    }
                                }

                                // Collapsed Row 2 (and Segmented Group 1 when expanded): Big Time + Toggle, followed by Rings-in line
                                Column {
                                    id: timeSummaryGroup
                                    width: parent.width
                                    spacing: alarmCard.isExpanded ? 2 : 0

                                    readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                                    readonly property real innerR: Theme.groupedListInnerRadius ?? 4
                                    readonly property real hoverR: outerR + 3

                                    Rectangle {
                                        id: timeSegment
                                        width: parent.width
                                        height: alarmCard.isExpanded ? (gridContainer.isSpacious ? 64 : (gridContainer.isCompact ? 54 : 58)) : 50
                                        readonly property bool hovered: alarmCard.isExpanded && timeSegHover.hovered
                                        topLeftRadius: alarmCard.isExpanded ? (hovered ? timeSummaryGroup.hoverR : timeSummaryGroup.outerR) : 0
                                        topRightRadius: alarmCard.isExpanded ? (hovered ? timeSummaryGroup.hoverR : timeSummaryGroup.outerR) : 0
                                        bottomLeftRadius: alarmCard.isExpanded ? (hovered ? timeSummaryGroup.hoverR : timeSummaryGroup.innerR) : 0
                                        bottomRightRadius: alarmCard.isExpanded ? (hovered ? timeSummaryGroup.hoverR : timeSummaryGroup.innerR) : 0
                                        color: alarmCard.isExpanded ? Theme.surfaceContainerHigh : "transparent"
                                        border.width: alarmCard.isExpanded ? 1 : 0
                                        border.color: alarmCard.isExpanded ? (hovered ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)) : "transparent"

                                        HoverHandler { id: timeSegHover; enabled: alarmCard.isExpanded }

                                        Behavior on topLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on topRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on bottomLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on bottomRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: ClockMetrics.fadeDuration } }
                                        Behavior on border.color { enabled: Theme.animationsEnabled; ColorAnimation { duration: ClockMetrics.fadeDuration } }

                                        Item {
                                            anchors.fill: parent
                                            anchors.leftMargin: alarmCard.isExpanded ? Theme.spacingM : 0
                                            anchors.rightMargin: alarmCard.isExpanded ? Theme.spacingM : 0

                                            Rectangle {
                                                id: timeHoverPill
                                                x: -Theme.spacingS
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: timeRow.implicitWidth + Theme.spacingS * 2
                                                height: 46
                                                radius: Theme.cornerRadiusM
                                                color: Theme.surfaceText
                                                opacity: timeTapArea.pressed ? Theme.stateLayerPressed : (timeTapArea.containsMouse ? Theme.stateLayerHover : 0)

                                                Behavior on opacity {
                                                    enabled: Theme.animationsEnabled
                                                    NumberAnimation { duration: ClockMetrics.fadeDuration }
                                                }
                                            }

                                            Row {
                                                id: timeRow
                                                anchors.left: parent.left
                                                anchors.verticalCenter: timeHoverPill.verticalCenter
                                                spacing: 6

                                                NumericText {
                                                    id: hmLabel
                                                    text: alarmCard.hmText
                                                    font.pixelSize: Theme.fontSizeDisplay
                                                    font.weight: Font.Bold
                                                    color: alarmCard.isEnabled ? Theme.surfaceText : Theme.surfaceVariantText
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                StyledText {
                                                    visible: alarmCard.ampmText !== ""
                                                    text: alarmCard.ampmText
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    font.weight: Theme.fontWeightBold
                                                    color: alarmCard.isEnabled ? Theme.primary : Theme.surfaceVariantText
                                                    anchors.baseline: hmLabel.baseline
                                                }
                                            }

                                            MouseArea {
                                                id: timeTapArea
                                                anchors.fill: timeHoverPill
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: ClockService.openEditAlarmPicker(alarmCard.index)
                                            }

                                            DTooltipHost {
                                                target: timeHoverPill
                                                hoverArea: timeTapArea
                                                text: "Click to change alarm time"
                                            }

                                            Row {
                                                id: toggleControl
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: Theme.spacingXS

                                                DToggle {
                                                    hideText: true
                                                    checked: alarmCard.isEnabled
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    onToggled: isChecked => ClockService.toggleAlarm(alarmCard.index, isChecked)
                                                }
                                            }
                                        }
                                    }

                                    // Segmented Group 1 Last Row (When expanded): Schedule summary + "Rings in ..."
                                    Rectangle {
                                        id: ringsSegment
                                        visible: alarmCard.isExpanded
                                        width: parent.width
                                        height: gridContainer.isSpacious ? 42 : (gridContainer.isCompact ? 34 : 38)
                                        readonly property bool hovered: ringsSegHover.hovered
                                        topLeftRadius: hovered ? timeSummaryGroup.hoverR : timeSummaryGroup.innerR
                                        topRightRadius: hovered ? timeSummaryGroup.hoverR : timeSummaryGroup.innerR
                                        bottomLeftRadius: hovered ? timeSummaryGroup.hoverR : timeSummaryGroup.outerR
                                        bottomRightRadius: hovered ? timeSummaryGroup.hoverR : timeSummaryGroup.outerR
                                        color: Theme.surfaceContainerHigh
                                        border.width: 1
                                        border.color: hovered ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                                        HoverHandler { id: ringsSegHover }

                                        Behavior on topLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on topRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on bottomLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on bottomRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on border.color { enabled: Theme.animationsEnabled; ColorAnimation { duration: ClockMetrics.fadeDuration } }

                                        Item {
                                            anchors.fill: parent
                                            anchors.leftMargin: Theme.spacingM
                                            anchors.rightMargin: Theme.spacingM

                                            StyledText {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: alarmCard.scheduleSummary
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.DemiBold
                                                color: Theme.primary
                                            }

                                            StyledText {
                                                visible: alarmCard.isEnabled && alarmCard.nextInfo !== null
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: alarmCard.nextInfo ? `Rings ${alarmCard.nextInfo.relativeText}` : ""
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                            }
                                        }
                                    }
                                }

                                // Collapsed Row 3: Concise Schedule Summary ("Mon, Tue, Wed, Thu, Fri" or "Tomorrow" • "in 6h 20m")
                                // Clicking this summary row also toggles the expanded dropdown
                                Item {
                                    width: parent.width
                                    height: 22
                                    visible: !alarmCard.isExpanded

                                    Row {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        StyledText {
                                            text: alarmCard.scheduleSummary
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Medium
                                            color: alarmCard.isEnabled ? Theme.surfaceVariantText : Theme.withAlpha(Theme.surfaceVariantText, 0.5)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            visible: alarmCard.isEnabled && alarmCard.nextInfo !== null
                                            text: "•"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.withAlpha(Theme.surfaceVariantText, 0.4)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            visible: alarmCard.isEnabled && alarmCard.nextInfo !== null
                                            text: alarmCard.nextInfo ? alarmCard.nextInfo.relativeText : ""
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Medium
                                            color: Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ClockService.expandedAlarmIndex = alarmCard.index
                                    }
                                }

                                // Expanded Dropdown Drawer: All Advanced Controls (Days, Quick Presets, Sound, Snooze, Skip/Delete)
                                Column {
                                    visible: alarmCard.isExpanded
                                    width: parent.width
                                    spacing: Theme.spacingM
                                    topPadding: Theme.spacingXS

                                    // Weekday Selector Pills (S M T W T F S) inside Dropdown
                                    Column {
                                        width: parent.width
                                        spacing: 8

                                        Row {
                                            id: daysGroup
                                            width: parent.width
                                            height: gridContainer.isSpacious ? 36 : (gridContainer.isCompact ? 28 : 32)
                                            spacing: 2

                                            Repeater {
                                                model: root.dayItems

                                                Rectangle {
                                                    id: dayCircle
                                                    required property var modelData
                                                    required property int index

                                                    readonly property bool isSelected: {
                                                        void ClockService.alarmRevision;
                                                        return alarmCard.alarmDays.indexOf(modelData.key) >= 0;
                                                    }
                                                    readonly property bool isFirst: index === 0
                                                    readonly property bool isLast: index === root.dayItems.length - 1
                                                    readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                                                    readonly property real innerR: Theme.groupedListInnerRadius ?? 4

                                                    function toggleDaySelection() {
                                                        const currentDays = alarmCard.alarmDays.slice();
                                                        const pos = currentDays.indexOf(dayCircle.modelData.key);
                                                        if (pos >= 0)
                                                            currentDays.splice(pos, 1);
                                                        else
                                                            currentDays.push(dayCircle.modelData.key);
                                                        const ordered = ClockService.weekDays.filter(d => currentDays.indexOf(d) >= 0);
                                                        ClockService.updateAlarmDays(alarmCard.index, ordered);
                                                    }

                                                    width: Math.floor((daysGroup.width - daysGroup.spacing * 6) / 7)
                                                    height: daysGroup.height
                                                    topLeftRadius: (isSelected || dayMouse.containsMouse) ? outerR : (isFirst ? outerR : innerR)
                                                    bottomLeftRadius: (isSelected || dayMouse.containsMouse) ? outerR : (isFirst ? outerR : innerR)
                                                    topRightRadius: (isSelected || dayMouse.containsMouse) ? outerR : (isLast ? outerR : innerR)
                                                    bottomRightRadius: (isSelected || dayMouse.containsMouse) ? outerR : (isLast ? outerR : innerR)
                                                    scale: dayMouse.pressed ? 0.94 : (dayMouse.containsMouse ? 1.04 : 1.0)
                                                    clip: true
                                                    activeFocusOnTab: true
                                                    Accessible.role: Accessible.CheckBox
                                                    Accessible.name: modelData.key
                                                    Accessible.checkable: true
                                                    Accessible.checked: isSelected
                                                    Accessible.onPressAction: toggleDaySelection()
                                                    color: (isSelected || dayMouse.containsMouse) ? Theme.withAlpha(Theme.primary, 0.2) : Theme.surfaceContainerHigh
                                                    border.width: 1
                                                    border.color: (isSelected || dayMouse.containsMouse) ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                                                    Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                                    Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: 150 } }
                                                    Behavior on border.color { enabled: Theme.animationsEnabled; ColorAnimation { duration: 150 } }

                                                    DRipple { id: dayRipple; anchors.fill: parent; rippleColor: Theme.primary }

                                                    StyledText {
                                                        anchors.centerIn: parent
                                                        text: dayCircle.modelData.letter
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        font.weight: dayCircle.isSelected ? Font.Bold : Font.Medium
                                                        color: (dayCircle.isSelected || dayMouse.containsMouse) ? Theme.primary : Theme.surfaceText
                                                    }

                                                    MouseArea {
                                                        id: dayMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onPressed: mouse => dayRipple.trigger(mouse.x, mouse.y)
                                                        onClicked: dayCircle.toggleDaySelection()
                                                    }
                                                }
                                            }
                                        }

                                        // Quick Preset Custom Segmented Group Button (Weekdays, Weekends, Every day, One-time)
                                        Row {
                                            id: presetsGroup
                                            width: parent.width
                                            height: gridContainer.isSpacious ? 36 : (gridContainer.isCompact ? 28 : 32)
                                            spacing: 2

                                            Repeater {
                                                model: root.repeatPresets

                                                delegate: Rectangle {
                                                    required property var modelData
                                                    required property int index

                                                    readonly property bool active: modelData.label === alarmCard.scheduleSummary
                                                    readonly property bool isFirst: index === 0
                                                    readonly property bool isLast: index === root.repeatPresets.length - 1
                                                    readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                                                    readonly property real innerR: Theme.groupedListInnerRadius ?? 4

                                                    width: Math.floor((presetsGroup.width - presetsGroup.spacing * (root.repeatPresets.length - 1)) / root.repeatPresets.length)
                                                    height: presetsGroup.height
                                                    topLeftRadius: (active || rpMouse.containsMouse) ? outerR : (isFirst ? outerR : innerR)
                                                    bottomLeftRadius: (active || rpMouse.containsMouse) ? outerR : (isFirst ? outerR : innerR)
                                                    topRightRadius: (active || rpMouse.containsMouse) ? outerR : (isLast ? outerR : innerR)
                                                    bottomRightRadius: (active || rpMouse.containsMouse) ? outerR : (isLast ? outerR : innerR)
                                                    color: (active || rpMouse.containsMouse) ? Theme.withAlpha(Theme.primary, 0.2) : Theme.surfaceContainerHigh
                                                    border.width: 1
                                                    border.color: (active || rpMouse.containsMouse) ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                                                    scale: rpMouse.pressed ? 0.95 : (rpMouse.containsMouse ? 1.03 : 1.0)
                                                    clip: true

                                                    Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                                    DRipple { id: rpRipple; anchors.fill: parent; rippleColor: Theme.primary }

                                                    StyledText {
                                                        anchors.centerIn: parent
                                                        text: modelData.label
                                                        font.pixelSize: Theme.fontSizeSmall - 1
                                                        font.weight: active ? Font.DemiBold : Font.Medium
                                                        color: (active || rpMouse.containsMouse) ? Theme.primary : Theme.surfaceText
                                                    }

                                                    MouseArea {
                                                        id: rpMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onPressed: mouse => rpRipple.trigger(mouse.x, mouse.y)
                                                        onClicked: ClockService.updateAlarmDays(alarmCard.index, modelData.days.slice())
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Segmented Group 2 (Sound -> Snooze -> Volume -> Actions) matching Settings segmented UI
                                    Column {
                                        id: settingsSegmentGroup
                                        width: parent.width
                                        spacing: 2

                                        readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                                        readonly property real innerR: Theme.groupedListInnerRadius ?? 4
                                        readonly property real hoverR: outerR + 3
                                        readonly property real rowPadH: gridContainer.isSpacious ? Theme.spacingL : Theme.spacingM
                                        readonly property real rowPadV: gridContainer.isSpacious ? Theme.spacingM : (gridContainer.isCompact ? Theme.spacingXS : Theme.spacingS)

                                        // Segment 1 (First): Sound Selector Row (DDropdown)
                                        Rectangle {
                                            width: parent.width
                                            height: gridContainer.isSpacious ? 50 : (gridContainer.isCompact ? 40 : 44)
                                            readonly property bool hovered: soundSegHover.hovered
                                            topLeftRadius: hovered ? settingsSegmentGroup.hoverR : settingsSegmentGroup.outerR
                                            topRightRadius: hovered ? settingsSegmentGroup.hoverR : settingsSegmentGroup.outerR
                                            bottomLeftRadius: hovered ? settingsSegmentGroup.hoverR : settingsSegmentGroup.innerR
                                            bottomRightRadius: hovered ? settingsSegmentGroup.hoverR : settingsSegmentGroup.innerR
                                            color: Theme.surfaceContainerHigh
                                            border.width: 1
                                            border.color: hovered ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                                            HoverHandler { id: soundSegHover }

                                            Behavior on topLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on topRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on bottomLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on bottomRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on border.color { enabled: Theme.animationsEnabled; ColorAnimation { duration: ClockMetrics.fadeDuration } }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: settingsSegmentGroup.rowPadH
                                                anchors.rightMargin: Theme.spacingS
                                                spacing: Theme.spacingS

                                                DIcon {
                                                    name: "music_note"
                                                    size: 16
                                                    color: Theme.primary
                                                }

                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: "Sound"
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    font.weight: Font.Medium
                                                    color: Theme.surfaceText
                                                }

                                                DDropdown {
                                                    width: 150
                                                    enableFuzzySearch: ClockService.alarmSounds.length > ClockService.defaultAlarmSounds.length
                                                    options: ClockService.alarmSounds.map(s => s.name)
                                                    optionValues: ClockService.alarmSounds.map(s => s.id)
                                                    optionIcons: ClockService.alarmSounds.map(s => s.icon || "music_note")
                                                    currentValue: alarmCard.soundId
                                                    onValueChanged: val => {
                                                        if (val) ClockService.updateAlarmSound(alarmCard.index, val);
                                                    }
                                                }
                                            }
                                        }

                                        // Segment 2 (Middle): Snooze Duration Selector (5m, 10m, 15m, 30m)
                                        Rectangle {
                                            width: parent.width
                                            height: Math.max(gridContainer.isSpacious ? 50 : (gridContainer.isCompact ? 40 : 44), snoozeGroup.height + settingsSegmentGroup.rowPadV * 2)
                                            readonly property bool hovered: snoozeSegHover.hovered
                                            topLeftRadius: hovered ? settingsSegmentGroup.hoverR : settingsSegmentGroup.innerR
                                            topRightRadius: hovered ? settingsSegmentGroup.hoverR : settingsSegmentGroup.innerR
                                            bottomLeftRadius: hovered ? settingsSegmentGroup.hoverR : settingsSegmentGroup.innerR
                                            bottomRightRadius: hovered ? settingsSegmentGroup.hoverR : settingsSegmentGroup.innerR
                                            color: Theme.surfaceContainerHigh
                                            border.width: 1
                                            border.color: hovered ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                                            HoverHandler { id: snoozeSegHover }

                                            Behavior on topLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on topRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on bottomLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on bottomRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on border.color { enabled: Theme.animationsEnabled; ColorAnimation { duration: ClockMetrics.fadeDuration } }

                                            Item {
                                                anchors.fill: parent
                                                anchors.leftMargin: settingsSegmentGroup.rowPadH
                                                anchors.rightMargin: Theme.spacingS

                                                StyledText {
                                                    anchors.left: parent.left
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "Snooze"
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    font.weight: Font.Medium
                                                    color: Theme.surfaceText
                                                }

                                                DButtonGroup {
                                                    id: snoozeGroup
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    size: "small"
                                                    selectionMode: "single"
                                                    checkEnabled: false
                                                    minButtonWidth: 42
                                                    buttonPadding: Theme.spacingS
                                                    model: ClockService.snoozeOptions.map(m => `${m}m`)
                                                    currentIndex: Math.max(0, ClockService.snoozeOptions.indexOf(alarmCard.snoozeMin))
                                                    onSelectionChanged: (idx, sel) => {
                                                        if (sel && idx >= 0 && idx < ClockService.snoozeOptions.length)
                                                            ClockService.updateAlarmSnooze(alarmCard.index, ClockService.snoozeOptions[idx]);
                                                    }
                                                }
                                            }
                                        }

                                        // Segment 3 (Middle): Alarm Volume Slider
                                        Rectangle {
                                            width: parent.width
                                            height: volCol.implicitHeight + settingsSegmentGroup.rowPadV * 2
                                            readonly property bool hovered: volSegHover.hovered
                                            topLeftRadius: hovered ? settingsSegmentGroup.hoverR : settingsSegmentGroup.innerR
                                            topRightRadius: hovered ? settingsSegmentGroup.hoverR : settingsSegmentGroup.innerR
                                            bottomLeftRadius: hovered ? settingsSegmentGroup.hoverR : settingsSegmentGroup.innerR
                                            bottomRightRadius: hovered ? settingsSegmentGroup.hoverR : settingsSegmentGroup.innerR
                                            color: Theme.surfaceContainerHigh
                                            border.width: 1
                                            border.color: hovered ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                                            HoverHandler { id: volSegHover }

                                            Behavior on topLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on topRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on bottomLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on bottomRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on border.color { enabled: Theme.animationsEnabled; ColorAnimation { duration: ClockMetrics.fadeDuration } }

                                            Column {
                                                id: volCol
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: settingsSegmentGroup.rowPadH
                                                anchors.rightMargin: settingsSegmentGroup.rowPadH
                                                spacing: 4

                                                Item {
                                                    width: parent.width
                                                    height: 18

                                                    StyledText {
                                                        anchors.left: parent.left
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: "Volume"
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        font.weight: Font.Medium
                                                        color: Theme.surfaceText
                                                    }

                                                    NumericText {
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: `${alarmCard.volume}%`
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        font.weight: Font.Bold
                                                        color: Theme.primary
                                                    }
                                                }

                                                DSlider {
                                                    width: parent.width
                                                    size: "s"
                                                    minimum: 0
                                                    maximum: 100
                                                    step: 5
                                                    unit: "%"
                                                    startIcon: alarmCard.volume === 0 ? "volume_off" : (alarmCard.volume < 50 ? "volume_down" : "volume_up")
                                                    value: alarmCard.volume
                                                    onSliderValueChanged: v => ClockService.updateAlarmVolume(alarmCard.index, v)
                                                    onSliderDragFinished: v => ClockService.previewAlarmSound(alarmCard.soundId, v)
                                                }
                                            }
                                        }

                                        // Segment 4 (Last): Bottom Action Row (Skip Once / Delete after goes off / Duplicate / Delete)
                                        Rectangle {
                                            width: parent.width
                                            height: gridContainer.isSpacious ? 50 : (gridContainer.isCompact ? 40 : 44)
                                            readonly property bool hovered: actionsSegHover.hovered
                                            topLeftRadius: hovered ? settingsSegmentGroup.hoverR : settingsSegmentGroup.innerR
                                            topRightRadius: hovered ? settingsSegmentGroup.hoverR : settingsSegmentGroup.innerR
                                            bottomLeftRadius: hovered ? settingsSegmentGroup.hoverR : settingsSegmentGroup.outerR
                                            bottomRightRadius: hovered ? settingsSegmentGroup.hoverR : settingsSegmentGroup.outerR
                                            color: Theme.surfaceContainerHigh
                                            border.width: 1
                                            border.color: hovered ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                                            HoverHandler { id: actionsSegHover }

                                            Behavior on topLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on topRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on bottomLeftRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on bottomRightRadius { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on border.color { enabled: Theme.animationsEnabled; ColorAnimation { duration: ClockMetrics.fadeDuration } }

                                            Item {
                                                anchors.fill: parent
                                                anchors.leftMargin: settingsSegmentGroup.rowPadH
                                                anchors.rightMargin: Theme.spacingS

                                                Row {
                                                    anchors.left: parent.left
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 6

                                                    DButton {
                                                        visible: alarmCard.isEnabled && alarmCard.alarmDays.length > 0
                                                        text: alarmCard.isSkippedNext ? "Restore next" : "Skip once"
                                                        iconName: alarmCard.isSkippedNext ? "event_available" : "event_busy"
                                                        buttonHeight: Theme.buttonHeightXS
                                                        backgroundColor: alarmCard.isSkippedNext ? Theme.primaryContainer : Theme.secondaryContainer
                                                        textColor: alarmCard.isSkippedNext ? Theme.onPrimaryContainer : Theme.onSecondaryContainer
                                                        onClicked: ClockService.skipAlarmOnce(alarmCard.index)
                                                    }

                                                    DButton {
                                                        visible: alarmCard.alarmDays.length === 0
                                                        text: "Delete after goes off"
                                                        iconName: alarmCard.deleteAfterGoesOff ? "check_box" : "check_box_outline_blank"
                                                        buttonHeight: Theme.buttonHeightXS
                                                        backgroundColor: alarmCard.deleteAfterGoesOff ? Theme.primaryContainer : Theme.secondaryContainer
                                                        textColor: alarmCard.deleteAfterGoesOff ? Theme.onPrimaryContainer : Theme.onSecondaryContainer
                                                        onClicked: ClockService.updateAlarmDeleteAfter(alarmCard.index, !alarmCard.deleteAfterGoesOff)
                                                    }

                                                    DButton {
                                                        text: alarmCard.isPausedRange ? "Paused" : "Pause"
                                                        iconName: "pause_circle"
                                                        buttonHeight: Theme.buttonHeightXS
                                                        backgroundColor: alarmCard.isPausedRange ? Theme.withAlpha(Theme.warning, 0.22) : Theme.secondaryContainer
                                                        textColor: alarmCard.isPausedRange ? Theme.warning : Theme.onSecondaryContainer
                                                        onClicked: pauseCalendarPopup.openForAlarm(alarmCard.index, alarmCard.pauseStartDate, alarmCard.pauseEndDate)
                                                    }
                                                }

                                                Row {
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 4

                                                    DIconButton {
                                                        iconName: "content_copy"
                                                        variant: "standard"
                                                        size: "s"
                                                        tooltipText: "Duplicate alarm"
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        onClicked: ClockService.duplicateAlarm(alarmCard.index)
                                                    }

                                                    DIconButton {
                                                        iconName: "delete_outline"
                                                        variant: "standard"
                                                        size: "s"
                                                        iconColor: Theme.error
                                                        tooltipText: "Delete alarm"
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        onClicked: ClockService.removeAlarm(alarmCard.index)
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
            }

            // Bottom Row: Add Alarm Card + Vacation Mode Switch (matching other views)
            RowLayout {
                width: parent.width
                spacing: gridContainer.gap

                Rectangle {
                    id: addAlarmCard
                    Layout.fillWidth: true
                    height: gridContainer.isSpacious ? 76 : (gridContainer.isCompact ? 58 : 66)
                    radius: Theme.cornerRadiusXL
                    scale: addAlarmMouse.pressed ? 0.98 : 1.0
                    color: addAlarmHover.hovered ? Theme.withAlpha(Theme.primary, 0.14) : Theme.foregroundColor(Theme.surfaceContainerLow, true)
                    border.width: addAlarmHover.hovered ? 1.5 : 1
                    border.color: addAlarmHover.hovered ? Theme.primary : Theme.outlineVariant

                    Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: ClockMetrics.transitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: ClockMetrics.curveFastSpatial } }
                    Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: ClockMetrics.fadeDuration } }

                    HoverHandler { id: addAlarmHover }

                    MouseArea {
                        id: addAlarmMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ClockService.openAddAlarmPicker()
                    }

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DIcon {
                                name: "add_alarm"
                                size: Theme.iconSizeSmall
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: "New Alarm"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.DemiBold
                                color: addAlarmHover.hovered ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        DIcon {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            name: "add"
                            size: Theme.iconSize
                            color: Theme.primary
                        }
                    }
                }

                Rectangle {
                    id: vacSwitchCard
                    Layout.preferredWidth: vacRow.implicitWidth + Theme.spacingXL * 2
                    height: addAlarmCard.height
                    radius: Theme.cornerRadiusXL
                    readonly property bool isActive: ClockService.isVacationActive || ClockService.vacationSheetOpen
                    color: (isActive || vacHover.hovered) ? Theme.withAlpha(Theme.primary, 0.18) : Theme.foregroundColor(Theme.surfaceContainerLow, true)
                    border.width: (isActive || vacHover.hovered) ? 1.5 : 1
                    border.color: (isActive || vacHover.hovered) ? Theme.primary : Theme.outlineVariant
                    scale: vacMouse.pressed ? 0.98 : 1.0

                    Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: ClockMetrics.transitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: ClockMetrics.curveFastSpatial } }
                    Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: ClockMetrics.fadeDuration } }

                    HoverHandler { id: vacHover }

                    MouseArea {
                        id: vacMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ClockService.vacationSheetOpen = !ClockService.vacationSheetOpen
                    }

                    Row {
                        id: vacRow
                        anchors.centerIn: parent
                        spacing: Theme.spacingS

                        DIcon {
                            name: "beach_access"
                            size: Theme.iconSizeSmall
                            color: (vacSwitchCard.isActive || vacHover.hovered) ? Theme.primary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: ClockService.isVacationActive ? "Vacation On" : "Vacation"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.DemiBold
                            color: (vacSwitchCard.isActive || vacHover.hovered) ? Theme.primary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }

    // Per-Alarm Pause Date Range Calendar Popup
    Popup {
        id: pauseCalendarPopup
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 330
        height: 380
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: Theme.spacingM
        background: Rectangle {
            radius: Theme.cornerRadiusXL
            color: Theme.surfaceContainerHigh
            border.width: 1
            border.color: Theme.outlineMedium
        }

        property int targetAlarmIndex: -1
        property string startKey: ""
        property string endKey: ""
        property int viewYear: (ClockService.now || new Date()).getFullYear()
        property int viewMonth: (ClockService.now || new Date()).getMonth()

        function openForAlarm(idx, s, e) {
            targetAlarmIndex = idx;
            startKey = s || "";
            endKey = e || "";
            open();
        }

        Column {
            anchors.fill: parent
            spacing: Theme.spacingS

            StyledText {
                width: parent.width
                text: pauseCalendarPopup.startKey === ""
                    ? "Select pause start date"
                    : (pauseCalendarPopup.endKey === "" ? `Start: ${pauseCalendarPopup.startKey} • Pick end date` : `Paused: ${pauseCalendarPopup.startKey} → ${pauseCalendarPopup.endKey}`)
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.primary
                horizontalAlignment: Text.AlignHCenter
            }

            Row {
                width: parent.width
                height: 32

                DIconButton {
                    iconName: "chevron_left"
                    variant: "standard"
                    size: "s"
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: {
                        if (pauseCalendarPopup.viewMonth === 0) {
                            pauseCalendarPopup.viewMonth = 11;
                            pauseCalendarPopup.viewYear--;
                        } else {
                            pauseCalendarPopup.viewMonth--;
                        }
                    }
                }

                StyledText {
                    width: parent.width - 72
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(new Date(pauseCalendarPopup.viewYear, pauseCalendarPopup.viewMonth, 1), "MMMM yyyy")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    color: Theme.surfaceText
                }

                DIconButton {
                    iconName: "chevron_right"
                    variant: "standard"
                    size: "s"
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: {
                        if (pauseCalendarPopup.viewMonth === 11) {
                            pauseCalendarPopup.viewMonth = 0;
                            pauseCalendarPopup.viewYear++;
                        } else {
                            pauseCalendarPopup.viewMonth++;
                        }
                    }
                }
            }

            DMonthGrid {
                width: parent.width
                height: parent.height - 104
                displayDate: new Date(pauseCalendarPopup.viewYear, pauseCalendarPopup.viewMonth, 1)
                dotColorsFor: date => {
                    const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
                    if (pauseCalendarPopup.startKey !== "" && pauseCalendarPopup.endKey !== "" && key >= pauseCalendarPopup.startKey && key <= pauseCalendarPopup.endKey)
                        return [Theme.warning];
                    if (key === pauseCalendarPopup.startKey)
                        return [Theme.primary];
                    return [];
                }
                onDayClicked: date => {
                    const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
                    if (pauseCalendarPopup.startKey === "" || (pauseCalendarPopup.startKey !== "" && pauseCalendarPopup.endKey !== "")) {
                        pauseCalendarPopup.startKey = key;
                        pauseCalendarPopup.endKey = "";
                    } else {
                        if (key < pauseCalendarPopup.startKey) {
                            pauseCalendarPopup.endKey = pauseCalendarPopup.startKey;
                            pauseCalendarPopup.startKey = key;
                        } else {
                            pauseCalendarPopup.endKey = key;
                        }
                        ClockService.updateAlarmPauseRange(pauseCalendarPopup.targetAlarmIndex, pauseCalendarPopup.startKey, pauseCalendarPopup.endKey);
                    }
                }
            }

            Row {
                anchors.right: parent.right
                spacing: Theme.spacingS

                DButton {
                    visible: pauseCalendarPopup.startKey !== ""
                    text: "Clear"
                    buttonHeight: Theme.buttonHeightXS
                    backgroundColor: Theme.errorContainer
                    textColor: Theme.onErrorContainer
                    onClicked: {
                        pauseCalendarPopup.startKey = "";
                        pauseCalendarPopup.endKey = "";
                        ClockService.updateAlarmPauseRange(pauseCalendarPopup.targetAlarmIndex, "", "");
                        pauseCalendarPopup.close();
                    }
                }

                DButton {
                    text: "Done"
                    buttonHeight: Theme.buttonHeightXS
                    onClicked: pauseCalendarPopup.close()
                }
            }
        }
    }
}
