///
module isodi.raylib.display;

import std.conv;
import std.math;
import std.typecons;
import std.container;

import raylib;

import isodi.bind;
import isodi.cell;
import isodi.display;
import isodi.position;
import isodi.resource;
import isodi.raylib.cell;
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
        const target = camera.follow is null
            ? Position()
            : camera.follow.position;

        // Update the camera
        // not sure how to get the correct fovy from distance, this is just close to the expected result.
        // TODO: figure it out.
        raycam.fovy = camera.distance * cellSize;
        raycam.target = target.toVector3(cellSize, Yes.center);
        raycam.position = raycam.target + Vector3(
            radX.sin * cosY,
            radY.sin,
            radX.cos * cosY,
        ) * camera.distance;

        // Draw
        BeginMode3D(raycam);

            ortho();
            foreach (cell; cells) cell.draw();

        EndMode3D();

    }

    /// Apply orthographic transfrom to match the one applied within Isodi's `draw` call.
    void ortho() {

        // TODO: Remove this from public once anchors are implemented.
        rlOrtho(0, 1, 1, 0, 0.1, 10_000);

    }

}
