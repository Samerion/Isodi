///
module isodi.cell;

import std.traits;

import isodi.tests;
import isodi.object3d;

/// Represents a single cell in the Isodi 3D space.
abstract class Cell : Object3D, WithDrawableResources {

    mixin Object3D.ImplementConst;

    /// Type of the cell.
    const string type;

    /// Params:
    ///     display = Display to place the cell in.
    ///     position = Position of the cell.
    ///     type = Type of the cell, eg. "grass".
    this(const Display display, const Position position, const string type) {

        super(display);
        this._position = position;
        this.type = type;

    }

    /// Create a cell with the current renderer.
    static Cell make(const Display display, const Position position, const string type) {

        return Renderer.createCell(display, position, type);

    }

}

mixin DisplayTest!((display) {

    display.addCell(position(0, 0, Height(0.2)), "grass");
    display.addCell(position(0, 1), "grass");
    display.addCell(position(0, 2), "grass");

});

mixin DisplayTest!((display) {

    display.addCell(position(0, 0), "grass");
    display.addCell(position(1, 0, Height(0.2, 1.2)), "grass");
    display.addCell(position(2, 0, Height(0.4, 1.4)), "grass");
    display.addCell(position(3, 0, Height(0.6, 1.6)), "grass");
    display.addCell(position(4, 0, Height(0.8, 1.8)), "grass");

});

mixin DisplayTest!((display) {

    display.addCell(position(0, 0, Height(5, 1)), "grass");
    display.addCell(position(1, 0, Height(5, 5)), "grass");
    display.addCell(position(2, 0, Height(5, 10)), "grass");

});
