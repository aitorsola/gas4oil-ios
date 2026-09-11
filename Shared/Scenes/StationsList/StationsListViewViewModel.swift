//
//  ListViewViewModel.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 6/3/22.
//

import CoreLocation
import Observation
import SwiftUI
#if canImport(UIKit)
import NotificationBannerSwift
#endif

enum CommonStationBrand: String {
    case alcampo
    case carrefour
    case bonarea
    case campsa
    case petroprix
    case eroski
    case repsol
    case cepsa
    case ballenoil
    case galp
    case bp
    case shell
    case avia
    case petronor
    case q8
    case moeve
    case plenergy
    case unknown
}

// MARK: - Logos

extension CommonStationBrand {
    
    /// Matches the `Rótulo` the ministry publishes ("REPSOL", "CEPSA ES", "BALLENOIL"...) against
    /// the brands we ship a logo for.
    init(rotulo: String) {
        let rawBrand = rotulo
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
            .components(separatedBy: CharacterSet(charactersIn: " -,"))
            .first ?? ""
        self = CommonStationBrand(rawValue: rawBrand) ?? .unknown
    }
    
    /// Brand logo as a round badge.
    ///
    /// The artwork is square and drawn on white, so it is *fitted* inside the circle over a white
    /// disc rather than clipped to it — clipping would slice the sides off the wordmarks
    /// (Alcampo, Carrefour, bonÀrea…).
    @ViewBuilder
    func roundIcon(size: CGFloat) -> some View {
        if self == .unknown {
            Image(systemName: "fuelpump.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(.orange)
        } else {
            image
                .resizable()
                .scaledToFit()
                .padding(size * 0.14)
                .frame(width: size, height: size)
                .background(Color.white)
                .clipShape(Circle())
        }
    }
    
    /// How the brand writes itself, which `rawValue.capitalized` gets wrong for BP and bonÀrea.
    var displayName: String {
        switch self {
        case .bp:
            return "BP"
        case .bonarea:
            return "bonÀrea"
        case .q8:
            return "Q8"
        case .unknown:
            return "listView.brand.all".translated
        default:
            return rawValue.capitalized
        }
    }
    
    var imageName: String? {
        switch self {
        case .alcampo:
            return "logo_alcampo"
        case .carrefour:
            return "logo_carrefour"
        case .bonarea:
            return "logo_bonarea"
        case .campsa:
            return "logo_campsa"
        case .petroprix:
            return "logo_petroprix"
        case .eroski:
            return "logo_eroski"
        case .repsol:
            return "logo_repsol"
        case .cepsa:
            return "logo_cepsa"
        case .ballenoil:
            return "logo_ballenoil"
        case .galp:
            return "logo_galp"
        case .bp:
            return "logo_bp"
        case .shell:
            return "logo_shell"
        case .avia:
            return "logo_avia"
        case .petronor:
            return "logo_petronor"
        case .q8:
            return "logo_q8"
        case .moeve:
            return "logo_moeve"
        case .plenergy:
            return "logo_plenergy"
        case .unknown:
            return nil
        }
    }
    
    var image: Image {
        guard let imageName else {
            return Image(systemName: "fuelpump.circle.fill")
        }
        return Image(imageName)
    }
    
#if canImport(UIKit)
    /// Round logo for a menu row.
    ///
    /// UIKit rasterises menu icons into a `UIImage` and drops SwiftUI shape modifiers, so
    /// `.clipShape(Circle())` there does nothing — the rounding has to be baked into the bitmap.
    func roundedMenuImage(size: CGFloat = 28) -> Image? {
        guard let imageName, let source = UIImage(named: imageName) else {
            return nil
        }
        let canvas = CGSize(width: size, height: size)
        let rendered = UIGraphicsImageRenderer(size: canvas).image { _ in
            let circle = UIBezierPath(ovalIn: CGRect(origin: .zero, size: canvas))
            UIColor.white.setFill()
            circle.fill()
            circle.addClip()
            let inset = size * 0.14
            let box = CGRect(origin: .zero, size: canvas).insetBy(dx: inset, dy: inset)
            let scale = min(box.width / source.size.width, box.height / source.size.height)
            let drawn = CGSize(width: source.size.width * scale, height: source.size.height * scale)
            source.draw(in: CGRect(x: (canvas.width - drawn.width) / 2,
                                   y: (canvas.height - drawn.height) / 2,
                                   width: drawn.width,
                                   height: drawn.height))
        }
        return Image(uiImage: rendered.withRenderingMode(.alwaysOriginal))
    }
#else
    /// AppKit menus draw the asset at its intrinsic size — Ballenoil is 400px — so macOS needs
    /// the same pre-rendered badge, not just the raw image.
    func roundedMenuImage(size: CGFloat = 20) -> Image? {
        guard let imageName, let source = NSImage(named: imageName) else {
            return nil
        }
        let canvas = NSSize(width: size, height: size)
        let rendered = NSImage(size: canvas)
        rendered.lockFocus()
        let bounds = NSRect(origin: .zero, size: canvas)
        let circle = NSBezierPath(ovalIn: bounds)
        NSColor.white.setFill()
        circle.fill()
        circle.addClip()
        let inset = size * 0.14
        let box = bounds.insetBy(dx: inset, dy: inset)
        let scale = min(box.width / source.size.width, box.height / source.size.height)
        let drawn = NSSize(width: source.size.width * scale, height: source.size.height * scale)
        source.draw(in: NSRect(x: (canvas.width - drawn.width) / 2,
                               y: (canvas.height - drawn.height) / 2,
                               width: drawn.width,
                               height: drawn.height))
        rendered.unlockFocus()
        return Image(nsImage: rendered)
    }
#endif
}

@MainActor
@Observable
final class StationsListViewViewModel {
    
