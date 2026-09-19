//
//  MacStationsTable.swift
//  Gas4Oil (macOS)
//

import SwiftUI

struct MacStationRow: Identifiable {
    
    let station: Station
    let isFavorite: Bool
    let distance: Double?
    let price: Double?
    let fillCost: Double?
    
    var id: Station.ID {
        station.id
    }
    
    var title: String {
        station.displayTitle.uppercased()
    }
    
    var subtitle: String {
        [station.displayAddress.capitalized, town].filter { !$0.isEmpty }.joined(separator: " · ")
    }
    
    var address: String {
        station.displayAddress.capitalized
    }
    
    var town: String {
        station.municipio.capitalized
    }
    
    var schedule: String {
        station.horario
    }
    
    var favoriteRank: Int {
        isFavorite ? 0 : 1
    }
    
    var sortDistance: Double {
        distance ?? .greatestFiniteMagnitude
    }
    
    var sortPrice: Double {
        price ?? .greatestFiniteMagnitude
    }
    
    var sortFillCost: Double {
        fillCost ?? .greatestFiniteMagnitude
    }
}

struct MacStationsTable: View {
    
    @Bindable var model: MacAppModel
    
    @Environment(\.openWindow) private var openWindow
    @State private var sortOrder: [KeyPathComparator<MacStationRow>] = []
    @AppStorage("mac.table.columns.v3") private var columns: TableColumnCustomization<MacStationRow>
    
    private var fuel: FuelType {
        model.stations.selectedFuel
    }
    
    private var rows: [MacStationRow] {
        // Same rule as the inspector and the iOS list: the tank is priced with the vehicle's
        // own fuel, whatever fuel the list is showing.
        let vehicle = VehicleFavorite.vehicleData
        let rows = model.displayedStations.map { station in
            var fillCost: Double?
            if let vehicle, let litres = vehicle.capacityLitres, let unit = station.price(for: vehicle.fuel) {
                fillCost = unit * litres
            }
            return MacStationRow(station: station,
                                 isFavorite: model.isFavorite(station),
                                 distance: model.stations.distance(to: station),
                                 price: station.price(for: fuel),
                                 fillCost: fillCost)
        }
        return sortOrder.isEmpty ? rows : rows.sorted(using: sortOrder)
    }
    
    var body: some View {
        let rows = rows
        let scale = MacPriceScale(prices: rows.compactMap(\.price))
        Table(of: MacStationRow.self,
              selection: $model.selectedStationID,
              sortOrder: $sortOrder,
              columnCustomization: $columns) {
            TableColumn("", value: \.favoriteRank) { row in
                Button {
                    model.toggleFavorite(row.station)
                } label: {
                    Image(systemName: row.isFavorite ? "star.fill" : "star")
                        .font(.body)
                        .foregroundStyle(row.isFavorite ? Color.yellow : Color.secondary)
                }
                .buttonStyle(.plain)
                .help((row.isFavorite ? "listView.station.removeFavorite" : "listView.station.addFavorite").translated)
                .accessibilityLabel((row.isFavorite ? "listView.station.removeFavorite" : "listView.station.addFavorite").translated)
            }
            .width(26)
            .customizationID("favorite")
            .disabledCustomizationBehavior(.visibility)
            
            TableColumn("mac.column.station".translated, value: \.title) { row in
                HStack(spacing: 10) {
                    CommonStationBrand(rotulo: row.station.rotulo).roundIcon(size: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                        Text(row.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 6)
                .help(row.station.fullAddress)
            }
            .width(min: 160, ideal: 210)
            .customizationID("station")
            .disabledCustomizationBehavior(.visibility)
            
            TableColumn(fuel.columnLabel, value: \.sortPrice) { row in
                HStack(spacing: 6) {
                    Circle()
                        .fill(scale.color(for: row.price))
                        .frame(width: 9, height: 9)
                    Text(MacFormat.price(row.station.rawPrice(for: fuel)))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 90, ideal: 104)
            .customizationID("price")
            .disabledCustomizationBehavior(.visibility)
            
            TableColumn("mac.column.distance".translated, value: \.sortDistance) { row in
                Text(MacFormat.distance(row.distance))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 60, ideal: 72)
            .customizationID("distance")
            
            TableColumn("mac.column.fill".translated, value: \.sortFillCost) { row in
                Text(MacFormat.cost(row.fillCost))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 84)
            .customizationID("fill")
            
            TableColumn("mac.column.address".translated, value: \.address) { row in
                Text(row.address)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(row.station.fullAddress)
            }
            .width(min: 100, ideal: 170)
            .defaultVisibility(.hidden)
            .customizationID("address")
            
            TableColumn("mac.column.town".translated, value: \.town)
                .width(min: 80, ideal: 120)
                .defaultVisibility(.hidden)
                .customizationID("town")
            
            TableColumn("station.schedule".translated, value: \.schedule) { row in
                Text(row.schedule)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(row.schedule)
            }
            .width(min: 80, ideal: 160)
            .defaultVisibility(.hidden)
            .customizationID("schedule")
        } rows: {
            ForEach(rows) { row in
                TableRow(row)
                    .draggable(row.station.mapsURL)
            }
        }
        .contextMenu(forSelectionType: Station.ID.self) { ids in
            if let id = ids.first, let station = model.station(with: id) {
                MacStationActions(model: model, station: station)
            }
        } primaryAction: { ids in
            ids.forEach { openWindow(id: MacWindowID.station, value: $0) }
        }
        // A header sort would otherwise silently override the order picked in the toolbar.
        .onChange(of: model.stations.effectiveSort) { _, _ in
            sortOrder = []
        }
        .onChange(of: model.showsFavorites) { _, _ in
            sortOrder = []
        }
        .onKeyPress(.return) {
            guard let station = model.selectedStation else {
                return .ignored
            }
            station.openInMaps()
            return .handled
        }
    }
}

/// Shared by the table's context menu, the inspector and the map callouts.
struct MacStationActions: View {
    
    let model: MacAppModel
    let station: Station
    
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        let isFavorite = model.isFavorite(station)
        Button {
            station.openInMaps()
        } label: {
            Label("listView.station.directions".translated, systemImage: "arrow.triangle.turn.up.right.circle")
        }
        Button {
            model.toggleFavorite(station)
        } label: {
            Label((isFavorite ? "listView.station.removeFavorite" : "listView.station.addFavorite").translated,
                  systemImage: isFavorite ? "star.slash" : "star")
        }
        Divider()
        Button {
            openWindow(id: MacWindowID.station, value: station.id)
        } label: {
            Label("mac.menu.openInWindow".translated, systemImage: "macwindow")
        }
        Button {
            model.copyAddress(of: station)
        } label: {
            Label("mac.menu.copyAddress".translated, systemImage: "doc.on.doc")
        }
        ShareLink(item: station.mapsURL, subject: Text(station.displayTitle)) {
            Label("mac.menu.share".translated, systemImage: "square.and.arrow.up")
        }
    }
}
