//
//  ProcedureKit
//
//  Copyright © 2016 ProcedureKit. All rights reserved.
//

import XCTest
import TestingProcedureKit
@testable import ProcedureKit

class DataProcessing: Procedure, ResultInjection {
    let result: PendingValue<Void> = .void
    var requirement: PendingValue<String> = .pending

    override func execute() {
        guard let output = requirement.value else {
            finish(withError: ProcedureKitError.requirementNotSatisfied())
            return
        }
        log.info(message: output)
        finish()
    }
}

class Printing: Procedure, ResultInjection {
    var requirement: PendingValue<String> = .ready("Default Requirement")
    let result: PendingValue<Void> = .void

    override func execute() {
        if let message = requirement.value {
            log.info(message: message)
        }
        finish()
    }
}

class ResultInjectionTestCase: ProcedureKitTestCase {
    var processing: DataProcessing!
    var printing: Printing!

    override func setUp() {
        super.setUp()
        processing = DataProcessing()
        printing = Printing()
    }
}

class ResultInjectionTests: ResultInjectionTestCase {

    func test__block_is_executed() {
        var injectionBlockDidExecute = false
        processing.inject(dependency: procedure) { processing, dependency, errors in
            injectionBlockDidExecute = true
        }
        wait(for: procedure, processing)
        XCTAssertTrue(injectionBlockDidExecute)
    }

    func test__block_passes_through_errors() {
        let error = TestError()
        var receivedErrors: [Error] = []
        procedure = TestProcedure(error: error)
        processing.inject(dependency: procedure) { processing, dependency, errors in
            receivedErrors = errors
        }
        wait(for: procedure, processing)
        XCTAssertTrue(TestError.verify(errors: receivedErrors, contains: error))
    }

    func test__automatic_requirement_is_injected() {
        processing.injectResult(from: procedure)
        wait(for: processing, procedure)
        XCTAssertProcedureFinishedWithoutErrors(processing)
    }

    func test__receiver_cancels_with_error_if_dependency_errors() {
        let error = TestError()
        procedure = TestProcedure(error: error)
        processing.injectResult(from: procedure)
        processing.addDidCancelBlockObserver { processing, errors in
            XCTAssertEqual(errors.count, 1)
            guard let procedureKitError = errors.first as? ProcedureKitError else {
                XCTFail("Incorrect error received"); return
            }
            XCTAssertEqual(procedureKitError.context, .dependencyFinishedWithErrors)
            XCTAssertTrue(TestError.verify(errors: procedureKitError.errors, contains: error))
        }
        wait(for: processing, procedure)
        XCTAssertProcedureCancelledWithErrors(processing, count: 1)
    }

    func test__receiver_cancels_with_errors_if_requirement_not_met() {
        procedure.result = .pending
        printing.injectResult(from: procedure)
        printing.addDidCancelBlockObserver { printing, errors in
            XCTAssertEqual(errors.count, 1)
            guard let procedureKitError = errors.first as? ProcedureKitError else {
                XCTFail("Incorrect error received"); return
            }
            XCTAssertEqual(procedureKitError.context, .requirementNotSatisfied)
        }
        wait(for: printing, procedure)
        XCTAssertProcedureCancelledWithErrors(printing, count: 1)
    }

    func test__receiver_cancels_if_dependency_is_cancelled() {
        processing.injectResult(from: procedure)
        processing.addDidCancelBlockObserver { printing, errors in
            XCTAssertEqual(errors.count, 1)
            guard let procedureKitError = errors.first as? ProcedureKitError else {
                XCTFail("Incorrect error received"); return
            }
            XCTAssertEqual(procedureKitError.context, .parentCancelledWithErrors)
        }
        procedure.cancel()
        wait(for: processing, procedure)
        XCTAssertProcedureCancelledWithErrors(processing, count: 1)
    }

    func test__automatic_unwrap_when_result_is_optional_requrement() {
        let hello = ResultProcedure<String?> { "Hello, World" }
        hello.log.severity = .notice
        let print = Printing().injectResult(from: hello)
        print.log.severity = .notice
        wait(for: print, hello)
        XCTAssertProcedureFinishedWithoutErrors(print)
    }

    func test__automatic_unwrap_when_result_is_nil_optional_requrement() {
        let hello = ResultProcedure<String?> { nil }
        let printer = Printing().injectResult(from: hello)
        wait(for: printer, hello)
        XCTAssertProcedureCancelledWithErrors(printer, count: 1)
    }

    func test__collection_flatMap() {
        let hello = ResultProcedure { "Hello" }
        let world = ResultProcedure { "World" }
        let mapped = [world, hello].flatMap { $0.uppercased() }
        wait(forAll: [hello, world, mapped])
        XCTAssertProcedureFinishedWithoutErrors(hello)
        XCTAssertProcedureFinishedWithoutErrors(world)
        XCTAssertProcedureFinishedWithoutErrors(mapped)
        XCTAssertEqual(mapped.result.value ?? [], ["WORLD", "HELLO"])
    }

    func test__collection_reduce() {
        let hello = ResultProcedure { "Hello" }
        let world = ResultProcedure { "World" }
        let helloWorld = [hello, world].reduce("") { accumulator, element in
            guard !accumulator.isEmpty else { return element }
            return "\(accumulator) \(element)"
        }
        wait(forAll: [hello, world, helloWorld])
        XCTAssertProcedureFinishedWithoutErrors(hello)
        XCTAssertProcedureFinishedWithoutErrors(world)
        XCTAssertProcedureFinishedWithoutErrors(helloWorld)
        XCTAssertEqual(helloWorld.result.value, "Hello World")
    }

    func test__collection_reduce_which_throws_finishes_with_error() {
        let hello = ResultProcedure { "Hello" }
        let world = ResultProcedure { "World" }
        let error = TestError()
        let helloWorld = [hello, world].reduce("") { _, _ in throw error }
        wait(forAll: [hello, world, helloWorld])
        XCTAssertProcedureFinishedWithoutErrors(hello)
        XCTAssertProcedureFinishedWithoutErrors(world)
        XCTAssertProcedureFinishedWithErrors(helloWorld, count: 1)
        XCTAssertNil(helloWorld.result.value)
    }

    func test__collection_gather() {
        let hello = ResultProcedure { "Hello" }
        let world = ResultProcedure { "World" }
        let gathered = [hello, world].gather()

        wait(forAll: [hello, world, gathered])
        XCTAssertProcedureFinishedWithoutErrors(hello)
        XCTAssertProcedureFinishedWithoutErrors(world)
        XCTAssertProcedureFinishedWithoutErrors(gathered)
        XCTAssertEqual(gathered.result.value ?? [], ["Hello", "World"])
    }
}


