//
//  VehicleViewViewModel.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 21/3/22.
//

import Foundation
import Observation

/// What a full tank costs right now across the stations currently on screen.
struct FillCost {
    let cheapest: Double
    let priciest: Double
    let cheapestStation: Station
}

@MainActor
@Observable
final class DefaultVehicleViewViewModel {
    
    // MARK: - Properties
    
    var vehicleData: VehicleStored = VehicleStored(brand: "", model: "", capacity: "", fuel: .gas95)
    var showSuccessAlert: Bool = false
    
    /// Whether a vehicle is stored, as opposed to merely typed into the form.
    private(set) var isSaved: Bool = false
    
    let allFuelTypes = FuelType.allCases
    
    init() {
        loadVehicleData()
    }
    
    // MARK: - Public
    
    func loadVehicleData() {
        guard let stored = VehicleFavorite.vehicleData else {
            isSaved = false
            return
        }
        vehicleData = stored
        isSaved = true
    }
    
    func save() {
        guard vehicleData.isValid else {
            return
        }
        vehicleData.brand = vehicleData.brand.trimmingCharacters(in: .whitespaces)
        vehicleData.model = vehicleData.model.trimmingCharacters(in: .whitespaces)
        VehicleFavorite.saveVehicleData(data: vehicleData)
        isSaved = true
        showSuccessAlert = true
    }
    
    func removeVehicle() {
        VehicleFavorite.removeVehicleData()
        vehicleData.reset()
        isSaved = false
    }
    
    /// Turns the tank size into the thing the user actually cares about: what filling it costs at
    /// the stations they can reach. This is the whole point of the screen, and until now it only
    /// ever showed up on the other tab.
    func fillCost(using stations: [Station]) -> FillCost? {
        guard let litres = vehicleData.capacityLitres else {
            return nil
        }
        let totals = stations.compactMap { station -> (Station, Double)? in
            guard let price = station.price(for: vehicleData.fuel) else {
                return nil
            }
            return (station, price * litres)
        }
        guard let cheapest = totals.min(by: { $0.1 < $1.1 }),
              let priciest = totals.max(by: { $0.1 < $1.1 }) else {
            return nil
        }
        return FillCost(cheapest: cheapest.1, priciest: priciest.1, cheapestStation: cheapest.0)
    }
}
