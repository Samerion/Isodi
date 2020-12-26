module isodi.exceptions;

import std.exception;

/// Any exception thrown in Isodi extends from this one.
abstract class IsodiException : Exception {

    mixin basicExceptionCtors;

}

/// Any exception that occurs while loading packs or textures.
class PackException : Exception {

    mixin basicExceptionCtors;

}
