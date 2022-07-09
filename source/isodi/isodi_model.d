module isodi.isodi_model;

import raylib;
import std.format;

import isodi.utils;
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

        /// Texture used to send matrices to the model.
        ///
        /// The expected texture format is R32G32B32A32 (each pixel is a single matrix column). The image is to be 4
        /// pixels wide and as high as the model's bone count.
        ///
        /// Requires setting `bones` for each vertex.
        Texture2D matrixTexture;
        // TODO embed variant data in this texture as well. Using two booleans we could control if matrices are to be
        // embedded or not and dictate texture size based on that.

        /// If true, the model should "fold" the textures, letting them repeat automatically — used for block sides.
        int performFold;

        /// If true, the model will stay aligned to the camera on the Y camera-space axis.
        int flatten;

        /// If true, backface culling will be disabled. Used for rendering skeleton models.
        bool showBackfaces;

        /// Vertices making up the model.
        Vector3[] vertices;

        /// Atlas texture fragments mapped to each vertex.
        Rectangle[] variants;

        /// Texture coordinates within given variants.
        Vector2[] texcoords;

        /// Bone each vertex belongs to. Each should be a fraction (bone index/bone count).
        float[] bones;

        /// Triangles in the model, each is an index in the vertex array.
        ushort[3][] triangles;

    }

    private {

        /// ID of the uploaded array.
        uint vertexArrayID;

        /// ID of the bone buffer, if any.
        uint bonesBufferID;

    }

    private static {

        /// Shader used for the model.
        ///
        /// Note: Currently TLS'd but it might be thread-safe — I'm not sure. Regardless though GPU data should only be
        /// accessed from a single thread.
        uint _shader;

        // Locations of shader uniforms
        uint textureLoc;
        uint transformLoc;
        uint modelviewLoc;
        uint projectionLoc;
        uint colDiffuseLoc;
        uint performFoldLoc;
        uint flattenLoc;
        uint matrixTextureLoc;

    }

    immutable {

        /// Default fragment shader used to render the model.
        ///
        /// The data is null-terminated for C compatibility.
        immutable vertexShader = q{

            #version 330
            #define PI %s

            in vec3 vertexPosition;
            in vec2 vertexTexCoord;
            in vec4 vertexVariantUV;
            in float vertexBone;

            uniform mat4 transform;
            uniform mat4 modelview;
            uniform mat4 projection;
            uniform int flatten;
            uniform sampler2D matrixTexture;

            out vec2 fragTexCoord;
            out vec4 fragVariantUV;
            out vec2 fragAnchor;
            flat out int angle;

            /// Rotate a vector by a quaternion.
            /// See: https://stackoverflow.com/questions/9037174/glsl-rotation-with-a-rotation-vector/9037454#9037454
            vec4 rotate(vec4 vector, vec4 quat) {

                vec3 temp = cross(quat.xyz, vector.xyz) + quat.w * vector.xyz;
                return vector + vec4(2.0 * cross(quat.xyz, temp), 0.0);

            }

            void main() {

                // Send vertex attributes to fragment shader
                fragTexCoord = vertexTexCoord;
                fragVariantUV = vertexVariantUV;

                // Flatview: Camera transform (modelview) excluding vertex height
                mat4 flatview = modelview;
                flatview[0].y = 0;
                flatview[1].y = 1;
                flatview[2].y = 0;
                // Keep [3] to let translations (such as sharpview) through

                // Also correct Z result, required for proper angle checking
                flatview[1].z = 0;
                flatview[2].z /= modelview[1].y;
                // Note: I achieved this correction by experimenting. It might not be mathematically accurate, but
                // it looks good enough.

                // Set transform matrix, angle quaternion and angle index for this bone
                mat4 boneMatrix = mat4(1.0);
                vec4 boneQuat = vec4(0, 0, 0, 1);
                angle = 0;

                // If we do have bone data
                if (!isnan(vertexBone)) {

                    // Load the matrix
                    boneMatrix = mat4(
                        texture2D(matrixTexture, vec2(0.0/4, vertexBone)),
                        texture2D(matrixTexture, vec2(1.0/4, vertexBone)),
                        texture2D(matrixTexture, vec2(2.0/4, vertexBone)),
                        texture2D(matrixTexture, vec2(3.0/4, vertexBone))
                    );

                    // Get the normal in camera view, only as seen from top in 2D
                    vec2 normal = normalize(
                        (flatview * boneMatrix * vec4(0, 0, 1, 0)).xz
                    );

                    // Get the bone's orientation in the 2D plane (around Z axis)
                    float orientation = atan(normal.y, normal.x) + PI / 2;

                    // Snap the angle to texture angles
                    // TODO Use the bone's angle property
                    float snapped = round(orientation * 2 / PI);

                    // Revert the rotation for textures
                    angle = (4-int(snapped)) %% 4;

                    // Convert angle index to radians
                    orientation = snapped * PI / 2 / 2;

                    // Create a quaternion to counter the orientation
                    boneQuat = vec4(0, sin(orientation), 0, cos(orientation));

                }

                // Transform the vertex according to bone properties
                vec4 position = boneMatrix * rotate(vec4(vertexPosition, 1), boneQuat);

                // Set the anchor
                fragAnchor = position.xz;

                // Regular shape
                if (flatten == 0) {

                    // Calculate final vertex position
                    gl_Position = projection * modelview * transform * position;

                }

                // Flattened shape
                else {

                    // Sharp: Camera transform only affecting height
                    mat4 sharpview = mat4(
                        1, modelview[0].y, 0, 0,
                        0, modelview[1].y, 0, 0,
                        0, modelview[2].y, 1, 0,
                        0, modelview[3].y, 0, 1
                    );

                    // Calculate the final position in flat mode
                    gl_Position = projection * flatview * (

                        // Get the regular position
                        position

                        // Apply transform
                        + sharpview * (transform * vec4(1, 1, 1, 1) - vec4(1, 1, 1, 1))

                    );
                    // TODO Fix transform to work properly with rotations.

                }

            }


        }.format(raylib.PI) ~ '\0';

        /// Default fragment shader used to render the model.
        ///
        /// The data is null-terminated for C compatibility.
        immutable fragmentShader = q{

            #version 330

            in vec2 fragTexCoord;
            in vec4 fragVariantUV;
            in vec2 fragAnchor;
            flat in int angle;

            uniform sampler2D texture0;
            uniform vec4 colDiffuse;
            uniform mat4 transform;
            uniform mat4 modelview;
            uniform mat4 projection;
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

                // Apply angle offset
                offset.x += angle * size.x;

                // Fetch the data from the texture
                vec4 texelColor = texture(texture0, coords + offset);

                if (texelColor.w == 0) discard;

                // Set the color
                finalColor = texelColor * colDiffuse;

            }

            void setDepth() {

                // Change Y axis in the modelview matrix to (0, 1, 0, 0) so camera height doesn't affect depth
                // calculations
                mat4 flatview = modelview;
                flatview[0].y = 0;
                flatview[1].y = 1;
                flatview[2].y = 0;
                flatview[3].y = 0;
                mat4 flatform = transform;
                flatform[0].y = 0;
                flatform[1].y = 1;
                flatform[2].y = 0;
                flatform[3].y = 0;

                // Transform the anchor in the world
                vec4 anchor = flatview * flatform * vec4(fragAnchor.x, 0, fragAnchor.y, 1);

                // Get the clip space coordinates
                vec4 clip = projection * anchor * vec4(1, 0, 1, 1);

                // Convert to OpenGL's value range
                float depth = (clip.z / clip.w + 1) / 2.0;
                gl_FragDepth = gl_DepthRange.diff * depth + gl_DepthRange.near;

            }

            void main() {

                setDepth();
                setColor();

            }

        } ~ '\0';

    }

    /// Destroy the shader
    static ~this() @trusted @nogc {

        // Ignore if the window isn't open anymore
        if (!IsWindowReady) return;

        // Unload the shader (created lazily in makeShader)
        rlUnloadShaderProgram(shader);

    }

    /// Get the shader used by the model.
    static uint shader() @nogc => _shader;

    /// Prepare the model shader.
    ///
    /// Automatically performed when making the model.
    void makeShader() @trusted @nogc {

        assert(IsWindowReady, "Cannot create shader for IsodiModel, there's no window open");

        // Ignore if already constructed
        if (shader != 0) return;

        // Load the shader
        _shader = rlLoadShaderCode(vertexShader.ptr, fragmentShader.ptr);

        // Find locations
        textureLoc = rlGetLocationUniform(shader, "texture0");
        transformLoc = rlGetLocationUniform(shader, "transform");
        modelviewLoc = rlGetLocationUniform(shader, "modelview");
        projectionLoc = rlGetLocationUniform(shader, "projection");
        colDiffuseLoc = rlGetLocationUniform(shader, "colDiffuse");
        performFoldLoc = rlGetLocationUniform(shader, "performFold");
        flattenLoc = rlGetLocationUniform(shader, "flatten");
        matrixTextureLoc = rlGetLocationUniform(shader, "matrixTexture");

    }

    /// Upload the model to the GPU.
    void upload() @trusted
    in {

        // Check buffers
        assert(vertexArrayID == 0, "The model has already been uploaded");  // TODO: allow updates
        assert(vertices.length <= ushort.max, "Model cannot be drawn, too many vertices exist");
        assert(variants.length == vertices.length,
            format!"Variant count (%s) doesn't match vertex count (%s)"(variants.length, vertices.length));
        assert(texcoords.length == vertices.length,
            format!"Texcoord count (%s) doesn't match vertex count (%s)"(texcoords.length, vertices.length));

        // Check matrixTexture
        if (matrixTexture.id != 0) {

            assert(matrixTexture.width == 4,
                format!"Matrix texture width (%s) must be 4."(matrixTexture.width));
            assert(matrixTexture.height != 0, format!"Matrix texture height must not be 0.");
            assert(bones.length == vertices.length,
                format!"Bone count (%s) doesn't match vertex count (%s)"(bones.length, vertices.length));

        }

        else assert(bones.length == 0, "Vertex bone definitions are present, but no matrixTexture is attached");

    }
    do {

        uint registerBuffer(T)(T[] arr, const char* attribute, int type) {

            // Determine size of the type
            static if (__traits(compiles, T.tupleof)) enum length = T.tupleof.length;
            else enum length = 1;

            // Find location in the shader
            const location = rlGetLocationAttrib(shader, attribute);

            // If the array is empty
            if (arr.length == 0) {

                // For some reason type passed to rlSetVertexAttributeDefault doesn't match the one passed to
                // rlSetVertexAttribute. If you look into the Raylib code then you'll notice that the type argument is
                // actually completely unnecessary, but must match the length.
                // For this reason, this code path is only implemented for this case.
                assert(length == 1);
                // BTW DMD incorrectly emits a warning here, this is the reason silenceWarnings is set.

                const value = T.init;

                // Set a default value for the attribute
                rlSetVertexAttributeDefault(location, &value, rlShaderAttributeDataType.RL_SHADER_ATTRIB_FLOAT, length);
                rlDisableVertexAttribute(location);

                return 0;

            }

            // Load the buffer
            auto bufferID = rlLoadVertexBuffer(arr.ptr, cast(int) (arr.length * T.sizeof), false);

            // Stop if the attribute isn't set
            if (location == -1) return bufferID;

            // Assign to a shader attribute
            rlSetVertexAttribute(location, length, type, 0, 0, null);

            // Turn the attribute on
            rlEnableVertexAttribute(location);

            return bufferID;

        }

        // Prepare the shader
        makeShader();

        // Create the vertex array
        vertexArrayID = rlLoadVertexArray();
        rlEnableVertexArray(vertexArrayID);
        scope (exit) rlDisableVertexArray;

        // Send vertex positions
        registerBuffer(vertices, "vertexPosition", RL_FLOAT);
        registerBuffer(variants, "vertexVariantUV", RL_FLOAT);
        registerBuffer(texcoords, "vertexTexCoord", RL_FLOAT);
        bonesBufferID = registerBuffer(bones, "vertexBone", RL_FLOAT);
        rlLoadVertexBufferElement(triangles.ptr, cast(int) (triangles.length * 3 * ushort.sizeof), false);


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

        // Set data
        rlSetUniform(performFoldLoc, &performFold, Type.RL_SHADER_UNIFORM_INT, 1);
        rlSetUniform(flattenLoc, &flatten, Type.RL_SHADER_UNIFORM_INT, 1);

        // Set colDiffuse
        rlSetUniform(colDiffuseLoc, &properties.tint, Type.RL_SHADER_UNIFORM_VEC4, 1);

        /// Set active texture.
        void setTexture(int slot, int loc, Texture2D texture) {

            // Ignore if there isn't any
            if (texture.id == 0) return;

            rlActiveTextureSlot(slot);
            rlEnableTexture(texture.id);
            rlSetUniform(loc, &slot, Type.RL_SHADER_UNIFORM_INT, 1);

        }

        /// Disable the texture.
        void unsetTexture(int slot) {
            rlActiveTextureSlot(slot);
            rlDisableTexture;
        }

        // Set texture to use
        setTexture(0, textureLoc, texture);
        scope (exit) unsetTexture(0);

        // Set matrix texture
        setTexture(1, matrixTextureLoc, matrixTexture);
        scope (exit) unsetTexture(1);

        // Set transform matrix
        const transformMatrix = properties.transform
            .MatrixMultiply(rlGetMatrixTransform);
        rlSetUniformMatrix(transformLoc, transformMatrix);

        // Set model view & projection matrices
        rlSetUniformMatrix(modelviewLoc, rlGetMatrixModelview);
        rlSetUniformMatrix(projectionLoc, rlGetMatrixProjection);

        // Enable the vertex array
        const enabled = rlEnableVertexArray(vertexArrayID);
        assert(enabled, "Failed to enable a vertex array");
        scope (exit) rlDisableVertexArray;

        // Toggle backface culling
        if (showBackfaces) rlDisableBackfaceCulling();
        scope (exit) rlEnableBackfaceCulling();
        // Note: Reordering the vertices in the vertex shader in skeleton models doesn't appear achievable without
        // sending otherwise unnecessary data. So we disable it entirely instead.

        rlDrawVertexArrayElements(0, cast(int) triangles.length * 3, null);

    }

}
