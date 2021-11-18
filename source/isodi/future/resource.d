module isodi.future.resource;

import raylib;

import isodi.position;
import isodi.camera : Camera;


@safe:


interface DrawableResource {

    void draw(ref Camera camera);

}

abstract class AdvancedDrawableResource : DrawableResource {

    void draw(ref Camera camera) {

        drawOffset(camera, Position());

    }

    abstract void drawOffset(ref Camera camera, Position offset);

}
