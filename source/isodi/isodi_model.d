module isodi.isodi_model;

import raylib;
import std.format;

import isodi.properties;


@safe:


/// This struct represents an Isodi model uploaded to the GPU. Its resources are managed by Isodi and must NOT be
/// cleaned up with Raylib functions, with the exception of the texture.
struct IsodiModel {

    public {

        /// Rendering properties of the model.
        Properties properties;

        /// Atlas texture to be used by the model. Will NOT be freed along with the model.
        Texture2D texture;

        /// If true, the model should "fold" the textures, letting them repeat automatically — used for block sides.
        int performFold;

        /// Vertices making up the model.
        Vector3[] vertices;

        /// Atlas texture fragments mapped to each vertex.
        Rectangle[] variants;

        /// Texture coordinates within given variants.
        Vector2[] texcoords;

        /// Normals of each model face.
        Vector3[] normals;

        /// Position of the middle of each face on the Z axis. Used to calculate face depth.
        Vector2[] anchors;

        /// Triangles in the model, each is an index in the vertex array.
        ushort[3][] triangles;

    }

    private {

        /// ID of the uploaded array.
        uint vertexArrayID;

        // IDs of each buffer.
        uint verticesBufferID;
        uint variantsBufferID;
        uint texcoordsBufferID;
        uint normalsBufferID;
        uint anchorsBufferID;
        uint trianglesBufferID;

    }

    private static {

        /// Shader used for the model.
        ///
        /// Note: Currently TLS'd but it might be thread-safe — I'm not sure.
        uint shader;

        // Locations of shader uniforms.
        uint textureLoc;
        uint transformLoc;
        uint mvpLoc;
        uint colDiffuseLoc;
        uint performFoldLoc;

    }

    immutable {

        /// Default fragment shader used to render the model.
        ///
        /// The data is null-terminated for C compatibility.
        immutable vertexShader = q{

            #version 330

            in vec3 vertexPosition;
            in vec2 vertexTexCoord;
            in vec4 vertexVariantUV;
            in vec2 vertexAnchor;

            uniform mat4 transform;
            uniform mat4 mvp;

            out vec2 fragTexCoord;
            out vec4 fragVariantUV;
            out vec2 fragAnchor;

            void main() {

                // Send vertex attributes to fragment shader
                fragTexCoord = vertexTexCoord;
                fragVariantUV = vertexVariantUV;
                fragAnchor = vertexAnchor;

                // Calculate final vertex position
                gl_Position = mvp * transform * vec4(vertexPosition, 1.0);

            }


        } ~ '\0';

        /// Default fragment shader used to render the model.
        ///
        /// The data is null-terminated for C compatibility.
        immutable fragmentShader = q{

            #version 330

            in vec2 fragTexCoord;
            in vec4 fragVariantUV;
            in vec2 fragAnchor;

            uniform sampler2D texture0;
            uniform vec4 colDiffuse;
            uniform mat4 transform;
            uniform mat4 mvp;
            uniform int performFold;

            out vec4 finalColor;

            void setColor() {

                // Get texture coordinates in the atlas
                vec2 coords = vec2(fragVariantUV.x, fragVariantUV.y);

                // Get size of the texture
                vec2 size = vec2(fragVariantUV.z, fragVariantUV.w);

                vec2 offset;

                // No folding, render like normal
                if (performFold == 0) {

                    // Set the offset in the region with no special overrides
                    offset = fragTexCoord * size;

                }

                // Perform fold
                else {

                    // Get texture ratio
                    vec2 ratio = vec2(1, size.y / size.x);

                    // Get segment where the texture starts to repeat
                    vec2 fold = vec2(0, size.y - size.x);

                    // Get offset 1. until the fold
                    offset = min(fold, fragTexCoord * size / ratio)

                        // 2. repeat after the fold
                        + fract(max(vec2(0), fragTexCoord - ratio + 1))*size.x;

                }

                // Fetch the data from the texture
                vec4 texelColor = texture(texture0, coords + offset);

                if (texelColor.w == 0) discard;

                // Set the color
                finalColor = texelColor * colDiffuse;

            }

            void setDepth() {

                vec4 anchor = transform * vec4(fragAnchor.x, 0, fragAnchor.y, 0);
                vec4 clip = mvp * vec4(anchor.x, 0, anchor.z, 1);
                float depth = (clip.z / clip.w + 1) / 2.0;
                gl_FragDepth = gl_DepthRange.diff * depth + gl_DepthRange.near;
                //gl_FragDepth = 1;
                //finalColor = vec4(vec3(depth), 1);

            }

            void main() {

                setDepth();
                setColor();

            }

        } ~ '\0';

    }

    /// Destroy the shader
    static ~this() @trusted {

        // Ignore if the window isn't open anymore
        if (!IsWindowReady) return;

        // Unload the shader (created lazily in makeShader)
        rlUnloadShaderProgram(shader);

    }

