///
module isodi.resource;

import isodi.pack_list;

/// Defines an object that makes use of some resources, or is a resource itself. It will be signaled every time the
/// pack list is updated.
interface WithResources {

    /// Reload the resource's dependencies using the given pack list.
    ///
    /// Those dependencies are usually textures, audio files, etc.
    void reload();

}

/// Defines an object that uses drawable resources, or is one itself.
///
/// Note that some renderers, for example Godot, automatically manage drawing and don't let the user draw manually.
/// In this case, the `draw` implementation should be omitted.
interface WithDrawableResources : WithResources {

    /// Draw this resource, if supported by the renderer.
    void draw();

}
