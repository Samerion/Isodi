module isodi.tests;

import core.runtime;
import std.typecons;

import isodi.bind;
import isodi.display;

/// Type of the test callback.
alias TestCallback = void delegate(Display);

/// Test type.
private enum TestType {

    /// Unit test.
    unit,

    /// This test is meant to check if everything is displayed correctly and requires human approval.
    display,

    /// This test is meant to measure performance of a certain feature.
    benchmark,

}

/// Register a display test
mixin template DisplayTest(TestCallback callback) {
    TestRunner.Register!(TestType.display, callback) register;
}

/// Register a benchmark
mixin template Benchmark(TestCallback callback) {
    TestRunner.Register!(TestType.benchmark, callback) register;
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
    private struct Register(TestType type, TestCallback callback) {

        static this() {

            // Add this test
            TestRunner.tests.require(type, []) ~= callback;

        }

    }

    /// List of registered tests.
    static TestCallback[][TestType] tests;

    /// Current status of the test runner.
    Status status;

    /// Message about the current status for the user.
    string statusMessage;

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

        statusMessage = "";

    }

    /// Start next test.
    ///
    /// This function returns instantly and the test will be started in a separate thread. Check the `status` property
    /// for updates.
    void nextTest() {

        assert(status != Status.working, "Cannot start tests, the runner is busy.");
        assert(status != Status.finished, "Cannot start tests, all tests have finished already.");

        status = Status.working;

        // Check if the tester should proceed
        if (!proceed) return;

    }

    /// Update the test data.
    /// Returns: true if the runner should proceed to the next test.
    private bool proceed() {

        // Waiting for unit tests
        if (lastType == TestType.unit) {

            // Start them
            import core.runtime : runModuleUnitTests;

            // Run the tests
            const result = runModuleUnitTests();

            totalPassed   += result.passed;
            totalExecuted += result.executed;

            lastType++;

        }

        return false;

    }

}
