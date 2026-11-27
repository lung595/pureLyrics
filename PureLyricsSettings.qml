import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.DCommon.Widgets
import "settings"

// Search field on top, categories on the left, one category at a time on the right.
// Typing shows every matching setting across categories; Esc clears.
PluginSettings {
    id: root
    pluginId: "pureLyricsPlus"

    // DMS only reloads its direct children; the settings here sit inside tabs, so reload them all.
    function reloadNested(item) {
        for (const child of item.children) {
            if (child.settingKey !== undefined && child.loadValue)
                child.loadValue();
            else
                reloadNested(child);
        }
    }
    function resetNested(item) {
        for (const child of item.children) {
            if (child.settingKey !== undefined && child.defaultValue !== undefined)
                root.saveValue(child.settingKey, child.defaultValue);
            else
                resetNested(child);
        }
    }
    onPluginServiceChanged: if (pluginService) Qt.callLater(reloadNested, scope)
    Connections {
        target: root.pluginService
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId)
                Qt.callLater(root.reloadNested, scope);
        }
    }

    QtObject {
        id: view
        property string current: "text"
        property string query: ""
    }

    FocusScope {
        id: scope
        width: parent ? parent.width : 0
        implicitHeight: column.implicitHeight

        Shortcut {
            sequence: "Ctrl+F"
            enabled: scope.visible
            onActivated: input.forceActiveFocus()
        }

        Column {
            id: column
            width: parent.width
            spacing: Theme.spacingM

            // Search field
            Rectangle {
                width: parent.width
                height: 44
                radius: height / 2
                color: Theme.surfaceContainerHigh
                border.width: input.activeFocus || view.query ? 2 : 1
                border.color: input.activeFocus || view.query ? Theme.primary : Theme.outline

                DankIcon {
                    id: glass
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: 20
                    color: view.query ? Theme.primary : Theme.surfaceVariantText
                }

                TextInput {
                    id: input
                    anchors.left: glass.right
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.primaryText
                    maximumLength: 60
                    Accessible.role: Accessible.EditableText
                    Accessible.name: I18n.tr("Search settings")
                    onTextChanged: view.query = text
                    Keys.onEscapePressed: text = ""

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !input.text && !input.preeditText
                        text: I18n.tr("Search settings (Ctrl+F)")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM

                // Category tabs
                Column {
                    id: tabs
                    width: root.width < 420 ? 48 : 150
                    spacing: Theme.spacingXS

                    Repeater {
                        model: [pageText, pagePlayer, pageStyle, pageInfo]

                        Rectangle {
                            id: tab
                            required property var modelData
                            readonly property bool open: !view.query.trim() && view.current === modelData.category
                            readonly property bool dimmed: !!view.query.trim() && modelData.matches === 0

                            width: tabs.width
                            height: 44
                            radius: height / 2
                            color: open ? Theme.secondaryContainer : hover.hovered ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent"
                            opacity: dimmed ? 0.4 : 1
                            Accessible.role: Accessible.PageTab
                            Accessible.name: modelData.title

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                x: tabs.width < 100 ? (parent.width - 20) / 2 : 14
                                spacing: Theme.spacingS

                                DankIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: tab.modelData.icon
                                    size: 20
                                    filled: tab.open
                                    color: tab.open ? Theme.onSecondaryContainer : Theme.surfaceVariantText
                                }
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: tabs.width >= 100
                                    text: tab.modelData.title
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: tab.open ? Font.Bold : Font.Medium
                                    color: tab.open ? Theme.onSecondaryContainer : Theme.surfaceText
                                }
                            }

                            HoverHandler {
                                id: hover
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: {
                                    input.text = "";
                                    view.current = tab.modelData.category;
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width - tabs.width - Theme.spacingM
                    spacing: Theme.spacingL

                    StyledText {
                        width: parent.width
                        visible: !!view.query.trim() && pageText.matches + pagePlayer.matches + pageStyle.matches + pageInfo.matches === 0
                        topPadding: Theme.spacingXL
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: I18n.tr("Nothing matches. Try: font, bold, glow, player, seek, background, credit")
                        color: Theme.surfaceVariantText
                    }

                    SettingsPage {
                        id: pageText
                        view: view
                        category: "text"
                        title: I18n.tr("Text")
                        icon: "text_fields"

                        SettingsSection {
                            title: I18n.tr("Font")

                            SelectionSetting {
                                settingKey: "fontFamily"
                                label: I18n.tr("Font")
                                description: I18n.tr("Typeface of the lyrics.")
                                defaultValue: "dms"
                                // Not "": the dropdown saves the label when a value is falsy.
                                options: [{ label: I18n.tr("DMS font"), value: "dms" }].concat(Qt.fontFamilies())
                            }

                            SliderSetting {
                                settingKey: "textScale"
                                label: I18n.tr("Sung line size")
                                description: I18n.tr("Size of the line being sung. 100% matches the DMS dash.")
                                defaultValue: 140
                                minimum: 60
                                maximum: 250
                                unit: "%"
                            }

                            SliderSetting {
                                settingKey: "activeWeight"
                                label: I18n.tr("Sung line weight")
                                description: I18n.tr("Boldness of the line being sung: 400 regular, 700 bold, 900 black.")
                                defaultValue: 800
                                minimum: 300
                                maximum: 900
                            }
                        }

                        SettingsSection {
                            title: I18n.tr("Layout")

                            SelectionSetting {
                                id: alignSel
                                settingKey: "textAlign"
                                label: I18n.tr("Alignment")
                                description: I18n.tr("Auto centres the lyrics and puts each duet singer on their side. Follow widget aligns to the widget's side of the screen.")
                                defaultValue: "auto"
                                options: [
                                    { label: I18n.tr("Auto"), value: "auto" },
                                    { label: I18n.tr("Left"), value: "left" },
                                    { label: I18n.tr("Centre"), value: "center" },
                                    { label: I18n.tr("Right"), value: "right" },
                                    { label: I18n.tr("Follow widget"), value: "follow" }
                                ]
                            }

                            ToggleSetting {
                                // Auto already puts duet singers on their side.
                                property bool shown: alignSel.value !== "auto"
                                settingKey: "duetSides"
                                label: I18n.tr("Duet sides")
                                description: I18n.tr("In duets, the first singer goes left and the second right, whatever the alignment.")
                                defaultValue: true
                            }

                            ToggleSetting {
                                id: oneLineSw
                                settingKey: "oneLine"
                                label: I18n.tr("One line")
                                description: I18n.tr("Only the sung line. The next one slides in as it fades.")
                                defaultValue: false
                            }
                        }

                        SettingsSection {
                            title: I18n.tr("Other lines")
                            shown: !oneLineSw.value

                            SliderSetting {
                                settingKey: "restScale"
                                label: I18n.tr("Size")
                                description: I18n.tr("Size of the lines around the sung one, relative to it.")
                                defaultValue: 80
                                minimum: 30
                                maximum: 100
                                unit: "%"
                            }

                            SliderSetting {
                                settingKey: "restWeight"
                                label: I18n.tr("Weight")
                                description: I18n.tr("Boldness of the lines around the sung one. Never bolder than the sung line.")
                                defaultValue: 500
                                minimum: 300
                                maximum: 900
                            }

                            SliderSetting {
                                settingKey: "pyramid"
                                label: I18n.tr("Shrink with distance")
                                description: I18n.tr("Pyramid: each line further out is this much smaller. 0% keeps them one size.")
                                defaultValue: 15
                                minimum: 0
                                maximum: 40
                                unit: "%"
                            }

                            SliderSetting {
                                settingKey: "distanceFade"
                                label: I18n.tr("Fade with distance")
                                description: I18n.tr("Each line further out is this much fainter. 0% keeps them equally visible.")
                                defaultValue: 0
                                minimum: 0
                                maximum: 80
                                unit: "%"
                            }

                            SliderSetting {
                                settingKey: "lineSpacing"
                                label: I18n.tr("Spacing")
                                description: I18n.tr("Gap between the sung line and the others. Negative pulls them closer.")
                                defaultValue: 0
                                minimum: -40
                                maximum: 80
                                unit: "px"
                            }
                        }
                    }

                    SettingsPage {
                        id: pagePlayer
                        view: view
                        category: "player"
                        title: I18n.tr("Player")
                        icon: "play_circle"

                        SettingsSection {
                            title: I18n.tr("Buttons")

                            ToggleSetting {
                                id: playerSw
                                settingKey: "showPlayer"
                                label: I18n.tr("Player buttons")
                                description: I18n.tr("Previous, play/pause and next, in the DMS theme colours.")
                                defaultValue: true
                            }

                            ToggleSetting {
                                id: hoverSw
                                property bool shown: playerSw.value
                                settingKey: "playerOnHover"
                                label: I18n.tr("Show on hover")
                                description: I18n.tr("Buttons appear under the pointer and fade 1 s after it leaves. Off: always shown.")
                                defaultValue: true
                            }

                            SelectionSetting {
                                id: positionSel
                                property bool shown: playerSw.value
                                settingKey: "playerPosition"
                                label: I18n.tr("Position")
                                description: I18n.tr("A row under the sung line, or a column beside it. Follow text puts the row on the lyrics' side. A widget too short for a column gets a row.")
                                defaultValue: "center"
                                options: [
                                    { label: I18n.tr("Row, centre"), value: "center" },
                                    { label: I18n.tr("Row, left"), value: "left" },
                                    { label: I18n.tr("Row, right"), value: "right" },
                                    { label: I18n.tr("Row, follow text"), value: "follow" },
                                    { label: I18n.tr("Column, left"), value: "columnLeft" },
                                    { label: I18n.tr("Column, right"), value: "columnRight" }
                                ]
                            }

                            SelectionSetting {
                                // The cover only sits on a column while the header shows (columnCover in PureLyrics.qml).
                                property bool shown: playerSw.value && positionSel.value.startsWith("column") && headerSw.value
                                settingKey: "coverSide"
                                label: I18n.tr("Cover side")
                                description: I18n.tr("The cover above a column is wider than its buttons and overhangs one side.")
                                defaultValue: "inner"
                                options: [
                                    { label: I18n.tr("Toward the lyrics"), value: "inner" },
                                    { label: I18n.tr("Toward the edge"), value: "outer" }
                                ]
                            }

                            ToggleSetting {
                                id: hoverRoomSw
                                property bool shown: playerSw.value && positionSel.value.startsWith("column") && hoverSw.value
                                settingKey: "hoverRoom"
                                label: I18n.tr("Keep room on hover")
                                description: I18n.tr("The lyrics keep clear of the column even while it is hidden. Off: it floats over them.")
                                defaultValue: false
                            }

                            SliderSetting {
                                // The gap only applies to a column with reserved room (playerRoom in PureLyrics.qml).
                                property bool shown: playerSw.value && positionSel.value.startsWith("column") && (!hoverSw.value || hoverRoomSw.value)
                                settingKey: "playerGap"
                                label: I18n.tr("Column gap")
                                description: I18n.tr("Space between the column and the sung line. Lines further out step back toward the edge.")
                                defaultValue: 32
                                minimum: 0
                                maximum: 120
                                unit: "px"
                            }

                            SliderSetting {
                                property bool shown: playerSw.value
                                settingKey: "playerOpacity"
                                label: I18n.tr("Opacity")
                                description: I18n.tr("Below 100%, the buttons blur what is behind them when DMS blur is on.")
                                defaultValue: 100
                                minimum: 10
                                maximum: 100
                                unit: "%"
                            }
                        }

                        SettingsSection {
                            title: I18n.tr("Seek")

                            ToggleSetting {
                                settingKey: "clickToSeek"
                                label: I18n.tr("Click to seek")
                                description: I18n.tr("Click a lyrics line to jump the song to it.")
                                defaultValue: true
                            }
                        }
                    }

                    SettingsPage {
                        id: pageStyle
                        view: view
                        category: "style"
                        title: I18n.tr("Style")
                        icon: "palette"

                        SettingsSection {
                            title: I18n.tr("Motion")

                            ToggleSetting {
                                id: lowPowerSw
                                settingKey: "lowPower"
                                label: I18n.tr("Low power")
                                description: I18n.tr("Turns off floating words, depth blur, shadow and glow, so the lyrics redraw only when a word changes. Off: those settings apply.")
                                defaultValue: true
                            }

                            ToggleSetting {
                                property bool shown: !lowPowerSw.value
                                settingKey: "floatWords"
                                label: I18n.tr("Floating words")
                                description: I18n.tr("Each word rises and glows while it is sung, then the line settles.")
                                defaultValue: true
                            }

                            ToggleSetting {
                                settingKey: "smoothSweep"
                                label: I18n.tr("Smooth sweep")
                                description: I18n.tr("The fill glides through each word instead of stepping. Uses more CPU: redraws every frame while a line is sung.")
                                defaultValue: false
                            }
                        }

                        SettingsSection {
                            title: I18n.tr("Depth")

                            SliderSetting {
                                // It blurs only the other lines, which one-line mode hides.
                                property bool shown: !oneLineSw.value && !lowPowerSw.value
                                settingKey: "depthBlur"
                                label: I18n.tr("Depth blur")
                                description: I18n.tr("Lines away from the sung one go out of focus, like a camera. 0% turns it off.")
                                defaultValue: 40
                                minimum: 0
                                maximum: 100
                                unit: "%"
                            }

                            ToggleSetting {
                                property bool shown: !lowPowerSw.value
                                settingKey: "shadow"
                                label: I18n.tr("Text shadow")
                                description: I18n.tr("Soft shadow that keeps lyrics readable on light wallpapers.")
                                defaultValue: true
                            }

                            ToggleSetting {
                                property bool shown: !lowPowerSw.value
                                settingKey: "glow"
                                label: I18n.tr("Glow")
                                description: I18n.tr("Breathing halo behind the sung line. Animates every frame while playing.")
                                defaultValue: false
                            }
                        }

                        SettingsSection {
                            title: I18n.tr("Card")

                            SliderSetting {
                                settingKey: "backgroundOpacity"
                                label: I18n.tr("Background")
                                description: I18n.tr("Rounded card behind the lyrics. 0% hides it.")
                                defaultValue: 0
                                minimum: 0
                                maximum: 100
                                unit: "%"
                            }

                            SliderSetting {
                                settingKey: "borderOpacity"
                                label: I18n.tr("Border")
                                description: I18n.tr("Outline around the widget. 0% hides it.")
                                defaultValue: 0
                                minimum: 0
                                maximum: 100
                                unit: "%"
                            }
                        }
                    }

                    SettingsPage {
                        id: pageInfo
                        view: view
                        category: "info"
                        title: I18n.tr("Info")
                        icon: "info"

                        SettingsSection {
                            title: I18n.tr("Labels")

                            SelectionSetting {
                                settingKey: "singerName"
                                label: I18n.tr("Singer name")
                                description: I18n.tr("Name chip over the sung line, in the singer's colour. Without named voices (only local .ttml has them) it shows the artist and featured artists.")
                                defaultValue: "change"
                                options: [
                                    { label: I18n.tr("When the singer changes"), value: "change" },
                                    { label: I18n.tr("While they sing"), value: "singing" },
                                    { label: I18n.tr("On hover"), value: "hover" },
                                    { label: I18n.tr("Off"), value: "off" }
                                ]
                            }

                            ToggleSetting {
                                id: headerSw
                                settingKey: "showHeader"
                                label: I18n.tr("Cover and title")
                                description: I18n.tr("Cover, title and artist until the first line is sung.")
                                defaultValue: true
                            }

                            ToggleSetting {
                                settingKey: "showAttribution"
                                label: I18n.tr("Lyrics source")
                                description: I18n.tr("Shows the provider credit, e.g. Better Lyrics, under the lyrics. Providers are chosen in DMS Settings → Media.")
                                defaultValue: true
                            }
                        }
                    }
                }
            }

            DButton {
                id: reset
                property bool armed: false
                anchors.right: parent.right
                visible: !view.query.trim()
                variant: "text"
                iconName: "restart_alt"
                danger: armed
                text: armed ? I18n.tr("Click again to reset all") : I18n.tr("Reset to defaults")
                // No undo, so the first click only arms it for 4 s.
                onClicked: {
                    if (!armed) {
                        armed = true;
                        disarm.restart();
                        return;
                    }
                    armed = false;
                    disarm.stop();
                    root.resetNested(scope);
                    Qt.callLater(root.reloadNested, scope);
                }
                Timer {
                    id: disarm
                    interval: 4000
                    onTriggered: reset.armed = false
                }
            }
        }
    }
}
