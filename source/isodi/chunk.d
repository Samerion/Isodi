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
    immutable vertexShader = q{

        #version 330

        in vec3 vertexPosition;
        in vec2 vertexTexCoord;
        in vec4 vertexColor;
        in vec4 vertexVariantUV;

        uniform mat4 mvp;

        out vec2 fragTexCoord;
        out vec4 fragColor;
        out vec4 fragVariantUV;

        void main() {

            // Send vertex attributes to fragment shader
            fragTexCoord = vertexTexCoord;
            fragColor = vertexColor;
            fragVariantUV = vertexVariantUV;

            // Calculate final vertex position
            gl_Position = mvp * vec4(vertexPosition, 1.0);

        }


    } ~ '\0';

    /// Default fragment shader used to render chunks.
    ///
    /// The data is null-terminated for C compatibility.
    immutable fragmentShader = q{

        #version 330

        in vec2 fragTexCoord;
        in vec4 fragColor;
        in vec4 fragVariantUV;

        uniform sampler2D texture0;
        uniform vec4 colDiffuse;

        out vec4 finalColor;

        void main() {

            // Get texture coordinates in the atlas
            vec2 coords = vec2(fragVariantUV.x, fragVariantUV.y);

            // Get offset by fragment coordinates (frac to repeat)
            vec2 offset = fract(fragTexCoord * vec2(fragVariantUV.z, fragVariantUV.w));

            // Texel color fetching from texture sampler
            vec4 texelColor = texture(texture0, coords + offset);

            finalColor = texelColor * colDiffuse;

        }

    } ~ '\0';

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

                blocks[position.vector] = Block(type, blockPosition);

                // Update the position
                __traits(getMember, position, direction) += 1;

            }

            else static assert(false, format!"Unrecognized type %s"(typeid(T)));

        }

    }

    /// Get texture area in the atlas to use for given block.
    RectangleL getTile(Vector2L position, BlockType type) @nogc @trusted const {

        // Get texture segment for this block
        const uv = type in atlas;
        assert(uv, "Chunk contains a block not present in texture");

        // Get tile variant to use
        const variant = randomVariant(
            Vector2L(uv.tileArea.width, uv.tileArea.height),
            Vector2L(uv.tileSize, uv.tileSize),
            seed + position.toHash,
        );

        return RectangleL(
            uv.tileArea.x + variant.x,
            uv.tileArea.y + variant.y,
            uv.tileSize,
            uv.tileSize,
        );

    }

    /// Make mesh for the chunk.
    Mesh makeMesh(Vector2 atlasSize, int variantAttributeLoc) @nogc @trusted const {

        // We must NOT allocate anything in the mesh with the GC to prevent memory corruption when the mesh is unloaded.

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
        auto variants  = mallocArray!Rectangle(mesh.vertexCount);
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

            // Get the variants
            const tileVariant = getTile(block.position.vector, block.type).toShader(atlasSize);

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
                Vector2(1, 1),
                Vector2(1, 0),
                Vector2(0, 0),

                // North (-Z)
                Vector2(0, 1),
                Vector2(1, 1),
                Vector2(1, 0),
                Vector2(0, 0),

                // East (X)
                Vector2(0, 1),
                Vector2(1, 1),
                Vector2(1, 0),
                Vector2(0, 0),

                // Sorth (Z)
                Vector2(0, 1),
                Vector2(1, 1),
                Vector2(1, 0),
                Vector2(0, 0),

                // West (-X)
                Vector2(0.5, 1),
                Vector2(1, 1),
                Vector2(1, 0),
                Vector2(0.5, 0),

            );

            const chunkIndex = i * trianglesPerBlock/2;

            // Variants
            variants.assign(chunkIndex + 0, 4, tileVariant);
            variants.assign(chunkIndex + 1, 4, tileVariant); // tiles for sides, temporarily
            variants.assign(chunkIndex + 2, 4, tileVariant);
            variants.assign(chunkIndex + 3, 4, tileVariant);
            variants.assign(chunkIndex + 4, 4, tileVariant);

            // Normals
            normals.assign(chunkIndex + 0, 4, Vector3( 0, 1,  0));  // Tile
            normals.assign(chunkIndex + 1, 4, Vector3( 0, 1, -1));  // North (-Z)
            normals.assign(chunkIndex + 2, 4, Vector3(+1, 1,  0));  // East (X)
            normals.assign(chunkIndex + 3, 4, Vector3( 0, 1, +1));  // South (Z)
            normals.assign(chunkIndex + 4, 4, Vector3(-1, 1,  0));  // West (-X)

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

        // Assign general data
        mesh.vertices = cast(float*) vertices.ptr;
        mesh.texcoords = cast(float*) texcoords.ptr;
        mesh.normals = cast(float*) normals.ptr;
        mesh.indices = cast(ushort*) indices.ptr;

        // Send the mesh to the GPU
        UploadMesh(&mesh, false);

        rlEnableVertexArray(mesh.vaoId);
        scope (exit) rlDisableVertexArray();

        // Assign variants
        // Warning: NOT FREED
        // TODO: Make Chunk a Mesh superset with `LoadChunk` and `UnloadChunk` functions
        const bufferSize = cast(int) (variants.length * variants[0].sizeof);
        const bufferID = rlLoadVertexBuffer(variants.ptr, bufferSize, false);
        rlSetVertexAttribute(variantAttributeLoc, 4, RL_FLOAT, 0, 0, null);
        rlEnableVertexAttribute(variantAttributeLoc);

        return mesh;

    }

    Model makeModel(return Texture2D texture) @nogc @trusted const {

        import std.algorithm;

        // Create the shader
        auto shader = LoadShaderFromMemory(vertexShader.ptr, fragmentShader.ptr);

        // Find variant location
        auto variantLoc = GetShaderLocationAttrib(shader, "vertexVariantUV");

        // Create the mesh
        auto meshes = mallocArray!Mesh(1);
        meshes[0] = makeMesh(Vector2(texture.width, texture.height), variantLoc);

        // Create the material
        auto materials = mallocArray!Material(1);
        {

            // Load the default material so we can make our own
            materials[0] = LoadMaterialDefault();

            // Load the shader
            // TODO check if it's possible to reuse a shader
            materials[0].shader = shader;

            // Initialize the important ones
            with (MaterialMapIndex) with (materials[0]) {
                maps[MATERIAL_MAP_ALBEDO].texture = texture;
                maps[MATERIAL_MAP_ALBEDO].color = Colors.WHITE;
                maps[MATERIAL_MAP_METALNESS].color = Colors.WHITE;
           }

        }

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
    RectangleL decorationArea;
    uint tileSize;
    uint decorationSize;

}
