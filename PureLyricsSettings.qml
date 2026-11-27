import QtQuick
import qs.Common
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "pureLyrics"

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

    SliderSetting {
        settingKey: "backgroundOpacity"
        label: I18n.tr("Background Opacity")
        description: I18n.tr("Rounded background card behind the lyrics (0 = none)")
        defaultValue: 0
        minimum: 0
        maximum: 100
        unit: "%"
    }

    SliderSetting {
        settingKey: "borderOpacity"
        label: I18n.tr("Border Opacity")
        defaultValue: 0
        minimum: 0
        maximum: 100
        unit: "%"
    }
}
