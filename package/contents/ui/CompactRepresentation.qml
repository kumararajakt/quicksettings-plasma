import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.workspace.components as WorkspaceComponents

// The button in the panel: battery icon plus percentage, in place of a static
// settings cog. Machines with no battery always show the cog. Scrolling over
// it steps the screen brightness.
MouseArea {
    id: compact

    required property var app

    readonly property var config: Plasmoid.configuration
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool hasBattery: app.battery.present
    readonly property bool showBatteryIcon: hasBattery && config.panelShowBatteryIcon
    // No room for text beside the icon in a vertical panel.
    readonly property bool showLabel: hasBattery && config.panelShowPercentage && !vertical

    readonly property bool showTrayIcons: config.panelShowTrayIcons && app.tray.available
    readonly property var trayItems: showTrayIcons ? app.tray.items : []

    readonly property bool showPrivacy: config.panelShowPrivacy && app.privacy.active.length > 0

    readonly property int iconSize: Kirigami.Units.iconSizes.roundedIconSize(
        Math.min(Kirigami.Units.iconSizes.medium, vertical ? width : height))

    Layout.minimumWidth: vertical ? 0 : row.implicitWidth + Kirigami.Units.smallSpacing * 2
    Layout.preferredWidth: Layout.minimumWidth
    Layout.minimumHeight: vertical ? iconSize : 0

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton

    // Read on press, not on click: by the time the click lands the popup has
    // already closed itself on losing focus, and toggling would reopen it.
    property bool wasExpanded: false
    onPressed: wasExpanded = app.expanded
    onClicked: app.expanded = !wasExpanded

    // Touchpads send many small deltas; act once per notch's worth.
    property int wheelDelta: 0
    onWheel: wheel => {
        wheelDelta += wheel.angleDelta.y;
        while (Math.abs(wheelDelta) >= 120) {
            const up = wheelDelta > 0;
            wheelDelta += up ? -120 : 120;
            app.brightness.stepAll(up ? 0.05 : -0.05);
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing

        WorkspaceComponents.BatteryIcon {
            visible: compact.showBatteryIcon
            Layout.preferredWidth: compact.iconSize
            Layout.preferredHeight: compact.iconSize
            hasBattery: true
            percent: compact.app.battery.percent
            pluggedIn: compact.app.battery.pluggedIn
        }

        Kirigami.Icon {
            visible: !compact.showBatteryIcon
            Layout.preferredWidth: compact.iconSize
            Layout.preferredHeight: compact.iconSize
            source: "preferences-system-symbolic"
            active: compact.containsMouse
        }

        PlasmaComponents.Label {
            visible: compact.showLabel
            text: i18nc("battery percentage", "%1%", compact.app.battery.percent)
            textFormat: Text.PlainText
        }

        // Privacy and keyboard state, sitting beside the tray. Not controls:
        // the icons only report, and the clicks are swallowed so they do not
        // open the popup behind them.
        MouseArea {
            id: privacyArea

            visible: compact.showPrivacy
            Layout.preferredWidth: privacyRow.implicitWidth
            Layout.preferredHeight: compact.iconSize
            Layout.alignment: Qt.AlignVCenter
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

            PlasmaComponents.ToolTip {
                text: compact.app.privacy.active.join(" · ")
                visible: privacyArea.containsMouse
            }

            RowLayout {
                id: privacyRow

                anchors.centerIn: parent
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    visible: compact.app.privacy.cameraInUse
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: compact.iconSize
                    Layout.preferredHeight: compact.iconSize
                    source: "camera-on-symbolic"
                    active: privacyArea.containsMouse
                }
                Kirigami.Icon {
                    visible: compact.app.privacy.micInUse
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: compact.iconSize
                    Layout.preferredHeight: compact.iconSize
                    source: "audio-input-microphone-symbolic"
                    active: privacyArea.containsMouse
                }
                Kirigami.Icon {
                    visible: compact.app.privacy.screenInUse
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: compact.iconSize
                    Layout.preferredHeight: compact.iconSize
                    source: "camera-video-symbolic"
                    active: privacyArea.containsMouse
                }

                Kirigami.Icon {
                    visible: compact.app.privacy.capsLock
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: compact.iconSize
                    Layout.preferredHeight: compact.iconSize
                    source: "input-caps-on-symbolic"
                    active: privacyArea.containsMouse
                }
                Kirigami.Icon {
                    visible: compact.app.privacy.numLock
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: compact.iconSize
                    Layout.preferredHeight: compact.iconSize
                    // Breeze drops the symbolic Num Lock icon but still paints
                    // this one in the text colour, so it recolours like the rest.
                    source: "input-num-on"
                    isMask: true
                    active: privacyArea.containsMouse
                }
            }
        }

        Repeater {
            model: compact.trayItems

            delegate: MouseArea {
                id: trayArea

                required property var modelData
                readonly property var item: modelData
                readonly property string iconName: item ? item.activeIconName : ""
                readonly property string iconPixmap: item
                        ? item.iconUrlFor(compact.iconSize) : ""

                Layout.preferredWidth: compact.iconSize
                Layout.preferredHeight: compact.iconSize
                Layout.alignment: Qt.AlignVCenter
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                Accessible.name: item ? (item.title !== "" ? item.title : item.id) : ""
                Accessible.role: Accessible.Button

                onClicked: mouse => {
                    if (!trayArea.item) {
                        return;
                    }
                    if (mouse.button === Qt.RightButton
                            || (mouse.button === Qt.LeftButton && trayArea.item.itemIsMenu)) {
                        compact.app.tray.requestMenu(trayArea.item, trayArea);
                    } else if (mouse.button === Qt.MiddleButton) {
                        compact.app.tray.secondaryActivate(trayArea.item);
                    } else {
                        compact.app.tray.activate(trayArea.item);
                    }
                }

                onWheel: wheel => {
                    wheel.accepted = false;
                    if (trayArea.item) {
                        compact.app.tray.scroll(trayArea.item, wheel.angleDelta.y, false);
                    }
                }

                Kirigami.Icon {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: trayArea.iconName
                    fallback: "application-x-executable-symbolic"
                    active: trayArea.containsMouse
                }

                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: trayArea.iconPixmap
                    sourceSize.width: compact.iconSize
                    sourceSize.height: compact.iconSize
                    fillMode: Image.PreserveAspectFit
                    opacity: trayArea.containsMouse ? 0.7 : 1.0
                }
            }
        }
    }
}
