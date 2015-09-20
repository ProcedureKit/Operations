//
//  AddressBookConditions.swift
//  Operations
//
//  Created by Daniel Thorpe on 27/07/2015.
//  Copyright (c) 2015 Daniel Thorpe. All rights reserved.
//

import Foundation
import AddressBook

public struct AddressBookCondition: OperationCondition {

    public enum Error: ErrorType {
        case AuthorizationDenied
        case AuthorizationRestricted
        case AuthorizationNotDetermined
    }

    public let name = "Address Book"
    public let isMutuallyExclusive = false
    private let registrar: AddressBookPermissionRegistrar

    public init() {
        registrar = SystemAddressBookRegistrar()
    }

    init(registrar: AddressBookPermissionRegistrar) {
        self.registrar = registrar
    }

    public func dependencyForOperation(operation: Operation) -> NSOperation? {
        switch registrar.status {
        case .NotDetermined:
            return AddressBookOperation(registrar: registrar)
        default:
            return .None
        }
    }

    public func evaluateForOperation(operation: Operation, completion: OperationConditionResult -> Void) {
        switch registrar.status {
        case .Authorized:
            completion(.Satisfied)
        case .Denied:
            completion(.Failed(Error.AuthorizationDenied))
        case .Restricted:
            completion(.Failed(Error.AuthorizationRestricted))
        case .NotDetermined:
            // This could be possible, because the condition may have been
            // suppressed with a `SilentCondition`.
            completion(.Failed(Error.AuthorizationNotDetermined))
        }
    }
}
