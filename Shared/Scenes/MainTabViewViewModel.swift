//
//  MainTabViewViewModel.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 11/3/22.
//

import Observation

@MainActor
@Observable
final class MainTabViewViewModel {
    
    let listViewViewModel = StationsListViewViewModel()
    let favoriteViewViewModel = FavoriteListViewViewModel()
}
