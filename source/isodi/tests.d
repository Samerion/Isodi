module isodi.tests;

import raylib;
import core.runtime;

import std.file;
import std.stdio;

import isodi;


@system:
version (unittest):


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
                cast(void) m.unitTest();
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
    Camera camera = {
        position: Vector3(-1, 1, -1) * 15,
        up: Vector3(0.0f, 1f, 0.0f),
        fovy: 5.0f,
        projection: CameraProjection.CAMERA_ORTHOGRAPHIC,
    };
    SetCameraMode(camera, CameraMode.CAMERA_FREE);

    const grass = BlockType(0);

    // Load packs
    const pack = getPack("res/samerion-retro/pack.json");

    IsodiModel[] models;

    // Load textures
    auto texture = LoadTexture("res/samerion-retro/blocks/grass.png");
    scope (exit) UnloadTexture(texture);

    auto modelTexture = LoadTexture("res/samerion-retro/bones/white-wraith.png");
    scope (exit) UnloadTexture(modelTexture);

    // Load chunks
    foreach (map; "/home/soaku/git/samerion/server/resources/maps".dirEntries(SpanMode.shallow)) {
        // Yes, I'm loading some chunks I have not uploaded to the repository

        auto chunk = loadTilemap(cast(ubyte[]) map.read);
        chunk.properties.transform = MatrixTranslate(0.5, 0, 0.5);
        chunk.atlas[grass] = pack.getOptions("blocks/grass.png").blockUV;

        models ~= chunk.makeModel(texture);

    }

    // Load a skeleton
    Skeleton skeleton;
    {

        const cellSize = 8;

        const hips = BoneType(0);
        const abdomen = BoneType(1);

        skeleton.properties.transform = MatrixTranslate(0.5, 0, 0.5);

        skeleton.atlas[hips] = BoneUV([
            RectangleL(1, 52, 40, 6),
        ]);
        skeleton.atlas[abdomen] = BoneUV([
            RectangleL(1, 33, 32, 7),
        ]);

        const hipsBone = skeleton.addBone(hips, MatrixTranslate(0, 19.5 / cellSize, 0), Vector3(0, 6.0 / cellSize, 0));
        skeleton.addBone(abdomen, hipsBone, MatrixTranslate(0, 5.0 / cellSize, 1.0 / cellSize), Vector3(0, 7.0 / cellSize, 0));

        models ~= skeleton.makeModel(modelTexture);

    }

    // Drawing loop
    while (!WindowShouldClose) {

        BeginDrawing();
        scope (exit) EndDrawing();

        ClearBackground(Colors.WHITE);
        UpdateCamera(&camera);

        {

            BeginMode3D(camera);
            scope (exit) EndMode3D();

            DrawGrid(100, 1);

            foreach (model; models) {

                model.draw();

            }

            skeleton.drawDebug();

            // Draw spheres to show the terrain direction
            DrawSphere(Vector3( 0, 0, -1), 0.2, Colors.GREEN);   // North
            DrawSphere(Vector3(+1, 0,  0), 0.2, Colors.BLUE);    // East
            DrawSphere(Vector3( 0, 0, +1), 0.2, Colors.PINK);    // South
            DrawSphere(Vector3(-1, 0,  0), 0.2, Colors.YELLOW);  // West

        }

        DrawFPS(0, 0);

    }

}
