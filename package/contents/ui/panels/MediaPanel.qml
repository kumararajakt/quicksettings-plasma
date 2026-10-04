import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../components"

ColumnLayout {
    id: mediaRoot

    required property var app
    required property Style style

    readonly property real artSize: Math.round(Kirigami.Units.gridUnit * 2.4)

    readonly property bool mirrored: Application.layoutDirection === Qt.RightToLeft

    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Item {
            Layout.preferredWidth: mediaRoot.artSize
            Layout.preferredHeight: mediaRoot.artSize

            Kirigami.Icon {
                anchors.fill: parent
                source: mediaRoot.app.media.iconName !== "" ? mediaRoot.app.media.iconName : "multimedia-player-symbolic"
                fallback: "media-playback-start-symbolic"
                isMask: true
                color: mediaRoot.style.textMuted
                opacity: art.status === Image.Ready ? 0 : 1
            }

            Image {
                id: art
                anchors.fill: parent
                source: mediaRoot.app.media.artUrl
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            PlasmaComponents.Label {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: mediaRoot.app.media.title
                font.bold: true
                elide: Text.ElideRight
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: mediaRoot.app.media.subtitle !== ""
                textFormat: Text.PlainText
                text: mediaRoot.app.media.subtitle
                color: mediaRoot.style.textMuted
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
            }
        }

        IconButton {
            style: mediaRoot.style
            iconSize: 18
            iconName: mediaRoot.mirrored ? "media-skip-forward-symbolic" : "media-skip-backward-symbolic"
            tooltip: i18n("Previous Track")
            enabled: mediaRoot.app.media.canGoPrevious
            onClicked: mediaRoot.app.media.previous()
        }

        IconButton {
            style: mediaRoot.style
            iconSize: 22
            iconName: mediaRoot.app.media.playing ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
            tooltip: mediaRoot.app.media.playing ? i18n("Pause") : i18n("Play")
            onClicked: mediaRoot.app.media.playPause()
        }

        IconButton {
            style: mediaRoot.style
            iconSize: 18
            iconName: mediaRoot.mirrored ? "media-skip-backward-symbolic" : "media-skip-forward-symbolic"
            tooltip: i18n("Next Track")
            enabled: mediaRoot.app.media.canGoNext
            onClicked: mediaRoot.app.media.next()
        }
    }

    component SeekBar: Item {
        id: bar

        required property Style style
        required property real progress
        required property bool seekable

        signal seekRequested(real fraction)

        readonly property real trackHeight: Math.max(3, Math.round(Kirigami.Units.gridUnit * 0.2))

        property bool dragging: false
        property real draggedTo: 0
        readonly property real shown: dragging ? draggedTo : progress

        implicitHeight: Math.round(Kirigami.Units.gridUnit * 0.9)

        Rectangle {
            id: track

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: bar.trackHeight
            radius: height / 2
            color: bar.style.track

            Rectangle {
                width: Math.round(parent.width * bar.shown)
                height: parent.height
                radius: height / 2
                color: bar.seekable ? bar.style.accent : bar.style.textMuted
            }
        }

        Rectangle {
            visible: bar.seekable && (area.containsMouse || bar.dragging)
            width: bar.trackHeight + 4
            height: width
            radius: width / 2
            color: "#ffffff"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.18)
            x: Math.round(track.x + bar.shown * (track.width - width))
            y: track.y + (track.height - height) / 2
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            enabled: bar.seekable
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

            function fractionAt(mouse) {
                return Math.max(0, Math.min(1, (mouse.x - track.x) / Math.max(1, track.width)));
            }

            onPressed: function (mouse) {
                bar.dragging = true;
                bar.draggedTo = area.fractionAt(mouse);
            }
            onPositionChanged: function (mouse) {
                if (bar.dragging) {
                    bar.draggedTo = area.fractionAt(mouse);
                }
            }
            onReleased: function (mouse) {
                bar.seekRequested(area.fractionAt(mouse));
                bar.dragging = false;
                bar.draggedTo = 0;
            }
            onCanceled: {
                bar.dragging = false;
                bar.draggedTo = 0;
            }
        }
    }

    SeekBar {
        Layout.fillWidth: true
        style: mediaRoot.style
        progress: mediaRoot.app.media.progress
        seekable: mediaRoot.app.media.canSeek
        onSeekRequested: fraction => mediaRoot.app.media.seekTo(fraction)
    }
}
