module isodi.raylib.resources.bone;

import raylib;

import std.meta;
import std.math;
import std.math : PI;
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

    // Translation matrixes and related data for this bone.
    public {

        /// Matrix corresponding to the bone start.
        Matrix boneStart;

        /// Matrix corresponding to the bone end.
        ///
        /// Children will inherit their `boneStart` matrixes from this property.
        Matrix boneEnd;

        /// Local rotation of this bone, in radians.
        Vector3 boneRotation;

        /// Global rotation of the bone.
        private Vector3 globalRotation;

    }

    // Other data
    private {

        /// If true, this node has a parent
        bool hasParent;

        /// Scale to be applied to textures.
        float scale;

        /// Width of a single angle on the texture atlas.
        uint atlasWidth;

        /// Texture of the bone.
        Texture2D texture;

        /// Options of the resource.
        const(ResourceOptions)* options;

    }

    /// Create the bone and load resources.
    this(RaylibModel model, SkeletonNode node, Pack.Resource!string resource) {

        // Set parameters
        this.model = model;
        this.node  = node;

        // Ignore the rest if not displaying
        if (node.hidden) return;

        // Load the texture
        this.texture = LoadTexture(resource.match.toStringz);
        this.options = resource.options;

        // Get the scale
        this.scale = cast(float) model.display.cellSize / options.tileSize;
        this.atlasWidth = texture.width / options.angles;

        // Check if this node has a parent
        this.hasParent = cast(bool) model.bones.length;

    }

    ///
    void draw() const {

        // Ignore if not displaying
        if (node.hidden) return;

        rlPushMatrix();

            import std.conv : to;

            // Get the current atlas frame
            const rotationY = (2*360 - globalRotation.y * 180/PI - model.display.camera.angle.x);
            const frameDelimiter = 360.0 / options.angles;
            const atlasFrame = (rotationY / frameDelimiter + 0.5).to!uint % options.angles;

            /// Scale for mirroring
            const mirrorScale = node.mirror ? -1 : 1;

            /// Get the matrix
            auto matrixf = localMatrix(atlasFrame).MatrixToFloat;

            // Apply the matrix
            rlMultMatrixf(&matrixf[0]);

            // Scale appropriately
            rlScalef(scale, scale, scale);

            // Snap to frame
            rlRotatef(-cast(int)atlasFrame * frameDelimiter, 0, 1, 0);

            // Push a matrix if debugging bones
            static if (BoneDebug) rlPushMatrix();

            // Translate the texture
            rlTranslatef(
                node.texturePosition[0],
                node.texturePosition[1],
                node.texturePosition[2] + 1,
            );

            // Check for mirroring
            const textureFrame = node.mirror ? options.angles - atlasFrame : atlasFrame;

            // Draw the texture
            texture.DrawTextureRec(
                Rectangle(
                    atlasWidth * textureFrame, 0,
                    mirrorScale * cast(int) atlasWidth, texture.height
                ),
                Vector2(),
                Colors.WHITE
            );

            // Draw debug points
            static if (BoneDebug) {

                // Draw texture debug
                DrawCircle3D(
                    Vector3(0, 0, -1), 0.2,
                    Vector3(), 1,
                    Colors.BLUE
                );

                // Remove texture transform
                rlPopMatrix();

                // Draw node debug
                DrawCircle3D(
                    Vector3(0, 0, 0), 0.4,
                    Vector3(), 1,
                    Colors.GREEN
                );

            }

        rlPopMatrix();

    }

    /// Get local matrix for bone start.
    ///
    /// Params:
    ///     atlasFrame = Current atlas frame of the texture.
    private Matrix localMatrix(float atlasFrame) const {

        immutable rad = std.math.PI / 180;

        const camAngle = model.display.camera.angle;
        return boneStart.mult(

            // Negate camera vertical rotation
            MatrixRotateY(camAngle.x * rad),
            MatrixRotateX(camAngle.y * rad),
            MatrixRotateY(-camAngle.x * rad),

            // Move to the tile
            MatrixTranslate(
                model.position.toTuple3(model.display.cellSize, Yes.center).expand
            )

        );

    }

    /// Calculate matrixes for this node.
    void updateMatrixes() {

        // If there is a parent
        if (hasParent) {

            // Inherit start from parent
            const parent = model.bones[node.parent];
            boneStart = parent.boneEnd;
            globalRotation = parent.globalRotation;

        }

        // For the root, create an identity matrix
        else boneStart = MatrixIdentity;

        /// Prepare a scale matrix based on bone position
        Matrix boneTranslate(float[3] array) const {

            return MatrixTranslate(
                array[0] * scale,
                array[1] * scale,
                array[2] * scale,
            );

        }

        // Calculate points
        boneStart = mult(
            MatrixRotateXYZ(boneRotation),
            boneTranslate(node.boneStart),
            boneStart,
        );
        boneEnd = mult(
            boneTranslate(node.boneEnd),
            boneStart,
        );
        globalRotation = Vector3Add(globalRotation, boneRotation);

    }

}

/// Multiply matrixes.
private Matrix mult(Matrix[] matrixes...) {

    auto result = MatrixIdentity;
    foreach (matrix; matrixes) {

        result = MatrixMultiply(result, matrix);

    }

    return result;

}
