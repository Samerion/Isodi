module isodi.raylib.cell;

import std.conv;

import isodi.cell;
import isodi.display;
import isodi.resource;
import isodi.position;
import isodi.pack_list;
import isodi.raylib.display;

/// Cell implementation with Raylib.
///
/// DrawableResource is implemented as a wrapper for the cell's resource calls.
final class RaylibCell : Cell {

    ///
    this(Display display, const Position position, const string type) {

        super(display, position, type);

        // TODO Create the resources

    }

    ///
    void reload(PackList) {

    }

    ///
    void draw() {

    }

}
