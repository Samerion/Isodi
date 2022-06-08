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

// TODO refile below

struct TextureAtlas {

    /// Texture with the atlas.
    Texture2D texture;

    /// Position of each texture. Indexes are the same as given on creation.
    Rectangle[] positions;

}

/// Create a square texture atlas out of other square textures. Each texture must be of size `2^n`.
TextureAtlas makeAtlas(Texture2D[] tiles) {

    assert(false, "Not implemented");

}
