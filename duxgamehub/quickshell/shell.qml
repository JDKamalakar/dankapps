//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_WAYLAND_DISABLE_WINDOWDECORATION=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Material
//@ pragma UseQApplication
//@ pragma AppId dev.duxlabs.duxgamehub

import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.GameHub
import qs.DCommon.Common as DC

ShellRoot {
    id: root

    Connections {
        target: Quickshell
        function onLastWindowClosed() {
            Qt.quit()
        }
    }

    Component.onCompleted: {
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.Paths.backend = Paths;
        DC.Host.ownWindowDecorations = Qt.binding(() => SettingsData.windowTitleBars);
        Qt.callLater(() => {
            if (hubWidget && hubWidget.openFullscreenApp) {
                hubWidget.openFullscreenApp();
            }
        });
    }

    GameHubWidget {
        id: hubWidget
        visible: false
    }

    SettingsModal {
        id: appSettingsModal
    }
}
