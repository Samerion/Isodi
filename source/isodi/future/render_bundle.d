/// Implements RenderBundle. This module is exclusive to raylib-d, see #20 and #21.
module isodi.future.render_bundle;

import raylib;

import isodi.tests;
import isodi.position;
import isodi.camera : Camera;

import isodi.raylib.model;
import isodi.raylib.display;
import isodi.raylib.camera;

import isodi.future.resource;


@safe:


class RenderBundle : AdvancedDrawableResource {

    /// Position this bundle should be drawn at.
    Position position;

    /// Resources to be drawn as a part of this render bundle.
    DrawableResource[] resources;

    this() { }

    this(Position position) {

        this.position = position;

    }

    override void drawOffset(ref Camera camera, Position offset) @trusted {

        import isodi.raylib.internal;

        rlPushMatrix();
        scope (exit) rlPopMatrix();

        const outputPosition = position.sum(offset);

        // Move to the appropriate position
        rlTranslatef(outputPosition.toTuple3(100, CellPoint.center).expand);

        foreach (resource; resources) {

            rlPushMatrix();
            scope (exit) rlPopMatrix();

            if (auto advancedResource = cast(AdvancedDrawableResource) resource) {

                advancedResource.drawOffset(camera, outputPosition);

            }

            else resource.draw(camera);

        }

    }

}

mixin DisplayTest!((display) {

    import isodi.future.model;

    auto bundle1 = new RenderBundle(position(0, 0));
    auto bundle2 = new RenderBundle(position(1, 2, Height(0.2)));

    class RotatingResource : DrawableResource {

        void draw(ref Camera camera) @trusted {

            DrawGrid(10, 100);

            camera.applyBillboard();
            rlScalef(1, -1, 1);

            auto textWidth = MeasureText("This is a test", 20);
            DrawText("This is a test", -textWidth/2, 0, 20, Colors.BLACK);

        }

    }

    bundle2.resources ~= [

        cast(DrawableResource) new RotatingResource(),
        new OldModel(display, "wraith-white"),

    ];

    auto rldisplay = cast(RaylibDisplay) display;
    rldisplay.addAnchor({

        bundle2.draw(display.camera);

    }).position = bundle2.position;

});
