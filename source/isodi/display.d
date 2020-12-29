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
    /// Returns: The created cell.
    Cell addCell(const Position position, const string type) {

        auto cell = Cell.make(this, position, type);
        cellMap[position.toUnique] = cell;
        return cell;

    }

    /// Add a new anchor to the display.
    /// Returns: The created anchor.
    Anchor addAnchor() {

        // Create the anchor
        auto anchor = Anchor.make(this);

        // IDs should be implemented as internal anchor fields to keep track of them.
        // Alternatively, the map could be changed to Anchor[Anchor] or something like that.
        // RedBlackTree isn't too easy to implement
        const id = lastAnchor++;
        anchorMap[id] = anchor;

        return anchor;

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
