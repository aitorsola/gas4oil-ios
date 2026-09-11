//
//  MainTabView.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 9/3/22.
//

import SwiftUI

private enum TabSelectedType: Int {
    case stations
    case vehicle
    case favorite
}

struct MainTabView: View {
    
    @State private var tabSelected: Int = TabSelectedType.stations.rawValue
    @State private var canShowFavorites: Bool = false
    @State private var showAlert: Bool = false
    
    @State private var viewModel = MainTabViewViewModel()
    
#if os(iOS)
    @EnvironmentObject var appDelegate: AppDelegate
#endif
    
    var body: some View {
        VStack {
            
            TabView(selection: $tabSelected) {
                
                StationsListView(viewModel: viewModel.listViewViewModel)
                    .tag(TabSelectedType.stations.rawValue)
                    .tabItem {
                        VStack {
                            Image(systemName: "fuelpump.fill")
#if os(macOS)
                            Text("mainTab.stationsTabTitle".translated)
#endif
                        }
                    }
                
                VehicleView(stationsViewModel: viewModel.listViewViewModel) {
                    // Saving a tank size changes every fill price in the list.
                    viewModel.listViewViewModel.refresh()
                }
                    .tag(TabSelectedType.vehicle.rawValue)
                    .tabItem {
                        VStack {
                            Image(systemName: "car.fill")
#if os(macOS)
                            Text("mainTab.vehicle".translated)
#endif
                        }
                    }
#if os(macOS)
                    .frame(minWidth: 420, maxWidth: .infinity)
#endif
                
                FavoriteListView(viewModel: viewModel.favoriteViewViewModel)
                    .tag(TabSelectedType.favorite.rawValue)
                    .tabItem {
                        VStack {
                            Image(systemName: "star.fill")
#if os(macOS)
                            Text("mainTab.favTabTitle".translated)
#endif
                        }
                    }
                    // @Observable has no Combine publisher to subscribe to; onChange observes
                    // the property directly.
                    .onChange(of: viewModel.listViewViewModel.favorites, initial: true) { _, stations in
                        viewModel.favoriteViewViewModel.updateFavoriteStations(allStations: stations)
                    }
                
            }
            .padding(.top, 10)
            .font(.headline)
        }
#if os(iOS)
        .ignoresSafeArea()
#endif
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
