//
//  StationsEngine.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 4/3/22.
//

import CoreLocation

protocol ServiceStationsAPI: Sendable {
    func getAllStations() async throws(G4OError) -> [Station]
}

private enum StationsEndpoints {
    static let allStations = "https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/EstacionesTerrestres/"
}

extension Network: ServiceStationsAPI {
    
    func getAllStations() async throws(G4OError) -> [Station] {
        let data = try await perform(Request(url: StationsEndpoints.allStations, method: .get))
        guard let entity = try? JSONDecoder().decode(StationsResponse.self, from: data),
              let stations = entity.domainEntity()?.stations else {
            throw .parseProblems
        }
        return stations
    }
}
