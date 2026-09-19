//
//  MacSettingsView.swift
//  Gas4Oil (macOS)
//

import CoreLocation
import SwiftUI

struct MacSettingsView: View {
    
    let model: MacAppModel
    
    var body: some View {
        TabView {
            Tab("mac.settings.general".translated, systemImage: "gearshape") {
                MacGeneralSettings(model: model)
            }
            Tab("mainTab.vehicle".translated, systemImage: "car") {
                VehicleView(stationsViewModel: model.stations) {
                    model.stations.vehicleDidChange()
                }
            }
            Tab("mac.settings.location".translated, systemImage: "location") {
                MacLocationSettings(model: model)
            }
        }
        .frame(width: 520, height: 460)
        .modifier(MacAppearance())
    }
}

private struct MacGeneralSettings: View {
    
    @Bindable var model: MacAppModel
    
    @AppStorage(ThemePreference.storageKey) private var appearance: ThemePreference = .system
    @AppStorage(MacRefreshInterval.storageKey) private var refreshInterval: Int = MacRefreshInterval.half.rawValue
    
    var body: some View {
        Form {
            Section {
                Picker("appearance.title".translated, selection: $appearance) {
                    ForEach(ThemePreference.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section {
                Picker("country.title".translated, selection: countryBinding) {
                    ForEach(Country.allCases) { country in
                        Text(country.flag + " " + country.name).tag(country)
                    }
                }
                Picker("common.fuelType".translated, selection: fuelBinding) {
                    ForEach(model.stations.country.fuels, id: \.self) { fuel in
                        Text(fuel.name).tag(fuel)
                    }
                }
            } footer: {
                Text("mac.settings.country.hint".translated)
            }
            Section {
                Picker("mac.settings.refresh".translated, selection: $refreshInterval) {
                    ForEach(MacRefreshInterval.allCases) { interval in
                        Text(interval.title).tag(interval.rawValue)
                    }
                }
                if let updated = model.stations.lastUpdated {
                    LabeledContent("mac.settings.lastUpdate".translated,
                                   value: updated.formatted(date: .abbreviated, time: .shortened))
                }
            }
            Section {
                Toggle("mac.settings.menuBar".translated, isOn: $model.menuBarEnabled)
                Toggle("mac.settings.menuBar.price".translated, isOn: $model.menuBarShowsPrice)
                    .disabled(!model.menuBarEnabled)
            } footer: {
                Text("mac.settings.menuBar.hint".translated)
            }
        }
        .formStyle(.grouped)
    }
    
    private var countryBinding: Binding<Country> {
        Binding { model.stations.country } set: { newValue in
            model.searchText = ""
            model.selectedStationID = nil
            model.stations.showCountry(newValue)
        }
    }
    
    private var fuelBinding: Binding<FuelType> {
        Binding { model.stations.selectedFuel } set: { model.stations.showFuel($0) }
    }
}

private struct MacLocationSettings: View {
    
    let model: MacAppModel
    
    private var stations: StationsListViewViewModel {
        model.stations
    }
    
    var body: some View {
        Form {
            Section {
                LabeledContent("mac.settings.location.status".translated) {
                    Label(statusTitle, systemImage: statusIcon)
                        .foregroundStyle(stations.isLocationDenied ? Color.red : Color.primary)
                }
                if let city = stations.detectedCity, stations.hasLocation {
                    LabeledContent("mac.settings.location.detected".translated, value: city.capitalized)
                }
                if stations.locationFailed {
                    Label("listView.city.locationFailed".translated, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("landingView.privacy".translated)
            }
            Section {
                if stations.isLocationDenied {
                    Button("mac.location.openSettings".translated) {
                        model.openLocationSettings()
                    }
                } else {
                    Button("listView.city.useLocation".translated) {
                        model.useMyLocation()
                    }
                    .disabled(stations.isLocating)
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private var statusTitle: String {
        if stations.isLocationAuthorized {
            return "mac.settings.location.allowed".translated
        }
        if stations.isLocationDenied {
            return "mac.settings.location.denied".translated
        }
        return "mac.settings.location.notAsked".translated
    }
    
    private var statusIcon: String {
        if stations.isLocationAuthorized {
            return "location.fill"
        }
        return stations.isLocationDenied ? "location.slash.fill" : "location"
    }
}
