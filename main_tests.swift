// Respiro — TimerState unit tests
// Run: swiftc -DTESTING app.swift main_tests.swift -o run_tests -framework Cocoa -framework UserNotifications && ./run_tests

import Foundation

// MARK: - Test Helpers

var testCount = 0
var passCount = 0

func check(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    testCount += 1
    if condition {
        passCount += 1
    } else {
        print("  FAIL (\(file):\(line)): \(message)")
    }
}

// MARK: - Tests

func testInitialState() {
    let state = TimerState()
    check(state.phase == .working, "initial phase should be .working")
    check(state.secondsRemaining == 1200, "initial seconds should be 1200")
    check(state.paused == false, "initial paused should be false")
    print("  PASS: testInitialState")
}

func testTickDecrementsCounter() {
    var state = TimerState()
    let result = state.tick()
    check(state.secondsRemaining == 1199, "tick should decrement to 1199")
    check(result == nil, "tick mid-phase should return nil")
    print("  PASS: testTickDecrementsCounter")
}

func testTickWhilePaused() {
    var state = TimerState()
    state.paused = true
    let result = state.tick()
    check(state.secondsRemaining == 1200, "tick while paused should not decrement")
    check(result == nil, "tick while paused should return nil")
    print("  PASS: testTickWhilePaused")
}

func testTransitionToResting() {
    var state = TimerState()
    state.secondsRemaining = 1  // one tick away from transition
    let result = state.tick()
    check(result == .resting, "should transition to .resting")
    check(state.phase == .resting, "phase should be .resting")
    check(state.secondsRemaining == 20, "seconds should reset to 20")
    print("  PASS: testTransitionToResting")
}

func testTransitionToWorking() {
    var state = TimerState()
    state.phase = .resting
    state.secondsRemaining = 1  // one tick away from transition
    let result = state.tick()
    check(result == .working, "should transition to .working")
    check(state.phase == .working, "phase should be .working")
    check(state.secondsRemaining == 1200, "seconds should reset to 1200")
    print("  PASS: testTransitionToWorking")
}

func testFullWorkCycle() {
    var state = TimerState()

    // Tick through entire work phase
    for _ in 0..<1200 {
        _ = state.tick()
    }
    check(state.phase == .resting, "after 1200 ticks should be .resting")
    check(state.secondsRemaining == 20, "rest seconds should be 20")

    // Tick through entire rest phase
    for _ in 0..<20 {
        _ = state.tick()
    }
    check(state.phase == .working, "after rest ticks should be .working")
    check(state.secondsRemaining == 1200, "work seconds should be 1200")
    print("  PASS: testFullWorkCycle")
}

func testPausePreservesState() {
    var state = TimerState()

    // Tick 500 times
    for _ in 0..<500 {
        _ = state.tick()
    }
    check(state.secondsRemaining == 700, "after 500 ticks should have 700 left")

    // Pause and tick 100 times — should be no-ops
    state.togglePause()
    check(state.paused == true, "should be paused")
    for _ in 0..<100 {
        _ = state.tick()
    }
    check(state.secondsRemaining == 700, "paused ticks should not decrement")

    // Resume and tick once
    state.togglePause()
    check(state.paused == false, "should be unpaused")
    _ = state.tick()
    check(state.secondsRemaining == 699, "after resume tick should be 699")
    print("  PASS: testPausePreservesState")
}

func testDisplayTime() {
    var state = TimerState()

    state.secondsRemaining = 1200
    check(state.displayTime == "20:00", "1200s should display as 20:00")

    state.secondsRemaining = 61
    check(state.displayTime == "1:01", "61s should display as 1:01")

    state.secondsRemaining = 5
    check(state.displayTime == "0:05", "5s should display as 0:05")

    state.secondsRemaining = 0
    check(state.displayTime == "0:00", "0s should display as 0:00")

    print("  PASS: testDisplayTime")
}

// MARK: - Runner

@main
struct TestRunner {
    static func main() {
        print("Running Respiro tests...")
        print("")
        testInitialState()
        testTickDecrementsCounter()
        testTickWhilePaused()
        testTransitionToResting()
        testTransitionToWorking()
        testFullWorkCycle()
        testPausePreservesState()
        testDisplayTime()
        print("")
        print("\(passCount)/\(testCount) checks passed.")

        if passCount == testCount {
            print("All tests passed.")
        } else {
            print("SOME TESTS FAILED.")
            exit(1)
        }
    }
}
