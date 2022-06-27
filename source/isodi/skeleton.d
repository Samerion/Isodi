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
    IsodiModel makeModel(return Texture2D texture) const @trusted {

        const atlasSize = Vector2(texture.width, texture.height);

        // Model data
        const vertexCount = bones.length * 4;
        const triangleCount = bones.length * 2;

        // Create a model
        IsodiModel model = {
            properties: properties,
            texture: texture,
            flatten: true,
        };
        model.vertices.reserve = vertexCount;
        model.variants.length = vertexCount;
        model.texcoords.reserve = vertexCount;
        model.normals.length = vertexCount;
        model.anchors.reserve = vertexCount;
        model.triangles.reserve = triangleCount;

        // Copy the bones and apply all the transformations
        auto transBones = bones[].dup;

        // Add each bone
        foreach (i, ref bone; transBones) with (model) {

            const boneUV = bone.type in atlas;
            assert(boneUV, format!"%s not present in skeleton atlas"(bone));

            // Get the variant
            auto boneVariant = boneUV.getBone(seed + i).toShader(atlasSize);
            boneVariant.width /= 4;  // TODO

            // Get the size of the bone
            Vector2 boneSize;
            boneSize.y = Vector3Length(bone.vector);
            boneSize.x = boneSize.y * boneVariant.width / boneVariant.height;

            /// Matrix for the start of the bone
            Matrix startMatrix = bone.transform;

            // Inherit transform
            if (bone.parent) {

                // Get the parent bone
                const parent = transBones[bone.parent.index];

                // Inherit parent's transform
                startMatrix = MatrixMultiply(startMatrix, parent.transform);

            }

            /// Matrix for getting the other end of the bone
            const toEnd = MatrixTranslate(bone.vector.tupleof);

            /// Matrix for the end of the bone
            bone.transform = mul(toEnd, startMatrix);

            bool invertX, invertY;

            Vector3 makeVertex(bool start, int sign, bool adjust = false) {

                // Revert start and left, if needed, to make the bone face the right direction
                if (!adjust) {
                    sign  *= invertX ? -1 : 1;
                    start ^= invertY;
                }

                /// Matrix to adjust the horizontal position of the vertex
                const translation = MatrixTranslate(sign * boneSize.x / 2, 0, 0);

                /// Matrix to move to the start point of the bone
                const toStart = startMatrix;

                /// Final matrix
                const matrix = start
                    ? mul(translation, toStart)
                    : mul(toEnd, translation, toStart);

                return Vector3().Vector3Transform(matrix);

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

            // Normals
            normals.assign(i, 4, Vector3(0, 1, 0).Vector3Transform(normalMatrix));

            Vector2 anchor(bool start) {
                return Vector2(
                    makeVertex(start, 0).x.round,
                    makeVertex(start, 0).z.round,
                );
            }

            // Anchors
            anchors ~= [
                anchor(false),
                anchor(false),
                anchor(true),
                anchor(true),
            ];

            // Variants
            variants.assign(i, 4, boneVariant);

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

}

struct BoneType {

    ulong typeID;

}

struct BoneUV {

    RectangleL[] boneAreas;

    /// Get random bone variant within the UV.
    RectangleL getBone(ulong seed) const {

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
