/// This module contains structs containing data relating to packs.
///
/// To load packs, use `isodi.pack_json.getPack`, see examples attached to it.
///
/// Public_imports:
///     $(UL
///         $(LI `isodi.pack_list` with pack management functions)
///         $(LI `isodi.pack_json` with pack loading functions)
///     )
///
/// Macros:
///     TCOLON = $0:
module isodi.pack;

import std.conv;
import std.path;
import std.file;
import std.random;
import std.string;
import std.typecons;
import std.exception;
import std.algorithm;

import rcdata.json;

import isodi.model;
import isodi.internal;
import isodi.resource;
import isodi.exceptions;

public {

    import isodi.pack_list;
    import isodi.pack_json;

}

/// Resource options
struct ResourceOptions {

    /// If true, a filter will be applied to smooth out the texture. This should be off for pixel art packs.
    bool interpolate = true;

    /// Tile size assumed by the pack. It doesn't affect tiles themselves, but any other resource relying on
    /// that number will use this field.
    ///
    /// For example, decoration sprites will be scaled depending on their size and this field
    /// (`decoration side / metadata.tileSize`)
    ///
    /// Required.
    uint tileSize;

    /// Amount of angles each multi-directional texture will provide. All angles should be placed in a single
    /// row in the image.
    ///
    /// 4 angles means the textures have a separate sprite for every 90 degrees, 8 angles — 45 degrees,
    /// and so on.
    ///
    /// Defaults to `4`.
    uint angles = 4;

    /// $(TCOLON Decoration) Rectangle in the texture that will stick to the original tile.
    ///
    /// $(TCOLON Format) `[position x, position y, size x, size y]`. The top-left corner of each angle texture is at
    /// `(0, 0)`.
    ///
    /// Defaults to a single pixel in the bottom middle part of the texture.
    uint[4] hardArea;

    /// $(TCOLON Tiles) Amount of space that will be available to be spanned by decoration. See `decorationWeight`.
    /// for more info.
    ///
    /// This is a range. A random number will be chosen in it to select the actual value.
    ///
    /// Defaults to `[50, 100]`.
    uint[2] decorationSpace = [50, 100];

    /// $(TCOLON Decoration) Amount of space the decoration will use.
    ///
    /// Larger decoration textures should have a higher value set.
    ///
    /// Defaults to `20`.
    uint decorationWeight = 20;

}

/// Represents a pack.
///
/// To read a pack from a JSON file, use `getPack`.
struct Pack {

    /// Represents a resource along with its options.
    ///
    /// $(UL
    ///     $(LI `match` — Matched resource)
    ///     $(LI `options` — Options of the resource)
    /// )
    alias Resource(T) = Tuple!(
        T,                       "match",
        const(ResourceOptions)*, "options",
    );

    /// Path to the pack in the filesystem.
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

    /// Option fields applied to specific files.
    ///
    /// The keys are a relative path to a resource or a directory. Options defined under an empty key affect all
    /// resources. In JSON, you can provide that key with an `options` field instead, for readability.
    ///
    /// Fields missing in the JSON will be inherited from parent directories or will use the default value.
    @JSONExclude
    ResourceOptions[string] fileOptions;


    /// Glob search within the pack.
    string[] glob(string file) {

        import std.array : array;

        // Get paths to the resource
        const resPath = path.buildPath(file);
        const resDir = resPath.dirName;

        // This directory must exist
        if (!resDir.exists || !resDir.isDir) return null;

        // List all files inside
        return resDir.dirEntries(resPath.baseName, SpanMode.shallow).array.to!(string[]);

    }

    /// Read options of the given resource.
    /// Params:
    ///     res = Relative path to the resource.
    /// Returns: A pointer to the resource's options.
    const(ResourceOptions)* getOptions(string res) const {

        // Remove prefixes
        res = res.chompPrefix(path).stripLeft("/");

        /// Search for the closest matching resource
        foreach (file; res.stripRight("/").deepAncestors) {

            // Return the first one found
            if (auto p = file in fileOptions) return p;

        }

        assert(0, name.format!"Internal error: Root options missing for pack %s");

    }

    ///
    unittest {

        // Load the pack
        auto pack = getPack("res/samerion-retro/pack.json");

        // Check root options
        const rootOptions = pack.getOptions("");
        assert(!rootOptions.interpolate);
        assert(rootOptions.tileSize == 32);

        // Check if getOptions correctly handles resources that don't have any options set directly
        assert(pack.getOptions("cells/grass") is pack.getOptions("cells/grass/not-existing"));

    }

