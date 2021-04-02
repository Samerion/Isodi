module isodi.tests;

import core.runtime;

import std.format;
import std.typecons;

import isodi.bind;
import isodi.pack;
import isodi.display;

// Disable cylic dependency checks while unittesting
//
// This thing  is madness and should  be disabled by default.  It causes more problems  than it fixes due  to how many
// false-positives it  catches. It makes  it impossible to  create custom inline tests,  because "oh module  1 imports
// module 2  and they  both have  tests! oh no!".  It's annoying.  And I feel  stupid making  a separate  directory or
// something just for testing.  Tests are better inline. Wait, did  I mention this is a RUNTIME  feature? It should be
// done by the compiler. I don't mean just speed, but... why runtime?
//
// Well, I probably should use `unittest` blocks with  decorators `@DisplayTest` and `@Benchmark`, but that comes with
// a problem:  there's no  way to  list all  modules compile-time  (wtf?) which  would be  necessary to  load unittest
// attributes. Same if I used some magic property or function to define tests.
version (unittest)
private extern(C) __gshared string[] rt_options = ["oncycle=ignore"];

/// Type of the test callback.
alias TestCallback = immutable void delegate(Display);

/// Test type.
enum TestType {

    /// Unit test.
    unit,

    /// This test is meant to check if everything is displayed correctly and so requires human approval.
    display,

    /// This test is meant to measure performance of a certain feature.
    ///
    /// Unimplemented.
    benchmark,

}

/// Register a display test
mixin template DisplayTest(TestCallback callback) {
    version (unittest)
    private TestRunner.Register!(TestType.display, callback) register;
}

/// Register a benchmark
mixin template Benchmark(TestCallback callback) {
    version (unittest)
    private TestRunner.Register!(TestType.benchmark, callback) register;
}

/// Struct for running the tests.
version (unittest)
struct TestRunner {

    /// Current status of the test runner.
    enum Status {

        /// The tester is done with the current test.
        idle,

        /// The tester is working, wait before starting another test.
        working,

        /// Awaits <Enter> key press.
        paused,

        /// The tester has finished and there are no tests left.
        finished,

    }

    /// Helper template for registering tests
    package struct Register(TestType type, TestCallback callback) {

        static this() {

            // Add this test
            TestRunner.tests.require(type, []) ~= callback;

        }

    }

    /// List of registered tests.
    static TestCallback[][TestType] tests;

    public {

        /// Current status of the test runner.
        Status status;

        /// Message about the current status for the user.
        string statusMessage;

        /// Temporary display this test is running in. The object this points to will change every test, so make
        /// sure to not save the pointer, but use this reference instead.
        Display display;

    }

    // Private data used by the runner
    private {

        /// Number of total tests executed.
        size_t totalExecuted, totalPassed;

        /// Number of tests of this type executed.
        size_t typeExecuted, typePassed;

        /// Last test type ran.
        TestType lastType;

        /// Queue of tests.
        Tuple!(TestType, TestCallback)[] testQueue;

    }

    /// Start the tests
    void runTests() {

        import std.array : array;
        import std.algorithm : map;
        import std.traits : EnumMembers;

        statusMessage = "";

        // Create the queue
        static foreach (type; EnumMembers!TestType) {

            // For each type, fetch all the tests
            testQueue ~= tests.get(type, [])

                // Create a testing tuple
                .map!(cb => tuple(type, cb))
                .array;

        }

    }

    /// Start next test.
    ///
    /// This function may return before the test completes. Check the `status` property for updates.
    ///
    /// Since this function is thread-local, it is guarateed to be thread safe.
    void nextTest() {

        import std.range : front, popFront;

        assert(status != Status.working, "Cannot start tests, the runner is busy.");
        assert(status != Status.finished, "Cannot start tests, all tests have finished already.");

        status = Status.working;

        // Check if the tester should proceed
        if (!proceed) return;

        statusMessage = lastType.format!"Running %s tests... %s/%s completed"(typePassed, typeExecuted);

        // Count the test
        typeExecuted++;

        {

            // I'm too lazy to search for the full dscanner name to @suppress it, ok?
            // @suppress(dscanner...catch_em_all) I never know what's in the middle lol
            alias QuietThrowable = Throwable;

            // Create a display
            display = Display.make;
            display.packs = PackList.make(
                getPack("res/samerion-retro/pack.json")
            );
            display.camera.angle.x = display.camera.angle.x + 180;

            // Run the test
            try {

                testQueue.front[1](display);
                typePassed++;

            }

            // Show all errors
            catch (QuietThrowable e) Renderer.log(e.toString, LogType.error);


            // React based on test type
            with (TestType)
            final switch (testQueue.front[0]) {

                // Unittest? Can't happen!
                case unit:
                    assert(0, "Unit tests should be created through the unittest statement, not isodi's test runner");

                // Display test, need to wait for user input
                case display:
                    status = Status.paused;
                    statusMessage = format!"Display test %s/%s. Press <Enter> to continue."(
                        typeExecuted, tests[display].length
                    );
                    break;

                // Benchmark, should probably wait for some callback
                case benchmark:
                    break;

            }

        }

        // Pop the queue
        testQueue.popFront();

    }

    /// Update the test data.
    /// Returns: true if the runner should proceed to the next test.
    private bool proceed() {

        import std.conv : text;
        import std.range : front;

        // Waiting for unit tests
        if (lastType == TestType.unit) {

            // Start them
            import core.runtime : runModuleUnitTests;

            statusMessage = "Running unit tests...";

            // Run the tests
            const result = runModuleUnitTests();

            typePassed   += result.passed;
            typeExecuted += result.executed;

        }

        // Check if there are any tests left
        if (!testQueue.length) {

            endSection();
            endTests();

            return false;

        }

        // Next test section
        if (lastType != testQueue.front[0]) {

            endSection();

        }

        lastType = testQueue.front[0];

        return true;

    }

    /// Force abort tests before completion.
    void abortTests() {

        // Update test counts
        totalPassed   += typePassed;
        totalExecuted += typeExecuted;

        // Prepare output
        const output = format!"tests aborted. %s/%s passed, %s left unfinished."(
            totalPassed - 1, totalExecuted - 1, testQueue.length + 1
        );

        // Output as failure
        Renderer.log(output, LogType.error);

        status = Status.finished;

    }

    /// End test section.
    private void endSection() {

        const output = lastType.format!"%s tests finished. %s/%s passed."(typePassed, typeExecuted);

        // Output the log
        Renderer.log(output, typePassed == typeExecuted ? LogType.success : LogType.error);

        // Update test counts
        totalPassed   += typePassed;
        totalExecuted += typeExecuted;
        typePassed   = 0;
        typeExecuted = 0;

    }

    /// End all tests
    private void endTests() {

        const output = format!"all tests finished. %s/%s passed."(totalPassed, totalExecuted);

        // Output
        Renderer.log(output, totalPassed == totalExecuted ? LogType.success : LogType.error);

        statusMessage = "All done! Finishing...";
        status = Status.finished;

    }

}
