//
//  LocationCapabilityTests.swift
//  Operations
//
//  Created by Daniel Thorpe on 01/10/2015.
//  Copyright © 2015 Dan Thorpe. All rights reserved.
//

import Foundation
import CoreLocation
import XCTest
@testable import Operations

class TestableLocationRegistrar: NSObject {

    let fakeLocationManager = CLLocationManager()

    var servicesEnabled = true
    var didCheckServiceEnabled = false

    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var didCheckAuthorizationStatus = false

    weak var delegate: CLLocationManagerDelegate!
    var didSetDelegate = false

    var responseStatus: CLAuthorizationStatus = .authorizedAlways
    var didRequestAuthorization: LocationUsage? = .none

    required override init() { }
}

extension TestableLocationRegistrar: LocationCapabilityRegistrarType {

    func opr_locationServicesEnabled() -> Bool {
        didCheckServiceEnabled = true
        return servicesEnabled
    }

    func opr_authorizationStatus() -> CLAuthorizationStatus {
        didCheckAuthorizationStatus = true
        return authorizationStatus
    }

    func opr_setDelegate(_ aDelegate: CLLocationManagerDelegate?) {
        didSetDelegate = true
        delegate = aDelegate
    }

    func opr_requestAuthorizationWithRequirement(_ requirement: LocationUsage) {
        didRequestAuthorization = requirement
        authorizationStatus = responseStatus
        // In some cases CLLocationManager will immediately send a .NotDetermined 
        delegate.locationManager!(fakeLocationManager, didChangeAuthorization: .notDetermined)
        delegate.locationManager!(fakeLocationManager, didChangeAuthorization: responseStatus)
    }
}

class CLLocationManagerTests: XCTestCase, CLLocationManagerDelegate {

    func test__setting_delegate_works() {
        let manager = CLLocationManager()
        manager.opr_setDelegate(self)
        XCTAssertNotNil(manager.delegate)
    }
}

class CLAuthorizationStatusTests: XCTestCase {

    func test__given_status_not_determined__requirements_not_met() {
        let status = CLAuthorizationStatus.notDetermined
        XCTAssertFalse(status.isRequirementMet(.whenInUse))
    }

    func test__given_status_restricted__requirements_not_met() {
        let status = CLAuthorizationStatus.restricted
        XCTAssertFalse(status.isRequirementMet(.whenInUse))
    }

    func test__given_status_denied__requirements_not_met() {
        let status = CLAuthorizationStatus.denied
        XCTAssertFalse(status.isRequirementMet(.whenInUse))
    }

    func test__given_status_authorized_when_in_use__requirement_always_not_met() {
        let status = CLAuthorizationStatus.authorizedWhenInUse
        XCTAssertFalse(status.isRequirementMet(.always))
    }

    func test__given_status_authorized_when_in_use__requirement_when_in_use_met() {
        let status = CLAuthorizationStatus.authorizedWhenInUse
        XCTAssertTrue(status.isRequirementMet(.whenInUse))
    }

    func test__given_status_authorized_always__requirement_when_in_use_met() {
        let status = CLAuthorizationStatus.authorizedAlways
        XCTAssertTrue(status.isRequirementMet(.whenInUse))
    }

    func test__given_status_authorized_always__requirement_always_met() {
        let status = CLAuthorizationStatus.authorizedAlways
        XCTAssertTrue(status.isRequirementMet(.always))
    }
}

class LocationCapabilityTests: OperationTests {

    var registrar: TestableLocationRegistrar!
    var capability: LocationCapability!

    override func setUp() {
        super.setUp()
        registrar = TestableLocationRegistrar()
        capability = LocationCapability(.whenInUse)
        capability.registrar = registrar
    }

    override func tearDown() {
        registrar = nil
        capability = nil
        super.tearDown()
    }

    func test__name() {
        XCTAssertEqual(capability.name, "Location")
    }

    func test__requirement_is_set() {
        XCTAssertEqual(capability.requirement, LocationUsage.whenInUse)
    }

    func test__is_available_queries_registrar() {
        XCTAssertTrue(capability.isAvailable())
        XCTAssertTrue(registrar.didCheckServiceEnabled)
    }

    func test__authorization_status_queries_register() {
        capability.authorizationStatus { XCTAssertEqual($0, CLAuthorizationStatus.notDetermined) }
        XCTAssertTrue(registrar.didCheckAuthorizationStatus)
    }

    func test__given_service_disabled__requesting_authorization_returns_directly() {
        registrar.servicesEnabled = false
        var didComplete = false
        capability.requestAuthorizationWithCompletion {
            didComplete = true
        }
        XCTAssertTrue(registrar.didCheckServiceEnabled)
        XCTAssertNil(registrar.didRequestAuthorization)
        XCTAssertTrue(didComplete)
    }

    func test__given_not_determined_request_authorization() {
        var didComplete = false
        capability.requestAuthorizationWithCompletion {
            didComplete = true
        }
        XCTAssertTrue(registrar.didCheckServiceEnabled)
        XCTAssertEqual(registrar.didRequestAuthorization!, LocationUsage.whenInUse)
        XCTAssertTrue(registrar.didSetDelegate)
        XCTAssertTrue(didComplete)
    }

    func test__given_when_in_use_require_always_request_authorization() {
        registrar.authorizationStatus = .authorizedWhenInUse
        capability = LocationCapability(.always)
        capability.registrar = registrar
        var didComplete = false
        capability.requestAuthorizationWithCompletion {
            didComplete = true
        }
        XCTAssertTrue(registrar.didCheckServiceEnabled)
        XCTAssertEqual(registrar.didRequestAuthorization!, LocationUsage.always)
        XCTAssertTrue(registrar.didSetDelegate)
        XCTAssertTrue(didComplete)
    }

    func test__given_denied_does_not_request_authorization() {
        registrar.authorizationStatus = .denied
        var didComplete = false
        capability.requestAuthorizationWithCompletion {
            didComplete = true
        }
        XCTAssertNil(registrar.didRequestAuthorization)
        XCTAssertTrue(didComplete)
    }

    func test__given_already_authorized_always_does_not_request_authorization() {
        registrar.authorizationStatus = .authorizedAlways
        capability = LocationCapability(.whenInUse)
        capability.registrar = registrar
        var didComplete = false
        capability.requestAuthorizationWithCompletion {
            didComplete = true
        }
        XCTAssertNil(registrar.didRequestAuthorization)
        XCTAssertTrue(didComplete)
    }

    func test__given_already_authorized_sufficiently_does_not_request_authorization() {
        registrar.authorizationStatus = .authorizedAlways
        capability = LocationCapability(.whenInUse)
        capability.registrar = registrar
        var didComplete = false
        capability.requestAuthorizationWithCompletion {
            didComplete = true
        }
        XCTAssertNil(registrar.didRequestAuthorization)
        XCTAssertTrue(didComplete)
    }
}
