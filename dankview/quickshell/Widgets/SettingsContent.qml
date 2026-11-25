import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Services
import qs.DCommon.Common
import qs.DCommon.Widgets

Item {
    id: root

    property int currentIndex: 0
    property string searchQuery: ""
    readonly property var currentFlickable: pageLoader.item

    readonly property var landingPageItems: {
        const items = [
            { key: "gallery", label: "Timeline", icon: "timeline" },
            { key: "favorites", label: "Favorites", icon: "favorite" },
            { key: "albums", label: "Albums", icon: "collections_bookmark" }
        ];
        const folders = (ImageService.quickAccessFolderAlbums || []).concat(ImageService.folderAlbums || []);
        for (let i = 0; i < folders.length; i++) {
            const name = folders[i] && folders[i].name;
            if (name && !items.some(it => it.key === "qa:" + name))
                items.push({ key: "qa:" + name, label: name, icon: "folder" });
        }
        return items;
    }

    readonly property var landingPageOptions: landingPageItems.map(item => item.label)

    readonly property var landingPageIconMap: {
        const map = {};
        for (let i = 0; i < landingPageItems.length; i++) {
            map[landingPageItems[i].label] = landingPageItems[i].icon;
        }
        return map;
    }

    readonly property string landingPageCurrentLabel: {
        const currentKey = SettingsData.galleryLandingPage || "gallery";
        for (let i = 0; i < landingPageItems.length; i++) {
            if (landingPageItems[i].key === currentKey) {
                return landingPageItems[i].label;
            }
        }
        return "Timeline";
    }

    function setLandingPageFromLabel(label) {
        for (let i = 0; i < landingPageItems.length; i++) {
            if (landingPageItems[i].label === label) {
                SettingsData.galleryLandingPage = landingPageItems[i].key;
                return;
            }
        }
        SettingsData.galleryLandingPage = "gallery";
    }

    Loader {
        id: pageLoader
        anchors.fill: parent
        sourceComponent: {
            switch (root.currentIndex) {
            case 0:
                return appearancePage;
            case 1:
                return viewerPage;
            case 2:
                return galleryPage;
            case 3:
                return libraryPage;
            case 4:
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
        id: viewerPage

        SettingsPage {
            SettingsCard {
                title: "Controls & display"
                iconName: "display_settings"

                SettingsToggleRow {
                    iconName: "visibility_off"
                    text: "Auto-hide controls"
                    description: "Automatically hide header and action bar when idle"
                    checked: SettingsData.autoHideControls
                    onToggled: chk => SettingsData.autoHideControls = chk
                }

                SettingsToggleRow {
                    iconName: "grid_on"
                    text: "Transparent backdrop"
                    description: "Display transparency checkerboard pattern for transparent images"
                    checked: SettingsData.showCheckerboard
                    onToggled: chk => SettingsData.showCheckerboard = chk
                }
            }
        }
    }

    Component {
        id: galleryPage

        SettingsPage {
            SettingsCard {
                title: "Navigation"
                iconName: "explore"

                SettingsDropdownRow {
                    iconName: "home"
                    text: "Startup landing page"
                    description: "Choose which section or folder opens when launching the gallery"
                    options: root.landingPageOptions
                    currentValue: root.landingPageCurrentLabel
                    dropdownWidth: 240
                    onValueChanged: val => root.setLandingPageFromLabel(val)
                }

                SettingsToggleRow {
                    iconName: "videocam"
                    text: "Include videos in gallery"
                    description: "Scan and display video files alongside photos in timeline and albums"
                    checked: SettingsData.galleryScanVideos
                    onToggled: chk => {
                        SettingsData.galleryScanVideos = chk;
                        ImageService.rescan();
                    }
                }

                SettingsToggleRow {
                    iconName: "bolt"
                    text: "Show quick access in sidebar"
                    description: "Display pinned albums as quick access shortcuts in the gallery sidebar"
                    checked: SettingsData.showQuickAccessInSidebar
                    onToggled: chk => SettingsData.showQuickAccessInSidebar = chk
                }
            }

            SettingsCard {
                title: "Layout"
                iconName: "grid_view"

                SettingsToggleRow {
                    iconName: "dashboard"
                    text: "Dynamic grid layout"
                    description: "Arrange thumbnails dynamically by aspect ratio (like Google Photos) instead of uniform squares"
                    checked: SettingsData.galleryThumbnailLayout === "masonry"
                    onToggled: chk => {
                        SettingsData.setGalleryThumbnailLayout(chk ? "dynamic" : "square");
                    }
                }

                SettingsSliderRow {
                    iconName: "photo_size_select_actual"
                    text: "Grid item size"
                    description: "Size of thumbnails displayed in timeline and albums (" + SettingsData.galleryItemSize + "px)"
                    minimum: 80
                    maximum: 280
                    step: 20
                    value: SettingsData.galleryItemSize
                    unit: "px"
                    onSliderValueChanged: newValue => SettingsData.galleryItemSize = newValue
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
                    subtitle: "Choose a directory to scan and display in gallery and albums"
                    iconName: "create_new_folder"
                    clickable: true
                    showChevron: true
                    onClicked: {
                        ImageService.openAddFolderDialog();
                    }
                }

                Repeater {
                    model: ImageService.watchedFolders || []

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
                            onClicked: ImageService.removeWatchedFolder(modelData)
                        }
                    }
                }
            }

            SettingsCard {
                title: "Maintenance"
                iconName: "build"

                SettingsRow {
                    title: "Rescan watched library"
                    subtitle: "Scan all directories now to discover newly added or modified images"
                    iconName: "refresh"
                    clickable: true
                    onClicked: ImageService.rescan()

                    DButton {
                        text: "Rescan"
                        
                        
                        onClicked: ImageService.rescan()
                    }
                }

                SettingsRow {
                    title: "Clear thumbnail cache"
                    subtitle: "Delete generated disk thumbnails to reclaim storage space"
                    iconName: "cached"
                    clickable: true
                    onClicked: ImageService.clearCache()

                    DButton {
                        text: "Clear"
                        
                        
                        onClicked: ImageService.clearCache()
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
                brand: "DUX Galary"
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
                    text: 'DUX Galary is an image viewer and gallery for the modern Linux desktop with a <a href="https://m3.material.io/" style="text-decoration:none; color:%1;">material 3 inspired</a> design, featuring fast pan and zoom, gallery navigation, and album management.<br /><br />It is built with <a href="https://quickshell.org" style="text-decoration:none; color:%1;">Quickshell</a>, a QT6 framework for building desktop shells, and <a href="https://go.dev" style="text-decoration:none; color:%1;">Go</a>, a statically typed, compiled programming language.'.arg(Theme.primary)
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
                        { icon: "code", accent: "purple", title: "GitHub", subtitle: "github.com/JD-Danklinux/dankapps", url: "https://github.com/JD-Danklinux/dankapps" },
                        { icon: "gavel", accent: "green", title: "License", subtitle: "MIT License", url: "https://github.com/JD-Danklinux/dankapps/blob/master/LICENSE" }
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
