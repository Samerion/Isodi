/// Module for saving and loading tilemap data.
module isodi.tilemap;

import std.array;
import std.bitmanip;
import std.algorithm;
import std.exception;

import rcdata.bin;

import isodi.tests;
import isodi.display;
import isodi.position;
import isodi.exceptions;

/// A start leet code, just for fun (and identification)
private immutable leet = 0x150D1;

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

/// Save tilemap
/// Params:
///     display = Isodi display to use.
///     range   = An output range the tilemap should be written to.
void saveTilemap(T)(Display display, T range) {

    /// Serializer for the tilemap
    auto bin = rcbinSerializer(range);

    /// IDs assigned to strings.
    string[] declarations;

    /// Get the entries
    auto entries = saveTilemapImpl(display, declarations);

    // Place the contents
    bin.get(leet.nativeToBigEndian)
       .get(declarations)
       .get(entries);

}

/// Implementation of
private auto saveTilemapImpl(Display display, ref string[] declarations) {

    /// Tile names assigned to IDs.
    ulong[string] ids;

    // Sort the cells by position
    auto cells = display.cells.array.positionSort;

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
/// Note: Offset ignores depth.
void loadTilemap(T)(Display display, T range, Position offset = Position.init) {

    /// Create the parser
    auto bin = rcbinParser(range);

    // Check for the magic number
    enforce!MapException(bin.read!int.swapEndian == leet, "Given file is not a tilemap");

    /// Values
    string[] declarations = bin.read!(string[]);

    /// Load entries
    // rcdata.bin could get support for reading as ranges probably
    auto size = bin.read!ulong;

    foreach (index; 0..size) {

        auto entry = bin.read!Entry;
        auto position = position(entry.x, entry.y, entry.layer);
        position.x += offset.x;
        position.y += offset.y;

        // Load each cell
        foreach (cell; entry.cells) {

            position.height = cell.height;
            position.height.top += offset.height.top;
            display.addCell(position, declarations[cell.cellID]);

            // Increment position
            position.x += 1;

        }

    }

}

mixin DisplayTest!((display) {

    // TODO: add tests for layers and objects spaced apart

    foreach (y; 0..3)
    foreach (x; 0..3) {

        display.addCell(position(x, y), "grass");

    }

    auto data = appender!(ubyte[]);
    saveTilemap(display, data);

    auto result = data[];
    assert(result[0..4] == [0, 1, 0x50, 0xD1]);

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
