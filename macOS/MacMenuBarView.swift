//
//  MacMenuBarView.swift
//  Gas4Oil (macOS)
//

import SwiftUI

struct MacMenuBarView: View {
    
    let model: MacAppModel
    
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    
    private var stations: StationsListViewViewModel {
        model.stations
    }
    
    private var fuel: FuelType {
        stations.selectedFuel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            if let error = stations.loadError {
                Label(error.title, systemImage: error.icon)
                    .font(.callout.weight(.semibold))
                Text(error.errorDescription ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("common.retry".translated) {
                    model.retry()
                }
            } else if stations.isLoading || stations.isAwaitingLocation {
                HStack(spacing: 8) {
                    SwiftUI.ProgressView()
                        .controlSize(.small)
                    Text("common.loading".translated)
                        .foregroundStyle(.secondary)
                }
            } else if let cheapest = stations.cheapestNearby {
                sectionTitle("listView.cheapest.title".translated(fuel.name))
                stationRow(cheapest)
            } else if !stations.hasChosenCountry || stations.needsCityChoice {
                Text("mac.menuBar.setup".translated)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("listView.empty".translated)
                    .foregroundStyle(.secondary)
            }
            if !stations.favorites.isEmpty {
                Divider()
                sectionTitle("favorites.title".translated)
                ForEach(stations.favorites.prefix(6)) { station in
                    stationRow(station)
                }
            }
            if stations.refreshFailed {
                Label("error.refreshFailed".translated, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            footer
        }
        .padding(12)
        .frame(width: 300)
        .modifier(MacAppearance())
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(stations.navigationTitle ?? stations.country.name)
                    .font(.headline)
                if let updated = stations.lastUpdated {
                    Text("mac.subtitle.updated".translated(updated.formatted(date: .omitted, time: .shortened)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                model.refresh()
            } label: {
                if model.isRefreshing {
                    SwiftUI.ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .disabled(!model.canRefresh)
            .help("mac.help.refresh".translated)
        }
    }
    
    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }
    
    private func stationRow(_ station: Station) -> some View {
        Button {
            showMainWindow()
            model.showsFavorites = false
            model.selectedStationID = station.id
        } label: {
            HStack(spacing: 8) {
                CommonStationBrand(rotulo: station.rotulo).roundIcon(size: 22)
                VStack(alignment: .leading, spacing: 0) {
                    Text(station.displayTitle.capitalized)
                        .lineLimit(1)
                    Text([station.municipio.capitalized,
                          stations.distance(to: station).map { MacFormat.distance($0) }]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Text(MacFormat.price(station.rawPrice(for: fuel)))
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("listView.station.directions".translated) {
                station.openInMaps()
            }
        }
    }
    
    private var footer: some View {
        HStack {
            Button("mac.menuBar.open".translated) {
                showMainWindow()
            }
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .help("mac.menuBar.settings".translated)
            Spacer()
            Button("mac.menuBar.quit".translated) {
                NSApp.terminate(nil)
            }
        }
        .controlSize(.small)
    }
    
    private func showMainWindow() {
        openWindow(id: MacWindowID.main)
        NSApp.activate(ignoringOtherApps: true)
    }
}
