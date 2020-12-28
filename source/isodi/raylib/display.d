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
        camera.target = Vector3(200.0, 0.0, 100.0);
        camera.position = camera.target + fovy;
        camera.up = Vector3(0.0, 1.0, 0.0);
        camera.type = CameraType.CAMERA_ORTHOGRAPHIC;

    }

    override void reloadResources() {

        foreach (cell; cells) cell.reload(packs);

    }

    /// Draw the contents of the display.
    ///
    /// Must be called inside DrawingMode.
    void draw() {

        foreach (cell; cells) cell.draw();

    }

}
