///
module isodi.display;

import isodi.bind;
import isodi.cell;
import isodi.pack;
import isodi.tests;
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
        Cell[UniquePosition] cellsMap;

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

        return cellsMap.byValue;

    }

    /// Add a new cell to the display.
    /// Params:
    ///     position = Position of the cell in the display.
    ///     type     = Type of the cell.
    void addCell(const Position position, const string type) {

        cellsMap[position.toUnique] = Cell.make(this, position, type);

    }

}

mixin DisplayTest!((display) {

    display.addCell(position(0, 0), "grass");
    display.addCell(position(1, 0, Height(0.2)), "grass");
    assert(display.cellsMap[UniquePosition(0, 0, 0)].type == "grass");

});
