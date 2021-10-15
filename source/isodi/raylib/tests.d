module isodi.raylib.tests;

import raylib;
import core.runtime;

import isodi.tests;
import isodi.raylib.camera;
import isodi.raylib.display;


@system:  // This module is all system, no memory safety for us damned


version (unittest):

shared static this() {

    // Redirect to our main
    Runtime.extendedModuleUnitTester = {

        UnitTestResult result = {
            runMain: true
        };

        return result;

    };

}

void main() {

    // Restore original test runner
    Runtime.extendedModuleUnitTester = null;

    // Create the window
    SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
    SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE);
    InitWindow(1600, 900, "unittest");
    SetWindowMinSize(800, 600);
    SetTargetFPS(60);
    scope(exit) CloseWindow();

    // Set camera keybinds
    // Too bad with() changes scope
    const CameraKeybindings keybinds = {

        zoomIn:  KeyboardKey.KEY_EQUAL,
        zoomOut: KeyboardKey.KEY_MINUS,

        rotateLeft:  KeyboardKey.KEY_Q,
        rotateRight: KeyboardKey.KEY_E,
        rotateUp:    KeyboardKey.KEY_R,
        rotateDown:  KeyboardKey.KEY_F,

        moveLeft:  KeyboardKey.KEY_A,
        moveRight: KeyboardKey.KEY_D,
        moveDown:  KeyboardKey.KEY_S,
        moveUp:    KeyboardKey.KEY_W,
        moveBelow: KeyboardKey.KEY_PAGE_DOWN,
        moveAbove: KeyboardKey.KEY_PAGE_UP,

    };

    // Create a test runner
    TestRunner runner;
    runner.runTests();

    // Prepre the display for the next test
    void prepare() {

        // Add a camera
        auto camAnchor = runner.display.addAnchor;
        runner.display.camera.follow = camAnchor;

    }

    // Run the tests
    loop: while (true) {

        // Requested closing the window
        if (WindowShouldClose) {

            // Abort tests
            runner.abortTests();
            break;

        }

        BeginDrawing();
        scope (exit) EndDrawing();

        import std.string : toStringz;

        ClearBackground(Colors.WHITE);

        with (TestRunner.Status)
        final switch (runner.status) {

            // Idle
            case idle:

                // Order next task
                runner.nextTest();
                prepare();
                break;

            // Paused
            case paused:

                // If pressing enter or space
                if (IsKeyPressed(KeyboardKey.KEY_SPACE) || IsKeyPressed(KeyboardKey.KEY_ENTER)) {

                    // Continue to next task
                    runner.nextTest();
                    prepare();

                }

                break;

            // Finished
            case finished:

                // Stop the program
                break loop;

            // Working, let it do its job
            case working: break;

        }

        auto display = cast(RaylibDisplay) runner.display;

        // Draw the frame
        display.camera.updateCamera(keybinds);
        display.draw();

        // Output status message
        DrawText(runner.statusMessage.toStringz, 10, 10, 20, Colors.BLACK);
        DrawFPS(10, GetScreenHeight - 20);

    }

}
