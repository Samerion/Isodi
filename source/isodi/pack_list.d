///
module isodi.pack_list;

import std.conv;
import std.file;
import std.path;
import std.array;
import std.string;
import std.random;
import std.typecons;
import std.exception;

import isodi.bind;
import isodi.pack;
import isodi.model;
import isodi.resource;
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
    alias GlobResult(T) = Tuple!(
        T[],   "matches",
        Pack*, "pack",
    );

    alias Resource = Pack.Resource;

    private {

        GlobResult!string[string] packGlobCache;
        Resource!(SkeletonNode[])[string] getSkeletonCache;
        Resource!(AnimationPart[])[string] getAnimationCache;

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
    /// Returns: A `GlobResult` tuple with the result.
    /// Throws: `IsodiException` if the path wasn't found in any of the packs.
    GlobResult!string packGlob(string path) {

        // Attempt to read from the cache
        if (auto cached = path in packGlobCache) {
            return *cached;
        }

        // Not in the cache, load it
        foreach (ref pack; packList) {

            auto glob = pack.glob(path);

            // Found a match
            if (glob.length) {

                return packGlobCache[path] = GlobResult!string(glob, &pack);

            }

        }

        throw new PackException(path.format!"Texture %s wasn't found in any pack");

    }

    // Barely a unittest, needs more packs to work
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

    /// Get a random resource under a file matching the pattern.
    /// Params:
    ///     path = File path to look for.
    ///     seed = Seed for the RNG.
    /// Returns: A tuple with path to the file and options of the resource.
    /// Throws: `IsodiException` if the path wasn't found in any of the packs.
    Resource!string randomGlob(RNG)(string path, RNG rng)
    if (isUniformRNG!RNG) {

        auto result = packGlob(path);
        auto resource = result.matches.choice(rng);

        return Resource!string(
            resource,
            result.pack.getOptions(resource),
        );

    }

    /// Load the given skeleton.
    /// Params:
    ///     name = Name of the skeleton.
    /// Returns:
    ///     A `Resource` tuple, first item is a list of the skeleton's nodes.
    Resource!(SkeletonNode[]) getSkeleton(string name) {

        // Attempt to read from the cache
        if (auto cached = name in getSkeletonCache) {
            return *cached;
        }

        return packSearch!"getSkeleton"(
            name,
            name.format!"Skeleton %s wasn't found in any listed pack"
        );

    }

    /// Load the given animation.
    /// Params:
    ///     name = Name of the animation.
    ///     frameCount = Frame count of the animation.
    /// Returns: A `Resource` tuple, first item is a list of animation parts.
    Resource!(AnimationPart[]) getAnimation(string name, out uint frameCount) {

        if (auto cached = name in getAnimationCache) {
            return *cached;
        }

        return packSearch!"getAnimation"(
            name, frameCount,
            name.format!"Animation '%s' wasn't found in any listed pack"
        );

    }

    private auto packSearch(string method, Args...)(ref Args args, lazy string fail) {

        /// Check each pack
        foreach (ref pack; packList) {

            // Attempt to load the method
            try return mixin("pack." ~ method ~ "(args)");

            // If failed, continue to the next pack
            catch (PackException) continue;

        }

        throw new PackException(fail);

    }

}
