module isodi.raylib.resources.tile;

import raylib;

import std.string;
import std.random;
import std.exception;

import isodi.bind;
import isodi.cell;
import isodi.pack;
import isodi.raylib.internal;

/// A tile resource.
struct Tile {

    /// Owner object.
    Cell cell;

    /// Loaded texture.
    Texture2D texture;

    /// Display scale of the tile.
    float scale;

    /// Tile optoins loaded
    const(ResourceOptions)* options;

    /// Create the tile and load textures.
    this(Cell cell) {

        this.cell = cell;

        // Create RNG
        const seed = cast(ulong) cell.position.toHash;
        auto rng = Mt19937_64(seed);

        // Get a random file
        const path = cell.type.format!"cells/%s/tile/*.png";
        auto glob = cell.display.packs.packGlob(path);
        const file = glob.matches.choice(rng);
        options = glob.pack.getOptions(file);

        // Load the texture
        texture = LoadTexture(file.toStringz);
        scale = cast(float) cell.display.cellSize / texture.width;

    }

    /// Draw the tile
    void draw() {

        const cellSize = cell.display.cellSize;

        rlPushMatrix();

            // Move to the appropriate position
            rlTranslatef(cell.position.toTuple3(cellSize).expand);

            // Rotate to make it lay
            rlRotatef(-90, 1, 0, 0);

            // Scale the tile to fit cell size
            rlScalef(scale, scale, scale);

            // Correct position
            rlTranslatef(0, 0, 1);

            // Draw
            texture.DrawTexture(0, 0, Colors.WHITE);

        rlPopMatrix();

    }

}
