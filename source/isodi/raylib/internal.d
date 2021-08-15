module isodi.raylib.internal;

import raylib;

import std.typecons;

import isodi.bind;
import isodi.position;


@safe:


enum CellPoint {

    edge,
    center,
    bottomEdge,
    bottomCenter,

}

/// Convert position to Vector3
inout(Vector3) toVector3(inout(Position) position, int cellSize, CellPoint point = CellPoint.edge) {

    return Vector3(position.toTuple3(cellSize, point).expand);

}

/// Get a Vector3 from given position.
auto toTuple3(inout(Position) position, int cellSize, CellPoint point = CellPoint.edge) {

    alias Ret = Tuple!(float, float, float);

    const center = point == CellPoint.center     || point == CellPoint.bottomCenter;
    const bottom = point == CellPoint.bottomEdge || point == CellPoint.bottomCenter;

    const height = bottom
        ? position.height.top - position.height.depth
        : position.height.top;

    // Center the position
    if (center) {

        return Ret(
            (position.x + 0.5) * cellSize,
            height * cellSize,
            (position.y + 0.5) * cellSize,
        );

    }

    // Align to corner instead.
    else {

        return Ret(
            position.x * cellSize,
            height * cellSize,
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
