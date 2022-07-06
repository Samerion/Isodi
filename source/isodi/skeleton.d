module isodi.skeleton;

import raylib;

import std.math;
import std.array;
import std.format;
import std.algorithm;

import isodi.utils;
import isodi.properties;
import isodi.isodi_model;

private alias PI = std.math.PI;


@safe:


/// Skeleton.
///
/// TODO documentation
struct Skeleton {

    public {

        /// Properties for the skeleton.
        Properties properties;

        /// Seed to use to generate variants on the skeleton.
        ulong seed;

        /// Mapping of bone types to their positions in the texture.
        BoneUV[BoneType] atlas;

        /// All bones in the skeleton.
        ///
        /// Note: A child bone should never come before its parent.
        Bone[] bones;

    }

    /// Add a bone from the given bone set.
    Bone* addBone(BoneType type, const Bone* parent, Matrix matrix, Vector3 vector) return {

        bones ~= Bone(bones.length, type, parent, matrix, vector);
        return &bones[$-1];

    }

    /// ditto
    Bone* addBone(BoneType type, Matrix matrix, Vector3 vector) return
        => addBone(type, null, matrix, vector);

    /// ditto
    Bone* addBone(BoneType type, const Bone* parent) @trusted return
        => addBone(type, parent, MatrixIdentity, Vector3(0, 1, 0));

    /// ditto
    Bone* addBone(BoneType type) @trusted return
        => addBone(type, MatrixIdentity, Vector3(0, 1, 0));

    /// Make a model out of the skeleton.
    ///
    /// Note: `texture` and `matrixImage` will not be automatically freed. This must be done manually.
    IsodiModel makeModel(return Texture2D texture, return Texture2D matrixTexture = Texture2D.init) const @trusted
    in (matrixTexture.height == 0 || matrixTexture.height == bones.length,
        format!"Matrix texture height (%s) must match bone count (%s) or be 0"(matrixTexture.height, bones.length))
    in (matrixTexture.height == 0 || matrixTexture.width == 4,  // note: width == 0 isn't valid if height != 0
        format!"Matrix texture width (%s) must be 4"(matrixTexture.width))
    do {

        const atlasSize = Vector2(texture.width, texture.height);

        // Model data
        const vertexCount = bones.length * 4;
        const triangleCount = bones.length * 2;

        // Create a model
        IsodiModel model = {
            properties: properties,
            texture: texture,
            matrixTexture: matrixTexture,
            flatten: true,
            showBackfaces: true,
        };
        model.vertices.reserve = vertexCount;
        model.variants.length = vertexCount;
        model.texcoords.reserve = vertexCount;
        model.bones.length = matrixTexture.height * 4;
        model.triangles.reserve = triangleCount;

        // Add each bone
        foreach (i, const bone; bones) with (model) {

            const boneUV = bone.type in atlas;
            assert(boneUV, format!"%s not present in skeleton atlas"(bone));

            // Get the variant
            auto boneVariant = boneUV.getBone(seed + i).toShader(atlasSize);
            boneVariant.width /= 4;  // TODO use variant count instead

            // Get the size of the bone
            Vector2 boneSize;
            boneSize.y = Vector3Length(bone.vector);
            boneSize.x = boneSize.y * boneVariant.width / boneVariant.height;

            bool invertX, invertY;

            Vector3 makeVertex(bool start, int sign, bool adjust = false) {

                // Revert start and left, if needed, to make the bone face the right direction
                if (!adjust) {
                    sign  *= invertX ? -1 : 1;
                    start ^= invertY;
                }

                /// Matrix to adjust the horizontal position of the vertex
                const translation = MatrixTranslate(sign * boneSize.x / 2, 0, 0);

                /// Vector to use for transformation — one for start, one for end
                const vector = start
                    ? Vector3()
                    : bone.vector;

                return vector.Vector3Transform(translation);

            }

            // Check inverts
            {

                const xstart = makeVertex(true, -1, true);
                const xend   = makeVertex(true, +1, true);

                const ystart = makeVertex(true,  +1, true);
                const yend   = makeVertex(false, +1, true);

                invertX = xstart.x > xend.x;
                invertY = ystart.y > yend.y;

            }

            // Vertices
            vertices ~= [
                makeVertex(false, -1),
                makeVertex(false, +1),
                makeVertex(true,  +1),
                makeVertex(true,  -1),
            ];

            // UVs
            texcoords ~= [
                Vector2( invertX,  invertY),
                Vector2(!invertX,  invertY),
                Vector2(!invertX, !invertY),
                Vector2( invertX, !invertY),
            ];

            // TODO verify this
            const normalMatrix = MatrixMultiply(
                MatrixRotate(Vector3(-1, 0, 0), PI / 2),
                bone.transform,
            );

            Vector2 anchor(bool start) {
                return Vector2(
                    makeVertex(start, 0).x.round,
                    makeVertex(start, 0).z.round,
                );
            }

            // Variants
            variants.assign(i, 4, boneVariant);

            // Bones
            if (bones.length != 0) {
                bones.assign(i, 4, cast(float) i / this.bones.length);
            }

            ushort[3] value(int[] offsets) => [
                cast(ushort) (i*4 + offsets[0]),
                cast(ushort) (i*4 + offsets[1]),
                cast(ushort) (i*4 + offsets[2]),
            ];

            // Triangles
            triangles ~= map!value([
                [0, 1, 2],
                [0, 2, 3],
            ]).array;

        }

        // Upload the model
        model.upload();

        return model;

    }

    /// Generate a matrix image for the skeleton.
    Image matrixImage() const
    in (bones.length <= int.max, "There are too many bones to fit in an image")
    do {

        auto data = matrixImageData;

        Image result = {
            data: &data[0],
            width: 4,
            height: cast(int) data.length,
            mipmaps: 1,
            format: PixelFormat.PIXELFORMAT_UNCOMPRESSED_R32G32B32A32,
        };

        return result;

    }

