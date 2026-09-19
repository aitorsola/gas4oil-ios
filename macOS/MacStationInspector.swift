//
//  MacStationInspector.swift
//  Gas4Oil (macOS)
//

import MapKit
import SwiftUI

struct MacStationInspector: View {
    
    let model: MacAppModel
    
    var body: some View {
        if let station = model.selectedStation {
            MacStationDetail(model: model, station: station)
        } else {
            StateView(icon: "fuelpump", title: "listView.detail.empty".translated)
        }
    }
}

struct MacStationDetail: View {
    
    let model: MacAppModel
    let station: Station
    
    @State private var lookAroundScene: MKLookAroundScene?
    
    private var isFavorite: Bool {
        model.isFavorite(station)
    }
    
    var body: some View {
        Form {
            Section {
                header
                actions
            }
            Section("mac.inspector.prices".translated) {
                let columns = pricedFuels
                if columns.isEmpty {
                    Text("mac.inspector.noPrices".translated)
                        .foregroundStyle(.secondary)
                }
                ForEach(columns, id: \.self) { fuel in
                    LabeledContent {
                        Text(MacFormat.price(station.rawPrice(for: fuel)))
                            .monospacedDigit()
                            .fontWeight(fuel == model.stations.selectedFuel ? .bold : .regular)
                    } label: {
                        Label {
                            Text(fuel.name)
                        } icon: {
                            Circle()
                                .fill(fuel.columnColor)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                if let cost = fillCost {
                    LabeledContent("myVehicle.fill.title".translated, value: MacFormat.cost(cost))
                }
            }
            Section("mac.inspector.info".translated) {
                LabeledContent("mac.column.address".translated) {
                    Text(station.fullAddress)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.trailing)
                }
                if let distance = model.stations.distance(to: station) {
                    LabeledContent("mac.column.distance".translated, value: MacFormat.distance(distance))
                }
                if !station.horario.isEmpty {
                    LabeledContent("station.schedule".translated) {
                        Text(station.horario)
                            .multilineTextAlignment(.trailing)
                    }
                }
                if let services = station.services, !services.isEmpty {
                    LabeledContent("mac.inspector.services".translated) {
                        Text(services.joined(separator: ", "))
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            if let lookAroundScene {
                Section("mac.inspector.lookAround".translated) {
                    LookAroundPreview(initialScene: lookAroundScene)
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .id(station.id)
                }
            }
        }
        .formStyle(.grouped)
        .task(id: station.id) {
            lookAroundScene = nil
            guard station.hasValidCoordinates else {
                return
            }
            let request = MKLookAroundSceneRequest(coordinate: CLLocationCoordinate2D(latitude: station.latitude,
                                                                                      longitude: station.longitude))
            lookAroundScene = try? await request.scene
        }
    }
    
    private var pricedFuels: [FuelType] {
        (station.country ?? model.stations.country).fuels.filter { !station.rawPrice(for: $0).isEmpty }
    }
    
    private var fillCost: Double? {
        guard let vehicle = VehicleFavorite.vehicleData,
              let litres = vehicle.capacityLitres,
              let price = station.price(for: vehicle.fuel) else {
            return nil
        }
        return price * litres
    }
    
    private var header: some View {
        HStack(spacing: 10) {
            CommonStationBrand(rotulo: station.rotulo).roundIcon(size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(station.displayTitle.uppercased())
                    .font(.headline)
                    .lineLimit(2)
                Text(station.municipio.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
    
    private var actions: some View {
        HStack {
            Button {
                station.openInMaps()
            } label: {
                Label("listView.station.directions".translated, systemImage: "arrow.triangle.turn.up.right.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!station.hasValidCoordinates)
            Spacer(minLength: 4)
            Button {
                model.toggleFavorite(station)
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? Color.yellow : Color.primary)
            }
            .help((isFavorite ? "listView.station.removeFavorite" : "listView.station.addFavorite").translated)
            ShareLink(item: station.mapsURL, subject: Text(station.displayTitle)) {
                Image(systemName: "square.and.arrow.up")
            }
            .help("mac.menu.share".translated)
        }
    }
}

/// Stand-alone window opened by double-clicking a station.
struct MacStationWindow: View {
    
    let model: MacAppModel
    let stationID: Station.ID?
    
    var body: some View {
        Group {
            if let stationID, let station = model.station(with: stationID) {
                HSplitView {
                    MacStationDetail(model: model, station: station)
                        .frame(minWidth: 280, idealWidth: 320, maxWidth: 420)
                    MapView(station: station)
                        .frame(minWidth: 320)
                }
                .navigationTitle(station.displayTitle.capitalized)
                .navigationSubtitle(station.municipio.capitalized)
            } else if model.stations.isLoading || model.stations.isPreparing {
                SwiftUI.ProgressView("common.loading".translated)
            } else if let error = model.stations.loadError {
                StateView(error: error) {
                    model.retry()
                }
            } else {
                StateView(icon: "fuelpump.slash",
                          title: "mac.station.unavailable".translated,
                          message: "mac.station.unavailable.hint".translated)
            }
        }
        .frame(minWidth: 640, minHeight: 420)
        .modifier(MacAppearance())
    }
}
