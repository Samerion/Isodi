/// Optional helper utility for managing the camera.
module isodi.camera;

import raylib;

import std.conv;
import std.math;
import std.meta;
import std.traits;

private alias PI = std.math.PI;


@safe:


// Helper UDAs for metaprogramming
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

    @Affects!"yaw" {

        /// Rotate the camera around the Y axis clockwise.
        @Change!(-1)
        KeyboardKey rotateRight;

        /// Rotate the camera around the Y axis counter-clockwise.
        @Change!(+1)
        KeyboardKey rotateLeft;

    }

    @Affects!"pitch" {

        /// Pitch the camera down.
        @Change!(-1)
        KeyboardKey rotateDown;

        /// Pitch the camera up.
        @Change!(+1)
        KeyboardKey rotateUp;

    }

    @Affects!"offsetScreenX" {

        /// Move the camera towards negative X.
        @Change!(-1)
        KeyboardKey moveWest;

        /// Move the camera towards positive X.
        @Change!(+1)
        KeyboardKey moveEast;

    }

    @Affects!"offsetScreenZ" {

        /// Move the camera towards positive Z.
        @Change!(+1)
        KeyboardKey moveSouth;

        /// Move the camera towards negative Z.
        @Change!(-1)
        KeyboardKey moveNorth;

    }

    @Affects!"offset.y" {

        /// Move the camera downwards.
        @Change!(-1)
        KeyboardKey moveDown;

        /// Move the camera upwards.
        @Change!(+1)
        KeyboardKey moveUp;

    }

    @Speed {

        /// Zoom speed, cell per second.
        @Affects!"distance"
        float zoomSpeed = 15;

        /// Rotation speed, radians per second.
        @Affects!"yaw"
        @Affects!"pitch"
        float rotateSpeed = PI_2;

        /// Movement speed, cells per second.
        @Affects!"offsetScreenX"
        @Affects!"offsetScreenZ"
        @Affects!"offset.y"
        float movementSpeed = 4;

    }

    /// Maximum zoom in.
    float zoomInLimit = 5;

    /// Maximum zoom out. This should be greater than `zoomInLimit`.
    float zoomOutLimit = 50;

}

struct CameraController {

    /// Camera yaw.
    float yaw = PI_4;

    /// Camera pitch.
    ///
    /// Must be between 0° (side view) and 90° (top-down), defaults to 45°
    float pitch = PI_4;

    /// Convience function to determine the camera's position.
    ///
    /// This can be null. If so, follows position (0, 0, 0).
    Vector3 delegate() @safe follow;

    /// Distance between the camera and the followed object.
    float distance = 15;

    /// Distance to FOV ratio, used to correct projection parameters.
    float distanceFOVRatio = 5;

    /// Offset between camera and the followed object.
    Vector3 offset;

    /// Change the offset relative to the screen
    void offsetScreenX(float value) {

        offset.x += value * yaw.cos;
        offset.z += value * yaw.sin;

    }

    /// Change the offset relative to the screen
    void offsetScreenZ(float value) {

        offset.x += value * yaw.sin;
        offset.z += value * yaw.cos;

    }

    /// Get input and update the camera.
    void update(CameraKeybindings keybinds, ref Camera camera) {

        input(keybinds);
        output(camera);

    }

    /// ditto
    Camera update(CameraKeybindings keybinds) {

        Camera camera = {
            up: Vector3(0, 1, 0),
            projection: CameraProjection.CAMERA_ORTHOGRAPHIC,
        };

        update(keybinds, camera);

        return camera;

    }

    /// Move the camera using bound keys.
    void input(CameraKeybindings keybinds) @trusted {

        alias SpeedFields = getSymbolsByUDA!(CameraKeybindings, Speed);

        const delta = GetFrameTime();

        // Check each field
        static foreach (actionName; FieldNameTuple!CameraKeybindings) {{

            alias BindField = mixin("CameraKeybindings." ~ actionName);

            // This is a key field
            static if (hasUDA!(BindField, Change)) {

                alias ChangeDeco = getUDAs!(BindField, Change)[0];
                enum direction = ChangeDeco.value;

                // Pressed
                if (mixin("keybinds." ~ actionName).IsKeyDown) {

                    // Get the affected field
                    alias AffectDeco = getUDAs!(BindField, Affects)[0];
                    enum controllerField = "this." ~ AffectDeco.name;
                    alias ControllerField = typeof(mixin(controllerField));

                    // Get the speed field for the deco
                    alias HasAffectDeco = ApplyRight!(hasUDA, AffectDeco);
                    alias speedSymbol = Filter!(HasAffectDeco, SpeedFields)[0];
                    enum speedField = __traits(identifier, speedSymbol);

                    // Get the total change
                    const change = direction * delta * mixin("keybinds." ~ speedField);

                    // Check if the given type is a field or property
                    enum IsField(alias T) = !isFunction!T || functionAttributes!T & FunctionAttribute.property;

                    // If so
                    static if (IsField!(mixin(controllerField))) {

                        import std.algorithm : clamp;

                        // Get the new value
                        auto newValue = mixin(controllerField) + change;

                        // Clamp camera distance
                        static if (AffectDeco.name == "distance") {

                            newValue = newValue.clamp(keybinds.zoomInLimit, keybinds.zoomOutLimit);

                        }

                        // Update the field
                        mixin(controllerField) = newValue;

                    }

                    // Call the function otherwise
                    else mixin(controllerField)(change);

                }

            }

        }}

    }

    /// Update the camera based on controller data.
    void output(ref Camera camera) const {

        // Calculate the target
        const target = follow is null
            ? Vector3()
            : follow();

        // Update the camera
        // not sure how to get the correct fovy from distance, this is just close to the expected result.
        // TODO: figure it out.
        camera.fovy = distance;

        // Get the target
        camera.target = target + offset;

        // And place the camera
        camera.position = camera.target + Vector3(
            pitch.cos * yaw.sin,
            pitch.sin,
            pitch.cos * yaw.cos,
        ) * (distance * distanceFOVRatio);

    }

}
