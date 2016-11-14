//
//  ProcedureKit
//
//  Copyright © 2016 ProcedureKit. All rights reserved.
//

import CloudKit

@available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *)
extension CKAcceptSharesOperation: CKAcceptSharesOperationProtocol, AssociatedErrorProtocol {

    // The associated error type
    public typealias AssociatedError = PKCKError
}

extension CKProcedure where T: CKAcceptSharesOperationProtocol, T: AssociatedErrorProtocol, T.AssociatedError: CloudKitError {

    var shareMetadatas: [T.ShareMetadata] {
        get { return operation.shareMetadatas }
        set { operation.shareMetadatas = newValue }
    }

    var perShareCompletionBlock: CloudKitProcedure<T>.AcceptSharesPerShareCompletionBlock? {
        get { return operation.perShareCompletionBlock }
        set { operation.perShareCompletionBlock = newValue }
    }

    func setAcceptSharesCompletionBlock(_ block: @escaping CloudKitProcedure<T>.AcceptSharesCompletionBlock) {
        operation.acceptSharesCompletionBlock = { [weak self] error in
            if let strongSelf = self, let error = error {
                strongSelf.append(fatalError: PKCKError(underlyingError: error))
            }
            else {
                block()
            }
        }
    }
}

extension CloudKitProcedure where T: CKAcceptSharesOperationProtocol, T: AssociatedErrorProtocol, T.AssociatedError: CloudKitError {

    /// A typealias for the block type used by CloudKitOperation<CKAcceptSharesOperationType>
    public typealias AcceptSharesPerShareCompletionBlock = (T.ShareMetadata, T.Share?, Error?) -> Void

    /// A typealias for the block type used by CloudKitOperation<CKAcceptSharesOperationType>
    public typealias AcceptSharesCompletionBlock = () -> Void

    /// - returns: the share metadatas
    public var shareMetadatas: [T.ShareMetadata] {
        get { return current.shareMetadatas }
        set {
            current.shareMetadatas = newValue
            appendConfigureBlock { $0.shareMetadatas = newValue }
        }
    }

    /// - returns: the block used to return accepted shares
    public var perShareCompletionBlock: AcceptSharesPerShareCompletionBlock? {
        get { return current.perShareCompletionBlock }
        set {
            current.perShareCompletionBlock = newValue
            appendConfigureBlock { $0.perShareCompletionBlock = newValue }
        }
    }

    /**
     Before adding the CloudKitOperation instance to a queue, set a completion block
     to collect the results in the successful case. Setting this completion block also
     ensures that error handling gets triggered.

     - parameter block: an AcceptSharesCompletionBlock block
     */
    public func setAcceptSharesCompletionBlock(block: @escaping AcceptSharesCompletionBlock) {
        appendConfigureBlock { $0.setAcceptSharesCompletionBlock(block) }
    }
}
