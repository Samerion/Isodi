module isodi.resources.loader;

import raylib;
import std.algorithm;

import isodi.chunk;
import isodi.utils;
import isodi.skeleton;


@safe:


/// Interface for resource loading, can be specified in the `Properties` of each object.
///
/// Use `Pack` and `getPack` to use Isodi's default pack loader.
///
/// The loader should be responsible for allocating, caching and freeing the textures.
interface ResourceLoader {

    /// Get options for the given resource.
    const(ResourceOptions)* options(ResourceType resource, string name);

    /// Load texture for a chunk.
    Texture2D blockTexture(string[] names, out BlockUV[BlockType] uv)
    in (isSorted(names));

    ///// Load texture for the given bone sets.
    Texture2D boneSetTexture(string[] names, out BoneUV[BoneType] uv)
    in (isSorted(names));

    /// Load bones for a skeleton, using the given bone set.
    Bone[] skeleton(string name, string boneSet);

    // TODO packImages wrapper to support variably sized images.

    /// Combine the given images to create an atlas map. Each image must be square with dimensions equal to a power of
    /// two, eg. 32×32 or 128x128. All images must be of equal size.
    ///
    /// UV type must be a `RectangleI` or struct containing `RectangleI`s. The new mapping will offset the positions
    /// of those rectangles to match those of the newly made image.
    ///
    /// If given only one image, returns it unchanged.
    static Image packImages(UV, Type)(return scope UV[Type][] mapping, return scope Image[] images,
        out UV[Type] newMapping)
    in (images.length != 0,
        "No images given")
    in (images.all!"a.width == a.height && !(a.width & (a.width-1))",
        "All images are required to be square with dimensions equal to a power of two, eg. 32x32")
    in (images.isSorted!"a.width > b.width",
        "Given images must be sorted descending by size")
    in (mapping.length == images.length,
        "Map and image count must be equal")
    out (r; r.width == r.height,
        "Output image must be square")
    out (r; !(r.width & (r.width - 1)),
        "Output image must have dimensions equal to a power of two")
    do {

        import std.math, std.range, std.traits;

        static assert(is(UV == struct), "Mapping type must be a struct");

        T offsetUV(T)(T uv, int x, int y) {

            // Given a rectangle, offset it
            static if (is(T == RectangleI)) {

                return RectangleI(uv.x + x, uv.y + y, uv.width, uv.height);

            }

            // Something else!
            else {

                // Check each field of the struct
                foreach (ref field; uv.tupleof) {

                    // Search for rectangles
                    static if (is(typeof(field) == RectangleI)) {

                        // Apply offset to them
                        field = offsetUV(field, x, y);

                    }

                }

                return uv;

            }

        }

        // Just one image
        if (mapping.length == 1) {

            // Nothing to do
            newMapping = mapping[0];
            return images[0];

        }

        // Allocate the new image
        const imagesPerRow = cast(int) sqrt(cast(real) mapping.length).ceil;
        const partSize = images[0].width;
        const size = partSize * imagesPerRow;

        Image result = {
            data: &(new Color[size * size])[0],
            width: size,
            height: size,
            mipmaps: 1,
            format: PixelFormat.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8,
        };

        int i, j;

        foreach (map, image; zip(mapping, cast(const(Image)[]) images)) {

            // Advance to the next spot
            scope (success) {
                i += 1;
                j += i / imagesPerRow;
                i %= imagesPerRow;
            }

            const offsetX = partSize*i;
            const offsetY = partSize*j;

            // Update the mapping
            foreach (key, value; map) {

                newMapping[key] = offsetUV(value, offsetX, offsetY);

            }

            // Place the image
            () @trusted {

                // Note: ImageDraw is very imprecise

                // Copy the pixels over
                foreach (y; 0 .. partSize)
                foreach (x; 0 .. partSize) {

                    ImageDrawPixel(&result, offsetX + x, offsetY + y, GetImageColor(cast() image, x, y));

                }

            }();

        }

        return result;

    }

    unittest {

        Color[2][2] colorsA = [
            [Color(1, 1, 1, 1), Color(2, 2, 2, 2)],
            [Color(3, 3, 3, 3), Color(4, 4, 4, 4)],
        ];
        Color[2][2] colorsB = [
            [Color(5, 5, 5, 5), Color(6, 6, 6, 6)],
            [Color(7, 7, 7, 7), Color(8, 8, 8, 8)],
        ];

        scope Image imageA = {
            data: &colorsA,
            width: 2,
            height: 2,
            mipmaps: 1,
            format: PixelFormat.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8,
        };
        scope Image imageB = {
            data: &colorsB,
            width: 2,
            height: 2,
            mipmaps: 1,
            format: PixelFormat.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8,
        };

        RectangleI[string] mapA = [
            "a": RectangleI(0, 0, 1, 2),
        ];
        RectangleI[string] mapB = [
            "b": RectangleI(0, 0, 1, 2),
            "c": RectangleI(1, 0, 1, 2),
        ];
        RectangleI[string] map;

        auto image = packImages([mapA, mapB], [imageA, imageB], map);

        () @trusted {

            assert(image.GetImageColor(0, 0) == Color(1, 1, 1, 1));
            assert(image.GetImageColor(1, 0) == Color(2, 2, 2, 2));
            assert(image.GetImageColor(2, 0) == Color(5, 5, 5, 5));
            assert(image.GetImageColor(3, 0) == Color(6, 6, 6, 6));
            assert(image.GetImageColor(3, 1) == Color(8, 8, 8, 8));
            assert(image.GetImageColor(3, 3) == Color(0, 0, 0, 0));

        }();

        assert(map == [
            "a": RectangleI(0, 0, 1, 2),
            "b": RectangleI(2, 0, 1, 2),
            "c": RectangleI(3, 0, 1, 2),
        ]);

    }

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
