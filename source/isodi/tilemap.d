/// Module for saving and loading tilemap data.
module isodi.tilemap;

import rcdata.bin;
import std.bitmanip;

import isodi.chunk;
import isodi.exception;
import isodi.tilemap_legacy;


@safe:


enum FormatVersion : int {

    version0 = 0x000150D1,

}

/// Load tilemaps
/// Params:
///     range    = Range of bytes containing map data.
///     modifier = Delegate to edit blocks before adding them into the chunk.
Chunk loadTilemap(T)(T range, void delegate(ref Block block) @safe modifier = null) {

    Chunk chunk;
    LoadTilemap loader;

    string[] declarations;
    BlockPosition blockPosition;

    loader.onDeclarations = (decl, heightSteps) @safe {

        chunk.properties.heightSteps = heightSteps;
        declarations = decl.dup;

    };

    loader.onEntry = (x, y, layer) @safe {

        blockPosition = BlockPosition(x, y);

    };

    loader.onBlock = (id, height, depth) @safe {

        blockPosition.height = height;
        blockPosition.depth = depth;

        // Create the block
        auto block = Block(
            BlockType(id),
            blockPosition,
        );

        // Edit the block
        if (modifier) modifier(block);

        // Add it to the chunk
        chunk.addX(block.tupleof, block.position.height);

        // Increment position
        blockPosition.x += 1;

    };

    loader.parse(range);

    return chunk;

}

/// Struct for advanced tilemap loading.
struct LoadTilemap {

    /// This delegate is called with data declarations at the start of the file.
    void delegate(scope string[] blockNames, int heightSteps) @safe onDeclarations;
    // TODO elaborate

    /// This delegate is called when matched an entry, that is, a row of blocks in an arbitrary position.
    ///
    /// The parameters define the position of the entry. Following block calls will start from this position, each new
    /// block should increment x.
    void delegate(int x, int y, int layer) @safe onEntry;

    /// This delegate is called when found a block. It is called with an ID corresponding to the tile type declaration
    /// (from [onDeclarations]) and a definition of the block's height.
    void delegate(ulong blockID, int heightTop, int depth) @safe onBlock;

    /// Begin parsing. A callback member will be ran for each matched element of the input.
    void parse(T)(T range) {

        // Create the parser
        auto bin = rcbinParser(range);

        // Read magic bytes
        auto magicBytes = bin.read!(ubyte[4]).bigEndianToNative!int;

        switch (magicBytes) with (FormatVersion) {

            case version0:
                parseVersion0(bin, this);
                return;

            default:
                enforce!MapException("Given file is not a tilemap");

        }

    }

}
