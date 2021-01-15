module isodi.raylib.cell;

import isodi.cell;
import isodi.display;
import isodi.resource;
import isodi.position;
import isodi.raylib.resources;

/// Cell implementation with Raylib.
///
/// DrawableResource is implemented as a wrapper for the cell's resource calls.
final class RaylibCell : Cell, WithDrawableResources {

    package {

        Tile tile;
        Side side;
        Decoration decoration;

    }

    ///
    this(Display display, const Position position, const string type) {

        super(display, position, type);
        reload();

    }

    ///
    void reload() {

        tile = Tile(this, getTile);
        side = Side(this, getSide);
        decoration = Decoration(this, getDecoration(tile.options));

    }

    ///
    void draw() {

        tile.draw();
        side.draw();
        decoration.draw();

    }

}