    /// Get a skeleton from this pack
    /// Params:
    ///     name = Name of the skeleton to load.
    /// Returns: A `Resource` tuple, first item is a list of nodes in the skeleton.
    /// Throws:
    ///     $(UL
    ///         $(LI `PackException` if the skeleton doesn't exist.)
    ///         $(LI `rcdata.json.JSONException` if the skeleton isn't valid.)
    ///     )
    Resource!(SkeletonNode[]) getSkeleton(const string name) {

        // Get the path
        const path = path.buildPath(name.format!"models/skeleton/%s.json");

        // Check if the file exists
        enforce!PackException(path.exists, format!"Skeleton %s wasn't found in pack %s"(name, this.name));

        // Read the file
        auto json = JSONParser(path.readText);

        return Resource!(SkeletonNode[])(
            getSkeletonImpl(json, name, 0, 0),
            getOptions(path),
        );

    }

    private SkeletonNode[] getSkeletonImpl(ref JSONParser json, const string name, const size_t parent,
        const size_t id) {

        // Get the nodes
        SkeletonNode[] children;
        auto root = json.getStruct!SkeletonNode((ref obj, key) {

            // Check the key — note most of the keys are handled automatically
            switch (key) {

                case "display":  // possibly deprecated, "hidden" is preferred
                    obj.hidden = !json.getBoolean;
                    break;

                // Children nodes
                case "nodes":

                    // Check each node
                    foreach (index; json.getArray) {

                        children ~= getSkeletonImpl(json, name, id, id + children.length + 1);

                    }
                    break;

                default:
                    throw new JSONException(
                        format!"Unknown field '%s' (skeleton '%s/%s')"(key, this.name, name)
                    );

            }

        });

        // Assign a parent
        root.parent = parent;

        // Set a default ID
        if (root.id == "") {

            root.id = root.name;

        }

        return [root] ~ children;

    }

    /// Get an animation from this pack. Used variant will be chosen randomly.
    /// Params:
    ///     name       = Name of the animation to load.
    ///     frameCount = `out` parameter filled with frame count of the animation.
    /// Returns: A `Resource` tuple, first item is a list of animation parts.
    /// Throws:
    ///     $(UL
    ///         $(LI `PackException` if the animation doesn't exist.)
    ///         $(LI `rcdata.json.JSONException` if the animation isn't valid.)
    ///     )
    Resource!(AnimationPart[]) getAnimation(const string name, out uint frameCount) {

        import std.array : array;
        import std.algorithm : map;

        // Search for the animation
        auto matches = glob(name.format!"models/animation/%s/*.json");

        enforce!PackException(matches.length, format!"Animation %s wasn't found in pack %s"(name, this.name));

        // Pick a random match
        const animation = matches.choice;

        // Read the JSON
        auto json = JSONParser(animation.readText);
        auto partsMap = json.getArray.map!(index => getAnimationPart(json, name, frameCount));

        // .array method wrongly issues a deprecation warning of Nullable property of the map. This is the workaround.
        AnimationPart[] parts;
        foreach (part; partsMap) parts ~= part;

        return Resource!(AnimationPart[])(parts, getOptions(animation));

    }

    private AnimationPart getAnimationPart(ref JSONParser json, const string name, ref uint frameCount) {

        AnimationPart result;

        foreach (key; json.getObject) {

            switch (key) {

                case "length":
                    result.length = json.get!uint;
                    break;

                case "offset":
                    result.offset = getAnimationProperty!(float[3])(json);
                    break;

                default:
                    result.bone[key.to!string] = getAnimationBone(json, name);

            }

        }

        frameCount += result.length;

        return result;

    }

    private AnimationBone getAnimationBone(ref JSONParser json, const string name) {

        AnimationBone result;

        foreach (key; json.getObject) {

            // Too small for automation
            switch (key) {

                case "rotate":
                    result.rotate = getAnimationProperty!(float[3])(json);
                    break;

                case "scale":
                    result.scale = getAnimationProperty!float(json);
                    break;

                default:
                    throw new JSONException(
                        format!"Unknown property %s (animation '%s/%s')"(key, this.name, name)
                    );

            }

        }

        return result;

    }

    private Nullable!T getAnimationProperty(T : Value[N], Value, size_t N)(ref JSONParser json) {

        // Get the same value with one value more
        auto value = json.get!(Value[N+1]);
        return value[1..$].to!T.nullable;

    }

    private Nullable!T getAnimationProperty(alias T)(ref JSONParser json) {

        auto value = json.get!(T[2]);
        return value[1].nullable;
    }

    /// List cells available in the pack.
    /// Returns: A range with all cells that can be found in the pack.
    auto listCells() const {

        // Return all directories within "cells/"
        return path.buildPath("cells")
            .dirEntries(SpanMode.shallow)
            .filter!((string name) => name.isDir)
            .map!baseName;

    }

    unittest {

        // Load the pack
        auto pack = getPack("res/samerion-retro/pack.json");
        assert(pack.listCells.canFind("grass"));

    }

}
