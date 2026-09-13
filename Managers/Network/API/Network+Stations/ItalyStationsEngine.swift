//
//  ItalyStationsEngine.swift
//  Gas4Oil
//

import Foundation

private enum ItalyEndpoints {
    static let prices = "https://www.mimit.gov.it/images/exportCSV/prezzo_alle_8.csv"
    static let registry = "https://www.mimit.gov.it/images/exportCSV/anagrafica_impianti_attivi.csv"
}

struct ItalyStationsAPI: ServiceStationsAPI {
    
    private let network = Network()
    
    func getAllStations() async throws(G4OError) -> [Station] {
        async let pricesData = network.perform(Request(url: ItalyEndpoints.prices, method: .get))
        async let registryData = network.perform(Request(url: ItalyEndpoints.registry, method: .get))
        let prices: Data
        let registry: Data
        do {
            (prices, registry) = try await (pricesData, registryData)
        } catch let error as G4OError {
            throw error
        } catch {
            throw .networkProblem(error)
        }
        let stations = ItalyFeed.stations(registry: ItalyFeed.rows(registry), prices: ItalyFeed.rows(prices))
        guard !stations.isEmpty else {
            throw .parseProblems
        }
        return stations
    }
}

enum ItalyFeed {
    
    private enum RegistryColumn {
        static let id = 0
        static let brand = 2
        static let address = 5
        static let municipality = 6
        static let province = 7
    }
    
    private enum PriceColumn {
        static let id = 0
        static let fuelName = 1
        static let price = 2
        static let isSelfService = 3
    }
    
    private static let premiumPetrolNames = ["Benzina speciale", "Blue Super", "HiQ Perform+",
                                             "Benzina WR 100", "Benzina Plus 98", "V-Power"]
    private static let premiumDieselNames = ["Blue Diesel", "Supreme Diesel", "Hi-Q Diesel", "Gasolio speciale",
                                             "Gasolio Premium", "Diesel Shell V Power", "DieselMax", "Excellium Diesel"]
    
    static func rows(_ data: Data) -> [[String]] {
        let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        return text.split(separator: "\n").dropFirst(2).map {
            $0.trimmingCharacters(in: .newlines).components(separatedBy: "|")
        }
    }
    
    private static func fuel(for name: String) -> FuelType? {
        switch name {
        case "Benzina":
            return .gas95
        case "Gasolio":
            return .diesel
        case "GPL":
            return .glp
        default:
            if premiumPetrolNames.contains(name) {
                return .gas95Premium
            }
            if premiumDieselNames.contains(name) {
                return .dieselPremium
            }
            return nil
        }
    }
    
    private static func brand(_ name: String) -> String {
        switch name.lowercased() {
        case "pompe bianche":
            return ""
        case "agip eni":
            return "Eni"
        case "api-ip":
            return "IP"
        default:
            return name
        }
    }
    
    private static func splitAddress(_ raw: String) -> (street: String, postalCode: String) {
        let parts = raw.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").filter { !$0.isEmpty }
        if let last = parts.last, last.count == 5, Int(last) != nil {
            return (parts.dropLast().joined(separator: " "), last)
        }
        return (parts.joined(separator: " "), "")
    }
    
    static func stations(registry: [[String]], prices: [[String]]) -> [Station] {
        var selfServicePrices: [Int: [FuelType: String]] = [:]
        var attendedPrices: [Int: [FuelType: String]] = [:]
        for row in prices where row.count >= 4 {
            guard let id = Int(row[PriceColumn.id]),
                  let fuel = fuel(for: row[PriceColumn.fuelName]),
                  let value = Double(row[PriceColumn.price]) else {
                continue
            }
            let text = String(format: "%.3f", value).replacingOccurrences(of: ".", with: ",")
            if row[PriceColumn.isSelfService] == "1" {
                selfServicePrices[id, default: [:]][fuel] = selfServicePrices[id]?[fuel] ?? text
            } else {
                attendedPrices[id, default: [:]][fuel] = attendedPrices[id]?[fuel] ?? text
            }
        }
        return registry.compactMap { row in
            guard row.count >= 10,
                  let id = Int(row[RegistryColumn.id]),
                  let latitude = Double(row[row.count - 2]),
                  let longitude = Double(row[row.count - 1]),
                  latitude != 0, longitude != 0 else {
                return nil
            }
            let prices = attendedPrices[id, default: [:]]
                .merging(selfServicePrices[id, default: [:]]) { _, selfService in selfService }
            guard !prices.isEmpty else {
                return nil
            }
            let address = splitAddress(row[RegistryColumn.address])
            let stationID = Country.italy.idOffset + id
            return Station(id: stationID,
                           cp: address.postalCode,
                           provincia: row[RegistryColumn.province].lowercased(),
                           municipio: row[RegistryColumn.municipality].lowercased(),
                           direccion: address.street,
                           horario: "",
                           longitude: longitude,
                           latitude: latitude,
                           gasNaturalComprimido: "",
                           gasNaturalLicuado: "",
                           gasoleoA: prices[.diesel] ?? "",
                           gasoleoB: "",
                           gasoleoPremium: prices[.dieselPremium] ?? "",
                           gasolina95E10: "",
                           gasolina95E5: prices[.gas95] ?? "",
                           gasolina95E5Premium: prices[.gas95Premium] ?? "",
                           gasolina98E10: "",
                           gasolina98E5: "",
                           hidrogeno: "",
                           glp: prices[.glp] ?? "",
                           rotulo: brand(row[RegistryColumn.brand]),
                           isFav: FavoriteStations.isFavorite(stationID),
                           country: .italy)
        }
    }
}
