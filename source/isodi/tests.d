module isodi.tests;

import raylib;
import std.stdio;
import core.runtime;

import isodi.chunk;
import isodi.resources;


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
        position: Vector3(-20, 20, -20),
        up: Vector3(0.0f, 1f, 0.0f),
        fovy: 15.0f,
        projection: CameraProjection.CAMERA_ORTHOGRAPHIC,
    };
    SetCameraMode(camera, CameraMode.CAMERA_FREE);

    auto grass = BlockType("grass");

    Chunk chunk;
    chunk.addX(
        &grass,
        BlockPosition(0, 0, 0, 5), 0, 2, 6, 10, 10, 10, 12, 16, 14,
        BlockPosition(0, 1, 0, 5), 0, 4, 4, 8, 10, 12, 12, 16, 16,
    );

    auto mesh = chunk.makeMesh();
    UploadMesh(&mesh, false);
    scope (exit) UnloadMesh(mesh);

    auto material = LoadMaterialDefault();
    material.shader = LoadShader(null, "res/shader.fs");
    scope (exit) UnloadMaterial(material);
    // Note: Shader is unloaded by the material

    // Temporary sample image for testing direction
    // Tiles: Green is north (-Z), blue is east (+X)
    // Sides: Green is top (Y), blue is east
    auto image = GenImageColor(10, 5, Color(0x26, 0x26, 0x26, 0xff));
    ImageDrawRectangle(&image, 5, 0, 5, 5, Color(0x1c, 0x1c, 0x1c, 0xff));
    ImageDrawPixel(&image, 2, 1, Color(0x87, 0xff, 0xaf, 0xff));
    ImageDrawPixel(&image, 1, 2, Color(0xf2, 0xf0, 0x02, 0xff));
    ImageDrawPixel(&image, 3, 2, Color(0x14, 0xfb, 0xfb, 0xff));
    ImageDrawPixel(&image, 2, 3, Color(0xf8, 0x28, 0xfa, 0xff));
    ImageDrawPixel(&image, 7, 1, Color(0x87, 0xff, 0xaf, 0xff));
    ImageDrawPixel(&image, 6, 2, Color(0xf2, 0xf0, 0x02, 0xff));
    ImageDrawPixel(&image, 8, 2, Color(0x14, 0xfb, 0xfb, 0xff));
    ImageDrawPixel(&image, 7, 3, Color(0xf8, 0x28, 0xfa, 0xff));

    scope (exit) UnloadImage(image);

    auto texture = LoadTextureFromImage(image);
    scope (exit) UnloadTexture(texture);

    SetMaterialTexture(&material, MaterialMapIndex.MATERIAL_MAP_ALBEDO, texture);

    //auto chunkTexture = packBlockTextures();

    while (!WindowShouldClose) {

        BeginDrawing();
        scope (exit) EndDrawing();

        ClearBackground(Colors.WHITE);
        UpdateCamera(&camera);

        BeginMode3D(camera);
        scope (exit) EndMode3D();

        auto matrix = MatrixTranslate(0.5, 0, 0.5);

        DrawGrid(100, 1);
        DrawMesh(mesh, material, matrix);
        //DrawTexture(chunkTexture, 3, 0, Colors.WHITE);

        // Draw spheres to show the terrain direction
        DrawSphere(Vector3( 0, 0, -1), 0.2, Colors.GREEN);   // North
        DrawSphere(Vector3(+1, 0,  0), 0.2, Colors.BLUE);    // East
        DrawSphere(Vector3( 0, 0, +1), 0.2, Colors.PINK);    // South
        DrawSphere(Vector3(-1, 0,  0), 0.2, Colors.YELLOW);  // West

    }

}
