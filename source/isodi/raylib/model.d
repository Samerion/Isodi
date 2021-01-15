module isodi.raylib.model;

import std.math;
import std.array;
import std.typecons;
import std.algorithm;

import isodi.model;
import isodi.display;
import isodi.resource;
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

        // Sort the bones
        bones.map!((ref a) => cameraDistance(&a, rad))
            .array
            .sort!((a, b) => a[1] > b[1])

            // Draw them
            .each!(a => a[0].draw());

    }

    private Tuple!(Bone*, float) cameraDistance(Bone* bone, real rad) {

        return Tuple!(Bone*, float)(
            bone,
            bone.boneStart.x * sin(rad)
              + bone.boneStart.z * cos(rad),
        );

    }

}
