module isodi.future.model;

import raylib;

import isodi.display;
import isodi.position;
import isodi.raylib.model;
import isodi.model : Model;
import isodi.camera : Camera;

import isodi.future.resource;


@safe:


/// A model wrapper to be compatible with RenderBundle.
class OldModel : AdvancedDrawableResource {

    Model model;

    this(Model model) {

        this.model = model;

    }

    this(Display display, string type) {

        this.model = new RaylibModel(display, type);

    }

    override void drawOffset(ref Camera camera, Position position) @trusted {

        rlPushMatrix();
        scope (exit) rlPopMatrix();

        rlLoadIdentity();

        model.position = position;
        model.draw();

    }

}
