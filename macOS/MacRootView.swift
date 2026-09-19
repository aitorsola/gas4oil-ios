//
//  MacRootView.swift
//  Gas4Oil (macOS)
//

import SwiftUI

struct MacRootView: View {
    
    @Bindable var model: MacAppModel
    
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isSearchFocused: Bool
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    private var stations: StationsListViewViewModel {
        model.stations
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            MacSidebar(model: model)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            VStack(spacing: 0) {
                if stations.refreshFailed {
                    refreshFailedBanner
                }
                // As an overlay the state screens cannot feed their own size back into the split
                // view, which otherwise grows taller than the window and shifts the sidebar up.
                Color.clear
                    .overlay {
                        content
                    }
            }
            .inspector(isPresented: $model.showsInspector) {
                MacStationInspector(model: model)
                    .inspectorColumnWidth(min: 240, ideal: 300, max: 420)
            }
        }
        .navigationTitle(model.windowTitle)
        .navigationSubtitle(model.windowSubtitle)
        .toolbar {
            toolbarContent
        }
        .searchable(text: $model.searchText,
                    placement: .toolbar,
                    prompt: Text("listView.search.placeholder".translated))
        .searchFocused($isSearchFocused)
        .searchSuggestions {
            searchSuggestions
        }
        .onSubmit(of: .search) {
            model.submitSearch()
        }
        .onChange(of: model.searchText) { _, _ in
            model.searchTextChanged()
        }
        .onChange(of: model.searchFocusTick) { _, _ in
            takeSearchFocus()
        }
        .onAppear {
            takeSearchFocus()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                stations.didBecomeActive()
            }
        }
        .alert("mac.location.denied.title".translated, isPresented: $model.showsLocationDeniedAlert) {
            Button("mac.location.openSettings".translated) {
                model.openLocationSettings()
            }
            Button("common.cancel".translated, role: .cancel) { }
        } message: {
            Text("mac.location.denied.message".translated)
        }
        .alert("listView.city.noMatches".translated, isPresented: $model.showsNoSearchMatches) {
            Button("common.ok".translated, role: .cancel) { }
        } message: {
            Text("mac.search.noMatches.hint".translated(model.searchText))
        }
        .modifier(MacAppearance())
    }
}

private extension MacRootView {
    
    func takeSearchFocus() {
        guard model.searchFocusPending else {
            return
        }
        model.searchFocusPending = false
        isSearchFocused = true
    }
}

// MARK: - Content states

private extension MacRootView {
    
    @ViewBuilder
    var content: some View {
        if model.showsFavorites {
            if stations.favorites.isEmpty {
                StateView(icon: "star",
                          title: "favorites.empty".translated,
                          message: "mac.favorites.empty.hint".translated)
            } else {
                stationsContent
            }
        } else if stations.needsCountryChoice {
            MacCountryChooser(model: model)
        } else if stations.isPreparing || stations.isLoading || stations.isAwaitingLocation {
            loading
        } else if let error = stations.loadError {
            StateView(error: error) {
                model.retry()
            }
        } else if stations.needsCityChoice {
            cityChoice
        } else if stations.stations.isEmpty {
            emptyResults
        } else {
            stationsContent
        }
    }
    
    var loading: some View {
        VStack(spacing: 12) {
            SwiftUI.ProgressView()
                .controlSize(.large)
            Text((stations.isAwaitingLocation && !stations.isLoading
                  ? "common.gettingLocation" : "common.loading").translated)
                .foregroundStyle(.secondary)
        }
    }
    
    var cityChoice: some View {
        StateView(icon: stations.locationFailed ? "location.slash" : "mappin.and.ellipse",
                  title: "listView.city.prompt".translated,
                  message: (stations.locationFailed
                            ? "listView.city.locationFailed" : "mac.city.hint").translated,
                  actionTitle: "listView.city.useLocation".translated) {
            model.useMyLocation()
        }
    }
    
    var emptyResults: some View {
        StateView(icon: "fuelpump.slash",
                  title: "listView.empty".translated,
                  message: "listView.empty.hint".translated,
                  actionTitle: stations.hasActiveFilters ? "mac.filters.reset".translated : nil,
                  action: stations.hasActiveFilters ? {
            model.searchText = ""
            stations.resetFilters()
        } : nil)
    }
    
