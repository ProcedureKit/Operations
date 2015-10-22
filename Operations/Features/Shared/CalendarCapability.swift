//
//  CalendarCapability.swift
//  Operations
//
//  Created by Daniel Thorpe on 01/10/2015.
//  Copyright © 2015 Dan Thorpe. All rights reserved.
//

import EventKit

public protocol EventsCapabilityRegistrarType: CapabilityRegistrarType {
    func opr_authorizationStatusForRequirement(requirement: EKEntityType) -> EKAuthorizationStatus
    func opr_requestAccessForRequirement(requirement: EKEntityType, completion: EKEventStoreRequestAccessCompletionHandler)
}

extension EKEventStore: EventsCapabilityRegistrarType {

    public func opr_authorizationStatusForRequirement(requirement: EKEntityType) -> EKAuthorizationStatus {
        return EKEventStore.authorizationStatusForEntityType(requirement)
    }

    public func opr_requestAccessForRequirement(requirement: EKEntityType, completion: EKEventStoreRequestAccessCompletionHandler) {
        requestAccessToEntityType(requirement, completion: completion)
    }
}

extension EKAuthorizationStatus: AuthorizationStatusType {

    public func isRequirementMet(requirement: EKEntityType) -> Bool {
        if case .Authorized = self {
            return true
        }
        return false
    }
}

public class _EventsCapability<Registrar: EventsCapabilityRegistrarType>: NSObject, CapabilityType {

    public let name = "Events"
    public let requirement: EKEntityType

    let registrar: Registrar

    public required init(_ requirement: EKEntityType = .Event, registrar: Registrar = Registrar()) {
        self.requirement = requirement
        self.registrar = registrar
        super.init()
    }

    public func isAvailable() -> Bool {
        return true
    }

    public func authorizationStatus(completion: EKAuthorizationStatus -> Void) {
        completion(registrar.opr_authorizationStatusForRequirement(requirement))
    }

    public func requestAuthorizationWithCompletion(completion: dispatch_block_t) {
        let status = registrar.opr_authorizationStatusForRequirement(requirement)
        switch status {
        case .NotDetermined:
            registrar.opr_requestAccessForRequirement(requirement) { success, error in
                completion()
            }
        default:
            completion()
        }
    }
}

extension Capability {
    public typealias Calendar = _EventsCapability<EKEventStore>
}

@available(*, unavailable, renamed="AuthorizedFor(Capability.Calendar(.Event))")
public typealias CalendarCondition = AuthorizedFor<Capability.Calendar>