    // MARK: - Properties
    
    private var locationManager: LocationManager
    private var servicesStationsAPI: ServiceStationsAPI
    
    private var kMaxLenght = 200
    private var fetchTask: Task<Void, Never>?
    
    let defaults: UserDefaults = UserDefaults.standard
    
    var allStations: [Station] = []
    var allMunicipios: [String] = []
    var currentCity: String?
    var currentSortBrand: FuelBrandSortType = .all
    
    var locationAllowed: Bool = false {
        didSet {
            isLoading = !locationAllowed
        }
    }
    var adViewSeen: Bool = true
    var isLoading: Bool = false
    var navigationTitle: String?
    var isLoaded: Bool = false
    var stations: [Station] = []
    var favorites: [Station] = []
    /// The fuel every price comparison refers to. There is no "none": one is always selected.
    var selectedFuel: FuelType = .gas95
    var sortOrder: StationSort = .nearest
    let allBrands: [CommonStationBrand] = [
        .alcampo,
        .avia,
        .bp,
        .ballenoil,
        .q8,
        .bonarea,
        .campsa,
        .carrefour,
        .cepsa,
        .eroski,
        .galp,
        .moeve,
        .petronor,
        .plenergy,
        .repsol,
        .petroprix,
        .shell].sorted(by: { $0.rawValue < $1.rawValue })
    
    // MARK: - Lifecycle
    
    init(locationManager: LocationManager = Managers.location, servicesAPI: ServiceStationsAPI = Network()) {
        self.locationManager = locationManager
        self.servicesStationsAPI = servicesAPI
#if os(macOS)
        self.locationAllowed = locationManager.currentAuth == .authorized || locationManager.currentAuth == .authorizedAlways
#else
        self.locationAllowed = locationManager.currentAuth == .authorizedWhenInUse || locationManager.currentAuth == .authorizedAlways
#endif
        _ = FavoriteStations.getAllFavorites()
        setupLocationManager()
    }
    
    // MARK: - Public
    
    func requestLocation() {
#if os(iOS)
        if locationManager.currentAuth == .denied || locationManager.currentAuth == .restricted {
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
            return
        }
#endif
        locationManager.requestAuth()
    }
    
    func favoriteStationTapAction(_ station: Station) {
        favorites = FavoriteStations.manageFavorite(station)
        let isFav = favorites.contains(where: { $0.id == station.id })
        // update both the visible list and the full data set so the flag survives a re-filter
        if let index = stations.firstIndex(where: { $0.id == station.id }) {
            stations[index].isFav = isFav
        }
        if let index = allStations.firstIndex(where: { $0.id == station.id }) {
            allStations[index].isFav = isFav
        }
    }
    
    func searchResults(text: String) -> [String] {
        if text.isEmpty {
            return allMunicipios
        } else {
            return allMunicipios.filter { $0.contains(text) }
        }
    }
    
    func didTapAdButton() {
        adViewSeen = true
        defaults.set(true, forKey: "stationsView.adSeen")
    }
    
    // MARK: - Private
    
