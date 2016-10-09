//
//  ProcedureKit
//
//  Copyright © 2016 ProcedureKit. All rights reserved.
//

import XCTest
import ProcedureKit
import TestingProcedureKit
@testable import ProcedureKitMobile

class TestableNetworkActivityIndicator: NetworkActivityIndicatorProtocol {
    typealias IndicatorVisibilityDidChange = (Bool) -> Void

    let visibilityDidChange: IndicatorVisibilityDidChange

    init(_ didChange: @escaping IndicatorVisibilityDidChange) {
        visibilityDidChange = didChange
    }

    var networkActivityIndicatorVisible = false {
        didSet {
            visibilityDidChange(networkActivityIndicatorVisible)
        }
    }
}

class NetworkObserverTests: ProcedureKitTestCase {
    var controller: NetworkActivityController!
    var indicator: TestableNetworkActivityIndicator!
    var _changes: Protector<[Bool]>!

    var changes: [Bool] {
        return _changes.read { $0 }
    }

    override func setUp() {
        super.setUp()
        let indicatorExpectation = expectation(description: "Indicator Expectation")
        _changes = Protector<[Bool]>([])
        indicator = TestableNetworkActivityIndicator { visibility in
            self._changes.append(visibility)
            if !visibility {
                DispatchQueue.main.async {
                    indicatorExpectation.fulfill()
                }
            }
        }
        controller = NetworkActivityController(indicator: indicator)
    }

    override func tearDown() {
        _changes = nil
        indicator = nil
        controller = nil
        super.tearDown()
    }

    func test__network_indicator_shows_when_procedure_starts() {
        procedure.add(observer: NetworkObserver(controller: controller))
        wait(for: procedure, withTimeout: 5) { _ in
            self.XCTAssertProcedureFinishedWithoutErrors()
            XCTAssertTrue(self.changes.first ?? false)
        }
    }

    func test__network_indicator_hides_after_short_delay_when_procedure_finishes() {
        procedure.add(observer: NetworkObserver(controller: controller))
        wait(for: procedure, withTimeout: 5) { _ in
            self.XCTAssertProcedureFinishedWithoutErrors()
            guard self.changes.count == 2 else {
                XCTFail("Too few changes"); return
            }
            XCTAssertTrue(self.changes[0])
            XCTAssertFalse(self.changes[1])
        }
    }

    func test__network_indicator_only_changes_once_when_multiple_procedures_start() {
        let procedure1 = TestProcedure()
        procedure1.add(observer: NetworkObserver(controller: controller))
        let procedure2 = TestProcedure()
        procedure2.add(observer: NetworkObserver(controller: controller))

        wait(for: procedure1, procedure2, withTimeout: 5) { _ in
            self.XCTAssertProcedureFinishedWithoutErrors(procedure1)
            self.XCTAssertProcedureFinishedWithoutErrors(procedure2)
            XCTAssertEqual(self.changes.count, 4)
        }
    }

    func test__network_indicator_does_not_hide_before_all_procedures_are_finished() {
        //
        // Definitions:
        //  timerInterval = the interval used inside NetworkIndicatorController for its Timer
        //
        // This test uses the following 3 operations to affect the NetworkIndicator:
        //
        //              [startTime]                                         [duration]
        // procedure1   immediately                                         0.1 seconds
        // procedure2   operation1.endTime + 0.1 seconds                    2 x timerInterval
        // procedure3   operation1.endTime + timerInterval + (a bit extra)  0.1 seconds
        //
        // procedure1
        //      - started immediately (by itself), triggers the network indicator, ends, and causes
        //        NetworkIndicatorController to queue a Timer to remove the network indicator
        // procedure2
        //      - a "long-running" operation, starts after procedure1 finishes, but before the
        //        Timer that was queued as a result of procedure1 finishing fires
        //      - this should result in the Timer being cancelled before it fires, and the network
        //        activity indicator remaining visible for the duration of procedure2
        //        (procedure2 is the last operation to finish)
        // procedure3
        //      - a short procedure that starts after procedure2 is running, after the original Timer
        //        that procedure1 triggered would have fired (if it weren't cancelled), and
        //        ends before procedure2 is finished
        //      - this should not change the visible state of the network indicator, as it should still
        //        be visible (as a result of procedure2)
        //
        // The expected output of this timing and sequence of operations is a network indicator that
        // shows at the start of procedure1, and disappears "timerInterval" seconds after the end of
        // procedure2. (i.e. 2 visibility changes: true, false)
        //
        // Previously, this test would fail by producing 4 visibility changes: (true, false, true, false)
        //

        let delay1 = DelayProcedure(by: 0.1)
        let delay2 = DelayProcedure(by: 1.1)

        let procedure1 = TestProcedure(delay: 0.1)
        procedure1.add(observer: NetworkObserver(controller: controller))

        let procedure2 = TestProcedure(delay: 2.1)
        procedure2.add(observer: NetworkObserver(controller: controller))
        procedure2.add(dependency: delay1)

        let procedure3 = TestProcedure(delay: 0.1)
        procedure3.add(observer: NetworkObserver(controller: controller))
        procedure3.add(dependency: delay2)

        procedure1.addWillExecuteBlockObserver { procedure in
            procedure.produce(operation: delay1)
            procedure.produce(operation: procedure2)
            procedure.produce(operation: delay2)
            procedure.produce(operation: procedure3)
        }

        wait(for: procedure1, withTimeout: 5) { _ in
            self.XCTAssertProcedureFinishedWithoutErrors(procedure1)
            self.XCTAssertProcedureFinishedWithoutErrors(procedure2)
            self.XCTAssertProcedureFinishedWithoutErrors(procedure3)
            XCTAssertEqual(self.changes.count, 5)
        }

    }
}


class NetworkActivityControllerTimerTests: ProcedureKitTestCase {

    func test__network_indicator_timer_cancellation_prevents_handler_from_running() {
        let expect = expectation(description: "Test: \(#function)")
        var didRunBlock = false
        let timer = NetworkActivityController.Timer(interval: 0.4) { didRunBlock = true }
        timer.cancel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { expect.fulfill() }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertFalse(didRunBlock)
    }
}


