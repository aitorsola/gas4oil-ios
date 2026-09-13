//
//  StationDetailView.swift
//  Gas4Oil
//

import MapKit
import SwiftUI

struct StationDetailView: View {
    
    let station: Station
    var onToggleFavorite: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            MapView(station: station)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension StationDetailView {
    
    var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                CommonStationBrand(rotulo: station.rotulo).roundIcon(size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.brandName.uppercased())
                        .font(.customSize(22, weight: .bold))
                    Text(station.direccion.capitalized + " · " + station.municipio.capitalized)
                        .font(.customSize(14))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                distance
                if onToggleFavorite != nil {
                    favouriteButton
                }
            }
            
            HStack(spacing: 12) {
                priceTile("95E5", station.gasolina95E5, .green)
                priceTile("Diesel", station.gasoleoA, .gray)
                priceTile("98E5", station.gasolina98E5, .red)
            }
            
            HStack(spacing: 12) {
                Label(station.horario, systemImage: "clock")
                    .font(.customSize(13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 12)
                Button {
                    station.openInMaps()
                } label: {
                    Label("listView.station.directions".translated,
                          systemImage: "arrow.triangle.turn.up.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding(20)
    }
    
    var favouriteButton: some View {
        Button {
            onToggleFavorite?()
        } label: {
            Image(systemName: station.isFav ? "star.fill" : "star")
                .font(.customSize(20))
                .foregroundStyle(.orange)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: station.isFav)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(station.isFav
              ? "listView.station.removeFavorite".translated
              : "listView.station.addFavorite".translated)
        .accessibilityLabel(station.isFav
                            ? "listView.station.removeFavorite".translated
                            : "listView.station.addFavorite".translated)
    }
    
    @ViewBuilder
    var distance: some View {
        switch Location.distanceFromPoint(station.getCLLocationCoordinates()) {
        case .km(let value):
            distanceText("\(value.toString()) km.")
        case .metters(let value):
            distanceText("\(value.toString()) m.")
        case .none:
            EmptyView()
        }
    }
    
    func distanceText(_ text: String) -> some View {
        Label(text, systemImage: "location.fill")
            .font(.customSize(16, weight: .bold))
            .foregroundStyle(.orange)
    }
    
    func priceTile(_ title: String, _ price: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.customSize(15, weight: .bold))
                .foregroundStyle(color)
            Text(price.isEmpty ? "--" : price + " €")
                .font(.customSize(20, weight: .medium))
                .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct StationSidebarRow: View {
    
    let station: Station
    let fuel: FuelType
    
    var body: some View {
        HStack(spacing: 10) {
            CommonStationBrand(rotulo: station.rotulo).roundIcon(size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(station.brandName.uppercased())
                    .font(.customSize(14, weight: .bold))
                    .lineLimit(1)
                Text(station.direccion.capitalized)
                    .font(.customSize(12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if station.isFav {
                Image(systemName: "star.fill")
                    .font(.customSize(11))
                    .foregroundStyle(.orange)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(price.isEmpty ? "--" : price + " €")
                    .font(.customSize(15, weight: .semibold))
                distance
            }
        }
        .padding(.vertical, 6)
    }
    
    private var price: String {
        station.rawPrice(for: fuel)
    }
    
    @ViewBuilder
    private var distance: some View {
        switch Location.distanceFromPoint(station.getCLLocationCoordinates()) {
        case .km(let value):
            Text("\(value.toString()) km.").font(.customSize(11)).foregroundStyle(.secondary)
        case .metters(let value):
            Text("\(value.toString()) m.").font(.customSize(11)).foregroundStyle(.secondary)
        case .none:
            EmptyView()
        }
    }
}
