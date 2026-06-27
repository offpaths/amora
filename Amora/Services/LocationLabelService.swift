import Combine
import CoreLocation
import Foundation
import MapKit

struct PlanningArea: Equatable {
    var label: String
    var countryCode: String
}

enum LocationLabelFormatter {
    static func label(from placemark: CLPlacemark) -> String {
        label(
            subLocality: placemark.subLocality,
            locality: placemark.locality,
            administrativeArea: placemark.administrativeArea
        )
    }

    static func label(subLocality: String?, locality: String?, administrativeArea: String?) -> String {
        if let subLocality, let locality {
            return "\(subLocality), \(locality)"
        }
        if let locality, let administrativeArea {
            return "\(locality), \(administrativeArea)"
        }
        if let locality {
            return locality
        }
        if let administrativeArea {
            return administrativeArea
        }
        return ""
    }
}

enum LocationSuggestionFormatter {
    static func label(title: String, subtitle: String) -> String {
        guard !subtitle.isEmpty else { return title }
        guard !title.localizedCaseInsensitiveContains(subtitle) else { return title }
        return "\(title), \(subtitle)"
    }
}

@MainActor
final class LocationSuggestionService: NSObject, ObservableObject, @preconcurrency MKLocalSearchCompleterDelegate {
    @Published private(set) var suggestions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest, .query]
    }

    func update(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            clear()
            return
        }
        completer.queryFragment = trimmedQuery
    }

    func clear() {
        completer.queryFragment = ""
        suggestions = []
    }

    func label(for suggestion: MKLocalSearchCompletion) -> String {
        LocationSuggestionFormatter.label(title: suggestion.title, subtitle: suggestion.subtitle)
    }

    func planningArea(for suggestion: MKLocalSearchCompletion) async throws -> PlanningArea? {
        let request = MKLocalSearch.Request(completion: suggestion)
        let response = try await MKLocalSearch(request: request).start()
        guard let placemark = response.mapItems.first?.placemark else {
            return nil
        }
        return PlanningArea.from(placemark: placemark, fallbackLabel: label(for: suggestion))
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = Array(completer.results.prefix(5))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}

@MainActor
final class LocationLabelService: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func currentAreaLabel() async throws -> String {
        try await currentPlanningArea()?.label ?? ""
    }

    func currentPlanningArea() async throws -> PlanningArea? {
        let location: CLLocation?
        if let cachedLocation = manager.location {
            location = cachedLocation
        } else {
            location = await requestCurrentLocation()
        }
        guard let location else {
            return nil
        }
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else {
            return nil
        }
        return PlanningArea.from(placemark: placemark, fallbackLabel: LocationLabelFormatter.label(from: placemark))
    }

    func planningArea(for query: String) async throws -> PlanningArea? {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return nil
        }
        let placemarks = try await geocoder.geocodeAddressString(trimmedQuery)
        guard let placemark = placemarks.first else {
            return nil
        }
        return PlanningArea.from(placemark: placemark, fallbackLabel: trimmedQuery)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard locationContinuation != nil else { return }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            finishLocationRequest(with: nil)
        case .notDetermined:
            break
        @unknown default:
            finishLocationRequest(with: nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finishLocationRequest(with: locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finishLocationRequest(with: nil)
    }

    private func requestCurrentLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            locationContinuation = continuation

            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                finishLocationRequest(with: nil)
            @unknown default:
                finishLocationRequest(with: nil)
            }
        }
    }

    private func finishLocationRequest(with location: CLLocation?) {
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }
}

private extension PlanningArea {
    static func from(placemark: CLPlacemark, fallbackLabel: String) -> PlanningArea? {
        guard let countryCode = placemark.isoCountryCode?.trimmingCharacters(in: .whitespacesAndNewlines), !countryCode.isEmpty else {
            return nil
        }
        let label = LocationLabelFormatter.label(from: placemark)
        return PlanningArea(label: label.isEmpty ? fallbackLabel : label, countryCode: countryCode.uppercased())
    }
}
