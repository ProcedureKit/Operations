//
//  ProcedureKit
//
//  Copyright © 2016 ProcedureKit. All rights reserved.
//

extension Collection where Iterator.Element: Operation {

    internal var operationsAndProcedures: ([Operation], [Procedure]) {
        return reduce(([], [])) { result, element in
            var (operations, procedures) = result
            if let procedure = element as? Procedure {
                procedures.append(procedure)
            }
            else {
                operations.append(element)
            }
            return (operations, procedures)
        }
    }

    internal var conditions: [Condition] {
        return flatMap { $0 as? Condition }
    }

    internal var userIntent: UserIntent {
        get {
            let (_, procedures) = operationsAndProcedures
            return procedures.map { $0.userIntent }.max { $0.rawValue < $1.rawValue } ?? .none
        }
    }

    internal func forEachProcedure(body: (Procedure) throws -> Void) rethrows {
        try forEach {
            if let procedure = $0 as? Procedure {
                try body(procedure)
            }
        }
    }

    /**
     Add the last operation of the receiver as a dependency of each element
     of the argument sequence. An Array of the receiver extended by the argument is
     returned.
     - parameter operation: the Iterator.Element instance to add
         the receiver as a dependency.
     - returns: an array of all operations operations.
     */
    public func then<S: Sequence>(do sequence: S) -> [Iterator.Element] where S.Iterator.Element == Iterator.Element {
        var operations = Array(self)
        if let last = operations.last {
            assert(!last.isFinished, "Cannot add a finished operation as a dependency.")
            sequence.forEach { $0.add(dependency: last) }
        }
        operations += sequence
        return operations
    }

    /**
     Add the last operation of the receiver as a dependency of each element
     of the argument. An Array of the receiver extended by the argument is
     returned.
     - parameter operations: a variable argument of Iterator.Element instance(s) to
         add the receiver as a dependency.
     - returns: an array of all operations.
     */
    public func then(do operations: Iterator.Element...) -> [Iterator.Element] {
        return then(do: operations)
    }

    /**
     Add the result of a closure onto the receiver.
     - parameter block: a throwing closure which returns an optional element
     - returns: an array of all operations.
     */
    func then(do block: () throws -> Iterator.Element?) rethrows -> [Iterator.Element] {
        guard let operations = try block() else { return Array(self) }
        return then(do: operations)
    }

    /**
     Adds the receiver to a ProcedureQueue.
     - parameter queue: a ProcedureQueue, with a default argument
    */
    func enqueue(on queue: ProcedureQueue = ProcedureQueue()) {
        queue.add(operations: self)
    }
}

// MARK: - ResultInjection & Gathering

extension Collection where Iterator.Element: ProcedureProtocol, Iterator.Element: ResultInjection {

    public func gather() -> ResultProcedure<[Self.Iterator.Element.Result]> {

        let gather = ResultProcedure { self.flatMap { $0.result.value } }

        forEach { gather.add(dependency: $0) }

        return gather
    }

    public func reduce<ReducedResult>(_ initialResult: ReducedResult, _ nextPartialResult: @escaping (ReducedResult, Self.Iterator.Element.Result) throws -> ReducedResult) rethrows -> ResultProcedure<ReducedResult> {

        // Create a procedure to gather the results of the collection
        let result = ResultProcedure { try self.flatMap { $0.result.value }.reduce(initialResult, nextPartialResult) }

        // Add each collection element as a dependency
        forEach { result.add(dependency: $0) }

        return result
    }
}
