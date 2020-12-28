module isodi.raylib.display;

import std.conv;
import std.container;

import raylib;

import isodi.bind;
import isodi.cell;
import isodi.display;
import isodi.resource;
import isodi.raylib.cell;

///
final class RaylibDisplay : Display {

    /// Underlying raylib camera.
    ///
    /// Changes to this structs are likely to be overriden when changing properties of the main camera.
    raylib.Camera camera;

    ///
    this() {

        // Set default parameters for the camera
        const fovy = 100;
        camera.fovy = fovy;
        camera.target = Vector3(0.0, 0.0, 0.0);
        camera.position = camera.target + fovy;
        camera.up = Vector3(0.0, 1.0, 0.0);
        camera.type = CameraType.CAMERA_ORTHOGRAPHIC;

    }

    override void reloadResources() {

        foreach (cell; cells) cell.reload();

    }

    /// Draw the contents of the display.
    ///
    /// Must be called inside `DrawingMode`, but not `BeginMode3D`.
    void draw() {

        BeginMode3D(camera);

            ortho();
            foreach (cell; cells) cell.draw();

        EndMode3D();

    }

    /// Apply orthographic transfrom to match the one applied within Isodi's `draw` call.
    void ortho() {

        // TODO: Remove this from public once anchors are implemented.

        rlOrtho(0, 10, 10, 0, 0.1, 10_000);

    }

}
