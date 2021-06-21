
module isodi.headless.tests;

import core.runtime;

import isodi.tests;
import isodi.headless.display;

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

    // Create a test runner
    TestRunner runner;
    runner.runTests();

    // Run the tests
    loop: while (true) {

        with (TestRunner.Status)
        final switch (runner.status) {

            // Idle
            case idle:
            case paused:

                // Order next task
                runner.nextTest();
                break;

            // Finished
            case finished:

                // Stop the program
                break loop;

            // Working, let it do its job
            case working: break;

        }

    }

}
