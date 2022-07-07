module isodi.resources.loader;

import raylib;

import isodi.chunk;
import isodi.utils;
import isodi.skeleton;


@safe:


/// Interface for resource loading, can be specified in the `Properties` of each object.
///
/// Use `Pack` and `getPack` to use Isodi's default pack loader.
interface ResourceLoader {

    /// Get options for the given resource.
    const(ResourceOptions)* options(ResourceType resource, string name);

    /// Load texture for the
    Texture2D blockTexture(string name);

    /// Load texture for the given bone set.
    Texture2D boneSetTexture(string name);

    /// Load UVs for a bone set.
    ///
    /// Within packs, this data is stored in `bones/*.json`.
    ///
    /// Returns: An associative array mapping each bone to their rectangles in the texture.
    BoneUV[BoneType] boneSet(string name);

    /// Load bones for the given skeleton.
    Bone[] skeleton(string name);

}

/// Type of the resource.
enum ResourceType {

    block,
    bone,
    skeleton,

}

/// Resource options
struct ResourceOptions {

    /// If true, a filter will be applied to smooth out the texture. This should be off for pixel art packs.
    bool interpolate = true;

    // TODO better docs

    /// Size of the tile texture (both width and height).
    ///
    /// Required.
    uint tileSize;

    /// Side texture height.
    uint sideSize;

    /// Amount of angles each multi-directional texture will provide. All angles should be placed in a single
    /// row in the image.
    ///
    /// 4 angles means the textures have a separate sprite for every 90 degrees, 8 angles — 45 degrees,
    /// and so on.
    ///
    /// Defaults to `4`.
    uint angles = 4;

    int[4] tileArea;
    int[4] sideArea;

    auto blockUV() const => BlockUV(
        cast(RectangleI) tileArea,
        cast(RectangleI) sideArea,
        tileSize,
        sideSize,
    );

}


// TODO utility function for merging textures, especially needed for chunks
