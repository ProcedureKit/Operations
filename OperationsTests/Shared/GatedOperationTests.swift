//
//  GatedOperationTests.swift
//  Operations
//
//  Created by Daniel Thorpe on 24/07/2015.
//  Copyright (c) 2015 Daniel Thorpe. All rights reserved.
//

import XCTest
@testable import Operations

class GatedOperationTests: OperationTests {

    func test__when_gate_is_closed_operation_is_not_performed() {

        let gate = GatedOperation(operation: TestOperation()) { return false }
        addCompletionBlockToTestOperation(gate, withExpectation: expectationWithDescription("Test: \(__FUNCTION__)"))

        runOperation(gate)

        waitForExpectationsWithTimeout(5, handler: nil)
        XCTAssertTrue(gate.finished)
        XCTAssertFalse(gate.operation.didExecute)
    }

    func test__when_gate_is_open_operation_is_performed() {
        let gate = GatedOperation(operation: TestOperation()) { return true }
        addCompletionBlockToTestOperation(gate, withExpectation: expectationWithDescription("Test: \(__FUNCTION__), Gate"))
        addCompletionBlockToTestOperation(gate.operation, withExpectation: expectationWithDescription("Test: \(__FUNCTION__), Operation"))

        runOperation(gate)

        waitForExpectationsWithTimeout(5, handler: nil)
        XCTAssertTrue(gate.finished)
        XCTAssertTrue(gate.operation.didExecute)
        XCTAssertTrue(gate.operation.finished)
    }

}

