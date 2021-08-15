/// Module for saving and loading tilemap data.
module isodi.tilemap;

import std.array;
import std.bitmanip;
import std.algorithm;
import std.exception;

import rcdata.bin;

import isodi.cell;
import isodi.tests;
import isodi.display;
import isodi.position;
import isodi.exceptions;

/// A start leet code, just for fun (and identification)
private immutable int leet = 0x150D1;

private struct EntryCell {

    ulong cellID;
    Height height;

}

private struct Entry {

    // Each entry starts with its starting position
    int x;
    int y;
    int layer;

    // Then followed by a list of cells (expanding towards positive X)
    // Cell under index 0 will be placed under the same position as the entry
    EntryCell[] cells;

}


@safe:


/// Save the display contents into a tilemap.
/// Params:
///     display = Isodi display to use.
///     range   = An output range the tilemap should be written to.
void saveTilemap(T)(Display display, T range) {

    saveTilemap(display.cells.array, range);

}

/// Save a tilemap containing the given cells.
/// Params:
///     cells = Cells to store in the tilemap.
///     range = An output range the tilemap should be written to.
void saveTilemap(T)(Cell[] cells, T range) @trusted {

    /// Serializer for the tilemap
    auto bin = rcbinSerializer(range);

    /// IDs assigned to strings.
    string[] declarations;

    /// Get the entries
    auto entries = saveTilemapImpl(cells, declarations);

    // Place the contents
    bin.get(leet.nativeToBigEndian)
       .get(declarations)
       .get(entries);

}

/// Implementation of
private auto saveTilemapImpl(Cell[] allCells, ref string[] declarations) {

    /// Tile names assigned to IDs.
    ulong[string] ids;

    // Sort the cells by position
    auto cells = allCells.positionSort;

    // Resulting entries
    auto entries = [Entry()];

    // Check each cell
    foreach (cell; cells) {

        auto entry = &entries[$-1];

        // Check if this cell matches the entry
        if (entry.layer != cell.position.layer
            || entry.y != cell.position.y
            || entry.x + entry.cells.length != cell.position.x
        ) {

            // It doesn't, make a new entry
            entries ~= Entry(cell.position.toUnique.expand);
            entry = &entries[$-1];

        }

        // Get tile ID
        auto id = ids.require(cell.type, declarations.length);

        // Declare the tile if it's new
        if (id >= declarations.length) {

            declarations ~= cell.type;

        }

        // Add the cell to the entry
        entry.cells ~= EntryCell(id, cell.position.height);

    }

    return entries;

}

/// Load tilemaps
/// Params:
///     display     = Display to place the tilemap in.
///     range       = Range of bytes containing map data.
///     offset      = Optional position offset to apply to each cell. Ignores depth.
///     postprocess = A callback ran after adding each cell to the tilemap.
void loadTilemap(T)(Display display, T range, Position offset = Position.init,
    void delegate(Cell) @trusted postprocess = null)
do {

    LoadTilemap loader;

    string[] declarations;
    Position cellPosition;

    loader.onDeclarations = (decl) @safe {

        declarations = decl.dup;

    };

    loader.onEntry = (x, y, layer) @safe {

        cellPosition = position(
            x + offset.x,
            y + offset.y,
            layer
        );

    };

    loader.onCell = (id, height) @safe {

        cellPosition.height = height;
        cellPosition.height.top += offset.height.top;

        // Add it to the display
        auto isodiCell = display.addCell(cellPosition, declarations[cast(size_t) id]);

        // Postprocess the cell
        if (postprocess) postprocess(isodiCell);

        // Increment position
        cellPosition.x += 1;

    };

    loader.parse(range);

}

/// Struct for advanced tilemap loading.
struct LoadTilemap {

    /// This delegate is called with tile declarations at the start of the file. Indexes within the array are later to
    /// be used to find the tile name for a cell ID.
    void delegate(scope string[]) onDeclarations;

    /// This delegate is called when matched an entry, that is, a row of cells in an arbitrary position.
    ///
    /// The parameters are the position of the entry. Following cell calls will start from this position, each new
    /// cell should increment x.
    void delegate(int x, int y, int layer) onEntry;

    /// This delegate is called when found a cell. It is called with an ID corresponding to the tile type declaration
    /// (from [onDeclarations]) and a definition of the cell's height.
    void delegate(ulong cellID, Height height) onCell;

    /// Begin parsing. A callback member will be ran for each matched element of the input.
    void parse(T)(T range) @trusted {

        /// Create the parser
        auto bin = rcbinParser(range);

        // Check for the magic number
        enforce!MapException(bin.read!(ubyte[4]).bigEndianToNative!int == leet, "Given file is not a tilemap");

        /// Load declarations
        onDeclarations(bin.read!(string[]));

        /// Load entries
        // rcdata.bin could get support for reading as ranges probably
        auto size = bin.read!ulong;

        foreach (index; 0..size) {

            auto entry = bin.read!Entry;
            onEntry(entry.x, entry.y, entry.layer);

            // Load each cell
            foreach (cell; entry.cells) {

                onCell(cell.cellID, cell.height);

            }

        }

    }

}

mixin DisplayTest!((display) {

    // TODO: add tests for layers and objects spaced apart

    foreach (y; 0..3)
    foreach (x; 0..3) {

        display.addCell(position(x, y), "grass");

    }
    display.addCell(position(10, 10), "wood");

    auto data = appender!(ubyte[]);
    saveTilemap(display, data);

    auto result = data[];

    display.addModel(position(4, 1), "wraith-white");
    loadTilemap(display, result, position(3, 0));
    loadTilemap(display, result, position(0, 3, Height(0.5)));

});

/// Write a hexdump for debugging
debug private void hexDump(ubyte[] bytes) {

    import std.stdio;

    writefln("%s bytes:", bytes.length);
    foreach (i, value; bytes) {

        writef("%0.2x ", value);

        if (i % 16 == 15) writeln();

    }

}
