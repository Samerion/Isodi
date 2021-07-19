module isodi.raylib.resources.side;

import raylib;

import std.string;
import std.random;

import isodi.pack;
import isodi.raylib.cell;
import isodi.raylib.internal;

/// A side resource.
struct Side {

    /// Owner object.
    RaylibCell cell;

    /// Textures of each side.
    Texture2D[4] textures;

    /// Display scale of the sides.
    float[4] scale;

    /// Create the side and load resources.
    this(RaylibCell cell, Pack.Resource!string[4] resources) {

        this.cell = cell;

        foreach (side, resource; resources) {

            // Load the texture
            textures[side] = cell.display.loadTexture(resource.match);
            scale[side] = cast(float) cell.display.cellSize / textures[side].width;

        }

    }

    /// Draw the side
    void draw() {

        const cellSize = cell.display.cellSize;

        const leftSide  = cast(short) (360+180 - cell.display.camera.angle.x) / 90 % 4;
        const rightSide = (leftSide + 1) % 4;

        // Draw each side
        foreach (side; [leftSide, rightSide]) {

            // If there's a neighbor on this side
            if (auto neighbor = cell.getNeighbor(cast(ubyte) side)) {

                auto thisHeight = cell.position.height;
                auto neighborHeight = neighbor.position.height;

                // And it covers the the side of this cell, don't render
                if (neighborHeight.top >= thisHeight.top
                    && neighborHeight.depth + neighborHeight.top >= thisHeight.depth) continue;

            }

            rlPushMatrix();

                // Transform
                {

                    // Move to an appropriate position
                    rlTranslatef(cell.visualPosition.toTuple3(cellSize).expand);

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
                const targetDepth = cell.visualPosition.height.depth * texture.width;

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
                        rlTranslatef(0, -drawSpace - drawn, 0);

                        // Draw the texture
                        textures[side].DrawTextureRec(
                            Rectangle(
                                0,             start,
                                texture.width, -drawSpace,
                            ),
                            Vector2(0, 0),
                            cell.color,
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

            rlPopMatrix();

        }

    }

}
