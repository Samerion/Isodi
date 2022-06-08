///
module isodi.exception;

public import std.exception;


@safe:


/// Any exception thrown in Isodi extends from this one.
abstract class IsodiException : Exception {

    mixin basicExceptionCtors;

}

/// Any exception that occurs while loading packs or textures.
class PackException : IsodiException {

    mixin basicExceptionCtors;

}

/// Any exception that occurs while loading or exporting tilemaps.
class MapException : IsodiException {

    mixin basicExceptionCtors;

}
