//
//  CroatiaStationsEngine.swift
//  Gas4Oil
//

import Foundation

private enum CroatiaEndpoints {
    static let all = "https://mzoe-gor.hr/data.json"
}

struct CroatiaStationsAPI: ServiceStationsAPI {
    
    private let network = Network()
    
    func getAllStations() async throws(G4OError) -> [Station] {
        let data = try await network.perform(Request(url: CroatiaEndpoints.all, method: .get))
        guard let feed = try? JSONDecoder().decode(CroatiaFeed.self, from: data) else {
            throw .parseProblems
        }
        return feed.stations()
    }
}

struct CroatiaFeed: Decodable {
    
    struct StationRow: Decodable {
        let id: Int
        let address: String?
        let town: String?
        let operatorID: Int?
        let latitudeText: String?
        let longitudeText: String?
        let openingHours: [OpeningHours]?
        let prices: [Price]?
        
        enum CodingKeys: String, CodingKey {
            case id
            case address = "adresa"
            case town = "mjesto"
            case operatorID = "obveznik_id"
            case latitudeText = "long"
            case longitudeText = "lat"
            case openingHours = "radnaVremena"
            case prices = "cjenici"
        }
    }
    
    struct OpeningHours: Decodable {
        let dayTypeID: Int
        let opens: String?
        let closes: String?
        
        enum CodingKeys: String, CodingKey {
            case dayTypeID = "vrsta_dana_id"
            case opens = "pocetak"
            case closes = "kraj"
        }
    }
    
    struct Price: Decodable {
        let fuelID: Int
        let value: Double?
        
        enum CodingKeys: String, CodingKey {
            case fuelID = "gorivo_id"
            case value = "cijena"
        }
    }
    
    struct Fuel: Decodable {
        let id: Int
        let kindID: Int?
        
        enum CodingKeys: String, CodingKey {
            case id
            case kindID = "vrsta_goriva_id"
        }
    }
    
    struct Operator: Decodable {
        let id: Int
        let name: String?
        
        enum CodingKeys: String, CodingKey {
            case id
            case name = "naziv"
        }
    }
    
    private enum FuelKind {
        static let petrol95WithAdditives = 1
        static let petrol95 = 2
        static let petrol100WithAdditives = 5
        static let petrol100 = 6
        static let dieselWithAdditives = 7
        static let diesel = 8
        static let lpg = 9
    }
    
    private enum DayType {
        static let weekday = 1
        static let saturday = 2
        static let sunday = 3
    }
    
    let stationRows: [StationRow]
    let fuels: [Fuel]
    let operators: [Operator]
    
    enum CodingKeys: String, CodingKey {
        case stationRows = "postajas"
        case fuels = "gorivos"
        case operators = "obvezniks"
    }
    
    private static let legalSuffixes = [" j.d.o.o.", " d.o.o.", " d.d.", " d.o.o", " d.d"]
    
    private static func brand(_ name: String?) -> String {
        var value = name ?? ""
        for separator in [" – ", " - "] {
            if let range = value.range(of: separator) {
                value = String(value[..<range.lowerBound])
            }
        }
        for suffix in legalSuffixes where value.lowercased().hasSuffix(suffix) {
            value = String(value.dropLast(suffix.count))
        }
        value = value.trimmingCharacters(in: .whitespaces)
        return value == "-" ? "" : value
    }
    
    private static func price(_ value: Double) -> String {
        String(format: "%.3f", value).replacingOccurrences(of: ".", with: ",")
    }
    
    private static func schedule(_ hours: [OpeningHours]?) -> String {
        guard let hours, !hours.isEmpty else {
            return ""
        }
        let labels = [DayType.weekday: "L-V", DayType.saturday: "S", DayType.sunday: "D"]
        var parts: [(String, String)] = []
        for day in [DayType.weekday, DayType.saturday, DayType.sunday] {
            guard let entry = hours.first(where: { $0.dayTypeID == day }),
                  let opens = entry.opens?.prefix(5), let closes = entry.closes?.prefix(5) else {
                continue
            }
            let allDay = opens == closes || (opens == "00:00" && (closes == "23:59" || closes == "24:00"))
            let range = allDay ? "24H" : "\(opens)-\(closes)"
            parts.append((labels[day] ?? "", range))
        }
        let ranges = Set(parts.map(\.1))
        if parts.count == 3, ranges.count == 1, let range = ranges.first {
            return "L-D: \(range)"
        }
        return parts.map { "\($0.0): \($0.1)" }.joined(separator: "; ")
    }
    
    func stations() -> [Station] {
        let kindByFuelID = Dictionary(fuels.map { ($0.id, $0.kindID ?? 0) }, uniquingKeysWith: { first, _ in first })
        let brandByOperatorID = Dictionary(operators.map { ($0.id, Self.brand($0.name)) },
                                           uniquingKeysWith: { first, _ in first })
        return stationRows.compactMap { row in
            guard let latitude = Double(row.latitudeText ?? ""), let longitude = Double(row.longitudeText ?? "") else {
                return nil
            }
            var cheapestByKind: [Int: Double] = [:]
            for entry in row.prices ?? [] {
                guard let value = entry.value, value > 0, let kind = kindByFuelID[entry.fuelID] else {
                    continue
                }
                cheapestByKind[kind] = min(cheapestByKind[kind] ?? value, value)
            }
            func basePlusPremium(_ kinds: [Int]) -> (base: String, premium: String) {
                let values = kinds.compactMap { cheapestByKind[$0] }.sorted()
                guard let base = values.first else {
                    return ("", "")
                }
                let premium = values.count > 1 ? Self.price(values[values.count - 1]) : ""
                return (Self.price(base), premium)
            }
            let petrol = basePlusPremium([FuelKind.petrol95WithAdditives, FuelKind.petrol95])
            let diesel = basePlusPremium([FuelKind.dieselWithAdditives, FuelKind.diesel])
            let petrol100 = basePlusPremium([FuelKind.petrol100WithAdditives, FuelKind.petrol100])
            let lpg = cheapestByKind[FuelKind.lpg]
            guard !petrol.base.isEmpty || !diesel.base.isEmpty || lpg != nil else {
                return nil
            }
            let id = Country.croatia.idOffset + row.id
            return Station(id: id,
                           cp: "",
                           provincia: "",
                           municipio: (row.town ?? "").lowercased(),
                           direccion: (row.address ?? "").capitalized,
                           horario: Self.schedule(row.openingHours),
                           longitude: longitude,
                           latitude: latitude,
                           gasNaturalComprimido: "",
                           gasNaturalLicuado: "",
                           gasoleoA: diesel.base,
                           gasoleoB: "",
                           gasoleoPremium: diesel.premium,
                           gasolina95E10: "",
                           gasolina95E5: petrol.base,
                           gasolina95E5Premium: petrol.premium,
                           gasolina98E10: "",
                           gasolina98E5: petrol100.base,
                           hidrogeno: "",
                           glp: lpg.map(Self.price) ?? "",
                           rotulo: brandByOperatorID[row.operatorID ?? -1] ?? "",
                           isFav: FavoriteStations.isFavorite(id),
                           country: .croatia)
        }
    }
}
