///
module isodi.raylib.display;

import std.conv;
import std.math;
import std.typecons;
import std.container;

import raylib;

import isodi.bind;
import isodi.display;
import isodi.position;
import isodi.resource;
import isodi.raylib.cell;
import isodi.raylib.anchor;
import isodi.raylib.internal;

///
final class RaylibDisplay : Display {

    /// Underlying raylib camera.
    private raylib.Camera raycam;

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

    }

    /// Draw the contents of the display.
    ///
    /// Must be called inside `DrawingMode`, but not `BeginMode3D`.
    void draw() {

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

        // Draw
        BeginMode3D(raycam);

            rlOrtho(0, 1, 1, 0, 0.1, 10_000);
            foreach (cell; cells) cell.draw();
            foreach (anchor; anchors) anchor.to!RaylibAnchor.draw();

        EndMode3D();

    }

    /// Add a Raylib anchor. See `isodi.Anchor` for reference.
    /// Params:
    ///     callback = Function that will be called every frame in order to draw the anchor content.
    /// Returns: The created anchor
    Anchor addAnchor(void delegate() callback) {

        auto anchor = super.addAnchor();
        anchor.to!RaylibAnchor.draw = callback;
        return anchor;

    }

}