    @ViewBuilder
    var stationsContent: some View {
        switch model.viewMode {
        case .split:
            MacSplitLayout {
                MacStationsTable(model: model)
            } trailing: {
                MacStationsMap(model: model)
            }
        case .table:
            MacStationsTable(model: model)
        case .map:
            MacStationsMap(model: model)
        }
    }
    
    var refreshFailedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("error.refreshFailed".translated)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button("common.retry".translated) {
                model.refresh()
            }
            .disabled(!model.canRefresh)
            Button {
                stations.dismissRefreshFailure()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("mac.banner.dismiss".translated)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.yellow.opacity(0.14))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
    
    @ViewBuilder
    var searchSuggestions: some View {
        let query = model.searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            let matches = stations.searchResults(text: query)
            if matches.isEmpty, stations.isLoaded {
                Text("listView.city.noMatches".translated)
                    .foregroundStyle(.secondary)
            }
            ForEach(matches.prefix(8), id: \.self) { town in
                Label {
                    VStack(alignment: .leading) {
                        Text(town.capitalized)
                        if let province = stations.province(of: town), province != town {
                            Text(province.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: "mappin")
                }
                .searchCompletion(town.capitalized)
            }
        }
    }
}

// MARK: - Toolbar

private extension MacRootView {
    
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(id: "location", placement: .navigation) {
            Button {
                model.useMyLocation()
            } label: {
                Label("listView.city.useLocation".translated,
                      systemImage: model.isShowingNearby ? "location.fill" : "location")
            }
            .help("mac.help.location".translated)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Picker("common.fuelType".translated, selection: fuelBinding) {
                ForEach(stations.country.fuels, id: \.self) { fuel in
                    Label(fuel.name, systemImage: "drop")
                        .labelStyle(.titleAndIcon)
                        .tag(fuel)
                }
            }
            .help("mac.help.fuel".translated)
            
            Picker("mac.toolbar.brand".translated, selection: brandBinding) {
                Label("listView.brand.all".translated, systemImage: "fuelpump.fill")
                    .labelStyle(.titleAndIcon)
                    .tag("")
                Divider()
                ForEach(stations.brandOptions) { option in
                    MacBrandLabel(option: option).tag(option.key)
                }
            }
            .disabled(stations.brandOptions.isEmpty || model.showsFavorites)
            .help("mac.help.brand".translated)
            
            Picker("listView.sort.title".translated, selection: sortBinding) {
                ForEach(stations.availableSorts, id: \.self) { order in
                    Label(order.title, systemImage: order.icon)
                        .labelStyle(.titleAndIcon)
                        .tag(order)
                }
            }
            .disabled(model.showsFavorites)
            .help("mac.help.sort".translated)
            
            Picker("country.title".translated, selection: countryBinding) {
                ForEach(Country.allCases) { country in
                    Text(country.flag + " " + country.name).tag(country)
                }
            }
            .help("country.title".translated)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Picker("mac.view.title".translated, selection: $model.viewMode) {
                ForEach(MacViewMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .help("mac.view.title".translated)
            
            Button {
                model.refresh()
            } label: {
                if model.isRefreshing {
                    SwiftUI.ProgressView()
                        .controlSize(.small)
                } else {
                    Label("mac.menu.refresh".translated, systemImage: "arrow.clockwise")
                }
            }
            .disabled(!model.canRefresh)
            .help("mac.help.refresh".translated)
            
            Button {
                model.showsInspector.toggle()
            } label: {
                Label("mac.menu.inspector".translated, systemImage: "sidebar.trailing")
            }
            .help("mac.menu.inspector".translated)
        }
    }
    
    var fuelBinding: Binding<FuelType> {
        Binding { stations.selectedFuel } set: { stations.showFuel($0) }
    }
    
    var sortBinding: Binding<StationSort> {
        Binding { stations.effectiveSort } set: { stations.showSorted($0) }
    }
    
    var countryBinding: Binding<Country> {
        Binding { stations.country } set: { newValue in
            model.searchText = ""
            model.selectedStationID = nil
            stations.showCountry(newValue)
        }
    }
    
    var brandBinding: Binding<String> {
        Binding {
            model.brandSelectionKey
        } set: { key in
            stations.showByBrand(key.isEmpty ? .all : .brand(key))
        }
    }
}

// MARK: - Brand label

/// Brand name with its logo, for the brand pickers in the toolbar and the View menu.
struct MacBrandLabel: View {
    
    let option: StationsListViewViewModel.StationBrand
    
