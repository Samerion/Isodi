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

/// `Model` implementation for Raylib.
final class RaylibModel : Model, WithDrawableResources {

    package {

        Bone[] bones;
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
            bones ~= Bone(this, node, getBone(node));
            auto bone = &bones[$-1];

            // Save by ID
            assert(bone.node.id !in bonesID);
            bonesID[bone.node.id] = bone;

        }

    }

    ///
    void draw() {

        const rad = display.camera.angle.x * std.math.PI / 180;

        runAnimations();

        rlPushMatrix();

            // Sort the bones
            bones.map!((ref a) => cameraDistance(&a, rad))
                .array
                .sort!((a, b) => a[1] > b[1])

                // Draw them
                .each!(a => a[0].draw());

        rlPopMatrix();

    }

    private void runAnimations() {

        foreach_reverse (i, ref animation; animations) {

            // Increment frame time
            animation.frame += animation.fps * GetFrameTime();

            // Run the animation
            while (true) {

                // Get the next part
                const part = animation.parts[animation.current];

                // Run it; end if the part didn't finish
                if (!runAnimationPart(part)) break;

                // Advance to the next part
                if (animation.advance == Yes.ended) {

                    // The animation ended, remove it
                    animations = animations.remove(i);

                    // Continue to the next animation
                    break;

                }

            }

        }

    }

    /// Run the current animation part.
    /// Returns: true if the animation part finished.
    private bool runAnimationPart(const AnimationPart part) {

        return false;

    }

    private Tuple!(Bone*, float) cameraDistance(Bone* bone, real rad) {

        // Get new matrixes
        bone.updateMatrixes();

        const vec = Vector3Transform(Vector3Zero, bone.boneStart);

        return Tuple!(Bone*, float)(
            bone,
            vec.x * sin(rad)
              + vec.z * cos(rad),
        );

    }

}
