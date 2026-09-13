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
    case eni
    case meroil
    case naturgy
    case tamoil
    case unknown
}

extension CommonStationBrand {
    
    init(rotulo: String) {
        let rawBrand = rotulo
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
            .components(separatedBy: CharacterSet(charactersIn: " -,"))
            .first ?? ""
        self = CommonStationBrand(rawValue: rawBrand) ?? .unknown
    }
    
    @ViewBuilder
    func roundIcon(size: CGFloat) -> some View {
        if self == .unknown {
            Image(systemName: "fuelpump.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(.primary)
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
        case .eni:
            return "logo_eni"
        case .meroil:
            return "logo_meroil"
        case .naturgy:
            return "logo_naturgy"
        case .tamoil:
            return "logo_tamoil"
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
    
    private var locationManager: LocationManager
    private let provider: (Country) -> ServiceStationsAPI
    
    private var kMaxLenght = 200
    private static let selectedFuelKey = "listView.selectedFuel"
    private static let sortOrderKey = "listView.sortOrder"
    private static let brandKey = "listView.brand"
    private static let cityKey = "listView.city"
    private(set) var country: Country = .spain
    private(set) var hasChosenCountry = false
    private var countryPinnedByUser = false
    private(set) var isLocating = false
    private var townSearchKeys: [String] = []
    private var fetchTask: Task<Void, Never>?
    private var locatingTask: Task<Void, Never>?
    private static let locatingTimeout: Duration = .seconds(15)
    
    let defaults: UserDefaults = UserDefaults.standard
    
    var allStations: [Station] = []
    var allMunicipios: [String] = []
    private(set) var provinceByTown: [String: String] = [:]
    var currentCity: String?
    private(set) var currentSortBrand: FuelBrandSortType = .all
    
    private(set) var skippedLocation: Bool = false
    private var hasStarted = false
    private var isFetching = false
    
    var locationAllowed: Bool = false
    var adViewSeen: Bool = true
    var isLoading: Bool = false
    var navigationTitle: String?
    var isLoaded: Bool = false
    private(set) var loadError: String?
    
    var suggestedCities: [String] {
        country.suggestedCities.filter { allMunicipios.contains($0) }
    }
    
    func province(of municipio: String) -> String? {
        provinceByTown[municipio]
    }
    
    private var locationTitle: String? {
        guard locationManager.currentCoordinates != nil else {
            return nil
        }
        if Country(isoCode: locationManager.currentCountryCode) != country {
            return country.name
        }
        return locationManager.currentCity?.capitalized
    }
    
    var needsCountryChoice: Bool {
        !hasChosenCountry && !isLocating
    }
    
    var needsCityChoice: Bool {
        locationManager.currentCoordinates == nil && currentCity == nil
    }
    
    var isPreparing: Bool {
        stations.isEmpty && !isLoaded
    }
    
    var stations: [Station] = []
    private(set) var cheapestNearby: Station?
    var favorites: [Station] = []
    
    var hasLocation: Bool {
        locationManager.currentCoordinates != nil
    }
    
    var effectiveSort: StationSort {
        hasLocation ? sortOrder : .cheapest
    }
    
    var availableSorts: [StationSort] {
        hasLocation ? StationSort.allCases : [.cheapest]
    }
    
    private func preferredFuel(for country: Country) -> FuelType {
        if let vehicleFuel = VehicleFavorite.vehicleData?.fuel, country.fuels.contains(vehicleFuel) {
            return vehicleFuel
        }
        return country.defaultFuel
    }
    private(set) var selectedFuel: FuelType = .gas95
    private(set) var sortOrder: StationSort = .nearest
    private(set) var brandOptions: [StationBrand] = []
    
    struct StationBrand: Identifiable, Hashable {
        let key: String
        let title: String
        let logo: CommonStationBrand?
        let stationCount: Int
        
        var id: String {
            key
        }
    }
    
    private static let genericBrandTokens: Set<String> = [
        "estacion", "estación", "servicio", "gasolinera", "area", "área", "oil", "energy",
        "energia", "energía", "carburantes", "combustibles", "petrol", "gasoleos", "gasóleos",
        "auto", "gas", "unknown", "genérico", "generico"
    ]
    
    private static let minStationsPerBrand = 20
    private static let minBareBrandNames = 5
    
    static func brandTokens(_ rotulo: String) -> [String] {
        rotulo.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }
    
    static func rotulo(_ rotulo: String, matches key: String) -> Bool {
        brandTokens(rotulo).contains(key)
    }
    
    static func brandOptions(from stations: [Station]) -> [StationBrand] {
        var bareBrandNames: [String: Int] = [:]
        for station in stations {
            let tokens = brandTokens(station.rotulo)
            if tokens.count == 1 {
                bareBrandNames[tokens[0], default: 0] += 1
            }
        }
        
        var counts: [String: Int] = [:]
        var logos: [String: CommonStationBrand] = [:]
        for station in stations {
            let tokens = brandTokens(station.rotulo)
            if let known = tokens.lazy
                .compactMap({ CommonStationBrand(rawValue: $0) })
                .first(where: { $0 != .unknown }) {
                counts[known.rawValue, default: 0] += 1
                logos[known.rawValue] = known
                continue
            }
            let discovered = tokens.first {
                !genericBrandTokens.contains($0)
                    && $0.count >= 3
                    && bareBrandNames[$0, default: 0] >= minBareBrandNames
            }
            if let discovered {
                counts[discovered, default: 0] += 1
            }
        }
        
        let branded = counts
            .filter { logos[$0.key] != nil }
            .map { StationBrand(key: $0.key,
                                title: logos[$0.key]?.displayName ?? $0.key.capitalized,
                                logo: logos[$0.key],
                                stationCount: $0.value) }
            .sorted { $0.stationCount > $1.stationCount }
        let discovered = counts
            .filter { logos[$0.key] == nil && $0.value >= minStationsPerBrand }
            .map { StationBrand(key: $0.key,
                                title: $0.key.capitalized,
                                logo: nil,
                                stationCount: $0.value) }
            .sorted { $0.stationCount > $1.stationCount }
        return branded + discovered
    }
    
    init(locationManager: LocationManager = Managers.location,
         provider: @escaping (Country) -> ServiceStationsAPI = Country.provider) {
        self.locationManager = locationManager
        self.provider = provider
        self.locationAllowed = isAuthorized(locationManager.currentAuth)
        _ = FavoriteStations.getAllFavorites()
        restoreFilters()
    }
    
    func start() {
        guard !hasStarted else {
            return
        }
        hasStarted = true
        locationManager.delegate = self
        if locationAllowed {
            locationManager.requestAuth()
            startLocatingTimeout()
            return
        }
#if os(macOS)
        locationManager.requestAuth()
#endif
        let auth = locationManager.currentAuth
        if currentCity != nil || auth == .denied || auth == .restricted {
            continueWithoutLocation()
        }
    }
    
    private func startLocatingTimeout() {
        locatingTask?.cancel()
        isLocating = true
        locatingTask = Task {
            try? await Task.sleep(for: Self.locatingTimeout)
            guard !Task.isCancelled else {
                return
            }
            isLocating = false
            guard allStations.isEmpty, !isFetching, hasChosenCountry else {
                return
            }
            getStations()
        }
    }
    
    func requestLocation() {
        countryPinnedByUser = false
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
    
    func useCurrentLocation() {
        if locationManager.currentAuth == .denied || locationManager.currentAuth == .restricted {
            requestLocation()
            return
        }
        countryPinnedByUser = false
        currentCity = nil
        defaults.removeObject(forKey: Self.cityKey)
        navigationTitle = locationTitle
        refresh()
        locationManager.requestAuth()
        startLocatingTimeout()
    }
    
    func continueWithoutLocation() {
        skippedLocation = true
        if currentCity == nil, allStations.isEmpty {
            hasChosenCountry = false
            return
        }
        if hasChosenCountry, allStations.isEmpty, !isFetching {
            getStations()
        }
    }
    
    func favoriteStationTapAction(_ station: Station) {
        favorites = FavoriteStations.manageFavorite(station)
        let isFav = favorites.contains(where: { $0.id == station.id })
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
            return zip(allMunicipios, townSearchKeys)
                .filter { $0.1.contains(text) }
                .map(\.0)
        }
    }
    
    static func townSearchKey(_ name: String) -> String {
        guard name.hasSuffix(")"), let open = name.lastIndex(of: "(") else {
            return name
        }
        let article = name[name.index(after: open)..<name.index(before: name.endIndex)]
            .trimmingCharacters(in: .whitespaces)
        let base = name[name.startIndex..<open].trimmingCharacters(in: .whitespaces)
        guard !article.isEmpty, !base.isEmpty else {
            return name
        }
        let separator = article.hasSuffix("'") ? "" : " "
        return "\(name) \(article)\(separator)\(base)"
    }
    
    func didTapAdButton() {
        adViewSeen = true
        defaults.set(true, forKey: "stationsView.adSeen")
    }
    
    private func restoreFilters() {
        if let key = defaults.string(forKey: Country.storageKey),
           let saved = Country(rawValue: key) {
            country = saved
            hasChosenCountry = true
        }
        selectedFuel = preferredFuel(for: country)
        if let key = defaults.string(forKey: Self.selectedFuelKey),
           let fuel = FuelType(storageKey: key),
           country.fuels.contains(fuel) {
            selectedFuel = fuel
        }
        if let key = defaults.string(forKey: Self.sortOrderKey),
           let order = StationSort(rawValue: key) {
            sortOrder = order
        }
        if let key = defaults.string(forKey: Self.brandKey), !key.isEmpty {
            currentSortBrand = .brand(key)
        }
        if !locationAllowed, let city = defaults.string(forKey: Self.cityKey), !city.isEmpty {
            currentCity = city.lowercased()
            navigationTitle = city.capitalized
        }
    }
    
    private func dropBrandFilterIfGone() {
        guard case .brand(let key) = currentSortBrand,
              !brandOptions.contains(where: { $0.key == key }) else {
            return
        }
        currentSortBrand = .all
        defaults.removeObject(forKey: Self.brandKey)
    }
    
    private func getStations() {
        locationAllowed = true
        isLoading = true
        allStations = []
        allMunicipios = []
        provinceByTown = [:]
        townSearchKeys = []
        brandOptions = []
        stations = []
        loadError = nil
        isFetching = true
        
        fetchTask?.cancel()
        let api = provider(country)
        fetchTask = Task {
            do throws(G4OError) {
                let stations = try await api.getAllStations()
                guard !Task.isCancelled else {
                    return
                }
                allStations = stations
                allMunicipios = stations.map(\.municipio).unique().sorted()
                provinceByTown = Dictionary(stations.map { ($0.municipio, $0.provincia) },
                                                 uniquingKeysWith: { first, _ in first })
                townSearchKeys = allMunicipios.map(Self.townSearchKey)
                brandOptions = Self.brandOptions(from: stations)
                dropBrandFilterIfGone()
                favorites = refreshedFavorites(with: stations)
                refresh()
                finishLoading()
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                loadError = error.localizedDescription
                finishLoading()
                show(error)
            }
        }
    }
    
    private func finishLoading() {
        isFetching = false
        isLoaded = true
        isLoading = false
        adViewSeen = defaults.bool(forKey: "stationsView.adSeen")
    }
    
    func retryLoading() {
        getStations()
    }
    
    func reload() async {
        if isAuthorized(locationManager.currentAuth), locationManager.currentCoordinates == nil {
            locationManager.requestAuth()
        }
        getStations()
        await fetchTask?.value
    }
    
    private func show(_ error: G4OError) {
#if os(iOS)
        NotificationBanner(
            title: error.localizedDescription,
            subtitle: "",
            leftView: nil,
            rightView: nil,
            style: .warning,
            colors: nil
        ).show()
#else
        print(error.localizedDescription)
#endif
    }
    
}

extension StationsListViewViewModel {
    
    func showByBrand(_ brandSortType: FuelBrandSortType) {
        currentSortBrand = brandSortType
        if case .brand(let key) = brandSortType {
            defaults.set(key, forKey: Self.brandKey)
        } else {
            defaults.removeObject(forKey: Self.brandKey)
        }
        refresh()
    }
    
    func showFuelByCity(_ city: String) {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        currentCity = trimmed.isEmpty ? nil : trimmed
        refresh()
        navigationTitle = currentCity?.capitalized ?? locationTitle
        if locationManager.currentCoordinates == nil {
            if let currentCity {
                defaults.set(currentCity, forKey: Self.cityKey)
            } else {
                defaults.removeObject(forKey: Self.cityKey)
            }
        }
    }
    
    func showCountry(_ newCountry: Country) {
        countryPinnedByUser = true
        applyCountry(newCountry)
    }
    
    private func applyCountry(_ newCountry: Country) {
        defaults.set(newCountry.rawValue, forKey: Country.storageKey)
        let firstChoice = !hasChosenCountry
        hasChosenCountry = true
        if newCountry == country {
            if allStations.isEmpty, !isFetching {
                getStations()
            }
            return
        }
        country = newCountry
        if firstChoice, defaults.string(forKey: Self.selectedFuelKey) == nil {
            selectedFuel = preferredFuel(for: newCountry)
        }
        if !newCountry.fuels.contains(selectedFuel) {
            selectedFuel = preferredFuel(for: newCountry)
            defaults.set(selectedFuel.storageKey, forKey: Self.selectedFuelKey)
        }
        currentSortBrand = .all
        defaults.removeObject(forKey: Self.brandKey)
        currentCity = nil
        defaults.removeObject(forKey: Self.cityKey)
        navigationTitle = locationTitle
        getStations()
    }
    
    func vehicleDidChange() {
        if let fuel = VehicleFavorite.vehicleData?.fuel, country.fuels.contains(fuel), fuel != selectedFuel {
            showFuel(fuel)
        } else {
            refresh()
        }
    }
    
    func nearbyStations() -> [Station] {
        priceScope(allStations.filter { matchesCity($0) })
    }
    
    func showFuel(_ fuel: FuelType) {
        selectedFuel = fuel
        defaults.set(fuel.storageKey, forKey: Self.selectedFuelKey)
        refresh()
    }
    
    func showSorted(_ order: StationSort) {
        sortOrder = order
        defaults.set(order.rawValue, forKey: Self.sortOrderKey)
        refresh()
    }
    
    func refresh() {
        let filtered = allStations.filter { station in
            matchesCity(station) && matchesBrand(station) && hasPriceForCurrentFuel(station)
        }
        let byPrice = priceScope(filtered).sorted {
            (price(for: $0) ?? .greatestFiniteMagnitude) < (price(for: $1) ?? .greatestFiniteMagnitude)
        }
        cheapestNearby = byPrice.first
        switch effectiveSort {
        case .nearest:
            stations = Array(sortedByProximity(filtered).prefix(kMaxLenght))
        case .cheapest:
            stations = Array(byPrice.prefix(kMaxLenght))
        }
    }
    
    private func priceScope(_ stations: [Station]) -> [Station] {
        guard currentCity == nil, let here = locationManager.currentCoordinates else {
            return stations
        }
        let byDistance = stations
            .map { ($0, $0.getCLLocationCoordinates().distance(from: here)) }
            .sorted { $0.1 < $1.1 }
        let near = byDistance.filter { $0.1 <= FillCost.nearbyRadius }
        return (near.isEmpty ? Array(byDistance.prefix(FillCost.minimumCandidates)) : near).map(\.0)
    }
    
    private func matchesCity(_ station: Station) -> Bool {
        guard let currentCity else {
            return true
        }
        return Self.townSearchKey(station.municipio).contains(currentCity)
            || station.provincia.contains(currentCity)
    }
    
    private func matchesBrand(_ station: Station) -> Bool {
        switch currentSortBrand {
        case .all:
            return true
        case .brand(let key):
            return Self.rotulo(station.rotulo, matches: key)
        }
    }
    
    private func hasPriceForCurrentFuel(_ station: Station) -> Bool {
        price(for: station) != nil
    }
    
    private func price(for station: Station) -> Double? {
        station.price(for: selectedFuel)
    }
    
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
            allFavs[index].glp = station.glp
            allFavs[index].gasoleoPremium = station.gasoleoPremium
            allFavs[index].gasolina95E5Premium = station.gasolina95E5Premium
        }
        return allFavs
    }
}

extension StationsListViewViewModel: LocationManagerDelegate {
    
