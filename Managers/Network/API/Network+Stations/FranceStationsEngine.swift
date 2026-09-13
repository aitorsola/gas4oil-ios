//
//  FranceStationsEngine.swift
//  Gas4Oil
//

import Foundation

private enum FranceEndpoints {
    static let allStations = "https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/exports/json"
    static let fields = "id,adresse,cp,ville,departement,geom,gazole_prix,sp95_prix,e10_prix,sp98_prix,e85_prix,gplc_prix,horaires_automate_24_24,horaires_jour,services_service"
}

struct FranceStationsAPI: ServiceStationsAPI {
    
    private let network = Network()
    
    func getAllStations() async throws(G4OError) -> [Station] {
        let request = Request(url: FranceEndpoints.allStations,
                              method: .get,
                              parameters: ["select": FranceEndpoints.fields])
        let data = try await network.perform(request)
        guard let rows = try? JSONDecoder().decode([FranceStationRow].self, from: data) else {
            throw .parseProblems
        }
        return rows.compactMap { $0.domainEntity() }
    }
}

struct FranceStationRow: Decodable {
    
    struct Coordinates: Decodable {
        let lon: Double
        let lat: Double
    }
    
    let id: Int
    let address: String?
    let postalCode: String?
    let city: String?
    let department: String?
    let coordinates: Coordinates?
    let dieselPrice: Double?
    let sp95Price: Double?
    let e10Price: Double?
    let sp98Price: Double?
    let e85Price: Double?
    let lpgPrice: Double?
    let open24h: String?
    let dailyHours: String?
    let services: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case address = "adresse"
        case postalCode = "cp"
        case city = "ville"
        case department = "departement"
        case coordinates = "geom"
        case dieselPrice = "gazole_prix"
        case sp95Price = "sp95_prix"
        case e10Price = "e10_prix"
        case sp98Price = "sp98_prix"
        case e85Price = "e85_prix"
        case lpgPrice = "gplc_prix"
        case open24h = "horaires_automate_24_24"
        case dailyHours = "horaires_jour"
        case services = "services_service"
    }
    
    private static let shortDays = [
        ("Lundi", "L"), ("Mardi", "M"), ("Mercredi", "X"), ("Jeudi", "J"),
        ("Vendredi", "V"), ("Samedi", "S"), ("Dimanche", "D")
    ]
    
    private static func price(_ value: Double?) -> String {
        guard let value else {
            return ""
        }
        return String(format: "%.3f", value).replacingOccurrences(of: ".", with: ",")
    }
    
    private var schedule: String {
        if open24h == "Oui" {
            return "L-D: 24H"
        }
        guard let dailyHours, !dailyHours.isEmpty else {
            return ""
        }
        let entries: [(String, String)] = dailyHours.components(separatedBy: ", ").compactMap { part in
            guard let day = Self.shortDays.first(where: { part.hasPrefix($0.0) }) else {
                return nil
            }
            let range = part.dropFirst(day.0.count).replacingOccurrences(of: ".", with: ":")
            return (day.1, range)
        }
        let ranges = Set(entries.map(\.1))
        if ranges.count == 1, let range = ranges.first {
            return range == "00:00-00:00" ? "L-D: 24H" : "L-D: \(range)"
        }
        return entries.map { "\($0.0): \($0.1)" }.joined(separator: "; ")
    }
    
    func domainEntity() -> Station? {
        guard let coordinates else {
            return nil
        }
        return Station(id: id,
                       cp: postalCode ?? "",
                       provincia: (department ?? "").lowercased(),
                       municipio: (city ?? "").lowercased(),
                       direccion: address ?? "",
                       horario: schedule,
                       longitude: coordinates.lon,
                       latitude: coordinates.lat,
                       gasNaturalComprimido: "",
                       gasNaturalLicuado: "",
                       gasoleoA: Self.price(dieselPrice),
                       gasoleoB: "",
                       gasoleoPremium: "",
                       gasolina95E10: Self.price(e10Price),
                       gasolina95E5: Self.price(sp95Price),
                       gasolina95E5Premium: "",
                       gasolina98E10: "",
                       gasolina98E5: Self.price(sp98Price),
                       hidrogeno: "",
                       glp: Self.price(lpgPrice),
                       rotulo: "",
                       isFav: FavoriteStations.isFavorite(id),
                       country: .france,
                       e85: Self.price(e85Price),
                       services: services)
    }
}
