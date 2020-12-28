module isodi.raylib.resources.side;

import raylib;

import std.string;
import std.random;

import isodi.cell;
import isodi.pack;

/// A side resource.
struct Side {

    // TODO: Implement cache.

    /// Owner object.
    Cell cell;

    /// Textures of each side.
    Texture2D[4] textures;

    /// Display scale of the sides.
    float[4] scale;

    /// Create the side and load resources.
    this(Cell cell) {

        this.cell = cell;

        // Create RNG
        const seed = cast(ulong) cell.position.toHash;
        Mt19937_64 rng;

        // Get possible sides
        const path = cell.type.format!"cells/%s/side/*.png";

        // Generate each side
        foreach (side; 0..4) {

            // Get a random file
            rng.seed(seed + side + 1);
            const file = cell.display.packs.packGlob(path).choice(rng);

            // Load the texture
            textures[side] = LoadTexture(file.toStringz);
            scale[side] = cast(float) cell.display.cellSize / textures[side].width;

        }

    }

    /// Draw the side
    void draw() {

        const cellSize = cell.display.cellSize;

        // Draw each side
        foreach (side; 0..4) {

            rlPushMatrix();

                // Transform
                {

                    // Move to an appropriate position
                    rlTranslatef(
                        cell.position.x * cellSize,
                        -cell.position.height.top * cellSize,
                        -(cell.position.y + 1) * cellSize
                    );

                    // Correct positions
                    rlTranslatef(
                        cellSize * (side == 1 || side == 2),
                        0,
                        cellSize * (side == 2 || side == 3)
                    );

                    // Rotate appropriately
                    rlRotatef(side * -90, 0, 1, 0);

                    // Scale to fit
                    rlScalef(scale[side], scale[side], scale[side]);

                    // Final corrections
                    rlTranslatef(0, 0, 1);

                }

                const texture = textures[side];
                const targetDepth = cell.position.height.depth * texture.width;

                float drawn = 0;
                size_t start = 0;

                // Draw the texture
                while (drawn < targetDepth) {

                    /// Space on the image that can be drawn
                    const drawAvailable = texture.height - start;

                    /// Space left to draw
                    const drawLeft = targetDepth - drawn;

                    /// Get space to draw
                    const drawSpace = drawLeft < drawAvailable
                        ? drawLeft
                        : drawAvailable;

                    rlPushMatrix();

                        // Push the texture down
                        rlTranslatef(0, drawn, 0);

                        // Draw the texture
                        textures[side].DrawTextureRec(
                            Rectangle(
                                0,             start,
                                texture.width, drawSpace,
                            ),
                            Vector2(0, 0),
                            Colors.WHITE
                        );

                    rlPopMatrix();

                    // Mark as drawn
                    drawn += drawSpace;

                    // Texture is higher than wide
                    if (!start && texture.height > texture.width) {

                        // Move start
                        start = texture.height - texture.width;

                    }

                }

                // TODO: change to DrawTextureRec

            rlPopMatrix();

        }

    }

}
