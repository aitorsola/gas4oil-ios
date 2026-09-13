//
//  MapView.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 7/3/22.
//

import MapKit
import SwiftUI

struct MapView: View {
    
    private let station: Station
    @State private var position: MapCameraPosition
    @Namespace private var mapScope
    
    init(station: Station) {
        self.station = station
        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: station.latitude,
                                                                       longitude: station.longitude),
                                        span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01))
        self._position = State(initialValue: .region(region))
    }
    
    var body: some View {
        Map(position: $position, scope: mapScope) {
            Annotation(station.brandName,
                       coordinate: CLLocationCoordinate2D(latitude: station.latitude,
                                                          longitude: station.longitude)) {
                MapPin(station: station) {
                    station.openInMaps()
                }
            }
            UserAnnotation()
        }
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            MapCompass(scope: mapScope)
                .mapControlVisibility(.automatic)
                .padding(.trailing, 12)
                .safeAreaPadding(.top)
        }
        .mapScope(mapScope)
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView(station: Station(id: 0, cp: "", provincia: "", municipio: "", direccion: "Glorieta Embajadores, 0", horario: "", longitude: -3.7038, latitude: 40.4168, gasNaturalComprimido: "", gasNaturalLicuado: "", gasoleoA: "", gasoleoB: "", gasoleoPremium: "", gasolina95E10: "", gasolina95E5: "", gasolina95E5Premium: "", gasolina98E10: "", gasolina98E5: "", hidrogeno: "", rotulo: "Repsol", isFav: true))
    }
}
