import QtQuick
import org.kde.pipewire.monitor as PipeWire
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator

Item {
    id: privacy

    visible: false

    readonly property bool cameraInUse: cameraMonitor.runningCount > 0
    readonly property bool micInUse: micMonitor.runningCount > 0
    readonly property bool screenInUse: screenMonitor.runningCount > 0

    readonly property bool capsLock: capsKey.locked
    readonly property bool numLock: numKey.locked

    readonly property bool anyInUse: cameraInUse || micInUse || screenInUse

    readonly property var active: {
        let names = [];
        if (cameraInUse) {
            names.push(i18n("Camera in use"));
        }
        if (micInUse) {
            names.push(i18n("Microphone in use"));
        }
        if (screenInUse) {
            names.push(i18n("Screen being recorded"));
        }
        if (capsLock) {
            names.push(i18n("Caps Lock on"));
        }
        if (numLock) {
            names.push(i18n("Num Lock on"));
        }
        return names;
    }

    PipeWire.MediaMonitor {
        id: cameraMonitor
        role: PipeWire.MediaRole.Camera
    }
    PipeWire.MediaMonitor {
        id: micMonitor
        role: PipeWire.MediaRole.Communication
    }
    PipeWire.MediaMonitor {
        id: screenMonitor
        role: PipeWire.MediaRole.Screen
    }

    KeyboardIndicator.KeyState {
        id: capsKey
        key: Qt.Key_CapsLock
    }
    KeyboardIndicator.KeyState {
        id: numKey
        key: Qt.Key_NumLock
    }
}
