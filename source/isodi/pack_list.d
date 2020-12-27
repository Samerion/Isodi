module isodi.pack_list;

import isodi.bind;
import isodi.pack;

/// Represents a pack list.
abstract class PackList {

    /// Underlying pack list.
    Pack[] packList;
    alias packList this;

    /// Create a pack list for the current renderer.
    static PackList make() {

        return Renderer.createPackList();

    }

    /// Create a pack list for the current renderer.
    /// Params:
    ///     packs = Preload the list with given packs.
    static PackList make(Pack[] packs...) {

        auto list = make();
        list.packList = packs;
        list.clearCache();
        return list;

    }

    /// Clear resource cache. Call when the list contents were changed or reordered.
    abstract void clearCache();

}
