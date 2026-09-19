//
//  MacStationsMap.swift
//  Gas4Oil (macOS)
//

import MapKit
import SwiftUI

struct MacStationsMap: View {
    
    @Bindable var model: MacAppModel
    
    @State private var position: MapCameraPosition = .automatic
    @State private var didFit = false
    @State private var tappedID: Station.ID?
    @State private var showsPrices = false
    @Namespace private var mapScope
    
    /// Zoomed out, a couple of hundred price labels pile up on each other, so they
    /// collapse into dots until the visible area is small enough to read them.
    private static let labelledSpan = 0.12
    private static let alwaysLabelledLimit = 25
    
    private var fuel: FuelType {
        model.stations.selectedFuel
    }
    
    private var stations: [Station] {
        model.displayedStations.filter(\.hasValidCoordinates)
    }
    
    /// A station picked from the menu bar or the sidebar card may be filtered out of the list.
    private var pinnedStations: [Station] {
        let stations = stations
        guard let selected = model.selectedStation, selected.hasValidCoordinates,
              !stations.contains(where: { $0.id == selected.id }) else {
            return stations
        }
        return stations + [selected]
    }
    
    var body: some View {
        let stations = stations
        let scale = MacPriceScale(prices: stations.compactMap { $0.price(for: fuel) })
        Map(position: $position, scope: mapScope) {
            UserAnnotation()
            ForEach(pinnedStations) { station in
                Annotation(station.displayTitle,
                           coordinate: CLLocationCoordinate2D(latitude: station.latitude,
                                                              longitude: station.longitude),
                           anchor: .bottom) {
                    MacPricePin(price: MacFormat.price(station.rawPrice(for: fuel)),
                                showsPrice: showsPrices || stations.count <= Self.alwaysLabelledLimit,
                                color: scale.color(for: station.price(for: fuel)),
                                isSelected: station.id == model.selectedStationID) {
                        tappedID = station.id
                        model.selectedStationID = station.id
                    }
                    .contextMenu {
                        MacStationActions(model: model, station: station)
                    }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapZoomStepper()
            MapCompass()
            MapUserLocationButton()
            MapScaleView()
        }
        .mapScope(mapScope)
        .onMapCameraChange(frequency: .onEnd) { context in
            showsPrices = context.region.span.latitudeDelta < Self.labelledSpan
        }
        .overlay(alignment: .bottomLeading) {
            legend(scale)
        }
        .overlay(alignment: .topLeading) {
            Button {
                fitAll()
            } label: {
                Label("mac.map.fitAll".translated, systemImage: "arrow.up.left.and.arrow.down.right")
                    .labelStyle(.iconOnly)
            }
            .help("mac.map.fitAll".translated)
            .padding(.horizontal, 10)
            .padding(.top, 16)
        }
        .onChange(of: model.selectedStationID) { _, id in
            focus(on: id)
        }
        .onChange(of: stations.map(\.id)) { _, _ in
            fitAll()
        }
        .onAppear {
            if model.selectedStation.map(\.hasValidCoordinates) == true {
                focus(on: model.selectedStationID)
            } else if !didFit {
                fitAll(animated: false)
            }
        }
    }
    
    private var isNearbyMode: Bool {
        model.isShowingNearby
    }
    
    private func fitAll(animated: Bool = true) {
        didFit = true
        let target = fittedRegion().map { MapCameraPosition.region($0) } ?? .automatic
        if animated {
            withAnimation {
                position = target
            }
        } else {
            position = target
        }
    }
    
    /// `.automatic` also frames the user's own position and every stray match, which for a
    /// searched town zooms out to half the country. The region is built by hand instead:
    /// around the user and the closest stations when browsing nearby, and around the bulk
    /// of the stations (outliers trimmed) for a town or the favourites.
    private func fittedRegion() -> MKCoordinateRegion? {
        let stations = stations
        guard !stations.isEmpty else {
            return nil
        }
        var latitudes: [Double]
        var longitudes: [Double]
        if isNearbyMode, let here = model.stations.currentCoordinate {
            let closest = stations
                .sorted { (model.stations.distance(to: $0) ?? 0) < (model.stations.distance(to: $1) ?? 0) }
                .prefix(Self.nearbyFitCount)
            latitudes = closest.map(\.latitude) + [here.latitude]
            longitudes = closest.map(\.longitude) + [here.longitude]
        } else {
            latitudes = Self.trimmed(stations.map(\.latitude))
            longitudes = Self.trimmed(stations.map(\.longitude))
        }
        guard let minLat = latitudes.min(), let maxLat = latitudes.max(),
              let minLon = longitudes.min(), let maxLon = longitudes.max() else {
            return nil
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: min(max((maxLat - minLat) * 1.35, 0.02), 90),
                                    longitudeDelta: min(max((maxLon - minLon) * 1.35, 0.02), 180))
        return MKCoordinateRegion(center: center, span: span)
    }
    
    /// Drops the outer 5 % at each end of an axis so a namesake town or a province-wide
    /// match does not drag the frame away from where most stations are.
    private static func trimmed(_ values: [Double]) -> [Double] {
        guard values.count >= 10 else {
            return values
        }
        let sorted = values.sorted()
        let cut = sorted.count / 20
        return Array(sorted[cut..<(sorted.count - cut)])
    }
    
    private static let nearbyFitCount = 25
    
    private func focus(on id: Station.ID?) {
        guard let id, id != tappedID,
              let station = pinnedStations.first(where: { $0.id == id }) else {
            tappedID = nil
            return
        }
        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: station.latitude,
                                                                       longitude: station.longitude),
                                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
        withAnimation {
            position = .region(region)
        }
    }
    
    @ViewBuilder
    private func legend(_ scale: MacPriceScale) -> some View {
        if scale.high > scale.low {
            HStack(spacing: 6) {
                Text(scale.low.formatted(.number.precision(.fractionLength(3))))
                LinearGradient(colors: [scale.color(for: scale.low),
                                        scale.color(for: (scale.low + scale.high) / 2),
                                        scale.color(for: scale.high)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: 70, height: 6)
                    .clipShape(Capsule())
                Text(scale.high.formatted(.number.precision(.fractionLength(3))))
            }
            .font(.caption.monospacedDigit())
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: Capsule())
            .padding(10)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("mac.map.legend".translated)
        }
    }
}

private struct MacPricePin: View {
    
    let price: String
    let showsPrice: Bool
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            if showsPrice || isSelected {
                label
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                    .contentShape(Circle().inset(by: -4))
            }
        }
        .buttonStyle(.plain)
        .help(price)
        .accessibilityLabel(price)
        .zIndex(isSelected ? 1 : 0)
    }
    
    private var label: some View {
        Text(price)
            .font(.system(size: isSelected ? 13 : 11, weight: .bold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, isSelected ? 8 : 6)
            .padding(.vertical, isSelected ? 5 : 3)
            .background(color, in: Capsule())
            .overlay(Capsule().strokeBorder(.white, lineWidth: isSelected ? 2.5 : 1))
            .shadow(color: .black.opacity(isSelected ? 0.45 : 0.2), radius: isSelected ? 5 : 2, y: 1)
    }
}
