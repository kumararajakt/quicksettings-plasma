import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

// What the pills do when clicked, and the two sections that sit outside the
    // grid. Their order and their visibility dropdowns are on the General page,
    // which owns pillOrder and every visibility* entry.
KCM.SimpleKCM {
    id: root

    property alias cfg_showMedia: showMedia.checked
    property alias cfg_showNotifications: showNotifications.checked
    property alias cfg_bodyToggles: bodyToggles.checked

    Kirigami.FormLayout {
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

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: showMedia
            Kirigami.FormData.label: i18n("Sections:")
            text: i18n("Show the media player")
        }
        QQC2.CheckBox {
            id: showNotifications
            text: i18n("Show the notification list")
        }
        QQC2.Label {
            leftPadding: showMedia.indicator.width + showMedia.spacing
            text: i18n("Order these and everything else from the General page.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }
    }
}
