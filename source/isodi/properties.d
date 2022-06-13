module isodi.properties;

import raylib;
import std.math;

import isodi.resources;

private alias PI = std.math.PI;


@safe:


/// Properties used to render the object.
struct Properties {

    /// Number of steps for height — this number of height steps results in height difference equivalent to the distance
    /// between two neighboring blocks (of the same height).
    int heightSteps = 10;

    /// Perspective of the viewer, used to correctly render models and other flat objects.
    const(Perspective)* perspective;

    /// Transform matrix affecting the object.
    Matrix transform = Matrix(
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    );

    /// Resource data to be used by this object.
    ResourceData resources;

    /// Color to modulate the object with.
    Color tint = Colors.WHITE;

}

struct Perspective {

    /// Perspective angles, in radians.
    float angleX, angleY;

    /// Update the perspective based on camera properties.
    void fromCamera(Camera3D camera) {

        const pos = camera.target - camera.position;

        const sine = Vector2(
            pos.x / sqrt(pos.x^^2 + pos.z^^2),
            pos.x / sqrt(pos.x^^2 + pos.y^^2),
        );

        // Set the angles
        angleX = sgn(pos.z) * acos(sine.x) - PI_2;
        angleY = PI_2 - sgn(pos.x) * asin(sine.y);

    }

}

struct ResourceData {

    ResourceLoader loader;

}
