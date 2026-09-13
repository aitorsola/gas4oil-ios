//
//  PortugalStationsEngine.swift
//  Gas4Oil
//

import Foundation

private enum PortugalEndpoints {
    static let stations = "https://precoscombustiveis.dgeg.gov.pt/api/PrecoComb/PesquisarPostos"
    static let fuelIDs = "3201,3205,3400,2101,2105,1120"
}

struct PortugalStationsAPI: ServiceStationsAPI {
    
    private let network = Network()
    
    func getAllStations() async throws(G4OError) -> [Station] {
        let request = Request(url: PortugalEndpoints.stations,
                              method: .get,
                              parameters: ["idsTiposComb": PortugalEndpoints.fuelIDs,
                                           "qtdPorPagina": "30000",
                                           "pagina": "1"])
        let data = try await network.perform(request)
        guard let response = try? JSONDecoder().decode(PortugalResponse.self, from: data) else {
            throw .parseProblems
        }
        return response.stations()
    }
}

struct PortugalResponse: Decodable {
    
    let results: [Row]
    
    enum CodingKeys: String, CodingKey {
        case results = "resultado"
    }
    
    struct Row: Decodable {
        let id: Int
        let brand: String?
        let address: String?
        let postalCode: String?
        let municipality: String?
        let district: String?
        let latitude: Double
        let longitude: Double
        let priceText: String?
        let fuelName: String?
        
        enum CodingKeys: String, CodingKey {
            case id = "Id"
            case brand = "Marca"
            case address = "Morada"
            case postalCode = "CodPostal"
            case municipality = "Municipio"
            case district = "Distrito"
            case latitude = "Latitude"
            case longitude = "Longitude"
            case priceText = "Preco"
            case fuelName = "Combustivel"
        }
        
        var fuel: FuelType? {
            switch fuelName {
            case "Gasolina simples 95":
                return .gas95
            case "Gasolina especial 95":
                return .gas95Premium
            case "Gasolina 98":
                return .gas98
            case "Gasóleo simples":
                return .diesel
            case "Gasóleo especial":
                return .dieselPremium
            case "GPL Auto":
                return .glp
            default:
                return nil
            }
        }
        
        var price: String {
            (priceText ?? "")
                .replacingOccurrences(of: "€", with: "")
                .trimmingCharacters(in: .whitespaces)
        }
        
        var brandName: String {
            let value = (brand ?? "").trimmingCharacters(in: .whitespaces)
            return value.lowercased() == "genérico" ? "" : value
        }
    }
    
    func stations() -> [Station] {
        var byID: [Int: Station] = [:]
        var order: [Int] = []
        for row in results {
            guard let fuel = row.fuel else {
                continue
            }
            if byID[row.id] == nil {
                order.append(row.id)
                let id = Country.portugal.idOffset + row.id
                byID[row.id] = Station(id: id,
                                       cp: row.postalCode ?? "",
                                       provincia: (row.district ?? "").lowercased(),
                                       municipio: (row.municipality ?? "").lowercased(),
                                       direccion: row.address ?? "",
                                       horario: "",
                                       longitude: row.longitude,
                                       latitude: row.latitude,
                                       gasNaturalComprimido: "",
                                       gasNaturalLicuado: "",
                                       gasoleoA: "",
                                       gasoleoB: "",
                                       gasoleoPremium: "",
                                       gasolina95E10: "",
                                       gasolina95E5: "",
                                       gasolina95E5Premium: "",
                                       gasolina98E10: "",
                                       gasolina98E5: "",
                                       hidrogeno: "",
                                       glp: "",
                                       rotulo: row.brandName,
                                       isFav: FavoriteStations.isFavorite(id),
                                       country: .portugal)
            }
            switch fuel {
            case .gas95:
                byID[row.id]?.gasolina95E5 = row.price
            case .gas95Premium:
                byID[row.id]?.gasolina95E5Premium = row.price
            case .gas98:
                byID[row.id]?.gasolina98E5 = row.price
            case .diesel:
                byID[row.id]?.gasoleoA = row.price
            case .dieselPremium:
                byID[row.id]?.gasoleoPremium = row.price
            case .glp:
                byID[row.id]?.glp = row.price
            case .e10, .e85:
                break
            }
        }
        return order.compactMap { byID[$0] }
    }
}
