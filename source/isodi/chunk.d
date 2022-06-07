module isodi.chunk;

import raylib;

import std.range;
import std.format;

import isodi.utils;
import isodi.properties;


@safe:


/// Represents a chunk of blocks.
struct Chunk {

    Properties properties;

    /// Blocks making up the chunk.
    ///
    /// Note: Private, because the underlying structure might change, even at runtime. The lookup mechanism might switch
    /// to using regular arrays for a row of contiguous blocks.
    private Block[BlockPosition] blocks;

    inout(Block*) find(BlockPosition position) inout {

        return position in blocks;

    }

    /// Add multiple items.
    ///
    /// * Pass a `BlockPosition` to change the position of the following blocks.
    /// * Pass a `BlockType*` to change the type of the following blocks.
    /// * Pass a `long` to add a new block with given height. Increment X or Y of the block position, respectively for
    ///   the function used.
    void addX(T...)(T items) => addImpl!"x"(items);

    /// ditto
    void addY(T...)(T items) => addImpl!"y"(items);

    void addImpl(string direction, T...)(T items) {

        BlockPosition position;
        BlockType* type;

        foreach (item; items) {

            alias T = typeof(item);

            // Changing position
            static if (is(T : BlockPosition)) {

                position = item;

            }

            // Changing type
            else static if (is(T : BlockType*)) {

                type = item;

            }

            // Adding block
            else static if (is(T : long)) {

                blocks[position] = Block(type, position, item);

                // Update the position
                __traits(getMember, position, direction) += 1;

            }

            else static assert(false, format!"Unrecognized type %s"(typeid(T)));

        }

    }

    /// Generate a mesh for the chunk. Does not upload the mesh.
    Mesh makeMesh() @nogc @trusted {//pure {

        // We must NOT allocate in the GC to prevent memory corruption when the mesh is unloaded.

        Mesh mesh;

        // Count vertices
        mesh.vertexCount = cast(int) blocks.length * 4;
        mesh.triangleCount = cast(int) blocks.length * 2;
        // Note: Those values will change in the future, and might decrease in the runtime with culling.
        // realloc will be necessary.

        auto vertices  = mallocArray!Vector3(mesh.vertexCount);
        auto texcoords = mallocArray!Vector2(mesh.vertexCount);
        auto normals   = mallocArray!Vector3(mesh.vertexCount);
        auto indices   = mallocArray!ushort(mesh.triangleCount*3);

        /// Add each block.
        foreach (i, block; blocks.byValue.enumerate) {

            const position = Vector3(
                block.position.x,
                cast(float) block.height / properties.heightSteps,
                block.position.y,
            );

            assign(vertices, i,
                position + Vector3(-0.5, 0, -0.5),
                position + Vector3(-0.5, 0, 0.5),
                position + Vector3(0.5, 0, 0.5),
                position + Vector3(0.5, 0, -0.5),
            );

            assign(texcoords, i,
                Vector2(0, 0),
                Vector2(0.5, 0),
                Vector2(0.5, 1),
                Vector2(0, 1),
            );

            normals[4*i .. 4*i+4] = Vector3(0, 1, 0);

            ushort value(ushort offset) => cast(ushort) (i*4 + offset);

            assign!value(indices, i, 0, 1, 2, 0, 2, 3);

        }

        mesh.vertices = cast(float*) vertices.ptr;
        mesh.texcoords = cast(float*) texcoords.ptr;
        mesh.normals = cast(float*) normals.ptr;
        mesh.indices = cast(ushort*) indices.ptr;

        return mesh;

    }

}

struct BlockPosition {

    long x, y;

}

struct Block {

    BlockType* type;
    BlockPosition position;
    long height;

}

// Note: this struct should be provided by the pack.
struct BlockType {

    string name;

}
