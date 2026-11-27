import QtQuick
import qs.Common
import qs.Widgets

// One category of the settings. Shown while its tab is open, or during a search when one of its
// settings matches; then only the matching settings show (label, description, group or category name).
Item {
    id: page

    required property var view
    required property string category
    required property string title
    required property string icon
    default property alias content: column.data

    property int matches: 0

    // Rows may declare `property bool shown`: without a query visibility follows it live, so a
    // parent switch hides its dependents. With a query only matches show and `shown` is ignored.
    function filter() {
        const query = view.query.trim().toLowerCase();
        const words = query.split(/\s+/).filter(w => w);
        let count = 0;
        for (const section of column.children) {
            if (section.body === undefined)
                continue;
            let hits = 0;
            for (const child of section.body.children) {
                if (child.settingKey === undefined)
                    continue;
                const text = [title, section.title, child.label, child.description].join(" ").toLowerCase();
                const hit = words.every(w => text.includes(w));
                if (query)
                    child.visible = hit;
                else
                    child.visible = Qt.binding(() => child.shown ?? true);
                if (hit)
                    hits++;
            }
            if (query)
                section.visible = hits > 0;
            else
                section.visible = Qt.binding(() => section.shown);
            count += hits;
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
        spacing: Theme.spacingL

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
