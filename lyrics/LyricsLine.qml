pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.DDash
import "LyricsModel.js" as LyricsModel

Item {
    id: root

    required property var item
    required property int index
    required property var controller
    // The playback time for the lines around the centre, -1 ahead of it and Infinity behind it.
    property real clock: -1
    property bool promoted: false
    property bool synced: true
    property bool following: true
    property bool playing: false
    property bool sweep: true
    property bool animationsEnabled: true
    property real leadFontSize: Theme.fontSizeXLarge
    property Item leadMetrics: null
    property Item backgroundMetrics: null
    property real breakSize: Theme.iconSizeLarge
    property real shift: 0
    // A line that playback moves on from keeps its highlight a moment before it dims.
    property bool lingering: false
    // A line left by a seek turns inactive at once and stays unsung until the dimming hides its real fill.
    property bool holding: false
    property real ringProgress: 0
    // pureLyrics: weight of the lines around the centre, and the readability shadow and glow.
    property int restWeight: Font.Medium
    property bool shadow: false
    property bool glow: false

    readonly property bool isBreak: item.kind === "break"
    // The move into the centre paces itself to the song, see LyricsController.prepareLines.
    readonly property int moveDuration: Math.round((item.move ?? DashMetrics.lyricsMoveMin) * 1000)
    readonly property bool isPlain: item.kind === "plain"
    readonly property bool lit: promoted || lingering
    readonly property real shownClock: holding ? -1 : clock
    readonly property real breakProgress: isBreak ? Math.max(0, Math.min(1, (clock - item.t) / (item.e - item.t))) : 0
    // Lines that wait or are done rest in one translucent colour, a single fade instead of a colour and
    // an opacity that move at different paces. While browsing every line stays fully visible.
    readonly property color restingColor: Theme.withAlpha(Theme.onSurfaceVariant, synced && following ? DashMetrics.lyricsLineInactiveAlpha : 1)
    readonly property bool shrunk: synced && following && !isPlain && !promoted
    // Every part is wrapped here, so the height is known when the row is created. A height that
    // settles a frame later moves the rows around it while the view scrolls past. Measuring writes
    // the probe's text, so this is rebuilt from handlers rather than bound.
    property var layouts: []
    readonly property font leadFont: leadMetrics?.font ?? Qt.font({})
    readonly property font backgroundFont: backgroundMetrics?.font ?? Qt.font({})

    property bool seekable: true
    // pureLyrics: "left", "center", "right" or "auto" (centred, singers on their side); duetSides keeps
    // the singers on their side in every mode. singerName: "change", "singing", "hover" or "off".
    property string textAlign: "auto"
    property bool duetSides: true
    property string singerName: "change"
    property bool pointerOver: false
    // Room above the line for the singer chip, counted in the overlay's heights too.
    property real chipSpace: 0
    // Shown when the lyrics do not say who sings: the track artist and featured artists.
    property string artistLabel: ""
    // Pyramid: each line further from the sung one shrinks by this much more, toward the sung line.
    property real pyramid: 0
    property bool before: false
    readonly property real shrinkScale: restScale * Math.pow(1 - pyramid, Math.max(0, depth - 1))
    // The whole line shrinks outside its cached layer, so a move only re-composites the texture
    // instead of redrawing the text, shadow and blur on every frame.
    readonly property int lineAlign: {
        const lead = layouts.find(layout => !layout.part.background);
        if (lead)
            return alignFor(lead.part);
        return textAlign === "left" ? Text.AlignLeft : textAlign === "right" ? Text.AlignRight : Text.AlignHCenter;
    }
    property real faceScale: shrunk ? shrinkScale : 1
    Behavior on faceScale {
        enabled: root.animationsEnabled
        NumberAnimation {
            duration: root.moveDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.moveCurve
        }
    }
    // Gentle start and a long soft landing (M3 emphasized), smoother than DMS's quick-start curve.
    readonly property var moveCurve: [0.2, 0, 0, 1, 1, 1]
    function originFor(alignment) {
        if (alignment === Text.AlignLeft)
            return before ? Item.BottomLeft : Item.TopLeft;
        if (alignment === Text.AlignRight)
            return before ? Item.BottomRight : Item.TopRight;
        return before ? Item.Bottom : Item.Top;
    }

    function alignFor(part) {
        if (part.side !== 0 && (duetSides || textAlign === "auto"))
            return (part.side < 0) !== LyricsModel.isRtl(part.x) ? Text.AlignLeft : Text.AlignRight;
        return textAlign === "left" ? Text.AlignLeft : textAlign === "right" ? Text.AlignRight : Text.AlignHCenter;
    }
    // One theme colour per singer; tertiary second, since secondary is often a greyer primary.
    function accentFor(part) {
        if (part.chorus)
            return Theme.secondary;
        if (part.side !== 0)
            return [Theme.primary, Theme.tertiary, Theme.secondary][part.voiceIndex % 3];
        return Theme.primary;
    }
    property real depth: 0
    property real depthBlur: 0
    property bool floatWords: false
    // Lines away from the centre go out of focus, more with distance; the layer redraws only while it moves.
    readonly property real blurAmount: synced && following && !promoted && !isBreak ? depthBlur * Math.min(1, depth / 3) : 0
    property real shownBlur: blurAmount
    Behavior on shownBlur {
        enabled: root.animationsEnabled
        NumberAnimation {
            duration: root.moveDuration
            easing.type: Easing.OutCubic
        }
    }
    property real restScale: DashMetrics.lyricsLineInactiveScale
    signal activated

    function relayout() {
        if (item.kind !== "line" || width <= 0 || !leadMetrics || !backgroundMetrics) {
            layouts = [];
            return;
        }
        layouts = LyricsModel.partLayouts(item.group.parts, width, leadMetrics, backgroundMetrics, Theme.spacingXS);
    }

    onWidthChanged: relayout()
    onItemChanged: relayout()
    onLeadFontChanged: relayout()
    onBackgroundFontChanged: relayout()
    Component.onCompleted: relayout()

    // The push starts from where the line was, so the view can snap and the lines catch up.
    function push(delta, delay) {
        pushMotion.stop();
        shift += delta;
        pushPause.duration = delay;
        pushMotion.start();
    }

    function settle() {
        pushMotion.stop();
        shift = 0;
    }

    onPromotedChanged: {
        lingerTimer.stop();
        fadeTimer.stop();
        lingering = !promoted && !controller.jumping;
        holding = !promoted && controller.jumping;
        if (holding) {
            ringProgress = 0;
            fadeTimer.start();
        } else if (lingering) {
            lingerTimer.start();
        }
    }

    implicitHeight: isPlain ? plainLoader.height + Theme.spacingS * 2 : LyricsModel.rowHeight(item, layouts, breakSize, Theme.spacingS, Theme.spacingXS) + chipSpace
    height: implicitHeight
    Accessible.role: Accessible.StaticText
    Accessible.name: isBreak ? I18n.tr("Instrumental", "Track has no lyrics because it is instrumental") : isPlain ? item.text : item.group.x
    ListView.onPooled: settle()
    ListView.onReused: {
        settle();
        lingerTimer.stop();
        fadeTimer.stop();
        lingering = false;
        holding = false;
        ringProgress = 0;
    }

    // Only the active break shows its progress, every other one rests empty like an unsung line. A
    // break that playback moves on from keeps its arc while it fades and empties once it is dim.
    Binding {
        target: root
        property: "ringProgress"
        value: root.breakProgress
        when: root.isBreak && root.lit
        restoreMode: Binding.RestoreNone
    }

    Timer {
        id: lingerTimer
        interval: DashMetrics.lyricsLineLinger
        onTriggered: {
            root.lingering = false;
            fadeTimer.start();
        }
    }

    Timer {
        id: fadeTimer
        interval: root.moveDuration
        onTriggered: {
            root.holding = false;
            root.ringProgress = 0;
        }
    }

    SequentialAnimation {
        id: pushMotion

        PauseAnimation {
            id: pushPause
        }

        NumberAnimation {
            target: root
            property: "shift"
            to: 0
            duration: root.moveDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.moveCurve
        }
    }

    Item {
        id: face

        width: root.width
        height: root.height
        transform: [
            Scale {
                origin.x: root.lineAlign === Text.AlignLeft ? 0 : root.lineAlign === Text.AlignRight ? face.width : face.width / 2
                origin.y: root.before ? face.height : 0
                xScale: root.faceScale
                yScale: root.faceScale
            },
            Translate {
                y: root.shift
            }
        ]
        // Re-rendered only when this line's content changes, not while the view scrolls or shrinks.
        layer.enabled: root.shadow || root.shownBlur > 0.01
        layer.smooth: true
        layer.mipmap: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            blurEnabled: root.shownBlur > 0.01
            blur: root.shownBlur
            blurMax: 24
            shadowEnabled: root.shadow
            shadowColor: Qt.rgba(0, 0, 0, 0.55)
            shadowBlur: 0.6
            shadowVerticalOffset: 2
        }

        Repeater {
            model: root.layouts

            LyricsPart {
                required property var modelData

                y: Theme.spacingS + root.chipSpace + modelData.y
                width: face.width
                layout: modelData
            }
        }

        Loader {
            id: breakLoader

            y: Theme.spacingS
            x: root.textAlign === "left" ? 0 : root.textAlign === "right" ? parent.width - width : (parent.width - width) / 2
            width: root.breakSize
            height: root.breakSize
            active: root.isBreak

            sourceComponent: DCircularWavyProgress {
                progress: root.ringProgress
                color: root.lit ? Theme.primary : root.restingColor
                trackColor: root.lit && root.following ? Theme.withAlpha(Theme.primary, DashMetrics.lyricsRestAlpha) : root.restingColor
                waveSpeed: root.promoted && root.playing && root.animationsEnabled ? wavelength : 0

                Behavior on color {
                    enabled: root.animationsEnabled
                    ColorAnimation {
                        duration: root.moveDuration
                    }
                }

                Behavior on trackColor {
                    enabled: root.animationsEnabled
                    ColorAnimation {
                        duration: root.moveDuration
                    }
                }
            }
        }

        Loader {
            id: plainLoader

            y: Theme.spacingS
            width: parent.width
            height: item?.implicitHeight ?? 0
            active: root.isPlain

            sourceComponent: StyledText {
                text: root.item.text || " "
                color: Theme.onSurfaceVariant
                font.pixelSize: root.leadFontSize
                font.weight: Theme.fontWeightMedium
                horizontalAlignment: root.textAlign === "left" ? Text.AlignLeft : root.textAlign === "right" ? Text.AlignRight : Text.AlignHCenter
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                Accessible.ignored: true
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.seekable && !root.isPlain && root.controller.canSeekLines
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activated()
        }
    }

    // Singer name: a tonal chip over the sung line, on the singer's side and in their colour. Kept
    // outside the face, whose layer would clip anything above the line.
    // Same scale and push as the face, so the chip sticks to its line frame by frame.
    Item {
        width: root.width
        height: root.height
        transform: [
            Scale {
                origin.x: root.lineAlign === Text.AlignLeft ? 0 : root.lineAlign === Text.AlignRight ? root.width : root.width / 2
                origin.y: root.before ? root.height : 0
                xScale: root.faceScale
                yScale: root.faceScale
            },
            Translate {
                y: root.shift
            }
        ]

    Repeater {
        model: root.singerName === "off" ? [] : root.layouts

        Item {
            id: chip

            required property var modelData
            readonly property var part: modelData.part
            readonly property int alignment: root.alignFor(part)
            readonly property color accent: root.accentFor(part)
            readonly property string name: part.voiceName || root.artistLabel
            readonly property bool named: !part.background && !!name
            property bool fresh: false
            readonly property bool shown: named && root.promoted && root.following && (root.singerName === "singing" || root.singerName === "hover" && root.pointerOver || root.singerName === "change" && fresh) && root.faceScale > 0.9

            x: alignment === Text.AlignLeft ? 0 : alignment === Text.AlignRight ? root.width - width : (root.width - width) / 2
            y: Theme.spacingS + root.chipSpace + modelData.y - height - Theme.spacingXS
            width: pill.width
            height: pill.height
            opacity: shown ? 1 : 0
            visible: opacity > 0
            transform: Translate {
                y: chip.shown ? 0 : Theme.spacingXS
                Behavior on y {
                    enabled: root.animationsEnabled
                    NumberAnimation {
                        duration: Theme.expressiveDurations.expressiveEffects
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                    }
                }
            }

            Behavior on opacity {
                enabled: root.animationsEnabled
                NumberAnimation {
                    duration: chip.shown ? 260 : 140
                    easing.type: Easing.OutCubic
                }
            }

            // Named once when the voice changes, then it fades.
            Connections {
                target: root
                function onPromotedChanged() {
                    chip.fresh = root.promoted && root.chipSpace > 0;
                    if (chip.fresh)
                        freshTimer.restart();
                }
            }
            Timer {
                id: freshTimer
                interval: 2200
                onTriggered: chip.fresh = false
            }

            Rectangle {
                id: pill
                width: Math.min(label.implicitWidth, root.width - dot.width - Theme.spacingS * 3) + dot.width + Theme.spacingS * 3
                height: label.implicitHeight + Theme.spacingXS * 2
                radius: height / 2
                color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.85)

                Rectangle {
                    id: dot
                    x: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 6
                    radius: 3
                    color: chip.accent
                }
                StyledText {
                    id: label
                    x: dot.x + dot.width + Theme.spacingXS + 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: pill.width - x - Theme.spacingS
                    text: chip.name
                    elide: Text.ElideRight
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: chip.accent
                }
            }
        }
    }
    }

    component LyricsPart: Item {
        id: lyricsPart

        required property var layout

        readonly property var part: layout.part
        readonly property bool timed: part.w.length > 0
        readonly property bool rtl: LyricsModel.isRtl(part.x)
        readonly property int alignment: root.alignFor(part)
        readonly property bool sung: root.shownClock >= part.t
        // A background part can still be sung after its line left the centre.
        readonly property bool lit: root.lit || (sung && root.shownClock < part.e)
        // Duets keep a colour per singer, a single voice takes the first one.
        readonly property color accent: root.accentFor(part)
        // While browsing every line rests in the same colour, so the playing one reads by its fill alone.
        readonly property color restColor: lit && root.following ? Theme.withAlpha(accent, DashMetrics.lyricsRestAlpha) : root.restingColor
        readonly property color fillColor: lit ? accent : root.restingColor

        height: layout.rows.length * layout.rowHeight
        // A background part still being sung keeps its size while the rest of its line shrinks. A lead
        // part that is still finishing as the next line moves in shrinks with its line.
        // The line shrinks as a whole (faceScale); a background part still being sung undoes it.
        scale: root.shrunk && part.background && root.clock >= part.t && root.clock < part.e ? 1 / root.faceScale : 1
        // Shrinks toward its aligned edge, so a left or right aligned column keeps one straight edge.
        transformOrigin: root.originFor(alignment)
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: true


        Repeater {
            model: lyricsPart.layout.rows

            Item {
                id: row

                required property var modelData
                required property int index
                // The edge sweeps each cue over its own time with a soft lead ahead of it, wide enough
                // to glide through a short syllable instead of flicking across it. Line timed parts
                // have no cues, so the whole line changes colour when it starts.
                readonly property real lead: root.sweep ? lyricsPart.layout.rowHeight * DashMetrics.lyricsSweepLead : 0
                readonly property real edge: {
                    if (!lyricsPart.timed || width <= 0)
                        return 0;
                    const edge = root.sweep ? LyricsModel.smoothEdge(modelData.segments, root.shownClock, lead, DashMetrics.lyricsSweepWindow) : LyricsModel.fillEdge(modelData.segments, root.shownClock, false, 0);
                    return Math.min(1, edge / width);
                }
                readonly property real feather: width > 0 ? lead / width : 0
                readonly property color restColor: !lyricsPart.timed && lyricsPart.sung ? lyricsPart.fillColor : lyricsPart.restColor
                // Floating words: each word rises as one solid piece over the time it is sung (a held word
                // rises slowly), glows while sung, and the line settles once it is no longer sung. Each word
                // draws its slice of the row through its own shader, so the glyphs never bend.
                readonly property bool floating: root.floatWords && root.animationsEnabled && lyricsPart.timed && !lyricsPart.part.background
                property real floatAmount: floating && root.promoted ? 1 : 0
                Behavior on floatAmount {
                    NumberAnimation {
                        duration: root.moveDuration
                        easing.type: Easing.InOutSine
                    }
                }
                // Visual [a, b) slices covering the whole row, cut halfway between words, with timings.
                readonly property var words: {
                    const segments = floating ? modelData.segments : [];
                    if (segments.length === 0 || width <= 0)
                        return [{ a: 0, b: width, t: Infinity, e: Infinity }];
                    const out = [];
                    for (let i = 0; i < segments.length; i++) {
                        const s = segments[i];
                        const start = i === 0 ? 0 : (segments[i - 1].x1 + s.x0) / 2;
                        const end = i === segments.length - 1 ? width : (s.x1 + segments[i + 1].x0) / 2;
                        const a = lyricsPart.rtl ? width - end : start;
                        const b = lyricsPart.rtl ? width - start : end;
                        out.push({ a: Math.floor(a), b: Math.ceil(b), t: s.t, e: s.e });
                    }
                    return out;
                }

                // Opening or closing punctuation hangs past the aligned edge, so the letters line up.
                readonly property real hang: lyricsPart.rtl ? 0 : lyricsPart.alignment === Text.AlignLeft ? -opening.advanceWidth : lyricsPart.alignment === Text.AlignRight ? closing.advanceWidth : 0
                TextMetrics {
                    id: opening
                    font: glyphs.font
                    text: /^[(\[“‘"'«¿¡]/.test(row.modelData.text) ? row.modelData.text[0] : ""
                }
                TextMetrics {
                    id: closing
                    font: glyphs.font
                    text: /[)\]”’"'»,.]$/.test(row.modelData.text) ? row.modelData.text[row.modelData.text.length - 1] : ""
                }
                x: Math.round(hang + (lyricsPart.alignment === Text.AlignLeft ? 0 : lyricsPart.alignment === Text.AlignRight ? lyricsPart.width - width : (lyricsPart.width - width) / 2))
                y: index * lyricsPart.layout.rowHeight
                width: modelData.width
                height: lyricsPart.layout.rowHeight

                StyledText {
                    id: glyphs
                    width: row.width
                    height: row.height
                    text: row.modelData.text
                    font.family: lyricsPart.layout.font.family
                    font.pixelSize: lyricsPart.layout.font.pixelSize
                    // Rows are laid out with the active weight; restWeight is clamped below it so a resting row never overflows.
                    font.weight: lyricsPart.part.background || root.promoted ? lyricsPart.layout.font.weight : Math.min(root.restWeight, lyricsPart.layout.font.weight)
                    horizontalAlignment: lyricsPart.alignment
                    // Only the coverage reaches the shader, the colour is applied there.
                    color: Theme.surfaceText
                    wrapMode: Text.NoWrap
                    Accessible.ignored: true
                }

                ShaderEffectSource {
                    id: glyphSource
                    sourceItem: glyphs
                    hideSource: true
                    smooth: true
                }

                MultiEffect {
                    id: glowEffect
                    anchors.fill: parent
                    source: glyphSource
                    visible: root.glow && root.promoted && !lyricsPart.part.background
                    autoPaddingEnabled: true
                    blurEnabled: true
                    blurMax: 32
                    blur: 1
                    colorization: 1
                    colorizationColor: lyricsPart.fillColor
                    brightness: 0.3
                    opacity: 0.5

                    SequentialAnimation on opacity {
                        running: glowEffect.visible && root.playing && root.animationsEnabled
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.75; duration: 1600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.35; duration: 1600; easing.type: Easing.InOutSine }
                    }
                }

                Repeater {
                    model: row.words

                    Item {
                        id: word

                        required property var modelData
                        readonly property bool started: root.shownClock >= modelData.t
                        readonly property bool singing: started && root.shownClock < modelData.e
                        property real rise: 0
                        property real shine: singing && row.floatAmount > 0 ? 1 : 0

                        x: modelData.a
                        width: modelData.b - modelData.a
                        height: row.height
                        clip: true
                        transform: Translate {
                            y: -row.height * 0.08 * word.rise * row.floatAmount
                        }

                        Component.onCompleted: rise = started ? 1 : 0
                        onStartedChanged: {
                            riseAnimation.stop();
                            if (!started) {
                                rise = 0;
                                return;
                            }
                            riseAnimation.duration = Math.max(280, Math.min(1600, (modelData.e - root.shownClock) * 1000));
                            riseAnimation.start();
                        }
                        NumberAnimation {
                            id: riseAnimation
                            target: word
                            property: "rise"
                            to: 1
                            easing.type: Easing.OutCubic
                            paused: running && !root.playing
                        }
                        Behavior on shine {
                            NumberAnimation {
                                duration: word.singing ? 180 : 700
                                easing.type: Easing.OutCubic
                            }
                        }

                        ShaderEffect {
                            x: -word.x
                            width: row.width
                            height: row.height
                            property var source: glyphSource
                            property color restColor: row.restColor
                            property color fillColor: lyricsPart.fillColor
                            property real edge: row.edge
                            property real feather: row.feather
                            property real rtl: lyricsPart.rtl ? 1 : 0
                            property real shine: word.shine
                            fragmentShader: Qt.resolvedUrl("../shaders/lyrics_float.frag.qsb")

                            Behavior on restColor {
                                enabled: root.animationsEnabled
                                ColorAnimation {
                                    duration: root.moveDuration
                                }
                            }

                            Behavior on fillColor {
                                enabled: root.animationsEnabled
                                ColorAnimation {
                                    duration: root.moveDuration
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
