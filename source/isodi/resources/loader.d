module isodi.resources.loader;

import raylib;


@safe:


alias ResourceLoader = Texture2D delegate(TextureResourceType resourceType, string filename);

/// Type of the resource, assuming a texture.
enum TextureResourceType {

    tile,
    side,
    decoration,
    bone,

}
