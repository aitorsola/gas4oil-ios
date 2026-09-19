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
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        VStack {
            
            TabView(selection: $tabSelected) {
                
                StationsListView(viewModel: viewModel.listViewViewModel)
                    .tint(.primary)
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
                    viewModel.listViewViewModel.vehicleDidChange()
                }
                    .tint(.primary)
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
                    .tint(.primary)
                    .tag(TabSelectedType.favorite.rawValue)
                    .tabItem {
                        VStack {
                            Image(systemName: "star.fill")
#if os(macOS)
                            Text("mainTab.favTabTitle".translated)
#endif
                        }
                    }
                    .onChange(of: viewModel.listViewViewModel.favorites, initial: true) { _, stations in
                        viewModel.favoriteViewViewModel.updateFavoriteStations(allStations: stations)
                    }
                
            }
            .padding(.top, 10)
            .font(.headline)
            .tint(.primary)
        }
        .task {
            viewModel.listViewViewModel.start()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                viewModel.listViewViewModel.didBecomeActive()
            }
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
