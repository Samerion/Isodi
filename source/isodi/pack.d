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

import std.path;
import std.file;
import std.string;

import rcjson;

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
    /// Returns: List of nodes in the skeleton.
    /// Throws:
    ///     $(UL
    ///         $(LI `PackException` if the skeleton doesn't exist.)
    ///         $(LI `rcjson.JSONException` if the skeleton isn't valid.)
    ///     )
    SkeletonNode[] getSkeleton(const string name) {

        // Get the path
        const path = path.buildPath(name.format!"models/skeleton/%s.json");

        // Read the file
        auto json = JSONParser(path.readText);

        return getSkeletonImpl(json, name, 0, 0);

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
                    throw new JSONException(format!"Unknown skeleton field '%s' (skeleton '%s')"(key, name));

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

}
