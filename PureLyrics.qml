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
import qs.DCommon.Common
import qs.DCommon.Widgets
import "lyrics"

// Renders a copy of DMS's lyrics view (lyrics/, from DMS 2.1.2) on the desktop. Lyrics come from the
// shared LyricsService, so the dash and this widget never fetch the same song twice.
DesktopPluginComponent {
    id: root

    // "dms" (and "DMS font", saved by older versions) means the DMS font.
    readonly property string fontFamily: {
        const f = pluginData.fontFamily ?? "";
        return f === "dms" || f === "DMS font" ? "" : f;
    }
    readonly property int activeWeight: pluginData.activeWeight ?? 800
    readonly property int restWeight: pluginData.restWeight ?? 500
    readonly property bool smoothSweep: pluginData.smoothSweep ?? false
    readonly property bool oneLine: pluginData.oneLine ?? false
    // Low power drops the effects that redraw every frame while words are sung.
    readonly property bool lowPower: pluginData.lowPower ?? true
    readonly property bool shadow: !lowPower && (pluginData.shadow ?? true)
    readonly property bool glow: !lowPower && (pluginData.glow ?? false)
    readonly property bool showHeader: pluginData.showHeader ?? true
    readonly property real backgroundOpacity: (pluginData.backgroundOpacity ?? 0) / 100
    readonly property real borderOpacity: (pluginData.borderOpacity ?? 0) / 100
    readonly property bool showPlayer: pluginData.showPlayer ?? true
    readonly property real playerOpacity: (pluginData.playerOpacity ?? 100) / 100
    readonly property bool clickToSeek: pluginData.clickToSeek ?? true
    readonly property bool playerOnHover: pluginData.playerOnHover ?? true
    // A hover column can still keep its room beside the lyrics, so it never covers them.
    readonly property bool hoverRoom: pluginData.hoverRoom ?? false
    // center, left, right, follow (the text's side) in a row; columnLeft, columnRight stacked.
    readonly property string playerPosition: pluginData.playerPosition ?? "center"
    // Where the column's cover overhangs its narrow buttons: "inner" toward the lyrics, "outer" toward the widget's edge.
    readonly property string coverSide: pluginData.coverSide ?? "inner"
    readonly property real depthBlur: lowPower ? 0 : (pluginData.depthBlur ?? 40) / 100
    readonly property bool floatWords: !lowPower && (pluginData.floatWords ?? true)
    readonly property real textScale: (pluginData.textScale ?? 140) / 100
    readonly property real lineSpacing: pluginData.lineSpacing ?? 0
    readonly property real playerGap: pluginData.playerGap ?? 32
    // Other lines size, relative to the middle line; layout keeps full-size rows, so capped at 100%.
    readonly property real restScale: (pluginData.restScale ?? 80) / 100
    readonly property string textAlign: pluginData.textAlign ?? "auto"
    readonly property bool duetSides: pluginData.duetSides ?? true
    readonly property string singerName: pluginData.singerName ?? "change"
    readonly property real pyramid: (pluginData.pyramid ?? 15) / 100
    readonly property real distanceFade: (pluginData.distanceFade ?? 0) / 100
    readonly property bool showAttribution: pluginData.showAttribution ?? true
    // "feat." guests named in the title, e.g. "Song (ft. A et B)".
    readonly property string titleGuest: /[(\[](?:feat\.?|ft\.?|with)\s+([^)\]]+)[)\]]/i.exec(player?.trackTitle ?? "")?.[1]?.trim() ?? ""
    // Credited artists in order: the player's artist list, then the title's guests, without repeats.
    // Unnamed voices of the lyrics are matched to it by number (v2 → second credit).
    // shortcut: a single artist string like "A, B" stays one credit, since "Tyler, The Creator" holds a comma.
    readonly property var credits: {
        const listed = player?.metadata?.["xesam:artist"];
        const artists = typeof listed === "object" && listed?.length > 0 ? Array.from(listed) : [player?.trackArtist ?? ""];
        const guests = titleGuest.split(/\s*,\s*|\s+(?:&|et|and|x)\s+/i);
        const names = [];
        for (const name of artists.concat(guests).map(entry => String(entry).trim())) {
            if (name && !names.some(known => known.toLowerCase() === name.toLowerCase()))
                names.push(name);
        }
        return names;
    }
    // Track artist plus a "feat." guest from the title when the artist field leaves it out.
    readonly property string artistLabel: {
        const artist = (player?.trackArtist ?? "").trim();
        const guest = titleGuest;
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

    // DMS keeps the current player while it plays; here the player that starts last takes the lyrics.
    // YouTube thumbnail previews in Firefox play too, so they are left out.
    Instantiator {
        model: MprisController.availablePlayers
        delegate: QtObject {
            required property MprisPlayer modelData
            readonly property bool playing: modelData.isPlaying
            onPlayingChanged: {
                if (playing && modelData !== MprisController.activePlayer && !MprisController.isFirefoxYoutubeHoverPreview(modelData))
                    MprisController.setActivePlayer(modelData);
            }
        }
    }
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

    // DMS only corrects drift past 1 s. A gap past 0.2 s seen on two probes in a row gets corrected here,
    // and two probes keep one coarse Position from moving the lyrics.
    Timer {
        id: driftProbe
        property real lastDrift: 0
        interval: 2000
        repeat: true
        running: !!overlay && overlay.visible && overlay.synced && overlay.playing && overlay.controller.busName !== "" && DMSService.isConnected
        onRunningChanged: lastDrift = 0
        onTriggered: {
            const c = overlay.controller;
            const token = c.serial;
            const name = c.busName;
            DMSService.dbusGetProperty("session", name, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Position", response => {
                if (token !== c.serial || name !== c.busName || !c.playing || response.error)
                    return;
                const observed = Number(response.result?.value) / 1e6;
                const drift = observed - c.currentTime();
                if (!Number.isFinite(drift) || Math.abs(drift) < 0.2 || Math.abs(drift) >= 1) {
                    lastDrift = 0;
                    return;
                }
                if (Math.sign(drift) !== Math.sign(lastDrift)) {
                    lastDrift = drift;
                    return;
                }
                lastDrift = 0;
                c.anchorPosition = observed;
                c.anchorWall = Date.now();
                c.resync();
            });
        }
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
        lowPower: root.lowPower
        textAlign: root.resolvedAlign
        leftRoom: root.playerSide === "left" ? root.playerRoom : 0
        rightRoom: root.playerSide === "right" ? root.playerRoom : 0
        roomTop: (columnCover.visible ? columnCover.y : transport.y) - Theme.spacingS
        roomBottom: transport.y + transport.height + Theme.spacingS
        duetSides: root.duetSides
        singerName: root.singerName
        pointerOver: hover.hovered
        pyramid: root.pyramid
        distanceFade: root.distanceFade
        artistLabel: root.artistLabel
        credits: root.credits
        showAttribution: root.showAttribution
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
    // An always shown column pushes the lyrics aside; on hover it floats over them unless hoverRoom keeps
    // its room reserved while hidden too, so the text never jumps either way.
    // Measured from the column's widget-side edge to whichever reaches further in, buttons or the cover above them.
    readonly property real playerRoom: {
        if (!playerColumn || !transport.visible || playerOnHover && !hoverRoom)
            return 0;
        const left = transport.x, right = transport.x + transport.width;
        if (!columnCover.visible)
            return transport.width + playerGap;
        return (playerSide === "left" ? Math.max(right, columnCover.x + columnCover.width) - left : right - Math.min(left, columnCover.x)) + playerGap;
    }

    // Previous, play/pause, next in a row under the sung line, or in a column beside it.
    Grid {
        id: transport
        readonly property real edge: Math.max(Theme.spacingM, overlay.shapeInset)
        readonly property real minY: (header.visible ? header.y + header.height + Theme.spacingS : Theme.spacingS) + (columnCover.visible ? columnCover.height + spacing : 0)
        columns: root.playerColumn ? 1 : sourceButton.visible ? 4 : 3
        spacing: Theme.spacingS
        x: root.playerSide === "left" ? edge : root.playerSide === "right" ? root.width - width - edge : (root.width - width) / 2
        // Row: under the sung line (a fifth of the space below lower), over the next ones while shown.
        // Column: centred on the sung line. Both kept inside the widget.
        y: root.playerColumn
            ? Math.min(root.height - height - Theme.spacingS, Math.max(minY, overlay.focusCentre - height / 2))
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
            // 1.5× as long as the others along the buttons' axis: taller in a column, wider in a row.
            height: Math.round(buttonSize * (root.playerColumn ? 1.5 : 1))
            width: Math.round((iconSize + horizontalInset * 2) * (root.playerColumn ? 1 : 1.5))
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

        // Shown only with several players (Spotify, a browser tab...): a click hands lyrics to the next one.
        // setActivePlayer, not setPinned, so DMS's own player choice is left as the user set it.
        DIconButton {
            id: sourceButton
            readonly property var players: MprisController.availablePlayers
            size: "s"
            widthMode: root.playerColumn ? "narrow" : "wide"
            variant: "tonal"
            // 0.75× along the buttons' axis, so the column steps 1, 1.5, 1, 0.75 around the play button.
            height: Math.round(buttonSize * (root.playerColumn ? 0.75 : 1))
            width: Math.round((iconSize + horizontalInset * 2) * (root.playerColumn ? 1 : 0.75))
            visible: players.length > 1
            // Tertiary container: darker and set apart from the playback buttons.
            containerColor: Style.tertiaryContainer
            contentColor: Style.onTertiaryContainer
            iconName: "swap_horiz"
            iconFilled: false
            Accessible.name: I18n.tr("Switch source") + ": " + (root.player?.identity ?? "")
            onClicked: MprisController.setActivePlayer(players[(players.indexOf(root.player) + 1) % players.length])
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
        opacity: root.showHeader && root.height >= 140 && !overlay.unsynced && overlay.controller.activeIndex < 0 && !!root.player ? 1 : 0
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
            visible: art.status === Image.Ready && !columnCover.shown

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
            width: Math.min(Math.max(title.implicitWidth, artist.implicitWidth), header.parent.width - 48 - Theme.spacingM * 3)

            StyledText {
                id: title
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
                id: artist
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

    // In a column the header's cover sits on top of the buttons instead, spaced like them. It is wider
    // than the narrow buttons, so one edge lines up with theirs and it overhangs toward coverSide, kept in the widget.
    ClippingRectangle {
        id: columnCover
        readonly property bool shown: root.playerColumn && transport.visible && art.status === Image.Ready
        readonly property bool alignLeft: (root.playerSide === "left") === (root.coverSide === "inner")
        x: Math.max(0, Math.min(root.width - width, alignLeft ? transport.x : transport.x + transport.width - width))
        y: transport.y - height - transport.spacing
        width: 48
        height: 48
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHighest
        opacity: header.opacity
        visible: shown && header.visible

        Image {
            anchors.fill: parent
            source: art.source
            sourceSize: art.sourceSize
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }
}
