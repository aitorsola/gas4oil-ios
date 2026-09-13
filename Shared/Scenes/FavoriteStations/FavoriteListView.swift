//
//  FavoriteListView.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 11/3/22.
//

import SwiftUI

struct FavoriteListView: View {
    
    private let viewModel: FavoriteListViewViewModel
#if os(macOS)
    @State private var selectedStationID: Station.ID?
#endif
    
    init(viewModel: FavoriteListViewViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
#if os(macOS)
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 340, ideal: 380, max: 460)
        } detail: {
            if let station = viewModel.favoriteStations.first(where: { $0.id == selectedStationID }) {
                StationDetailView(station: station) {
                    viewModel.removeFavorite(station)
                    selectedStationID = nil
                }
            } else {
                ContentUnavailableView(viewModel.favoriteStations.isEmpty
                                       ? "favorites.empty".translated
                                       : "listView.detail.empty".translated,
                                       systemImage: "star")
            }
        }
#else
        NavigationStack {
            Group {
                if viewModel.favoriteStations.isEmpty {
                    Text("favorites.empty".translated)
                } else {
                    phoneList
                }
            }
            .navigationTitle("favorites.title".translated)
        }
#endif
    }
    
#if os(macOS)
    private var sidebar: some View {
        List(viewModel.favoriteStations, selection: $selectedStationID) { station in
            StationSidebarRow(station: station, fuel: viewModel.preferredFuel)
                .contextMenu {
                    Button {
                        viewModel.removeFavorite(station)
                    } label: {
                        Label("listView.station.removeFavorite".translated, systemImage: "star.slash")
                    }
                    Button {
                        station.openInMaps()
                    } label: {
                        Label("listView.station.directions".translated,
                              systemImage: "arrow.triangle.turn.up.right.circle")
                    }
                }
        }
        .listStyle(.sidebar)
        .navigationTitle("favorites.title".translated)
    }
#else
    private var phoneList: some View {
        List(viewModel.favoriteStations) { station in
            ZStack(alignment: .leading) {
                NavigationLink(value: station) { EmptyView() }.opacity(0)
                getStationView(station)
            }
            .hidingOuterSeparators(isFirst: station.id == viewModel.favoriteStations.first?.id,
                                   isLast: station.id == viewModel.favoriteStations.last?.id)
        }
        .listStyle(.plain)
        .navigationDestination(for: Station.self) { station in
            MapView(station: station)
        }
    }
#endif
}

extension FavoriteListView {
    

    private func getStationView(_ station: Station) -> StationView {
        var fillPrice: Double?
        let vehicle = VehicleFavorite.vehicleData
        if let vehicle,
           let unitPrice = station.price(for: vehicle.fuel),
           let litres = vehicle.capacityLitres {
            fillPrice = unitPrice * litres
        }
        return StationView(prices: PriceColumn.columns(for: station),
                           brand: station.displayTitle,
                           address: station.displayAddress,
                           schedule: station.horario,
                           coordinates: station.getCLLocationCoordinates(),
                           showFavButton: false,
                           directionsAction: { station.openInMaps() },
                           fillPrice: fillPrice,
                           isFav: station.isFav)
    }
}

struct FavoriteListView_Previews: PreviewProvider {
    static var previews: some View {
        FavoriteListView(viewModel: FavoriteListViewViewModel())
    }
}
