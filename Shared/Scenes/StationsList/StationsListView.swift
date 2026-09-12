//
//  StationsListView.swift
//  Gas4Oil
//
//  Created by Aitor Sola on 6/3/22.
//

import SwiftUI
import MapKit

/// How the list is ordered. Which fuel it refers to is a separate axis (`FuelType`), because
/// "what does my car take" and "nearest or cheapest" are different questions — folding them into
/// one nine-case enum made the control unable to say which of the two you had changed.
enum StationSort: CaseIterable, Hashable {
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
        case .gas98:
            return "fuel.98".translated
        case .diesel:
            return "fuel.diesel".translated
        }
    }
    
    /// Short form for the toolbar button.
    var tag: String {
        switch self {
        case .gas95:
            return "95"
        case .gas98:
            return "98"
        case .diesel:
            return "fuel.diesel".translated
        }
    }
}

enum FuelBrandSortType: Hashable {
    case all
    case brand(String)
}

struct StationsListView: View {
    
    let viewModel: StationsListViewViewModel
    
    @State private var sortBrand: FuelBrandSortType = .all
    @State private var queryString: String = ""
    /// Drives the search field so it can be collapsed once a town has been chosen.
    @State private var isSearchPresented: Bool = false
#if os(macOS)
    @State private var selectedStationID: Station.ID?
#endif
    @State private var offsetHeight: CGSize = CGSize(width: 0, height: 150)
    @State var kOffsetHeightWhenShow = 150.0
    @State var kOffsetHeightWhenHidden = 2000.0
    @AppStorage(ThemePreference.storageKey) private var appearance: ThemePreference = .system
    
    var body: some View {
        if !viewModel.locationAllowed {
            landing
        } else {
            ZStack {
                if viewModel.isPreparing || viewModel.isLoading {
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
#endif
                    if !viewModel.adViewSeen {
                        draggableView()
                    }
                }
            }
#if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: .updateStations)) { _ in
                viewModel.requestLocation()
            }
#endif
        }
    }
}

// MARK: - Screens

private extension StationsListView {
    
    var landing: some View {
        VStack(spacing: 10) {
            Spacer()
            VStack(spacing: 20) {
                HStack {
                    Image("icn_main_logo", bundle: nil)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40, alignment: .center)
                        .clipped()
                    Text("Gas4Oil").font(.customSize(50))
                }
                Text("landingView.title.discover".translated)
                    .font(.customSize(20)).multilineTextAlignment(.center)
            }
            Spacer()
            Gas4OilButton(title: "landingView.button.requestLocationPermission".translated,
                          image: nil,
                          isDisabled: false) {
                viewModel.requestLocation()
            }
            Spacer()
        }
        .padding()
    }
    
    /// Cells the size of the real ones, enough of them to reach the bottom of the screen.
    ///
    /// In the same `List` the real rows land in, so they inherit its insets and its safe area: a
    /// bare `VStack` here sat under the status bar and behind the tab bar, because the `TabView`
    /// above ignores the safe area. Three stretched cells also read as three oversized rows
    /// rather than as a list about to arrive.
    var loadingPlaceholder: some View {
        skeletonRows
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("common.loading".translated)
    }
    
    private var skeletonRows: some View {
        List(0..<5, id: \.self) { _ in
            FakeView()
                .frame(height: 200)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollDisabled(true)
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: Self.statusBarInset)
        }
    }
    
    /// The `TabView` above ignores the safe area, so nothing here reserves room for the status
    /// bar: the real list only clears it because its navigation bar has a title to lay out. Read
    /// off the window rather than guessed, so a notch and a dynamic island both come out right.
    private static var statusBarInset: CGFloat {
#if os(iOS)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.top ?? 44
#else
        0
#endif
    }
    
    /// Split out of `body`: inline, the whole screen was one expression the type checker gave up on.
    var stationsScreen: some View {
        VStack(spacing: 15) {
#if os(macOS)
            macSearchField
#endif
            if viewModel.isLoaded && viewModel.stations.isEmpty {
                Spacer()
                Text("listView.empty".translated)
                    .font(.customSize(20))
                    .foregroundColor(.secondary)
                Spacer()
            }
            stationList
        }

    }
    
    /// The platform-specific list, wrapped so the shared modifiers below have a receiver:
    /// chaining them straight after an `#endif` leaves them dangling.
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
        List(viewModel.stations) { station in
            ZStack(alignment: .leading) {
                NavigationLink(value: station) { EmptyView() }.opacity(0)
                getStationView(station)
            }
            .hidingOuterSeparators(isFirst: station.id == viewModel.stations.first?.id,
                                   isLast: station.id == viewModel.stations.last?.id)
        }
        .navigationDestination(for: Station.self) { station in
            MapView(station: station)
        }
#endif
    }
    
    var stationList: some View {
        searchableList
            .platformListStyle()
            .refreshable {
                viewModel.requestLocation()
            }
            .navigationTitle(viewModel.navigationTitle ?? "")
            .sidebarSafeToolbar { filterButtons }
    }
    
    /// macOS never rendered `.searchable`, in either the toolbar or `.sidebar` placement, so the
    /// sidebar gets a plain field of its own. iOS keeps the system search, which brings the
    /// suggestions list and the collapse-on-submit behaviour with it.
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
    
    /// Toolbar items attached to a view inside the sidebar column render on the *left* of the
    /// window, crowding the sidebar toggle and pushing the tab picker off centre. On macOS they
    /// are attached to the split view instead; on iOS the list is the right place for them.
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

