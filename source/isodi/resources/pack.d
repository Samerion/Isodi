/// This module contains structs containing data relating to packs.
module isodi.resources.pack;

import rcdata.json;

import std.conv;
import std.path;
import std.file;
import std.string;

import isodi.chunk;
import isodi.utils;

public import isodi.resources.pack_json;


@safe:


/// Resource options
struct ResourceOptions {

    /// If true, a filter will be applied to smooth out the texture. This should be off for pixel art packs.
    bool interpolate = true;

    // TODO better docs

    /// Size of the tile texture (both width and height).
    ///
    /// Required.
    uint tileSize;

    /// Decoration texture height.
    uint decorationSize;

    /// Amount of angles each multi-directional texture will provide. All angles should be placed in a single
    /// row in the image.
    ///
    /// 4 angles means the textures have a separate sprite for every 90 degrees, 8 angles — 45 degrees,
    /// and so on.
    ///
    /// Defaults to `4`.
    uint angles = 4;

    long[4] tileArea;
    long[4] decorationArea;

    auto blockUV() const => BlockUV(
        cast(RectangleL) tileArea,
        cast(RectangleL) decorationArea,
        tileSize,
        decorationSize
    );

}

/// Represents a pack.
///
/// To read a pack from a JSON file, use `getPack`.
struct Pack {

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

    /// Option fields applied to specific files.
    ///
    /// The keys are a relative path to a resource or a directory. Options defined under an empty key affect all
    /// resources. In JSON, you can provide that key with an `options` field instead, for readability.
    ///
    /// Fields missing in the JSON will be inherited from parent directories or will use the default value.
    @JSONExclude
    ResourceOptions[string] fileOptions;

    /// Glob search within the pack.
    string[] glob(string file) @trusted {

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
        foreach (file; res.stripRight("/").DeepAncestors) {

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

}
