///
module isodi.display;

import isodi.bind;
import isodi.cell;
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

    }

    protected {

        /// Registered cells
        Cell[UniquePosition] cellsMap;

    }

    /// Create a display with the current renderer.
    static Display make() {

        return Renderer.createDisplay();

    }

    /// Iterate on all cells
    auto cells() {

        return cellsMap.byValue;

    }

    /// Load, or reload, all the packs.
    ///
    /// TODO: Implement this.
    void loadPacks() { }

    /// Add a new cell to the display.
    /// Params:
    ///     position = Position of the cell in the display.
    ///     type     = Type of the cell.
    void addCell(const Position position, const string type) {

        cellsMap[position.toUnique] = new Cell(this, position, type);

    }

}

version (unittest) {

    /// A non-abstract version of the display, just for unit testing.
    private class TestDisplay : Display { }

    mixin DisplayTest!((display) {

        with (new TestDisplay) {

            addCell(position(0, 0), "grass");
            addCell(position(1, 0, Height(0.2)), "grass");
            assert(cellsMap[UniquePosition(0, 0, 0)].type == "grass");

        }

    });

}
