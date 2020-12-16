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

    // Create the window
    SetConfigFlags(ConfigFlag.FLAG_WINDOW_RESIZABLE);
    InitWindow(1600, 900, "unittest");
    SetWindowMinSize(800, 600);
    SetTargetFPS(60);

    // Create a test runner
    TestRunner runner;
    runner.runTests();

    // Run the tests
    loop: while (!WindowShouldClose) {

        BeginDrawing();

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

                    // unimplemented
                    break;

                // Finished
                case finished:

                    // Stop the program
                    break loop;

                // Working, let it do its job
                case working: break;

            }

        EndDrawing();

    }

    // End the program
    CloseWindow();

}
