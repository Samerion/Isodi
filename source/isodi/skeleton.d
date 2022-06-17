module isodi.skeleton;

import raylib;

import std.array;
import std.format;
import std.algorithm;

import isodi.utils;
import isodi.properties;
import isodi.isodi_model;


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

        // Create an empty model (for now)
        IsodiModel model = {
            properties: properties,
            texture: texture,
        };
        model.vertices.reserve = vertexCount;
        model.variants.length = vertexCount;
        model.texcoords.reserve = vertexCount;
        model.normals.length = vertexCount;
        model.anchors.length = vertexCount;
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

            import std.stdio;
            float[4] f = (cast(float[4]) boneVariant)[] * atlasSize.x;
            writefln!"%s"(f);

            // Get the size of the bone
            Vector2 boneSize;
            boneSize.y = Vector3Length(bone.vector);
            boneSize.x = boneSize.y * boneVariant.width / boneVariant.height;
            writefln!"%s %s %s %s"(
                Vector3(-boneSize.x/2, 0, 0).Vector3Transform(bone.transform),
                Vector3(+boneSize.x/2, 0, 0).Vector3Transform(bone.transform),
                Vector3(+boneSize.x/2, boneSize.y, 0).Vector3Transform(bone.transform),
                Vector3(-boneSize.x/2, boneSize.y, 0).Vector3Transform(bone.transform),
            );

            // Inherit transform
            if (bone.parent) {

                // Get the parent bone
                const parent = transBones[bone.parent.index];

                // Apply its transform
                bone.transform = MatrixMultiply(parent.transform, bone.transform);

            }

            // Vertices
            vertices ~= [
                Vector3(-boneSize.x/2, boneSize.y, 0).Vector3Transform(bone.transform),
                Vector3(+boneSize.x/2, boneSize.y, 0).Vector3Transform(bone.transform),
                Vector3(+boneSize.x/2, 0, 0).Vector3Transform(bone.transform),
                Vector3(-boneSize.x/2, 0, 0).Vector3Transform(bone.transform),
            ];

            // UVs
            texcoords ~= [
                Vector2(0, 0),
                Vector2(1, 0),
                Vector2(1, 1),
                Vector2(0, 1),
            ];

            const normalMatrix = MatrixMultiply(
                MatrixRotate(Vector3(-1, 0, 0), PI / 2),
                bone.transform,
            );

            // Normals
            normals.assign(i, 4, Vector3(0, 1, 0).Vector3Transform(normalMatrix));

            // Anchors
            const anchor = Vector3(0, 0, 0).Vector3Transform(bone.transform);
            anchors.assign(i, 4, Vector2(anchor.x, anchor.z));

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

    /// Draw lines for each bone to visualise the skeleton.
    void drawDebug() @trusted {

        /// Copy the bones and apply all the transformations.
        auto transBones = bones[].dup;

        // Add each bone
        foreach (i, ref bone; transBones) {

            // Inherit transform
            Matrix parentTransform = bone.parent
                ? transBones[bone.parent.index].transform
                : properties.transform;

            bone.transform = MatrixMultiply(parentTransform, bone.transform);

            DrawLine3D(
                Vector3Transform(Vector3(), bone.transform),
                Vector3Transform(bone.vector, bone.transform),
                Colors.RED,
            );

        }

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
