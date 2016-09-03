//
//  ProcedureKit
//
//  Copyright © 2016 ProcedureKit. All rights reserved.
//

import Foundation

/**
 The result of a Condition. Either the condition is satisfied,
 indicated by `.satisfied` or it has failed. In the failure
 case, an `Error` must be associated with the result.
 */
public enum ConditionResult {

    /// Indicates that the condition is satisfied
    case satisfied

    /// Indicates that the condition failed, but can be ignored
    case ignored

    /// Indicates that the condition failed with an associated error.
    case failed(Error)
}

public extension ConditionResult {

    var error: Error? {
        guard case .failed(let error) = self else { return nil }
        return error
    }
}

public protocol ConditionProtocol: ProcedureProcotol {

    var mutuallyExclusive: Bool { get set }

    func evaluate(operation: Operation, completion: (ConditionResult) -> Void)
}

internal extension ConditionProtocol {

    var category: String {
        return String(describing: type(of: self))
    }
}

// MARK: Condition Errors

public extension Errors {

    public struct FalseCondition: Error {
        internal init() { }
    }
}

open class Condition: Procedure, ConditionProtocol {

    public var mutuallyExclusive: Bool = false

    internal weak var operation: Operation? = nil

    open override func execute() {
        guard let operation = operation else {
            log.verbose(message: "Condition finishing before evaluation because operation is nil.")
            finish()
            return
        }
        evaluate(operation: operation, completion: finish)
    }

    public func evaluate(operation: Operation, completion: (ConditionResult) -> Void) {
        completion(.failed(Errors.ProgrammingError(reason: "Condition must be subclassed, and \(#function) overridden.")))
    }

    internal func finish(withConditionResult conditionResult: ConditionResult) {
        finish(withError: conditionResult.error)
    }
}

public class TrueCondition: Condition {

    public init(name: String = "True Condition", mutuallyExclusive: Bool = false) {
        super.init()
        self.name = name
        self.mutuallyExclusive = mutuallyExclusive
    }

    public override func evaluate(operation: Operation, completion: (ConditionResult) -> Void) {
        completion(.satisfied)
    }
}

public class FalseCondition: Condition {

    public init(name: String = "False Condition", mutuallyExclusive: Bool = false) {
        super.init()
        self.name = name
        self.mutuallyExclusive = mutuallyExclusive
    }

    public override func evaluate(operation: Operation, completion: (ConditionResult) -> Void) {
        completion(.failed(Errors.FalseCondition()))
    }
}
