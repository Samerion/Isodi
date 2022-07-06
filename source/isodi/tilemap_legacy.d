/// Old Isodi tilemap loading code, for compatibility.
module isodi.tilemap_legacy;

import std.conv;
import std.algorithm;
import std.exception;

import rcdata.bin;

import isodi.tilemap;
import isodi.exception;


@safe:




/// Magic bytes
private immutable int leet = 0x150D1;

private struct EntryCell {

    ulong cellID;
    float height;
    float depth;

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

void parseVersion0(T)(T bin, ref LoadTilemap loader) @trusted {

    // Load declarations
    loader.onDeclarations(bin.read!(string[]), 1000);

    // Load entries
    // rcdata.bin could get support for reading as ranges probably
    auto size = bin.read!ulong;

    foreach (index; 0..size) {

        auto entry = bin.read!Entry;
        loader.onEntry(entry.x, entry.y, entry.layer);

        // Load each cell
        foreach (cell; entry.cells) {

            loader.onBlock(cell.cellID, to!int(cell.height * 1000), to!int(cell.depth * 1000));

        }

    }

}
