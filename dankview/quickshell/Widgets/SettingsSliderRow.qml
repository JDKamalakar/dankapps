import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets

SettingsRow {
    id: root

    property string text: ""
    property string description: ""
    property string minimumLabel: ""
    property real value: 0
    property alias minimum: slider.minimum
    property alias maximum: slider.maximum
    property alias step: slider.step
    property alias showStops: slider.showStops
    property alias unit: slider.unit
    property alias decimals: slider.decimals

    readonly property bool atMinimum: minimumLabel !== "" && slider.value === slider.minimum
    readonly property int stepAmount: Math.max(1, step)

    signal sliderValueChanged(int newValue)

    function nudge(direction) {
        const next = Math.max(minimum, Math.min(maximum, slider.value + direction * stepAmount));
        if (next === slider.value)
            return;
        slider.value = next;
        sliderValueChanged(next);
    }

    title: text
    subtitle: description
    onValueChanged: slider.value = Math.round(value)

    body: RowLayout {
        width: parent.width
        spacing: Theme.spacingM

        DActionButton {
            buttonSize: Theme.iconButtonSize
            iconName: "remove"
            Accessible.name: I18n.tr("Decrease", "slider row step down button")
            iconSize: Theme.iconSizeMedium
            iconColor: Theme.surfaceVariantText
            enabled: root.enabled && slider.value > slider.minimum
            Layout.alignment: Qt.AlignVCenter
            onClicked: root.nudge(-1)
        }

        DSlider {
            id: slider
            Accessible.name: root.text
            Accessible.description: root.description
            size: "s"
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            enabled: root.enabled
            wheelEnabled: false
            showValue: false
            Component.onCompleted: value = Math.round(root.value)
            onSliderValueChanged: newValue => root.sliderValueChanged(newValue)
        }

        DActionButton {
            buttonSize: Theme.iconButtonSize
            iconName: "add"
            Accessible.name: I18n.tr("Increase", "slider row step up button")
            iconSize: Theme.iconSizeMedium
            iconColor: Theme.surfaceVariantText
            enabled: root.enabled && slider.value < slider.maximum
            Layout.alignment: Qt.AlignVCenter
            onClicked: root.nudge(1)
        }

        Rectangle {
            id: valuePill
            width: 64
            height: 32
            color: Theme.surfaceContainerHigh
            radius: height / 2
            border.color: valInput.activeFocus ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
            border.width: 1
            Layout.alignment: Qt.AlignVCenter
            opacity: root.enabled ? 1.0 : 0.4

            TextInput {
                id: valInput
                anchors.fill: parent
                anchors.margins: 4
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                enabled: root.enabled
                text: activeFocus ? slider.value.toString() : (root.atMinimum ? root.minimumLabel : (slider.value + (root.unit ? root.unit : "")))
                selectByMouse: true

                onEditingFinished: {
                    var cleanText = text.replace(/[^0-9.-]/g, "").trim();
                    var parsed = parseInt(cleanText, 10);
                    if (!isNaN(parsed)) {
                        var clamped = Math.max(slider.minimum, Math.min(slider.maximum, parsed));
                        slider.value = clamped;
                        root.sliderValueChanged(clamped);
                    }
                    valInput.focus = false;
                }

                onAccepted: {
                    editingFinished();
                }
            }
        }
    }
}
