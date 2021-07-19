module isodi.raylib.cell;

import raylib;

import isodi.cell;
import isodi.tests;
import isodi.display;
import isodi.resource;
import isodi.position;
import isodi.raylib.display;
import isodi.raylib.internal;
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

    /// Modulate the color of the cell.
    Color color = Colors.WHITE;

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

mixin DisplayTest!((display) {

    display.addCell(position(0, 0), "grass");

    auto second = cast(RaylibCell) display.addCell(position(1, 0), "grass");
    second.color = Color(0xcc, 0xaa, 0xff, 0xee);

});
