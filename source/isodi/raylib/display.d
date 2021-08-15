///
module isodi.raylib.display;

import std.conv;
import std.math;
import std.typecons;
import std.container;
import std.algorithm;

import raylib;

import isodi.bind;
import isodi.display;
import isodi.object3d;
import isodi.position;
import isodi.resource;
import isodi.raylib.cell;
import isodi.raylib.anchor;
import isodi.raylib.internal;


@safe:


///
final class RaylibDisplay : Display {

    /// Underlying raylib camera.
    package raylib.Camera raycam;

    ///
    this() {

        // Set camera constants
        raycam.up = Vector3(0.0, 1.0, 0.0);
        raycam.type = CameraType.CAMERA_ORTHOGRAPHIC;

    }

    /// Get the underlying Raylib camera.
    const(raylib.Camera) raylibCamera() const {

        return raycam;

    }

    override void reloadResources() {

        packs.clearCache();
        foreach (cell; cells) cell.reload();
        foreach (model; models) model.reload();

    }

    /// Get Isodi position from world position.
    /// Params:
    ///     original = Raylib world position.
    Position isodiPosition(Vector3 original) const {

        return position(
            cast(int) floor(original.x / cellSize),
            cast(int) floor(original.z / cellSize),
            Height(original.y / cellSize),
        );

    }

    /// Get a ray from the mouse position relative to the camera.
    /// Params:
    ///     inverted = Shoots the ray behind the camera. It might be useful to check both the normal and inverted ray
    ///         the ray doesn't recognize camera height properly.
    Ray mouseRay(bool inverted) const @trusted {

        auto ray = GetMouseRay(GetMousePosition, raycam);

        if (inverted) {

            ray.direction = Vector3Negate(ray.direction);

        }

        return ray;

    }

    /// Snap a Vector3 with a world position to Isodi.
    Vector3 snapWorldPosition(Vector3 pos) const {

        return Vector3(
            cast(int) pos.x / cellSize * cellSize,
            cast(int) pos.y / cellSize * cellSize,
            cast(int) pos.z / cellSize * cellSize,
        );

    }

    /// Draw the contents of the display.
    ///
    /// Must be called inside `DrawingMode`, but not `BeginMode3D`.
    void draw() @trusted {

        updateCamera();

        // Draw
        BeginMode3D(raycam);
        scope (exit) EndMode3D();

        import std.array : array;
        import std.range : chain;

        rlOrtho(-1, 1, -1, 1, 0.01, cellSize * cellSize);
        rlDisableDepthTest();

        alias PI = std.math.PI;

        const rad = PI / 180;
        const radX = camera.angle.x * rad;
        const radY = camera.angle.y * rad;

        // Get perceived screen size based on camera angle
        // 90° = ×1, 0° = ×∞
        // No idea what would be the best formula here, at first I used tan, but it turned out to be excessive.
        // This seems to work well...
        const screenWidth  = GetScreenWidth;
        const screenHeight = cast(int) (GetScreenHeight * sqrt(1 + radY));

        // Get all 3D objects
        chain(
            cells.map!(a => cameraDistance(a, radX, 0)),
            models.map!(a => cameraDistance(a, radX, 1)),
            anchors.map!(a => cameraDistance(a, radX, 2, (cast(RaylibAnchor) a).drawOrder))
        )

            // Ignore invisible objects
            .filter!(a => inBounds(a, screenWidth, screenHeight))

            // Depth sort
            .array
            .multiSort!(`a[1] < b[1]`, `a[2] > b[2]`, `a[3] < b[3]`, `a[4] < b[4]`)

            // Draw them
            .each!(a => a[0].to!WithDrawableResources.draw());

    }

    private alias SortTuple = Tuple!(Object3D, RaylibAnchor.DrawOrder, float, float, uint);

    /// Check if the object is in bounds of the display.
    private bool inBounds(SortTuple object, int screenWidth, int screenHeight) {

        Vector2 screenPoint(CellPoint point) @trusted {

            return GetWorldToScreen(object[0].position.toVector3(cellSize, point), raycam);

        }

        const center = screenPoint(CellPoint.center);
        const edge   = screenPoint(CellPoint.edge);

        const diagX = abs(edge.x - center.x);
        const diagY = abs(edge.y - center.y);

        // Top is visible
        if (0 <= center.x + diagX && center.x - diagX < screenWidth
         && 0 <= center.y + diagY && center.y - diagY < screenHeight) {

            return true;

        }

        // Get bottom position
        const bottom = screenPoint(CellPoint.bottomCenter);

        // Bottom is visible
        if (0 <= bottom.x + diagX && bottom.x - diagX < screenWidth
         && 0 <= bottom.y + diagY && bottom.y - diagY < screenHeight) {

            return true;

        }

        // Nope, nothing is visible
        return false;

    }

    /// Get the camera distance of given Object3D
    private SortTuple cameraDistance(Object3D object, real rad, uint priority,
    RaylibAnchor.DrawOrder order = RaylibAnchor.DrawOrder.position) {

        return SortTuple(
            object,
            order,
            -object.visualPosition.x * sin(rad)
              - object.visualPosition.y * cos(rad),
            object.visualPosition.height.top,
            priority,
        );

    }

    private void updateCamera() {

        const rad = std.math.PI / 180;
        const radX = camera.angle.x * rad;
        const radY = camera.angle.y * rad;
        const cosY = cos(camera.angle.y * rad);

        // Calculate the target
        const target = camera.follow is null
            ? Position()
            : camera.follow.visualPosition;
        const targetVector = target.toVector3(cellSize, CellPoint.center);

        // Update the camera
        // not sure how to get the correct fovy from distance, this is just close to the expected result.
        // TODO: figure it out.
        raycam.fovy = camera.distance * cellSize;

        // Get the target
        raycam.target = Vector3(
            targetVector.x + camera.offset.x * cellSize,
            targetVector.y + camera.offset.height * cellSize,
            targetVector.z + camera.offset.y * cellSize,
        );

        // And place the camera
        raycam.position = raycam.target + Vector3(
            radX.sin * cosY,
            radY.sin,
            radX.cos * cosY,
        ) * camera.distance;

    }

    /// Add a Raylib anchor. See `isodi.Anchor` for reference.
    /// Params:
    ///     callback = Function that will be called every frame in order to draw the anchor content.
    /// Returns: The created anchor
    RaylibAnchor addAnchor(void delegate() @trusted callback) {

        auto anchor = cast(RaylibAnchor) super.addAnchor();
        anchor.callback = callback;
        return anchor;

    }

}
