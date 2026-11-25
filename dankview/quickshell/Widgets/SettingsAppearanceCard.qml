pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Common as DC
import qs.DCommon.Widgets
import qs.Widgets

Column {
    id: root

    width: parent ? parent.width : 0
    spacing: SettingsMetrics.cardGap

    readonly property var colorSourceOptions: [
        { label: "Auto", value: "auto" },
        { label: "Preset", value: "preset" },
        { label: "Custom", value: "custom" }
    ]

    readonly property var densityOptions: [
        { label: "Spacious", value: "spacious" },
        { label: "Comfortable", value: "comfortable" },
        { label: "Compact", value: "compact" },
        { label: "Dense", value: "dense" }
    ]

    readonly property var fontSourceOptions: [
        { label: "Auto", value: "auto" },
        { label: "System", value: "system" },
        { label: "Custom", value: "custom" }
    ]

    readonly property var motionDurationOptions: [
        { label: "Very fast (250ms)", value: 0 },
        { label: "Fast (375ms)", value: 1 },
        { label: "Normal (500ms)", value: 2 },
        { label: "Deliberate (750ms)", value: 3 },
        { label: "Slow (1000ms)", value: 4 }
    ]

    // 1. Theme Card
    SettingsCard {
        title: "Theme"
        iconName: "palette"

        SettingsButtonGroupRow {
            iconName: "dark_mode"
            text: "Theme mode"
            description: {
                switch (SettingsData.themeMode) {
                case "light": return "Always use the light theme.";
                case "dark": return "Always use the dark theme.";
                default: return "Following the system color scheme (" + (Theme.isLightMode ? "light" : "dark") + ").";
                }
            }
            model: ["Auto", "Light", "Dark"]
            currentIndex: {
                switch (SettingsData.themeMode) {
                case "light": return 1;
                case "dark": return 2;
                default: return 0;
                }
            }
            onSelectionChanged: (idx, sel) => {
                if (sel) {
                    const modes = ["auto", "light", "dark"];
                    SettingsData.themeMode = modes[idx];
                }
            }
        }

        SettingsButtonGroupRow {
            iconName: "format_color_fill"
            text: "Color source"
            description: {
                switch (SettingsData.colorSource) {
                case "preset": return "Use a bundled color palette.";
                case "custom": return "Load colors from your own theme file.";
                default: return "Follow Dux Shell colors, falling back to a preset.";
                }
            }
            model: ["Auto", "Preset", "Custom"]
            currentIndex: {
                switch (SettingsData.colorSource) {
                case "preset": return 1;
                case "custom": return 2;
                default: return 0;
                }
            }
            onSelectionChanged: (idx, sel) => {
                if (sel) {
                    const sources = ["auto", "preset", "custom"];
                    SettingsData.colorSource = sources[idx];
                }
            }
        }

        SettingsRow {
            visible: SettingsData.colorSource === "auto"
            iconName: Theme.dmsColorsAvailable ? "check_circle" : "info"
            iconColor: Theme.dmsColorsAvailable ? Theme.success : Theme.surfaceVariantText
            title: Theme.dmsColorsAvailable ? "Using Dux Shell dynamic colors." : "Dux Shell not detected, using the " + Theme.presetLabel(SettingsData.presetTheme) + " preset."
        }

        SettingsRow {
            visible: SettingsData.colorSource === "preset"
            iconName: "palette"
            title: "Palette: " + Theme.presetLabel(SettingsData.presetTheme)
            body: Flow {
                width: parent.width
                spacing: Theme.spacingS

                Repeater {
                    model: Theme.presetNames()

                    Rectangle {
                        id: swatch
                        required property string modelData
                        readonly property bool active: SettingsData.presetTheme === modelData

                        width: Theme.avatarSize
                        height: Theme.avatarSize
                        radius: Theme.fullRadius(width, height)
                        color: Theme.presetColors(modelData).primary

                        DIcon {
                            anchors.centerIn: parent
                            name: "check"
                            size: Theme.iconSizeSmall
                            color: Theme.presetColors(swatch.modelData).primaryText
                            visible: swatch.active
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: SettingsData.presetTheme = swatch.modelData
                        }
                    }
                }
            }
        }

        SettingsRow {
            visible: SettingsData.colorSource === "custom"
            clickable: true
            iconName: "folder_open"
            title: SettingsData.customThemeFile ? SettingsData.customThemeFile.split("/").pop() : "No theme file selected"
            subtitle: SettingsData.customThemeFile ? SettingsData.customThemeFile : "Choose a JSON color theme file."
            showChevron: true
            onClicked: {
                if (typeof FilePicker !== "undefined" || typeof openThemeDialog !== "undefined") {
                    // file picker hook
                }
            }
        }
    }

    // 2. Shape Card
    SettingsCard {
        title: "Shape"
        iconName: "rounded_corner"

        SettingsSliderRow {
            iconName: "rounded_corner"
            text: "Radius strength"
            description: "50 is the Material default (" + SettingsData.radiusStrength + "%)."
            minimumLabel: "Square"
            value: SettingsData.radiusStrength
            minimum: 0
            maximum: 100
            settingKey: "radiusStrength"
            onSliderValueChanged: newValue => SettingsData.radiusStrength = newValue
        }
    }

    // 3. Density Card
    SettingsCard {
        title: "Density"
        iconName: "density_medium"

        SettingsButtonGroupRow {
            iconName: "density_medium"
            text: "Interface density"
            description: "Interface layout density and spacing."
            model: ["Spacious", "Comfortable", "Compact", "Dense"]
            currentIndex: {
                switch (SettingsData.density) {
                case "spacious": return 0;
                case "compact": return 2;
                case "dense": return 3;
                default: return 1;
                }
            }
            onSelectionChanged: (idx, sel) => {
                if (sel) {
                    const dens = ["spacious", "comfortable", "compact", "dense"];
                    if (typeof SettingsData.setDensity === "function") {
                        SettingsData.setDensity(dens[idx]);
                    } else {
                        SettingsData.density = dens[idx];
                    }
                }
            }
        }
    }

    // 4. Typography Card
    SettingsCard {
        title: "Typography"
        iconName: "text_fields"

        SettingsButtonGroupRow {
            iconName: "font_download"
            text: "Font source"
            description: "Choose system default, Qt system font, or custom."
            model: ["Auto", "System", "Custom"]
            currentIndex: {
                switch (SettingsData.fontSource) {
                case "system": return 1;
                case "custom": return 2;
                default: return 0;
                }
            }
            onSelectionChanged: (idx, sel) => {
                if (sel) {
                    const src = ["auto", "system", "custom"];
                    SettingsData.fontSource = src[idx];
                }
            }
        }

        SettingsSliderRow {
            iconName: "format_bold"
            text: "Font weight"
            description: "Base text thickness (" + SettingsData.fontWeight + ")."
            minimum: 100
            maximum: 900
            step: 100
            showStops: true
            value: SettingsData.fontWeight
            settingKey: "fontWeight"
            onSliderValueChanged: newValue => SettingsData.fontWeight = newValue
        }

        SettingsSliderRow {
            iconName: "format_size"
            text: "Font scale"
            description: "Scale font sizes (" + Math.round(SettingsData.fontScale * 100) + "%)."
            minimum: 75
            maximum: 150
            unit: "%"
            value: Math.round(SettingsData.fontScale * 100)
            settingKey: "fontScale"
            onSliderValueChanged: newValue => SettingsData.fontScale = newValue / 100
        }
    }

    // 5. Windows Card
    SettingsCard {
        title: "Windows"
        iconName: "window"

        SettingsToggleRow {
            iconName: "view_headline"
            text: "Title bars"
            description: "Off leaves decorations to compositor. Applies to new windows."
            settingKey: "windowTitleBars"
            checked: SettingsData.windowTitleBars
            onToggled: chk => SettingsData.windowTitleBars = chk
        }

        SettingsSliderRow {
            iconName: "opacity"
            text: "Window opacity"
            description: "Lets desktop show through. Text and controls stay solid (" + Math.round(SettingsData.floatingWindowTransparency * 100) + "%)."
            minimum: 10
            maximum: 100
            unit: "%"
            value: Math.round(SettingsData.floatingWindowTransparency * 100)
            settingKey: "floatingWindowTransparency"
            onSliderValueChanged: newValue => SettingsData.floatingWindowTransparency = newValue / 100
        }

        SettingsToggleRow {
            iconName: "layers"
            text: "Foreground layers"
            description: "Keeps cards and panes solid when window is see-through."
            settingKey: "floatingWindowForegroundLayers"
            checked: SettingsData.floatingWindowForegroundLayers
            onToggled: chk => SettingsData.floatingWindowForegroundLayers = chk
        }

        SettingsSliderRow {
            iconName: "view_agenda"
            text: "Layer opacity"
            description: "Foreground layer transparency (" + Math.round(SettingsData.floatingWindowForegroundTransparency * 100) + "%)."
            enabled: SettingsData.floatingWindowForegroundLayers
            minimum: 10
            maximum: 100
            unit: "%"
            value: Math.round(SettingsData.floatingWindowForegroundTransparency * 100)
            settingKey: "floatingWindowForegroundTransparency"
            onSliderValueChanged: newValue => SettingsData.floatingWindowForegroundTransparency = newValue / 100
        }

        SettingsToggleRow {
            iconName: "blur_on"
            text: "Background blur"
            description: "Blurs what shows through the window. Needs an opacity below 100%."
            settingKey: "blurEnabled"
            checked: SettingsData.blurEnabled
            onToggled: chk => SettingsData.blurEnabled = chk
        }

        SettingsToggleRow {
            iconName: "border_style"
            text: "Clear item separation"
            description: "Gives settings containers and cards clear visual outlines and distinct fills."
            settingKey: "settingsItemSeparation"
            checked: SettingsData.settingsItemSeparation
            onToggled: chk => SettingsData.settingsItemSeparation = chk
        }
    }

    // 5b. Sidebar Card
    SettingsCard {
        title: "Sidebar"
        iconName: "view_sidebar"

        SettingsButtonGroupRow {
            iconName: "view_sidebar"
            text: "Sidebar labels"
            description: "Choose where labels appear for sidebar navigation items"
            settingKey: "sidebarStyle"
            model: ["Icons only", "Below icons", "Next to icons"]
            currentIndex: SettingsData.sidebarStyle === "icons_only" ? 0 : (SettingsData.sidebarStyle === "below" ? 1 : 2)
            onSelectionChanged: (idx, sel) => {
                if (!sel) return;
                const styles = ["icons_only", "below", "beside"];
                SettingsData.sidebarStyle = styles[idx] || "beside";
            }
        }

        SettingsToggleRow {
            iconName: "vertical_align_center"
            text: "Center sidebar items"
            description: "Vertically center navigation items in the app sidebar (except Settings)."
            settingKey: "sidebarCentered"
            checked: SettingsData.sidebarCentered
            onToggled: chk => SettingsData.sidebarCentered = chk
        }

        SettingsToggleRow {
            iconName: "dock_to_left"
            text: "Floating sidebar"
            description: "Float the sidebar as an auto-hiding rounded panel with an edge reveal pill."
            settingKey: "sidebarFloating"
            checked: SettingsData.sidebarFloating
            onToggled: chk => SettingsData.sidebarFloating = chk
        }

        SettingsSliderRow {
            visible: SettingsData.sidebarFloating
            iconName: "timer"
            text: "Floating sidebar delay"
            description: "How quickly the floating sidebar auto-hides (" + SettingsData.sidebarAutoHideMs + " ms)"
            minimum: 300
            maximum: 4000
            step: 100
            value: SettingsData.sidebarAutoHideMs
            unit: "ms"
            onSliderValueChanged: v => SettingsData.sidebarAutoHideMs = v
        }
    }

    // 6. Motion Card
    SettingsCard {
        title: "Motion"
        iconName: "animation"

        SettingsDropdownRow {
            iconName: "speed"
            text: "Duration"
            description: "Animation speed."
            options: ["Very fast (250ms)", "Fast (375ms)", "Normal (500ms)", "Deliberate (750ms)", "Slow (1000ms)"]
            currentValue: root.motionDurationOptions[Math.max(0, Math.min(4, SettingsData.motionDuration))]?.label ?? "Normal (500ms)"
            onValueChanged: val => {
                const idx = root.motionDurationOptions.findIndex(o => o.label === val);
                if (idx >= 0) SettingsData.motionDuration = idx;
            }
        }

        SettingsButtonGroupRow {
            iconName: "sports_volleyball"
            text: "Spring bounce"
            description: "Spring physics behavior on interactive animations."
            model: ["Smooth", "Balanced", "Playful"]
            currentIndex: SettingsData.springBounce
            onSelectionChanged: (idx, sel) => {
                if (sel) SettingsData.springBounce = idx;
            }
        }

        SettingsToggleRow {
            iconName: "water_drop"
            text: "Ripple effects"
            description: "Show Material touch ripple effects when clicking controls."
            settingKey: "enableRippleEffects"
            checked: SettingsData.enableRippleEffects
            onToggled: chk => SettingsData.enableRippleEffects = chk
        }

        SettingsToggleRow {
            iconName: "motion_photos_off"
            text: "Reduce motion"
            description: "Minimize animations and spatial transitions."
            settingKey: "reduceMotion"
            checked: SettingsData.reduceMotion
            onToggled: chk => SettingsData.reduceMotion = chk
        }
    }

    // 7. Focus Ring Card
    SettingsCard {
        title: "Focus Ring"
        iconName: "filter_center_focus"

        SettingsToggleRow {
            iconName: "radio_button_checked"
            text: "Focus ring"
            description: "Visible keyboard focus highlight ring."
            settingKey: "focusRingEnabled"
            checked: SettingsData.focusRingEnabled
            onToggled: chk => SettingsData.focusRingEnabled = chk
        }

        SettingsSliderRow {
            iconName: "line_weight"
            text: "Focus ring thickness"
            description: "Focus ring outline width (" + SettingsData.focusRingWidth + "px)."
            enabled: SettingsData.focusRingEnabled
            minimum: 1
            maximum: 5
            step: 1
            unit: "px"
            value: SettingsData.focusRingWidth
            settingKey: "focusRingWidth"
            onSliderValueChanged: newValue => SettingsData.focusRingWidth = newValue
        }
    }
}
