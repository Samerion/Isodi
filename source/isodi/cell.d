///
module isodi.cell;

import isodi.object3d;

/// Represents a single cell in the Isodi 3D space.
final class Cell : Object3D {

    mixin Object3D.Implement;

    /// Type of the cell.
    const string type;

    /// Params:
    ///     display = Display to place the cell in.
    ///     position = Position of the cell.
    ///     type = Type of the cell, eg. "grass".
    this(Display display, Position position, const string type) {

        super(display);
        this.position = position;
        this.type = type;

    }

}
