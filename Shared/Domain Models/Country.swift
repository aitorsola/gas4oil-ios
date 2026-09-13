//
//  Country.swift
//  Gas4Oil
//

import Foundation

enum Country: String, CaseIterable, Codable, Identifiable {
    case spain
    case france
    case portugal
    case italy
    case croatia
    
    var id: String {
        rawValue
    }
    
    static let storageKey = "listView.country"
    
    var idOffset: Int {
        switch self {
        case .spain, .france:
            return 0
        case .portugal:
            return 100_000_000
        case .italy:
            return 200_000_000
        case .croatia:
            return 300_000_000
        }
    }
    
    init?(isoCode: String?) {
        switch isoCode?.uppercased() {
        case "ES":
            self = .spain
        case "FR":
            self = .france
        case "PT":
            self = .portugal
        case "IT":
            self = .italy
        case "HR":
            self = .croatia
        default:
            return nil
        }
    }
    
    var flag: String {
        switch self {
        case .spain:
            return "🇪🇸"
        case .france:
            return "🇫🇷"
        case .portugal:
            return "🇵🇹"
        case .italy:
            return "🇮🇹"
        case .croatia:
            return "🇭🇷"
        }
    }
    
    var code: String {
        switch self {
        case .spain:
            return "ES"
        case .france:
            return "FR"
        case .portugal:
            return "PT"
        case .italy:
            return "IT"
        case .croatia:
            return "HR"
        }
    }
    
    var name: String {
        switch self {
        case .spain:
            return "country.spain".translated
        case .france:
            return "country.france".translated
        case .portugal:
            return "country.portugal".translated
        case .italy:
            return "country.italy".translated
        case .croatia:
            return "country.croatia".translated
        }
    }
    
    var fuels: [FuelType] {
        switch self {
        case .spain:
            return [.gas95, .gas95Premium, .gas98, .diesel, .dieselPremium, .glp]
        case .france:
            return [.e10, .gas95, .gas98, .e85, .diesel, .glp]
        case .portugal:
            return [.gas95, .gas95Premium, .gas98, .diesel, .dieselPremium, .glp]
        case .italy:
            return [.gas95, .gas95Premium, .diesel, .dieselPremium, .glp]
        case .croatia:
            return [.gas95, .gas95Premium, .gas98, .diesel, .dieselPremium, .glp]
        }
    }
    
    var defaultFuel: FuelType {
        switch self {
        case .spain:
            return .gas95
        case .france:
            return .e10
        case .portugal, .italy, .croatia:
            return .gas95
        }
    }
    
    var suggestedCities: [String] {
        switch self {
        case .spain:
            return ["madrid", "barcelona", "valencia", "sevilla", "zaragoza", "málaga",
                    "murcia", "palma de mallorca", "bilbao", "alicante/alacant",
                    "valladolid", "vigo", "gijón", "córdoba"]
        case .france:
            return ["paris", "marseille", "lyon", "toulouse", "nice", "nantes",
                    "montpellier", "strasbourg", "bordeaux", "lille", "rennes",
                    "reims", "toulon", "grenoble"]
        case .portugal:
            return ["lisboa", "porto", "vila nova de gaia", "braga", "coimbra", "funchal",
                    "setúbal", "aveiro", "faro", "leiria", "sintra", "cascais",
                    "évora", "guimarães"]
        case .italy:
            return ["roma", "milano", "napoli", "torino", "palermo", "genova", "bologna",
                    "firenze", "bari", "catania", "venezia", "verona", "messina", "padova"]
        case .croatia:
            return ["zagreb", "split", "rijeka", "osijek", "zadar", "pula", "slavonski brod",
                    "karlovac", "varaždin", "šibenik", "dubrovnik", "sisak", "koprivnica", "bjelovar"]
        }
    }
    
    static func provider(for country: Country) -> ServiceStationsAPI {
        switch country {
        case .spain:
            return Network()
        case .france:
            return FranceStationsAPI()
        case .portugal:
            return PortugalStationsAPI()
        case .italy:
            return ItalyStationsAPI()
        case .croatia:
            return CroatiaStationsAPI()
        }
    }
}
