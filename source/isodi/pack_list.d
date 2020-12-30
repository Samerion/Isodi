module isodi.pack_list;

import std.conv;
import std.file;
import std.path;
import std.array;
import std.string;
import std.typecons;
import std.exception;

import isodi.bind;
import isodi.pack;
import isodi.exceptions;

/// Represents a pack list.
abstract class PackList {

    /// Underlying pack list.
    Pack[] packList;
    alias packList this;

    /// `packGlob` result.
    ///
    /// $(UL
    ///     $(LI `files` — Matched files)
    ///     $(LI `pack` — Pack the files come from)
    /// )
    alias GlobResult = Tuple!(
        string[], "files",
        Pack*,    "pack",
    );

    private {

        GlobResult[string] packGlobCache;

    }

    /// Create a pack list for the current renderer.
    static PackList make() {

        return Renderer.createPackList();

    }

    /// Create a pack list for the current renderer.
    /// Params:
    ///     packs = Preload the list with given packs.
    static PackList make(Pack[] packs...) {

        auto list = make();
        list.packList = packs;
        list.clearCache();
        return list;

    }

    /// Clear resource cache. Call when the list contents were changed or reordered.
    ///
    /// When overriding, make sure to call `super.clearCache()`.
    abstract void clearCache() {

        packGlobCache.clear();

    }

    /// List matching files in the first matching pack.
    /// Params:
    ///     path = File path to look for.
    /// Returns: A [GlobResult] tuple with the result.
    /// Throws: [IsodiException] if the path wasn't found in any of the packs.
    GlobResult packGlob(string path) {

        // Attempt to read from the cache
        if (auto cached = path in packGlobCache) {
            return *cached;
        }

        // Not in the cache, load it
        foreach (ref pack; packList) {

            // The pack must exist
            enforce!PackException(pack.path.exists, pack.path.format!"Pack %s doesn't exist");

            // Get paths to the resource
            const resPath = pack.path.buildPath(path);
            const resDir = resPath.dirName;

            // This directory must exist
            if (!resDir.exists || !resDir.isDir) continue;

            // List all files inside
            return packGlobCache[path] = GlobResult(
                resDir.dirEntries(resPath.baseName, SpanMode.shallow).array.to!(string[]),
                &pack
            );

        }

        throw new PackException(path.format!"Texture %s wasn't found in any pack");

    }

    // Barely an unittest, needs more packs to work
    unittest {

        auto packs = PackList.make(
            getPack("res/samerion-retro/pack.json")
        );

        // Get a list of grass textures
        auto glob = packs.packGlob("cells/grass/tile/*.png");
        assert(glob.pack.name == "SamerionRetro");
        assert(glob.files.length);

        // Check all
        foreach (file; glob.files) {

            assert(file.endsWith(".png"));

        }

    }

}
