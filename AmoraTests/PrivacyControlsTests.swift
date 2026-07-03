import XCTest

final class PrivacyControlsTests: XCTestCase {
    func testAIConsentViewUsesLightweightContextDisclosureCopy() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Amora/ContentView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("A quick note before we plan"))
        XCTAssertTrue(source.contains("Used only to shape this date plan"))
        XCTAssertTrue(source.contains("Continue"))
        XCTAssertFalse(source.contains("Agree and Continue"))
    }

    func testAppDoesNotExposeAnalyticsControls() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURLs = [
            projectRoot.appendingPathComponent("Amora/ContentView.swift"),
            projectRoot.appendingPathComponent("Amora/Views/InputView.swift"),
            projectRoot.appendingPathComponent("Amora/Views/Components.swift")
        ]
        let source = try sourceURLs
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")

        XCTAssertFalse(
            source.contains("AnalyticsPrivacyToggle") || source.contains("Share app analytics"),
            "The app should not expose in-app analytics controls because analytics collection is removed."
        )
    }
}
