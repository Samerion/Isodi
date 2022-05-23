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

    ///
    this(Display display, const string type) {

        super(display, type);
        reload();

    }

    override void changeVariant(string id, string variant) {

        //auto bone = bonesID[id].changeVariant(variant);
        assert(0, "unimplemented");

    }

    ///
    void reload() {

        // Clear the array first
        bones = [];

        // Get the bones
        auto skeleton = display.packs.getSkeleton(type);
        foreach (node; skeleton.match) {

            // Create a bone
            auto bone = new Bone(this, node, getBone(node));
            bones ~= bone;

            // Save by ID
            bonesID[bone.node.id] = bone;

        }

    }

    ///
    void draw() @trusted {

        const rad = display.camera.angle.x * std.math.PI / 180;

        runAnimations();

        rlPushMatrix();
        scope(exit) rlPopMatrix();

        // Sort the bones
        bones.map!((a) => cameraDistance(a, rad))
            .array
            .sort!((a, b) => a[1] > b[1])

            // Draw them
            .each!(a => a[0].draw());

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
            {

                import std.range : enumerate;

                // Tween each value
                auto newValues = [node.boneRotation.tupleof]
                    .enumerate
                    .map!((item) {

                        const targetRad = target.rotate[item.index] * std.math.PI / 180;

                        return tweenAngle(progress, item.value, targetRad);

                    });

                // Assign it
                node.boneRotation = Vector3(newValues[0], newValues[1], newValues[2]);

            }

            // Changing scale
            if (target.scale != 0) {

                node.boneScale = tween(progress, node.boneScale, target.scale);

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
