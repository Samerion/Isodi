/// This package holds modules to be included in later versions of Isodi as a part of the main package, replacing the
/// old display system. See #21 for more details.
///
/// Note: Display cellSize is ignored and assumed to be 100. If you're using this package, it's preferred not to rely
/// on this value at all, as it will likely change in the future.
module isodi.future;

// TODO: consider using Matrix transformations instead of rlgl directly.

public {

    import isodi.future.model;
    import isodi.future.render_bundle;
    import isodi.future.resource;

}