    private func getStations() {
        locationAllowed = true
        isLoading = true
        allStations = []
        allMunicipios = []
        stations = []
        // Fuel, order and brand survive: a refresh reloads prices, it is not a "start over".
        currentCity = nil
        
        fetchTask?.cancel()
        fetchTask = Task {
            defer {
                isLoaded = true
                isLoading = false
                adViewSeen = defaults.bool(forKey: "stationsView.adSeen")
            }
            // Typed throws: without the annotation the catch block widens to `any Error`.
            do throws(G4OError) {
                let stations = try await servicesStationsAPI.getAllStations()
                guard !Task.isCancelled else {
                    return
                }
                // The decode already happened off the main actor inside the service; the heavy
                // grouping here is cheap enough not to warrant leaving the actor again.
                allStations = stations
                allMunicipios = stations.map(\.municipio).unique().sorted()
                favorites = refreshedFavorites(with: stations)
                refresh()
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                show(error)
            }
        }
    }
    
    private func show(_ error: G4OError) {
#if os(iOS)
        NotificationBanner(title: error.localizedDescription,
                           subtitle: "",
                           leftView: nil,
                           rightView: nil,
                           style: .warning,
                           colors: nil)
        .show()
#else
        print(error.localizedDescription)
#endif
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
#if os(macOS)
        locationManager.requestAuth()
#endif
    }
}

// MARK: - Filtering & sorting

extension StationsListViewViewModel {
    
    func showByBrand(_ brandSortType: FuelBrandSortType) {
        currentSortBrand = brandSortType
        refresh()
    }
    
    func showFuelByCity(_ city: String) {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        currentCity = trimmed.isEmpty ? nil : trimmed
        refresh()
        navigationTitle = currentCity?.capitalized ?? locationManager.currentCity?.capitalized
    }
    
    func showFuel(_ fuel: FuelType) {
        selectedFuel = fuel
        refresh()
    }
    
    func showSorted(_ order: StationSort) {
        sortOrder = order
        refresh()
    }
    
    func refresh() {
        stations = filteredAndSortedStations()
    }
    
    /// Single pipeline shared by every filter/sort entry point: filter by city, brand and fuel
    /// availability, keep the `kMaxLenght` closest stations and only then apply the requested order.
    private func filteredAndSortedStations() -> [Station] {
        let filtered = allStations.filter { station in
            matchesCity(station) && matchesBrand(station) && hasPriceForCurrentFuel(station)
        }
        let nearest = Array(sortedByProximity(filtered).prefix(kMaxLenght))
        
        switch sortOrder {
        case .nearest:
            return nearest
        case .cheapest:
            return nearest.sorted { (price(for: $0) ?? 0) < (price(for: $1) ?? 0) }
        case .priciest:
            return nearest.sorted { (price(for: $0) ?? 0) > (price(for: $1) ?? 0) }
        }
    }
    
    /// Partial match on purpose: typing "rivas" should find Rivas-Vaciamadrid. Exact equality
    /// only ever worked because the suggestion list completed the name first.
    private func matchesCity(_ station: Station) -> Bool {
        guard let currentCity else {
            return true
        }
        return station.municipio.contains(currentCity) || station.provincia.contains(currentCity)
    }
    
    private func matchesBrand(_ station: Station) -> Bool {
        switch currentSortBrand {
        case .all:
            return true
        case .brand(let brand):
            return station.rotulo.uppercased().contains(brand.uppercased())
        }
    }
    
    private func hasPriceForCurrentFuel(_ station: Station) -> Bool {
        price(for: station) != nil
    }
    
    private func price(for station: Station) -> Double? {
        station.price(for: selectedFuel)
    }
    
    /// Decorate-sort-undecorate: computing the distance once per station instead of on every
    /// comparison keeps this cheap even with the ~11.000 stations the service returns.
    private func sortedByProximity(_ stations: [Station]) -> [Station] {
        guard let currentPoint = locationManager.currentCoordinates else {
            return stations
        }
        return stations
            .map { ($0, $0.getCLLocationCoordinates().distance(from: currentPoint)) }
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }
    }
    
    private func refreshedFavorites(with stations: [Station]) -> [Station] {
        var allFavs = FavoriteStations.getAllFavorites()
        for station in stations {
            guard let index = allFavs.firstIndex(where: { $0.id == station.id }) else {
                continue
            }
            allFavs[index].gasolina95E5 = station.gasolina95E5
            allFavs[index].gasolina98E5 = station.gasolina98E5
            allFavs[index].gasoleoA = station.gasoleoA
        }
        return allFavs
    }
}

// MARK: - LocationManagerDelegate

extension StationsListViewViewModel: LocationManagerDelegate {
    
    func didGet(city: String?) {
        navigationTitle = city?.capitalized
        getStations()
    }
    
    func didFailGettingLocation(_ error: Error) {
        isLoading = false
    }
}
