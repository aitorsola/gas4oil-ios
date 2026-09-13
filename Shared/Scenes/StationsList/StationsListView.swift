//
//  StationsListView.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 6/3/22.
//

import SwiftUI
import MapKit

enum StationSort: String, CaseIterable, Hashable {
    case nearest
    case cheapest
    case priciest
    
    var title: String {
        switch self {
        case .nearest:
            return "listView.sortOrder.near".translated
        case .cheapest:
            return "listView.sortOrder.down".translated
        case .priciest:
            return "listView.sortOrder.up".translated
        }
    }
    
    var icon: String {
        switch self {
        case .nearest:
            return "location.fill"
        case .cheapest:
            return "arrow.down"
        case .priciest:
            return "arrow.up"
        }
    }
}

extension FuelType {
    
    var name: String {
        switch self {
        case .gas95:
            return "fuel.95".translated
        case .gas95Premium:
            return "fuel.gas95Premium".translated
        case .gas98:
            return "fuel.98".translated
        case .diesel:
            return "fuel.diesel".translated
        case .dieselPremium:
            return "fuel.dieselPremium".translated
        case .glp:
            return "fuel.glp".translated
        case .e10:
            return "fuel.e10".translated
        case .e85:
            return "fuel.e85".translated
        }
    }
    
    var tag: String {
        switch self {
        case .gas95:
            return "95"
        case .gas95Premium:
            return "95+"
        case .gas98:
            return "98"
        case .diesel:
            return "fuel.diesel.short".translated
        case .dieselPremium:
            return "fuel.dieselPremium".translated
        case .glp:
            return "GLP"
        case .e10:
            return "E10"
        case .e85:
            return "E85"
        }
    }
}

enum FuelBrandSortType: Hashable {
    case all
    case brand(String)
}

struct StationsListView: View {
    
    let viewModel: StationsListViewViewModel
    
    @State private var queryString: String = ""
    @State private var isSearchPresented: Bool = false
    @State private var selectedStation: Station?
    @State private var showOnboarding: Bool = false
    @State private var cityQuery: String = ""
#if os(macOS)
    @State private var selectedStationID: Station.ID?
#endif
    @State private var offsetHeight: CGSize = CGSize(width: 0, height: 150)
    @State var kOffsetHeightWhenShow = 150.0
    @State var kOffsetHeightWhenHidden = 2000.0
    @AppStorage(ThemePreference.storageKey) private var appearance: ThemePreference = .system
    
    var body: some View {
        if !viewModel.locationAllowed && !viewModel.skippedLocation {
            landing
        } else {
            ZStack {
                if viewModel.needsCountryChoice {
                    countryPrompt
                } else if viewModel.isPreparing || viewModel.isLoading {
                    loadingPlaceholder
                } else {
#if os(macOS)
                    NavigationSplitView {
                        stationsScreen
                            .navigationSplitViewColumnWidth(min: 340, ideal: 380, max: 460)
                    } detail: {
                        if let station = viewModel.stations.first(where: { $0.id == selectedStationID }) {
                            StationDetailView(station: station) {
                                viewModel.favoriteStationTapAction(station)
                            }
                        } else {
                            ContentUnavailableView("listView.detail.empty".translated,
                                                   systemImage: "fuelpump")
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            filterButtons
                        }
                    }
#else
                    NavigationStack {
                        stationsScreen
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if !viewModel.needsCityChoice {
                            locationButton
                        }
                    }
#endif
                }
            }
            .onChange(of: viewModel.isLoaded, initial: true) { _, loaded in
                if loaded && !viewModel.adViewSeen {
                    showOnboarding = true
                }
            }
            .sheet(isPresented: $showOnboarding, onDismiss: { viewModel.didTapAdButton() }) {
                onboarding
            }
#if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: .updateStations)) { _ in
                Task {
                    await viewModel.reload()
                }
            }
#endif
        }
    }
}

private extension StationsListView {
    
