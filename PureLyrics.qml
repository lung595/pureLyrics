import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Modules.Plugins
import qs.Modules.DDash.Media

// Renders DMS's own lyrics view (LyricsOverlay) on the desktop. Lyrics come from the shared
// LyricsService, so the dash and this widget never fetch the same song twice.
DesktopPluginComponent {
    id: root

    readonly property string fontFamily: pluginData.fontFamily ?? ""
    readonly property bool smoothSweep: pluginData.smoothSweep ?? false
    readonly property real backgroundOpacity: (pluginData.backgroundOpacity ?? 0) / 100
    readonly property real borderOpacity: (pluginData.borderOpacity ?? 0) / 100

    implicitWidth: 600
    implicitHeight: 260
    minWidth: 200
    minHeight: 80

    readonly property var player: MprisController.activePlayer
    // Hidden when nothing plays; the overlay then drops its LyricsService subscription too.
    opacity: !!player && player.playbackState !== MprisPlaybackState.Stopped ? 1 : 0
    visible: opacity > 0
    Behavior on opacity {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    // The overlay reads smoothLyrics from its player and writes lyricsFocusTarget back onto it.
    // Without the smooth sweep the fill moves per word on the controller's cue timer instead of every frame.
    QtObject {
        id: prefs
        property bool smoothLyrics: root.smoothSweep
        property var lyricsFocusTarget: null
    }

    LyricsOverlay {
        id: overlay
        anchors.fill: parent
        player: prefs
        radius: Theme.cornerRadius * 2
        backgroundColor: Theme.withAlpha(Theme.surfaceContainerHighest, root.backgroundOpacity)
        Component.onCompleted: root.applyFont()
    }

    Rectangle {
        anchors.fill: parent
        radius: overlay.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.withAlpha(Theme.outline, root.borderOpacity)
        visible: root.borderOpacity > 0
    }

    // shortcut: LyricsOverlay exposes no font property, so this sets the family on its two
    // measuring probes (found by their advanceWidth function); lines take the font from them.
    // Breaks if DMS renames that inner component; upgrade if DMS adds a font property.
    function applyFont() {
        const family = fontFamily || Theme.fontFamily;
        for (const child of overlay.children) {
            if (typeof child.advanceWidth === "function")
                child.font.family = family;
        }
    }
    onFontFamilyChanged: applyFont()
}
