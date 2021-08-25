///
module isodi.cell;

import std.traits;
import std.format;
import std.random;

import isodi.pack;
import isodi.tests;
import isodi.object3d;


@safe:


/// Represents a single cell in the Isodi 3D space.
abstract class Cell : Object3D, WithDrawableResources {

    mixin Object3D.ImplementConst;

    /// Type of the cell.
    const string type;

    /// Seed to use for RNG calls related to generation of this cell's resources.
    ///
    /// It's preferred to sum this with a magic number to ensure unique combinations.
    const ulong seed;

    /// Params:
    ///     display = Display to place the cell in.
    ///     position = Position of the cell.
    ///     type = Type of the cell, eg. "grass".
    this(Display display, const Position position, const string type) {

        super(display);
        this._position = position;
        this._visualPosition = position;
        this.seed = position.toHash;
        this.type = type;

    }

    /// Create a cell with the current renderer.
    static Cell make(Display display, const Position position, const string type) {

        return Renderer.createCell(display, position, type);

    }

    ///
    Pack.Resource!string getTile() {

        // Get a random file
        return display.packs.randomGlob(
            type.format!"cells/%s/tile/*.png",
            Mt19937_64(seed)
        );

    }

    ///
    Pack.Resource!string[4] getSide() @trusted {

        Mt19937_64 rng;
        Pack.Resource!string[4] result;

        // Get possible sides
        const path = type.format!"cells/%s/side/*.png";
        auto glob = display.packs.packGlob(path);

        // Generate each side
        foreach (side; 0..4) {

            // Get a random file
            rng.seed(seed + 1 + side);
            const file = glob.matches.choice(rng);

            result[side] = Pack.Resource!string(
                file,
                glob.pack.getOptions(file)
            );

        }

        return result;

    }

    /// Params:
    ///     tileOptions = Pack options set for the tile resource.
    Pack.Resource!string[] getDecoration(const ResourceOptions* tileOptions) @trusted {

        Pack.Resource!string[] result;

        // Create RNG
        auto rng = Mt19937_64(seed + 5);

        // Get available space
        const spaceRange = tileOptions.decorationSpace;
        uint space = uniform!"[]"(spaceRange[0], spaceRange[1], rng);

        // While there is space for new decoration
        while (space) {

            rng.seed(seed + space + 5);

            // Get a random file
            const path = type.format!"cells/%s/decoration/*.png";
            auto glob = display.packs.packGlob(path);
            const file = glob.matches.choice(rng);
            const options = glob.pack.getOptions(file);

            // Stop if there's no space
            if (space < options.decorationWeight) break;

            // Reduce space
            space -= options.decorationWeight;

            // Get the option
            result ~= Pack.Resource!string(file, options);

        }

        return result;

    }

    /// Get a neighbor in given direction.
    /// Params:
    ///     direction = 0 for negative Y, 1 for positive X, 2 for positive Y, 3 for negative X. Calling with other
    ///         values is invalid.
    /// Returns:
    ///     The queried cell within the same layer. `null` if not found
    Cell getNeighbor(ubyte direction) {

        return getNeighbor(direction, position);

    }

    /// Get a visual neighbour in given direction — this will take cell offset into account.
    /// Params:
    ///     direction = 0 for negative Y, 1 for positive X, 2 for positive Y, 3 for negative X. Calling with other
    ///         values is invalid.
    /// Returns:
    ///     The queried cell within the same layer. `null` if not found
    Cell getVisualNeighbor(ubyte direction) {

        return getNeighbor(direction, visualPosition);

    }

    /// Get the neighbor from a set position
    private Cell getNeighbor(ubyte direction, Position pos) {

        auto newPosition = cast() pos;

        final switch (direction) {

            case 0:
                newPosition.y -= 1;
                break;
            case 1:
                newPosition.x += 1;
                break;
            case 2:
                newPosition.y += 1;
                break;
            case 3:
                newPosition.x -= 1;
                break;

        }

        // Find the cell
        return display.getCell(newPosition.toUnique);

    }

}

mixin DisplayTest!((display) {

    display.addCell(position(0, 0, Height(0.2)), "grass");
    display.addCell(position(0, 1), "grass");
    display.addCell(position(0, 2), "grass");

    display.addCell(position(1, 0), "grass");
    display.addCell(position(1, 1), "grass");
    display.addCell(position(1, 2), "grass");

    display.addCell(position(2, 0), "grass");
    display.addCell(position(2, 1), "grass");
    display.addCell(position(2, 2), "grass");

});

mixin DisplayTest!((display) {

    display.addCell(position(0, 0), "grass");
    display.addCell(position(1, 0, Height(0.2, 1.2)), "grass");
    display.addCell(position(2, 0, Height(0.4, 1.4)), "grass");
    display.addCell(position(3, 0, Height(0.6, 1.6)), "grass");
    display.addCell(position(4, 0, Height(0.8, 1.8)), "grass");

    display.addCell(position(0, 1), "grass");
    display.addCell(position(1, 1, Height(2, 2)), "grass");
    display.addCell(position(2, 1, Height(4, 4)), "grass");
    display.addCell(position(3, 1, Height(6, 6)), "grass");
    display.addCell(position(4, 1, Height(8, 8)), "grass");

    auto moved = display.addCell(position(5, 0), "grass");
    moved.offset = position(-5, -1);

});

mixin DisplayTest!((display) {

    display.addCell(position(0, 0, Height(5, 1)), "grass");
    display.addCell(position(1, 0, Height(5, 5)), "grass");
    display.addCell(position(2, 0, Height(5, 10)), "grass");

});
