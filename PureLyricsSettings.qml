import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "settings"

// Search field on top, categories on the left, one category at a time on the right.
// Typing shows every matching setting across categories; Esc clears.
PluginSettings {
    id: root
    pluginId: "pureLyricsPlus"

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
                        model: [pageText, pageEffects, pagePlayer, pageCard]

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
                        visible: !!view.query.trim() && pageText.matches + pageEffects.matches + pagePlayer.matches + pageCard.matches === 0
                        topPadding: Theme.spacingXL
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: I18n.tr("Nothing matches. Try: font, bold, glow, player, seek, background")
                        color: Theme.surfaceVariantText
                    }

                    SettingsPage {
                        id: pageText
                        view: view
                        category: "text"
                        title: I18n.tr("Text")
                        icon: "text_fields"

                        SelectionSetting {
                            settingKey: "fontFamily"
                            label: I18n.tr("Font")
                            description: I18n.tr("Font of the lyrics. Sources and player follow DMS Settings → Media.")
                            defaultValue: ""
                            options: [{ label: I18n.tr("DMS font"), value: "" }].concat(Qt.fontFamilies())
                        }

                        SliderSetting {
                            settingKey: "activeWeight"
                            label: I18n.tr("Active line weight")
                            description: I18n.tr("Boldness of the line being sung (400 regular, 700 bold, 900 black)")
                            defaultValue: 800
                            minimum: 300
                            maximum: 900
                        }

                        SliderSetting {
                            settingKey: "restWeight"
                            label: I18n.tr("Other lines weight")
                            description: I18n.tr("Boldness of the lines around it. Capped at the active line weight.")
                            defaultValue: 500
                            minimum: 300
                            maximum: 900
                        }

                        ToggleSetting {
                            settingKey: "oneLine"
                            label: I18n.tr("One line")
                            description: I18n.tr("Show only the sung line; the next one slides in as it fades")
                            defaultValue: false
                        }
                    }

                    SettingsPage {
                        id: pageEffects
                        view: view
                        category: "effects"
                        title: I18n.tr("Effects")
                        icon: "auto_awesome"

                        ToggleSetting {
                            settingKey: "showHeader"
                            label: I18n.tr("Cover and title")
                            description: I18n.tr("Show cover, title and artist until the first line is sung")
                            defaultValue: true
                        }

                        ToggleSetting {
                            settingKey: "shadow"
                            label: I18n.tr("Text shadow")
                            description: I18n.tr("Soft shadow for light wallpapers. Low cost: redrawn only when a line changes.")
                            defaultValue: true
                        }

                        ToggleSetting {
                            settingKey: "glow"
                            label: I18n.tr("Active line glow")
                            description: I18n.tr("Breathing halo behind the sung line. Animates every frame while playing.")
                            defaultValue: false
                        }

                        ToggleSetting {
                            settingKey: "smoothSweep"
                            label: I18n.tr("Smooth sweep")
                            description: I18n.tr("Glide the fill through each word. Redraws every frame while a line is sung, so it uses more CPU. Off: the fill steps word by word.")
                            defaultValue: false
                        }
                    }

                    SettingsPage {
                        id: pagePlayer
                        view: view
                        category: "player"
                        title: I18n.tr("Player")
                        icon: "play_circle"

                        ToggleSetting {
                            settingKey: "showPlayer"
                            label: I18n.tr("Player buttons")
                            description: I18n.tr("Previous, play/pause and next under the lyrics, in the DMS theme colours")
                            defaultValue: true
                        }

                        SliderSetting {
                            settingKey: "playerOpacity"
                            label: I18n.tr("Player opacity")
                            description: I18n.tr("Opacity of the player buttons")
                            defaultValue: 100
                            minimum: 10
                            maximum: 100
                            unit: "%"
                        }

                        ToggleSetting {
                            settingKey: "clickToSeek"
                            label: I18n.tr("Click a line to seek")
                            description: I18n.tr("Clicking a lyrics line jumps the song to that line")
                            defaultValue: true
                        }
                    }

                    SettingsPage {
                        id: pageCard
                        view: view
                        category: "card"
                        title: I18n.tr("Background")
                        icon: "rounded_corner"

                        SliderSetting {
                            settingKey: "backgroundOpacity"
                            label: I18n.tr("Background opacity")
                            description: I18n.tr("Rounded background card behind the lyrics (0 = none)")
                            defaultValue: 0
                            minimum: 0
                            maximum: 100
                            unit: "%"
                        }

                        SliderSetting {
                            settingKey: "borderOpacity"
                            label: I18n.tr("Border opacity")
                            description: I18n.tr("Outline around the widget (0 = none)")
                            defaultValue: 0
                            minimum: 0
                            maximum: 100
                            unit: "%"
                        }
                    }
                }
            }
        }
    }
}
