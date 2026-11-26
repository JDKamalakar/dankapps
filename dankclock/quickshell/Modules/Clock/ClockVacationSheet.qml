pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Common
import qs.DCommon.Widgets

Rectangle {
    id: root

    property bool opened: ClockService.vacationSheetOpen
    readonly property string densityMode: SettingsData.density || "comfortable"
    readonly property bool isSpacious: densityMode === "spacious"
    readonly property bool isCompact: densityMode === "compact" || densityMode === "dense"
    width: opened ? (isSpacious ? 400 : (isCompact ? 330 : 360)) : 0
    visible: width > 0
    radius: Theme.cornerRadiusXL
    color: ClockMetrics.paneColor
    border.color: Theme.outlineMedium
    border.width: Theme.layerOutlineWidth
    clip: true

    Behavior on width {
        enabled: Theme.animationsEnabled
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    function dismiss() {
        ClockService.vacationSheetOpen = false;
    }

    readonly property string todayStr: ClockService._todayDateKey()
    readonly property var currentVacation: ClockService.vacation
    readonly property bool isEnabled: Boolean(currentVacation && currentVacation.enabled)
    readonly property string startDateStr: (currentVacation && currentVacation.startDate) || todayStr
    readonly property string endDateStr: (currentVacation && currentVacation.endDate) || startDateStr

    readonly property int totalDaysCount: {
        const s = new Date(startDateStr);
        const e = new Date(endDateStr);
        const diffMs = e.getTime() - s.getTime();
        return Math.max(1, Math.round(diffMs / 86400000) + 1);
    }

    function _formatDate(d) {
        return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    }

    function _applyPreset(idx) {
        const now = ClockService.now;
        const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const sStr = _formatDate(start);
        let eStr = sStr;
        if (idx === 0) {
            eStr = sStr;
        } else if (idx === 1) {
            const jsDay = start.getDay();
            const daysUntilSun = (7 - jsDay) % 7;
            eStr = _formatDate(new Date(start.getTime() + daysUntilSun * 86400000));
        } else if (idx === 2) {
            eStr = _formatDate(new Date(start.getTime() + 2 * 86400000));
        } else if (idx === 3) {
            eStr = _formatDate(new Date(start.getTime() + 6 * 86400000));
        }
        ClockService.setVacationMode(true, sStr, eStr);
    }

    function _adjustDuration(deltaDays, deltaMonths) {
        const s = new Date(startDateStr);
        const curEnd = new Date(endDateStr);
        const nextEnd = new Date(curEnd.getFullYear(), curEnd.getMonth() + (deltaMonths || 0), curEnd.getDate() + (deltaDays || 0));
        if (nextEnd >= s) {
            ClockService.setVacationMode(true, startDateStr, _formatDate(nextEnd));
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: root.opened
        Keys.onEscapePressed: event => {
            root.dismiss();
            event.accepted = true;
        }

        Item {
            id: drawerPanel
            anchors.fill: parent

        Item {
            id: drawerHeader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingM
            height: 44

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingS

                DIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "beach_access"
                    size: Theme.iconSizeMedium
                    color: Theme.primary
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Vacation"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Theme.fontWeightBold
                    color: Theme.surfaceText
                }
            }
        }

        // Animated upper-half hero when enabled (slides controls down, randomizes theme on open)
        Item {
            id: vacationHero
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: drawerHeader.bottom
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            height: root.isEnabled ? (SettingsData.vacationFlipClock ? (root.isSpacious ? 320 : 300) : (root.isSpacious ? 224 : 204)) : 0
            opacity: root.isEnabled ? 1.0 : 0.0
            clip: true

            property int _remSecs: 0
            function _updateRemaining() {
                if (!root.isEnabled) { _remSecs = 0; return; }
                const parts = root.endDateStr.split("-");
                if (parts.length !== 3) return;
                const endDt = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]), 23, 59, 59);
                const diff = Math.max(0, Math.floor((endDt.getTime() - Date.now()) / 1000));
                _remSecs = diff;
            }

            Timer {
                interval: 1000
                repeat: true
                running: root.isEnabled && root.visible && SettingsData.vacationFlipClock
                triggeredOnStart: true
                onTriggered: vacationHero._updateRemaining()
            }

            Connections {
                target: root
                function onOpenedChanged() {
                    if (root.opened)
                        ClockService.randomizeVacationTheme();
                }
                function onIsEnabledChanged() {
                    if (root.isEnabled)
                        ClockService.randomizeVacationTheme();
                }
            }

            Behavior on height { enabled: Theme.animationsEnabled; NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                anchors.bottomMargin: Theme.spacingM
                radius: Theme.cornerRadiusL
                color: Theme.withAlpha(Theme.primary, 0.12)
                border.color: Theme.withAlpha(Theme.primary, 0.35)
                border.width: 1

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 220
                        height: 140

                        AnimatedImage {
                            anchors.fill: parent
                            visible: ClockService.vacationThemes[ClockService.vacationThemeIndex].isGif
                            source: visible ? Qt.resolvedUrl("../../assets/vacation/" + ClockService.vacationThemes[ClockService.vacationThemeIndex].file) : ""
                            fillMode: Image.PreserveAspectFit
                            playing: root.isEnabled && root.visible
                        }

                        Image {
                            anchors.fill: parent
                            visible: !ClockService.vacationThemes[ClockService.vacationThemeIndex].isGif
                            source: visible ? Qt.resolvedUrl("../../assets/vacation/" + ClockService.vacationThemes[ClockService.vacationThemeIndex].file) : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                    }

                    // Animated Flip Clock Countdown (Days : Hrs : Min : Sec)
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6
                        visible: SettingsData.vacationFlipClock

                        readonly property int d: Math.floor(vacationHero._remSecs / 86400)
                        readonly property int h: Math.floor((vacationHero._remSecs % 86400) / 3600)
                        readonly property int m: Math.floor((vacationHero._remSecs % 3600) / 60)
                        readonly property int s: vacationHero._remSecs % 60

                        Repeater {
                            id: flipRepeater
                            model: ["D", "H", "M", "S"]

                            delegate: Column {
                                id: flipCol
                                required property string modelData
                                required property int index
                                spacing: 2

                                readonly property int curVal: index === 0 ? parent.d : (index === 1 ? parent.h : (index === 2 ? parent.m : parent.s))
                                readonly property string dispStr: String(curVal).padStart(2, "0")

                                onCurValChanged: flipAnim.restart()

                                Rectangle {
                                    id: flipCard
                                    width: 56
                                    height: 48
                                    radius: Theme.cornerRadiusS
                                    color: Theme.surfaceContainerHighest
                                    border.color: Theme.withAlpha(Theme.primary, 0.4)
                                    border.width: 1
                                    clip: true

                                    // Static full digit
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: flipCol.dispStr
                                        font.pixelSize: Theme.fontSizeLarge + 2
                                        font.weight: Font.Bold
                                        color: Theme.primary
                                    }

                                    // Animated bottom split-flap hinged at center line
                                    Item {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: parent.height / 2
                                        clip: true
                                        visible: flipAnim.running

                                        transform: Rotation {
                                            origin.x: flipCard.width / 2
                                            origin.y: 0
                                            axis { x: 1; y: 0; z: 0 }
                                            angle: 0

                                            NumberAnimation on angle {
                                                id: flipAnim
                                                running: false
                                                from: 90
                                                to: 0
                                                duration: 260
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        Rectangle {
                                            width: flipCard.width
                                            height: flipCard.height
                                            y: -flipCard.height / 2
                                            radius: Theme.cornerRadiusS
                                            color: Theme.surfaceContainerHighest

                                            StyledText {
                                                anchors.centerIn: parent
                                                text: flipCol.dispStr
                                                font.pixelSize: Theme.fontSizeLarge + 2
                                                font.weight: Font.Bold
                                                color: Theme.primary
                                            }
                                        }
                                    }

                                    // Center split hinge line
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 1
                                        color: Theme.withAlpha(Theme.outlineVariant, 0.5)
                                        z: 3
                                    }
                                }

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: flipCol.modelData
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: Theme.surfaceVariantText
                                }
                            }
                        }
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: ClockService.vacationThemes[ClockService.vacationThemeIndex].label + " • Alarms Paused"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.primary
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: ClockService.formatVacationRange(ClockService.vacation)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }
            }
        }

        Flickable {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: vacationHero.bottom
            anchors.bottom: parent.bottom
            anchors.margins: root.isSpacious ? Theme.spacingL : (root.isCompact ? Theme.spacingS : Theme.spacingM)
            contentWidth: width
            contentHeight: vacationCol.implicitHeight + Theme.spacingM
            clip: true

            Column {
                id: vacationCol
                width: parent.width
                spacing: root.isSpacious ? Theme.spacingL : (root.isCompact ? Theme.spacingS : Theme.spacingM)
    readonly property var currentVacation: ClockService.vacation
    readonly property bool isEnabled: Boolean(currentVacation && currentVacation.enabled)
    readonly property string startDateStr: (currentVacation && currentVacation.startDate) || todayStr
    readonly property string endDateStr: (currentVacation && currentVacation.endDate) || startDateStr

    readonly property int totalDaysCount: {
        const s = new Date(startDateStr);
        const e = new Date(endDateStr);
        const diffMs = e.getTime() - s.getTime();
        return Math.max(1, Math.round(diffMs / 86400000) + 1);
    }

    function _formatDate(d) {
        return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    }

    function _applyPreset(idx) {
        const now = ClockService.now;
        const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const sStr = _formatDate(start);
        let eStr = sStr;

        if (idx === 0) {
            // Today only
            eStr = sStr;
        } else if (idx === 1) {
            // Until end of weekend (Sunday)
            const jsDay = start.getDay(); // 0=Sun .. 6=Sat
            const daysUntilSun = (7 - jsDay) % 7;
            const end = new Date(start.getTime() + daysUntilSun * 86400000);
            eStr = _formatDate(end);
        } else if (idx === 2) {
            // Next 3 days
            const end = new Date(start.getTime() + 2 * 86400000);
            eStr = _formatDate(end);
        } else if (idx === 3) {
            // 1 week
            const end = new Date(start.getTime() + 6 * 86400000);
            eStr = _formatDate(end);
        }
        ClockService.setVacationMode(true, sStr, eStr);
    }

    function _adjustDuration(deltaDays, deltaMonths) {
        const s = new Date(startDateStr);
        const curEnd = new Date(endDateStr);
        const nextEnd = new Date(curEnd.getFullYear(), curEnd.getMonth() + (deltaMonths || 0), curEnd.getDate() + (deltaDays || 0));
        if (nextEnd >= s) {
            ClockService.setVacationMode(true, startDateStr, _formatDate(nextEnd));
        }
    }


        // Master Switch Row (Full row clickable, persists immediately)
        ClockRow {
            width: parent.width
            title: "Silence all alarms"
            subtitle: root.isEnabled ? "Pause all active alarms" : "Alarms will go off as scheduled"
            iconName: "beach_access"
            accent: root.isEnabled ? "orange" : ""
            clickable: true
            isFirstInGroup: true
            isLastInGroup: true
            onClicked: {
                if (root.isEnabled) {
                    ClockService.disableVacationMode();
                } else {
                    const now = ClockService.now;
                    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
                    const days = Math.max(1, SettingsData.vacationDefaultDays || 3);
                    const end = new Date(start.getTime() + (days - 1) * 86400000);
                    ClockService.setVacationMode(true, root._formatDate(start), root._formatDate(end));
                }
            }

            DToggle {
                hideText: true
                checked: root.isEnabled
                anchors.verticalCenter: parent.verticalCenter
                onToggled: isChecked => {
                    if (isChecked) {
                        const now = ClockService.now;
                        const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
                        const days = Math.max(1, SettingsData.vacationDefaultDays || 3);
                        const end = new Date(start.getTime() + (days - 1) * 86400000);
                        ClockService.setVacationMode(true, root._formatDate(start), root._formatDate(end));
                    } else {
                        ClockService.disableVacationMode();
                    }
                }
            }
        }

        // Section: Presets (always clickable, turns Vacation on for that duration)
        Column {
            width: parent.width
            spacing: Theme.spacingXS

            Row {
                spacing: Theme.spacingXS

                DIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "tune"
                    size: 14
                    color: Theme.primary
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "PRESETS"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightBold
                    color: Theme.surfaceVariantText
                }
            }

            Row {
                id: presetGroup
                width: parent.width
                spacing: 2

                readonly property var presetModel: [
                    { icon: "today", text: "Today" },
                    { icon: "weekend", text: "Weekend" },
                    { icon: "date_range", text: "3 Days" },
                    { icon: "calendar_month", text: "1 Week" }
                ]
                readonly property int activeIdx: {
                    if (!root.isEnabled) return -1;
                    if (root.totalDaysCount === 1) return 0;
                    if (root.totalDaysCount === 3) return 2;
                    if (root.totalDaysCount === 7) return 3;
                    return -1;
                }

                Repeater {
                    model: presetGroup.presetModel

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        readonly property bool active: presetGroup.activeIdx === index
                        readonly property bool isFirst: index === 0
                        readonly property bool isLast: index === presetGroup.presetModel.length - 1
                        readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                        readonly property real innerR: Theme.groupedListInnerRadius ?? 4

                        width: Math.floor((presetGroup.width - presetGroup.spacing * 3) / 4)
                        height: root.isSpacious ? 42 : (root.isCompact ? 30 : 36)
                        topLeftRadius: (active || pMouse.containsMouse) ? outerR : (isFirst ? outerR : innerR)
                        bottomLeftRadius: (active || pMouse.containsMouse) ? outerR : (isFirst ? outerR : innerR)
                        topRightRadius: (active || pMouse.containsMouse) ? outerR : (isLast ? outerR : innerR)
                        bottomRightRadius: (active || pMouse.containsMouse) ? outerR : (isLast ? outerR : innerR)
                        color: (active || pMouse.containsMouse) ? Theme.withAlpha(Theme.primary, 0.2) : Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: (active || pMouse.containsMouse) ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                        scale: pMouse.pressed ? 0.96 : (pMouse.containsMouse ? 1.04 : 1.0)
                        clip: true

                        Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: 150 } }
                        Behavior on border.color { enabled: Theme.animationsEnabled; ColorAnimation { duration: 150 } }

                        DRipple { id: pRipple; anchors.fill: parent; rippleColor: Theme.primary }

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            DIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: modelData.icon
                                size: 14
                                color: (active || pMouse.containsMouse) ? Theme.primary : Theme.surfaceVariantText
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.text
                                font.pixelSize: Theme.fontSizeSmall - 1
                                font.weight: active ? Font.DemiBold : Font.Medium
                                color: (active || pMouse.containsMouse) ? Theme.primary : Theme.surfaceText
                            }
                        }

                        MouseArea {
                            id: pMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => pRipple.trigger(mouse.x, mouse.y)
                            onClicked: root._applyPreset(index)
                        }
                    }
                }
            }
        }

        // Section: Adjust Duration Header + 2x3 Grid Card
        Column {
            width: parent.width
            spacing: Theme.spacingXS
            opacity: root.isEnabled ? 1.0 : 0.45
            enabled: root.isEnabled

            Row {
                spacing: Theme.spacingXS

                DIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "date_range"
                    size: 14
                    color: Theme.primary
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ADJUST DURATION"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightBold
                    color: Theme.surfaceVariantText
                }
            }

            Rectangle {
                width: parent.width
                height: adjustCol.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadiusXL
                color: Theme.surfaceContainerLow
                border.width: Theme.layerOutlineWidth
                border.color: Theme.outlineLight

                Column {
                    id: adjustCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingM

                    // Date Timeline Bar (Start -> Duration Pill -> End)
                    Row {
                        width: parent.width
                        height: 44

                        Column {
                            width: (parent.width - 80) / 2
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            StyledText {
                                text: "STARTS"
                                font.pixelSize: Theme.fontSizeSmall - 1
                                font.weight: Theme.fontWeightBold
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                text: root.startDateStr
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Theme.fontWeightBold
                                color: Theme.surfaceText
                            }
                        }

                        Item {
                            width: 80
                            height: parent.height

                            DBadge {
                                anchors.centerIn: parent
                                text: `${root.totalDaysCount} ${root.totalDaysCount === 1 ? 'day' : 'days'}`
                                color: Theme.surfaceContainerHighest
                                textColor: Theme.primary
                            }
                        }

                        Column {
                            width: (parent.width - 80) / 2
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            StyledText {
                                anchors.right: parent.right
                                text: "ENDS"
                                font.pixelSize: Theme.fontSizeSmall - 1
                                font.weight: Theme.fontWeightBold
                                color: Theme.tertiary
                            }

                            StyledText {
                                anchors.right: parent.right
                                text: root.endDateStr
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Theme.fontWeightBold
                                color: Theme.surfaceText
                            }
                        }
                    }

                    // 2x3 Segmented Grid Group Button (-1D, -1W, -1M / +1D, +1W, +1M)
                    Grid {
                        id: adjustGrid
                        width: parent.width
                        columns: 3
                        spacing: 2

                        readonly property var adjustItems: [
                            { text: "-1 Day", days: -1, months: 0 },
                            { text: "-1 Week", days: -7, months: 0 },
                            { text: "-1 Month", days: 0, months: -1 },
                            { text: "+1 Day", days: 1, months: 0 },
                            { text: "+1 Week", days: 7, months: 0 },
                            { text: "+1 Month", days: 0, months: 1 }
                        ]

                        Repeater {
                            model: adjustGrid.adjustItems

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                readonly property int col: index % 3
                                readonly property int row: Math.floor(index / 3)
                                readonly property real outerR: Theme.groupedListOuterRadius ?? 16
                                readonly property real innerR: Theme.groupedListInnerRadius ?? 4

                                width: Math.floor((adjustGrid.width - adjustGrid.spacing * 2) / 3)
                                height: root.isSpacious ? 40 : (root.isCompact ? 28 : 34)
                                topLeftRadius: adjMouse.containsMouse ? outerR : ((row === 0 && col === 0) ? outerR : innerR)
                                topRightRadius: adjMouse.containsMouse ? outerR : ((row === 0 && col === 2) ? outerR : innerR)
                                bottomLeftRadius: adjMouse.containsMouse ? outerR : ((row === 1 && col === 0) ? outerR : innerR)
                                bottomRightRadius: adjMouse.containsMouse ? outerR : ((row === 1 && col === 2) ? outerR : innerR)
                                color: adjMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.2) : Theme.surfaceContainerHigh
                                border.width: 1
                                border.color: adjMouse.containsMouse ? Theme.primary : (Theme.outlineMedium ?? Theme.outlineVariant)
                                scale: adjMouse.pressed ? 0.95 : (adjMouse.containsMouse ? 1.03 : 1.0)
                                clip: true

                                Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                DRipple { id: adjRipple; anchors.fill: parent; rippleColor: Theme.primary }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: modelData.text
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    font.weight: Font.Medium
                                    color: adjMouse.containsMouse ? Theme.primary : Theme.surfaceText
                                }

                                MouseArea {
                                    id: adjMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: mouse => adjRipple.trigger(mouse.x, mouse.y)
                                    onClicked: root._adjustDuration(modelData.days, modelData.months)
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
