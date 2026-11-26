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

    property string activeFilter: "upcoming" // "upcoming" | "today" | "done"

    onActiveFilterChanged: {
        if (Theme.animationsEnabled)
            tabSwitchAnim.restart();
    }

    ParallelAnimation {
        id: tabSwitchAnim
        NumberAnimation { target: panelsRow; property: "opacity"; from: 0.35; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: panelsTranslate; property: "y"; from: 10; to: 0; duration: 200; easing.type: Easing.OutCubic }
    }

    readonly property string densityMode: SettingsData.density || "comfortable"
    readonly property bool isSpacious: densityMode === "spacious"
    readonly property bool isCompact: densityMode === "compact" || densityMode === "dense"
    readonly property real panelPad: isSpacious ? Theme.spacingXL : (isCompact ? Theme.spacingM : Theme.spacingL)
    readonly property real panelGap: isSpacious ? Theme.spacingXL : (isCompact ? Theme.spacingM : Theme.spacingL)
    readonly property string todayKey: ClockService._todayDateKey()

    function _formatTimeDisp(hour, minute) {
        const use24 = SettingsData.use24HourClock;
        const m = String(minute).padStart(2, "0");
        if (use24)
            return `${String(hour).padStart(2, "0")}:${m}`;
        const hDisp = String(hour % 12 || 12);
        const meridiem = hour >= 12 ? "PM" : "AM";
        return `${hDisp}:${m} ${meridiem}`;
    }

    function _matchesFilter(r) {
        if (!r)
            return false;
        const isDone = r.completedDateKey === todayKey;
        if (activeFilter === "done")
            return isDone;
        if (isDone || !r.enabled)
            return false;
        if (activeFilter === "today") {
            const cur = ClockService.now || new Date();
            const jsDay = cur.getDay();
            const dayOfMonth = cur.getDate();
            if (r.date && todayKey < r.date)
                return false;
            const rep = r.repeat || "none";
            if (rep === "none")
                return r.date === todayKey;
            if (rep === "daily" || rep === "every2h")
                return true;
            if (rep === "weekdays")
                return jsDay >= 1 && jsDay <= 5;
            if (rep === "weekly") {
                const rDate = r.date ? new Date(r.date + "T12:00:00") : cur;
                return rDate.getDay() === jsDay;
            }
            if (rep === "monthly") {
                const rDate = r.date ? new Date(r.date + "T12:00:00") : cur;
                return rDate.getDate() === dayOfMonth;
            }
        }
        return true;
    }

    readonly property var importantList: {
        void ClockService.reminderRevision;
        void ClockService.now;
        const list = ClockService.reminders || [];
        const res = [];
        for (let i = 0; i < list.length; i++) {
            const r = list[i];
            if (r && r.important && _matchesFilter(r))
                res.push({ index: i, item: r });
        }
        return res;
    }

    readonly property var regularList: {
        void ClockService.reminderRevision;
        void ClockService.now;
        const list = ClockService.reminders || [];
        const res = [];
        for (let i = 0; i < list.length; i++) {
            const r = list[i];
            if (r && !r.important && _matchesFilter(r))
                res.push({ index: i, item: r });
        }
        return res;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.panelPad
        spacing: root.panelGap

        // Top Filter Bar (Custom Segmented Group)
        Row {
            id: customFilterTabs
            Layout.alignment: Qt.AlignHCenter
            width: Math.min(540, parent.width)
            spacing: 2

            readonly property var tabModel: [
                { key: "upcoming", icon: "alarm", text: "Upcoming" },
                { key: "today", icon: "today", text: "Today" },
                { key: "done", icon: "check_circle", text: "Done" }
            ]
            readonly property int itemHeight: root.isSpacious ? 42 : (root.isCompact ? 32 : 36)

            Repeater {
                model: customFilterTabs.tabModel

                Rectangle {
                    required property var modelData
                    required property int index

                    readonly property bool active: root.activeFilter === modelData.key
                    readonly property bool isFirst: index === 0
                    readonly property bool isLast: index === customFilterTabs.tabModel.length - 1
                    readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                    readonly property real innerR: Theme.groupedListInnerRadius ?? 4

                    width: Math.floor((customFilterTabs.width - customFilterTabs.spacing * 2) / 3)
                    height: customFilterTabs.itemHeight
                    topLeftRadius: (active || tabMouse.containsMouse) ? outerR : (isFirst ? outerR : innerR)
                    bottomLeftRadius: (active || tabMouse.containsMouse) ? outerR : (isFirst ? outerR : innerR)
                    topRightRadius: (active || tabMouse.containsMouse) ? outerR : (isLast ? outerR : innerR)
                    bottomRightRadius: (active || tabMouse.containsMouse) ? outerR : (isLast ? outerR : innerR)
                    color: (active || tabMouse.containsMouse) ? Theme.withAlpha(Theme.primary, 0.2) : Theme.foregroundColor(Theme.surfaceContainerLow, true)
                    border.width: 1
                    border.color: (active || tabMouse.containsMouse) ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                    scale: tabMouse.pressed ? 0.96 : 1.0
                    clip: true

                    Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                    DRipple { id: tabRipple; anchors.fill: parent; rippleColor: Theme.primary }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        DIcon {
                            name: modelData.icon
                            size: 16
                            color: (active || tabMouse.containsMouse) ? Theme.primary : Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: modelData.text
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: active ? Font.DemiBold : Font.Medium
                            color: (active || tabMouse.containsMouse) ? Theme.primary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => tabRipple.trigger(mouse.x, mouse.y)
                        onClicked: root.activeFilter = modelData.key
                    }
                }
            }
        }

        // Always 2-Panel Split: Left = Reminders (+ Add Card), Right = Important
        RowLayout {
            id: panelsRow
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.panelGap
            transform: Translate { id: panelsTranslate; y: 0 }

            // LEFT PANEL: Regular Reminders + Add Reminder Card
            DFlickable {
                id: regularFlickable
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                clip: true
                contentWidth: width
                contentHeight: regularCol.implicitHeight + Theme.spacingL

                Column {
                    id: regularCol
                    x: 4
                    width: Math.max(0, regularFlickable.width - 8)
                    spacing: root.isSpacious ? Theme.spacingM : (root.isCompact ? Theme.spacingXS : Theme.spacingS)

                    ClockSectionLabel {
                        width: parent.width
                        iconName: "notifications"
                        text: `Reminders (${root.regularList.length})`
                    }

                    ClockEmptyState {
                        visible: root.regularList.length === 0
                        cardHeight: 130
                        iconName: "notifications_none"
                        iconSize: Theme.iconSizeLarge
                        title: "Nothing to show"
                        titlePixelSize: Theme.fontSizeMedium
                        subtitle: "Add a reminder below."
                    }

                    Column {
                        visible: root.regularList.length > 0
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: root.regularList

                            Rectangle {
                                id: regCard
                                required property var modelData
                                required property int index

                                readonly property int rIdx: modelData.index
                                readonly property var rObj: modelData.item
                                readonly property bool isDone: rObj.completedDateKey === root.todayKey
                                readonly property bool isFirst: index === 0
                                readonly property bool isLast: index === root.regularList.length - 1
                                readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                                readonly property real innerR: Theme.groupedListInnerRadius ?? 4

                                width: parent.width
                                height: root.isSpacious ? 76 : (root.isCompact ? 58 : 66)
                                topLeftRadius: regHover.hovered ? Theme.cornerRadiusXL : (isFirst ? outerR : innerR)
                                topRightRadius: regHover.hovered ? Theme.cornerRadiusXL : (isFirst ? outerR : innerR)
                                bottomLeftRadius: regHover.hovered ? Theme.cornerRadiusXL : (isLast ? outerR : innerR)
                                bottomRightRadius: regHover.hovered ? Theme.cornerRadiusXL : (isLast ? outerR : innerR)
                                color: regHover.hovered ? Theme.foregroundColor(Theme.surfaceContainerHigh, true) : Theme.foregroundColor(Theme.surfaceContainerLow, true)
                                border.width: 1
                                border.color: regHover.hovered ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)

                                Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: ClockMetrics.fadeDuration } }

                                HoverHandler { id: regHover }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ClockService.openEditReminderSheet(regCard.rIdx)
                                }

                                Item {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.rightMargin: Theme.spacingS

                                    Row {
                                        anchors.left: parent.left
                                        anchors.right: regActions.left
                                        anchors.rightMargin: Theme.spacingS
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Theme.spacingS

                                        DIcon {
                                            name: regCard.isDone ? "task_alt" : "notifications"
                                            size: Theme.iconSizeSmall
                                            color: regCard.isDone ? Theme.success : Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Column {
                                            width: Math.max(0, parent.width - Theme.iconSizeSmall - Theme.spacingS)
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 2

                                            StyledText {
                                                width: parent.width
                                                text: regCard.rObj.title || "Reminder"
                                                font.pixelSize: Theme.fontSizeMedium
                                                font.weight: Font.DemiBold
                                                color: Theme.surfaceText
                                                elide: Text.ElideRight
                                            }

                                            StyledText {
                                                width: parent.width
                                                text: `${root._formatTimeDisp(regCard.rObj.hour, regCard.rObj.minute)}${regCard.rObj.date ? " • " + regCard.rObj.date : ""}`
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    Row {
                                        id: regActions
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

                                        DIconButton {
                                            iconName: regCard.isDone ? "undo" : "check_circle"
                                            variant: regCard.isDone ? "standard" : "tonal"
                                            size: "s"
                                            tooltipText: regCard.isDone ? "Mark pending" : "Mark done"
                                            onClicked: ClockService.toggleReminder(regCard.rIdx, !regCard.isDone)
                                        }

                                        Item {
                                            width: regHover.hovered ? regDelBtn.implicitWidth : 0
                                            height: regDelBtn.implicitHeight
                                            clip: true
                                            opacity: regHover.hovered ? 1 : 0
                                            Behavior on width { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150 } }

                                            DIconButton {
                                                id: regDelBtn
                                                iconName: "delete_outline"
                                                variant: "standard"
                                                size: "s"
                                                iconColor: Theme.error
                                                tooltipText: "Delete reminder"
                                                onClicked: ClockService.removeReminder(regCard.rIdx)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Add Reminder Card (always visible except in Done filter)
                    Rectangle {
                        id: addReminderCard
                        visible: root.activeFilter !== "done"
                        width: parent.width
                        height: root.isSpacious ? 76 : (root.isCompact ? 58 : 66)
                        radius: Theme.cornerRadiusXL
                        scale: addRemMouse.pressed ? 0.98 : 1.0
                        color: addRemHover.hovered ? Theme.withAlpha(Theme.primary, 0.14) : Theme.foregroundColor(Theme.surfaceContainerLow, true)
                        border.width: addRemHover.hovered ? 1.5 : 1
                        border.color: addRemHover.hovered ? Theme.primary : Theme.outlineVariant

                        Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: ClockMetrics.transitionDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: ClockMetrics.curveFastSpatial } }
                        Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: ClockMetrics.fadeDuration } }

                        HoverHandler { id: addRemHover }

                        MouseArea {
                            id: addRemMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ClockService.openAddReminderSheet()
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
                                    name: "add_alert"
                                    size: Theme.iconSizeSmall
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: "New Reminder"
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.DemiBold
                                    color: addRemHover.hovered ? Theme.primary : Theme.surfaceText
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
                }
            }

            // RIGHT PANEL: Important Reminders
            DFlickable {
                id: importantFlickable
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                clip: true
                contentWidth: width
                contentHeight: importantCol.implicitHeight + Theme.spacingL

                Column {
                    id: importantCol
                    x: 4
                    width: Math.max(0, importantFlickable.width - 8)
                    spacing: 0

                    ClockSectionLabel {
                        width: parent.width
                        iconName: "star"
                        text: `Important (${root.importantList.length})`
                    }

                    ClockEmptyState {
                        visible: root.importantList.length === 0
                        cardHeight: 150
                        iconName: "star_outline"
                        iconSize: Theme.iconSizeLarge
                        title: "Nothing to show"
                        titlePixelSize: Theme.fontSizeMedium
                        subtitle: "Important reminders will appear here."
                    }

                    Column {
                        visible: root.importantList.length > 0
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: root.importantList

                            Rectangle {
                                id: impCard
                                required property var modelData
                                required property int index

                                readonly property int rIdx: modelData.index
                                readonly property var rObj: modelData.item
                                readonly property bool isDone: rObj.completedDateKey === root.todayKey
                                readonly property bool isFirst: index === 0
                                readonly property bool isLast: index === root.importantList.length - 1
                                readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                                readonly property real innerR: Theme.groupedListInnerRadius ?? 4

                                width: parent.width
                                height: root.isSpacious ? 76 : (root.isCompact ? 58 : 66)
                                topLeftRadius: impHover.hovered ? Theme.cornerRadiusXL : (isFirst ? outerR : innerR)
                                topRightRadius: impHover.hovered ? Theme.cornerRadiusXL : (isFirst ? outerR : innerR)
                                bottomLeftRadius: impHover.hovered ? Theme.cornerRadiusXL : (isLast ? outerR : innerR)
                                bottomRightRadius: impHover.hovered ? Theme.cornerRadiusXL : (isLast ? outerR : innerR)
                                color: impHover.hovered ? Theme.foregroundColor(Theme.surfaceContainerHigh, true) : Theme.foregroundColor(Theme.surfaceContainerLow, true)
                                border.width: 1
                                border.color: impHover.hovered ? Theme.warning : (Theme.outlineMedium ?? Theme.outlineVariant)

                                Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: ClockMetrics.fadeDuration } }

                                HoverHandler { id: impHover }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ClockService.openEditReminderSheet(impCard.rIdx)
                                }

                                Item {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.rightMargin: Theme.spacingS

                                    Row {
                                        anchors.left: parent.left
                                        anchors.right: impActions.left
                                        anchors.rightMargin: Theme.spacingS
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Theme.spacingS

                                        DIcon {
                                            name: "star"
                                            size: Theme.iconSizeSmall
                                            color: Theme.warning
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Column {
                                            width: Math.max(0, parent.width - Theme.iconSizeSmall - Theme.spacingS)
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 2

                                            StyledText {
                                                width: parent.width
                                                text: impCard.rObj.title || "Reminder"
                                                font.pixelSize: Theme.fontSizeMedium
                                                font.weight: Font.DemiBold
                                                color: Theme.surfaceText
                                                elide: Text.ElideRight
                                            }

                                            StyledText {
                                                width: parent.width
                                                text: `${root._formatTimeDisp(impCard.rObj.hour, impCard.rObj.minute)}${impCard.rObj.date ? " • " + impCard.rObj.date : ""}`
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    Row {
                                        id: impActions
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

                                        DIconButton {
                                            iconName: impCard.isDone ? "undo" : "check_circle"
                                            variant: impCard.isDone ? "standard" : "tonal"
                                            size: "s"
                                            tooltipText: impCard.isDone ? "Mark pending" : "Mark done"
                                            onClicked: ClockService.toggleReminder(impCard.rIdx, !impCard.isDone)
                                        }

                                        Item {
                                            width: impHover.hovered ? impDelBtn.implicitWidth : 0
                                            height: impDelBtn.implicitHeight
                                            clip: true
                                            opacity: impHover.hovered ? 1 : 0
                                            Behavior on width { enabled: Theme.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150 } }

                                            DIconButton {
                                                id: impDelBtn
                                                iconName: "delete_outline"
                                                variant: "standard"
                                                size: "s"
                                                iconColor: Theme.error
                                                tooltipText: "Delete reminder"
                                                onClicked: ClockService.removeReminder(impCard.rIdx)
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
}
