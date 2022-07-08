/// This module contains structs containing data relating to packs.
module isodi.resources.pack;

import raylib;
import rcdata.json;

import std.conv;
import std.path;
import std.file;
import std.string;

import isodi.chunk;
import isodi.utils;
import isodi.skeleton;
import isodi.exception;
import isodi.resources.loader;

public import isodi.resources.pack_json;


@safe:


/// Represents a pack.
///
/// To read a pack from a JSON file, use `getPack`. This must be used from the renderer thread.
class Pack : ResourceLoader {

    public {

        /// Path to the pack directory in the filesystem.
        @JSONExclude
        string path;

        /// Name of the pack.
        string name;

        /// Description of the pack.
        string description;

        /// Version of the pack.
        string packVersion;

        /// Targeted Isodi version
        string isodiVersion;

        /// License of the pack.
        string license;

        /// Block types registered in the pack.
        @JSONExclude
        BlockType[string] blockTypes;

        /// Bone types registered in the pack.
        @JSONExclude
        BoneType[AbsoluteBoneType] boneTypes;

        /// Next block type ID to use.
        @JSONExclude
        size_t nextBlockType;

        /// Next bone type ID to use.
        @JSONExclude
        size_t nextBoneType;

        /// Option fields applied to specific files. Filename extensions are to be omitted in keys.
        ///
        /// If no option is found for a file, the entry of its parent directory will be checked, then the grandparent
        /// and so on until an empty string.
        ///
        /// In JSON, the `options` property is an alias to an empty string key. Additionally, the JSON parser will
        /// inherit fields from the parent entries instead of using `.init` values.
        ///
        /// Fields missing in the JSON will be inherited from parent directories or will use the default value.
        @JSONExclude
        ResourceOptions[string] fileOptions;


    }

    // Caches.
    static private {

        struct CacheEntry(UV, Type) {

            Texture2D texture;
            UV[Type] uv;

        }

        /// Image cache. `path => image`
        Image[string] imageCache;

        /// Block texture cache
        CacheEntry!(BlockUV, BlockType)[string[]] blockCache;

        /// Bone texture cache.
        CacheEntry!(BoneUV, BoneType)[string[]] boneCache;

    }

    private {

        /// Bone set cache
        BoneUV[BoneType][string] boneSetCache;

    }

    static ~this() @trusted {

        // OpenGL enforces thread-local context access. GPU texture references are not usable from other threads, so
        // destroying those textures should be safe, as references on other threads are invalid anyway, so as a result,
        // no live references will be invalidated.

        destroyGlobalCache();

    }

    /// Free all textures loaded into the GPU and clear the image cache. Make sure to remove all references to those
    /// textures before calling.
    ///
    /// This is automatically done when the rendering thread is freed.
    static void destroyGlobalCache() @system {

        import std.range, std.algorithm;

        // Empty the cache when done
        scope (success) {
            imageCache = null;
            blockCache = null;
            boneCache = null;
        }

        // If the window isn't open, there aren't any textures to free.
        if (!IsWindowReady) return;

        // Unload images
        foreach (image; imageCache) {

            UnloadImage(image);

        }

        // Unload all textures
        foreach (texture; chain(blockCache.byValue.map!"a.texture", boneCache.byValue.map!"a.texture")) {

            UnloadTexture(texture);

        }

    }

    /// Destroy the bone set cache.
    void destroyLocalCache() {

        boneSetCache = null;

    }

    /// Destroy both global and local cache.
    void destroyAllCache() @system {

        destroyGlobalCache();
        destroyLocalCache();

    }

    /// Load an image by a filesystem path (from cache or filesystem).
    ///
    /// The image will be loaded into cache. Stored data must not be freed.
    static Image loadImageStatic(string path) {

        // Load from cache
        if (auto image = path in imageCache) {

            return *image;

        }

        // Load from filesystem
        else {

            // Load the texture
            auto image = (() @trusted => LoadImage(path.toStringz))();

            // Write to cache
            imageCache[path] = image;

            return image;

        }

    }

    /// Get a filesystem path given a pack path.
    string globalPath(string file) const => buildPath(path, file);

    /// Load an image by a path relative to the pack. (from cache or filesystem).
    ///
    /// The image will be loaded into the cache. Image data must not be freed.
    Image loadImage(string file) const {

        return loadImageStatic(globalPath(file));

    }

    /// Glob search within the pack.
    string[] glob(string file) @trusted const {

        import std.array : array;

        // Get paths to the resource
        const resPath = buildPath(path, file);
        const resDir = resPath.dirName;

        // Return an empty set if the directory doesn't exist
        if (!resDir.exists || !resDir.isDir) return null;

        // List all files inside
        return resDir.dirEntries(resPath.baseName, SpanMode.shallow).array.to!(string[]);

    }

