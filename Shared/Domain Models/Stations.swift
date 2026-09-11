//
//  Stations.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 4/3/22.
//

import Foundation
import CoreLocation
import MapKit

struct Stations {
    let stations: [Station]
}

// Hashable is what `NavigationLink(value:)` and `navigationDestination(for:)` route on.
struct Station: Identifiable, Codable, Hashable {
    let id: Int
    let cp: String
    let provincia: String
    let municipio: String
    let direccion: String
    let horario: String
    let longitude: Double
    let latitude: Double
    let gasNaturalComprimido: String
    let gasNaturalLicuado: String
    var gasoleoA: String
    let gasoleoB: String
    let gasoleoPremium: String
    let gasolina95E10: String
    var gasolina95E5: String
    let gasolina95E5Premium: String
    let gasolina98E10: String
    var gasolina98E5: String
    let hidrogeno: String
    let rotulo: String
    var isFav: Bool
    
    func getCLLocationCoordinates() -> CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    /// Price of a given fuel exactly as the ministry publishes it (`1,899`), empty when
    /// the station does not sell it.
    func rawPrice(for fuel: FuelType) -> String {
        switch fuel {
        case .gas95:
            return gasolina95E5
        case .gas98:
            return gasolina98E5
        case .diesel:
            return gasoleoA
        }
    }
    
    /// Price of a given fuel, parsed from the `1,899` format the ministry publishes.
    /// `nil` means the station does not sell it.
    func price(for fuel: FuelType) -> Double? {
        Double(rawPrice(for: fuel).replacingOccurrences(of: ",", with: "."))
    }
    
    /// Rótulo cleaned up for display: the ministry ships trailing blanks and stray punctuation.
    var brandName: String {
        rotulo.trimmingCharacters(in: CharacterSet(charactersIn: " -.,"))
    }
    
    /// Opens driving directions to the station in Apple Maps.
    ///
    /// Uses `MKMapItem` rather than a `maps://` URL so the destination arrives named and
    /// addressed — Apple Maps shows "Repsol, Glorieta Embajadores" instead of bare coordinates.
    func openInMaps() {
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude,
                                                                       longitude: longitude))
        let item = MKMapItem(placemark: placemark)
        item.name = brandName.isEmpty ? direccion.capitalized : brandName
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}
