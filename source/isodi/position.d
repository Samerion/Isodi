///
module isodi.position;

import std.meta;
import std.typecons;
import std.algorithm;

/// Represents the height of a cell
struct Height {

    /// Position of the cell's top side.
    float top = 0;

    /// Depth of the cell; how much space does the cell occupy in this column.
    float depth = 1;

}

/// Unique values for locating an object in the 3D space.
alias UniquePosition = Tuple!(
    int, "x",
    int, "y",
    int, "layer",
);

/// Denotes an object's position.
alias Position = Tuple!(
    int, "x",
    int, "y",
    int, "layer",
    Height, "height",
);

/// Arguments to pass to `multiSort` to sort Object3Ds by `position`.
private alias positionSortArgs = AliasSeq!(
    `a.position.layer < b.position.layer`,
    `a.position.y < b.position.y`,
    `a.position.x < b.position.x`,
);

/// Sort Object3Ds by `position`.
alias positionSort = multiSort!positionSortArgs;


@safe:


/// Create a position tuple.
Position position(int x, int y, int layer = 0, Height height = Height.init) {

    return Position(x, y, layer, height);

}

/// Create a position tuple.
Position position(int x, int y, Height height, int layer = 0) {

    return Position(x, y, layer, height);

}

/// Create an offset tuple.
///
/// Unlike the other position constructors, this will subtract 1 from depth.
Position positionOff(int x, int y, Height height = Height.init) {

    height.depth -= 1;

    return Position(x, y, 0, height);

}

/// Get the unique position from a Position tuple.
inout(UniquePosition) toUnique(inout Position position) {

    return UniquePosition(position.x, position.y, position.layer);

}
