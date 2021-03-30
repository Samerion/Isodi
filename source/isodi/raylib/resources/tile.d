module isodi.raylib.resources.tile;

import raylib;

import std.string;
import std.exception;

import isodi.bind;
import isodi.pack;
import isodi.raylib.cell;
import isodi.raylib.internal;

/// A tile resource.
struct Tile {

    /// Owner object.
    RaylibCell cell;

    /// Loaded texture.
    Texture2D texture;

    /// Display scale of the tile.
    float scale;

    /// Tile options loaded
    const(ResourceOptions)* options;

    /// Create the tile and load textures.
    this(RaylibCell cell, Pack.Resource!string resource) {

        this.cell = cell;
        this.texture = LoadTexture(resource.match.toStringz);
        this.options = resource.options;
        this.scale = cast(float) cell.display.cellSize / texture.width;

    }

    /// Draw the tile
    void draw() {

        const cellSize = cell.display.cellSize;

        rlPushMatrix();

            // Move to the appropriate position
            rlTranslatef(cell.visualPosition.toTuple3(cellSize).expand);

            // Rotate to make it lay
            rlRotatef(90, 1, 0, 0);

            // Scale the tile to fit cell size
            rlScalef(scale, scale, scale);

            // Correct position
            rlTranslatef(0, 0, 1);

            // Draw
            texture.DrawTexture(0, 0, cell.color);

        rlPopMatrix();

    }

}
