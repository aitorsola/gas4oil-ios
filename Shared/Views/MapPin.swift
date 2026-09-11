//
//  MapPin.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 7/3/22.
//

import SwiftUI
import CoreLocation

struct MapPin: View {
    
    let station: Station
    var tapBlock: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "mappin.circle")
                    .resizable()
                    .frame(width: 20, height: 20)
                Text(station.direccion.capitalized).font(.body)
            }
            .padding(12)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.primary)
            .offset(x: 0, y: -5)
            
            CommonStationBrand(rotulo: station.rotulo).roundIcon(size: 50)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        }
        .onTapGesture {
            tapBlock?()
        }
    }
}

#Preview {
    MapPin(station: Station(id: 0, cp: "", provincia: "", municipio: "", direccion: "Glorieta Embajadores, 0", horario: "", longitude: 0, latitude: 0, gasNaturalComprimido: "", gasNaturalLicuado: "", gasoleoA: "", gasoleoB: "", gasoleoPremium: "", gasolina95E10: "", gasolina95E5: "", gasolina95E5Premium: "", gasolina98E10: "", gasolina98E5: "", hidrogeno: "", rotulo: "Repsol", isFav: false))
}
