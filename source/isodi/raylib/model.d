module isodi.raylib.model;

import raylib;

import std.math;
import std.array;
import std.typecons;
import std.algorithm;

import isodi.model : Model;
import isodi.display;
import isodi.resource;
import isodi.raylib.internal;
import isodi.raylib.resources.bone;


@safe:


/// `Model` implementation for Raylib.
final class RaylibModel : Model, WithDrawableResources {

    package {

        Bone*[] bones;
        Bone*[string] bonesID;

    }

    public {

        /// If true, enable debugging all bone points.
        debug (Isodi_BoneDebug) {

            bool boneDebug = true;
            bool positionDebug = true;

        }
        else {

            bool boneDebug = false;
            bool positionDebug = false;

        }

    }

    ///
    this(Display display, const string type) {

        super(display, type);
        changeSkeleton(type);

    }

    /// Get/set bone debug for a node.
    ref bool nodeBoneDebug(size_t index) {

        return bones[index].boneDebug;

    }

    override void changeSkeleton(string type) {

        // Get the bones
        auto skeleton = display.packs.getSkeleton(type);

        changeSkeleton(skeleton.match);

    }

    override void changeSkeleton(SkeletonNode[] nodes) {

        // Unregister all bones
        bonesID = null;

        // Prepare the array
        bones.length = nodes.length;

        // Add them
        foreach (i, node; nodes) replaceNode(node, i);

    }

    override void copySkeleton(Model model) {

        auto rlmodel = cast(RaylibModel) model;

        // Prepare the array
        bones.length = rlmodel.bones.length;

        // Add the bones
        foreach (i, bone; rlmodel.bones) replaceNode(bone.node, i);

    }

    override SkeletonNode[] skeletonBones() {

        return bones.map!"a.node".array;

    }

    override size_t addNode(SkeletonNode node) {

        const index = bones.length;
        bones ~= null;
        replaceNode(node, index);

        return index;

    }

    override void replaceNode(SkeletonNode node, size_t index) {

        import std.format;

        // Remove the old node
        if (index < bones.length) {

            // Get the bone
            if (auto bone = bones[index]) {

                // Remove it from the list.
                bonesID.remove(bone.node.id);

            }

        }

        auto bone = new Bone(this, index != 0, node, getBone(node));
        bones[index] = bone;

        // Save by ID
        assert(node.id !in bonesID, node.id.format!"Duplicate skeleton node ID %s");
        bonesID[node.id] = bone;

    }

    override SkeletonNode[] removeNodes(string[] nodes...) @system
    out(r) {

        if (r.length == 0) {

            // Top parent of the removed node must be 0.
            assert(r[0].parent == 0);

        }

    }
    do {
        // TODO: unittest?

        SkeletonNode[] newBones;
        SkeletonNode[] removed;
        size_t[] newIndexes;
        size_t[] removedIndexes;

        // Remove the nodes
        foreach (i, bone; bones) {

            // The node is to be removed, or its parent has been removed
            const toRemove = nodes.canFind(bone.node.id);
            const parentRemoved = removedIndexes.canFind(bone.node.parent);

            // Then this node is to be removed
            if (toRemove || parentRemoved) {

                newIndexes ~= removed.length;

                // Make parent of the node refer to local index within `removed`
                bone.node.parent = parentRemoved
                    ? newIndexes[bone.node.parent]
                    : 0;

                // List as removed
                removed ~= bone.node;
                removedIndexes ~= i;

            }

            // This node is to be kept
            else {

                newIndexes ~= newBones.length;

                // The parent might have moved
                bone.node.parent = newIndexes[bone.node.parent];

                // Add again
                newBones ~= bone.node;

            }

        }

        // It's easier to just reset the skeleton
        changeSkeleton(newBones);

        return removed;

    }

    override SkeletonNode* getNode(size_t index) {

        return index < bones.length
            ? &bones[index].node
            : null;

    }

    override SkeletonNode* getNode(string id) {

        if (auto bone = id in bonesID) {

            return &(*bone).node;

        }

        else return null;

    }

    override void changeVariant(string id, string variant) {

        //auto bone = bonesID[id].changeVariant(variant);
        assert(0, "unimplemented");

    }

