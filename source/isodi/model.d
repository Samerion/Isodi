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

    static private size_t nextID;

    /// ID of the model.
    const size_t id;

    /// Type of the model.
    deprecated("Model type information is no longer to be provided at runtime as model's skeleton may differ from the "
        ~ "skeleton saved in the pack.")
    @property const string type() { return null; }

    /// Active animations.
    protected Animation[] animations;

    /// Seed to use for RNG calls related to generation of this model's resources.
    ///
    /// It's preferred to sum this with a magic number to ensure unique combinations.
    const ulong seed;

    /// Create a new model.
    /// Params:
    ///     display  = Display to create the model for.
    ///     skeleton = Skeleton to use for the model; leave empty to not load any.
    this(Display display, const string skeleton = null) {

        // TODO: ModelBuilder for Isodi editors.

        super(display);
        this.id = nextID++;
        this.seed = unpredictableSeed;

    }

    /// Ditto
    static Model make(Display display, const string type = null) {

        return Renderer.createModel(display, type);

    }

    /// Replace the current skeleton with one saved in the pack.
    /// Params:
    ///     type = Type of the skeleton to load.
    abstract void changeSkeleton(string type);

    /// Replace the current skeleton with one made from given bones.
    /// Params:
    ///     bones = Bones to put in the skeleton.
    abstract void changeSkeleton(SkeletonNode[] nodes);

    /// Copy the skeleton from a different model. Animations and related state will not be copied over.
    abstract void copySkeleton(Model model);

    /// List all bones in the model's skeleton.
    abstract SkeletonNode[] skeletonBones();

    /// Add a new bone.
    /// Returns: Index of the new bone.
    abstract size_t addNode(SkeletonNode node);

    /// Replace a bone at given index.
    abstract void replaceNode(SkeletonNode node, size_t index);

    /// Remove a list of nodes.
    /// Returns: All removed nodes; this is given nodes plus their children
    abstract SkeletonNode[] removeNodes(string[] ids...);

    /// Get the bone at given index.
    abstract SkeletonNode* getNode(size_t index);

    /// Get the bone with given ID
    abstract SkeletonNode* getNode(string id);

    deprecated {
        alias addBone = addNode;
        alias replaceBone = replaceNode;
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
    Pack.Resource!string getBone(const SkeletonNode node) @trusted {

        import std.path, std.array, std.algorithm;

        // Hidden, don't load
        if (node.hidden) {

            return typeof(return)("", null);

        }

        auto rng = Mt19937_64(seed + node.parent);

        // Get the texture
        const glob = display.packs.packGlob(node.name.format!"models/bone/%s/*.png");
        const matches = node.variants.length
            ? glob.matches.filter!(a => node.variants.canFind(a.baseName(".png"))).array
            : glob.matches;

        const file = matches[].choice(rng);

        return typeof(return)(
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

    // An invisible, empty model 3
    display.addModel(position(-2, 0), "");

    // Add a cell behind
    display.addCell(position(2, 1, Height(4, 5)), "grass");

});