    func isAuthorized(_ auth: CLAuthorizationStatus) -> Bool {
#if os(macOS)
        auth == .authorized || auth == .authorizedAlways
#else
        auth == .authorizedWhenInUse || auth == .authorizedAlways
#endif
    }
    
    func didGet(auth: CLAuthorizationStatus) {
        guard isAuthorized(auth) else {
            if auth == .denied || auth == .restricted {
                locationManager.currentCoordinates = nil
                locationManager.currentCity = nil
                locatingTask?.cancel()
                isLocating = false
                if currentCity == nil {
                    navigationTitle = nil
                }
                continueWithoutLocation()
                refresh()
            }
            return
        }
        if !locationAllowed {
            locationAllowed = true
        }
        startLocatingTimeout()
        if hasChosenCountry, allStations.isEmpty, !isFetching {
            getStations()
        }
    }
    
    func didGet(city: String?) {
        locatingTask?.cancel()
        isLocating = false
        if city != nil, currentCity == nil {
            navigationTitle = locationTitle
        }
        if let detected = Country(isoCode: locationManager.currentCountryCode),
           !countryPinnedByUser,
           detected != country || !hasChosenCountry {
            applyCountry(detected)
            return
        }
        guard hasChosenCountry else {
            return
        }
        if allStations.isEmpty {
            if !isFetching {
                getStations()
            }
        } else {
            refresh()
        }
    }
    
    func didFailGettingLocation(_ error: Error) {
        print(error.localizedDescription)
        locatingTask?.cancel()
        isLocating = false
        if hasChosenCountry, allStations.isEmpty, !isFetching {
            getStations()
        } else if !isFetching {
            isLoading = false
        }
    }
}
