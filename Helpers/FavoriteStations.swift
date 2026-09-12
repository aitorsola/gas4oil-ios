//
//  FavoriteStations.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 9/3/22.
//

import Foundation
import SwiftUI

class FavoriteStations {
    
    private static var defaults = UserDefaults.standard
    private static var allFavorites: [Station] = []
    
    static func manageFavorite(_ station: Station) -> [Station] {
        if let allFavorites = defaults.object(forKey: "favs") as? Data {
            let decoder = JSONDecoder()
            if let stationsDecoded = try? decoder.decode([Station].self, from: allFavorites) {
                self.allFavorites = stationsDecoded
                if stationsDecoded.contains(where: {$0.id == station.id}) {
                    return removeFavorite(station)
                } else {
                    return saveNewFavorite(station)
                }
            } else {
                return saveNewFavorite(station)
            }
        } else {
            return saveNewFavorite(station)
        }
    }
    
    static private func saveNewFavorite(_ station: Station) -> [Station] {
        var station = station
        station.isFav = true
        allFavorites.append(station)
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(allFavorites)
            defaults.set(data, forKey: "favs")
            defaults.synchronize()
        } catch(let error) {
            print(error.localizedDescription)
        }
        return allFavorites
    }
    
    static private func removeFavorite(_ station: Station) -> [Station] {
        allFavorites.removeAll(where: {$0.id == station.id})
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(allFavorites)
            defaults.set(data, forKey: "favs")
            defaults.synchronize()
        } catch(let error) {
            print(error.localizedDescription)
        }
        return allFavorites
    }
    
    static func isFavorite(_ stationId: Int) -> Bool {
        allFavorites.contains(where: { $0.id == stationId })
    }
    
    static func updateFavorite(_ station: Station) {
        let decoder = JSONDecoder()
        guard let data = defaults.object(forKey: "favs") as? Data,
              var stations = try? decoder.decode([Station].self, from: data) else {
            return
        }
        for i in 0..<stations.count {
            if stations[i].id == station.id {
                stations[i] = station
            }
        }
        allFavorites = stations
        let encoder = JSONEncoder()
        let stationsData = try? encoder.encode(stations)
        defaults.set(stationsData, forKey: "favs")
    }
    
    static func getAllFavorites() -> [Station] {
        if let object = defaults.object(forKey: "favs") as? Data {
            let decoder = JSONDecoder()
            if let stations = try? decoder.decode([Station].self, from: object) {
                allFavorites = stations
                return stations
            } else {
                return []
            }
        } else {
            return []
        }
    }
}
