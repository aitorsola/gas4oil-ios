//
//  VehicleViewViewModel.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 21/3/22.
//

import Foundation
import Observation

struct FillCost {
    let cheapest: Double
    let priciest: Double
    let cheapestStation: Station
}

extension VehicleStored {
    
    func fillCost(using stations: [Station]) -> FillCost? {
        guard let litres = capacityLitres else {
            return nil
        }
        let totals = stations.compactMap { station -> (Station, Double)? in
            guard let price = station.price(for: fuel) else {
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

@MainActor
@Observable
final class DefaultVehicleViewViewModel {
    
    var vehicleData: VehicleStored = VehicleStored(brand: "", model: "", capacity: "", fuel: .gas95)
    var showSuccessAlert: Bool = false
    
    private(set) var isSaved: Bool = false
    
    let allFuelTypes = FuelType.allCases
    
    init() {
        loadVehicleData()
    }
    
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
    
    func fillCost(using stations: [Station]) -> FillCost? {
        vehicleData.fillCost(using: stations)
    }
}
