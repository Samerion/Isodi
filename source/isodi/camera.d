///
module isodi.camera;

import std.math;

import isodi.object3d;

/// Represents a camera, giving a view into the Isodi world.
struct Camera {

    /// Represents the angle the camera is looking at.
    struct Angle {

        private float _x = 0;
        invariant(_x >= 0, "Somehow camera angle X is negative, this shouldn't be possible.");
        invariant(_x < 360, "Somehow camera angle X is >= 360, this shouldn't be possible.");
        invariant(!_x.isNaN, "Camera angle X is NaN, did you forget to initialize a float?");

        /// Y, vertical angle of the camera.
        ///
        /// Must be between 0° (side view) and 90° (top-down), defaults to 45°
        float y = 45;
        invariant(y >= 0, "Camera angle Y must be at least 0°.");
        invariant(y <= 90, "Camera angle Y must be at most 90°.");
        invariant(!y.isNaN, "Camera angle Y is NaN, did you forget to initialize a float?");

        /// X, horizontal angle of the camera.
        ///
        /// Automatically modulated by 360°.
        @property
        float x() { return _x; }

        /// Ditto
        @property
        float x(float value) {

            // Modulate
            value %= 360;

            // Prevent being negative
            if (value < 0) value += 360;

            return _x = value;

        }

    }

    /// Object this camera follows.
    ///
    /// This can be null. If so, follows position (0, 0, 0).
    Object3D follow;

    /// Angle the camera is looking from.
    Angle angle;

}
