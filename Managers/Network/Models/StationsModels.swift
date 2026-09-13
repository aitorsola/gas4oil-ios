//
//  StationsModels.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 4/3/22.
//

import CoreLocation

struct StationsResponse: Decodable, DomainConvertible {
    
    let date: String
    let prices: [ListaEESSPrecio]
    
    enum CodingKeys: String, CodingKey {
        case date = "Fecha"
        case prices = "ListaEESSPrecio"
    }
    
    func domainEntity() -> Stations? {
        let stations = prices.compactMap({$0.domainEntity()})
        return Stations(stations: stations)
    }
    
    struct ListaEESSPrecio: Decodable, DomainConvertible {
        
        let id: String
        let cp: String
        let provincia: String
        let municipio: String
        let direccion: String
        let horario: String
        let longitud: String
        let latitud: String
        let gasNaturalComprimido: String
        let gasNaturalLicuado: String
        let gasoleoA: String
        let gasoleoB: String
        let gasoleoPremium: String
        let gasolina95E10: String
        let gasolina95E5: String
        let gasolina95E5Premium: String
        let gasolina98E10: String
        let gasolina98E5: String
        let hidrogeno: String
        let glp: String
        let rotulo: String
        
        enum CodingKeys: String, CodingKey {
            case id = "IDEESS"
            case cp = "C.P."
            case provincia = "Provincia"
            case municipio = "Municipio"
            case direccion = "Dirección"
            case horario = "Horario"
            case longitud = "Longitud (WGS84)"
            case latitud = "Latitud"
            case gasNaturalComprimido = "Precio Gas Natural Comprimido"
            case gasNaturalLicuado = "Precio Gas Natural Licuado"
            case gasoleoA = "Precio Gasoleo A"
            case gasoleoB = "Precio Gasoleo B"
            case gasoleoPremium = "Precio Gasoleo Premium"
            case gasolina95E10 = "Precio Gasolina 95 E10"
            case gasolina95E5 = "Precio Gasolina 95 E5"
            case gasolina95E5Premium = "Precio Gasolina 95 E5 Premium"
            case gasolina98E10 = "Precio Gasolina 98 E10"
            case gasolina98E5 = "Precio Gasolina 98 E5"
            case hidrogeno = "Precio Hidrogeno"
            case glp = "Precio Gases licuados del petróleo"
            case rotulo = "Rótulo"
            
        }
        
        func domainEntity() -> Station? {
            guard let id = Int(id) else {
                return nil
            }
            
            return Station(id: id,
                           cp: cp,
                           provincia: provincia.lowercased(),
                           municipio: municipio.lowercased(),
                           direccion: direccion,
                           horario: horario,
                           longitude: Double(longitud.replacingOccurrences(of: ",", with: ".")) ?? 0,
                           latitude: Double(latitud.replacingOccurrences(of: ",", with: ".")) ?? 0,
                           gasNaturalComprimido: gasNaturalComprimido,
                           gasNaturalLicuado: gasNaturalLicuado,
                           gasoleoA: gasoleoA,
                           gasoleoB: gasoleoB,
                           gasoleoPremium: gasoleoPremium,
                           gasolina95E10: gasolina95E10,
                           gasolina95E5: gasolina95E5,
                           gasolina95E5Premium: gasolina95E5Premium,
                           gasolina98E10: gasolina98E10,
                           gasolina98E5: gasolina98E5,
                           hidrogeno: hidrogeno,
                           glp: glp,
                           rotulo: rotulo,
                           isFav: FavoriteStations.isFavorite(id))
        }
    }
}
