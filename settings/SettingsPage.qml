import QtQuick
import qs.Common
import qs.Widgets

// One category of the settings. Shown while its tab is open, or during a search when one of its
// settings matches; then only the matching settings show (label, description or category name).
Item {
    id: page

    required property var view
    required property string category
    required property string title
    required property string icon
    default property alias content: column.data

    property int matches: 0

    function filter() {
        const words = view.query.toLowerCase().split(/\s+/).filter(w => w);
        let count = 0;
        for (const child of column.children) {
            if (child.settingKey === undefined)
                continue;
            const text = [title, child.label, child.description].join(" ").toLowerCase();
            const hit = words.every(w => text.includes(w));
            child.visible = hit;
            if (hit)
                count++;
        }
        matches = count;
    }

    visible: view.query.trim() !== "" ? matches > 0 : view.current === category
    width: parent ? parent.width : 0
    implicitHeight: column.implicitHeight

    Component.onCompleted: filter()
    Connections {
        target: page.view
        function onQueryChanged() {
            page.filter();
        }
    }

    onVisibleChanged: if (visible && !SettingsData.reduceMotion) enter.restart()
    NumberAnimation {
        id: enter
        target: column
        property: "opacity"
        from: 0
        to: 1
        duration: 150
        easing.type: Easing.OutCubic
    }

    Column {
        id: column
        width: parent.width
        spacing: Theme.spacingM

        Row {
            spacing: Theme.spacingS
            height: 28
            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: page.icon
                size: 20
                color: Theme.primary
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: page.title
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
                color: Theme.surfaceText
            }
        }
    }
}
