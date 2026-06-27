import XCTest
@testable import Amora

final class LocationLabelServiceTests: XCTestCase {
    func testPrefersNeighborhoodOverCity() {
        XCTAssertEqual(
            LocationLabelFormatter.label(subLocality: "Williamsburg", locality: "Brooklyn", administrativeArea: "NY"),
            "Williamsburg, Brooklyn"
        )
    }

    func testFallsBackToCityAndState() {
        XCTAssertEqual(
            LocationLabelFormatter.label(subLocality: nil, locality: "Austin", administrativeArea: "TX"),
            "Austin, TX"
        )
    }

    func testFallsBackToRegionOnly() {
        XCTAssertEqual(
            LocationLabelFormatter.label(subLocality: nil, locality: nil, administrativeArea: "CA"),
            "CA"
        )
    }

    func testLocationSuggestionLabelCombinesTitleAndSubtitle() {
        XCTAssertEqual(
            LocationSuggestionFormatter.label(title: "Soho", subtitle: "London, UK"),
            "Soho, London, UK"
        )
    }

    func testLocationSuggestionLabelAvoidsDuplicateSubtitle() {
        XCTAssertEqual(
            LocationSuggestionFormatter.label(title: "Soho, London, UK", subtitle: "London, UK"),
            "Soho, London, UK"
        )
    }
}
