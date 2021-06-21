module isodi.raylib.internal;

import raylib;

public import std.typecons;

import isodi.bind;
import isodi.position;

/// Convert position to Vector3
inout(Vector3) toVector3(inout(Position) position, int cellSize, Flag!"center" center = No.center) {

    return Vector3(position.toTuple3(cellSize, center).expand);

}

/// Get a Vector3 from given position.
auto toTuple3(inout(Position) position, int cellSize, Flag!"center" center = No.center) {

    alias Ret = Tuple!(float, float, float);

    // Center the position
    if (center) {

        return Ret(
            (position.x + 0.5) * cellSize,
            position.height.top * cellSize,
            (position.y + 0.5) * cellSize,
        );

    }

    // Align to corner instead.
    else {

        return Ret(
            position.x * cellSize,
            position.height.top * cellSize,
            position.y * cellSize,
        );

    }

}

/// Load a texture from the display.
Texture loadTexture(Display display, string path) {

    import isodi.raylib.pack_list : RaylibPackList;

    // Get the pack list
    auto packs = cast(RaylibPackList) display.packs;

    // Return the texture
    return packs.loadTexture(path);

}
