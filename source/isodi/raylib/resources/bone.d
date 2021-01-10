module isodi.raylib.resources.bone;

import raylib;

import std.math;
import std.string;
import std.random;

import isodi.pack;
import isodi.model;
import isodi.raylib.model;
import isodi.raylib.internal;

/// A bone resource.
struct Bone {

    /// Enable debugging bone ends
    private enum BoneDebug = false;

    // Data
    public {

        /// Owner object.
        RaylibModel model;

        /// Skeleton node represented by this bone.
        SkeletonNode node;

    }

    // Recursively calculated points, relatively to model start point.
    public {

        /// Bone start position.
        Vector3 boneStart;

        /// Bone end position.
        Vector3 boneEnd;

        /// Position of the texture.
        Vector3 texturePosition;

    }

    // Other data
    public {

        /// Scale to be applied to textures.
        float scale;

        /// Texture of the bone.
        Texture2D texture;

        /// Options of the resource.
        const(ResourceOptions)* options;

    }

    /// Create the bone and load resources.
    this(RaylibModel model, SkeletonNode node) {

        // Set parameters
        this.model = model;
        this.node  = node;

        // Ignore the rest if not displaying
        if (node.hidden) return;

        auto display = model.display;

        // Get the RNG
        Mt19937_64 rng;
        // Seed?

        // Get the texture
        auto glob = display.packs.packGlob(node.name.format!"models/bone/%s/*.png");
        const file = glob.matches.choice(rng);

        // Load the texture
        texture = LoadTexture(file.toStringz);
        options = glob.pack.getOptions(file);

        // Get the scale
        this.scale = cast(float) display.cellSize / options.tileSize;

        Vector3 toVector3(float[3] array) {

            return Vector3(
                array[0],
                array[1],
                array[2],
            );

        }

        // If there is a parent
        if (model.bones.length) {

            // Inherit start from parent
            boneStart = model.bones[node.parent].boneEnd;
        }

        // Calculate points
        boneStart = boneStart + toVector3(node.boneStart);
        boneEnd = boneStart + toVector3(node.boneEnd);
        texturePosition = boneStart + toVector3(node.texturePosition);

    }

    ///
    void draw() {

        // Ignore if not displaying
        if (node.hidden) return;

        rlPushMatrix();

            const angle = 0;
            const atlasWidth = texture.width / options.angles;
            const display = model.display;

            // Center within the tile
            rlTranslatef(display.cellSize/2, 0, display.cellSize/2);

            // Scale to fit
            rlScalef(scale, scale, scale);

            // Rotate to counter the camera
            const camAngle = display.camera.angle;
            rlRotatef(camAngle.x, 0, 1, 0);
            rlRotatef(-camAngle.y, 1, 0, 0);
            rlRotatef(-camAngle.x, 0, 1, 0);

            // Correct translation
            rlTranslatef(0, 0, 1);

            rlPushMatrix();

                // Set the offset
                translateVec(texturePosition);

                // Get the mirror scale
                const mirrorScale = node.mirror ? -1 : 1;

                // Draw the texture
                texture.DrawTextureRec(
                    Rectangle(
                        atlasWidth * angle, 0,
                        mirrorScale * cast(int) atlasWidth, texture.height
                    ),
                    Vector2(),
                    Colors.WHITE
                );

                // Debug
                static if (BoneDebug)
                DrawCircle3D(
                    Vector3(0.1, 0.1, -1), 0.2,
                    Vector3(), 1,
                    Colors.BLUE
                );

            rlPopMatrix();

            static if (BoneDebug) {

                rlPushMatrix();

                    // Draw the bone start position
                    translateVec(boneStart);
                    DrawCircle3D(
                        Vector3(0.2, 0.2, -1), 0.4,
                        Vector3(), 1,
                        Colors.GREEN
                    );

                rlPopMatrix();

                rlPushMatrix();

                    translateVec(boneEnd);
                    DrawCircle3D(
                        Vector3(0.2, 0.2, -1), 0.4,
                        Vector3(), 1,
                        Colors.RED
                    );

                rlPopMatrix();

            }

        rlPopMatrix();

    }

    private void translateVec(Vector3 vec) {

        rlTranslatef(vec.x, vec.y, vec.z);

    }

}
