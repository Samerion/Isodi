module isodi.raylib.resources.decoration;

import raylib;

import std.string;
import std.random;
import std.typecons;
import std.exception;

import isodi.bind;
import isodi.cell;
import isodi.pack;
import isodi.raylib.cell;
import isodi.raylib.display;
import isodi.raylib.internal;


@safe:


private struct DecoPart {
    int x, y;
    Texture2D texture;
    const(ResourceOptions)* options;
    float scale;
    float direction;
}

/// A decoration resource.
struct Decoration {

    /// Owner object.
    RaylibCell cell;

    /// Loaded decorations
    DecoPart[] parts;

    /// Create the tile and load textures.
    this(RaylibCell cell, Pack.Resource!string[] resources) {

        this.cell = cell;

        Mt19937_64 rng;

        foreach (i, resource; resources) {

            // Load the texture
            auto texture = cell.display.loadTexture(resource.match);

            // Get direction of the decoration piece
            rng.seed(cell.seed + 100 + 10*i);
            const direction = uniform(0, 360, rng);

            // Create the decoration
            parts ~= DecoPart(
                randomPosition(texture, resource.options, cell.seed + 101 + 10*i).expand,
                texture, resource.options,
                cast(float) cell.display.cellSize / resource.options.tileSize,
                direction,
            );

        }

    }

    /// Get a random position for the decoration piece.
    private Tuple!(int, int) randomPosition(ref Texture2D texture, const ResourceOptions* options, ulong seed) {

        // Get the tile and decoration size
        const tileSize = cell.tile.texture.width;
        const hardArea = options.hardArea != options.hardArea.init
            ? options.hardArea
            : cast(const int[4]) [
                texture.width / 2 / options.angles,
                0,
                1,
                1,
            ];

        // Create an RNG
        Mt19937_64 rng;

        // Get a random position for the top-left corner of the hard area
        rng.seed(seed);
        const int x = uniform!"[]"(0, tileSize - hardArea[2], rng);

        rng.seed(seed + 1);
        const int y = uniform!"[]"(0, tileSize - hardArea[2], rng);

        // Get a position in the bounds
        return tuple(
            x - cast(int) hardArea[0],
            y - cast(int) hardArea[0],
        );

    }

    /// Draw the decoration
    void draw() @trusted {

        const cellSize = cell.display.cellSize;

        foreach (deco; parts) {

            rlPushMatrix();
            scope (exit) rlPopMatrix();

            import std.conv : to;

            const angleDelimiter = 360 / deco.options.angles;
            const rotation = cell.display.camera.angle.x + deco.direction;
            const angle = to!uint(rotation / angleDelimiter  +  0.5);

            const atlasWidth = deco.texture.width / deco.options.angles;
            const tileScale = cell.tile.scale;

            // Translate to the correct position
            rlTranslatef(cell.visualPosition.toTuple3(cellSize).expand);

            // Place within the tile
            rlTranslatef(
              deco.x * tileScale,
              0,
              deco.y * tileScale,
            );

            // Scale the tile to fit cell size
            rlScalef(deco.scale, deco.scale, deco.scale);

            // Counter camera rotation
            rlTranslatef(atlasWidth/2.0, 0, atlasWidth/2.0);
            rlRotatef(cell.display.camera.angle.x + 180, 0, 1, 0);
            rlTranslatef(atlasWidth/-2.0, 0, 0);
            rlRotatef(cell.display.camera.angle.y, 1, 0, 0);

            // Correct position
            rlTranslatef(atlasWidth, deco.texture.height, 1);

            // Draw
            DrawTexturePro(
                deco.texture,
                Rectangle(
                    atlasWidth * angle, 0,
                    atlasWidth, deco.texture.height
                ),
                Rectangle(
                    0, 0,
                    atlasWidth, deco.texture.height
                ),
                Vector2(),
                180,
                cell.color
            );

        }

    }

}
