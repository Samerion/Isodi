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


@safe:


/// A bone resource.
struct Bone {

    // Data
    public {

        /// Owner object.
        RaylibModel model;

        /// Skeleton node represented by this bone.
        SkeletonNode node;

        /// If true, the bone has individual bone debugging enabled.
        bool boneDebug;

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

        /// Original scale of the texture.
        float originalScale;

        /// Scale to be applied to textures.
        float scale = 1;

        /// Width of a single angle on the texture atlas.
        uint atlasWidth;

        /// Texture of the bone.
        Texture2D texture;

        /// Options of the resource.
        const(ResourceOptions)* options;

    }

    /// Create the bone and load resources.
    this(RaylibModel model, bool hasParent, SkeletonNode node, Pack.Resource!string resource) {

        // Set parameters
        this.model = model;
        this.node  = node;

        // Ignore the rest if not displaying
        if (node.hidden) return;

        // Load the texture
        this.texture = model.display.loadTexture(resource.match);
        this.options = resource.options;

        // Get the scale
        this.scale = cast(float) model.display.cellSize / options.tileSize;
        this.originalScale = this.scale;
        this.atlasWidth = texture.width / options.angles;

        // Check if this node has a parent
        this.hasParent = hasParent;

    }

    @property {

        /// Scale applied to this bone.
        float boneScale() const {

            return scale / originalScale;

        }

        /// Ditto
        float boneScale(float value) {

            return scale = originalScale * value;

        }

    }

    ///
    void draw() const @trusted {

        // Ignore if not displaying
        if (node.hidden) return;

        rlPushMatrix();
        scope (exit) rlPopMatrix();

        // Get frame to display
        const frame = atlasFrame();

        // Apply transforms for this bone
        applyBoneTranslate(frame, false);
        applyBoneRotation(frame);

        // Translate the texture
        rlTranslatef(
            node.texturePosition[0],
            node.texturePosition[1] - texture.height,
            node.texturePosition[2] + 1,
        );

        // Check for mirroring
        const textureFrame = node.mirror ? frame : options.angles - frame;

        // Draw the texture
        texture.DrawTextureRec(
            Rectangle(
                atlasWidth * textureFrame, 0,
                -mirrorScale * cast(int) atlasWidth, -texture.height
            ),
            Vector2(),
            Colors.WHITE
        );

    }

    void drawDebug() const @trusted {

        // Ignore if not displaying
        if (node.hidden) return;

        const frame = atlasFrame();

        // Start
        {

            rlPushMatrix();
            scope (exit) rlPopMatrix();

            // Apply transforms for this bone
            applyBoneTranslate(frame, false);

            // Draw debug points if debugging bones
            auto end = Vector3(node.boneEnd[0], node.boneEnd[1], node.boneEnd[2]);

            // Draw a line from here to bone end
            DrawLine3D(Vector3(0, 0, 0), end, Colors.ORANGE);

            // Apply frame rotation now
            applyBoneRotation(frame);

            // Draw node start debug
            DrawCircle3D(
                Vector3(0, 0, 0), 0.4,
                Vector3(), 0,
                Colors.GREEN
            );

            // Translate the texture
            rlTranslatef(
                node.texturePosition[0] + 1,
                node.texturePosition[1] - texture.height,
                node.texturePosition[2],
            );

            // Draw texture debug
            DrawCircle3D(
                Vector3(0, 0, 0), 0.2,
                Vector3(), 0,
                Colors.BLUE
            );

        }

        // End
        {

            rlPushMatrix();
            scope (exit) rlPopMatrix();

            // Move to node end
            applyBoneTranslate(frame, true);
            applyBoneRotation(frame);

            // Draw that transform
            DrawCircle3D(
                Vector3(0, 0, 0), 0.4,
                Vector3(), 0,
                Colors.RED
            );

        }

    }

    /// Get current textue part/angle to display.
    private uint atlasFrame() const {

        import std.conv : to;

        // Get camera options
        const rotationY = 360 - model.display.camera.angle.x;
        const frameDelimiter = 360.0 / options.angles;

        return to!uint(rotationY / frameDelimiter + 0.5 + 1e-7) % options.angles;

    }

    private void applyBoneTranslate(uint frame, bool end) const @trusted {

        /// Get the matrix
        auto matrixf = localMatrix(frame, end).MatrixToFloat;

        // Apply the matrix
        rlMultMatrixf(matrixf.ptr);

        // Scale appropriately
        rlScalef(scale, scale, scale);

    }

    private void applyBoneRotation(uint frame) const {

        // Snap to frame
        frameSnap(frame, 360.0 / options.angles);

    }

    /// Get local matrix for bone start.
    ///
    /// Params:
    ///     atlasFrame = Current atlas frame of the texture.
    private Matrix localMatrix(float atlasFrame, bool end) const @trusted {

        immutable rad = std.math.PI / 180;

        const camAngle = model.display.camera.angle;
        const start = end
            ? boneEnd
            : boneStart;

        return mult(

            // Move the bone to its position in the model
            start,

            // Negate camera vertical rotation
            MatrixRotateY(camAngle.x * rad),
            MatrixRotateX(camAngle.y * rad),
            MatrixRotateY(-camAngle.x * rad),

            // Move to the tile
            MatrixTranslate(
                model.visualPosition.toTuple3(model.display.cellSize, CellPoint.center).expand
            )

        );

    }

    /// Returns -1 if mirroring, -1 if not.
    private int mirrorScale() const {

        return node.mirror ? -1 : 1;

    }

    private void frameSnap(float atlasFrame, float frameDelimiter) const @trusted {

        // Note: still requires more testing, especially for models with more than 4 angles

        const snapAngle = cast(int) atlasFrame * frameDelimiter;

        // Rounding for floating point precision
        const piAbove = PI_2 + 1e-6;
        const piBelow = PI_2 - 1e-6;

        // Bone is above 90°
        if (globalRotation.x >= piAbove || globalRotation.z > piAbove) {

            rlRotatef(snapAngle, 0, 1, 0);

        }

        // Bone is exactly on 90°
        else if (globalRotation.x >= piBelow || globalRotation.z >= piBelow) {

            // TODO, both cases would probably be different

        }

        // Bone is below
        else {

            rlRotatef(180 - snapAngle, 0, 1, 0);

        }

    }

    /// Calculate matrixes for this node.
    void updateMatrixes() @trusted {

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

        const PI2 = PI * 2;

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
        globalRotation = Vector3(
            (globalRotation.x + boneRotation.x) % PI2,
            (globalRotation.y + boneRotation.y) % PI2,
            (globalRotation.z + boneRotation.z) % PI2,
        );

    }

}

/// Multiply matrixes.
private Matrix mult(Matrix[] matrixes...) @trusted {

    auto result = MatrixIdentity;
    foreach (matrix; matrixes) {

        result = MatrixMultiply(result, matrix);

    }

    return result;

}
