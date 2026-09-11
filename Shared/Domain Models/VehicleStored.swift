//
//  VehicleStored.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 25/3/22.
//

import Foundation

enum FuelType: Codable, CaseIterable {
    case gas95
    case gas98
    case diesel
}

struct VehicleStored: Codable, Equatable {
    var brand: String
    var model: String
    var capacity: String
    var fuel: FuelType
    
    /// Tank size in litres, or `nil` when what was typed is not a usable number.
    /// Accepts both `55` and `55,5`, since the keyboard offers the locale's separator.
    var capacityLitres: Double? {
        let normalised = capacity
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(normalised), value > 0, value < 500 else {
            return nil
        }
        return value
    }
    
    /// Capacity is the only field the app actually computes with; make and model are labels.
    var isValid: Bool {
        capacityLitres != nil
    }
    
    var displayName: String {
        let name = [brand, model]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? "myVehicle.unnamed".translated : name
    }
    
    func isEmpty() -> Bool {
        brand.isEmpty || model.isEmpty || capacity.isEmpty
    }
    
    mutating func reset() {
        brand = ""
        model = ""
        capacity = ""
        fuel = .gas95
    }
}