    var body: some View {
        Label {
            Text(option.title)
        } icon: {
            if let logo = option.logo?.roundedMenuImage(size: 18) {
                logo.renderingMode(.original)
            } else {
                Image(systemName: "fuelpump")
            }
        }
        .labelStyle(.titleAndIcon)
    }
}

// MARK: - Split layout

/// `HSplitView` lets a `Table` push the detail column wider than the window, so the split
/// between list and map is laid out by hand: a stored fraction and a draggable divider.
struct MacSplitLayout<Leading: View, Trailing: View>: View {
    
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing
    
    @AppStorage("mac.split.fraction") private var fraction = 0.5
    @State private var dragStart: Double?
    
    private let minLeading: CGFloat = 300
    private let minTrailing: CGFloat = 240
    
    var body: some View {
        GeometryReader { proxy in
            let total = proxy.size.width
            let leadingWidth = clamped(total * fraction, total: total)
            HStack(spacing: 0) {
                leading
                    .frame(width: leadingWidth)
                divider(total: total, leadingWidth: leadingWidth)
                trailing
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func clamped(_ width: CGFloat, total: CGFloat) -> CGFloat {
        min(max(width, minLeading), max(minLeading, total - minTrailing))
    }
    
    private func divider(total: CGFloat, leadingWidth: CGFloat) -> some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1)
            .overlay {
                Color.clear
                    .frame(width: 9)
                    .contentShape(Rectangle())
                    .pointerStyle(.columnResize)
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { value in
                                let start = dragStart ?? leadingWidth
                                dragStart = start
                                guard total > 0 else {
                                    return
                                }
                                fraction = clamped(start + value.translation.width, total: total) / total
                            }
                            .onEnded { _ in
                                dragStart = nil
                            }
                    )
            }
            .zIndex(1)
    }
}

// MARK: - Sidebar

struct MacSidebar: View {
    
    let model: MacAppModel
    
    private var selection: Binding<MacSidebarItem?> {
        Binding { model.sidebarSelection } set: { item in
            if let item {
                model.select(item)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            list
            if let station = model.stations.cheapestNearby, !model.stations.isLoading, !model.stations.needsCityChoice {
                MacCheapestCard(model: model, station: station)
            }
        }
    }
    
    private var list: some View {
        List(selection: selection) {
            Section("mac.sidebar.explore".translated) {
                Label(model.stations.detectedCity?.capitalized ?? "mac.sidebar.nearby".translated,
                      systemImage: model.stations.isLocationDenied ? "location.slash" : "location")
                    .tag(MacSidebarItem.nearby)
                Label("favorites.title".translated, systemImage: "star")
                    .badge(model.stations.favorites.count)
                    .tag(MacSidebarItem.favorites)
            }
            if !model.sidebarCities.isEmpty {
                Section("mac.sidebar.cities".translated) {
                    ForEach(model.sidebarCities, id: \.self) { city in
                        Label(city.capitalized, systemImage: "building.2")
                            .tag(MacSidebarItem.city(city))
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

private struct MacCheapestCard: View {
    
    let model: MacAppModel
    let station: Station
    
    var body: some View {
        Button {
            model.showsFavorites = false
            model.selectedStationID = station.id
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("listView.cheapest.title".translated(model.stations.selectedFuel.tag))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline) {
                    Text(station.displayTitle.capitalized)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(MacFormat.price(station.rawPrice(for: model.stations.selectedFuel)))
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(10)
        .help("mac.help.cheapest".translated)
    }
}

// MARK: - Country chooser

struct MacCountryChooser: View {
    
    let model: MacAppModel
    
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "globe.europe.africa")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("listView.country.prompt".translated)
                .font(.title2.weight(.semibold))
            Text("mac.country.hint".translated)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            VStack(spacing: 6) {
                ForEach(Country.allCases) { country in
                    Button {
                        model.stations.showCountry(country)
                    } label: {
                        HStack {
                            Text(country.flag)
                            Text(country.name)
                            Spacer()
                        }
                        .frame(width: 220)
                    }
                    .controlSize(.large)
                }
            }
            if model.stations.locationFailed {
                Label("mac.country.locationFailed".translated, systemImage: "location.slash")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if !model.stations.isLocationDenied {
                Button("listView.city.useLocation".translated) {
                    model.stations.requestLocation()
                }
                .buttonStyle(.link)
            }
        }
        .padding(32)
    }
}
