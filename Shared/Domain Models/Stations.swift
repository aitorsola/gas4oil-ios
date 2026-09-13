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
    var gasoleoPremium: String
    let gasolina95E10: String
    var gasolina95E5: String
    var gasolina95E5Premium: String
    let gasolina98E10: String
    var gasolina98E5: String
    let hidrogeno: String
    var glp: String?
    let rotulo: String
    var isFav: Bool
    
    func getCLLocationCoordinates() -> CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    func rawPrice(for fuel: FuelType) -> String {
        switch fuel {
        case .gas95:
            return gasolina95E5
        case .gas98:
            return gasolina98E5
        case .diesel:
            return gasoleoA
        case .glp:
            return glp ?? ""
        case .dieselPremium:
            return gasoleoPremium
        case .gas95Premium:
            return gasolina95E5Premium
        }
    }
    
    func price(for fuel: FuelType) -> Double? {
        Double(rawPrice(for: fuel).replacingOccurrences(of: ",", with: "."))
    }
    
    var brandName: String {
        rotulo.trimmingCharacters(in: CharacterSet(charactersIn: " -.,"))
    }
    
    func openInMaps() {
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude,
                                                                       longitude: longitude))
        let item = MKMapItem(placemark: placemark)
        item.name = brandName.isEmpty ? direccion.capitalized : brandName
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}
