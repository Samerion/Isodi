module isodi;

public {

    // Regular build, import majority of Isodi
    version (Isodi_Regular) {

        // Subpackages
        import isodi.resources;

        // Modules
        import isodi.camera;
        import isodi.chunk;
        import isodi.exception;
        import isodi.isodi_model;
            // package.d
        import isodi.properties;
        import isodi.skeleton;
            // isodi.tests omitted
        import isodi.tilemap;
            // isodi.tilemap_legacy omitted
        import isodi.utils;

    }

    // Tilemap build, include only source files
    version (Isodi_MiniTilemapLoader) {

        import isodi.exception;
        import isodi.tilemap;
        import isodi.tilemap_legacy;

    }

}
