///
module isodi.anchor;

import std.variant;

import isodi.object3d;

/// Anchors allow placing user-defined objects within the Isodi 3D space.
///
/// By their nature, they are majorily renderer-dependent. See binding documentation for usage.
abstract class Anchor : Object3D {

    mixin Object3D.Implement;

    ///
    this(const Display display) {

        super(display);

    }

    /// Make an anchor with the current renderer.
    static Anchor make(const Display display) {

        return Renderer.createAnchor(display);

    }

}
