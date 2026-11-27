import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets

// A titled group of settings in a page. `shown: false` hides it, header included.
Column {
    id: section

    required property string title
    property bool shown: true
    default property alias content: body.data
    readonly property alias body: body

    width: parent ? parent.width : 0

    SettingsSectionLabel {
        text: section.title
        topGap: 0
        bottomGap: Theme.spacingS
    }

    Column {
        id: body
        width: parent.width
        spacing: Theme.spacingM
    }
}
