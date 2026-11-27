import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
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
    // center, left, right, follow (the text's side) in a row; columnLeft, columnRight stacked.
    readonly property string playerPosition: pluginData.playerPosition ?? "center"
    readonly property real depthBlur: (pluginData.depthBlur ?? 40) / 100
    readonly property bool floatWords: pluginData.floatWords ?? true
    readonly property real textScale: (pluginData.textScale ?? 140) / 100
    readonly property real lineSpacing: pluginData.lineSpacing ?? 0
    readonly property real playerGap: pluginData.playerGap ?? 32
    // Other lines size, relative to the middle line; layout keeps full-size rows, so capped at 100%.
    readonly property real restScale: (pluginData.restScale ?? 80) / 100
    readonly property string textAlign: pluginData.textAlign ?? "auto"
    readonly property bool duetSides: pluginData.duetSides ?? true
    readonly property string singerName: pluginData.singerName ?? "change"
    readonly property real pyramid: (pluginData.pyramid ?? 15) / 100
    // Track artist plus a "feat." guest from the title when the artist field leaves it out.
    readonly property string artistLabel: {
        const artist = (player?.trackArtist ?? "").trim();
        const guest = /[(\[](?:feat\.?|ft\.?|with)\s+([^)\]]+)[)\]]/i.exec(player?.trackTitle ?? "")?.[1]?.trim() ?? "";
        if (!guest || artist.toLowerCase().includes(guest.toLowerCase()))
            return artist;
        return artist ? artist + " ft. " + guest : guest;
    }
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
        leftRoom: root.playerSide === "left" ? root.playerRoom : 0
        rightRoom: root.playerSide === "right" ? root.playerRoom : 0
        duetSides: root.duetSides
        singerName: root.singerName
        pointerOver: hover.hovered
        pyramid: root.pyramid
        artistLabel: root.artistLabel
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
    // A column needs the height of three buttons; a widget too short for it keeps a row on the same side.
    // Its buttons are narrow so the column stays thin beside the lyrics.
    readonly property bool playerColumn: (playerPosition === "columnLeft" || playerPosition === "columnRight")
        && height >= prevButton.height * 3 + transport.spacing * 2 + Theme.spacingS * 2
    readonly property string playerSide: {
        switch (playerPosition) {
        case "left":
        case "columnLeft":
            return "left";
        case "right":
        case "columnRight":
            return "right";
        case "follow":
            return resolvedAlign === "left" || resolvedAlign === "right" ? resolvedAlign : "center";
        }
        return "center";
    }
    // An always shown column pushes the lyrics aside; on hover it floats over them so the text never jumps.
    readonly property real playerRoom: playerColumn && transport.visible && !playerOnHover ? transport.width + root.playerGap : 0

    // Previous, play/pause, next in a row under the sung line, or in a column beside it.
    Grid {
        id: transport
        readonly property real edge: Math.max(Theme.spacingM, overlay.shapeInset)
        readonly property real minY: header.visible ? header.y + header.height + Theme.spacingS : Theme.spacingS
        columns: root.playerColumn ? 1 : 3
        spacing: Theme.spacingS
        x: root.playerSide === "left" ? edge : root.playerSide === "right" ? root.width - width - edge : (root.width - width) / 2
        // Row: under the sung line (a fifth of the space below lower), over the next ones while shown.
        // Column: centred on the sung line. Both kept inside the widget.
        y: root.playerColumn
            ? Math.max(minY, Math.min(overlay.focusCentre - height / 2, root.height - height - Theme.spacingS))
            : Math.max(0, Math.min(overlay.focusBottom + Theme.spacingM + Math.max(0, root.height - overlay.focusBottom - height) * 0.2, root.height - height - Theme.spacingS))
        Behavior on x {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
        visible: root.showPlayer && root.playerOpacity > 0 && root.height >= 120
        opacity: root.playerShown ? root.playerOpacity : 0
        enabled: opacity > 0.05
        // Slides in from the widget's edge in a column, from below in a row.
        transform: Translate {
            x: root.playerShown || !root.playerColumn ? 0 : root.playerSide === "left" ? -Theme.spacingS : Theme.spacingS
            y: root.playerShown || root.playerColumn ? 0 : Theme.spacingS
            Behavior on x {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        DIconButton {
            size: "s"
            widthMode: root.playerColumn ? "narrow" : "wide"
            variant: "tonal"
            id: prevButton
            iconName: "skip_previous"
            iconFilled: false
            enabled: !!root.player?.canGoPrevious || !!root.player?.canSeek
            Accessible.name: I18n.tr("Previous")
            onClicked: MprisController.previousOrRewind()
        }

        DIconButton {
            id: playButton
            readonly property bool playing: root.player?.playbackState === MprisPlaybackState.Playing
            size: "s"
            widthMode: root.playerColumn ? "narrow" : "wide"
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
            widthMode: root.playerColumn ? "narrow" : "wide"
            variant: "tonal"
            id: nextButton
            iconName: "skip_next"
            iconFilled: false
            enabled: !!root.player?.canGoNext
            Accessible.name: I18n.tr("Next")
            onClicked: MprisController.next()
        }
    }

    // See-through buttons blur what is behind them, with DMS's window blur. The region follows the
    // buttons once they settle; it is set while they show and dropped as soon as they start to hide.
    readonly property bool playerBlur: BlurService.enabled && transport.visible && playerShown && playerOpacity < 1
    Region {
        id: playerBlurRegion
        item: prevButton
        radius: prevButton.radius
        Region {
            item: playButton
            radius: playButton.radius
        }
        Region {
            item: nextButton
            radius: nextButton.radius
        }
    }
    function applyPlayerBlur() {
        const window = QsWindow.window;
        if (!window?.BackgroundEffect)
            return;
        window.BackgroundEffect.blurRegion = null;
        window.BackgroundEffect.blurRegion = playerBlur ? playerBlurRegion : null;
    }
    onPlayerBlurChanged: applyPlayerBlur()
    Timer {
        id: blurSettle
        interval: 320
        onTriggered: root.applyPlayerBlur()
    }
    Connections {
        target: transport
        function onXChanged() { if (root.playerBlur) blurSettle.restart(); }
        function onYChanged() { if (root.playerBlur) blurSettle.restart(); }
        function onColumnsChanged() { if (root.playerBlur) blurSettle.restart(); }
    }
    Component.onCompleted: applyPlayerBlur()
    Component.onDestruction: {
        const window = QsWindow.window;
        if (window?.BackgroundEffect)
            window.BackgroundEffect.blurRegion = null;
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
        // Same edge as the lyrics: the overlay's content inset plus its viewport margin.
        readonly property real edge: Math.max(Theme.spacingM, overlay.shapeInset)
        anchors.top: parent.top
        anchors.topMargin: Theme.spacingM
        x: root.resolvedAlign === "left" ? edge : root.resolvedAlign === "right" ? parent.width - width - edge : (parent.width - width) / 2
        layoutDirection: root.resolvedAlign === "right" ? Qt.RightToLeft : Qt.LeftToRight
        readonly property int textAlign: root.resolvedAlign === "right" ? Text.AlignRight : Text.AlignLeft
        width: Math.min(implicitWidth, parent.width - edge * 2)
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
                horizontalAlignment: header.textAlign
                font.family: root.fontFamily || Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Theme.fontWeightBold
                color: Theme.surfaceText
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                text: root.player?.trackArtist ?? ""
                horizontalAlignment: header.textAlign
                font.family: root.fontFamily || Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
            }
        }
    }
}
