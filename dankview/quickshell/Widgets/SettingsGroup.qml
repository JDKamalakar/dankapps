import QtQuick
import qs.Common

Item {
    id: root
    default property alias data: col.data

    width: parent?.width ?? 0
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: Theme.groupedListGap
    }
}
