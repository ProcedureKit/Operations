//
//  BlockConditionTests.swift
//  Operations
//
//  Created by Daniel Thorpe on 20/07/2015.
//  Copyright © 2015 Daniel Thorpe. All rights reserved.
//

import XCTest
@testable import Operations

class AlertOperationTests: OperationTests {

    let title = "This is the alert title"
    let message = "This is the alert message"
    var presentingController: TestablePresentingController!

    override func setUp() {
        super.setUp()
        presentingController = TestablePresentingController()
    }
    
    func test__alert_style_set_default() {
        let op = AlertOperation(presentAlertFrom: presentingController)
        XCTAssertEqual(op.alert.preferredStyle, UIAlertControllerStyle.Alert)
    }
    
    func test__alert_style_actionSheet() {
        let style = UIAlertControllerStyle.ActionSheet
        let op = AlertOperation(presentAlertFrom: presentingController, preferredStyle: style)
        XCTAssertEqual(op.alert.preferredStyle, style)
    }

    func test__alert_title_works() {
        let alert = AlertOperation(presentAlertFrom: presentingController)
        alert.title = title
        XCTAssertEqual(alert.title, title)
    }

    func test__alert_message_works() {
        let alert = AlertOperation(presentAlertFrom: presentingController)
        alert.message = message
        XCTAssertEqual(alert.message, message)
    }

    func test__alert_operation_presents_alert_controller() {

        var didPresentAlert = false
        let alert = AlertOperation(presentAlertFrom: presentingController)
        alert.title = title
        alert.message = message

        presentingController.expectation = expectationWithDescription("Test: \(#function)")
        presentingController.check = { received in
            if let alertController = received as? UIAlertController {
                XCTAssertTrue(alertController.title == alert.title)
                XCTAssertTrue(alertController.message == alert.message)
                didPresentAlert = true
            }
            else {
                XCTFail("Did not receive a UIAlertController")
            }
        }

        runOperation(alert)
        waitForExpectationsWithTimeout(2, handler: nil)

        XCTAssertTrue(didPresentAlert)
    }
}
