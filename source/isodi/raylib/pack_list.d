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
    Texture2D loadTexture(string filename) {

        return cache.require(filename, LoadTexture(filename.toStringz));

    }

    override void clearCache() {

        super.clearCache();
        cache.clear();

    }

}
