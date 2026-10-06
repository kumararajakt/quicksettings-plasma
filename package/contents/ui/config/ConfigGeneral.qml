import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: root

    property list<string> cfg_pillOrder: []
    property string cfg_visibilityWired: "popup"
    property string cfg_visibilityBluetooth: "both"
    property string cfg_visibilityWifi: "both"
    property string cfg_visibilityVpn: "popup"
    property string cfg_visibilityPower: "popup"
    property string cfg_visibilityFan: "popup"
    property string cfg_visibilityNightLight: "popup"
    property string cfg_visibilityAwake: "popup"
    property string cfg_visibilityAirplane: "popup"
    property string cfg_visibilityDnd: "popup"
    property string cfg_visibilityMedia: "popup"
    property string cfg_visibilityNotifications: "popup"

    readonly property var pillKeys: ["wired", "bluetooth", "wifi", "vpn", "power", "fan", "nightlight", "awake", "airplane", "dnd", "media", "notifications"]

    function visibilityProp(key) {
        switch (key) {
        case "nightlight": return "cfg_visibilityNightLight";
        case "notifications": return "cfg_visibilityNotifications";
        }
        return "cfg_visibility" + key.charAt(0).toUpperCase() + key.slice(1);
    }

    function category(key) {
        switch (key) {
        case "wired": case "bluetooth": case "wifi": case "vpn": case "airplane":
            return "Hardware";
        case "power": case "fan": case "nightlight": case "awake":
            return "HardwareControl";
        case "dnd": case "notifications": case "media":
            return "Communications";
        default:
            return "Miscellaneous";
        }
    }

    function categoryName(cat) {
        switch (cat) {
        case "Hardware": return i18n("Hardware");
        case "HardwareControl": return i18n("Hardware Control");
        case "Communications": return i18n("Communications");
        case "SystemServices": return i18n("System Services");
        case "ApplicationStatus": return i18n("Application Status");
        default: return i18n("Miscellaneous");
        }
    }

    function label(key) {
        switch (key) {
        case "wired": return i18n("Wired")
        case "bluetooth": return i18n("Bluetooth")
        case "wifi": return i18n("Wi-Fi")
        case "vpn": return i18n("VPN")
        case "power": return i18n("Power Mode")
        case "fan": return i18n("Fan Curve")
        case "nightlight": return i18n("Night Light")
        case "awake": return i18n("Keep Awake")
        case "airplane": return i18n("Airplane Mode")
        case "dnd": return i18n("Do Not Disturb")
        case "media": return i18n("Media Player")
        case "notifications": return i18n("Notifications")
        }
        return key;
    }

    function movePill(from, to) {
        const keys = root.order.slice();
        keys.splice(to, 0, keys.splice(from, 1)[0]);
        cfg_pillOrder = keys;
    }

    readonly property var order: {
        const keys = [];
        const stored = cfg_pillOrder;
        if (stored && stored.length !== undefined) {
            for (const key of stored) {
                if (pillKeys.indexOf(key) !== -1 && keys.indexOf(key) === -1) {
                    keys.push(key);
                }
            }
        }
        for (const key of pillKeys) {
            if (keys.indexOf(key) === -1) {
                keys.push(key);
            }
        }

        return keys;
    }

    readonly property var visibilityOptions: [
        { text: i18n("Popup and panel"), value: "both" },
        { text: i18n("Popup only"), value: "popup" },
        { text: i18n("Panel only"), value: "panel" },
        { text: i18n("Not shown"), value: "none" },
        { text: i18n("Where relevant"), value: "auto" }
    ]

    ListView {
        id: entriesList
        model: root.order

        Layout.fillHeight: true
        Layout.fillWidth: true

        delegate: QQC2.ItemDelegate {

            id: entryItem
            width: parent.width

            Kirigami.Theme.useAlternateBackgroundColor: true

            // Don't need highlight, hover, or pressed effects
            highlighted: false
            hoverEnabled: false
            down: false

            required property int index
            required property string modelData

            contentItem: RowLayout {
                Kirigami.ListItemDragHandle {
                    listItem: entryItem
                    listView: entriesList

                    onDropped: (oldIndex, newIndex) => {
                        root.movePill(oldIndex, newIndex)

                    }
                }

                QQC2.Label {
                    id: name
                    text: root.label(entryItem.modelData)
                    Layout.fillWidth: true

                }

                QQC2.ComboBox {
                    id: visCombo
                    model: root.visibilityOptions
                    textRole: "text"; valueRole: "value"
                    currentIndex: Math.max(0, indexOfValue(root[root.visibilityProp(entryItem.modelData)]))
                    onActivated: root[root.visibilityProp(entryItem.modelData)] = currentValue
                }
            }

        }
    }


    Item {
        id: orderList
        Layout.fillWidth: true
        Layout.preferredHeight: root.order.length * orderList.rowHeight
        Layout.bottomMargin: Kirigami.Units.smallSpacing

        readonly property int rowHeight: Math.round(Kirigami.Units.gridUnit * 1.8)
        readonly property int gutter: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing

        property int heldIndex: -1
        property int dropIndex: -1
        property real grabOffset: 0
        property real heldY: 0



    }

}
