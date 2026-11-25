import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets
import qs.Widgets

Item {
    id: root

    property int currentIndex: 0
    property string searchQuery: ""

    Loader {
        id: pageLoader
        anchors.fill: parent
        sourceComponent: {
            switch (root.currentIndex) {
            case 0:
                return appearancePage;
            case 1:
                return playbackPage;
            case 2:
                return libraryPage;
            case 3:
                return aboutPage;
            default:
                return appearancePage;
            }
        }

        opacity: 1.0
        Behavior on opacity {
            enabled: Theme.animationsEnabled
            NumberAnimation {
                duration: Theme.mediumDuration ?? 200
                easing.bezierCurve: Theme.expressiveCurves.expressiveSpatial ?? Theme.expressiveCurves.standard
            }
        }
        Behavior on y {
            enabled: Theme.animationsEnabled
            NumberAnimation {
                duration: Theme.mediumDuration ?? 200
                easing.bezierCurve: Theme.expressiveCurves.expressiveSpatial ?? Theme.expressiveCurves.standard
            }
        }
    }

    property int _prevIndex: 0

    onCurrentIndexChanged: {
        const goingDown = currentIndex > _prevIndex;
        _prevIndex = currentIndex;
        pageLoader.opacity = 0.0;
        pageLoader.y = goingDown ? 16 : -16;
        pageSwitchTimer.restart();
    }

    Timer {
        id: pageSwitchTimer
        interval: 20
        repeat: false
        onTriggered: {
            pageLoader.opacity = 1.0;
            pageLoader.y = 0;
        }
    }

    Component {
        id: appearancePage

        SettingsPage {
            SettingsAppearanceCard {}
        }
    }

    Component {
        id: playbackPage

        SettingsPage {
            SettingsCard {
                title: "Controls & display"
                iconName: "play_circle"

                SettingsToggleRow {
                    iconName: "visibility_off"
                    text: "Auto-hide controls"
                    description: "Automatically hide header and playback bar when idle"
                    checked: SettingsData.autoHideControls
                    onToggled: chk => SettingsData.autoHideControls = chk
                }

                SettingsButtonGroupRow {
                    iconName: "folder_open"
                    text: "External video open"
                    description: "Behavior when opening a video from file manager in a folder with multiple videos"
                    model: ["Ask", "Play all", "Selected only"]
                    currentIndex: {
                        switch (SettingsData.externalOpenFolderBehavior) {
                        case "all": return 1;
                        case "single": return 2;
                        default: return 0;
                        }
                    }
                    onSelectionChanged: (idx, sel) => {
                        if (sel) {
                            const modes = ["ask", "all", "single"];
                            SettingsData.externalOpenFolderBehavior = modes[idx];
                        }
                    }
                }

                SettingsButtonGroupRow {
                    iconName: "video_library"
                    text: "Library play mode"
                    description: "Playback behavior when clicking a video from the library All tab"
                    model: ["Single video", "Play all"]
                    currentIndex: SettingsData.libraryOpenBehavior === "all" ? 1 : 0
                    onSelectionChanged: (idx, sel) => {
                        if (sel) {
                            SettingsData.libraryOpenBehavior = idx === 1 ? "all" : "single";
                        }
                    }
                }

                SettingsButtonGroupRow {
                    iconName: "tab"
                    text: "Default player tab"
                    description: "Default section opened when launching the video library"
                    model: ["All", "Playlists", "Albums"]
                    currentIndex: {
                        switch (SettingsData.libraryDefaultTab) {
                        case "playlists": return 1;
                        case "folders": return 2;
                        default: return 0;
                        }
                    }
                    onSelectionChanged: (idx, sel) => {
                        if (sel) {
                            const tabs = ["all", "playlists", "folders"];
                            SettingsData.libraryDefaultTab = tabs[idx];
                        }
                    }
                }

                SettingsToggleRow {
                    iconName: "rounded_corner"
                    text: "Rounded video corners"
                    description: "Apply resolution-normalized rounded corners during video playback"
                    checked: SettingsData.videoPlayerRoundedCorners
                    onToggled: chk => SettingsData.videoPlayerRoundedCorners = chk
                }

                SettingsToggleRow {
                    iconName: "bolt"
                    text: "Show quick access in sidebar"
                    description: "Display quick access albums in the video library sidebar"
                    checked: SettingsData.showFavoriteAlbumsInSidebar
                    onToggled: chk => SettingsData.showFavoriteAlbumsInSidebar = chk
                }
            }
        }
    }

    Component {
        id: libraryPage

        SettingsPage {
            SettingsCard {
                title: "Manage folders"
                iconName: "folder_managed"

                SettingsRow {
                    title: "Add folder to library"
                    subtitle: "Choose a directory to scan and display in video library"
                    iconName: "create_new_folder"
                    clickable: true
                    showChevron: true
                    onClicked: {
                        VideoService.openAddFolderDialog()
                    }
                }

                Repeater {
                    model: VideoService.watchedFolders || []

                    SettingsRow {
                        required property string modelData
                        required property int index

                        title: modelData.split('/').pop() || modelData
                        subtitle: modelData
                        iconName: "folder"

                        DActionButton {
                            iconName: "delete"
                            tooltipText: "Remove from library"
                            Accessible.name: "Remove folder"
                            onClicked: VideoService.removeWatchedFolder(modelData)
                        }
                    }
                }
            }

            SettingsCard {
                title: "Maintenance"
                iconName: "build"

                SettingsRow {
                    title: "Rescan watched library"
                    subtitle: "Scan all directories now to discover newly added or modified videos"
                    iconName: "refresh"
                    clickable: true
                    onClicked: VideoService.rescan()

                    DButton {
                        text: "Rescan"
                        onClicked: VideoService.rescan()
                    }
                }
            }
        }
    }

    Component {
        id: aboutPage

        SettingsPage {
            spacing: Theme.spacingL

            DHeroCard {
                brand: "DUX Video Player"
                caption: "Part of the Dux Shell ecosystem."

                DButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Support Dux Labs"
                    iconName: "favorite"
                    backgroundColor: Theme.primary
                    textColor: Theme.onPrimary
                    onClicked: Qt.openUrlExternally("https://ko-fi.com/duxlabs")
                }
            }

            DCard {
                width: parent.width
                height: aboutText.implicitHeight + pad * 2
                pad: Theme.spacingL
                restRadius: Theme.groupedListOuterRadius
                color: SettingsMetrics.rowColor

                StyledText {
                    id: aboutText
                    width: parent.width
                    text: 'DUX Video Player is a hardware-accelerated video player utility for the modern Linux desktop with a <a href="https://m3.material.io/" style="text-decoration:none; color:%1;">material 3 inspired</a> design, part of the Dux Shell ecosystem.<br /><br />Built with <a href="https://quickshell.org" style="text-decoration:none; color:%1;">Quickshell</a> and <a href="https://go.dev" style="text-decoration:none; color:%1;">Go</a>.'.arg(Theme.primary)
                    textFormat: Text.RichText
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    linkColor: Theme.primary
                    wrapMode: Text.WordWrap
                    onLinkActivated: url => Qt.openUrlExternally(url)
                }
            }

            SettingsGroup {
                width: parent.width

                Repeater {
                    model: [
                        { icon: "menu_book", accent: "blue", title: "Docs", subtitle: "duxlabs.dev/docs", url: "https://duxlabs.dev/docs" },
                        { icon: "code", accent: "purple", title: "GitHub", subtitle: "github.com/JDKamalakar/dankapps", url: "https://github.com/JDKamalakar/dankapps" },
                        { icon: "gavel", accent: "green", title: "License", subtitle: "MIT License", url: "https://github.com/JDKamalakar/dankapps/blob/master/LICENSE" }
                    ]

                    SettingsRow {
                        id: aboutLinkRow
                        required property var modelData
                        required property int index

                        width: parent.width
                        iconName: modelData.icon
                        accent: modelData.accent
                        title: modelData.title
                        subtitle: modelData.subtitle
                        clickable: true
                        isFirstInGroup: index === 0
                        isLastInGroup: index === 2
                        onClicked: Qt.openUrlExternally(aboutLinkRow.modelData.url)

                        DIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "open_in_new"
                            size: Theme.iconSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                }
            }
        }
    }
}
