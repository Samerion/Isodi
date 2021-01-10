module isodi.raylib.model;

debug import std.stdio;
import std.array;
import std.algorithm;

import isodi.model;
import isodi.display;
import isodi.resource;
import isodi.raylib.resources.bone;

/// `Model` implementation for Raylib.
final class RaylibModel : Model, WithDrawableResources {

    package {

        Bone[] bones;

    }

    ///
    this(Display display, const string type) {

        super(display, type);
        reload();

    }

    override void changeVariant(string type, string variant) {

        assert(0, "unimplemented");

        // Check each bone
        //foreach (bone; bones) {

        //    // If the type matches
        //    if (bone.node.name == type) {

        //        // Reload with a changed variant
        //        bone.reload(variant);

        //    }

        //}

    }

    ///
    void reload() {

        // Clear the array first
        bones = [];

        // Get the bones
        auto skeleton = display.packs.getSkeleton(type);
        foreach (node; skeleton.matches) {

            bones ~= Bone(this, node);

        }

    }

    ///
    void draw() {

        // TODO Depth sort based on x.sin and z.sin
        foreach (bone; bones) bone.draw();

    }

}