    /// Load a block.
    ///
    /// Returned texture is stored in the cache. Texture data must not be freed.
    Texture blockTexture(string[] names, out BlockUV[BlockType] uv)
         => modelTexture!(BlockUV, BlockType, "block/%s.png", blockCache, blockAtlas)(names, uv);

    /// Load a bone.
    ///
    /// Returned texture is stored in the cache. Texture data must not be freed.
    Texture boneSetTexture(string[] name, out BoneUV[BoneType] uv)
        => modelTexture!(BoneUV, BoneType, "bone/%s.png", boneCache, boneSetAtlas)(name, uv);


    /// Load a model texture.
    Texture2D modelTexture(UV, Type, string path, alias cache, alias atlasLoader)(string[] names, out UV[Type] uv) {

        // This texture has already been loaded
        if (auto entry = names in cache) {

            uv = entry.uv;
            return entry.texture;

        }

        Image[] images;
        UV[Type][] maps;

        images.reserve(names.length);
        maps.reserve(names.length);

        // Check each texture
        foreach (i, name; names) {

            // Load the image
            images ~= loadImage(format!path(name));

            // Load the options
            maps ~= atlasLoader(name);

        }

        // Pack the images
        auto image = packImages(maps, images, uv);
        auto texture = (() @trusted => LoadTextureFromImage(image))();

        cache[cast(const) names] = CacheEntry!(UV, Type)(texture, uv);

        return texture;

    }

    /// Load a chunk UV map.
    BlockUV[BlockType] blockAtlas(string name) => [
        blockType(name): options(ResourceType.block, name).blockUV
    ];

    /// Load a bone UV map.
    BoneUV[BoneType] boneSetAtlas(string name) {

        // Check the cache first
        if (auto set = name in boneSetCache) return *set;

        const resPath = globalPath(format!"bone/%s.json"(name));

        // Try to read from file
        try {

            auto set = parseBoneSet(resPath.readText, bone => boneType(name, bone.to!string));

            // Write to cache
            boneSetCache[name] = set;

            return set;

        }

        // Oops.
        catch (Exception exc) {

            // Convert all exceptions to PackException.
            throw new PackException(format!"Failed to load boneSet %s from file '%s'; %s"(name, resPath, exc.msg));

        }

    }

    /// Get the block type for the given block string. Registers a new block type if the path doesn't exist.
    BlockType blockType(string block)

        => blockTypes.require(
            block,
            BlockType(nextBlockType++),
        );


    /// Get the bone type for the given model/bone strings. Registers a new bone type if the specified one wasn't
    /// registered before.
    BoneType boneType(string boneSet, string bone)

        => boneTypes.require(
            AbsoluteBoneType(boneSet, bone),
            BoneType(nextBoneType++),
        );


    /// Load a skeleton.
    /// Params:
    ///     name = Name for the skeleton.
    ///     boneSet = Bone set to use.
    ///     bonePicker = Delegate to determine what bone type to use for each bone.
    Bone[] skeleton(string name, string boneSet)

        => skeleton(name, bone => boneType(boneSet, bone.to!string));


    Bone[] skeleton(string name, BoneType delegate(wstring) @safe bonePicker) const {

        const resPath = globalPath(format!"skeleton/%s.json"(name));

        // Try to read & parse the file
        try return parseSkeleton(bonePicker, resPath.readText);

        // Oops.
        catch (Exception exc) {

            // Convert all exceptions to PackException.
            throw new PackException(format!"Failed to load skeleton %s from file '%s'; %s"(name, resPath, exc.msg));

        }

    }

    ///
    const(ResourceOptions)* options(ResourceType type, string res) const {

        const path = format!"%s/%s"(type, res);

        /// Search for the closest matching resource
        foreach (file; path.stripRight("/").DeepAncestors) {

            // Return the first one found
            if (auto p = file in fileOptions) return p;

        }

        assert(0, name.format!"Internal error: Root options missing for pack %s");

    }

    ///
    unittest {

        // Load the pack
        auto pack = getPack("res/samerion-retro/pack.json");

        enum blockType = ResourceType.block;

        // Check root options
        const rootOptions = pack.options(blockType, "");
        assert(!rootOptions.interpolate);
        assert(rootOptions.tileSize == 32);

        // Check if `options` correctly handles resources that don't have any options set directly
        assert(pack.options(blockType, "grass") is pack.options(blockType, "grass/not-existing"));

    }

}

struct AbsoluteBoneType {

    string boneset;
    string bone;

}
