module isodi.raylib.pack_list;

import raylib;
import std.string;

import isodi.pack_list;


@safe:


///
class RaylibPackList : PackList {

    /// Texture cache by filename
    private Texture2D[string] cache;

    /// Load a texture from file.
    Texture2D loadTexture(string filename) @trusted {

        return cache.require(filename, LoadTexture(filename.toStringz));

    }

    override void clearCache() @trusted {

        super.clearCache();
        cache.clear();

    }

}
