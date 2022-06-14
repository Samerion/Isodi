module isodi.tests;

import raylib;
import std.stdio;
import core.runtime;

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

    // TODO do run tests!
    Runtime.extendedModuleUnitTester = null;

    // Create the window
    SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
    SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE | ConfigFlags.FLAG_WINDOW_HIGHDPI);
    InitWindow(1600, 900, "Isodi test runner");
    SetWindowMinSize(800, 600);
    SetTargetFPS(60);
    scope (exit) CloseWindow();

    /// Prepare the camera
    Camera camera = {
        position: Vector3(-1, 1, -1) * 10,
        up: Vector3(0.0f, 1f, 0.0f),
        fovy: 15.0f,
        projection: CameraProjection.CAMERA_ORTHOGRAPHIC,
    };
    SetCameraMode(camera, CameraMode.CAMERA_FREE);

    auto grass = BlockType(0);

    // Load packs
    auto pack = getPack("res/samerion-retro/pack.json");

    Chunk[] chunks;
    ChunkModel[] models;
    //chunk.addX(
    //    grass,
    //    BlockPosition(0, 0, 0, 5), 0, 2, 6, 10, 10, 10, 12, 16, 14,
    //    BlockPosition(0, 1, 0, 5), 0, 4, 4, 8, 10, 12, 12, 16, 16,
    //    BlockPosition(-2, -1, 0,  0), 10,
    //    BlockPosition(-2,  0, 0,  5), 10,
    //    BlockPosition(-2,  1, 0, 15), 10,
    //    BlockPosition(-2,  2, 0, 50), 10,
    //    BlockPosition(-2,  3, 0, 30), 10,
    //);

    auto texture = LoadTexture("res/samerion-retro/blocks/grass.png");
    scope (exit) UnloadTexture(texture);  // :thinking:

    import std.file;

    foreach (map; "/home/soaku/git/samerion/server/resources/maps".dirEntries(SpanMode.shallow)) {

        auto chunk = loadTilemap(cast(ubyte[]) map.read);
        chunk.atlas[grass] = pack.getOptions("blocks/grass.png").blockUV;

        models ~= chunk.makeModel(texture);

    }
    // TODO unload resources

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

                model.properties.transform = MatrixTranslate(0.5, 0, 0.5);
                model.draw();

            }

            // Draw spheres to show the terrain direction
            DrawSphere(Vector3( 0, 0, -1), 0.2, Colors.GREEN);   // North
            DrawSphere(Vector3(+1, 0,  0), 0.2, Colors.BLUE);    // East
            DrawSphere(Vector3( 0, 0, +1), 0.2, Colors.PINK);    // South
            DrawSphere(Vector3(-1, 0,  0), 0.2, Colors.YELLOW);  // West

        }

        DrawFPS(0, 0);

    }

}
