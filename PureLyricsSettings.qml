import QtQuick
import qs.Common
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "pureLyrics"

    SelectionSetting {
        settingKey: "fontFamily"
        label: I18n.tr("Font")
        description: I18n.tr("Font of the lyrics. Lyrics sources and player follow DMS Settings → Media.")
        defaultValue: ""
        options: [{ label: I18n.tr("DMS font"), value: "" }].concat(Qt.fontFamilies())
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
