//
//  FavoriteListViewViewModel.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 11/3/22.
//

import Observation

@MainActor
@Observable
final class FavoriteListViewViewModel {
    
    var favoriteStations: [Station] = []
    
    var preferredFuel: FuelType {
        VehicleFavorite.vehicleData?.fuel ?? .gas95
    }
    
    func removeFavorite(_ station: Station) {
        favoriteStations = FavoriteStations.manageFavorite(station)
    }
    
    func updateFavoriteStations(allStations: [Station]) {
        favoriteStations = allStations
        allStations.forEach { station in
            FavoriteStations.updateFavorite(station)
        }
    }
}
