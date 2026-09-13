//
//  StationView.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 6/3/22.
//

import SwiftUI
import CoreLocation

extension Formatter {
    static let withSeparator: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter
    }()
}

struct PriceColumn: Identifiable {
    let label: String
    let price: String
    let color: Color
    
    var id: String { label }
    
    static func columns(for station: Station) -> [PriceColumn] {
        FuelType.allCases.compactMap { fuel in
            let price = station.rawPrice(for: fuel)
            guard !price.isEmpty else {
                return nil
            }
            return PriceColumn(label: fuel.columnLabel, price: price, color: fuel.columnColor)
        }
    }
}

extension FuelType {
    
    var columnLabel: String {
        switch self {
        case .gas95:
            return "95E5"
        case .gas95Premium:
            return "95+"
        case .gas98:
            return "98E5"
        case .diesel:
            return "fuel.diesel.short".translated
        case .dieselPremium:
            return "fuel.dieselPremium".translated
        case .glp:
            return "GLP"
        }
    }
    
    var columnColor: Color {
        switch self {
        case .gas95:
            return .green
        case .gas95Premium:
            return .mint
        case .gas98:
            return .red
        case .diesel:
            return Color(.darkGray)
        case .dieselPremium:
            return .indigo
        case .glp:
            return .blue
        }
    }
}

extension FillCost {
    
    static let nearbyRadius: Double = 50_000
    static let minimumCandidates = 20
    
    static func candidates(from stations: [Station]) -> [Station] {
        guard let here = Managers.location.currentCoordinates else {
            return stations
        }
        let byDistance = stations
            .map { ($0, $0.getCLLocationCoordinates().distance(from: here)) }
            .sorted { $0.1 < $1.1 }
        let near = byDistance.filter { $0.1 <= nearbyRadius }
        let chosen = near.isEmpty ? Array(byDistance.prefix(minimumCandidates)) : near
        return chosen.map { $0.0 }
    }
}

struct FillCostCard: View {
    
    let cost: FillCost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("myVehicle.fill.title".translated)
                        .font(.customSize(13))
                        .foregroundStyle(.secondary)
                    Text(cost.cheapest.asEuros)
                        .font(.customSize(30, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                }
                Spacer(minLength: 0)
                CommonStationBrand(rotulo: cost.cheapestStation.rotulo).roundIcon(size: 36)
            }
            HStack(spacing: 6) {
                Text(
                    "myVehicle.fill.cheapestAt".translated(
                        cost.cheapestStation.brandName,
                        cost.cheapestStation.municipio.capitalized
                    )
                )
                .font(.customSize(13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if let distance = Location.distanceFromPoint(cost.cheapestStation.getCLLocationCoordinates()) {
                    Label(distance.text, systemImage: "location.fill")
                        .font(.customSize(13, weight: .semibold))
                        .foregroundStyle(.orange)
                        .layoutPriority(1)
                }
            }
            Button {
                cost.cheapestStation.openInMaps()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                    Text("listView.station.directions".translated)
                }
                .font(.customSize(15, weight: .semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(.orange)
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
    }
}

extension MeasurementUnit {
    
    var text: String {
        switch self {
        case .metters(let value):
            return "\(Int(value)) m"
        case .km(let value):
            return String(format: "%.1f km", value).replacingOccurrences(of: ".", with: ",")
        }
    }
}

struct StationView: View {
    
    let prices: [PriceColumn]
    let brand: String
    let address: String
    let schedule: String
    let coordinates: CLLocation
    let showFavButton: Bool
    var directionsAction: (() -> Void)?
    let fillPrice: Double?
    let isFav: Bool
    
    var favCompletion: (() -> Void)?
    
    fileprivate static let actionFill = Color.gray.opacity(0.15)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            pricesHeader
            brandRow
            Text(address.capitalized)
                .font(.customSize(15))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            scheduleRow
            if let fillPrice = fillPrice, !fillPrice.isZero {
                fillPriceRow(fillPrice)
            }
            actionsRow
        }
        .padding(.vertical, 12)
    }
}

private extension StationView {
    
