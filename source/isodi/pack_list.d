///
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
import isodi.model;
import isodi.exceptions;

/// Represents a pack list.
abstract class PackList {

    /// Underlying pack list.
    Pack[] packList;
    alias packList this;

    /// Result of globbing functions.
    ///
    /// $(UL
    ///     $(LI `matches` — Matched objects)
    ///     $(LI `pack` — Pack the files come from)
    /// )
    alias Result(T) = Tuple!(
        T[],      "matches",
        Pack*,    "pack",
    );

    private {

        Result!string[string] packGlobCache;
        Result!SkeletonNode[string] getSkeletonCache;

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
        getSkeletonCache.clear();

    }

    /// List matching files in the first matching pack.
    /// Params:
    ///     path = File path to look for.
    /// Returns: A [GlobResult] tuple with the result.
    /// Throws: [IsodiException] if the path wasn't found in any of the packs.
    Result!string packGlob(string path) {

        // Attempt to read from the cache
        if (auto cached = path in packGlobCache) {
            return *cached;
        }

        // Not in the cache, load it
        foreach (ref pack; packList) {

            // Get paths to the resource
            const resPath = pack.path.buildPath(path);
            const resDir = resPath.dirName;

            // This directory must exist
            if (!resDir.exists || !resDir.isDir) continue;

            // List all files inside
            return packGlobCache[path] = Result!string(
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
        assert(glob.matches.length);

        // Check all
        foreach (file; glob.matches) {

            assert(file.endsWith(".png"));

        }

    }

    /// Load the given skeleton.
    /// Params:
    ///     name = Name of the skeleton.
    /// Returns:
    ///     A `Result` tuple, first item is a list of the skeleton's nodes.
    Result!SkeletonNode getSkeleton(string name) {

        // Attempt to read from the cache
        if (auto cached = name in getSkeletonCache) {
            return *cached;
        }

        // Check each pack
        foreach (ref pack; packList) {

            Result!SkeletonNode result;

            // Attempt to load the skeleton
            try result = Result!SkeletonNode(pack.getSkeleton(name), &pack);

            // If failed, continue to the next pack
            catch (PackException) continue;

            return result;

        }

        throw new PackException(name.format!"Skeleton %s wasn't found in any pack");

    }

}