// MARK: - Search

/// Pulled out of the view body as a modifier: inlined, the list plus its search modifiers formed
/// one expression the type checker refused to finish.
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
    
    /// macOS puts a `.automatic` search field in the window toolbar, where it floats over the
    /// detail pane; a list search belongs in the sidebar. And the `isPresented` binding drives
    /// whether the field is *shown*, so passing it there hid the sidebar field altogether.
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

// MARK: - Search (macOS)

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
    
    /// Stand-in for `.searchSuggestions`, which only exists alongside `.searchable`.
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

// MARK: - Filters

extension StationsListView {
    
    /// Two buttons, each showing the filter it currently applies instead of a generic word.
    /// They used to be bare `Picker`s: no background, no chevron, a tap target the size of the
    /// text, and "Sort" listing nine flat options that mixed fuel with ordering.
    fileprivate var filterButtons: some View {
        HStack(spacing: 2) {
            Menu {
                Button {
                    sortBrand = .all
                    viewModel.showByBrand(.all)
                } label: {
                    Label("listView.brand.all".translated,
                          systemImage: isBrandFiltered ? "fuelpump.fill" : "checkmark")
                }
                Divider()
                ForEach(viewModel.allBrands, id: \.self) { brand in
                    Button {
                        let selection = FuelBrandSortType.brand(brand.rawValue)
                        sortBrand = selection
                        viewModel.showByBrand(selection)
                    } label: {
                        Label {
                            Text(brand.displayName)
                        } icon: {
                            if sortBrand == .brand(brand.rawValue) {
                                Image(systemName: "checkmark")
                            } else {
                                (brand.roundedMenuImage() ?? brand.image).renderingMode(.original)
                            }
                        }
                    }
                }
            } label: {
                filterChip(icon: "fuelpump",
                           title: isBrandFiltered ? brandTitle : nil,
                           isActive: isBrandFiltered)
            }
            
            Menu {
                Section {
                    ForEach(FuelType.allCases, id: \.self) { fuel in
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
    
    /// Icon only, and lit up only while the appearance is being overridden — following the system
    /// is the default, not a filter the user has switched on.
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
    
    /// Icon only while the filter is at its default, icon plus value once it is not: the bar has
    /// little room, and the state only needs spelling out when it is actually filtering.
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
        if case .brand = sortBrand {
            return true
        }
        return false
    }
    
    fileprivate var brandTitle: String {
        if case .brand(let brand) = sortBrand {
            return brand.capitalized
        }
        return "listView.brand.all".translated
    }
    
    fileprivate func draggableView() -> some View {
        AdView(title: "listView.ad.title".translated,
               descr: "listView.ad.description".translated,
               buttonTitle: "OK",
               image: "icn_car") {
            withAnimation(.spring()) {
                offsetHeight.height = kOffsetHeightWhenHidden
                viewModel.didTapAdButton()
            }
        }
               .offset(CGSize(width: 0,
                              height: offsetHeight.height))
               .gesture(
                DragGesture()
                    .onChanged { value in
                        let height = value.translation.height
                        self.offsetHeight.height = height < 0 ? value.translation.height * 0.2 + kOffsetHeightWhenShow : height + kOffsetHeightWhenShow
                    }
                    .onEnded { value in
                        withAnimation(.spring()) {
                            offsetHeight.height = value.translation.height > kOffsetHeightWhenShow ? kOffsetHeightWhenHidden : kOffsetHeightWhenShow
                        }
                    }
               )
    }
    
    private func getStationView(_ station: Station) -> StationView {
        var fillPrice: Double?
        let vehicle = VehicleFavorite.vehicleData
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.decimalSeparator = ","
        formatter.groupingSeparator = ""
        if let vehicle = vehicle {
            switch vehicle.fuel {
            case .gas95:
                let fuelPrice = formatter.number(from: station.gasolina95E5)?.doubleValue ?? 0
                let vehicleCapacity = formatter.number(from: vehicle.capacity)?.doubleValue ?? 0
                fillPrice = (fuelPrice * vehicleCapacity)
            case .gas98:
                let fuelPrice = formatter.number(from: station.gasolina98E5) ?? 0
                let vehicleCapacity = formatter.number(from: vehicle.capacity) ?? 0
                fillPrice = fuelPrice.doubleValue * vehicleCapacity.doubleValue
            case .diesel:
                let fuelPrice = formatter.number(from: station.gasoleoA) ?? 0
                let vehicleCapacity = formatter.number(from: vehicle.capacity) ?? 0
                fillPrice = fuelPrice.doubleValue * vehicleCapacity.doubleValue
            }
        }
        return StationView(price95: station.gasolina95E5,
                           price98: station.gasolina98E5,
                           priceDiesel: station.gasoleoA,
                           brand: station.rotulo,
                           address: station.direccion,
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

// MARK: - Separators

extension View {
    
    /// A plain `List` draws a rule above its first row and below its last one, which reads as a
    /// stray line floating against the background. Separators only belong *between* cells.
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
