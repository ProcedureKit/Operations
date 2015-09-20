//
//  LocationOperations.swift
//  Operations
//
//  Created by Daniel Thorpe on 27/07/2015.
//  Copyright (c) 2015 Daniel Thorpe. All rights reserved.
//

#if os(iOS)

import Foundation
import CoreLocation

@available(*, unavailable, renamed="UserLocationOperation")
public typealias LocationOperation = UserLocationOperation

/**
    An `Operation` subclass to request the user's current
    geographic location.
*/
public class UserLocationOperation: Operation {
    public typealias LocationResponseHandler = (location: CLLocation) -> Void
    private typealias LocationManagerConfiguration = (LocationManager) -> Void

    public enum Error: ErrorType, Equatable {
        case LocationManagerDidFail(NSError)
    }

    private let accuracy: CLLocationAccuracy
    private var manager: LocationManager?
    private let handler: LocationResponseHandler

    /// Access the user's location once it has updated.
    public var location: CLLocation? = .None

    /**
    Initialize an operation which will use CLLocationManager to determine
    the user's current location to the desired accuracy. It will ask for
    permission if required.
    
    :param: accuracy, the location accuracy which defaults to 3km.
    :param: handler, a response handler LocationResponseHandler.
    */
    public convenience init(accuracy: CLLocationAccuracy = kCLLocationAccuracyThreeKilometers, handler: LocationResponseHandler = { _ in }) {
        self.init(accuracy: accuracy, manager: CLLocationManager(), handler: handler)
    }

    init(accuracy: CLLocationAccuracy, manager: LocationManager, handler: LocationResponseHandler) {
        self.accuracy = accuracy
        self.manager = manager
        self.handler = handler
        super.init()
        addCondition(LocationCondition(usage: .WhenInUse, manager: manager))
        addCondition(MutuallyExclusive<LocationManager>())
    }

    public override func execute() {

        let configureLocationManager: LocationManagerConfiguration = { manager in
            manager.opr_setDesiredAccuracy(self.accuracy)
            manager.opr_setDelegate(self)
            manager.opr_startUpdatingLocation()
        }

        if let manager = manager {
            configureLocationManager(manager)
        }
        else {
            dispatch_async(Queue.Main.queue) {
                let manager = CLLocationManager()
                configureLocationManager(manager)
                self.manager = manager as LocationManager
            }
        }
    }

    public override func cancel() {
        dispatch_async(Queue.Main.queue) {
            self.stopLocationUpdates()
            super.cancel()
        }
    }

    private func stopLocationUpdates() {
        manager?.opr_stopLocationUpdates()
        manager = .None
    }
}

extension UserLocationOperation: CLLocationManagerDelegate {

    public func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last where location.horizontalAccuracy <= accuracy {
            stopLocationUpdates()
            self.location = location
            handler(location: location)
            finish()
        }
    }

    public func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        stopLocationUpdates()
        finish(Error.LocationManagerDidFail(error))
    }
}

public func ==(a: UserLocationOperation.Error, b: UserLocationOperation.Error) -> Bool {
    switch (a, b) {
    case let (.LocationManagerDidFail(aError), .LocationManagerDidFail(bError)):
        return aError == bError
    }
}

// MARK: - Geocoding

public protocol ReverseGeocoderType {
    func opr_cancel()
    func opr_reverseGeocodeLocation(location: CLLocation, completion: ([CLPlacemark], NSError?) -> Void)
}

extension CLGeocoder: ReverseGeocoderType {

    public func opr_cancel() {
        cancelGeocode()
    }

    public func opr_reverseGeocodeLocation(location: CLLocation, completion: ([CLPlacemark], NSError?) -> Void) {
        reverseGeocodeLocation(location) { (results, error) in
            completion(results ?? [], error as NSError?)
        }
    }
}

public class ReverseGeocodeOperation: Operation {

    public typealias ReverseGeocodeCompletionHandler = (CLPlacemark) -> Void

    public enum Error: ErrorType {
        case GeocoderError(NSError)
    }

    public let location: CLLocation
    internal let geocoder: ReverseGeocoderType
    internal let completion: ReverseGeocodeCompletionHandler?

    public private(set) var placemark: CLPlacemark? = .None

    /**
        This is the true public API, the other public initializer is really just a testing
        interface, and will not be public in Swift 2.0, Operations 2.0
    */
    public convenience init(location: CLLocation, completion: ReverseGeocodeCompletionHandler? = .None) {
        self.init(location: location, geocoder: CLGeocoder(), completion: completion)
    }

    init(location: CLLocation, geocoder: ReverseGeocoderType, completion: ReverseGeocodeCompletionHandler? = .None) {
        self.location = location
        self.geocoder = geocoder
        self.completion = completion
        super.init()
        name = "Reverse Geocode"
        addObserver(NetworkObserver())
        addObserver(BackgroundObserver())
        addCondition(MutuallyExclusive<ReverseGeocodeOperation>())
    }

    public override func cancel() {
        geocoder.opr_cancel()
        super.cancel()
    }

    public override func execute() {
        geocoder.opr_reverseGeocodeLocation(location) { (results, error) in
            if let placemark = results.first {
                self.placemark = placemark
                self.completion?(placemark)
            }
            self.finish(error.map { Error.GeocoderError($0) })
        }
    }
}

public class ReverseGeocodeUserLocationOperation: GroupOperation {

    public typealias ReverseGeocodeUserLocationCompletionHandler = (CLLocation, CLPlacemark) -> Void

    private let geocoder: ReverseGeocoderType
    private let completion: ReverseGeocodeUserLocationCompletionHandler?
    private let userLocationOperation: UserLocationOperation
    private var reverseGeocodeOperation: ReverseGeocodeOperation?

    public var location: CLLocation? {
        return userLocationOperation.location
    }

    public var placemark: CLPlacemark? {
        return reverseGeocodeOperation?.placemark
    }

    /**
        This is the true public API, the other public initializer is really just a testing
        interface, and will not be public in Swift 2.0, Operations 2.0
    */
    public convenience init(accuracy: CLLocationAccuracy = kCLLocationAccuracyThreeKilometers, completion: ReverseGeocodeUserLocationCompletionHandler? = .None) {
        self.init(accuracy: accuracy, manager: CLLocationManager(), geocoder: CLGeocoder(), completion: completion)
    }

    init(accuracy: CLLocationAccuracy, manager: LocationManager, geocoder: ReverseGeocoderType, completion: ReverseGeocodeUserLocationCompletionHandler? = .None) {
        self.geocoder = geocoder
        self.completion = completion
        self.userLocationOperation = UserLocationOperation(accuracy: accuracy, manager: manager) { location in
            // no-op
        }
        super.init(operations: [ userLocationOperation ])
        name = "Reverse Geocode User Location"
    }

    public override func cancel() {
        userLocationOperation.cancel()
        reverseGeocodeOperation?.cancel()
        super.cancel()
    }

    public override func operationDidFinish(operation: NSOperation, withErrors errors: [ErrorType]) {
        if errors.isEmpty && userLocationOperation == operation && !operation.cancelled {
            if let location = location {
                let reverseOp = ReverseGeocodeOperation(location: location, geocoder: geocoder) { [unowned self] placemark in
                    self.completion?(location, placemark)
                }
                addOperation(reverseOp)
                reverseGeocodeOperation = reverseOp
            }
        }
    }
}

#endif
