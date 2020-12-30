///
module isodi.raylib.anchor;

import isodi.anchor;
import isodi.display;
import isodi.resource;
import isodi.position;
import isodi.raylib.resources;

/// Anchor implementation for Raylib.
final class RaylibAnchor : Anchor {

    /// This delegate will be called every frame in order to draw. This is called within the display's Mode3D
    ///
    /// If you rely on time within, `raylib.GetFrameTime` to get time passed between frames.
    void delegate() draw;

    ///
    this(Display display) {

        super(display);
        draw = { };

    }

}
