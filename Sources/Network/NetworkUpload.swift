//
//  ProcedureKit
//
//  Copyright © 2016 ProcedureKit. All rights reserved.
//

/**
 NetworkUploadProcedure is a simple procedure which will perform a upload task using
 URLSession based APIs. It only supports the completion block style API, therefore
 do not use this procedure if you wish to use delegate based APIs on URLSession.
 */
open class NetworkUploadProcedure<Session: URLSessionTaskFactory>: Procedure, InputProcedure, OutputProcedure, NetworkOperation {
    public typealias NetworkResult = ProcedureResult<HTTPPayloadResponse<Data>>
    public typealias CompletionBlock = (NetworkResult) -> Void

    public var input: Pending<HTTPPayloadRequest<Data>> = .pending
    public var output: Pending<NetworkResult> = .pending

    public private(set) var session: Session
    public let completion: CompletionBlock

    internal var task: Session.UploadTask? = nil

    public var networkError: ProcedureKitNetworkError? {
        return errors.flatMap { $0 as? ProcedureKitNetworkError }.first
    }

    public init(session: Session, request: URLRequest? = nil, data: Data? = nil, completionHandler: @escaping CompletionBlock = { _ in }) {

        self.session = session
        self.input = request.flatMap { .ready(HTTPPayloadRequest(payload: data, request: $0)) } ?? .pending
        self.completion = completionHandler

        super.init()
        addWillCancelBlockObserver { procedure, _ in
            procedure.task?.cancel()
        }
    }

    open override func execute() {
        guard let requirement = input.value else {
            finish(withResult: .failure(ProcedureKitError.requirementNotSatisfied()))
            return
        }

        task = session.uploadTask(with: requirement.request, from: requirement.payload) { [weak self] data, response, error in
            guard let strongSelf = self else { return }

            if let error = error {
                strongSelf.finish(withResult: .failure(ProcedureKitNetworkError(error as NSError)))
                return
            }

            guard let data = data, let response = response as? HTTPURLResponse else {
                strongSelf.finish(withResult: .failure(ProcedureKitError.unknown))
                return
            }

            let http = HTTPPayloadResponse(payload: data, response: response)

            strongSelf.completion(.success(http))
            strongSelf.finish(withResult: .success(http))
        }

        task?.resume()
    }
}
