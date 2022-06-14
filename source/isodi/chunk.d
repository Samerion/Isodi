module isodi.chunk;

import raylib;

import std.meta;
import std.range;
import std.format;

import isodi.utils;
import isodi.properties;
import isodi.chunk_model;


@safe:


/// Represents a chunk of blocks.
struct Chunk {

    public {

        /// Properties of the chunk.
        Properties properties;

        /// Seed to use to generate variants on this chunk.
        ulong seed;

        /// Mapping of block types to their position in the texture.
        BlockUV[BlockType] atlas;

    }

    private {

        /// Blocks making up the chunk.
        ///
        /// Note: Private, because the underlying structure might change, even at runtime. The lookup mechanism might
        /// switch to using regular arrays for a row of contiguous blocks. (not implemented)
        Block[Vector2L] blocks;

    }

    inout(Block*) find(Vector2L position) inout {

        return position in blocks;

    }

    /// Add multiple items.
    ///
    /// * Pass a `BlockPosition` to change the position of the following blocks.
    /// * Pass a `BlockType` to change the type of the following blocks.
    /// * Pass a `long` to add a new block with given height. Increment X or Y of the block position, respectively for
    ///   the function used.
    void addX(T...)(T items) => addImpl!"x"(items);

    /// ditto
    void addY(T...)(T items) => addImpl!"y"(items);

    void addImpl(string direction, T...)(T items) {

        BlockPosition position;
        BlockType type;

        foreach (item; items) {

            alias T = typeof(item);

            // Changing position
            static if (is(T : BlockPosition)) {

                position = item;

            }

            // Changing type
            else static if (is(T : BlockType)) {

                type = item;

            }

            // Adding block
            else static if (is(T : long)) {

                auto blockPosition = position;
                blockPosition.height = item;

                blocks[position.vector] = Block(type, blockPosition);

                // Update the position
                __traits(getMember, position, direction) += 1;

            }

            else static assert(false, format!"Unrecognized type %s"(typeid(T)));

        }

    }

