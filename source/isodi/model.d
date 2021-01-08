///
module isodi.model;

import rcjson;

import isodi.tests;
import isodi.object3d;

/// Represents a 3D model.
abstract class Model : Object3D, WithDrawableResources {

    /// Position in the model is relative to the model's bottom, so if a cell is placed at the same position
    /// as the model, the model will be standing on the cell.
    mixin Object3D.Implement;

    /// Type of the model.
    const string type;

    /// Create a new model.
    /// Params:
    ///     display = Display to create the model for.
    ///     type    = Skeleton to use for the model.
    this(Display display, const string type) {

        // TODO: ModelBuilder for Isodi editors.

        super(display);
        this.type = type;

    }

    /// Ditto
    static Model make(Display display, const string type) {

        return Renderer.createModel(display, type);

    }

    /// Change the variant used for all bones of the given type.
    /// Params:
    ///     bone    = Type of the bones to be affected.
    ///     variant = Variant of the bone to be set.
    abstract void changeVariant(string bone, string variant);

    /// Randomize the variant used for all bones of the given type.
    /// Params:
    ///     bone = Type of the bones to be affected.
    void changeVariant(string bone) {

        assert(0, "unimplemented");

    }

}

mixin DisplayTest!((display) {

    display.addCell(Position(), "grass");
    display.addModel(Position(), "wraith-white");

    // Add a cell behind
    display.addCell(position(0, 1, Height(4, 5)), "grass");

});

/// Represents a node in the skeleton.
struct SkeletonNode {

    /// Parent index
    @JSONExclude
    size_t parent;

    /// If true, this node shouldn't be displayed and its bone resource shouldn't be loaded.
    bool hidden;

    /// Name of the node and its bone resource.
    string name;

    /// List of bone variants compatible with this node.
    ///
    /// If this is empty, all variants are allowed.
    string[] variants;

    /// Position of this node relative to the parent node.
    int[3] position;

    /// Rotation of the node.
    ushort rotation;
    invariant(rotation >= 0);
    invariant(rotation < 360);

}