    /// Generate a matrix image data for the skeleton.
    ///
    /// Both buffer parameters are optional, but can be provided to prevent allocation on subsequent calls.
    ///
    /// Params:
    ///     buffer = Buffer for use in the image. Filled with bone-start matrices.
    ///     matrices = Array filled with bone-end matrices. Byproduct of the matrix image generation.
    Vector4[4][] matrixImageData() const {

        // Create a buffer
        auto result = new Vector4[4][bones.length];

        // Write data to it
        matrixImageData(result);

        return result;

    }

    /// ditto
    void matrixImageData(Vector4[4][] buffer) const
    in (bones.length > 0, "Cannot generate image for an empty model")
    in (buffer.length == bones.length, "Buffer height differs from bone count")
    do {

        // Create a matrix array for the bones
        auto matrices = new Matrix[bones.length];

        matrixImageData(buffer, matrices);

    }

    /// ditto
    void matrixImageData(Vector4[4][] buffer, Matrix[] matrices) const
    in (buffer.length == bones.length, "Buffer count differs from bone count")
    in (matrices.length == bones.length, "Matrix count differs from bone count")
    do {

        size_t i;

        // Convert the matrices
        globalMatrices(matrices, (matrix) {

            // Write to the buffer with a column-first layout
            buffer[i++] = [
                Vector4(matrix.m0,  matrix.m1,  matrix.m2,  matrix.m3),
                Vector4(matrix.m4,  matrix.m5,  matrix.m6,  matrix.m7),
                Vector4(matrix.m8,  matrix.m9,  matrix.m10, matrix.m11),
                Vector4(matrix.m12, matrix.m13, matrix.m14, matrix.m15),
            ].staticArray;

        });

    }

    /// Fill the given array with matrices each transforming a zero vector to the end of corresponding bones, relative
    /// to the model.
    ///
    /// Given delegate will be called, for each bone, with the current matrix but pointing to the *start* of the bone.
    void globalMatrices(Matrix[] matrices, void delegate(Matrix) @safe startCb = null) const @trusted
    in (matrices.length == bones.length, "Length of the given matrix buffer doesn't match bones count")
    do {

        // Prepare matrices for each bone
        foreach (i, bone; bones) {

            // Get the bone's relative transform
            Matrix matrix = bone.transform;

            // If there's a parent
            if (bone.parent) {

                // Get the parent transform
                const parent = matrices[bone.parent.index];

                // Inherit it
                matrix = MatrixMultiply(matrix, parent);

            }

            // Finally, transform the matrix to the bone's end
            matrices[i] = MatrixMultiply(MatrixTranslate(bone.vector.tupleof), matrix);

            // Emit the matrix
            if (startCb) startCb(matrix);

        }

    }

    /// Draw lines for each bone in the skeleton.
    /// Params:
    ///     buffer = Optional matrix buffer for the function to operate on. Can be specified to prevent memory
    ///         allocation on subsequent calls to this function.
    void drawBoneLines() const {

        auto buffer = new Matrix[bones.length];
        drawBoneLines(buffer);

    }

    /// ditto
    void drawBoneLines(Matrix[] buffer) const @trusted
    in (buffer.length == bones.length, "Buffer length must equal bone count")
    do {

        size_t i;

        globalMatrices(buffer, (matrix) @trusted {

            scope (success) i++;

            matrix = MatrixMultiply(matrix, properties.transform);

            const start = Vector3().Vector3Transform(matrix);
            const end = bones[i].vector.Vector3Transform(matrix);

            DrawCylinderEx(start, end, 0.03, 0.03, 3, boneColor(i));

        });

    }

    /// Draw normals for each bone.
    void drawBoneNormals(Matrix[] buffer) const @trusted
    in (buffer.length == bones.length, "Buffer length must equal bone count")
    do {

        size_t i;

        globalMatrices(buffer, (matrix) @trusted {

            scope (success) i++;

            matrix = mul(
                MatrixTranslate(Vector3Divide(bones[i].vector, Vector3(2, 2, 2)).tupleof),
                matrix,
                properties.transform,
            );

            const start = Vector3().Vector3Transform(matrix);
            const end = Vector3(0, 0, -0.1).Vector3Transform(matrix);

            DrawCylinderEx(start, end, 0.02, 0.02, 3, boneColor(i, 0.4));

        });

    }

    /// Get a representative color for the bone based on its index. Useful for debugging.
    static Color boneColor(size_t i, float saturation = 0.6, float value = 0.9) @trusted

        => ColorFromHSV(i * 35 % 360, saturation, value);

}

struct BoneType {

    ulong typeID;

}

struct BoneUV {

    RectangleI[] boneAreas;

    /// Get random bone variant within the UV.
    RectangleI getBone(ulong seed) const {

        import std.random;

        auto rng = Mt19937_64(seed);

        return boneAreas[].choice(rng);

    }

}

struct Bone {

    const size_t index;
    BoneType type;
    const(Bone)* parent;
    Matrix transform;
    Vector3 vector;

}

/// Polyfill from Raylib master branch
private float Vector3Angle(Vector3 v1, Vector3 v2) @nogc pure {

    float result = 0.0f;

    auto cross = Vector3(v1.y*v2.z - v1.z*v2.y, v1.z*v2.x - v1.x*v2.z, v1.x*v2.y - v1.y*v2.x);
    float len = sqrt(cross.x*cross.x + cross.y*cross.y + cross.z*cross.z);
    float dot = (v1.x*v2.x + v1.y*v2.y + v1.z*v2.z);
    result = atan2(len, dot);

    return result;

}
