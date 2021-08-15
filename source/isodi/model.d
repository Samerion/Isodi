///
module isodi.model;

import core.time;
import std.string;
import std.random;

import isodi.pack;
import isodi.tests;
import isodi.object3d;
import isodi.resource;


@safe:


/// Represents a 3D model.
abstract class Model : Object3D, WithDrawableResources {

    /// Position in the model is relative to the model's bottom, so if a cell is placed at the same position
    /// as the model, the model will be standing on the cell.
    mixin Object3D.Implement;

    private {

        static size_t nextID;
        size_t _id;

    }

    /// Type of the model.
    const string type;

    /// Active animations.
    protected Animation[] animations;

    /// Seed to use for RNG calls related to generation of this model's resources.
    ///
    /// It's preferred to sum this with a magic number to ensure unique combinations.
    const ulong seed;

    /// Create a new model.
    /// Params:
    ///     display = Display to create the model for.
    ///     type    = Skeleton to use for the model.
    this(Display display, const string type) {

        // TODO: ModelBuilder for Isodi editors.

        super(display);
        this._id = nextID++;
        this.type = type;
        this.seed = unpredictableSeed;

    }

    @property
    size_t id() const { return _id; }

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
    ///     duration = Time it should take for one loop of the animation to complete.
    ///     times    = How many times the animation should be ran.
    void animate(string type, Duration duration, uint times = 1) {

        // Get the resource
        uint frameCount;  // @suppress(dscanner.suspicious.unmodified)
        auto resource = display.packs.getAnimation(type, frameCount);

        // Push the animation
        animations ~= Animation(
            cast(float) frameCount / duration.total!"msecs" * 1000f,
            times,
            resource.match
        );

    }

    /// Run an animation indefinitely.
    /// Params:
    ///     type     = Type of the animation
    ///     duration = Time it should take for one loop of the animation to complete.
    void animateInf(string type, Duration duration) {

        animate(type, duration, 0);

    }

    // TODO: stopAnimation

    ///
    protected Pack.Resource!string getBone(const SkeletonNode node) @trusted {

        // TODO: add support for node.variants

        auto rng = Mt19937_64(seed + node.parent);

        // Get the texture
        auto glob = display.packs.packGlob(node.name.format!"models/bone/%s/*.png");
        const file = glob.matches.choice(rng);

        return Pack.Resource!string(
            file,
            glob.pack.getOptions(file)
        );

    }

}

mixin DisplayTest!((display) {

    // Model 1
    display.addCell(Position(), "grass");
    with (display.addModel(Position(), "wraith-white")) {

        animateInf("breath", 6.seconds);
        animate("crab", 1.seconds);

    }

    // Model 2
    display.addCell(position(2, 0), "grass");
    display.addModel(position(2, 0), "wraith-white");

    // Add a cell behind
    display.addCell(position(2, 1, Height(4, 5)), "grass");

});
