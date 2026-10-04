import QtQuick
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.workspace.dbus as DBus

Item {
    id: sni

    visible: false

    readonly property string watcherService: "org.kde.StatusNotifierWatcher"
    readonly property string watcherPath: "/StatusNotifierWatcher"

    property var items: []

    readonly property int count: items.length

    property bool watcherUp: false
    readonly property bool available: watcherUp

    function itemAt(index) {
        return items[index] || null;
    }

    function activate(row) {
        sni._itemCall(row, "Activate", [0, 0], "(ii)");
    }

    function secondaryActivate(row) {
        sni._itemCall(row, "SecondaryActivate", [0, 0], "(ii)");
    }

    function requestMenu(row, anchor) {
        if (!row || row.menuPath === "" || row.menuPath === "/NO_DBUSMENU") {
            return;
        }
        row.ensureMenu(anchor);
    }

    function scroll(row, delta, horizontal) {
        sni._itemCall(row, "Scroll", [Math.round(delta), horizontal ? "horizontal" : "vertical"], "(is)");
    }

    function _init() {
        watcherProps.updateAll();
    }

    function _onItemsListed(keys) {
        sni.watcherUp = true;
        sni._syncItems(keys || []);
    }

    function _keyList(value) {
        if (Array.isArray(value)) {
            return value;
        }
        if (value !== null && typeof value === "object" && typeof value.length === "number") {
            return Array.prototype.slice.call(value);
        }
        if (typeof value === "string") {
            return value.split(",").map(k => k.trim()).filter(k => k !== "");
        }
        return [String(value)];
    }

    function _syncItems(keys) {
        const wanted = [];
        for (const key of keys) {
            if (Array.isArray(key)) {
                sni._syncItems(key);
                return;
            }
            const parsed = sni._parseKey(String(key));
            if (!parsed) {
                continue;
            }
            let row = sni._row(parsed.service, parsed.path);
            if (!row) {
                row = _rowComponent.createObject(sni, {
                    service: parsed.service,
                    path: parsed.path,
                });
            }
            wanted.push(row);
        }
        for (const row of sni.items) {
            if (wanted.indexOf(row) === -1) {
                row.dispose();
                row.destroy();
            }
        }
        sni.items = wanted;
    }

    function _row(service, path) {
        return items.find(row => row.service === service && row.path === path) || null;
    }

    function _parseKey(key) {
        if (!key) {
            return null;
        }
        const slash = key.indexOf("/");
        const service = slash === -1 ? key : key.slice(0, slash);
        const path = slash === -1 ? "/StatusNotifierItem" : key.slice(slash);
        if (!/^[A-Za-z0-9_.:-]+$/.test(service) || !/^[A-Za-z0-9_/.]+$/.test(path)) {
            console.warn("Quick Settings: skipping unreachable tray item", key);
            return null;
        }
        return { service: service, path: path };
    }

    function _itemCall(row, member, args, signature) {
        if (!row) {
            return;
        }
        DBus.SessionBus.asyncCall({
            service: row.service,
            path: row.path,
            iface: "org.kde.StatusNotifierItem",
            member: member,
            arguments: args,
            signature: signature,
        }, null, error => console.warn("Quick Settings: SNI " + member + " failed:", error && error.message));
    }

    DBus.SignalWatcher {
        busType: DBus.BusType.Session
        service: "org.freedesktop.DBus"
        path: "/org/freedesktop/DBus"
        iface: "org.freedesktop.DBus"

        function dbusNameOwnerChanged(name, oldOwner, newOwner) {
            if (name === sni.watcherService) {
                if (newOwner !== "") {
                    sni._init();
                } else {
                    sni.watcherUp = false;
                    sni._syncItems([]);
                }
                return;
            }
            if (oldOwner !== "" && oldOwner !== newOwner) {
                const dead = sni.items.filter(row => row.service === oldOwner);
                if (dead.length > 0) {
                    sni.items = sni.items.filter(row => row.service !== oldOwner);
                    dead.forEach(row => {
                        row.dispose();
                        row.destroy();
                    });
                }
            }
        }
    }

    DBus.Properties {
        id: watcherProps

        busType: DBus.BusType.Session
        service: sni.watcherService
        path: sni.watcherPath
        iface: sni.watcherService

        onRefreshed: {
            const p = properties;
            const list = p.RegisteredStatusNotifierItems;
            if (list !== undefined && list !== null) {
                sni._onItemsListed(sni._keyList(list));
            } else {
                sni.watcherUp = true;
            }
        }
    }

    DBus.SignalWatcher {
        id: watcherSignals

        busType: DBus.BusType.Session
        service: sni.watcherService
        path: sni.watcherPath
        iface: sni.watcherService

        function dbusStatusNotifierItemRegistered(notifierItemId) {
            const parsed = sni._parseKey(String(notifierItemId));
            if (!parsed) {
                return;
            }
            if (sni._row(parsed.service, parsed.path)) {
                sni.refreshRow(parsed);
                return;
            }
            const row = _rowComponent.createObject(sni, {
                service: parsed.service,
                path: parsed.path,
            });
            sni.items = sni.items.concat([row]);
        }

        function dbusStatusNotifierItemUnregistered(notifierItemId) {
            const parsed = sni._parseKey(String(notifierItemId));
            if (!parsed) {
                return;
            }
            const row = sni._row(parsed.service, parsed.path);
            if (row) {
                sni.items = sni.items.filter(r => r !== row);
                row.dispose();
                row.destroy();
            }
        }

        function dbusIsStatusNotifierHostRegisteredChanged() {
            sni._init();
        }
    }

    function refreshRow(parsed) {
        const row = sni._row(parsed.service, parsed.path);
        if (row) {
            row.refreshProperties();
        }
    }

    Component {
        id: _rowComponent

        QtObject {
            id: row

            property string service: ""
            property string path: ""

            property string id: ""
            property string title: ""
            property string tooltip: ""
            property string iconName: ""
            property bool itemIsMenu: false
            property string menuPath: ""

            property string status: ""
            property string attentionIconName: ""
            property var iconPixmap: null
            property var attentionIconPixmap: null

            readonly property bool usesAttentionIcon: row.status === "NeedsAttention"
                    && (row.attentionIconName !== "" || sni._hasPixmap(row.attentionIconPixmap))
            readonly property string activeIconName: row.usesAttentionIcon
                    ? row.attentionIconName : row.iconName
            readonly property var activeIconPixmap: row.usesAttentionIcon
                    ? row.attentionIconPixmap : row.iconPixmap

            property var _menu: null

            readonly property var props: DBus.Properties {
                busType: DBus.BusType.Session
                service: row.service
                path: row.path
                iface: "org.kde.StatusNotifierItem"

                onRefreshed: row._readAll()
                onPropertiesChanged: (ifaceName, changed, invalid) => {
                    if (ifaceName !== "org.kde.StatusNotifierItem") {
                        return;
                    }
                    for (const name of Object.keys(changed)) {
                        row._apply(name, changed[name]);
                    }
                    for (const name of invalid) {
                        props.update(name);
                    }
                }
            }

            function refreshProperties() {
                props.updateAll();
            }

            function _readAll() {
                const p = props.properties;
                row._apply("Id", p.Id);
                row._apply("Title", p.Title);
                row._apply("ToolTip", p.ToolTip);
                row._apply("Status", p.Status);
                row._apply("IconName", p.IconName);
                row._apply("AttentionIconName", p.AttentionIconName);
                row._apply("IconPixmap", p.IconPixmap);
                row._apply("AttentionIconPixmap", p.AttentionIconPixmap);
                row._apply("ItemIsMenu", p.ItemIsMenu);
                row._apply("Menu", p.Menu);
            }

            function _apply(name, value) {
                if (value === undefined || value === null) {
                    return;
                }
                switch (name) {
                case "Id":
                    row.id = String(value);
                    break;
                case "Title":
                    row.title = String(value);
                    break;
                case "ToolTip":
                    row.tooltip = row._tooltipText(value);
                    break;
                case "Status":
                    row.status = String(value);
                    break;
                case "IconName":
                    row.iconName = String(value);
                    break;
                case "AttentionIconName":
                    row.attentionIconName = String(value);
                    break;
                case "IconPixmap":
                    row.iconPixmap = value;
                    break;
                case "AttentionIconPixmap":
                    row.attentionIconPixmap = value;
                    break;
                case "ItemIsMenu":
                    row.itemIsMenu = value === true;
                    break;
                case "Menu": {
                    let mp = "";
                    if (typeof value === "string") {
                        mp = value;
                    } else if (typeof value === "object") {
                        const inner = value.value !== undefined ? value.value : (value.objectPath || "");
                        mp = typeof inner === "object" && inner !== null
                             ? (typeof inner.path !== "undefined" ? String(inner.path)
                                : typeof inner.toString === "function" ? inner.toString() : String(inner))
                             : String(inner);
                    }
                    row.menuPath = mp.indexOf("/") === 0 ? mp : "";
                    break;
                }
                }
            }

            function _tooltipText(t) {
                if (!t || !t.length) {
                    return "";
                }
                return String(t[2] || "") || String(t[3] || "") || String(t[1] || "") || String(t[0] || "");
            }

            function iconUrlFor(targetSize) {
                if (row.activeIconName !== "") {
                    return "";
                }
                return sni._pixmapToSvgUrl(row.activeIconPixmap, targetSize);
            }

            function ensureMenu(anchorItem) {
                if (row.menuPath === "" || !anchorItem) {
                    return;
                }
                if (!row._menu || row._menu.menuPath !== row.menuPath) {
                    if (row._menu) {
                        row._menu.destroy();
                    }
                    row._menu = _menuComponent.createObject(sni, {
                        service: row.service,
                        menuPath: row.menuPath,
                    });
                }
                row._menu.pendingAnchor = anchorItem;
                row._menu.aboutToShow();
            }

            function dispose() {
                if (row._menu) {
                    row._menu.destroy();
                    row._menu = null;
                }
            }

            Component.onDestruction: row.dispose()
        }
    }

    Component {
        id: _menuComponent

        DbusMenu {}
    }

    function _pixmapToSvgUrl(pixmaps, targetSide) {
        const img = sni._pickPixmap(pixmaps, targetSide);
        if (!img) {
            return "";
        }
        const srcW = sni._intOf(img[0]);
        const srcH = sni._intOf(img[1]);
        const bytes = img[2];
        const outW = targetSide > 0 ? Math.min(srcW, targetSide) : srcW;
        const outH = targetSide > 0 ? Math.min(srcH, targetSide) : srcH;
        const xStep = srcW / outW;
        const yStep = srcH / outH;
        const rects = [];
        for (let y = 0; y < outH; ++y) {
            const srcRow = 4 * Math.floor(y * yStep) * srcW;
            let runStart = -1;
            let runColor = "";
            for (let x = 0; x <= outW; ++x) {
                const i = srcRow + 4 * Math.floor(x * xStep);
                let color = "";
                if (x < outW) {
                    const a = sni._intOf(bytes[i]);
                    if (a > 0) {
                        const r = sni._intOf(bytes[i + 1]);
                        const g = sni._intOf(bytes[i + 2]);
                        const b = sni._intOf(bytes[i + 3]);
                        color = a === 255
                            ? "#" + sni._hex(r) + sni._hex(g) + sni._hex(b)
                            : "rgba(" + r + "," + g + "," + b + "," + (a / 255).toFixed(3) + ")";
                    }
                }
                if (color !== runColor) {
                    if (runColor !== "") {
                        rects.push('<rect x="' + runStart + '" y="' + y + '" width="' + (x - runStart)
                                   + '" height="1" fill="' + runColor + '"/>');
                    }
                    runStart = x;
                    runColor = color;
                }
            }
        }
        return "data:image/svg+xml;utf8," + encodeURIComponent(
            '<svg xmlns="http://www.w3.org/2000/svg" width="' + outW + '" height="' + outH
            + '" viewBox="0 0 ' + outW + " " + outH + '">' + rects.join("") + "</svg>");
    }

    function _hasPixmap(pixmaps) {
        return sni._pickPixmap(pixmaps, 0) !== null;
    }

    function _pickPixmap(pixmaps, targetSide) {
        if (!pixmaps || !pixmaps.length) {
            return null;
        }
        let bigEnough = null;
        let bigEnoughSide = 0;
        let largest = null;
        let largestSide = 0;
        for (let i = 0; i < pixmaps.length; ++i) {
            const img = pixmaps[i];
            const w = sni._intOf(img[0]);
            const h = sni._intOf(img[1]);
            if (w <= 0 || h <= 0 || !img[2] || img[2].length < w * h * 4) {
                continue;
            }
            const side = Math.max(w, h);
            if (side >= targetSide && (bigEnough === null || side < bigEnoughSide)) {
                bigEnough = img;
                bigEnoughSide = side;
            }
            if (side > largestSide) {
                largest = img;
                largestSide = side;
            }
        }
        return bigEnough !== null ? bigEnough : largest;
    }

    function _intOf(v) {
        if (typeof v === "number") {
            return v;
        }
        if (v && typeof v === "object" && v.value !== undefined) {
            const n = Number(v.value);
            return isNaN(n) ? -1 : n;
        }
        const n = Number(v);
        return isNaN(n) ? -1 : n;
    }

    function _hex(v) {
        return (v < 16 ? "0" : "") + v.toString(16);
    }

    component Node: QtObject {
        property int id: 0
        property string label: ""
        property bool enabled: true
        property bool visible: true
        property string type: "standard"
        property string toggleType: ""
        property int toggleState: 0
        property string iconName: ""
        property var children: []
    }

    component DbusMenu: Item {
        id: menuClient

        property string service: ""
        property string menuPath: ""

        readonly property string dbusMenuIface: "com.canonical.dbusmenu"

        property var items: ({})
        property var menu: null
        property var rows: ({})
        property var submenus: ({})

        property var pendingAnchor: null
        property bool synced: false

        function _openPending() {
            const anchor = menuClient.pendingAnchor;
            menuClient.pendingAnchor = null;
            if (!anchor || !menuClient.menu) {
                return;
            }
            menuClient.menu.visualParent = anchor;
            menuClient.menu.openRelative();
            menuClient._sendEvent(0, "opened");
        }

        function _initMenu() {
            if (menuClient.menu === null) {
                menuClient.menu = menuComponent.createObject(menuClient);
            }
        }

        function aboutToShow() {
            menuClient._initMenu();
            DBus.SessionBus.asyncCall({
                service: menuClient.service,
                path: menuClient.menuPath,
                iface: menuClient.dbusMenuIface,
                member: "AboutToShow",
                arguments: [0],
                signature: "(i)",
            }, reply => {
                if (reply.value === true) {
                    menuClient.sync();
                } else if (menuClient.synced) {
                    menuClient._openPending();
                }
            }, error => console.warn("Quick Settings: AboutToShow failed:", error && error.message));
        }

        function sync() {
            DBus.SessionBus.asyncCall({
                service: menuClient.service,
                path: menuClient.menuPath,
                iface: menuClient.dbusMenuIface,
                member: "GetLayout",
                arguments: [0, -1, []],
                signature: "(iias)",
            }, reply => {
                const values = reply.values;
                if (!values || values.length < 2) {
                    return;
                }
                const root = values[1];
                if (!root || root.length < 3) {
                    return;
                }
                const fresh = {};
                menuClient._ingest(root, fresh);
                menuClient.items = fresh;
                menuClient.synced = true;
                menuClient._rebuild();
                menuClient._openPending();
            }, error => console.warn("Quick Settings: GetLayout failed:", error && error.message));
        }

        function _ingest(node, into) {
            const id = sni._intOf(node[0]);
            const props = node[1] || {};
            const childRefs = node[2] || [];
            const item = nodeComponent.createObject(menuClient, {
                id: id,
                label: String(props.label || ""),
                enabled: props.enabled !== undefined ? props.enabled !== false : true,
                visible: props["visible"] !== undefined ? props["visible"] !== false : true,
                type: String(props.type || "standard"),
                toggleType: String(props["toggle-type"] || ""),
                toggleState: props["toggle-state"] !== undefined ? Number(props["toggle-state"]) : 0,
                iconName: props["icon-name"] !== undefined ? String(props["icon-name"]) : "",
            });
            const children = [];
            for (const child of childRefs) {
                children.push(menuClient._ingest(child, into));
            }
            item.children = children;
            into[id] = item;
            return item;
        }

        function _rebuild() {
            menuClient._initMenu();
            const m = menuClient.menu;
            m.clearMenuItems();
            menuClient.rows = {};
            menuClient.submenus = {};
            const root = menuClient.items[0];
            if (!root) {
                return;
            }
            for (const child of root.children) {
                menuClient._append(m, child);
            }
        }

        function _updateInPlace() {
            for (const id of Object.keys(menuClient.rows)) {
                const item = menuClient.items[Number(id)];
                const mi = menuClient.rows[Number(id)];
                if (!item || !mi) {
                    continue;
                }
                mi.text = menuClient._mnemonic(item.label);
                mi.enabled = item.enabled;
                mi.checked = item.toggleState === 1;
                mi.visible = item.visible;
            }
        }

        function _append(parentMenu, item) {
            if (!item.visible) {
                return;
            }
            if (item.type === "separator") {
                const sep = separatorComponent.createObject(parentMenu, { separator: true });
                parentMenu.addMenuItem(sep);
                return;
            }
            const mi = menuItemComponent.createObject(parentMenu, {
                text: menuClient._mnemonic(item.label),
                enabled: item.enabled,
                checkable: item.toggleType !== "",
                checked: item.toggleState === 1,
            });
            mi.icon = item.iconName;
            menuClient.rows[item.id] = mi;
            if (item.children.length > 0) {
                const sub = menuComponent.createObject(parentMenu);
                sub.visualParent = mi.action;
                parentMenu.addMenuItem(mi);
                menuClient.submenus[item.id] = sub;
                for (const child of item.children) {
                    menuClient._append(sub, child);
                }
            } else {
                const nodeId = item.id;
                mi.clicked.connect(() => menuClient._fire(nodeId));
                parentMenu.addMenuItem(mi);
            }
        }

        function _mnemonic(label) {
            return String(label).replace(/_(.)/g, "&$1");
        }

        function _sendEvent(id, eventId) {
            DBus.SessionBus.asyncCall({
                service: menuClient.service,
                path: menuClient.menuPath,
                iface: menuClient.dbusMenuIface,
                member: "Event",
                arguments: [id, eventId, new DBus.variant(""), new DBus.uint32(0)],
                signature: "(isvu)",
            }, null, error => console.warn("Quick Settings: menu Event failed:", error && error.message));
        }

        function _fire(id) {
            const item = menuClient.items[id];
            if (!item) {
                return;
            }
            if (item.toggleType !== "") {
                item.toggleState = item.toggleState === 1 ? 0 : 1;
                _sendEvent(id, "checked");
            } else {
                _sendEvent(id, "clicked");
            }
        }

        DBus.SignalWatcher {
            busType: DBus.BusType.Session
            service: menuClient.service
            path: menuClient.menuPath
            iface: menuClient.dbusMenuIface
            enabled: menuClient.service !== ""

            function dbusLayoutUpdated(revision, parent) {
                menuClient.sync();
            }

            function dbusItemsPropertiesUpdated(updates) {
                const changedList = updates[0] || [];
                for (const pair of changedList) {
                    const item = menuClient.items[sni._intOf(pair[0])];
                    if (!item) {
                        continue;
                    }
                    const props = pair[1] || {};
                    if (props.label !== undefined) {
                        item.label = String(props.label);
                    }
                    if (props.enabled !== undefined) {
                        item.enabled = props.enabled !== false;
                    }
                    if (props["visible"] !== undefined) {
                        item.visible = props["visible"] !== false;
                    }
                    if (props["toggle-state"] !== undefined) {
                        item.toggleState = Number(props["toggle-state"]);
                    }
                    if (props["icon-name"] !== undefined) {
                        item.iconName = String(props["icon-name"]);
                    }
                }
                let structural = (updates[1] || []).length > 0;
                if (!structural) {
                    for (const pair of changedList) {
                        if (!menuClient.rows[sni._intOf(pair[0])]) {
                            structural = true;
                            break;
                        }
                    }
                }
                if (structural) {
                    menuClient.sync();
                    return;
                }
                menuClient._updateInPlace();
            }

            function dbusItemActivationRequested(id, timestamp) {
            }
        }

        Component {
            id: nodeComponent

            Node {}
        }

        Component {
            id: menuComponent

            PlasmaExtras.Menu {
                placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
                onStatusChanged: {
                    if (status === PlasmaExtras.Menu.Closed) {
                        menuClient._sendEvent(0, "closed");
                    }
                }
            }
        }

        Component {
            id: menuItemComponent

            PlasmaExtras.MenuItem {}
        }

        Component {
            id: separatorComponent

            PlasmaExtras.MenuItem {}
        }

        Component.onCompleted: {
            if (menuClient.service !== "" && menuClient.menuPath !== "") {
                menuClient.sync();
            }
        }
    }

    Component.onCompleted: sni._init()
}
