/// This module contains structs containing data relating to packs.
///
/// To load packs, use `rcjson.JSONParser` along with `isodi.pack_impl.getPack`, see examples attached to it.
///
/// Public_imports:
///     $(UL
///         $(LI `isodi.pack_impl` with pack management functions)
///     )
///
/// Macros:
///     TCOLON = $0:
module isodi.pack;

import std.string;
import rcjson;

import isodi.internal;

public {

    import isodi.pack_list;
    import isodi.pack_json;

}

/// Resource options
struct ResourceOptions {

    /// If true, a filter will be applied to smooth out the texture. This should be off for pixel art packs.
    bool filter = true;

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

    /// 0-indexed position of the "anchor" in each image. The pixel marked with this property will be placed
    /// at the position of the sprite.
    ///
    /// This currently only affects decorations.
    ///
    /// Defaults to the bottom center part of the texture.
    deprecated uint[2] anchor;

    /// $(TCOLON Decoration) Rectangle in the texture that will stick to the original tile.
    ///
    /// $(TCOLON Format) `[position x, position y, size x, size y]`. The top-left corner of each angle texture is at
    /// `(0, 0)`.
    ///
    /// Defaults to a single pixel in the bottom middle part of the texture.
    uint[4] hardArea;

    /// $(TCOLON Tiles) Amount of space that will be availabe to be spanned by decoration. See `decorationWeight`.
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
    ///     pack = Pack to read from.
    ///     path = Relative path to the resource.
    /// Returns: A pointer to the resource's options.
    const(ResourceOptions)* getOptions(string path) const {

        /// Search for the closest matching resource
        foreach (file; path.stripRight("/").deepAncestors) {

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
        assert(!rootOptions.filter);
        assert(rootOptions.tileSize == 128);

        // Check if getOptions correctly handles resources that don't have any options set directly
        assert(pack.getOptions("cells/grass") is pack.getOptions("cells/grass/not-existing"));

    }

}
