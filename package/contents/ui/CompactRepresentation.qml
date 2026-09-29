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

        Repeater {
            model: compact.trayItems

            delegate: MouseArea {
                id: trayArea

                required property var modelData
                readonly property var item: modelData

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
                    source: trayArea.item && trayArea.item.iconThemeName !== ""
                            ? trayArea.item.iconThemeName : (trayArea.item ? String(trayArea.item.iconUrl) : "")
                    fallback: "application-x-executable-symbolic"
                    active: trayArea.containsMouse
                }
            }
        }
    }
}
