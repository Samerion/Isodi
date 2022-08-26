module isodi.tests;

import isodi;
import raylib;
import core.runtime;

import std.file;
import std.stdio;


@system:
version (unittest):


// This never detects anything useful. Only false-positives.
private extern(C) __gshared string[] rt_options = ["oncycle=ignore"];

shared static this() {

    // Redirect to our main
    Runtime.extendedModuleUnitTester = {

        // Run tests
        UnitTestResult result;
        foreach (m; ModuleInfo) {

            if (!m) continue;

            // If the module has unittests
            if (m.unitTest) try {

                // Run them
                ++result.executed;
                m.unitTest()();
                ++result.passed;

            }

            // Print exceptions
            catch (Throwable e) writeln(e);

        }

        // Run main if all tests pass
        result.runMain = result.executed == result.passed;

        // Print the results
        result.summarize = true;

        return result;

    };

}


void main() {

    Runtime.extendedModuleUnitTester = null;

    // Create the window
    SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
    SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE);
    InitWindow(1600, 900, "Isodi test runner");
    SetWindowMinSize(800, 600);
    SetTargetFPS(60);
    scope (exit) CloseWindow();

    /// Prepare the camera
    CameraController controller;
    CameraKeybindings cameraKeys = {

        zoomIn:  KeyboardKey.KEY_EQUAL,
        zoomOut: KeyboardKey.KEY_MINUS,

        moveForward:  KeyboardKey.KEY_W,
        moveBackward: KeyboardKey.KEY_S,
        moveLeft:     KeyboardKey.KEY_A,
        moveRight:    KeyboardKey.KEY_D,
        rotateLeft:   KeyboardKey.KEY_Q,
        rotateRight:  KeyboardKey.KEY_E,
        rotateUp:     KeyboardKey.KEY_R,
        rotateDown:   KeyboardKey.KEY_F,

    };

    const grass = BlockType(0);

    // Load packs
    auto pack = getPack("res/samerion-retro/pack.json");

    IsodiModel[] models;

    // Load chunks
    foreach (map; "../server/resources/maps".dirEntries(SpanMode.shallow)) {
        // Yes, I'm loading some chunks I have not uploaded to the repository
        // They're legacy, so I'm gonna replace them with something new later on
        // Contact me for the proper ones, ok? Not feeling like having them here!

        import std.array, std.algorithm;

        string[] declarations;

        // Load the chunk
        auto chunk = pack.loadTilemap(cast(ubyte[]) map.read, declarations);
        chunk.properties.transform = MatrixTranslate(0.5, 0, 0.5);

        // Build the model
        auto texture = pack.blockTexture(declarations.sort.array, chunk.atlas);

        models ~= chunk.makeModel(texture);

    }

    // One more chunk for testing stuff
    {

        Chunk chunk;
        chunk.properties.transform = MatrixTranslate(0.5, 0, 0.5);
        chunk.properties.tint = Vector4(0.8, 0.8, 0.8, 1);
        chunk.atlas[grass] = pack.options(ResourceType.block, "grass").blockUV;

        chunk.addX(
            grass,
            BlockPosition(2, 2, 0, 5),  20, 22, 24, 26, 28, 30,
            BlockPosition(2, 3, 0, 5),  20, 20, 20, 20, 20, 20,
            BlockPosition(2, 4, 0, 35), 60, 62, 64, 66, 68, 70,
        );

        auto texture = pack.blockTexture(["grass"], chunk.atlas);
        models ~= chunk.makeModel(texture);

        BlockUV[BlockType] uv1, uv2;
        assert(pack.blockTexture(["grass"], uv1) == pack.blockTexture(["grass"], uv2));
        assert(uv1 == uv2);

    }

    Texture2D defaultPoseTexture, advancedPoseTexture;
    scope (exit) {
        UnloadTexture(defaultPoseTexture);
        UnloadTexture(advancedPoseTexture);
    }

    // Load a skeleton
    Skeleton skeleton;
    {

        const model = "white-wraith";

        // Load the skeleton
        skeleton.bones = pack.skeleton("humanoid", model);

        // Load the bone set texture
        auto texture = pack.boneSetTexture([model], skeleton.atlas);

        // Create a matrix texture for the default pose
        defaultPoseTexture = LoadTextureFromImage(skeleton.matrixImage);

        // Test instances for billboard behavior etc
        foreach (i; 2..8) {

            skeleton.properties.transform = MatrixTranslate(i + 0.5, 2.0, 3.5);

            models ~= skeleton.makeModel(texture, defaultPoseTexture);

        }

        void mulbone(T...)(T matrices, ref Matrix matrix) {

            matrix = mul(matrices, matrix);

        }

        // Create a more advanced pose
        foreach (i; 0..2) {

            const im = 4 + 3*i;
            mulbone(MatrixRotateX(PI/5), MatrixRotateY(PI/4), skeleton.bones[im].transform);
            mulbone(MatrixRotateZ(PI/2), skeleton.bones[im+1].transform);
            mulbone(MatrixRotateX(PI/4), skeleton.bones[im+2].transform);

        }

        // Make a matrix for it
        advancedPoseTexture = LoadTextureFromImage(skeleton.matrixImage);

        // Instance one with it
        skeleton.properties.transform = MatrixTranslate(0.5, 0.2, 0.5);
        models ~= skeleton.makeModel(texture, advancedPoseTexture);

    }

    auto buf = new Matrix[skeleton.bones.length];

    // Drawing loop
    while (!WindowShouldClose) {

        BeginDrawing();
        scope (exit) EndDrawing();

        ClearBackground(Colors.WHITE);

        // Update the camera
        auto camera = controller.update(cameraKeys);

        {

            BeginMode3D(camera);
            scope (exit) EndMode3D();

            DrawGrid(100, 1);

            // Draw each model
            foreach (ref model; models) {

                model.draw();

            }

            // Draw skeleton debug
            skeleton.drawBoneLines(buf);
            skeleton.drawBoneNormals(buf);

            // Draw spheres to show the terrain direction
            DrawSphere(Vector3( 0, 0, -1), 0.2, Colors.GREEN);   // North
            DrawSphere(Vector3(+1, 0,  0), 0.2, Colors.BLUE);    // East
            DrawSphere(Vector3( 0, 0, +1), 0.2, Colors.PINK);    // South
            DrawSphere(Vector3(-1, 0,  0), 0.2, Colors.YELLOW);  // West

        }

        DrawFPS(0, 0);

    }

}
