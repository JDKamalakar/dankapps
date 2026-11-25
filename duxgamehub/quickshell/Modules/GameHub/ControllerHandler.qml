// ControllerHandler.qml
// Listens for the gamepad HOME button (via QtGamepad) and emits launchRequested.
// Requires the controllerHomeEnabled setting to be true before reacting.

import QtQuick

Item {
    id: controllerRoot

    // Whether controller Home button triggering is enabled (driven by settings toggle)
    property bool enabled: false

    // Emitted when the controller's Home/Guide button is pressed while enabled
    signal launchRequested()

    // Poll the gamepad state via a timer (QtGamepad module may not be available in all envs;
    // we guard all access with typeof checks for safe fallback)
    Timer {
        id: gamepadPollTimer
        interval: 100
        repeat: true
        running: controllerRoot.enabled

        property bool wasHomePressed: false

        onTriggered: {
            // Qt Gamepad API: Gamepad is in QtGamepad 1.0 (Qt 5) or qt.gamepad (Qt 6)
            // We attempt to access via the global Gamepad attached object if available
            var gp = null;
            if (typeof GamepadManager !== "undefined" && GamepadManager !== null) {
                var ids = GamepadManager.connectedGamepads;
                if (ids && ids.length > 0) {
                    // We use the first connected gamepad
                    gp = Qt.createQmlObject(
                        'import QtGamepad 1.0; Gamepad { deviceId: ' + ids[0] + ' }',
                        controllerRoot, "DynamicGamepad"
                    );
                }
            }

            // If we cannot query the gamepad dynamically, skip
            if (!gp) {
                return;
            }

            var homeNow = gp.buttonGuide || false;
            if (homeNow && !gamepadPollTimer.wasHomePressed) {
                // Rising edge: button just pressed
                if (controllerRoot.enabled) {
                    controllerRoot.launchRequested();
                }
            }
            gamepadPollTimer.wasHomePressed = homeNow;
            gp.destroy();
        }
    }

    // Alternative: use a persistent Gamepad loader so we don't create/destroy each tick
    Loader {
        id: gamepadLoader
        active: controllerRoot.enabled
        sourceComponent: gamepadComponent
    }

    Component {
        id: gamepadComponent

        QtObject {
            id: gpObj

            // Try to load Gamepad via dynamic import
            property var _gp: null
            property bool _homeWasPressed: false

            Component.onCompleted: {
                // Stop the polling timer since we have a persistent object
                gamepadPollTimer.stop();
                _tryCreateGamepad();
            }

            function _tryCreateGamepad() {
                try {
                    var gp = Qt.createQmlObject(
                        'import QtGamepad 1.15; Gamepad { id: gp0; deviceId: GamepadManager.connectedGamepads.length > 0 ? GamepadManager.connectedGamepads[0] : -1 }',
                        controllerRoot, "PersistentGamepad"
                    );
                    if (gp) {
                        _gp = gp;
                        _gp.buttonGuideChanged.connect(function() {
                            var pressed = _gp.buttonGuide;
                            if (pressed && !_homeWasPressed) {
                                if (controllerRoot.enabled) {
                                    controllerRoot.launchRequested();
                                }
                            }
                            _homeWasPressed = pressed;
                        });
                    }
                } catch(e) {
                    // QtGamepad not available; fall back to polling timer
                    gamepadPollTimer.start();
                }
            }

            Component.onDestruction: {
                if (_gp) {
                    _gp.destroy();
                    _gp = null;
                }
            }
        }
    }
}
