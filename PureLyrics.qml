import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Modules.Plugins
import qs.Widgets
import "lyrics"

// Renders a copy of DMS's lyrics view (lyrics/, from DMS 2.1.2) on the desktop. Lyrics come from the
// shared LyricsService, so the dash and this widget never fetch the same song twice.
DesktopPluginComponent {
    id: root

    readonly property string fontFamily: pluginData.fontFamily ?? ""
    readonly property int activeWeight: pluginData.activeWeight ?? 800
    readonly property int restWeight: pluginData.restWeight ?? 500
    readonly property bool smoothSweep: pluginData.smoothSweep ?? false
    readonly property bool oneLine: pluginData.oneLine ?? false
    readonly property bool shadow: pluginData.shadow ?? true
    readonly property bool glow: pluginData.glow ?? false
    readonly property bool showHeader: pluginData.showHeader ?? true
    readonly property real backgroundOpacity: (pluginData.backgroundOpacity ?? 0) / 100
    readonly property real borderOpacity: (pluginData.borderOpacity ?? 0) / 100

    implicitWidth: 600
    implicitHeight: 260
    minWidth: 200
    minHeight: 60

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
        fontFamily: root.fontFamily
        activeWeight: root.activeWeight
        restWeight: root.restWeight
        shadow: root.shadow
        glow: root.glow
        oneLine: root.oneLine
    }

    Rectangle {
        anchors.fill: parent
        radius: overlay.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.withAlpha(Theme.outline, root.borderOpacity)
        visible: root.borderOpacity > 0
    }

    // Cover, title and artist until the first line is sung, then it fades away.
    Row {
        id: header
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Theme.spacingM
        width: Math.min(implicitWidth, parent.width - Theme.spacingM * 2)
        spacing: Theme.spacingM
        opacity: root.showHeader && root.height >= 140 && overlay.controller.activeIndex < 0 && !!root.player ? 1 : 0
        visible: opacity > 0
        layer.enabled: root.shadow
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.55)
            shadowBlur: 0.6
            shadowVerticalOffset: 2
        }
        Behavior on opacity {
            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        }

        ClippingRectangle {
            width: 48
            height: 48
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHighest
            visible: art.status === Image.Ready

            Image {
                id: art
                anchors.fill: parent
                source: TrackArtService.resolvedArtUrl
                sourceSize: Qt.size(96, 96)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, header.parent.width - 48 - Theme.spacingM * 3)

            StyledText {
                width: parent.width
                text: root.player?.trackTitle ?? ""
                font.family: root.fontFamily || Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Theme.fontWeightBold
                color: Theme.surfaceText
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                text: root.player?.trackArtist ?? ""
                font.family: root.fontFamily || Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
            }
        }
    }
}
