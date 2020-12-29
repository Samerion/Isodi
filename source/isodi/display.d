///
module isodi.display;

import isodi.bind;
import isodi.cell;
import isodi.pack;
import isodi.tests;
import isodi.anchor;
import isodi.camera;
import isodi.position;

/// Display is the main class of Isodi which manages all Isodi resources.
///
/// This class is abstract, as it should be overriden by the renderer. Use the `make` method to create a display with
/// the current renderer.
abstract class Display {

    public {

        /// Base cell size in the display, if supported by the renderer.
        ///
        /// Usually in pixels.
        int cellSize = 100;

        /// Active camera.
        Camera camera;

        /// Used pack list
        PackList packs;

    }

    protected {

        /// Registered cells
        Cell[UniquePosition] cellMap;

        /// Registered anchors
        Anchor[size_t] anchorMap;

    }

    private {

        /// ID of the last added anchor
        size_t lastAnchor;

    }

    ///
    this() {

        packs = PackList.make();

    }

    /// Create a display with the current renderer.
    static Display make() {

        return Renderer.createDisplay();

    }

    /// Reload all resources in the display. Make sure to call `PackList.clearCache`.
    abstract void reloadResources();

    /// Iterate on all cells
    auto cells() {

        return cellMap.byValue;

    }

    /// Iterate on all anchors
    auto anchors() {

        return anchorMap.byValue;

    }

    /// Add a new cell to the display.
    /// Params:
    ///     position = Position of the cell in the display.
    ///     type     = Type of the cell.
    void addCell(const Position position, const string type) {

        cellMap[position.toUnique] = Cell.make(this, position, type);

    }

    /// Add a new anchor to the display.
    /// Params:
    ///     cb = Callback with a reference to the created anchor.
    /// Returns: ID of the anchor, used to remove it from the display.
    size_t addAnchor(void delegate(scope Anchor) cb) {

        // Create the anchor
        auto anchor = Anchor.make(this);
        cb(anchor);

        const id = lastAnchor++;
        anchorMap[id] = anchor;

        return id;

    }

    // TODO
    version (None) {

        /// Remove the cell at given position.
        void removeCell(UniquePosition);

        /// Remove given anchor.
        ///
        /// Returns: `true` if the anchor was actually removed, `false` otherwise.
        bool removeAnchor(size_t);

    }

}
