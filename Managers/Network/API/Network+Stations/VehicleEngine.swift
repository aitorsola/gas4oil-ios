//
//  VehicleEngine.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 27/3/22.
//

import Foundation

protocol VehicleAPI: Sendable {
    func getBrands() async throws(G4OError) -> [VehicleBrandEntity]
    func getModelByBrand(brandId: Int) async throws(G4OError) -> [VehicleModelEntity]
}

private enum VehicleEndpoints {
    static let allBrands = "https://the-vehicles-api.herokuapp.com/brands/"
    static let modelByBrand = "https://the-vehicles-api.herokuapp.com/models"
}

extension Network: VehicleAPI {
    
    func getBrands() async throws(G4OError) -> [VehicleBrandEntity] {
        let data = try await perform(Request(url: VehicleEndpoints.allBrands, method: .get))
        guard let entity = try? JSONDecoder().decode([VehicleBrand].self, from: data) else {
            throw .parseProblems
        }
        return entity.compactMap { $0.domainEntity() }
    }
    
    func getModelByBrand(brandId: Int) async throws(G4OError) -> [VehicleModelEntity] {
        let request = Request(url: VehicleEndpoints.modelByBrand,
                              method: .get,
                              parameters: ["brandId": String(brandId)])
        let data = try await perform(request)
        guard let entity = try? JSONDecoder().decode([VehicleModel].self, from: data) else {
            throw .parseProblems
        }
        return entity.compactMap { $0.domainEntity() }
    }
}