    /// Reload the bones.
    override void reload() {

        // Clear the bone ID list
        bonesID = null;

        // Regenerate each bone
        foreach (i, bone; bones) replaceNode(bone.node, i);

    }

    ///
    void draw() @trusted {

        import std.range;

        const rad = display.camera.angle.x * std.math.PI / 180;

        runAnimations();

        // Debug mode
        if (positionDebug) {

            rlPushMatrix();
            scope(exit) rlPopMatrix();

            // Move to the appropriate position
            rlTranslatef(visualPosition.toTuple3(display.cellSize, CellPoint.center).expand);
            rlRotatef(90, 1, 0, 0);
            rlTranslatef(0, 0, 1);

            // Draw a circle below the model
            DrawCircle(0, 0, display.cellSize / 3, Colors.BLUE);

        }

        // Get bones to have bone debugging enabled for
        Bone*[] boneDebugTargets;

        // Sort the bones
        auto boneRange = bones[].map!((a) => cameraDistance(a, rad))
            .array
            .sort!((a, b) => a[1] > b[1])
            .tee!((bone) {

                // Check if bone debugging is enabled for this bone
                if (!bone[0].boneDebug) return;
                boneDebugTargets ~= bone[0];

            });

        // Draw them
        boneRange.each!(a => a[0].draw());

        // Debug mode: draw debug points
        if (boneDebug) boneRange.each!(a => a[0].drawDebug);

        // Otherwise draw debug points only for chosen nodes
        else boneDebugTargets.each!(a => a.drawDebug);

    }

    private void runAnimations() {

        foreach_reverse (i, ref animation; animations) {

            const previousFrame = animation.frame;
            const delta = (() @trusted => animation.fps * GetFrameTime)();

            // Increment frame time
            animation.frame += delta;

            // Run the animation
            while (true) {

                // Get the next part
                const part = animation.parts[animation.current];

                // Frame delta / Frames until the end. Used to calculate changes in animated values
                const progress = min(1, delta / (part.length - previousFrame));

                // Run the animation
                runAnimationPart(part, progress);

                // Stop if the part didn't end
                if (progress != 1) break;

                // Decrease frame by part length
                animation.frame -= part.length;

                // Advance to the next part
                if (animation.advance == Yes.ended) {

                    // The animation ended, remove it
                    animations = animations.remove(i);

                    // Continue to the next animation
                    break;

                }

                // Break if this is an infinite loop
                else if (animation.times == 0) break;

            }

        }

    }

    /// Run the current animation part.
    private void runAnimationPart(const AnimationPart part, float progress) {

        // TODO: offset

        // Check the bones
        foreach (bone, target; part.bone) {

            // Get the node for this bone
            auto node = bonesID.get(bone, null);

            // Ignore if the node doesn't exist
            // This is because models and animations might be provided by different packs and different models may
            // have different complexity level — less complex models should still work with animations designed for
            // advanced ones, assuming that basic naming is kept the same.
            // Detecting mispellings and unknown bones is the job of a resource editor.
            if (node is null) continue;

            // Changing rotation
            if (!target.rotate.isNull) {

                import std.range : enumerate;

                // Tween each value
                auto newValues = [node.boneRotation.tupleof]
                    .enumerate
                    .map!((item) {

                        const targetRad = target.rotate.get[item.index] * std.math.PI / 180;

                        return tweenAngle(progress, item.value, targetRad);

                    });

                // Assign it
                node.boneRotation = Vector3(newValues[0], newValues[1], newValues[2]);

            }

            // Changing scale
            if (!target.scale.isNull) {

                node.boneScale = tween(progress, node.boneScale, target.scale.get);

            }

        }

    }

    /// Animate the given rotation property.
    private T tweenAngle(T)(float progress, T currentValue, T target) {

        // TODO: make this consider wrapping
        return currentValue + progress * (target - currentValue);

    }

    /// Animate the given property.
    private T tween(T)(float progress, T currentValue, T target) {

        return currentValue + progress * (target - currentValue);

    }

    private Tuple!(Bone*, float) cameraDistance(Bone* bone, real rad) {

        // Get new matrixes
        bone.updateMatrixes();

        const vec = (() @trusted => Vector3Transform(Vector3Zero, bone.boneStart))();

        return Tuple!(Bone*, float)(
            bone,
            -vec.x * sin(rad)
              - vec.z * cos(rad),
        );

    }

}