    var landing: some View {
        ScrollView {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(colors: [Color.orange.opacity(0.22), .clear],
                                       center: .center, startRadius: 0, endRadius: 105)
                    )
                    .frame(width: 210, height: 210)
                Image("icn_main_logo", bundle: nil)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 96)
            }
            .accessibilityHidden(true)
            Text("Gas4Oil")
                .font(.customSize(34, weight: .bold, design: .rounded))
                .padding(.top, 4)
            Text("landingView.title.discover".translated)
                .font(.customSize(17))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 14) {
                landingBenefit("location.fill", "landingView.benefit.nearby")
                landingBenefit("eurosign.circle.fill", "landingView.benefit.prices")
                landingBenefit("star.fill", "landingView.benefit.favorites")
            }
            .padding(.top, 24)
            .padding(.horizontal, 8)
            Spacer(minLength: 24)
            Button {
                viewModel.requestLocation()
            } label: {
                Text("landingView.button.requestLocationPermission".translated)
                    .font(.customSize(17, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.orange)
            .padding(.horizontal, 24)
            Button("landingView.button.notNow".translated) {
                viewModel.continueWithoutLocation()
            }
            .buttonStyle(.plain)
            .font(.customSize(16, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.top, 16)
            Text("landingView.privacy".translated)
                .font(.customSize(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
                .padding(.top, 14)
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, minHeight: minLandingHeight)
        }
        .scrollBounceBehavior(.basedOnSize)
        .hidingTabBar()
    }
    
    var minLandingHeight: CGFloat {
#if os(iOS)
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.bounds.height ?? 700) - 130
#else
        0
#endif
    }
    
    func landingBenefit(_ symbol: String, _ key: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.customSize(17, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 30)
            Text(key.translated)
                .font(.customSize(16))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }
    
    var loadingPlaceholder: some View {
        skeletonRows
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("common.loading".translated)
    }
    
    private var skeletonRows: some View {
        List(0..<4, id: \.self) { _ in
            FakeView()
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollDisabled(true)
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: Self.statusBarInset)
        }
    }
    
    private static var statusBarInset: CGFloat {
#if os(iOS)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.top ?? 44
#else
        0
#endif
    }
    
    var fillCost: FillCost? {
        guard let vehicle = VehicleFavorite.vehicleData, vehicle.isValid else {
            return nil
        }
        return vehicle.fillCost(using: FillCost.candidates(from: viewModel.stations))
    }
    
    var stationsScreen: some View {
        VStack(spacing: 15) {
#if os(macOS)
            macSearchField
#endif
            if viewModel.isLoaded && viewModel.needsCityChoice {
                cityPrompt
            } else if viewModel.isLoaded && viewModel.stations.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Text(viewModel.loadError ?? "listView.empty".translated)
                        .font(.customSize(20))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    if viewModel.loadError != nil {
                        Gas4OilButton(title: "common.retry".translated,
                                      image: nil,
                                      isDisabled: false) {
                            viewModel.retryLoading()
                        }
                    }
                }
                .padding(.horizontal, 20)
                Spacer()
            }
            if !(viewModel.isLoaded && viewModel.needsCityChoice) {
                stationList
            }
        }
    }
    
    var locationButton: some View {
        Button {
            viewModel.useCurrentLocation()
        } label: {
            Image(systemName: "location.fill")
                .font(.customSize(20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.orange, in: Circle())
                .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 12)
        .accessibilityLabel("listView.city.useLocation".translated)
    }
    
    var countryPrompt: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.14))
                        .frame(width: 84, height: 84)
                    Image(systemName: "globe.europe.africa.fill")
                        .font(.customSize(34, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                .padding(.top, 28)
                Text("listView.country.prompt".translated)
                    .font(.customSize(22, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.top, 18)
                Text("listView.country.hint".translated)
                    .font(.customSize(14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .padding(.horizontal, 8)
                VStack(spacing: 12) {
                    ForEach(Country.allCases) { country in
                        Button {
                            viewModel.showCountry(country)
                        } label: {
                            HStack(spacing: 14) {
                                Text(country.flag)
                                    .font(.customSize(30))
                                Text(country.name)
                                    .font(.customSize(18, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.customSize(14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                            .contentShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 28)
                Spacer(minLength: 20)
                Button {
                    viewModel.requestLocation()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                        Text("listView.city.useLocation".translated)
                    }
                    .font(.customSize(15, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
                .padding(.top, 24)
                .padding(.bottom, 100)
            }
            .padding(.horizontal, 24)
        }
    }
    
    var cityPrompt: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.14))
                        .frame(width: 84, height: 84)
                    Image(systemName: "mappin.and.ellipse")
                        .font(.customSize(34, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                .padding(.top, 28)
                Text("listView.city.prompt".translated)
                    .font(.customSize(22, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.top, 18)
                Text("listView.city.hint".translated)
                    .font(.customSize(14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .padding(.horizontal, 8)
                cityField
                    .padding(.top, 22)
                if cityQuery.isEmpty {
                    suggestedCities
                } else {
                    cityMatches
                }
                Spacer(minLength: 20)
                Button {
                    viewModel.requestLocation()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                        Text("listView.city.useLocation".translated)
                    }
                    .font(.customSize(15, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
                .padding(.top, 24)
                .padding(.bottom, 100)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    var cityField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("listView.search.placeholder".translated, text: $cityQuery)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { viewModel.showFuelByCity(cityQuery) }
            if !cityQuery.isEmpty {
                Button {
                    cityQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.15), in: Capsule())
    }
    
    var suggestedCities: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("listView.city.suggested".translated)
                .font(.customSize(13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                ForEach(viewModel.suggestedCities, id: \.self) { town in
                    Button {
                        choose(town)
                    } label: {
                        Text(town.capitalized)
                            .font(.customSize(15, weight: .medium))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.orange.opacity(0.12), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 26)
    }
    
    var cityMatches: some View {
        let matches = viewModel.searchResults(text: cityQuery.lowercased()).prefix(8)
        return VStack(spacing: 0) {
            if matches.isEmpty {
                Text("listView.city.noMatches".translated)
                    .font(.customSize(14))
                    .foregroundStyle(.secondary)
                    .padding(.top, 28)
            }
            ForEach(Array(matches), id: \.self) { town in
                Button {
                    choose(town)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.customSize(20))
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(town.capitalized)
                                .font(.customSize(16))
                            if let province = viewModel.province(of: town) {
                                Text(province.capitalized)
                                    .font(.customSize(12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.customSize(12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
        .padding(.top, 12)
    }
    
    func choose(_ town: String) {
        cityQuery = ""
#if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
#endif
        viewModel.showFuelByCity(town)
    }
    
    @ViewBuilder
    var platformList: some View {
#if os(macOS)
        List(viewModel.stations, selection: $selectedStationID) { station in
            StationSidebarRow(station: station, fuel: viewModel.selectedFuel)
                .contextMenu {
                    Button {
                        viewModel.favoriteStationTapAction(station)
                    } label: {
                        Label(station.isFav
                              ? "listView.station.removeFavorite".translated
                              : "listView.station.addFavorite".translated,
                              systemImage: station.isFav ? "star.slash" : "star")
                    }
                    Button {
                        station.openInMaps()
                    } label: {
                        Label("listView.station.directions".translated,
                              systemImage: "arrow.triangle.turn.up.right.circle")
                    }
                }
        }
#else
        List {
            if let cost = fillCost {
                FillCostCard(cost: cost)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }
            ForEach(viewModel.stations) { station in
                getStationView(station)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedStation = station }
                    .hidingOuterSeparators(isFirst: station.id == viewModel.stations.first?.id,
                                           isLast: station.id == viewModel.stations.last?.id)
            }
        }
        .navigationDestination(item: $selectedStation) { station in
            MapView(station: station)
        }
#endif
    }
    
    var stationList: some View {
        searchableList
            .platformListStyle()
            .refreshable {
                await viewModel.reload()
            }
            .navigationTitle(viewModel.navigationTitle ?? "")
            .sidebarSafeToolbar { filterButtons }
    }
    
    @ViewBuilder
    var searchableList: some View {
#if os(macOS)
        platformList
#else
        platformList
            .modifier(TownSearch(query: $queryString,
                                 isPresented: $isSearchPresented,
                                 viewModel: viewModel))
#endif
    }
}

private extension View {
    
    @ViewBuilder
    func hidingTabBar() -> some View {
#if os(iOS)
        toolbar(.hidden, for: .tabBar)
#else
        self
#endif
    }
}

private extension View {
    
    @ViewBuilder
    func sidebarSafeToolbar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
#if os(macOS)
        self
#else
        toolbar {
            ToolbarItem(placement: .primaryAction) {
                content()
            }
        }
#endif
    }
}

private struct TownSearch: ViewModifier {
    
    @Binding var query: String
    @Binding var isPresented: Bool
    let viewModel: StationsListViewViewModel
    
    func body(content: Content) -> some View {
        searchField(content)
            .searchSuggestions {
                ForEach(viewModel.searchResults(text: query.lowercased()), id: \.self) { town in
                    Text(town.capitalized).searchCompletion(town.capitalized)
                }
            }
            .onSubmit(of: .search) {
                viewModel.showFuelByCity(query)
                isPresented = false
            }
            .onChange(of: query) { _, newValue in
                if newValue.isEmpty {
                    viewModel.showFuelByCity("")
                }
            }
    }
    
    @ViewBuilder
    private func searchField(_ content: Content) -> some View {
#if os(macOS)
        content.searchable(text: $query,
                           placement: .sidebar,
                           prompt: Text("listView.search.placeholder".translated))
#else
        content.searchable(text: $query,
                           isPresented: $isPresented,
                           placement: .automatic,
                           prompt: Text("listView.search.placeholder".translated))
#endif
    }
}

private extension View {
    
    @ViewBuilder
    func platformListStyle() -> some View {
#if os(macOS)
        listStyle(.sidebar)
#else
        listStyle(.plain)
#endif
    }
}

#if os(macOS)

private extension StationsListView {
    
    var macSearchField: some View {
        VStack(spacing: 0) {
            TextField("listView.search.placeholder".translated, text: $queryString)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.showFuelByCity(queryString)
                }
                .onChange(of: queryString) { _, newValue in
                    if newValue.isEmpty {
                        viewModel.showFuelByCity("")
                    }
                }
            suggestions
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }
    
    @ViewBuilder
    var suggestions: some View {
        let matches = viewModel.searchResults(text: queryString.lowercased())
        if !queryString.isEmpty, !matches.contains(queryString.lowercased()), !matches.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(matches.prefix(6), id: \.self) { town in
                    Button {
                        queryString = town.capitalized
                        viewModel.showFuelByCity(town)
                    } label: {
                        Text(town.capitalized)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            .padding(.top, 4)
        }
    }
}

#endif

extension StationsListView {
    
    fileprivate var filterButtons: some View {
        HStack(spacing: 2) {
            countryMenu
            
            if !viewModel.brandOptions.isEmpty {
                brandMenu
            }
            
            Menu {
                Section {
                    ForEach(viewModel.country.fuels, id: \.self) { fuel in
                        Button {
                            viewModel.showFuel(fuel)
                        } label: {
                            Label(fuel.name,
                                  systemImage: viewModel.selectedFuel == fuel ? "checkmark" : "drop")
                        }
                    }
                } header: {
                    Text("common.fuelType".translated)
                }
                Section {
                    ForEach(StationSort.allCases, id: \.self) { order in
                        Button {
                            viewModel.showSorted(order)
                        } label: {
                            Label(order.title,
                                  systemImage: viewModel.sortOrder == order ? "checkmark" : order.icon)
                        }
                    }
                } header: {
                    Text("listView.sort.title".translated)
                }
            } label: {
                filterChip(icon: viewModel.sortOrder.icon,
                           title: viewModel.selectedFuel.tag,
                           isActive: viewModel.sortOrder != .nearest)
            }
            
            appearanceMenu
        }
    }
    
    fileprivate var countryMenu: some View {
        Menu {
            ForEach(Country.allCases) { country in
                Button {
                    viewModel.showCountry(country)
                } label: {
                    Label {
                        Text(country.flag + " " + country.name)
                    } icon: {
                        if viewModel.country == country {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            filterChip(emoji: viewModel.country.flag, title: viewModel.country.code, isActive: false)
        }
        .accessibilityLabel("country.title".translated)
    }
    
    fileprivate var brandMenu: some View {
        Group {
            Menu {
                Button {
                    viewModel.showByBrand(.all)
                } label: {
                    Label("listView.brand.all".translated,
                          systemImage: isBrandFiltered ? "fuelpump.fill" : "checkmark")
                }
                Divider()
                ForEach(viewModel.brandOptions) { option in
                    Button {
                        viewModel.showByBrand(.brand(option.key))
                    } label: {
                        Label {
                            Text(option.title)
                        } icon: {
                            if viewModel.currentSortBrand == .brand(option.key) {
                                Image(systemName: "checkmark")
                            } else if let logo = option.logo {
                                (logo.roundedMenuImage() ?? logo.image).renderingMode(.original)
                            } else {
                                Image(systemName: "fuelpump")
                            }
                        }
                    }
                }
            } label: {
                filterChip(icon: "fuelpump",
                           title: isBrandFiltered ? brandTitle : nil,
                           isActive: isBrandFiltered)
            }
        }
    }
    
    fileprivate var appearanceMenu: some View {
        Menu {
            ForEach(ThemePreference.allCases) { option in
                Button {
                    appearance = option
                } label: {
                    Label(option.title,
                          systemImage: appearance == option ? "checkmark" : option.icon)
                }
            }
        } label: {
            filterChip(icon: appearance.icon, title: nil, isActive: appearance != .system)
        }
        .accessibilityLabel("appearance.title".translated)
    }
    
    fileprivate func filterChip(emoji: String, title: String?, isActive: Bool) -> some View {
        HStack(spacing: 5) {
            Text(emoji)
                .font(.customSize(14))
            if let title {
                Text(title)
                    .font(.customSize(14, weight: .semibold))
                    .lineLimit(1)
            }
        }
        .foregroundColor(isActive ? .white : .orange)
        .padding(.horizontal, isActive ? 10 : 8)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(isActive ? Color.orange : Color.orange.opacity(0.15))
        )
    }
    
    fileprivate func filterChip(icon: String, title: String?, isActive: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.customSize(13, weight: .semibold))
            if let title {
                Text(title)
                    .font(.customSize(14, weight: .semibold))
                    .lineLimit(1)
            }
        }
        .foregroundColor(isActive ? .white : .orange)
        .padding(.horizontal, isActive ? 10 : 8)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(isActive ? Color.orange : Color.orange.opacity(0.15))
        )
    }
    
    fileprivate var isBrandFiltered: Bool {
        if case .brand = viewModel.currentSortBrand {
            return true
        }
        return false
    }
    
    fileprivate var brandTitle: String {
        guard case .brand(let key) = viewModel.currentSortBrand else {
            return "listView.brand.all".translated
        }
        return viewModel.brandOptions.first { $0.key == key }?.title ?? key.capitalized
    }
    
    fileprivate var onboarding: some View {
        AdView(title: "listView.ad.title".translated,
               tips: [OnboardingTip(symbol: "arrow.up.arrow.down",
                                    title: "listView.ad.sort.title".translated,
                                    detail: "listView.ad.sort.detail".translated),
                      OnboardingTip(symbol: "fuelpump",
                                    title: "listView.ad.filter.title".translated,
                                    detail: "listView.ad.filter.detail".translated),
                      OnboardingTip(symbol: "magnifyingglass",
                                    title: "listView.ad.search.title".translated,
                                    detail: "listView.ad.search.detail".translated),
                      OnboardingTip(symbol: "star",
                                    title: "listView.ad.favorites.title".translated,
                                    detail: "listView.ad.favorites.detail".translated)],
               buttonTitle: "listView.ad.button".translated) {
            showOnboarding = false
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func getStationView(_ station: Station) -> StationView {
        var fillPrice: Double?
        let vehicle = VehicleFavorite.vehicleData
        if let vehicle,
           let unitPrice = station.price(for: vehicle.fuel),
           let litres = vehicle.capacityLitres {
            fillPrice = unitPrice * litres
        }
        return StationView(prices: PriceColumn.columns(for: station),
                           brand: station.displayTitle,
                           address: station.displayAddress,
                           schedule: station.horario,
                           coordinates: station.getCLLocationCoordinates(),
                           showFavButton: true,
                           directionsAction: { station.openInMaps() },
                           fillPrice: fillPrice,
                           isFav: station.isFav) {
            viewModel.favoriteStationTapAction(station)
        }
    }
}

extension View {
    
    func hidingOuterSeparators(isFirst: Bool, isLast: Bool) -> some View {
        self
            .listRowSeparator(isFirst ? .hidden : .visible, edges: .top)
            .listRowSeparator(isLast ? .hidden : .visible, edges: .bottom)
    }
}

struct StationsListView_Previews: PreviewProvider {
    static var previews: some View {
        StationsListView(viewModel: StationsListViewViewModel())
            .preferredColorScheme(.dark)
    }
}
