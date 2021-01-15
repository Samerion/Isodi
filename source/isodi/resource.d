///
module isodi.resource;

import core.time;
import std.typecons;

import rcjson;

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

/// Represents a node in the skeleton.
struct SkeletonNode {

    /// Parent index
    @JSONExclude
    size_t parent;

    /// If true, this node shouldn't be displayed and its bone resource shouldn't be loaded.
    bool hidden;

    /// Name of the used bone resource.
    string name;

    /// ID of the node, defauls to the bone name. Must be unique, so should be defined in case a bone occurs more than
    /// one time.
    string id;

    /// List of bone variants compatible with this node.
    ///
    /// If this is empty, all variants are allowed.
    string[] variants;

    /// Offset for the bone's start relative to the parent's end.
    ///
    /// If the node is rotated, the whole bone will be rotated relative to this point.
    float[3] boneStart = [0, 0, 0];

    /// Position of the bone's end, relative to this node's start.
    float[3] boneEnd = [0, 0, 0];

    /// Position of the bone's texture relative to this node's start.
    float[3] texturePosition = [0, 0, 0];

    /// Rotation of the node.
    ushort rotation;
    invariant(rotation >= 0);
    invariant(rotation < 360);

    /// $(TCOLON Bone) If true, the bone textures will be mirrored.
    bool mirror;

}

/// Represents a running animation.
struct Animation {

    /// Frames per second.
    const float fps = 0;

    /// Current frame.
    float frame = 0;

    /// Current part
    uint current;

    /// Amount of times this animation is supposed to play for. 0 for infinite.
    uint times;

    /// Animations
    AnimationPart[] parts;

}

alias Property(T) = Nullable!(Tuple!(ubyte, "priority", T, "value"));

/// Represents a single part of the animation, it may be a single or a few frames.
struct AnimationPart {

    /// Length of the part in frames.
    uint length;

    /// Change the model offset or position.
    Property!(float[3]) offset;

    /// Apply changes to a bone
    AnimationBone[string] bone;

}

/// Changeable bone properties.
struct AnimationBone {

    /// Rotate the bone.
    Property!(float[3]) rotate;

    /// Rotate the bone.
    Property!float scale;

}
