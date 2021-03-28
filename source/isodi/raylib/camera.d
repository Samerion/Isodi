///
module isodi.raylib.camera;

import std.conv;
import std.meta;
import std.traits;

import raylib;

import isodi.camera;
import isodi.object3d;

private {

    struct Affects(string what) {
        static immutable name = what;
    }
    struct Change(short by) {
        static immutable value = by;
    }
    enum Speed;

}


/// Keys to connect to camera actions.
struct CameraKeybindings {

    @Affects!"distance" {

        /// Zoom the camera in.
        @Change!(-1)
        KeyboardKey zoomIn;

        /// Zoom the camera out
        @Change!(+1)
        KeyboardKey zoomOut;

    }

    @Affects!"angle.x" {

        /// Rotate the camera clockwise.
        @Change!(-1)
        KeyboardKey rotateLeft;

        /// Rotate the camera counter-clockwise.
        @Change!(+1)
        KeyboardKey rotateRight;

    }

    @Affects!"angle.y" {

        /// Rotate the camera down on the Y axis.
        @Change!(-1)
        KeyboardKey rotateDown;

        /// Rotate the camera up on the Y axis.
        @Change!(+1)
        KeyboardKey rotateUp;

    }

    @Affects!"offsetScreenX" {

        /// Move the camera towards negative X.
        @Change!(-1)
        KeyboardKey moveLeft;

        /// Move the camera towards positive X.
        @Change!(+1)
        KeyboardKey moveRight;

    }

    @Affects!"offsetScreenY" {

        /// Move the camera towards positive Y.
        @Change!(+1)
        KeyboardKey moveDown;

        /// Move the camera towards negative Y.
        @Change!(-1)
        KeyboardKey moveUp;

    }

    @Affects!"offset.height" {

        /// Move the camera downwards.
        @Change!(-1)
        KeyboardKey moveBelow;

        /// Move the camera upwards.
        @Change!(+1)
        KeyboardKey moveAbove;

    }

    @Speed {

        /// Zoom speed, cell per second.
        @Affects!"distance"
        float zoomSpeed = 10;

        /// Rotation speed, degrees per second.
        @Affects!"angle.x"
        @Affects!"angle.y"
        float rotateSpeed = 90;

        /// Movement speed, cells per second.
        @Affects!"offsetScreenX"
        @Affects!"offsetScreenY"
        @Affects!"offset.height"
        float movementSpeed = 4;

    }

    /// Maximum zoom in.
    float zoomInLimit = 5;

    /// Maximum zoom out. This should be greater than `zoomInLimit`.
    float zoomOutLimit = 50;

}

/// Helper for quickly binding keys to freely move the camera.
void updateCamera(ref isodi.camera.Camera camera, CameraKeybindings keybinds) {

    assert(camera.follow !is null,
        "camera.follow must be set for updateCamera to work, and it must use the Object3D.Implement mixin");

    alias SpeedFields = getSymbolsByUDA!(CameraKeybindings, Speed);

    const delta = GetFrameTime();

    // Check each field
    static foreach (actionName; FieldNameTuple!CameraKeybindings) {{

        alias BindField = mixin("CameraKeybindings." ~ actionName);

        // This is a key field
        static if (hasUDA!(BindField, Change)) {

            enum direction = getUDAs!(BindField, Change)[0].value;

            // Pressed
            if (mixin("keybinds." ~ actionName).IsKeyDown) {

                // Get the affected field
                alias AffectDeco = getUDAs!(BindField, Affects)[0];
                enum cameraField = "camera." ~ AffectDeco.name;
                alias CameraField = typeof(mixin(cameraField));

                // Get the speed field for the deco
                alias HasAffectDeco = ApplyRight!(hasUDA, AffectDeco);
                alias speedSymbol = Filter!(HasAffectDeco, SpeedFields)[0];
                enum speedField = __traits(identifier, speedSymbol);

                // Get the total change
                const change = direction * delta * mixin("keybinds." ~ speedField);

                // Check if the given type is a field or property
                enum IsField(alias T) = !isFunction!T || functionAttributes!T & FunctionAttribute.property;

                // If so
                static if (IsField!(mixin(cameraField))) {

                    // Increment the field
                    mixin(cameraField) = mixin(cameraField) + change;

                }

                // Call the function otherwise
                else mixin(cameraField)(change);

            }

        }

    }}

    import std.algorithm : clamp;

    // Update boundaries
    camera.angle.y  = camera.angle.y.clamp(0, 90);
    camera.distance = camera.distance.clamp(keybinds.zoomInLimit, keybinds.zoomOutLimit);

}
