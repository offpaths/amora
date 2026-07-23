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
            "The app should not expose an analytics toggle because privacy-limited analytics are enabled by default."
        )
    }

    func testPostHogDoesNotAutocaptureErrorsOrIdentifyPurchasers() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = try String(
            contentsOf: projectRoot.appendingPathComponent("Amora/AmoraApp.swift"),
            encoding: .utf8
        )
        let purchaseSource = try String(
            contentsOf: projectRoot.appendingPathComponent("Amora/Services/PurchaseService.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(appSource.contains("errorTrackingConfig.autoCapture = true"))
        XCTAssertTrue(appSource.contains("config.captureApplicationLifecycleEvents = false"))
        XCTAssertTrue(appSource.contains("config.captureScreenViews = false"))
        XCTAssertTrue(appSource.contains("config.sessionReplay = false"))
        XCTAssertTrue(appSource.contains("config.personProfiles = .never"))
        XCTAssertFalse(purchaseSource.contains("PostHogSDK.shared.identify"))
        XCTAssertFalse(purchaseSource.contains("transaction.originalID"))
    }

    func testPlanningInputsExposeVoiceOverLabelsAndBudgetValue() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Amora/Views/InputView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("accessibilityLabel(\"Personal anchor\")"))
        XCTAssertTrue(source.contains("accessibilityLabel(\"Plan near\")"))
        XCTAssertTrue(source.contains("accessibilityLabel(\"Budget for two\")"))
        XCTAssertTrue(source.contains("accessibilityValue(selectedBudgetLabel)"))
    }
}
