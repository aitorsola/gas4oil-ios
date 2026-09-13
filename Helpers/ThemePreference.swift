//
//  ThemePreference.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 12/9/26.
//

import SwiftUI

enum ThemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    
    static let storageKey = "appearance"
    
    var id: String {
        rawValue
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    var title: String {
        switch self {
        case .system:
            return "appearance.system".translated
        case .light:
            return "appearance.light".translated
        case .dark:
            return "appearance.dark".translated
        }
    }
    
    var icon: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }
}
