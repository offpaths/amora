import CoreLocation
import Foundation

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

@MainActor
final class LocationLabelService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func currentAreaLabel() async throws -> String {
        guard let location = manager.location else {
            return ""
        }
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        return placemarks.first.map(LocationLabelFormatter.label(from:)) ?? ""
    }
}
