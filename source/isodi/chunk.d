module isodi.chunk;

import raylib;

import std.range;
import std.format;

import isodi.utils;
import isodi.properties;


@safe:


/// Represents a chunk of blocks.
struct Chunk {

    /// Default fragment shader used to render chunks.
    ///
    /// The data is null-terminated for C compatibility.
    immutable fragmentShader = q{

        #version 330

        in vec2 fragTexCoord;
        in vec4 fragColor;

        uniform sampler2D texture0;
        uniform vec4 colDiffuse;

        out vec4 finalColor;

        void main() {

            // Texel color fetching from texture sampler
            vec4 texelColor = texture(texture0, fragTexCoord);

            finalColor = texelColor * colDiffuse;

        }

    } ~ '\0';

    public {

        /// Properties of the chunk.
        Properties properties;

        /// Mapping of block types to their position in the texture.
        BlockUV[BlockType] atlas;

    }

    private {

        /// Blocks making up the chunk.
        ///
        /// Note: Private, because the underlying structure might change, even at runtime. The lookup mechanism might
        /// switch to using regular arrays for a row of contiguous blocks.
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

                blocks[position.positionXY] = Block(type, blockPosition);

                // Update the position
                __traits(getMember, position, direction) += 1;

            }

            else static assert(false, format!"Unrecognized type %s"(typeid(T)));

        }

    }

    /// Generate a mesh for the chunk.
    ///
    /// The mesh must be manually freed using `UnloadMesh`
    Mesh makeMesh() @nogc @trusted const {

        // We must NOT allocate in the GC to prevent memory corruption when the mesh is unloaded

        const verticesPerBlock = 5*4;
        const trianglesPerBlock = 5*2;

        // Count vertices
        Mesh mesh;
        mesh.vertexCount = cast(int) blocks.length * verticesPerBlock;
        mesh.triangleCount = cast(int) blocks.length * trianglesPerBlock;
        // TODO Side culling; will have to change triangle count

        // TODO Verify mallocArray safety
        auto vertices  = mallocArray!Vector3(mesh.vertexCount);
        auto texcoords = mallocArray!Vector2(mesh.vertexCount);
        auto normals   = mallocArray!Vector3(mesh.vertexCount);
        auto indices   = mallocArray!ushort(mesh.triangleCount*3);

        // Add each block
        foreach (i, block; blocks.byValue.enumerate) {

            const position = Vector3(
                block.position.x,
                cast(float) block.position.height / properties.heightSteps,
                block.position.y,
            );

            const depth = -cast(float) block.position.depth / properties.heightSteps;

            // Vertices
            vertices.assign(i,

                // Tile
                position + Vector3(-0.5, 0, 0.5),
                position + Vector3(0.5, 0, 0.5),
                position + Vector3(0.5, 0, -0.5),
                position + Vector3(-0.5, 0, -0.5),

                // North side (negative Z)
                position + Vector3(0.5, depth, -0.5),
                position + Vector3(-0.5, depth, -0.5),
                position + Vector3(-0.5, 0, -0.5),
                position + Vector3(0.5, 0, -0.5),

                // East side (positive X)
                position + Vector3(0.5, depth, 0.5),
                position + Vector3(0.5, depth, -0.5),
                position + Vector3(0.5, 0, -0.5),
                position + Vector3(0.5, 0, 0.5),

                // South side (positive Z)
                position + Vector3(-0.5, depth, 0.5),
                position + Vector3(0.5, depth, 0.5),
                position + Vector3(0.5, 0, 0.5),
                position + Vector3(-0.5, 0, 0.5),

                // West side (negative X)
                position + Vector3(-0.5, depth, -0.5),
                position + Vector3(-0.5, depth, 0.5),
                position + Vector3(-0.5, 0, 0.5),
                position + Vector3(-0.5, 0, -0.5),

            );

            // UVs
            texcoords.assign(i,

                // Tile
                Vector2(0, 1),
                Vector2(0.5, 1),
                Vector2(0.5, 0),
                Vector2(0, 0),

                // North (-Z)
                Vector2(0.5, 1),
                Vector2(1, 1),
                Vector2(1, 0),
                Vector2(0.5, 0),

                // East (X)
                Vector2(0.5, 1),
                Vector2(1, 1),
                Vector2(1, 0),
                Vector2(0.5, 0),

                // Sorth (Z)
                Vector2(0.5, 1),
                Vector2(1, 1),
                Vector2(1, 0),
                Vector2(0.5, 0),

                // West (-X)
                Vector2(0.5, 1),
                Vector2(1, 1),
                Vector2(1, 0),
                Vector2(0.5, 0),

            );

            const normalIndex = i * trianglesPerBlock/2;

            // Normals
            normals.assign(normalIndex + 0, 4, Vector3( 0, 1,  0));  // Tile
            normals.assign(normalIndex + 1, 4, Vector3( 0, 1, -1));  // North (-Z)
            normals.assign(normalIndex + 2, 4, Vector3(+1, 1,  0));  // East (X)
            normals.assign(normalIndex + 3, 4, Vector3( 0, 1, +1));  // South (Z)
            normals.assign(normalIndex + 4, 4, Vector3(-1, 1,  0));  // West (-X)

            ushort value(ushort offset) => cast(ushort) (i*verticesPerBlock + offset);

            // Triangles (2 per rectangle)
            assign!value(indices, i,
                 0,  1,  2,   0,  2,  3,
                 4,  5,  6,   4,  6,  7,
                 8,  9, 10,   8, 10, 11,
                12, 13, 14,  12, 14, 15,
                16, 17, 18,  16, 18, 19,
            );

        }

        // Assign data
        mesh.vertices = cast(float*) vertices.ptr;
        mesh.texcoords = cast(float*) texcoords.ptr;
        mesh.normals = cast(float*) normals.ptr;
        mesh.indices = cast(ushort*) indices.ptr;

        // Send the mesh to the GPU
        UploadMesh(&mesh, false);

        return mesh;

    }

    /// Create a model with the chunk's mesh and an appropriate material.
    ///
    /// The model must be manually freed with `UnloadModel`. If this happens, the given texture will be removed along
    /// with the model.
    Model makeModel(return Texture2D texture) @nogc @trusted const {

        import std.algorithm;

        // Create the mesh
        auto meshes = mallocArray!Mesh(1);
        meshes[0] = makeMesh();

        // Create the material
        auto materials = mallocArray!Material(1);
        //{

            // Load the default material so we can make our own
            materials[0] = LoadMaterialDefault();

            // Load the shader
            // TODO check if it's possible to reuse a shader
            materials[0].shader = LoadShaderFromMemory(null, fragmentShader.ptr);

            // Initialize the important ones
            with (MaterialMapIndex) with (materials[0]) {
                maps[MATERIAL_MAP_ALBEDO].texture = texture;
                maps[MATERIAL_MAP_ALBEDO].color = Colors.WHITE;
                maps[MATERIAL_MAP_METALNESS].color = Colors.WHITE;
           }

        //}

        // Create an array binding meshes to materials
        auto bindings = mallocArray!int(1);
        bindings[0] = 0;

        // Load the data
        Model model = {
            transform: MatrixIdentity,
            meshCount: 1,
            meshes: meshes.ptr,
            materialCount: 1,
            materials: materials.ptr,
            meshMaterial: bindings.ptr,
        };

        debug {

            // We can GC-allocate in writeln, no need to care about that
            scope auto fundebug = delegate {

                import std.stdio;

            };
            (cast(void delegate() @nogc) fundebug)();

        }

        return model;

    }

}

struct Vector2L {

    long x, y;

}

struct BlockPosition {

    long x, y;
    long height, depth;

    Vector2L positionXY() const => Vector2L(x, y);

}

struct Block {

    BlockType type;
    BlockPosition position;

}

struct BlockType {

    ulong typeID;

}

/// Texture position data for given block.
///
/// Coordinates correspond to OpenGL shaders — (0,0) is the bottom-left corner of the texture, (1,1) is the top-right.
struct BlockUV {

    Rectangle tiles;
    Rectangle decoration;
    float tileSize;
    float decorationSize;

}
