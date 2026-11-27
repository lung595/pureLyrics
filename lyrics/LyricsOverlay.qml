pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Widgets
import qs.Services
import qs.Modules.DDash
import "LyricsModel.js" as LyricsModel

FocusScope {
    id: root

    property var player: null
    property var lyrics: null
    property real radius: DashMetrics.mediaInnerRadius
    property color backgroundColor: DashMetrics.cardColor
    property bool following: true
    property real now: 0
    // Low power steps a smooth sweep at 30 fps instead of every frame.
    property bool lowPower: false
    property int pushedItem: -1
    property bool animateFollow: false
    property var heightCache: ({})
    // pureLyrics options.
    property string fontFamily: ""
    property int activeWeight: Theme.fontWeightBold
    property int restWeight: Theme.fontWeightMedium
    property bool shadow: false
    property bool glow: false
    property bool oneLine: false
    property bool clickToSeek: true
    property real textScale: 1
    property real lineSpacing: 0
    property string textAlign: "auto"
    property bool duetSides: true
    property string singerName: "change"
    property bool pointerOver: false
    property real pyramid: 0
    property real distanceFade: 0
    property string artistLabel: ""
    // Space reserved above a line whose singer chip can show, so the chip never covers the line
    // before. "change" names the singer when the voice changes, or after a break without voices.
    readonly property real chipHeight: Math.ceil(Theme.fontSizeSmall * 1.35) + Theme.spacingXS * 3
    function leadPart(index) {
        return items[index]?.group?.parts.find(part => !part.background);
    }
    function chipSpace(index) {
        const part = leadPart(index);
        if (!part || singerName === "off" || !(part.voiceName || artistLabel))
            return 0;
        if (singerName !== "change")
            return chipHeight;
        if (!part.voice)
            return index === 0 || items[index - 1]?.kind !== "line" ? chipHeight : 0;
        for (let i = index - 1; i >= 0; i--) {
            const before = leadPart(i);
            if (before)
                return before.voice !== part.voice ? chipHeight : 0;
        }
        return chipHeight;
    }
    // Bottom of the centred line, in this item's coordinates; the widget puts its player there.
    property real centreHeight: 0
    // The singer chip band at the top of the centred line, left out of its text centre.
    property real centreChip: 0
    // In overlay coordinates, so items outside the view (a player column) can line up with it.
    readonly property real focusBottom: content.y + viewport.y + transcript.height / 2 + centreHeight / 2
    readonly property real focusCentre: focusBottom - (centreHeight - centreChip) / 2
    // Extra room kept free on each side, for a player column that is always shown.
    property real leftRoom: 0
    property real rightRoom: 0
    // Vertical band (overlay coordinates) taken by whatever needs the room, e.g. a player column.
    property real roomTop: 0
    property real roomBottom: 0
    property real depthBlur: 0
    property bool floatWords: false
    property real restScale: DashMetrics.lyricsLineInactiveScale
    property bool showAttribution: true
    // Lines shrink with their distance from this one: the sung line, or while browsing the one at the view's centre.
    property int browseCentre: -1
    readonly property int depthCentre: following ? centreItem : browseCentre
    property var squeezes: []
    onDepthCentreChanged: updateSqueeze()
    onRestScaleChanged: updateSqueeze()
    onPyramidChanged: updateSqueeze()

    readonly property var controller: root.lyrics ?? LyricsService.controller
    readonly property bool ready: controller.state === "ready"
    readonly property bool synced: controller.synced
    readonly property bool unsynced: ready && !synced
    readonly property bool showFollow: ready && synced && !following
    readonly property bool animationsEnabled: !SettingsData.reduceMotion && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
    readonly property bool sweep: (root.player?.smoothLyrics ?? MediaOptions.defaults.smoothLyrics) && animationsEnabled
    readonly property bool playing: controller.playing
    readonly property real sampleTime: controller.sampleTime
    readonly property string trackKey: controller.trackKey
    readonly property var items: synced ? LyricsModel.buildItems(LyricsModel.estimateWords(controller.lines), DashMetrics.lyricsBreakGap) : LyricsModel.plainItems(controller.plainLines)
    readonly property int trackedCentre: synced ? LyricsModel.centreItem(items, sampleTime, controller.followIndex) : -1
    property int centreItem: -1
    property real centreTime: -Infinity
    // Only a word sweep or a break moves every frame between the controller's cue ticks.
    readonly property bool needsClock: {
        const item = items[centreItem];
        if (!item)
            return false;
        if (item.kind === "break")
            return true;
        return sweep && item.group.parts.some(part => part.w.length > 0);
    }
    // Estimated words without a sweep only change at their own cues, which the controller does not tick.
    readonly property bool needsCues: {
        const item = items[centreItem];
        return !needsClock && !!item && item.kind !== "break" && item.group.parts.some(part => part.estimated);
    }
    readonly property bool clockActive: visible && ready && synced && playing && needsClock
    readonly property bool cueClockActive: visible && ready && synced && playing && needsCues
    onCueClockActiveChanged: stepCue()
    readonly property bool userScrolling: transcript.isUserScrolling || transcript.dragging
    readonly property real shapeInset: Math.ceil(Math.min(radius, width / 2, height / 2) * (1 - Math.SQRT1_2))
    readonly property bool compact: content.height < Theme.listItemTwoLineHeight * 2
    readonly property real breakSize: Math.round(leadFontSize * DashMetrics.lyricsBreakIndicatorScale)
    readonly property real leadFontSize: Math.round(textScale * Math.max(Theme.fontSizeXLarge, Math.min(Theme.fontSizeDisplay, transcript.height / DashMetrics.lyricsLeadHeightDivisor, transcript.width / DashMetrics.lyricsLeadWidthDivisor)))
    // The ends leave room for half a single row line, so scrolling stops with the first or last line centred.
    readonly property real endPadding: synced ? Math.max(0, transcript.height / 2 - (leadFontMetrics.lineHeight + Theme.spacingS * 2) / 2) : Theme.spacingS
    readonly property real edgeFade: Math.min(transcript.height * DashMetrics.lyricsEdgeFadeRatio, DashMetrics.lyricsEdgeFadeMax)
    readonly property string message: {
        switch (controller.state) {
        case "instrumental":
            return I18n.tr("Instrumental", "Track has no lyrics because it is instrumental");
        case "error":
            return I18n.tr("Unavailable");
        case "none":
            return I18n.tr("No results");
        }
        return "";
    }

    activeFocusOnTab: true
    Accessible.role: Accessible.Pane
    Accessible.name: I18n.tr("Lyrics", "Media player lyrics button")
    // A position correction or a floored resume can set the clock back a second just after the view
    // moved on, which would scroll back to the previous row and forward again a moment later.
    onTrackedCentreChanged: {
        const backstep = synced && trackedCentre >= 0 && trackedCentre === centreItem - 1;
        if (backstep && sampleTime < centreTime && centreTime - sampleTime < DashMetrics.lyricsFollowBackstepSlack)
            return;
        centreTime = sampleTime;
        centreItem = trackedCentre;
    }
    onCentreItemChanged: {
        requestFollow(true);
        if (cueClockActive)
            stepCue();
    }
    Component.onCompleted: centreItem = trackedCentre
    onItemsChanged: {
        pushedItem = -1;
        centreTime = -Infinity;
        centreItem = trackedCentre;
        requestFollow(false);
    }
    onReadyChanged: requestFollow(false)
    onWidthChanged: requestFollow(false)
    // Lines are narrower by the room a player column takes; their heights follow that width.
    readonly property real lineWidth: Math.max(0, transcript.width - leftRoom - rightRoom)
    onLineWidthChanged: requestFollow(false)
    onHeightChanged: requestFollow(false)
    onLeadFontSizeChanged: requestFollow(false)
    onSampleTimeChanged: {
        if (!clockActive)
            now = sampleTime;
        if (cueClockActive)
            stepCue();
    }
    onTrackKeyChanged: {
        if (controller.holdsSong())
            return;
        following = true;
        transcript.stopMomentum();
        transcript.positionViewAtBeginning();
        requestFollow(false);
    }
    onUserScrollingChanged: {
        if (userScrolling)
            browse();
    }

    LyricsSubscription {
        active: root.visible && !root.lyrics
    }

    Binding {
        target: root.player
        when: root.player !== null
        property: "lyricsFocusTarget"
        value: root
        restoreMode: Binding.RestoreBindingOrValue
    }

    function browse() {
        following = false;
        browseCentre = centreItem;
        scrollSpring.snapTo(transcript.contentY);
        settleRows();
    }

    function resume() {
        following = true;
        forceActiveFocus(Qt.OtherFocusReason);
        requestFollow(true);
    }

    function requestFollow(animate) {
        animateFollow = animate && (followTimer.running ? animateFollow : true);
        followTimer.restart();
    }

    function settleRows() {
        for (const row of transcript.contentItem.children) {
            if (row.settle)
                row.settle();
        }
    }

    // The view snaps to the new centre and every row is pushed back by the same distance, so the
    // rows can catch up one after another: the new line leads and the others follow outwards.
    function followCurrent() {
        const animate = animateFollow && animationsEnabled && pushedItem >= 0;
        animateFollow = false;
        if (!ready || !synced) {
            centreHeight = 0;
            centreChip = 0;
            return;
        }
        if (!following || transcript.count === 0)
            return;
        const centre = Math.max(0, centreItem);
        const jump = Math.abs(centre - pushedItem) > 1;
        pushedItem = centre;
        heightCache = {};
        centreHeight = cachedHeight(centre);
        centreChip = chipSpace(centre);
        updateSqueeze();
        // A scroll on its way retargets to the active line on every step.
        if (scrollSpring.running)
            return;
        transcript.stopMomentum();
        transcript.forceLayout();
        const target = Math.round(centreOffset(centre));
        const delta = target - transcript.contentY;
        if (delta === 0)
            return;
        // Rows far off are only laid out by moving there, so a jump lets the view place them.
        if (!animate && Math.abs(delta) > transcript.height) {
            settleRows();
            transcript.positionViewAtIndex(centre, ListView.Center);
            return;
        }
        // Further than a view away the rows cannot catch up one by one, so the view scrolls there.
        if (animate && Math.abs(delta) > transcript.height) {
            settleRows();
            scrollSpring.snapTo(transcript.contentY);
            scrollSpring.retarget(target);
            return;
        }
        transcript.contentY = target;
        if (!animate) {
            settleRows();
            return;
        }
        transcript.forceLayout();
        for (const row of transcript.contentItem.children) {
            if (!row.push || row.index < 0)
                continue;
            const lag = Math.abs(centre - row.index);
            row.push(delta, jump ? 0 : Math.min(lag, DashMetrics.lyricsTrackMaxPush) * row.moveDuration * DashMetrics.lyricsTrackPushShare);
        }
    }

    // The same sum a row makes of its height, so a line without a row is placed exactly.
    function itemHeight(index) {
        const item = items[index];
        if (!item)
            return 0;
        const layouts = item.kind === "line" ? LyricsModel.partLayouts(item.group.parts, lineWidth, leadFontMetrics, backgroundFontMetrics, Theme.spacingXS) : [];
        return LyricsModel.rowHeight(item, layouts, breakSize, Theme.spacingS, Theme.spacingXS) + chipSpace(index);
    }

    // Counted from the row in the middle of the view, which is always laid out for real. The view
    // keeps far off rows such as the first one at a guessed y, and lines without a row have none.
    function centreOffset(centre) {
        let anchor = transcript.itemAtIndex(transcript.indexAt(transcript.width / 2, transcript.contentY + transcript.height / 2));
        if (!anchor)
            anchor = transcript.itemAtIndex(Math.max(0, centreItem));
        if (!anchor)
            return transcript.contentY;
        let y = anchor.y;
        if (centre > anchor.index) {
            for (let i = anchor.index; i < centre; i++)
                y += cachedHeight(i) + transcript.spacing;
        } else {
            for (let i = centre; i < anchor.index; i++)
                y -= cachedHeight(i) + transcript.spacing;
        }
        return y + cachedHeight(centre) / 2 - transcript.height / 2;
    }

    // The size a row shrinks to, as LyricsLine.faceScale once it settles.
    function rowScale(index) {
        const depth = Math.abs(index - depthCentre);
        if (!synced || depth === 0 || items[index]?.kind === "plain")
            return 1;
        return restScale * Math.pow(1 - pyramid, depth - 1);
    }

    // Rows keep their full height in the view, so each one moves toward the centre line by the room
    // the shrunk rows between them leave free, and the lines stay evenly spaced at any size. Set from
    // handlers, since measuring a height writes the probe's text. Counted as far as rows can be laid out.
    function updateSqueeze() {
        const out = [];
        if (depthCentre >= 0) {
            for (const step of [-1, 1]) {
                let sum = 0;
                let reach = 0;
                for (let i = depthCentre + step; i >= 0 && i < items.length && reach < transcript.height * 2; i += step) {
                    out[i] = -step * sum;
                    const height = cachedHeight(i);
                    sum += (1 - rowScale(i)) * height;
                    reach += height;
                }
            }
        }
        squeezes = out;
    }

    function cachedHeight(index) {
        if (!(index in heightCache))
            heightCache[index] = itemHeight(index);
        return heightCache[index];
    }

    function scrollBy(amount) {
        browse();
        transcript.stopMomentum();
        transcript.contentY = Math.max(transcript.originY, Math.min(transcript.maximumContentY, transcript.contentY + amount));
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Up:
            scrollBy(-Theme.listItemHeight);
            break;
        case Qt.Key_Down:
            scrollBy(Theme.listItemHeight);
            break;
        case Qt.Key_PageUp:
            scrollBy(-transcript.height);
            break;
        case Qt.Key_PageDown:
            scrollBy(transcript.height);
            break;
        case Qt.Key_Home:
            browse();
            transcript.stopMomentum();
            transcript.positionViewAtBeginning();
            break;
        case Qt.Key_End:
            browse();
            transcript.stopMomentum();
            transcript.positionViewAtEnd();
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    // A spring keeps its speed when the active line changes on the way, so the scroll bends towards
    // the new line instead of starting over.
    SpringMotion {
        id: scrollSpring
        enabled: !Theme.springMotionDisabled
        stiffness: DashMetrics.lyricsScrollStiffness
        damping: DashMetrics.lyricsScrollDamping
        positionEpsilon: DashMetrics.lyricsScrollSettleDistance
        velocityEpsilon: DashMetrics.lyricsScrollSettleSpeed
        onValueChanged: {
            if (!running)
                return;
            transcript.contentY = Math.round(value);
            retarget(root.centreOffset(Math.max(0, root.centreItem)));
        }
    }

    Timer {
        id: followTimer
        interval: 0
        onTriggered: root.followCurrent()
    }

    // Wakes at the centre line's next cue only, so the scene redraws once per word instead of every frame.
    function stepCue() {
        cueClock.stop();
        if (!cueClockActive)
            return;
        now = controller.shownTime();
        let next = Infinity;
        for (const part of items[centreItem]?.group?.parts ?? []) {
            for (const cue of [part, ...part.w]) {
                if (cue.t > now)
                    next = Math.min(next, cue.t);
                else if (cue.e > now)
                    next = Math.min(next, cue.e);
            }
        }
        if (!Number.isFinite(next))
            return;
        cueClock.interval = Math.max(1, Math.min(2147483647, Math.ceil((next - now) * 1000 / Math.max(0.01, controller.rate)) + 1));
        cueClock.start();
    }

    Timer {
        id: cueClock
        onTriggered: root.stepCue()
    }

    FrameAnimation {
        id: clock
        running: root.clockActive && !root.lowPower
        onTriggered: root.now = root.controller.shownTime()
        onRunningChanged: root.now = root.controller.shownTime()
    }

    Timer {
        id: slowClock
        interval: 33
        repeat: true
        running: root.clockActive && root.lowPower
        onTriggered: root.now = root.controller.shownTime()
        onRunningChanged: root.now = root.controller.shownTime()
    }

    NumberAnimation on opacity {
        running: root.animationsEnabled
        from: 0
        to: 1
        duration: Theme.expressiveDurations.expressiveEffects
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.backgroundColor
        antialiasing: true
    }

    LineMeasure {
        id: leadFontMetrics
        font.pixelSize: root.leadFontSize
        font.weight: root.activeWeight
        font.family: root.fontFamily || Theme.fontFamily
    }

    LineMeasure {
        id: backgroundFontMetrics
        font.pixelSize: Math.round(root.leadFontSize * Theme.fontSizeLarge / Theme.fontSizeXLarge)
        font.weight: Theme.fontWeightMedium
        font.family: root.fontFamily || Theme.fontFamily
    }

    // Rows are measured by the same text type that draws them, so a row never comes out wider than it was laid out.
    component LineMeasure: Item {
        id: measure

        property alias font: probe.font
        readonly property real lineHeight: metrics.height

        visible: false

        function advanceWidth(text) {
            probe.text = text;
            return probe.implicitWidth;
        }

        StyledText {
            id: probe
            visible: false
            wrapMode: Text.NoWrap
            elide: Text.ElideNone
        }

        FontMetrics {
            id: metrics
            font: probe.font
        }
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: Math.max(0, root.shapeInset - Theme.spacingM)

        StyledText {
            id: heading
            anchors.top: parent.top
            anchors.topMargin: Theme.spacingM
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - Theme.spacingM * 2
            text: I18n.tr("Unsynced", "Lyrics have no timestamps")
            color: Theme.onSurfaceVariant
            font.pixelSize: Theme.fontSizeSmall
            horizontalAlignment: Text.AlignHCenter
            visible: root.unsynced && !root.compact
        }

        Item {
            id: viewport

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: heading.visible ? heading.bottom : parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: Theme.spacingM
            anchors.bottomMargin: Theme.spacingM
            // Clipped here rather than on the view, so hanging punctuation keeps the side margins.
            clip: true
            visible: root.ready
            opacity: root.ready ? 1 : 0

            Behavior on opacity {
                enabled: root.animationsEnabled
                NumberAnimation {
                    duration: Theme.expressiveDurations.expressiveEffects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                }
            }

            DListView {
                id: transcript

                anchors.fill: parent
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                spacing: root.lineSpacing
                fadeEdges: false
                showScrollBar: false
                clip: false
                reuseItems: true
                // Shrunk rows squeeze toward the centre, so rows laid out further away still show.
                cacheBuffer: Math.max(0, Math.round(height))
                model: root.items
                add: null
                remove: null
                displaced: null
                move: null
                onCountChanged: root.requestFollow(false)
                onContentYChanged: {
                    if (root.following)
                        return;
                    const index = indexAt(width / 2, contentY + height / 2);
                    if (index >= 0)
                        root.browseCentre = index;
                }
                header: Item {
                    width: transcript.width
                    height: root.endPadding
                }
                footer: Item {
                    width: transcript.width
                    height: Math.max(root.endPadding, credit.visible ? credit.implicitHeight + Theme.spacingM * 2 : 0)

                    StyledText {
                        id: credit
                        anchors.top: parent.top
                        anchors.topMargin: Theme.spacingM
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(implicitWidth, parent.width)
                        text: root.controller.attributionName
                        visible: root.showAttribution
                        color: Theme.outline
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }

                    StateLayer {
                        anchors.fill: credit
                        anchors.margins: -Theme.spacingXS
                        cornerRadius: Theme.cornerRadius
                        stateColor: Theme.outline
                        visible: credit.visible && root.controller.attributionUrl !== ""
                        tooltipText: root.controller.attributionText || root.controller.attributionUrl
                        onClicked: Qt.openUrlExternally(root.controller.attributionUrl)
                    }
                }

                delegate: LyricsLine {
                    id: line

                    required property var modelData
                    readonly property bool live: Math.abs(index - root.centreItem) <= 1
                    // Where the row shows once shrunk and squeezed toward the centre line.
                    readonly property real shownTop: y + squeeze + (before ? (1 - faceScale) * height : 0)
                    readonly property real shownHeight: height * faceScale
                    // Faded per row rather than through a layer over the view, so a sung word only repaints its own row.
                    readonly property real edgeDistance: Math.min(shownTop + shownHeight / 2 - transcript.contentY, transcript.contentY + transcript.height - shownTop - shownHeight / 2)

                    // Room for a player column, in three steps so the edges line up: a line beside it clears it
                    // fully, one within half its height clears half, the rest stay at the edge. Lines keep one
                    // width and only slide, so text never rewraps while scrolling.
                    readonly property real lineTop: content.y + viewport.y + shownTop - transcript.contentY
                    readonly property real gapToRoom: Math.max(0, root.roomTop - (lineTop + shownHeight), lineTop - root.roomBottom)
                    readonly property real indentTarget: root.leftRoom + root.rightRoom <= 0 ? 0 : gapToRoom <= 0 ? 1 : gapToRoom < (root.roomBottom - root.roomTop) / 2 ? 0.5 : 0
                    property real indent: indentTarget
                    Behavior on indent {
                        enabled: root.animationsEnabled
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                    width: root.lineWidth
                    // Text aligned away from the column keeps its edge where the column is cleared.
                    readonly property bool pinned: root.rightRoom > 0 && line.lineAlign === Text.AlignLeft || root.leftRoom > 0 && line.lineAlign === Text.AlignRight
                    hangPunctuation: indentTarget === 0 || pinned
                    transform: Translate {
                        x: line.pinned ? root.leftRoom : root.leftRoom * line.indent + root.rightRoom * (1 - line.indent)
                    }
                    // One-line mode shows the sung line only; the next one slides in as the old one fades.
                    opacity: (root.oneLine && root.synced ? (line.lit ? 1 : 0) : root.synced && root.edgeFade > 0 ? Math.max(0, Math.min(1, edgeDistance / root.edgeFade)) : 1) * line.fadeOpacity
                    Behavior on opacity {
                        enabled: root.oneLine && root.animationsEnabled
                        NumberAnimation {
                            duration: line.moveDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                    restWeight: root.restWeight
                    shadow: root.shadow
                    glow: root.glow
                    item: modelData
                    controller: root.controller
                    clock: {
                        if (!root.synced)
                            return -1;
                        if (line.live)
                            return root.now;
                        return line.index < root.centreItem ? Infinity : -1;
                    }
                    promoted: root.synced && index === root.centreItem
                    synced: root.synced
                    following: root.following
                    playing: root.playing
                    sweep: root.sweep
                    animationsEnabled: root.animationsEnabled
                    leadFontSize: root.leadFontSize
                    leadMetrics: leadFontMetrics
                    breakSize: root.breakSize
                    seekable: root.clickToSeek
                    restScale: root.restScale
                    textAlign: root.textAlign
                    duetSides: root.duetSides
                    singerName: root.singerName
                    pointerOver: root.pointerOver
                    pyramid: root.pyramid
                    distanceFade: root.distanceFade
                    artistLabel: root.artistLabel
                    before: index < root.depthCentre
                    chipSpace: root.chipSpace(index)
                    depth: Math.abs(index - root.depthCentre)
                    squeeze: root.squeezes[index] ?? 0
                    depthBlur: root.depthBlur
                    floatWords: root.floatWords
                    backgroundMetrics: backgroundFontMetrics
                    onActivated: {
                        root.resume();
                        if (line.item.kind === "break")
                            root.controller.seekToTime(line.item.t);
                        else
                            root.controller.seekToLine(line.item.line);
                    }
                }
            }
        }

        DButton {
            id: followButton
            focusRingColor: MediaAccentService.focusRing
            objectName: "followPlayback"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spacingL
            buttonHeight: Theme.buttonHeightXS
            maximumWidth: Math.max(0, parent.width - Theme.spacingM * 2)
            wrapText: true
            visible: root.showFollow
            text: root.compact ? "" : I18n.tr("Follow playback", "Resume automatic scrolling of lyrics")
            Accessible.name: I18n.tr("Follow playback", "Resume automatic scrolling of lyrics")
            tooltipText: root.compact ? Accessible.name : ""
            iconName: "my_location"
            backgroundColor: MediaAccentService.accentContainer
            textColor: MediaAccentService.onAccentContainer
            onClicked: root.resume()
        }

        Loader {
            anchors.centerIn: viewport
            active: opacity > 0
            opacity: root.controller.pending ? 1 : 0

            Behavior on opacity {
                enabled: root.animationsEnabled
                NumberAnimation {
                    duration: Theme.expressiveDurations.expressiveEffects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                }
            }

            sourceComponent: DLoadingIndicator {
                contained: true
                containerColor: MediaAccentService.accentContainer
                color: MediaAccentService.onAccentContainer
                Accessible.role: Accessible.ProgressBar
                Accessible.name: I18n.tr("Loading...")
            }
        }

        Column {
            readonly property bool shown: !root.ready && root.message !== ""

            anchors.centerIn: parent
            width: parent.width - Theme.spacingL * 2
            spacing: Theme.spacingM
            visible: shown
            opacity: shown ? 1 : 0

            Behavior on opacity {
                enabled: root.animationsEnabled
                NumberAnimation {
                    duration: Theme.expressiveDurations.expressiveEffects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                }
            }

            StyledText {
                width: parent.width
                text: root.message
                color: Theme.onSurfaceVariant
                font.pixelSize: Theme.fontSizeMedium
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }

            DButton {
                focusRingColor: MediaAccentService.focusRing
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.tr("Retry")
                visible: root.controller.state === "error"
                onClicked: root.controller.request()
            }
        }
    }
}
