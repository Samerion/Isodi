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

    /// Owner object.
    RaylibModel model;

    /// Skeleton node represented by this bone.
    SkeletonNode node;

    /// Scale to be applied to textures.
    float scale;

    /// Offset calculated based on the parent node.
    Vector3 offset;

    /// Texture of the bone.
    Texture2D texture;

    /// Options of the resource.
    const(ResourceOptions)* options;

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

        // Get the offset from parent
        if (model.bones.length) {

            offset = model.bones[node.parent].offset;

        }

        // Load by custom offset
        offset.x -= node.position[0];
        offset.y -= node.position[1];
        offset.z -= node.position[2];

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
            //rlRotatef(display.camera.angle.x, 0, 1, 0);
            //rlRotatef(-camAngle.x, 0, 0, 1);
            rlRotatef(camAngle.x, 0, 1, 0);
            rlRotatef(-camAngle.y, 1, 0, 0);
            rlRotatef(-camAngle.x, 0, 1, 0);

            // Center before rotating
            rlTranslatef(atlasWidth/-2.0, -texture.height, 0);

            // Set the offset
            rlTranslatef(offset.x, offset.y, offset.z + 1);

            // Draw the texture
            texture.DrawTextureRec(
                Rectangle(
                    atlasWidth * angle, 0,
                    atlasWidth, texture.height
                ),
                Vector2(),
                Colors.WHITE
            );

        rlPopMatrix();

    }

}
