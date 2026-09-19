//
//  MacAppModel.swift
//  Gas4Oil (macOS)
//

import AppKit
import CoreLocation
import Network
import Observation
import SwiftUI

enum MacViewMode: String, CaseIterable, Identifiable {
    case split
    case table
    case map
    
    var id: String {
        rawValue
    }
    
    var title: String {
        switch self {
        case .split:
            return "mac.view.split".translated
        case .table:
            return "mac.view.table".translated
        case .map:
            return "mac.view.map".translated
        }
    }
    
    var icon: String {
        switch self {
        case .split:
            return "rectangle.split.2x1"
        case .table:
            return "tablecells"
        case .map:
            return "map"
        }
    }
}

enum MacSidebarItem: Hashable {
    case nearby
    case favorites
    case city(String)
}

enum MacRefreshInterval: Int, CaseIterable, Identifiable {
    case off = 0
    case quarter = 15
    case half = 30
    case hour = 60
    
    static let storageKey = "mac.refreshInterval"
    
    var id: Int {
        rawValue
    }
    
    var title: String {
        self == .off ? "mac.settings.refresh.off".translated : "mac.settings.refresh.minutes".translated(rawValue)
    }
}

enum MacWindowID {
    static let main = "main"
    static let station = "station"
}

enum MacDefaults {
    static let menuBarEnabled = "mac.menuBar.enabled"
    static let menuBarShowsPrice = "mac.menuBar.showsPrice"
    static let viewMode = "mac.viewMode"
    static let showsInspector = "mac.showsInspector"
    static let selectedStation = "mac.selectedStation"
}

@MainActor
@Observable
final class MacAppModel {
    
    static let shared = MacAppModel()
    
    let stations = StationsListViewViewModel()
    
    /// Remembered across launches, like the rest of the window state.
    var selectedStationID: Station.ID? {
        didSet {
            defaults.set(selectedStationID, forKey: MacDefaults.selectedStation)
        }
    }
    var showsFavorites = false
    var searchText = ""
    var searchFocusTick = 0
    /// Set until a window takes the focus request; ⌘F can arrive with the window closed.
    var searchFocusPending = false
    var showsLocationDeniedAlert = false
    var showsNoSearchMatches = false
    private(set) var isRefreshing = false
    
    var viewMode: MacViewMode {
        didSet {
            defaults.set(viewMode.rawValue, forKey: MacDefaults.viewMode)
        }
    }
    
    var menuBarEnabled: Bool {
        didSet {
            defaults.set(menuBarEnabled, forKey: MacDefaults.menuBarEnabled)
        }
    }
    
    var menuBarShowsPrice: Bool {
        didSet {
            defaults.set(menuBarShowsPrice, forKey: MacDefaults.menuBarShowsPrice)
        }
    }
    
    var showsInspector: Bool {
        didSet {
            defaults.set(showsInspector, forKey: MacDefaults.showsInspector)
        }
    }
    
    private let defaults = UserDefaults.standard
    private var autoRefreshTask: Task<Void, Never>?
    private var searchDrivenCity: String?
    private var lastAutoRefreshAttempt: Date?
    private let pathMonitor = NWPathMonitor()
    
    private init() {
        selectedStationID = defaults.object(forKey: MacDefaults.selectedStation) as? Int
        viewMode = MacViewMode(rawValue: defaults.string(forKey: MacDefaults.viewMode) ?? "") ?? .split
        showsInspector = defaults.object(forKey: MacDefaults.showsInspector) as? Bool ?? true
        menuBarEnabled = defaults.object(forKey: MacDefaults.menuBarEnabled) as? Bool ?? true
        menuBarShowsPrice = defaults.object(forKey: MacDefaults.menuBarShowsPrice) as? Bool ?? true
    }
    
    func start() {
        stations.startOnMac()
        startAutoRefresh()
        startConnectivityMonitor()
    }
}

// MARK: - Derived state

extension MacAppModel {
    
    var displayedStations: [Station] {
        showsFavorites ? stations.favorites : stations.stations
    }
    
    var selectedStation: Station? {
        guard let selectedStationID else {
            return nil
        }
        return station(with: selectedStationID)
    }
    
    func station(with id: Station.ID) -> Station? {
        stations.stations.first { $0.id == id }
            ?? stations.favorites.first { $0.id == id }
            ?? stations.allStations.first { $0.id == id }
    }
    
