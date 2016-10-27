//
//  ProcedureKit
//
//  Copyright © 2016 ProcedureKit. All rights reserved.
//

#if !os(tvOS)

import XCTest
import CloudKit
import ProcedureKit
import TestingProcedureKit
@testable import ProcedureKitCloud

class TestCKDiscoverAllContactsOperation: TestCKOperation, CKDiscoverAllContactsOperationProtocol, AssociatedErrorProtocol {
    typealias AssociatedError = DiscoverAllContactsError<DiscoveredUserInfo>

    var result: [DiscoveredUserInfo]?
    var error: Error?
    var discoverAllContactsCompletionBlock: (([DiscoveredUserInfo]?, Error?) -> Void)? = nil

    init(result: [DiscoveredUserInfo]? = nil, error: Error? = nil) {
        self.result = result
        self.error = error
        super.init()
    }

    override func main() {
        discoverAllContactsCompletionBlock?(result, error)
    }
}
    
class CKDiscoverAllContactsOperationTests: CKProcedureTestCase {

    var target: TestCKDiscoverAllContactsOperation!
    var operation: CKProcedure<TestCKDiscoverAllContactsOperation>!

    override func setUp() {
        super.setUp()
        target = TestCKDiscoverAllContactsOperation()
        operation = CKProcedure(operation: target)
    }

    func test__success_without_completion_block() {
        wait(for: operation)
        XCTAssertProcedureFinishedWithoutErrors(operation)
    }

    func test__success_with_completion_block() {
        var didExecuteBlock = false
        operation.setDiscoverAllContactsCompletionBlock { _ in
            didExecuteBlock = true
        }
        wait(for: operation)
        XCTAssertProcedureFinishedWithoutErrors(operation)
        XCTAssertTrue(didExecuteBlock)
    }

    func test__error_without_completion_block() {
        target.error = TestError()
        wait(for: operation)
        XCTAssertProcedureFinishedWithoutErrors(operation)
    }

    func test__error_with_completion_block() {
        var didExecuteBlock = false
        operation.setDiscoverAllContactsCompletionBlock { _ in didExecuteBlock = true }
        target.error = TestError()
        wait(for: operation)
        XCTAssertProcedureFinishedWithErrors(operation, count: 1)
        XCTAssertFalse(didExecuteBlock)
    }
}

class CloudKitProcedureDiscoverAllContactsOperationTests: CKProcedureTestCase {

    var cloudkit: CloudKitProcedure<TestCKDiscoverAllContactsOperation>!

    override func setUp() {
        super.setUp()
        cloudkit = CloudKitProcedure(strategy: .immediate) { TestCKDiscoverAllContactsOperation(result: [ "user info" ]) }
    }

    func test__cancellation() {
        cloudkit.cancel()
        wait(for: cloudkit)
        XCTAssertProcedureCancelledWithoutErrors(cloudkit)
    }

    func test__success_without_completion_block_set() {
        wait(for: cloudkit)
        XCTAssertProcedureFinishedWithoutErrors(cloudkit)
    }

    func test__success_with_completion_block_set() {
        var didSetDiscoveredUserInfo: [TestCKDiscoverAllContactsOperation.DiscoveredUserInfo]? = nil
        cloudkit.setDiscoverAllContactsCompletionBlock { didSetDiscoveredUserInfo = $0 }
        wait(for: cloudkit)
        XCTAssertProcedureFinishedWithoutErrors(cloudkit)
        XCTAssertEqual(didSetDiscoveredUserInfo?.first ?? "not user info", "user info")
    }

    func test__error_without_completion_block_set() {
        cloudkit = CloudKitProcedure(strategy: .immediate) {
            let operation = TestCKDiscoverAllContactsOperation(result: [ "user info" ])
            operation.error = NSError(domain: CKErrorDomain, code: CKError.internalError.rawValue, userInfo: nil)
            return operation
        }
        wait(for: cloudkit)
        XCTAssertProcedureFinishedWithoutErrors(cloudkit)
    }

    func test__error_with_completion_block_set() {
        cloudkit = CloudKitProcedure(strategy: .immediate) {
            let operation = TestCKDiscoverAllContactsOperation(result: [ "user info" ])
            operation.error = NSError(domain: CKErrorDomain, code: CKError.internalError.rawValue, userInfo: nil)
            return operation
        }

        var didSetDiscoveredUserInfo: [TestCKDiscoverAllContactsOperation.DiscoveredUserInfo]? = nil
        cloudkit.setDiscoverAllContactsCompletionBlock { didSetDiscoveredUserInfo = $0 }

        wait(for: cloudkit)
        XCTAssertProcedureFinishedWithErrors(cloudkit, count: 1)
        XCTAssertNil(didSetDiscoveredUserInfo)
    }
}

#endif
