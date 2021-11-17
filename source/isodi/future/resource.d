module isodi.future.resource;

import isodi.camera;
import isodi.position;


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