    /// Make model for the chunk.
    ChunkModel makeModel(return Texture2D texture) const {

        import core.lifetime;

        const atlasSize = Vector2(texture.width, texture.height);

        // Render data per block
        const verticesPerBlock = 5*4;
        const trianglesPerBlock = 5*2;

        // Total data
        const vertexCount = blocks.length * verticesPerBlock;
        const triangleCount = blocks.length * trianglesPerBlock;

        // Prepare the model
        ChunkModel model = {
            properties: properties,
            texture: texture,
        };
        model.vertices.length = vertexCount;
        model.variants.length = vertexCount;
        model.texcoords.length = vertexCount;
        model.normals.length = vertexCount;
        model.anchors.length = vertexCount;
        model.triangles.length = triangleCount;
        // TODO: side culling

        // Add each block
        foreach (i, block; blocks.byValue.enumerate) with (model) {

            const position = Vector3(
                block.position.x,
                cast(float) block.position.height / properties.heightSteps,
                block.position.y,
            );

            const depth = cast(float) block.position.depth / properties.heightSteps;

            // Vertices
            vertices.assignChunk(i,

                // Tile
                position + Vector3(-0.5, 0, 0.5),
                position + Vector3(0.5, 0, 0.5),
                position + Vector3(0.5, 0, -0.5),
                position + Vector3(-0.5, 0, -0.5),

                // North side (negative Z)
                position + Vector3(0.5, -depth, -0.5),
                position + Vector3(-0.5, -depth, -0.5),
                position + Vector3(-0.5, 0, -0.5),
                position + Vector3(0.5, 0, -0.5),

                // East side (positive X)
                position + Vector3(0.5, -depth, 0.5),
                position + Vector3(0.5, -depth, -0.5),
                position + Vector3(0.5, 0, -0.5),
                position + Vector3(0.5, 0, 0.5),

                // South side (positive Z)
                position + Vector3(-0.5, -depth, 0.5),
                position + Vector3(0.5, -depth, 0.5),
                position + Vector3(0.5, 0, 0.5),
                position + Vector3(-0.5, 0, 0.5),

                // West side (negative X)
                position + Vector3(-0.5, -depth, -0.5),
                position + Vector3(-0.5, -depth, 0.5),
                position + Vector3(-0.5, 0, 0.5),
                position + Vector3(-0.5, 0, -0.5),

            );

            const chunkIndex = i * trianglesPerBlock/2;

            // UVs — tile
            texcoords.assignChunk(chunkIndex + 0,
                Vector2(0, 1),
                Vector2(1, 1),
                Vector2(1, 0),
                Vector2(0, 0),
            );

            // UVs — sides
            foreach (j; 1..5) texcoords.assignChunk(chunkIndex + j,
                Vector2(0, depth),
                Vector2(1, depth),
                Vector2(1, 0),
                Vector2(0, 0),
            );

            // Normals
            normals.assign(chunkIndex + 0, 4, Vector3( 0, 1,  0));  // Tile
            normals.assign(chunkIndex + 1, 4, Vector3( 0, 1, -1));  // North (-Z)
            normals.assign(chunkIndex + 2, 4, Vector3(+1, 1,  0));  // East (X)
            normals.assign(chunkIndex + 3, 4, Vector3( 0, 1, +1));  // South (Z)
            normals.assign(chunkIndex + 4, 4, Vector3(-1, 1,  0));  // West (-X)

            // Anchors
            anchors.assign(i, 5*4, Vector2(position.x, position.z));

            // Get the variants
            const blockUV = block.type in atlas;
            assert(blockUV, format!"%s is not present in chunk atlas"(block.type));

            // Tile variant
            const tileVariant = blockUV.getTile(block.position.vector, seed).toShader(atlasSize);
            variants.assign(chunkIndex + 0, 4, tileVariant);

            // Side variant
            foreach (j; 1..5) {

                const sideVariant = blockUV.getSide(block.position.vector, seed+j).toShader(atlasSize);
                variants.assign(chunkIndex + j, 4, sideVariant);

            }

            ushort[3] value(int[] offsets) => [
                cast(ushort) (i*verticesPerBlock + offsets[0]),
                cast(ushort) (i*verticesPerBlock + offsets[1]),
                cast(ushort) (i*verticesPerBlock + offsets[2]),
            ];

            // Triangles (2 per rectangle)
            assignChunk!value(triangles, i,
                [ 0,  1,  2],  [ 0,  2,  3],
                [ 4,  5,  6],  [ 4,  6,  7],
                [ 8,  9, 10],  [ 8, 10, 11],
                [12, 13, 14],  [12, 14, 15],
                [16, 17, 18],  [16, 18, 19],
            );

        }

        // Upload the model
        model.upload();

        // Return it
        return model;

    }

}

struct BlockPosition {

    long x, y;
    long height, depth;

    Vector2L vector() @nogc const => Vector2L(x, y);

}

struct Block {

    BlockType type;
    BlockPosition position;

}

struct BlockType {

    /// Global user-defined block ID.
    ulong typeID;

}

/// Texture position data for given block.
struct BlockUV {

    RectangleL tileArea;
    RectangleL sideArea;
    uint tileSize;
    uint sideSize;

    /// Get random tile variant within the UV.
    RectangleL getTile(Vector2L position, ulong seed) @nogc @trusted const {

        // Get tile variant to use
        const variant = randomVariant(
            Vector2L(tileArea.width, tileArea.height),
            Vector2L(tileSize, tileSize),
            seed + position.toHash,
        );

        return RectangleL(
            tileArea.x + variant.x,
            tileArea.y + variant.y,
            tileSize,
            tileSize,
        );

    }

    /// Get random side variant within the UV.
    RectangleL getSide(Vector2L position, ulong seed) @nogc @trusted const {

        // Get tile variant to use
        const variant = randomVariant(
            Vector2L(sideArea.width, sideArea.height),
            Vector2L(tileSize, sideSize),
            seed + position.toHash,
        );

        return RectangleL(
            sideArea.x + variant.x,
            sideArea.y + variant.y,
            tileSize,
            sideSize,
        );

    }

}