    /// Nothing is selected while browsing a country other than the detected one, so that
    /// clicking "near me" is a real selection change and brings the user back.
    var sidebarSelection: MacSidebarItem? {
        if showsFavorites {
            return .favorites
        }
        if let city = stations.currentCity {
            return .city(city)
        }
        return stations.isOutsideDetectedCountry ? nil : .nearby
    }
    
    var isShowingNearby: Bool {
        sidebarSelection == .nearby && stations.hasLocation
    }
    
    var sidebarCities: [String] {
        var cities = stations.suggestedCities
        if let current = stations.currentCity, !cities.contains(current) {
            cities.insert(current, at: 0)
        }
        return cities
    }
    
    var windowTitle: String {
        if showsFavorites {
            return "favorites.title".translated
        }
        return stations.navigationTitle ?? stations.currentCity?.capitalized ?? stations.country.name
    }
    
    var windowSubtitle: String {
        var parts: [String] = []
        if !showsFavorites {
            parts.append(stations.selectedFuel.name)
            if case .brand(let key) = stations.currentSortBrand {
                parts.append(stations.brandOptions.first { $0.key == key }?.title ?? key.capitalized)
            }
        }
        if showsFavorites || stations.isLoaded {
            let count = displayedStations.count
            parts.append(count == 1 ? "mac.subtitle.stations.one".translated : "mac.subtitle.stations".translated(count))
        }
        if let updated = stations.lastUpdated {
            parts.append("mac.subtitle.updated".translated(updated.formatted(date: .omitted, time: .shortened)))
        }
        return parts.joined(separator: " · ")
    }
    
    /// Empty when the price is hidden or unknown, which leaves just the icon in the menu bar.
    var menuBarTitle: String {
        guard menuBarShowsPrice,
              let price = stations.cheapestNearby?.rawPrice(for: stations.selectedFuel), !price.isEmpty else {
            return ""
        }
        return price + " €"
    }
    
    /// SwiftUI writes `isInserted` back on every scene update; ignoring the redundant
    /// writes keeps the scene graph from invalidating itself in a loop.
    var menuBarBinding: Binding<Bool> {
        Binding { [self] in
            menuBarEnabled
        } set: { [self] newValue in
            if menuBarEnabled != newValue {
                menuBarEnabled = newValue
            }
        }
    }
    
    /// The brand saved from a previous session may not exist yet (still loading) or any more.
    var brandSelectionKey: String {
        guard case .brand(let key) = stations.currentSortBrand,
              stations.brandOptions.contains(where: { $0.key == key }) else {
            return ""
        }
        return key
    }
    
    var canRefresh: Bool {
        stations.hasChosenCountry && !isRefreshing && !stations.isLoading
    }
}

// MARK: - Actions

extension MacAppModel {
    
    func select(_ item: MacSidebarItem) {
        switch item {
        case .favorites:
            searchDrivenCity = nil
            searchText = ""
            showsFavorites = true
        case .nearby:
            useMyLocation()
        case .city(let city):
            showsFavorites = false
            searchDrivenCity = nil
            searchText = ""
            if stations.currentCity != city {
                stations.showFuelByCity(city)
            }
        }
    }
    
    func useMyLocation() {
        if stations.isLocationDenied {
            showsLocationDeniedAlert = true
            return
        }
        showsFavorites = false
        searchDrivenCity = nil
        searchText = ""
        guard stations.currentCity != nil || !stations.hasLocation || stations.isOutsideDetectedCountry else {
            return
        }
        stations.useCurrentLocation()
    }
    