    var pricesHeader: some View {
        let size: Double
        switch prices.count {
        case 0, 1, 2, 3:
            size = 20
        case 4:
            size = 16
        case 5:
            size = 13
        default:
            size = 11
        }
        return HStack(spacing: 0) {
            ForEach(prices) { column in
                VStack(spacing: 8) {
                    Text(column.label)
                        .font(.customSize(size, weight: .bold))
                        .foregroundColor(column.color)
                    Text(column.price + " €")
                        .foregroundColor(.orange)
                        .font(.customSize(size, weight: .medium))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 2)
            }
        }
        .background(Self.actionFill, in: RoundedRectangle(cornerRadius: 15))
    }
}

private extension StationView {
    
    var brandRow: some View {
        HStack(spacing: 10) {
            CommonStationBrand(rotulo: brand).roundIcon(size: 28)
            Text(brand.uppercased())
                .font(.customSize(18, weight: .bold))
                .lineLimit(1)
            Spacer(minLength: 8)
            getDistanceLabel()
        }
    }
    
    var actionsRow: some View {
        HStack(spacing: 12) {
            if directionsAction != nil {
                directionsButton
            }
            if showFavButton {
                favouriteButton
            }
        }
        .padding(.top, 4)
    }
    
    var directionsButton: some View {
        Button {
            directionsAction?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                    .font(.customSize(18))
                    .foregroundStyle(.orange)
                Text("listView.station.directions".translated)
                    .font(.customSize(16, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Self.actionFill, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
    
    var scheduleRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.customSize(12))
                .foregroundColor(.secondary)
            Text(schedule.capitalized)
                .font(.customSize(13))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
    
    func fillPriceRow(_ fillPrice: Double) -> some View {
        HStack(spacing: 6) {
            Text("station.fillPrice".translated)
                .font(.customSize(13))
                .foregroundColor(.secondary)
            Text(fillPrice.asEuros)
                .foregroundColor(fillPrice < 100 ? .green : .red)
                .font(.customSize(15, weight: .bold, design: .monospaced))
        }
    }
    
    var favouriteButton: some View {
        Button {
            favCompletion?()
        } label: {
            Image(systemName: isFav ? "star.fill" : "star")
                .font(.customSize(20))
                .foregroundStyle(.orange)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: isFav)
                .frame(width: 56, height: 48)
                .background(Self.actionFill, in: RoundedRectangle(cornerRadius: 12))
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
    
    func getDistanceLabel() -> some View {
        HStack(spacing: 4) {
            Image(systemName: "location.fill")
                .font(.customSize(12))
                .foregroundColor(.orange)
            switch Location.distanceFromPoint(coordinates) {
            case .km(let value):
                Text("\(value.toString()) km.")
                    .foregroundColor(.orange)
                    .font(.customSize(15, weight: .bold))
            case .metters(let value):
                Text("\(value.toString()) m.")
                    .foregroundColor(.orange)
                    .font(.customSize(15, weight: .bold))
            case .none:
                EmptyView()
            }
        }
    }
    
}

struct StationView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            StationView(prices: [PriceColumn(label: "95E5", price: "1,966", color: .green),
                                 PriceColumn(label: "Diésel", price: "1,964", color: Color(.darkGray)),
                                 PriceColumn(label: "98E5", price: "2,065", color: .red)],
                        brand: "Ballenoil",
                        address: "C/ Miralrio 113, 3º 2",
                        schedule: "L-V: 07:30-22:00; S: 08:00-22:00; D: 09:00-21:00",
                        coordinates: CLLocation(latitude: 40.42500000, longitude: -3.68300000),
                        showFavButton: true,
                        fillPrice: 80,
                        isFav: false)
            Divider()
            StationView(prices: [PriceColumn(label: "95E5", price: "1,899", color: .green),
                                 PriceColumn(label: "Diésel", price: "1,799", color: Color(.darkGray)),
                                 PriceColumn(label: "Premium", price: "1,899", color: .indigo),
                                 PriceColumn(label: "GLP", price: "1,059", color: .blue)],
                        brand: "Repsol",
                        address: "Glorieta Embajadores, 0",
                        schedule: "L-D: 24H",
                        coordinates: CLLocation(latitude: 40.42500000, longitude: -3.68300000),
                        showFavButton: true,
                        fillPrice: nil,
                        isFav: true)
        }
        .padding(.horizontal)
        .preferredColorScheme(.dark)
    }
}
