import QtQuick
import qs.Common
import qs.DCommon.Widgets

Item {
    id: root

    property int currentIndex: 0
    property int highlightIndex: -1
    property var matchCounts: []
    property bool fieldOnly: false
    property alias query: searchField.text
    readonly property var tabKeywords: [
        "theme mode color source preset custom radius strength shape density spacious comfortable compact dense typography font scale weight title bar opacity transparency foreground layers blur separation sidebar center motion duration bounce ripple reduce focus ring thickness",
        "scientific keypad expanded angle unit radians degrees",
        "about version license github repository dux"
    ]

    onQueryChanged: {
        SettingsData.activeSettingsSearch = query;
        const q = query.trim().toLowerCase();
        if (!q) { matchCounts = []; return; }
        const counts = []; let firstMatch = -1;
        for (let g = 0; g < groups.length; g++) {
            for (let t = 0; t < groups[g].length; t++) {
                const tab = groups[g][t];
                const kw = (tabKeywords[tab.index] || "").toLowerCase();
                const c = kw.indexOf(q) !== -1 ? 1 : 0;
                counts[tab.index] = c;
                if (c > 0 && firstMatch < 0) firstMatch = tab.index;
            }
        }
        matchCounts = counts;
        if ((counts[currentIndex] || 0) === 0 && firstMatch >= 0) tabSelected(firstMatch);
    }

    signal tabSelected(int index)
    signal searchAccepted

    function focusSearch() {
        searchField.forceActiveFocus();
    }

    function clearSearch() {
        if (searchField.text === "")
            return false;
        searchField.text = "";
        return true;
    }

    function tabOrder() {
        return groups.reduce((all, group) => all.concat(group.map(tab => tab.index)), []);
    }

    function moveHighlight(delta) {
        const order = tabOrder();
        let position = order.indexOf(highlightIndex);
        if (position < 0)
            position = order.indexOf(currentIndex);
        highlightIndex = order[(position + delta + order.length) % order.length];
    }

    function selectHighlighted() {
        if (highlightIndex < 0)
            return false;
        tabSelected(highlightIndex);
        highlightIndex = -1;
        return true;
    }

    function clearHighlight() {
        if (highlightIndex < 0)
            return false;
        highlightIndex = -1;
        return true;
    }

        readonly property var groups: [[
            {
                accent: "blue",
                index: 0,
                label: "Calculator",
                hint: "Angle unit and history",
                icon: "calculate"
            },
            {
                accent: "blue",
                index: 1,
                label: "Appearance",
                hint: "Theme, shape and motion",
                icon: "palette"
            }
        ], [
            {
                accent: "purple",
                index: 2,
                label: "About",
                hint: "Version and links",
                icon: "info"
            }
        ]]

    implicitWidth: SettingsMetrics.sidebarWidth
    implicitHeight: fieldOnly ? searchField.height + navColumn.padding * 2 : 0

    DFlickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: navColumn.height

        Column {
            id: navColumn
            width: parent.width
            padding: SettingsMetrics.paneMargin
            spacing: SettingsMetrics.sidebarGroupGap

            Item {
                width: navColumn.width - navColumn.padding * 2
                height: searchField.height + SettingsMetrics.searchBarGap - navColumn.spacing

                DSearchField {
                    id: searchField

                    width: parent.width
                    placeholderText: I18n.tr("Search settings", "placeholder in the settings search field")
                    onAccepted: root.searchAccepted()
                }
            }

            Repeater {
                model: root.fieldOnly ? [] : root.groups

                Column {
                    id: groupColumn
                    required property var modelData
                    width: navColumn.width - navColumn.padding * 2
                    spacing: Theme.groupedListGap

                    Repeater {
                        model: groupColumn.modelData

                        SettingsSidebarItem {
                            required property var modelData
                            required property int index
                            width: groupColumn.width
                            iconName: modelData.icon
                            title: modelData.label
                            hint: modelData.hint
                            accent: modelData.accent
                            active: root.currentIndex === modelData.index
                            highlighted: root.highlightIndex === modelData.index
                            matchCount: root.matchCounts[modelData.index] ?? -1
                            isFirstInGroup: index === 0
                            isLastInGroup: index === groupColumn.modelData.length - 1
                            onActiveFocusChanged: {
                                if (activeFocus)
                                    root.highlightIndex = modelData.index;
                            }
                            Keys.onReturnPressed: event => event.accepted = root.selectHighlighted()
                            Keys.onEnterPressed: event => event.accepted = root.selectHighlighted()
                            Keys.onSpacePressed: event => event.accepted = root.selectHighlighted()
                            onClicked: {
                                root.highlightIndex = -1;
                                if ((SettingsData.activeSettingsSearch || "").trim() !== "" && (root.matchCounts[modelData.index] || 0) === 0) {
                                    root.clearSearch();
                                }
                                root.tabSelected(modelData.index);
                            }
                        }
                    }
                }
            }
        }
    }
}
