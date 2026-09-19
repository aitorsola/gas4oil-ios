//
//  MacCommands.swift
//  Gas4Oil (macOS)
//

import SwiftUI

struct MacCommands: Commands {
    
    @Bindable var model: MacAppModel
    
    @Environment(\.openWindow) private var openWindow
    
    private var stations: StationsListViewViewModel {
        model.stations
    }
    
    var body: some Commands {
        CommandGroup(replacing: .newItem) { }
        
        CommandGroup(after: .textEditing) {
            Button("mac.menu.find".translated) {
                openWindow(id: MacWindowID.main)
                model.focusSearch()
            }
            .keyboardShortcut("f", modifiers: .command)
        }
        
        CommandGroup(after: .toolbar) {
            Picker("mac.view.title".translated, selection: $model.viewMode) {
                ForEach(Array(MacViewMode.allCases.enumerated()), id: \.element) { index, mode in
                    Label(mode.title, systemImage: mode.icon)
                        .labelStyle(.titleAndIcon)
                        .tag(mode)
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command, .option])
                }
            }
            .pickerStyle(.inline)
            Button((model.showsInspector ? "mac.menu.inspector.hide" : "mac.menu.inspector.show").translated) {
                model.showsInspector.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            Divider()
            Picker("listView.sort.title".translated, selection: sortBinding) {
                ForEach(Array(stations.availableSorts.enumerated()), id: \.element) { index, order in
                    Label(order.title, systemImage: order.icon)
                        .labelStyle(.titleAndIcon)
                        .tag(order)
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
            .pickerStyle(.inline)
            Picker("common.fuelType".translated, selection: fuelBinding) {
                ForEach(stations.country.fuels, id: \.self) { fuel in
                    Label(fuel.name, systemImage: "drop")
                        .labelStyle(.titleAndIcon)
                        .tag(fuel)
                }
            }
            Picker("mac.toolbar.brand".translated, selection: brandBinding) {
                Text("listView.brand.all".translated).tag("")
                ForEach(stations.brandOptions) { option in
                    MacBrandLabel(option: option).tag(option.key)
                }
            }
            .disabled(stations.brandOptions.isEmpty || model.showsFavorites)
            Picker("country.title".translated, selection: countryBinding) {
                ForEach(Country.allCases) { country in
                    Text(country.flag + " " + country.name).tag(country)
                }
            }
            Divider()
            Button("listView.city.useLocation".translated) {
                model.useMyLocation()
            }
            .keyboardShortcut("l", modifiers: .command)
            Button("favorites.title".translated) {
                model.select(.favorites)
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])
            Button("mac.menu.refresh".translated) {
                model.refresh()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(!model.canRefresh)
            Divider()
        }
        
        CommandGroup(replacing: .help) {
            Link("mac.menu.help.project".translated,
                 destination: URL(string: "https://github.com/aitorsola/gas4oil-ios")!)
            Link("mac.menu.help.privacy".translated,
                 destination: URL(string: "https://github.com/aitorsola/gas4oil-ios/blob/master/PRIVACY.md")!)
        }
        
        CommandMenu("mac.menu.station".translated) {
            let station = model.selectedStation
            Group {
                Button("listView.station.directions".translated) {
                    station?.openInMaps()
                }
                .keyboardShortcut(.return, modifiers: .command)
                Button((station.map(model.isFavorite) == true
                        ? "listView.station.removeFavorite" : "listView.station.addFavorite").translated) {
                    model.toggleFavoriteOfSelection()
                }
                .keyboardShortcut("d", modifiers: .command)
                Divider()
                Button("mac.menu.openInWindow".translated) {
                    if let station {
                        openWindow(id: MacWindowID.station, value: station.id)
                    }
                }
                .keyboardShortcut("o", modifiers: .command)
                Button("mac.menu.copyAddress".translated) {
                    if let station {
                        model.copyAddress(of: station)
                    }
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                if let station {
                    ShareLink("mac.menu.share".translated, item: station.mapsURL)
                }
            }
            .disabled(station == nil)
        }
    }
    
    private var fuelBinding: Binding<FuelType> {
        Binding { stations.selectedFuel } set: { stations.showFuel($0) }
    }
    
    private var sortBinding: Binding<StationSort> {
        Binding { stations.effectiveSort } set: { stations.showSorted($0) }
    }
    
    private var countryBinding: Binding<Country> {
        Binding { stations.country } set: { newValue in
            model.searchText = ""
            model.selectedStationID = nil
            stations.showCountry(newValue)
        }
    }
    
    private var brandBinding: Binding<String> {
        Binding {
            model.brandSelectionKey
        } set: { key in
            stations.showByBrand(key.isEmpty ? .all : .brand(key))
        }
    }
}
