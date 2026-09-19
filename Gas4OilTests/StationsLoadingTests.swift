//
//  StationsLoadingTests.swift
//  Gas4OilTests
//

import CoreLocation
import XCTest
@testable import Gas4Oil

private final class MockLocation: LocationManager {
    var currentAuth: CLAuthorizationStatus = .denied
    weak var delegate: LocationManagerDelegate?
    var currentCoordinates: CLLocation?
    var currentCity: String?
    var currentCountryCode: String?
    func requestAuth() {}
}

private final class MockAPI: ServiceStationsAPI, @unchecked Sendable {
    var result: Result<[Station], G4OError> = .success([])
    
    func getAllStations() async throws(G4OError) -> [Station] {
        try result.get()
    }
}

@MainActor
final class StationsLoadingTests: XCTestCase {
    
    private let api = MockAPI()
    
    private func station(_ id: Int, price: String = "1,500") -> Station {
        Station(id: id, cp: "28001", provincia: "madrid", municipio: "madrid", direccion: "Calle \(id)",
                horario: "L-D: 24H", longitude: -3.7, latitude: 40.4, gasNaturalComprimido: "",
                gasNaturalLicuado: "", gasoleoA: price, gasoleoB: "", gasoleoPremium: "", gasolina95E10: "",
                gasolina95E5: price, gasolina95E5Premium: "", gasolina98E10: "", gasolina98E5: price,
                hidrogeno: "", rotulo: "Repsol", isFav: false)
    }
    
    private func makeViewModel() -> StationsListViewViewModel {
        StationsListViewViewModel(locationManager: MockLocation(), provider: { [api] _ in api })
    }
    
    func testFirstLoadFailureShowsErrorWithoutData() async {
        api.result = .failure(.networkProblem(URLError(.notConnectedToInternet)))
        let viewModel = makeViewModel()
        await viewModel.reload()
        XCTAssertNotNil(viewModel.loadError)
        XCTAssertEqual(viewModel.loadError?.isOffline, true)
        XCTAssertTrue(viewModel.allStations.isEmpty)
        XCTAssertTrue(viewModel.isLoaded)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.refreshFailed)
    }
    
    func testFailedRefreshKeepsPreviousData() async {
        api.result = .success([station(1), station(2)])
        let viewModel = makeViewModel()
        await viewModel.reload()
        XCTAssertEqual(viewModel.allStations.count, 2)
        XCTAssertNotNil(viewModel.lastUpdated)
        
        api.result = .failure(.badStatusCode(503))
        await viewModel.reload()
        XCTAssertEqual(viewModel.allStations.count, 2)
        XCTAssertNil(viewModel.loadError)
        XCTAssertTrue(viewModel.refreshFailed)
        XCTAssertFalse(viewModel.isLoading)
        
        api.result = .success([station(1), station(2), station(3)])
        await viewModel.reload()
        XCTAssertEqual(viewModel.allStations.count, 3)
        XCTAssertFalse(viewModel.refreshFailed)
    }
    
    func testRetryAfterFailureRecovers() async {
        api.result = .failure(.emptyResponse)
        let viewModel = makeViewModel()
        await viewModel.reload()
        XCTAssertNotNil(viewModel.loadError)
        
        api.result = .success([station(1)])
        await viewModel.reload()
        XCTAssertNil(viewModel.loadError)
        XCTAssertEqual(viewModel.allStations.count, 1)
    }
    
    func testUsingMyLocationReturnsToDetectedCountry() async {
        api.result = .success([station(1)])
        let location = MockLocation()
        location.currentAuth = .authorizedWhenInUse
        location.currentCoordinates = CLLocation(latitude: 40.4, longitude: -3.7)
        location.currentCountryCode = "ES"
        let viewModel = StationsListViewViewModel(locationManager: location, provider: { [api] _ in api })
        
        viewModel.showCountry(.france)
        XCTAssertEqual(viewModel.country, .france)
        XCTAssertTrue(viewModel.isOutsideDetectedCountry)
        
        viewModel.useCurrentLocation()
        XCTAssertEqual(viewModel.country, .spain)
        XCTAssertFalse(viewModel.isOutsideDetectedCountry)
        XCTAssertNil(viewModel.currentCity)
    }
    
    func testSavedCityComesBackWhenLocationFails() async {
        let defaults = UserDefaults.standard
        defaults.set("madrid", forKey: "listView.city")
        defer { defaults.removeObject(forKey: "listView.city") }
        api.result = .success([station(1)])
        let location = MockLocation()
        location.currentAuth = .authorizedWhenInUse
        let viewModel = StationsListViewViewModel(locationManager: location, provider: { [api] _ in api })
        XCTAssertNil(viewModel.currentCity, "with the permission granted the town is not restored at launch")
        
        viewModel.didFailGettingLocation(URLError(.unknown))
        XCTAssertEqual(viewModel.currentCity, "madrid")
        XCTAssertTrue(viewModel.locationFailed)
        XCTAssertFalse(viewModel.needsCityChoice)
    }
    
    func testResetFiltersAlwaysLeavesAnEmptySearch() async {
        api.result = .success([station(1)])
        let viewModel = makeViewModel()
        await viewModel.reload()
        viewModel.showFuelByCity("no existe")
        XCTAssertTrue(viewModel.stations.isEmpty)
        XCTAssertTrue(viewModel.hasActiveFilters)
        
        viewModel.resetFilters()
        XCTAssertNil(viewModel.currentCity)
        XCTAssertFalse(viewModel.hasActiveFilters)
        XCTAssertEqual(viewModel.stations.count, 1)
        UserDefaults.standard.removeObject(forKey: "listView.city")
    }
    
    func testSearchMatchesTownsAndProvinces() async {
        api.result = .success([station(1)])
        let viewModel = makeViewModel()
        await viewModel.reload()
        XCTAssertTrue(viewModel.hasMatches(for: "Madr"))
        XCTAssertFalse(viewModel.hasMatches(for: "zzz"))
        XCTAssertFalse(viewModel.hasMatches(for: "  "))
    }
    
    func testErrorPresentation() {
        XCTAssertTrue(G4OError.networkProblem(URLError(.notConnectedToInternet)).isOffline)
        XCTAssertFalse(G4OError.networkProblem(URLError(.timedOut)).isOffline)
        XCTAssertFalse(G4OError.badStatusCode(500).isOffline)
        for error in [G4OError.invalidURL, .networkProblem(nil), .badStatusCode(500), .emptyResponse, .parseProblems] {
            XCTAssertFalse(error.title.isEmpty)
            XCTAssertFalse(error.icon.isEmpty)
            XCTAssertFalse((error.errorDescription ?? "").isEmpty)
        }
    }
}
