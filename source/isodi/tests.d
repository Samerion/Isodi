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
        position: Vector3(-1, 1, -1) * 10,
        up: Vector3(0.0f, 1f, 0.0f),
        fovy: 10.0f,
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
        // They're legacy, so I'm gonna replace them with something new later on
        // Contact me for the proper ones, ok? Not feeling like having them here!

        auto chunk = loadTilemap(cast(ubyte[]) map.read);
        chunk.properties.transform = MatrixTranslate(0.5, 0, 0.5);
        chunk.atlas[grass] = pack.getOptions("blocks/grass.png").blockUV;

        models ~= chunk.makeModel(texture);

    }

    // One more chunk for testing stuff
    {

        Chunk chunk;
        chunk.properties.transform = MatrixTranslate(0.5, 0, 0.5);
        chunk.atlas[grass] = pack.getOptions("blocks/grass.png").blockUV;

        chunk.addX(
            grass,
            BlockPosition(2, 2, 0, 5),  20, 22, 24, 26, 28, 30,
            BlockPosition(2, 3, 0, 5),  20, 20, 20, 20, 20, 20,
            BlockPosition(2, 4, 0, 35), 60, 62, 64, 66, 68, 70,
        );

        models ~= chunk.makeModel(texture);

    }

    Texture2D defaultPoseTexture, advancedPoseTexture;
    scope (exit) {
        UnloadTexture(defaultPoseTexture);
        UnloadTexture(advancedPoseTexture);
    }

    // Load a skeleton
    Skeleton skeleton;
    {

        const cellSize = 16;

        const hips     = BoneType(0);
        const abdomen  = BoneType(1);
        const torso    = BoneType(2);
        const head     = BoneType(3);
        const upperArm = BoneType(4);
        const forearm  = BoneType(5);
        const hand     = BoneType(6);
        const thigh    = BoneType(7);
        const lowerLeg = BoneType(8);
        const foot     = BoneType(9);

        auto simpleUV(int[4] data...) => BoneUV([RectangleI(data[0], data[1], data[2], data[3])]);

        skeleton.atlas[hips]     = simpleUV(1,  52,  40, 6);
        skeleton.atlas[abdomen]  = simpleUV(1,  33,  32, 7);
        skeleton.atlas[torso]    = simpleUV(1,  1,   56, 16);
        skeleton.atlas[head]     = simpleUV(1,  18,  40, 14);
        skeleton.atlas[upperArm] = simpleUV(43, 31,  20, 13);
        skeleton.atlas[forearm]  = simpleUV(51, 49,  12, 9);
        skeleton.atlas[hand]     = simpleUV(43, 45,  20, 3);
        skeleton.atlas[thigh]    = simpleUV(43, 18,  20, 12);
        skeleton.atlas[lowerLeg] = simpleUV(1,  41,  12, 9);
        skeleton.atlas[foot]     = simpleUV(11, 59,  52, 4);

        auto vec3(alias f = Vector3)(float[3] vals...) {

            vals[] /= cellSize;
            return f(vals[0], vals[1], vals[2]);

        }

        // Torso
        const hipsBone    = skeleton.addBone(hips, vec3!MatrixTranslate(0, 20, 0), vec3(0, 6, 0));
        const abdomenBone = skeleton.addBone(abdomen, hipsBone, vec3!MatrixTranslate(0, -1, 1), vec3(0, 7, 0));
        const torsoBone   = skeleton.addBone(torso, abdomenBone, vec3!MatrixTranslate(0, -3, -1), vec3(0, 16, 0));
        const headBone    = skeleton.addBone(head, torsoBone, vec3!MatrixTranslate(0, -1, 0), vec3(0, 14, 0));

        foreach (i; 0..2) {

            const direction = i ? -1 : 1;
            const invert = i ? MatrixIdentity : MatrixScale(-1, 1, 1);

            // Arms
            const upperArmBone = skeleton.addBone(upperArm, torsoBone,
                mul(invert, vec3!MatrixTranslate(direction * 7.5, 0, 0)),
                vec3(0, -13, 0));
            const forearmBone = skeleton.addBone(forearm, upperArmBone, vec3!MatrixTranslate(0, 1, 0), vec3(0, -9, 0));
            const handBone = skeleton.addBone(hand, forearmBone, vec3!MatrixTranslate(1, 1, 0), vec3(0, -3, 0));

            // Legs
            const thighBone = skeleton.addBone(thigh, hipsBone,
                mul(invert, vec3!MatrixTranslate(direction * 2.5, -3, 0)),
                vec3(0, -12, 0));
            const lowerLegBone = skeleton.addBone(lowerLeg, thighBone, vec3!MatrixTranslate(0, 1, 0), vec3(0, -9, 0));
            const footBone = skeleton.addBone(foot, lowerLegBone, vec3!MatrixTranslate(0, 1, 0), vec3(0, -4, 0));

        }

        // Create a matrix texture for the default pose
        defaultPoseTexture = LoadTextureFromImage(skeleton.matrixImage);

        // Test instances for billboard behavior etc
        foreach (i; 2..8) {

            skeleton.properties.transform = MatrixTranslate(i + 0.5, 2.0, 3.5);
            models ~= skeleton.makeModel(modelTexture, defaultPoseTexture);

        }

        void mulbone(T...)(T matrices, ref Matrix matrix) {

            matrix = mul(matrices, matrix);

        }

        // Create a more advanced pose
        foreach (i; 0..2) {

            const im = 4 + 6*i;
            mulbone(MatrixRotateX(PI/5), MatrixRotateY(PI/4), skeleton.bones[im].transform);
            mulbone(MatrixRotateZ(PI/2), skeleton.bones[im+1].transform);
            mulbone(MatrixRotateX(PI/4), skeleton.bones[im+2].transform);

        }

        // Make a matrix for it
        advancedPoseTexture = LoadTextureFromImage(skeleton.matrixImage);

        // Instance one with it
        skeleton.properties.transform = MatrixTranslate(0.5, 0.2, 0.5);
        models ~= skeleton.makeModel(modelTexture, advancedPoseTexture);

    }

    auto buf = new Matrix[skeleton.bones.length];

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

            // Draw each model
            foreach (model; models) {

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
