import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: root

    property list<string> cfg_pillOrder: []

    // One flag per pill, named after its key in pillKeys. The rows are
    // delegates, so they cannot each own the checkbox the KCM has to save.
    property bool shownWired: true
    property bool shownBluetooth: true
    property bool shownWifi: true
    property bool shownVpn: true
    property bool shownPower: true
    property bool shownFan: true
    property bool shownNightlight: true
    property bool shownAwake: true
    property bool shownAirplane: true
    property bool shownDnd: true

    property alias cfg_showWired: root.shownWired
    property alias cfg_showBluetooth: root.shownBluetooth
    property alias cfg_showWifi: root.shownWifi
    property alias cfg_showVpn: root.shownVpn
    property alias cfg_showPower: root.shownPower
    property alias cfg_showFan: root.shownFan
    property alias cfg_showNightLight: root.shownNightlight
    property alias cfg_showAwake: root.shownAwake
    property alias cfg_showAirplane: root.shownAirplane
    property alias cfg_showDnd: root.shownDnd
    property alias cfg_showMedia: showMedia.checked
    property alias cfg_showNotifications: showNotifications.checked
    property alias cfg_bodyToggles: bodyToggles.checked

    readonly property var pillKeys: ["wired", "bluetooth", "wifi", "vpn", "power", "fan", "nightlight", "awake", "airplane", "dnd"]

    function flagName(key) {
        return "shown" + key.charAt(0).toUpperCase() + key.slice(1);
    }

    function label(key) {
        switch (key) {
        case "wired": return i18n("Wired");
        case "bluetooth": return i18n("Bluetooth");
        case "wifi": return i18n("Wi-Fi");
        case "vpn": return i18n("VPN");
        case "power": return i18n("Power Mode");
        case "fan": return i18n("Fan Curve");
        case "nightlight": return i18n("Night Light");
        case "awake": return i18n("Keep Awake");
        case "airplane": return i18n("Airplane Mode");
        case "dnd": return i18n("Do Not Disturb");
        }
        return key;
    }

    function movePill(from, to) {
        const keys = root.order.slice();
        keys.splice(to, 0, keys.splice(from, 1)[0]);
        cfg_pillOrder = keys;
    }

    // What the list shows: the stored order, with every pill it does not
    // mention put back where the popup would have put it.
    readonly property var order: {
        const keys = [];
        for (const key of root.cfg_pillOrder) {
            if (root.pillKeys.indexOf(key) !== -1 && keys.indexOf(key) === -1) {
                keys.push(key);
            }
        }
        for (const key of root.pillKeys) {
            if (keys.indexOf(key) === -1) {
                keys.push(key);
            }
        }
        return keys;
    }

    Kirigami.FormLayout {
        // One row per pill: a handle to drag it by, the name, and the box that
        // shows it. Rows keep their own height so the dragged one can slide
        // over its neighbours and push them along.
        Item {
            id: orderList
            Kirigami.FormData.label: i18n("Entries:")
            Layout.fillWidth: true
            Layout.preferredHeight: root.order.length * orderList.rowHeight
            Layout.bottomMargin: Kirigami.Units.smallSpacing

            readonly property int rowHeight: Math.round(Kirigami.Units.gridUnit * 1.4)
            readonly property int gutter: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing

            property int heldIndex: -1
            property int dropIndex: -1
            property real grabOffset: 0
            property real heldY: 0

            function shiftFor(row) {
                if (orderList.heldIndex < 0 || row === orderList.heldIndex) {
                    return 0;
                }
                if (orderList.heldIndex < row && row <= orderList.dropIndex) {
                    return -orderList.rowHeight;
                }
                if (orderList.dropIndex <= row && row < orderList.heldIndex) {
                    return orderList.rowHeight;
                }
                return 0;
            }

            function letGo() {
                const from = orderList.heldIndex;
                const to = orderList.dropIndex;
                orderList.heldIndex = -1;
                orderList.dropIndex = -1;
                if (from >= 0 && to >= 0 && from !== to) {
                    root.movePill(from, to);
                }
            }

            Repeater {
                model: root.order

                delegate: Item {
                    id: pillRow

                    required property int index
                    required property string modelData

                    width: orderList.width
                    height: orderList.rowHeight
                    readonly property bool held: orderList.heldIndex === pillRow.index
                    y: pillRow.held ? orderList.heldY
                                    : pillRow.index * orderList.rowHeight + orderList.shiftFor(pillRow.index)
                    activeFocusOnTab: true

                    Rectangle {
                        anchors.fill: parent
                        radius: Kirigami.Units.cornerRadius
                        color: Qt.rgba(0.5, 0.5, 0.5, 0.12)
                        visible: pillRow.activeFocus || grabArea.containsMouse
                    }

                    // Under the row's own controls, so the checkbox still gets
                    // the click.
                    MouseArea {
                        id: grabArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        cursorShape: pillRow.held ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                        onPressed: function (mouse) {
                            const point = grabArea.mapToItem(orderList, mouse.x, mouse.y);
                            orderList.grabOffset = point.y;
                            orderList.heldIndex = pillRow.index;
                            orderList.dropIndex = pillRow.index;
                            orderList.heldY = pillRow.y;
                        }
                        onPositionChanged: function (mouse) {
                            if (orderList.heldIndex < 0) {
                                return;
                            }
                            orderList.heldY = grabArea.mapToItem(orderList, mouse.x, mouse.y).y - orderList.grabOffset;
                            orderList.dropIndex = Math.max(0, Math.min(root.order.length - 1,
                                Math.floor((orderList.heldY + orderList.rowHeight / 2) / orderList.rowHeight)));
                        }
                        onReleased: orderList.letGo()
                        onCanceled: {
                            orderList.heldIndex = -1;
                            orderList.dropIndex = -1;
                        }
                    }

                    Kirigami.Icon {
                        id: gripIcon
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        width: Kirigami.Units.iconSizes.small
                        height: width
                        source: "drag-handle-symbolic"
                        isMask: true
                        color: grabArea.containsMouse || pillRow.activeFocus
                            ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                    }

                    QQC2.Label {
                        id: entryName
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: gripIcon.right
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.right: entryBox.left
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        text: root.label(pillRow.modelData)
                    }

                    QQC2.CheckBox {
                        id: entryBox
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        checked: root[root.flagName(pillRow.modelData)]
                        onToggled: root[root.flagName(pillRow.modelData)] = checked
                        Accessible.name: entryName.text
                    }

                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_Up && pillRow.index > 0) {
                            root.movePill(pillRow.index, pillRow.index - 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down && pillRow.index < root.order.length - 1) {
                            root.movePill(pillRow.index, pillRow.index + 1);
                            event.accepted = true;
                        }
                    }
                }
            }
        }

        QQC2.Label {
            leftPadding: orderList.gutter
            text: i18n("Drag an entry by its handle to move it, or focus one and use the arrow keys.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: showMedia
            Kirigami.FormData.label: i18n("Under the grid:")
            text: i18n("Media Player")
        }
        QQC2.CheckBox {
            id: showNotifications
            text: i18n("Notifications")
        }
        QQC2.Label {
            leftPadding: showMedia.indicator.width + showMedia.spacing
            text: i18n("The media player and the notification list sit below the pills, so they have no place in the order.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }

        QQC2.CheckBox {
            id: bodyToggles
            Kirigami.FormData.label: i18n("What clicking does:")
            text: i18n("Clicking a pill toggles it, the arrow opens its panel")
        }
        QQC2.Label {
            leftPadding: bodyToggles.indicator.width + bodyToggles.spacing
            text: i18n("This is how GNOME's Quick Settings behave. Turn it off to swap the two halves round.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }
    }
}
