module isodi.raylib.resources.bone;

import raylib;

import std.math;
import std.string;
import std.random;

import isodi.pack;
import isodi.model;
import isodi.resource;
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

        // If there is a parent
        if (model.bones.length) {

            // Inherit start from parent
            boneStart = model.bones[node.parent].boneEnd;
        }

        // Calculate points
        boneStart = boneStart + toVector3(node.boneStart);
        boneEnd = boneStart + toVector3(node.boneEnd);

    }

    ///
    void draw() const {

        // Ignore if not displaying
        if (node.hidden) return;

        import std.conv : to;

        rlPushMatrix();

            const display = model.display;
            const atlasWidth = texture.width / options.angles;

            /// Scale for mirroring
            const mirrorScale = node.mirror ? -1 : 1;

            // Get the node's rotation
            const rotation = node.rotation + 360-display.camera.angle.x;
            const angleDelimiter = 360.0 / options.angles;

            // Convert to angle
            const rotationAngle = rotation / angleDelimiter;
            const int angleTransform = (rotationAngle + options.angles + 0.5).abs.to!int % options.angles;
            const int angle = (rotationAngle * mirrorScale + options.angles + 0.5).abs.to!int % options.angles;

            // Move to the correct tile
            rlTranslatef(model.position.toTuple3(display.cellSize, Yes.center).expand);

            // Scale to fit
            rlScalef(scale, scale, scale);

            // Rotate to counter the camera
            const camAngle = display.camera.angle;
            rlRotatef(camAngle.x, 0, 1, 0);
            rlRotatef(-camAngle.y, 1, 0, 0);
            rlRotatef(-camAngle.x, 0, 1, 0);

            rlPushMatrix();

                // Offset the bone start
                translateVec(boneStart);

                // Rotate to match angle
                rlRotatef(-angleTransform * angleDelimiter, 0, 1, 0);

                rlPushMatrix();

                    // Offset the texture
                    translateVec(toVector3(node.texturePosition));

                    // Correct translation
                    rlTranslatef(0, 0, 1);

                    // Draw the texture
                    texture.DrawTextureRec(
                        Rectangle(
                            atlasWidth * angle, 0,
                            mirrorScale * cast(int) atlasWidth, texture.height
                        ),
                        Vector2(),
                        Colors.WHITE
                    );

                    // Debug: texturePosition
                    static if (BoneDebug)
                    DrawCircle3D(
                        Vector3(0, 0, -1), 0.2,
                        Vector3(), 1,
                        Colors.BLUE
                    );

                rlPopMatrix();

                // Debug: boneStart
                static if (BoneDebug)
                DrawCircle3D(
                    Vector3(0, 0, 0), 0.4,
                    Vector3(), 1,
                    Colors.GREEN
                );

            rlPopMatrix();

            // Debug: boneEnd
            static if (BoneDebug) {

                rlPushMatrix();

                    translateVec(boneEnd);
                    rlRotatef(-angleTransform * angleDelimiter, 0, 1, 0);

                    DrawCircle3D(
                        Vector3(0, 0, 0), 0.4,
                        Vector3(), 1,
                        Colors.RED
                    );

                rlPopMatrix();

            }

        rlPopMatrix();

    }

    private Vector3 toVector3(float[3] array) const {

        return Vector3(
            array[0],
            array[1],
            array[2],
        );

    }

    private void translateVec(Vector3 vec) const {

        rlTranslatef(vec.x, vec.y, vec.z);

    }

}
