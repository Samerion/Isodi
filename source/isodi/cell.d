///
module isodi.cell;

import std.traits;

import isodi.bind;
import isodi.tests;
import isodi.object3d;
import isodi.resource;

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
