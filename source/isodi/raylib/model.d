module isodi.raylib.model;

import isodi.model;
import isodi.display;

/// `Model` implementation for Raylib.
final class RaylibModel : Model {

    ///
    this(Display display, const string type) {

        super(display, type);

    }

    override void changeVariant(string bone, string variant) {

    }

    override void loadBone(ulong id, SkeletonNode node) {

    }

}
