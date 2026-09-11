//
//  LocationManager.swift
//  Test
//
//  Created by Aitor Sola on 22/2/22.
//

import CoreLocation

enum MeasurementUnit {
    case metters(Double)
    case km(Double)
}

/// Plain Swift protocol rather than `@objc`: the optional requirements only existed to avoid
/// implementing every callback, which a protocol extension does without the ObjC bridge — and
/// `@objc` members cannot satisfy a `@MainActor` requirement.
@MainActor
protocol LocationManagerDelegate: AnyObject {
    func didGet(auth: CLAuthorizationStatus)
    func didGet(city: String?)
    func didFailGettingLocation(_ error: Error)
}

extension LocationManagerDelegate {
    func didGet(auth: CLAuthorizationStatus) {}
    func didGet(city: String?) {}
}

protocol LocationManager {
    func requestAuth()
    var currentAuth: CLAuthorizationStatus { get }
    var delegate: LocationManagerDelegate? { get set }
    var currentCoordinates: CLLocation? { get set }
    var currentCity: String? { get set }
}

class Location: NSObject, LocationManager {
    
    private let manager: CLLocationManager = .init()
    
    weak var delegate: LocationManagerDelegate?
    
    var currentCoordinates: CLLocation?
    var currentCity: String?
    var currentAuth: CLAuthorizationStatus {
        manager.authorizationStatus
    }
    
    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.delegate = self
    }
    
    func requestAuth() {
        if case .notDetermined  = manager.authorizationStatus {
            manager.requestWhenInUseAuthorization()
        } else {
            manager.startUpdatingLocation()
        }
    }
    
    func getCityNameFor(_ coordinate: CLLocation, completion: @escaping (CLPlacemark?) -> Void) {
        let geoCoder = CLGeocoder()
        geoCoder.reverseGeocodeLocation(coordinate) { placemarks, error in
            completion(placemarks?.first)
        }
    }
    
    static func distanceFromPoint(_ point: CLLocation) -> MeasurementUnit? {
        guard let currentPoint = Managers.location.currentCoordinates else {
            return nil
        }
        let distance = Measurement(value: point.distance(from: currentPoint), unit: UnitLength.meters)
        
        if distance.value < 1000 {
            return .metters(distance.value.round(to: 0))
        } else {
            return .km(distance.converted(to: .kilometers).value.round(to: 1))
        }
    }
}

extension Location: CLLocationManagerDelegate {
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            delegate?.didGet(auth: status)
        }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            return
        }
        currentCoordinates = location
        getCityNameFor(location) { placemark in
            self.manager.stopUpdatingLocation()
            self.currentCity = placemark?.locality
            Task { @MainActor in
                self.delegate?.didGet(city: placemark?.locality)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            delegate?.didFailGettingLocation(error)
        }
    }
}
