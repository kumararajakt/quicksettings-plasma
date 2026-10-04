import QtQuick
import org.kde.plasma.private.mpris as Mpris

Item {
    id: media
    visible: false

    readonly property var player: mpris.currentPlayer

    readonly property int status: player ? player.playbackStatus : Mpris.PlaybackStatus.Unknown
    readonly property bool available: status > Mpris.PlaybackStatus.Stopped
    readonly property bool playing: status === Mpris.PlaybackStatus.Playing

    readonly property string title: (player && player.track) || identity
    readonly property string subtitle: (player && player.artist) || ""
    readonly property string identity: (player && player.identity) || ""
    readonly property string iconName: (player && player.iconName) || ""
    readonly property string artUrl: (player && player.artUrl) || ""

    readonly property real length: (player && player.length) || 0
    readonly property real position: (player && player.position) || 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

    readonly property bool canSeek: (player && player.canSeek) === true && length > 0
    readonly property bool canGoPrevious: (player && player.canGoPrevious) || false
    readonly property bool canGoNext: (player && player.canGoNext) || false

    Mpris.Mpris2Model {
        id: mpris
    }

    Timer {
        interval: 1000
        repeat: true
        running: media.available && media.playing
        onTriggered: {
            if (media.player) {
                media.player.updatePosition();
            }
        }
    }

    function playPause() {
        if (!player) {
            return;
        }
        if (playing) {
            if (player.canPause) {
                player.Pause();
            }
        } else if (player.canPlay) {
            player.Play();
        }
    }

    function next() {
        if (player && player.canGoNext) {
            player.Next();
        }
    }

    function previous() {
        if (player && player.canGoPrevious) {
            player.Previous();
        }
    }

    function seekTo(fraction) {
        if (!player || !canSeek || length <= 0) {
            return;
        }
        player.position = Math.round(Math.max(0, Math.min(1, fraction)) * length);
    }
}
