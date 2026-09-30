import QtQuick
import org.kde.kcmutils as KCMUtils
import org.kde.notificationmanager as NotificationManager

Item {
    id: notifications

    visible: false

    readonly property bool serverValid: NotificationManager.Server.valid
    readonly property bool available: serverValid

    readonly property var historyModel: historyModel
    readonly property int count: historyModel.count
    readonly property int unreadCount: historyModel.unreadNotificationsCount

    readonly property bool dnd: settings.notificationsInhibitedUntil.getTime() > Date.now()

    NotificationManager.Notifications {
        id: historyModel

        showExpired: true
        showDismissed: true
        showJobs: false
        sortMode: NotificationManager.Notifications.SortByDate
        groupMode: NotificationManager.Notifications.GroupApplicationsFlat
        groupLimit: 2
        expandUnread: true
    }

    NotificationManager.Settings {
        id: settings
    }

    function setDnd(on) {
        let date = on ? new Date(Date.now() + 365 * 24 * 60 * 60 * 1000) : new Date(0);
        settings.notificationsInhibitedUntil = date;
        settings.save();
    }

    function markAllRead() {
        for (let i = 0; i < historyModel.count; i++) {
            historyModel.setData(historyModel.index(i, 0), true, NotificationManager.Notifications.ReadRole);
        }
    }

    function clearHistory() {
        for (let i = historyModel.count - 1; i >= 0; --i) {
            historyModel.close(historyModel.index(i, 0));
        }
    }

    function openSettings() {
        KCMUtils.KCMLauncher.openSystemSettings("kcm_notifications");
    }
}
