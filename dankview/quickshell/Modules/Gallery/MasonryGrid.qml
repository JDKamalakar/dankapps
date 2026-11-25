import QtQuick
import qs.Common

Item {
    id: root

    property var model: []
    property int columns: 1
    property real tileWidth: 160
    property real spacing: Theme.spacingM
    property bool isTrashMode: false
    property real contentHeight: 0
    property var navigationPaths: []

    function relayout() {
        const cols = Math.max(1, columns);
        const occupied = [];

        function isFree(r, c, cs, rs) {
            if (c + cs > cols) return false;
            for (let rr = r; rr < r + rs; rr++) {
                const rowArr = occupied[rr];
                if (!rowArr) continue;
                for (let cc = c; cc < c + cs; cc++) {
                    if (rowArr[cc]) return false;
                }
            }
            return true;
        }

        function mark(r, c, cs, rs) {
            for (let rr = r; rr < r + rs; rr++) {
                if (!occupied[rr]) occupied[rr] = [];
                for (let cc = c; cc < c + cs; cc++) {
                    occupied[rr][cc] = true;
                }
            }
        }

        let maxRow = 0;
        const count = tiles.count;

        for (let i = 0; i < count; i++) {
            const tile = tiles.itemAt(i);
            if (!tile) continue;

            // Determine Google Photos-style dynamic span based on available columns, remaining items, and aspect ratio
            let cs = 1;
            let rs = 1;
            const ar = tile.imageAspectRatio || 1.0;

            if (cols >= 3 && count > cols + 2) {
                if ((i === 0 && count > cols + 2) || (i > 0 && i % 9 === 0 && count - i >= 4)) {
                    cs = cols >= 4 ? Math.min(2, cols - 1) : 2;
                    rs = 2;
                } else if (i % 5 === 2 && ar > 1.35 && count - i >= 2) {
                    cs = 2;
                    rs = 1;
                } else if (i % 7 === 4 && ar < 0.78 && count - i >= 2) {
                    cs = 1;
                    rs = 2;
                }
            }

            // Find first available (r, c)
            let placed = false;
            let r = 0;
            while (!placed) {
                for (let c = 0; c < cols; c++) {
                    if (isFree(r, c, cs, rs)) {
                        mark(r, c, cs, rs);
                        tile.masonryColumn = c;
                        tile.masonryX = c * (root.tileWidth + root.spacing);
                        tile.masonryY = r * (root.tileWidth + root.spacing);
                        tile.customWidth = cs * root.tileWidth + (cs - 1) * root.spacing;
                        tile.customHeight = rs * root.tileWidth + (rs - 1) * root.spacing;
                        maxRow = Math.max(maxRow, r + rs);
                        placed = true;
                        break;
                    }
                }
                if (!placed) {
                    if (cs > 1 || rs > 1) {
                        cs = 1;
                        rs = 1;
                        // retry same row as 1x1
                        for (let c = 0; c < cols; c++) {
                            if (isFree(r, c, 1, 1)) {
                                mark(r, c, 1, 1);
                                tile.masonryColumn = c;
                                tile.masonryX = c * (root.tileWidth + root.spacing);
                                tile.masonryY = r * (root.tileWidth + root.spacing);
                                tile.customWidth = root.tileWidth;
                                tile.customHeight = root.tileWidth;
                                maxRow = Math.max(maxRow, r + 1);
                                placed = true;
                                break;
                            }
                        }
                    }
                    if (!placed) r++;
                }
            }
        }

        contentHeight = count > 0 ? Math.max(0, maxRow * root.tileWidth + Math.max(0, maxRow - 1) * root.spacing) : 0;
    }

    implicitHeight: contentHeight

    onColumnsChanged: relayoutTimer.restart()
    onSpacingChanged: relayoutTimer.restart()
    onTileWidthChanged: relayoutTimer.restart()
    onModelChanged: relayoutTimer.restart()

    Timer {
        id: relayoutTimer
        interval: 50
        onTriggered: root.relayout()
    }

    Repeater {
        id: tiles
        model: root.model
        onItemAdded: relayoutTimer.restart()
        onItemRemoved: relayoutTimer.restart()

        delegate: GalleryThumbnail {
            required property var modelData
            required property int index

            property real masonryX: 0
            property real masonryY: 0

            imageItem: modelData
            tileSize: root.tileWidth
            thumbnailLayout: "masonry"
            isFirstInGroup: masonryColumn === 0
            isLastInGroup: masonryColumn >= Math.max(1, root.columns) - 1 || index === tiles.count - 1
            isTrashMode: root.isTrashMode
            navigationPaths: root.navigationPaths
            x: masonryX
            y: masonryY

            Behavior on x {
                enabled: Theme.animationsEnabled
                NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing }
            }
            Behavior on y {
                enabled: Theme.animationsEnabled
                NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing }
            }

            onImageAspectRatioChanged: relayoutTimer.restart()
        }
    }
}
