module isodi.raylib.bind;

import raylib;

import isodi.bind;
import isodi.raylib.internal;

/// Raylib bindings for Isodi.
class RaylibBinds : Bindings {

    mixin Bindings.Register!RaylibBinds;

    /// Underlying raylib camera.
    raylib.Camera camera;

    ///
    this() {

        // Set default parameters for the camera
        camera.target = Vector3(0, 0, 0);
        camera.position = Vector3(50, 50, 50);
        camera.fovy = 50;
        camera.type = CameraType.CAMERA_ORTHOGRAPHIC;

    }

    /// Logging implementation. Simply wraps `writeln` and, on Posix platforms, add ANSI escape codes.
    void log(string text, LogType type) {

        import std.stdio : writeln;
        import std.format : format;

        text.colorText(type).writeln;

    }

    /// Create a display.
    Display createDisplay() {

        import isodi.raylib.display : RaylibDisplay;
        return new RaylibDisplay;

    }

}
