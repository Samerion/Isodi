/// This module contains structs containing data relating to packs.
module isodi.resources.pack;

import raylib;
import rcdata.json;

import std.conv;
import std.path;
import std.file;
import std.string;

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

        /// Bone types registered in the pack.
        @JSONExclude
        BoneType[AbsoluteBoneType] boneTypes;

        /// Next bone type ID to use.
        @JSONExclude
        size_t nextBoneType = 1;

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

        /// Texture cache.
        @JSONExclude
        Texture2D[string] textureCache;

        /// Bone set cache
        RectangleI[BoneType] boneSetCache;

    }

    static ~this() @trusted {

        // OpenGL enforces thread-local context access. GPU texture references are not usable from other threads, so
        // destroying those textures should be safe, as references on other threads are invalid anyway, so as a result,
        // no live references will be invalidated.

        destroyTextures();

    }

    /// Free all textures loaded into the GPU and clear the texture cache. Make sure to remove all references to those
    /// textures before calling.
    ///
    /// This is automatically done when the rendering thread is freed.
    static void destroyTextures() @system {

        // Empty the cache when done
        scope (success) textureCache = null;

        // If the window isn't open, there aren't any textures to free.
        if (!IsWindowReady) return;

        // Unload all textures
        foreach (texture; textureCache) {

            UnloadTexture(texture);

        }

    }

    /// Load a texture by a filesystem path (from cache or filesystem).
    static Texture2D loadTextureStatic(string path) {

        // Load from cache
        if (auto texture = path in textureCache) {

            return *texture;

        }

        // Load from filesystem
        else {

            // Load the texture
            const texture = (() @trusted => LoadTexture(path.toStringz))();

            // Write to cache
            textureCache[path] = texture;

            return texture;

        }

    }

    /// Get a filesystem path given a pack path.
    string globalPath(string file) const => buildPath(path, file);

    /// Load a texture by a path relative to the pack. (from cache or filesystem).
    Texture2D loadTexture(string file) const {

        return loadTextureStatic(globalPath(file));

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
    Texture blockTexture(string name) const => loadTexture(format!"block/%s.png"(name));

    /// Load a bone.
    Texture boneSetTexture(string name) const => loadTexture(format!"bone/%s.png"(name));

    /// Load a bone set.
    BoneUV[BoneType] boneSet(string name) {

        const resPath = globalPath(format!"bone/%s.json"(name));

        // Try to read & parse the file
        try return parseBoneSet(name, resPath.readText);

        // Oops.
        catch (Exception exc) {

            // Convert all exceptions to PackException.
            throw new PackException(format!"Failed to load boneSet %s from file '%s'; %s"(name, resPath, exc.msg));

        }

    }

    /// Parse a bone set from a JSON string.
    private BoneUV[BoneType] parseBoneSet(string name, string json) @trusted {

        auto parser = JSONParser(json);
        BoneUV[BoneType] result;

        // Get each
        foreach (key; parser.getObject) {

            // Get the bone type
            const type = boneType(name, key.to!string);

            // Load the value
            const uv = cast(RectangleI) parser.get!(int[4]);

            result[type] = BoneUV(uv);
            // TODO support variants

        }

        return result;

    }

    unittest {

        auto pack = new Pack();
        auto boneSet = pack.parseBoneSet("model", q{
            {
                "torso": [1, 1, 56, 16],
                "head": [1, 18, 40, 14],
                "thigh": [43, 18, 20, 12],
                "abdomen": [1, 33, 31, 7],
                "upper-arm": [43, 31, 20, 13],
                "lower-leg": [1, 41, 12, 9],
                "hips": [1, 52, 40, 6],
                "hand": [43, 45, 20, 3],
                "forearm": [51, 49, 12, 9],
                "foot": [11, 59, 52, 4]
            }
        });

        assert(boneSet[BoneType(0)] == BoneUV(RectangleI(1, 1, 56, 16)));

        const forearm = pack.boneType("model", "forearm");
        assert(boneSet[forearm] == BoneUV(RectangleI(51, 49, 12, 9)));

    }

    /// Get the bone type for the given model/bone string. Registers a new bone type if the path doesn't exist
    BoneType boneType(string boneSet, string bone) {

        return boneTypes.require(
            AbsoluteBoneType(boneSet, bone),
            BoneType(nextBoneType++),
        );

    }

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

    private Bone[] parseSkeleton(BoneType delegate(wstring) @safe bonePicker, string json) const {

        auto parser = JSONParser(json);
        return parseSkeletonImpl(bonePicker, parser, 0, 0);

    }

    private Bone[] parseSkeletonImpl(BoneType delegate(wstring) @safe bonePicker, ref JSONParser parser, size_t parent,
    size_t index, float divisor = 1) const @trusted
    do {

        auto result = [Bone(index, BoneType.init, parent, MatrixIdentity)];
        size_t childIndex = index;

        foreach (key; parser.getObject) {

            switch (key) {

                case "name":
                    result[0].type = bonePicker(parser.getString);
                    break;

                case "matrix":
                    result[0].transform = Matrix(parser.get!(float[16]).tupleof);
                    break;

                case "transform":
                    parser.skipValue;
                    break; // TODO

                case "vector":
                    result[0].vector = Vector3(parser.get!(float[3]).tupleof) / divisor;
                    break;

                case "children":
                    foreach (child; parser.getArray) {
                        result ~= parseSkeletonImpl(bonePicker, parser, index, ++childIndex, divisor);
                    }
                    break;

                case "divisor":

                    // TODO It would be nice to remove those restrictions
                    enforce!PackException(result[0].transform == MatrixIdentity,
                        "`divisor` must precede `matrix` & `transform` fields");
                    enforce!PackException(result[0].vector == Vector3.init,
                        "`divisor` must precede the `vector` field");

                    divisor = parser.get!float;
                    break;

                default:
                    throw new PackException(format!"Unknown key '%s' on line %s"(key, parser.lineNumber));

            }

        }

        return result;

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
