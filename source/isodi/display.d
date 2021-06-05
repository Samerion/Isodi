///
module isodi.display;

import isodi.bind;
import isodi.cell;
import isodi.pack;
import isodi.tests;
import isodi.anchor;
import isodi.camera;
import isodi.position;

/// Display is the main class of Isodi which manages all Isodi resources.
///
/// This class is abstract, as it should be overriden by the renderer. Use the `make` method to create a display with
/// the current renderer.
abstract class Display {

    public {

        /// Base cell size in the display, if supported by the renderer.
        ///
        /// Usually in pixels.
        int cellSize = 100;

        /// Active camera.
        Camera camera;

        /// Used pack list
        PackList packs;

    }

    protected {

        /// Registered cells
        Cell[UniquePosition] cellMap;

        /// Registered anchors
        Anchor[size_t] anchorMap;

        /// Registered models
        Model[size_t] modelMap;

    }

    private {

        /// ID of the last added anchor
        size_t lastAnchor;

        /// ID of the last added model
        size_t lastModel;

    }

    ///
    this() {

        packs = PackList.make();

    }

    /// Create a display with the current renderer.
    static Display make() {

        return Renderer.createDisplay();

    }

    /// Reload all resources in the display. Make sure to call `PackList.clearCache`.
    abstract void reloadResources();

    /// Iterate on all cells
    auto cells() {

        return cellMap.byValue;

    }

    /// Iterate on all models
    auto models() {

        return modelMap.byValue;

    }

    /// Iterate on all anchors
    auto anchors() {

        return anchorMap.byValue;

    }

    /// Add a new cell to the display. Replaces the cell if one already exists.
    /// Params:
    ///     position = Position of the cell in the display.
    ///     type     = Type of the cell.
    /// Returns: The created cell.
    Cell addCell(const Position position, const string type) {

        auto cell = Cell.make(this, position, type);
        cellMap[position.toUnique] = cell;
        return cell;

    }

    /// Get a cell at given position.
    /// Params:
    ///     position = Position of the cell.
    /// Returns: The cell at this position. `null` if not found.
    Cell getCell(const UniquePosition position) {

        return cellMap.get(position, null);

    }

    /// Remove the cell at given position.
    ///
    /// Note: The cell will remain in the memory until collected by the GC. If you want to remove it instantly, use
    /// `cell.destroy`.
    ///
    /// Returns: True if the cell was actually removed.
    bool removeCell(UniquePosition position) {

        return cellMap.remove(position);

    }

    /// Ditto.
    bool removeCell(Position position) {

        return removeCell(position.toUnique);

    }

    unittest {

        auto display = TestRunner.makeDisplay;

        // Add two sample cells
        display.addCell(position(1, 2), "wood");
        display.addCell(position(2, 2), "wood");

        // Replace the first cell
        display.addCell(position(1, 2), "grass");

        // Add a cell on a different layer
        display.addCell(position(2, 2, 1), "grass");

        assert(display.getCell(UniquePosition(1, 2, 0)).type == "grass");
        assert(display.getCell(UniquePosition(2, 2, 0)).type == "wood");
        assert(display.getCell(UniquePosition(3, 2, 0)) is null);

        // Remove the first cell
        display.removeCell(position(1, 2));

        assert(display.getCell(UniquePosition(1, 2, 0)) is null);

    }

    /// Add a new model to the display.
    /// Params:
    ///     position = Position to place the model on.
    ///     type     = Skeleton for the model
    Model addModel(const string type) {

        // Create the model
        auto model = Model.make(this, type);
        modelMap[model.id] = model;

        return model;

    }

    /// Ditto
    Model addModel(Position position, const string type) {

        auto model = addModel(type);
        model.position = position;
        return model;

    }

    /// Remove the given model from the map.
    /// Returns: True if the model was actually removed.
    bool removeModel(Model model) {

        return modelMap.remove(model.id);

    }

    /// Add a new anchor to the display.
    /// Returns: The created anchor.
    Anchor addAnchor(Position position = Position.init) {

        // Create the anchor
        auto anchor = Anchor.make(this);
        anchorMap[anchor.id] = anchor;

        // Set the position
        anchor.position = position;

        return anchor;

    }

    /// Remove the given anchor from the map.
    /// Returns: True if the anchor was actually removed.
    bool removeAnchor(Anchor anchor) {

        return anchorMap.remove(anchor.id);

    }

}

mixin DisplayTest!((display) {

    // Add a few cells
    display.addCell(position(1, 1), "grass");
    display.addCell(position(1, 2), "grass");
    display.addCell(position(1, 3), "grass");
    auto a = display.addCell(position(1, 4), "grass");

    // Place models on them
    display.addModel(position(1, 1), "wraith-white");
    display.addModel(position(1, 2), "wraith-white");
    auto b = display.addModel(position(1, 3), "wraith-white");
    auto c = display.addModel(position(1, 4), "wraith-white");

    // Remove the third and fourth cell (different methods)
    display.removeCell(position(1, 3));
    a.destroy();

    // Remove the third and fourth models
    display.removeModel(b);
    c.destroy();

    // Also: need to test anchors, but there isn't really a visible way... should probably be handled by the renderer
    // still TODO

});
