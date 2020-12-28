module isodi.raylib.resources.tile;

import raylib;

import std.string;
import std.random;
import std.exception;

import isodi.bind;
import isodi.cell;
import isodi.pack;

/// A tile resource.
struct Tile {

    // Later: implement cache.

    /// Parent cell.
    Cell cell;

    /// Loaded texture.
    Texture2D texture;

    /// Display scale of the tile.
    float scale;

    /// Create the tile and load textures.
    this(Cell cell) {

        this.cell = cell;

        // Create RNG
        const seed = cast(ulong) cell.position.toHash;
        auto rng = Mt19937_64(seed);

        // Get a random file
        const path = cell.type.format!"cells/%s/tile/*.png";
        const file = cell.display.packs.packGlob(path).choice(rng);

        // Load the texture
        texture = LoadTexture(file.toStringz);
        scale = cast(float) cell.display.cellSize / texture.width;

    }

    /// Draw the tile
    void draw() {

        auto cellSize = cell.display.cellSize;

        rlPushMatrix();

            // Rotate to make it lay
            rlRotatef(-90, 1, 0, 0);

            // Move to the appropriate position
            rlTranslatef(
                cell.position.x * cellSize,
                cell.position.y * cellSize,
                scale - cell.position.height.top * cellSize
            );

            // Scale the tile to fit cell size
            rlScalef(scale, scale, scale);

            // Draw
            texture.DrawTexture(0, 0, Colors.WHITE);

        rlPopMatrix();

    }

}