    func submitSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return
        }
        if stations.isLoaded, stations.loadError == nil, !stations.hasMatches(for: query) {
            showsNoSearchMatches = true
            return
        }
        showsFavorites = false
        let matches = stations.searchResults(text: query.lowercased())
        stations.showFuelByCity(matches.first { $0 == query.lowercased() } ?? matches.first ?? query)
        searchDrivenCity = stations.currentCity
    }
    
    /// Emptying the field undoes a search, but only when the city came from that search
    /// and there is a location to fall back to.
    func searchTextChanged() {
        guard searchText.isEmpty, let city = searchDrivenCity else {
            return
        }
        searchDrivenCity = nil
        if stations.currentCity == city, stations.hasLocation {
            stations.showFuelByCity("")
        }
    }
    
    func focusSearch() {
        searchFocusPending = true
        searchFocusTick += 1
    }
    
    func refresh() {
        guard canRefresh else {
            return
        }
        isRefreshing = true
        Task {
            await stations.reload()
            isRefreshing = false
        }
    }
    
    func retry() {
        stations.retryLoading()
    }
    
    func toggleFavorite(_ station: Station) {
        stations.favoriteStationTapAction(station)
    }
    
    func toggleFavoriteOfSelection() {
        guard let station = selectedStation else {
            return
        }
        toggleFavorite(station)
    }
    
    func isFavorite(_ station: Station) -> Bool {
        stations.favorites.contains { $0.id == station.id }
    }
    
    func copyAddress(of station: Station) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(station.fullAddress, forType: .string)
    }
    
    func openLocationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    private func startAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                self?.refreshIfStale()
            }
        }
    }
    
    /// Retries on its own once the connection is back after a failed first load.
    private func startConnectivityMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else {
                return
            }
            Task { @MainActor in
                guard let self, self.stations.loadError != nil, !self.stations.isLoading else {
                    return
                }
                self.retry()
            }
        }
        pathMonitor.start(queue: .global(qos: .utility))
    }
    
    private func refreshIfStale() {
        let minutes = defaults.object(forKey: MacRefreshInterval.storageKey) as? Int ?? MacRefreshInterval.half.rawValue
        guard minutes > 0, stations.loadError == nil, let updated = stations.lastUpdated,
              Date().timeIntervalSince(updated) >= Double(minutes) * 60 else {
            return
        }
        // After a failed refresh the data stays stale; without this it would retry every minute.
        if let lastAttempt = lastAutoRefreshAttempt, Date().timeIntervalSince(lastAttempt) < 5 * 60 {
            return
        }
        lastAutoRefreshAttempt = Date()
        refresh()
    }
}

// MARK: - Station helpers

extension Station {
    
    var fullAddress: String {
        [direccion.capitalized, [cp, municipio.capitalized].filter { !$0.isEmpty }.joined(separator: " ")]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
    
    var hasValidCoordinates: Bool {
        (latitude != 0 || longitude != 0) && abs(latitude) <= 90 && abs(longitude) <= 180
    }
    
    var mapsURL: URL {
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
                                 URLQueryItem(name: "q", value: displayTitle)]
        return components.url ?? URL(string: "https://maps.apple.com/")!
    }
}

enum MacFormat {
    
    static func distance(_ metres: Double?) -> String {
        guard let metres else {
            return "—"
        }
        if metres < 1000 {
            return "\(metres.round(to: 0).toString()) m"
        }
        return "\((metres / 1000).round(to: 1).toString()) km"
    }
    
    static func price(_ raw: String) -> String {
        raw.isEmpty ? "—" : raw + " €"
    }
    
    static func cost(_ value: Double?) -> String {
        guard let value else {
            return "—"
        }
        return value.formatted(.currency(code: "EUR"))
    }
}

/// Green for the cheapest station on screen, red for the priciest.
struct MacPriceScale {
    
    let low: Double
    let high: Double
    
    /// With enough stations the ends are the 5th and 95th percentiles: one island or
    /// motorway outlier would otherwise paint every other station the same colour.
    init(prices: [Double]) {
        let sorted = prices.sorted()
        guard sorted.count >= 20 else {
            low = sorted.first ?? 0
            high = sorted.last ?? 0
            return
        }
        let cut = sorted.count / 20
        low = sorted[cut]
        high = sorted[sorted.count - 1 - cut]
    }
    
    func color(for price: Double?) -> Color {
        guard let price, high > low else {
            return price == nil ? .gray : .green
        }
        let position = min(max((price - low) / (high - low), 0), 1)
        return Color(hue: 0.33 * (1 - position), saturation: 0.75, brightness: 0.75)
    }
}

struct MacAppearance: ViewModifier {
    
    @AppStorage(ThemePreference.storageKey) private var appearance: ThemePreference = .system
    
    func body(content: Content) -> some View {
        content.onChange(of: appearance, initial: true) { _, preference in
            NSApp.appearance = preference.appKitAppearance
        }
    }
}
