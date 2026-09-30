import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import org.kde.coreaddons as KCoreAddons
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import "../components"

ColumnLayout {
    id: notificationsRoot

    required property var app
    required property Style style

    function stripMarkup(text) {
        let s = String(text || "");
        s = s.replace(/<\?xml[^>]*\?>/g, "");
        s = s.replace(/<br\s*\/?>/gi, "\n");
        s = s.replace(/<[^>]*>/g, "");
        return s.replace(/&amp;/g, "&")
                .replace(/&lt;/g, "<")
                .replace(/&gt;/g, ">")
                .replace(/&quot;/g, "\"")
                .replace(/&#39;/g, "'")
                .trim();
    }

    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Item {
            Layout.fillWidth: true
        }

        IconButton {
            style: notificationsRoot.style
            iconName: "edit-clear-history"
            tooltip: i18n("Clear History")
            visible: notificationsRoot.app.notifications.count > 0
            onClicked: notificationsRoot.app.notifications.clearHistory()
        }
    }

    ListView {
        id: list

        visible: count > 0
        Layout.fillWidth: true
        Layout.maximumHeight: Kirigami.Units.gridUnit * 12
        Layout.preferredHeight: contentHeight
        interactive: contentHeight > Kirigami.Units.gridUnit * 12
        clip: true
        spacing: Kirigami.Units.smallSpacing
        boundsBehavior: Flickable.StopAtBounds

        model: notificationsRoot.app.notifications.historyModel

        delegate: Item {
            id: delegateRoot

            required property var model
            required property int index

            readonly property bool group: model.isGroup === true
            readonly property bool inGroup: model.isInGroup === true
            readonly property string appName: notificationsRoot.stripMarkup(model.applicationName || model.summary || "")
            readonly property string heading: appName + (model.originName ? " · " + model.originName : "")
            readonly property date when_: !isNaN(model.updated) ? model.updated : model.created

            width: list.width
            height: col.height

            Column {
                id: col

                width: parent.width
                spacing: 2

                RowLayout {
                    visible: !delegateRoot.inGroup
                    width: parent.width
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        visible: !delegateRoot.inGroup
                        source: delegateRoot.model.applicationIconName || delegateRoot.model.iconName || ""
                        fallback: "preferences-desktop-notification"
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredWidth: delegateRoot.inGroup ? Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing : 0
                    }

                    Kirigami.Heading {
                        Layout.fillWidth: true
                        level: 5
                        opacity: 0.9
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                        textFormat: Text.PlainText
                        text: delegateRoot.heading
                    }

                    PlasmaComponents.Label {
                        visible: !delegateRoot.group
                        text: KCoreAddons.Format.formatRelativeDateTime(delegateRoot.when_, Locale.ShortFormat)
                        color: notificationsRoot.style.textMuted
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        textFormat: Text.PlainText
                    }

                    PlasmaComponents.Label {
                        visible: delegateRoot.group
                            && delegateRoot.model.groupChildrenCount > delegateRoot.model.expandedGroupChildrenCount
                        text: i18nc("Expand to show n more notifications",
                                    "Show %1 More",
                                    delegateRoot.model.groupChildrenCount - delegateRoot.model.expandedGroupChildrenCount)
                        color: notificationsRoot.style.textMuted
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        textFormat: Text.PlainText
                    }

                    T.AbstractButton {
                        id: expandButton

                        visible: delegateRoot.group
                            && delegateRoot.model.groupChildrenCount > delegateRoot.model.expandedGroupChildrenCount
                        implicitWidth: 16
                        implicitHeight: 16

                        onClicked: notificationsRoot.app.notifications.historyModel.setData(
                                       notificationsRoot.app.notifications.historyModel.index(delegateRoot.index, 0),
                                       !delegateRoot.model.isGroupExpanded,
                                       NotificationManager.Notifications.IsGroupExpandedRole)

                        contentItem: Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 12
                            height: 12
                            source: delegateRoot.model.isGroupExpanded ? "arrow-up-symbolic" : "arrow-down-symbolic"
                            isMask: true
                            color: notificationsRoot.style.text
                        }

                        background: Rectangle {
                            radius: 8
                            color: expandButton.pressed ? notificationsRoot.style.tilePressed
                                 : expandButton.hovered ? notificationsRoot.style.tileHover : "transparent"
                        }
                    }

                    T.AbstractButton {
                        id: closeButton

                        visible: delegateRoot.model.closable === true
                        implicitWidth: 20
                        implicitHeight: 20

                        Accessible.name: i18n("Close notification from %1", delegateRoot.appName)
                        Accessible.role: Accessible.Button
                        onClicked: notificationsRoot.app.notifications.historyModel.close(
                                       notificationsRoot.app.notifications.historyModel.index(delegateRoot.index, 0))

                        contentItem: Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 12
                            height: 12
                            source: "window-close-symbolic"
                            isMask: true
                            color: notificationsRoot.style.textMuted
                        }

                        background: Rectangle {
                            radius: 10
                            color: closeButton.pressed ? notificationsRoot.style.tilePressed
                                 : closeButton.hovered ? notificationsRoot.style.tileHover : "transparent"
                        }
                    }
                }

                PlasmaComponents.Label {
                    visible: !delegateRoot.group && (delegateRoot.model.summary || "") !== ""
                    width: parent.width
                    leftPadding: delegateRoot.inGroup ? Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing : 0
                    text: notificationsRoot.stripMarkup(delegateRoot.model.summary || "")
                    font.bold: true
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }

                PlasmaComponents.Label {
                    visible: !delegateRoot.group && notificationsRoot.stripMarkup(delegateRoot.model.body || "") !== ""
                    width: parent.width
                    leftPadding: delegateRoot.inGroup ? Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing : 0
                    text: notificationsRoot.stripMarkup(delegateRoot.model.body || "")
                    color: notificationsRoot.style.textMuted
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
            }
        }
    }

    PlasmaExtras.PlaceholderMessage {
        visible: notificationsRoot.app.notifications.count === 0
        Layout.alignment: Qt.AlignHCenter
        iconName: "checkmark"
        text: i18n("No unread notifications")
    }
}
