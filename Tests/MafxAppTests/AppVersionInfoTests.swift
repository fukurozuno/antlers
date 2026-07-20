@testable import MafxApp
import XCTest

final class AppVersionInfoTests: XCTestCase {
    func testAboutPanelVersionUsesShortVersionOnly() {
        let versionInfo = AppVersionInfo.from(infoDictionary: [
            "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": "1"
        ])

        XCTAssertEqual(versionInfo.aboutPanelVersion, "0.1.0")
    }

    func testAboutPanelVersionUsesShortVersionWhenBuildVersionIsMissing() {
        let versionInfo = AppVersionInfo.from(infoDictionary: [
            "CFBundleShortVersionString": "0.1.0"
        ])

        XCTAssertEqual(versionInfo.aboutPanelVersion, "0.1.0")
    }

    func testMissingShortVersionUsesDevelopmentFallback() {
        let versionInfo = AppVersionInfo.from(infoDictionary: nil)

        XCTAssertEqual(versionInfo.aboutPanelVersion, "Development")
    }
}
