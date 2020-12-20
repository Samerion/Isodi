module isodi.raylib.tests;

import raylib;
import core.runtime;

import isodi.tests;

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
    SetConfigFlags(ConfigFlag.FLAG_WINDOW_RESIZABLE);
    InitWindow(1600, 900, "unittest");
    SetWindowMinSize(800, 600);
    SetTargetFPS(60);

    // Create a test runner
    TestRunner runner;
    runner.runTests();

    // Run the tests
    loop: while (true) {

        // Requested closing the window
        if (WindowShouldClose) {

            // Abort tests
            runner.abortTests();
            break;

        }

        BeginDrawing();

            import std.string : toStringz;

            ClearBackground(Colors.WHITE);

            with (TestRunner.Status)
            final switch (runner.status) {

                // Idle
                case idle:

                    // Order next task
                    runner.nextTest();
                    break;

                // Paused
                case paused:

                    // If pressing enter or space
                    if (IsKeyPressed(KeyboardKey.KEY_SPACE) || IsKeyPressed(KeyboardKey.KEY_ENTER)) {

                        // Continue to next task
                        runner.nextTest();

                    }

                    break;

                // Finished
                case finished:

                    // Stop the program
                    break loop;

                // Working, let it do its job
                case working: break;

            }

            // Output status message
            DrawText(runner.statusMessage.toStringz, 10, 10, 24, Colors.BLACK);

        EndDrawing();

    }

    // End the program
    CloseWindow();

}
