///
module isodi.anchor;

import std.variant;

import isodi.object3d;

/// Anchors allow placing user-defined objects within the Isodi 3D space.
///
/// By their nature, they are majorily renderer-dependent. See binding documentation for usage.
abstract class Anchor : Object3D {

    mixin Object3D.Implement;

    private {

        static size_t nextID;
        size_t _id;

    }

    ///
    this(Display display) {

        super(display);
        this._id = nextID++;

    }

    ~this() {

        if (display) display.removeAnchor(this);

    }

    @property
    size_t id() const { return _id; }

    /// Make an anchor with the current renderer.
    static Anchor make(Display display) {

        return Renderer.createAnchor(display);

    }

}
