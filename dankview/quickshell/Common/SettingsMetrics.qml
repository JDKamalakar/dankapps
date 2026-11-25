pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

Singleton {
    readonly property real sidebarWidth: 336
    readonly property real compactBreakpoint: 700
    readonly property real contentMaxWidth: 920
    readonly property real windowWidth: 1100
    readonly property real windowHeight: 940
    readonly property real windowMinWidth: 500
    readonly property real windowMinHeight: 400
    readonly property real pagePaddingV: Theme.spacingXL + (Theme.densityStepM ?? 0)
    // Centers the page title on the sidebar search field
    readonly property real pageHeaderHeight: (Theme.fieldHeightLarge ?? 48) + paneMargin * 2
    readonly property real paneMargin: Theme.windowInset ?? Theme.spacingM
    readonly property real panePadding: Theme.spacingXL
    readonly property real rowPaddingH: Theme.spacingL + Theme.spacingXS + (Theme.densityStepS ?? 0)
    readonly property real rowPaddingV: Theme.spacingL + (Theme.densityStepS ?? 0)
    readonly property real rowMinHeight: Math.max((Theme.listItemHeight ?? 56) + (Theme.densityStepM ?? 0), (Theme.buttonHeightS ?? 32) + Theme.spacingXS)
    readonly property real rowMinHeightTwoLine: (Theme.listItemTwoLineHeight ?? 72) + (Theme.densityStepM ?? 0)
    readonly property real cardGap: Theme.spacingL + (Theme.densityStepS ?? 0)
    readonly property real rowContentSpacing: Theme.spacingL
    readonly property real resetChipPaddingH: Theme.spacingM
    readonly property real resetChipPaddingV: Theme.spacingXS
    readonly property real sectionLabelTopGap: Math.max(Theme.spacingXS, Theme.spacingS + (Theme.densityStepS ?? 0))
    readonly property real sectionLabelBottomGap: Theme.spacingM
    readonly property real navIconSize: Theme.avatarSize ?? 32
    readonly property real navItemMinHeight: rowMinHeight
    readonly property real sidebarGroupGap: Theme.spacingS
    readonly property real searchBarGap: Theme.spacingM
    readonly property real buttonGroupCompactThreshold: Theme.spacingXL * 8
    readonly property real dropdownWidth: 220
    readonly property real dropdownChrome: Theme.spacingS * 2 + Theme.spacingXS + (Theme.iconSize ?? 24) + Theme.spacingM
    readonly property real disabledOpacity: 0.38
    readonly property real highlightBlend: 0.2

    readonly property color sidebarColor: "transparent"
    readonly property color paneColor: Theme.floatingWindowPaneSurface
    readonly property color sidebarRowColor: rowColor
    readonly property color rowColor: Theme.foregroundColor(Theme.surfaceContainerHigh, true)
    readonly property color rowHoverColor: Theme.withAlpha(Theme.primary, 0.08)
    readonly property color controlSurface: Theme.surfaceContainerHighest ?? Theme.surface
    readonly property color controlColor: Theme.foregroundColor(controlSurface, true)
    readonly property color selectedRowColor: Theme.withAlpha(Theme.primary, 0.16)
    readonly property int transitionDuration: Theme.expressiveDurations?.expressiveFastSpatial ?? 250
    readonly property int fadeDuration: Theme.expressiveDurations?.expressiveEffects ?? 200
    readonly property int flashHold: 1200
}