    /// Prepare the model shader
    private void makeShader() @trusted {

        assert(IsWindowReady, "Cannot create shader for IsodiModel, there's no window open");

        // Ignore if already constructed
        if (shader != 0) return;

        // Load the shader
        shader = rlLoadShaderCode(vertexShader.ptr, fragmentShader.ptr);

        // Find locations
        textureLoc = rlGetLocationUniform(shader, "texture0");
        transformLoc = rlGetLocationUniform(shader, "transform");
        mvpLoc = rlGetLocationUniform(shader, "mvp");
        colDiffuseLoc = rlGetLocationUniform(shader, "colDiffuse");
        performFoldLoc = rlGetLocationUniform(shader, "performFold");

    }

    /// Upload the model to the GPU.
    void upload() @trusted
    in (vertexArrayID == 0, "The model has already been uploaded")  // TODO: allow updates
    in (vertices.length <= ushort.max, "Model cannot be drawn, too many vertices exist")
    in (variants.length == vertices.length,
        format!"Variant count (%s) doesn't match vertex count (%s)"(variants.length, vertices.length))
    in (texcoords.length == vertices.length,
        format!"Texcoord count (%s) doesn't match vertex count (%s)"(texcoords.length, vertices.length))
    in (normals.length == vertices.length,
        format!"Normal count (%s) doesn't match vertex count (%s)"(normals.length, vertices.length))
    in (anchors.length == vertices.length,
        format!"Anchor count (%s) doesn't match vertex count (%s)"(anchors.length, vertices.length))
    do {

        uint registerBuffer(T)(T[] arr, const char* attribute, int type) {

            // Load the buffer
            auto bufferID = rlLoadVertexBuffer(arr.ptr, cast(int) (arr.length * T.sizeof), false);

            // Find location in the shader
            const location = rlGetLocationAttrib(shader, attribute);

            // Stop if the attribute isn't set
            if (location == -1) return bufferID;

            // Assign to a shader attribute
            rlSetVertexAttribute(location, T.tupleof.length, type, 0, 0, null);

            // Turn the attribute on
            rlEnableVertexAttribute(location);

            return bufferID;

        }

        // Dunno what this does
        const dynamic = false;

        // Prepare the shader
        makeShader();

        // Create the vertex array
        vertexArrayID = rlLoadVertexArray();
        rlEnableVertexArray(vertexArrayID);
        scope (exit) rlDisableVertexArray;

        // Send vertex positions
        verticesBufferID = registerBuffer(vertices, "vertexPosition", RL_FLOAT);
        variantsBufferID = registerBuffer(variants, "vertexVariantUV", RL_FLOAT);
        texcoordsBufferID = registerBuffer(texcoords, "vertexTexCoord", RL_FLOAT);
        //normalsBufferID = registerBuffer(normals, "vertexNormal", RL_FLOAT);
        anchorsBufferID = registerBuffer(anchors, "vertexAnchor", RL_FLOAT);
        trianglesBufferID = rlLoadVertexBufferElement(triangles.ptr, cast(int) (triangles.length * 3 * ushort.sizeof),
            false);


    }

    /// Draw the model.
    ///
    /// Note: Each vertex in the model will be drawn as if it was on Y=0. It is recommended you draw other Isodi objects
    /// in order of height.
    void draw() const @trusted @nogc
    in (vertices.length <= ushort.max, "This model cannot be drawn, too many vertices exist")
    do {

        alias Type = rlShaderUniformDataType;

        // Update the shader
        rlEnableShader(shader);
        scope (exit) rlDisableShader();

        // Set colDiffuse
        float[4] colDiffuse = [properties.tint.tupleof] / 255f;
        rlSetUniform(colDiffuseLoc, &colDiffuse, Type.RL_SHADER_UNIFORM_VEC4, 1);

        // Set fold
        rlSetUniform(performFoldLoc, &performFold, Type.RL_SHADER_UNIFORM_INT, 1);

        // Set texture to use
        int slot = 0;
        rlActiveTextureSlot(slot);
        rlEnableTexture(texture.id);
        rlSetUniform(textureLoc, &slot, Type.RL_SHADER_UNIFORM_INT, 1);
        scope (exit) rlDisableTexture;

        // Set transform matrix
        const transformMatrix = properties.transform
            .MatrixMultiply(rlGetMatrixTransform);
        rlSetUniformMatrix(transformLoc, transformMatrix);

        // Set model view projection matrix
        const mvpMatrix = rlGetMatrixModelview
            .MatrixMultiply(rlGetMatrixProjection);
        rlSetUniformMatrix(mvpLoc, mvpMatrix);

        // Enable the vertex array
        const enabled = rlEnableVertexArray(vertexArrayID);
        assert(enabled, "Failed to enable a vertex array");
        scope (exit) rlDisableVertexArray;

        rlDrawVertexArrayElements(0, cast(int) triangles.length * 3, null);

    }

}
