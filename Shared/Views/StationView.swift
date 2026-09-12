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

struct StationView: View {
    
    let price95: String
    let price98: String
    let priceDiesel: String
    let brand: String
    let address: String
    let schedule: String
    let coordinates: CLLocation
    let showFavButton: Bool
    /// Opens directions to this station; nil hides the button.
    var directionsAction: (() -> Void)?
    let fillPrice: Double?
    let isFav: Bool
    
    var favCompletion: (() -> Void)?
    
    /// Matches the price header's fill so the whole cell uses one neutral surface.
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

// MARK: - Prices

private extension StationView {
    
    /// Unchanged: the fuel tags and their prices stay exactly as they were.
    var pricesHeader: some View {
        HStack {
            VStack(spacing: 10) {
                Text("95E5")
                    .font(.customSize(20, weight: .bold))
                    .foregroundColor(.green)
                Text(price95.isEmpty ? "--" : price95 + " €")
                    .foregroundColor(.orange)
                    .font(.customSize(20, weight: .medium))
            }.padding(10)
            Spacer()
            VStack(spacing: 10) {
                Text("Diesel")
                    .font(.customSize(20, weight: .bold))
                    .foregroundColor(Color(.darkGray))
                Text(priceDiesel.isEmpty ? "--" : priceDiesel + " €")
                    .foregroundColor(.orange)
                    .font(.customSize(20, weight: .medium))
            }.padding(10)
            Spacer()
            VStack(spacing: 10) {
                Text("98E5")
                    .font(.customSize(20, weight: .bold))
                    .foregroundColor(.red)
                Text(price98.isEmpty ? "--" : price98 + " €")
                    .foregroundColor(.orange)
                    .font(.customSize(20, weight: .medium))
            }.padding(10)
        }
        .background(Self.actionFill, in: RoundedRectangle(cornerRadius: 15))
    }
}

// MARK: - Details

private extension StationView {
    
    /// Brand, distance and the favourite toggle share one line: they are the three things you
    /// scan for, and keeping them together is what lets the cell stay short.
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
    
    /// Actions get a row of their own, sized for a glance-and-tap in the car: the directions
    /// button is full width and labelled, and the star gets the 44pt target it always needed.
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
            Text(String(format: "%.2f", fillPrice) + "€")
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
            StationView(price95: "1,966",
                        price98: "2,065",
                        priceDiesel: "1,964",
                        brand: "Ballenoil",
                        address: "C/ Miralrio 113, 3º 2",
                        schedule: "L-V: 07:30-22:00; S: 08:00-22:00; D: 09:00-21:00",
                        coordinates: CLLocation(latitude: 40.42500000, longitude: -3.68300000),
                        showFavButton: true,
                        fillPrice: 80,
                        isFav: false)
            Divider()
            StationView(price95: "1,899",
                        price98: "",
                        priceDiesel: "1,799",
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
