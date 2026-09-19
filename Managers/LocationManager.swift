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
    var currentCountryCode: String? { get }
}

class Location: NSObject, LocationManager {
    
    private let manager: CLLocationManager = .init()
    private var locationRetries = 0
    private static let maxLocationRetries = 3
    
    weak var delegate: LocationManagerDelegate?
    
    var currentCoordinates: CLLocation?
    var currentCity: String?
    private(set) var currentCountryCode: String?
    var currentAuth: CLAuthorizationStatus {
        manager.authorizationStatus
    }
    
    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.delegate = self
    }
    
    func requestAuth() {
        locationRetries = 0
        if case .notDetermined = manager.authorizationStatus {
            manager.requestWhenInUseAuthorization()
        } else {
            manager.requestLocation()
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
            manager.requestLocation()
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            return
        }
        locationRetries = 0
        currentCoordinates = location
        getCityNameFor(location) { placemark in
            self.currentCity = placemark?.locality
            self.currentCountryCode = placemark?.isoCountryCode
            Task { @MainActor in
                self.delegate?.didGet(city: placemark?.locality)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .locationUnknown, locationRetries < Self.maxLocationRetries {
            locationRetries += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                manager.requestLocation()
            }
            return
        }
        locationRetries = 0
        if currentCoordinates == nil, let cached = manager.location {
            locationManager(manager, didUpdateLocations: [cached])
            return
        }
        Task { @MainActor in
            delegate?.didFailGettingLocation(error)
        }
    }
}
