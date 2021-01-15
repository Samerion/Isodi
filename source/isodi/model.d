///
module isodi.model;

import core.time;

import isodi.tests;
import isodi.object3d;
import isodi.resource;

/// Represents a 3D model.
abstract class Model : Object3D, WithDrawableResources {

    /// Position in the model is relative to the model's bottom, so if a cell is placed at the same position
    /// as the model, the model will be standing on the cell.
    mixin Object3D.Implement;

    /// Type of the model.
    const string type;

    /// Active animations.
    protected Animation[] animations;

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

    /// Change the variant used for the node with given ID.
    /// Params:
    ///     id      = ID of the node to change.
    ///     variant = Variant of the bone to be set.
    abstract void changeVariant(string id, string variant);

    /// Randomize the variant used for the node with given ID.
    /// Params:
    ///     id = ID of the node to change.
    void changeVariant(string id) {

        assert(0, "unimplemented");

    }

    /// Run an animation.
    /// Params:
    ///     type     = Type of the animation.
    ///     duration = Time it should take for the animation to complete.
    ///     times    = How many times the animation should be ran.
    void animate(string type, Duration duration, ulong times = 1) {

        assert(0);

    }

}

mixin DisplayTest!((display) {

    // Model 1
    display.addCell(Position(), "grass");
    display.addModel(Position(), "wraith-white");

    // Model 2
    display.addCell(position(2, 0), "grass");
    display.addModel(position(2, 0), "wraith-white");

    // Add a cell behind
    display.addCell(position(2, 1, Height(4, 5)), "grass");

});
