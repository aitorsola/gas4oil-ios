//
//  VehicleStored.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 25/3/22.
//

import Foundation

enum FuelType: Codable, CaseIterable {
    case gas95
    case gas95Premium
    case gas98
    case diesel
    case dieselPremium
    case glp
}

extension FuelType {
    
    var storageKey: String {
        switch self {
        case .gas95:
            return "gas95"
        case .gas95Premium:
            return "gas95Premium"
        case .gas98:
            return "gas98"
        case .diesel:
            return "diesel"
        case .dieselPremium:
            return "dieselPremium"
        case .glp:
            return "glp"
        }
    }
    
    init?(storageKey: String) {
        guard let match = FuelType.allCases.first(where: { $0.storageKey == storageKey }) else {
            return nil
        }
        self = match
    }
}

struct VehicleStored: Codable, Equatable {
    var brand: String
    var model: String
    var capacity: String
    var fuel: FuelType
    
    var capacityLitres: Double? {
        let normalised = capacity
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(normalised), value > 0, value < 500 else {
            return nil
        }
        return value
    }
    
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
