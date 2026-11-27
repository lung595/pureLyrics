import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Modules.Plugins
import qs.Widgets
import qs.DCommon.Widgets
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
    readonly property bool showPlayer: pluginData.showPlayer ?? true
    readonly property real playerOpacity: (pluginData.playerOpacity ?? 100) / 100
    readonly property bool clickToSeek: pluginData.clickToSeek ?? true
    readonly property bool playerOnHover: pluginData.playerOnHover ?? true
    readonly property real depthBlur: (pluginData.depthBlur ?? 40) / 100
    readonly property bool floatWords: pluginData.floatWords ?? true
    readonly property real textScale: (pluginData.textScale ?? 140) / 100
    readonly property real lineSpacing: pluginData.lineSpacing ?? 0
    // Other lines size, relative to the middle line; layout keeps full-size rows, so capped at 100%.
    readonly property real restScale: (pluginData.restScale ?? 80) / 100
    readonly property string textAlign: pluginData.textAlign ?? "auto"
    readonly property bool duetSides: pluginData.duetSides ?? true
    readonly property string singerName: pluginData.singerName ?? "change"
    readonly property real pyramid: (pluginData.pyramid ?? 15) / 100
    // "follow": aligned toward the screen edge the widget sits on (its window is placed at the widget).
    readonly property string resolvedAlign: {
        if (textAlign !== "follow")
            return textAlign;
        const window = QsWindow.window;
        const screenWidth = window?.screen?.width ?? 0;
        if (screenWidth <= 0)
            return "center";
        const centre = ((window.margins?.left ?? 0) + width / 2) / screenWidth;
        return centre < 0.4 ? "left" : centre > 0.6 ? "right" : "center";
    }

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
        clickToSeek: root.clickToSeek
        textScale: root.textScale
        lineSpacing: root.lineSpacing
        restScale: root.restScale
        depthBlur: root.depthBlur
        floatWords: root.floatWords
        textAlign: root.resolvedAlign
        duetSides: root.duetSides
        singerName: root.singerName
        pointerOver: hover.hovered
        pyramid: root.pyramid
    }

    // With playerOnHover the buttons show while the pointer is over the widget and leave 1 s after it.
    HoverHandler {
        id: hover
        onHoveredChanged: if (!hovered) hideTimer.restart()
    }
    Timer {
        id: hideTimer
        interval: 1000
    }
    readonly property bool playerShown: !playerOnHover || hover.hovered || hideTimer.running

    // Previous, play/pause, next under the lyrics, M3 expressive buttons in the DMS theme colours.
    Row {
        id: transport
        // Under the sung line (a fifth of the space below lower), over the next ones while shown; kept inside the widget.
        y: Math.max(0, Math.min(overlay.focusBottom + Theme.spacingM + Math.max(0, root.height - overlay.focusBottom - height) * 0.2, root.height - height - Theme.spacingS))
        Behavior on y {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spacingS
        visible: root.showPlayer && root.playerOpacity > 0 && root.height >= 120
        opacity: root.playerShown ? root.playerOpacity : 0
        enabled: opacity > 0.05
        transform: Translate {
            y: root.playerShown ? 0 : Theme.spacingS
            Behavior on y {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        DIconButton {
            size: "s"
            widthMode: "wide"
            variant: "tonal"
            iconName: "skip_previous"
            iconFilled: false
            enabled: !!root.player?.canGoPrevious || !!root.player?.canSeek
            Accessible.name: I18n.tr("Previous")
            onClicked: MprisController.previousOrRewind()
        }

        DIconButton {
            readonly property bool playing: root.player?.playbackState === MprisPlaybackState.Playing
            size: "s"
            widthMode: "wide"
            variant: "filled"
            round: false
            checkable: true
            checked: playing
            iconName: playing ? "pause" : "play_arrow"
            enabled: !!root.player?.canTogglePlaying
            Accessible.name: playing ? I18n.tr("Pause") : I18n.tr("Play")
            onClicked: root.player.togglePlaying()
        }

        DIconButton {
            size: "s"
            widthMode: "wide"
            variant: "tonal"
            iconName: "skip_next"
            iconFilled: false
            enabled: !!root.player?.canGoNext
            Accessible.name: I18n.tr("Next")
            onClicked: MprisController.next()
        }
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
