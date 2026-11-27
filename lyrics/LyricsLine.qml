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

    implicitHeight: isPlain ? plainLoader.height + Theme.spacingS * 2 : LyricsModel.rowHeight(item, layouts, breakSize, Theme.spacingS, Theme.spacingXS)
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
            easing.bezierCurve: DashMetrics.lyricsTrackCurve
        }
    }

    Item {
        id: face

        width: root.width
        height: root.height
        transform: Translate {
            y: root.shift
        }
        // Re-rendered only when this line's content changes, not while the view scrolls.
        layer.enabled: root.shadow || root.shownBlur > 0.01
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

                y: Theme.spacingS + modelData.y
                width: face.width
                layout: modelData
            }
        }

        Loader {
            id: breakLoader

            y: Theme.spacingS
            width: parent.width
            height: root.breakSize
            active: root.isBreak
            scale: root.shrunk ? root.restScale : 1

            Behavior on scale {
                enabled: root.animationsEnabled
                NumberAnimation {
                    duration: root.moveDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: DashMetrics.lyricsTrackCurve
                }
            }

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
                horizontalAlignment: Text.AlignHCenter
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

    component LyricsPart: Item {
        id: lyricsPart

        required property var layout

        readonly property var part: layout.part
        readonly property bool timed: part.w.length > 0
        readonly property bool rtl: LyricsModel.isRtl(part.x)
        readonly property int alignment: part.side === 0 ? Text.AlignHCenter : (part.side < 0) !== rtl ? Text.AlignLeft : Text.AlignRight
        readonly property bool sung: root.shownClock >= part.t
        // A background part can still be sung after its line left the centre.
        readonly property bool lit: root.lit || (sung && root.shownClock < part.e)
        // Duets keep a colour per singer, a single voice takes the first one.
        readonly property color accent: {
            if (part.chorus)
                return Theme.primary;
            if (part.side !== 0)
                return [Theme.primary, Theme.secondary, Theme.tertiary][part.voiceIndex % 3];
            return Theme.primary;
        }
        // While browsing every line rests in the same colour, so the playing one reads by its fill alone.
        readonly property color restColor: lit && root.following ? Theme.withAlpha(accent, DashMetrics.lyricsRestAlpha) : root.restingColor
        readonly property color fillColor: lit ? accent : root.restingColor

        height: layout.rows.length * layout.rowHeight
        // A background part still being sung keeps its size while the rest of its line shrinks. A lead
        // part that is still finishing as the next line moves in shrinks with its line.
        scale: root.shrunk && !(part.background && root.clock >= part.t && root.clock < part.e) ? root.restScale : 1
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: true

        Behavior on scale {
            enabled: root.animationsEnabled
            NumberAnimation {
                duration: root.moveDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: DashMetrics.lyricsTrackCurve
            }
        }

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
                // Floating words rise letter by letter at the singer's pace. With the smooth sweep the lift
                // rides the fill edge; without it the fill steps per word, so on each cue the lift crosses
                // the word being sung over that word's own sung time (a held word rises slowly).
                readonly property bool floating: root.floatWords && root.animationsEnabled && lyricsPart.timed && !lyricsPart.part.background
                property real liftEdge: -1
                function retarget() {
                    if (!floating || width <= 0)
                        return;
                    if (root.sweep) {
                        liftAnimation.stop();
                        liftEdge = edge;
                        return;
                    }
                    const at = root.shownClock;
                    const segment = modelData.segments.find(s => at >= s.t && at < s.e);
                    liftAnimation.stop();
                    if (segment) {
                        liftAnimation.from = Math.max(liftEdge, segment.x0 / width);
                        liftAnimation.to = segment.x1 / width;
                        liftAnimation.duration = Math.max(1, (segment.e - at) * 1000);
                        liftAnimation.easing.type = Easing.Linear;
                    } else {
                        liftAnimation.from = liftEdge;
                        liftAnimation.to = edge;
                        liftAnimation.duration = 200;
                        liftAnimation.easing.type = Easing.OutCubic;
                    }
                    liftAnimation.start();
                }
                onEdgeChanged: retarget()
                Connections {
                    target: root
                    enabled: row.floating && !root.sweep
                    function onShownClockChanged() {
                        row.retarget();
                    }
                }
                NumberAnimation {
                    id: liftAnimation
                    target: row
                    property: "liftEdge"
                    paused: running && !root.playing
                }
                property real floatAmount: floating && root.promoted ? 1 : 0
                Behavior on floatAmount {
                    NumberAnimation {
                        duration: root.moveDuration
                        easing.type: Easing.InOutSine
                    }
                }

                x: Math.round(lyricsPart.alignment === Text.AlignLeft ? 0 : lyricsPart.alignment === Text.AlignRight ? lyricsPart.width - width : (lyricsPart.width - width) / 2)
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

                ShaderEffect {
                    anchors.fill: parent
                    property var source: glyphSource
                    property color restColor: row.restColor
                    property color fillColor: lyricsPart.fillColor
                    property real edge: row.edge
                    property real feather: row.feather
                    property real rtl: lyricsPart.rtl ? 1 : 0
                    property real lift: 0.07 * row.floatAmount
                    property real liftEdge: row.liftEdge
                    property real ramp: row.width > 0 ? lyricsPart.layout.rowHeight * 0.9 / row.width : 0
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
