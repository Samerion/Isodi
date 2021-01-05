///
module isodi.model;

import isodi.tests;
import isodi.object3d;

/// Represents a 3D model
abstract class Model : Object3D, WithDrawableResources {

    mixin Object3D.Implement;

    /// Type of the model.
    const string type;

    /// Create a new model.
    /// Params:
    ///     display = Display to create the model for.
    ///     type    = Type of the model to make. Leave empty to build a new model instead of loading.
    this(Display display, const string type) {

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

    /// Load a bone for the given skeleton node.
    ///
    /// This is called from the model's constructor while loading the skeleton for every node it contains, in a push
    /// parser fashion.
    ///
    /// Params:
    ///     id   = ID of the skeleton node.
    ///     node = Node to load.
    abstract protected void loadBone(size_t id, SkeletonNode node);

}

/// Represents a node in the skeleton.
struct SkeletonNode {

    /// Parent index
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

}
