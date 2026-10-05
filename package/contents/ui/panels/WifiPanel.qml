import QtQuick
import QtQuick.Layouts
import org.kde.plasma.networkmanagement as PlasmaNM
import "../components"

PanelBody {
    id: body

    title: i18n("Wi-Fi")
    iconName: "network-wireless-symbolic"
    footerText: i18n("Wi-Fi Settings")
    settingsModule: "kcm_networkmanagement"
    busy: app.network.scanning

    // How many networks to list; the panel scrolls. The model is already
    // sorted with the connected one first and the rest by signal, and merges
    // the per-band, per-AP duplicates of one SSID, so this is the best few.
    readonly property int limit: 12

    // Rescan when the panel is open rather than as it opens, so results
    // arriving do not reshuffle the list under the animation.
    function opened() {
        app.network.requestScan();
    }

    Repeater {
        id: list
        model: body.app.network.wifiConnections
        // A flat's worth of access points can be dozens of rows; only the
        // ones that show are worth building.
        delegate: Loader {
            id: slot

            required property var model
            required property int index

            Layout.fillWidth: true
            active: index < body.limit
            visible: active
            sourceComponent: PanelRow {
                readonly property bool up: slot.model.ConnectionState === PlasmaNM.Enums.Activated

                style: body.style
                iconName: app.network.signalIcon(slot.model.Signal)
                label: slot.model.ItemUniqueName ?? ""
                busy: slot.model.ConnectionState === PlasmaNM.Enums.Activating
                      || slot.model.ConnectionState === PlasmaNM.Enums.Deactivating
                actionText: up ? i18n("Disconnect") : i18n("Connect")
                onActivated: body.app.network.setConnection(slot.model, !up)
            }
        }
    }

    PanelNote {
        style: body.style
        visible: list.count === 0
        text: body.app.network.wifiEnabled ? i18n("No networks found") : i18n("Wi-Fi is switched off")
    }
}
