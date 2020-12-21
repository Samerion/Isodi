module isodi.raylib.display;

import raylib;

import isodi.bind;
import isodi.cell;
import isodi.display;

///
class RaylibDisplay : Display {

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

    /// Draw the contents of the display.
    ///
    /// Must be called inside DrawingMode.
    void draw() {

        // Draw each cell
        foreach (cell; this.cells) drawCell(cell);

    }

    /// Draw the given cell.
    ///
    /// Must be called inside DrawingMode. Prefer `draw` unless you're doing something advanced.
    ///
    /// TODO: Implement this
    void drawCell(Cell cell) { }

}
