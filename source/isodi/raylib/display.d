///
module isodi.raylib.display;

import std.conv;
import std.math;
import std.typecons;
import std.container;
import std.algorithm;

import raylib;

import isodi.bind;
import isodi.display;
import isodi.object3d;
import isodi.position;
import isodi.resource;
import isodi.raylib.cell;
import isodi.raylib.anchor;
import isodi.raylib.internal;

///
final class RaylibDisplay : Display {

    /// Underlying raylib camera.
    package raylib.Camera raycam;

    ///
    this() {

        // Set camera constants
        raycam.up = Vector3(0.0, 1.0, 0.0);
        raycam.type = CameraType.CAMERA_ORTHOGRAPHIC;

    }

    /// Get the underlying Raylib camera.
    const(raylib.Camera) raylibCamera() {

        return raycam;

    }

    override void reloadResources() {

        foreach (cell; cells) cell.reload();
        foreach (model; models) model.reload();

    }

    /// Draw the contents of the display.
    ///
    /// Must be called inside `DrawingMode`, but not `BeginMode3D`.
    void draw() {

        updateCamera();

        // Draw
        BeginMode3D(raycam);

            import std.array : array;
            import std.range : chain;

            rlOrtho(0, 1, 1, 0, 0.1, 10_000);
            rlDisableDepthTest();

            const rad = camera.angle.x * std.math.PI / 180;

            // Get all 3D objects
            chain(cells, models, anchors)

                // Depth sort
                .map!(a => cameraDistance(a, rad))
                .array
                .sort!((a, b) => a[1] != b[1]
                    ? a[1] > b[1]
                    : a[2] < b[2])

                // Draw them
                .each!(a => a[0].to!WithDrawableResources.draw());

        EndMode3D();

    }

    /// Get the camera distance of given Object3D
    private Tuple!(Object3D, float, float) cameraDistance(Object3D object, real rad) {

        return Tuple!(Object3D, float, float)(
            object,
            object.position.x * sin(rad)
              + object.position.y * cos(rad),
            object.position.height.depth,
        );

    }

    private void updateCamera() {

        const rad = std.math.PI / 180;
        const radX = camera.angle.x * rad;
        const radY = camera.angle.y * rad;
        const cosY = cos(camera.angle.y * rad);

        // Calculate the target
        const target = camera.follow is null
            ? Position()
            : camera.follow.position;
        const targetVector = target.toVector3(cellSize, Yes.center);

        // Update the camera
        // not sure how to get the correct fovy from distance, this is just close to the expected result.
        // TODO: figure it out.
        raycam.fovy = camera.distance * cellSize;

        // Get the target
        raycam.target = Vector3(
            targetVector.x + camera.offset.x * cellSize,
            targetVector.y - camera.offset.height * cellSize,
            targetVector.z + camera.offset.y * cellSize,
        );

        // And place the camera
        raycam.position = raycam.target + Vector3(
            radX.sin * cosY,
            radY.sin,
            radX.cos * cosY,
        ) * camera.distance;

    }

    /// Add a Raylib anchor. See `isodi.Anchor` for reference.
    /// Params:
    ///     callback = Function that will be called every frame in order to draw the anchor content.
    /// Returns: The created anchor
    Anchor addAnchor(void delegate() callback) {

        auto anchor = super.addAnchor();
        anchor.to!RaylibAnchor.callback = callback;
        return anchor;

    }

}
