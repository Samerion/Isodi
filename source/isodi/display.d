///
module isodi.display;

import isodi.cell;
import isodi.tests;
import isodi.camera;
import isodi.position;

/// Display is the main class of Isodi which manages all Isodi resources.
class Display {

    public {

        /// Active camera.
        Camera camera;

    }

    private {

        /// Registered cells
        Cell[UniquePosition] cellsMap;

    }

    /// Add a new cell to the display.
    /// Params:
    ///     position = Position of the cell in the display.
    ///     type     = Type of the cell.
    void addCell(const Position position, const string type) {

        cellsMap[position.toUnique] = new Cell(this, position, type);

    }

    unittest {

        with (new Display) {

            addCell(position(0, 0), "grass");
            addCell(position(1, 0, Height(0.2)), "grass");
            assert(cellsMap[UniquePosition(0, 0, 0)].type == "grass");

        }

    }

}
