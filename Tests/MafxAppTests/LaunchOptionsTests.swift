@testable import MafxApp
import MafxCore
import XCTest

final class LaunchOptionsTests: XCTestCase {
    func testParsesEnglishAndSolarizedDarkOptions() {
        let options = LaunchOptions.parse(arguments: [
            "--confined-root", "/tmp/manual",
            "--language", "en",
            "--theme", "solarized-dark"
        ])

        XCTAssertEqual(options.appLanguage, .english)
        XCTAssertEqual(options.themeID, "solarized-dark")
    }

    func testParsesJapaneseOption() {
        let options = LaunchOptions.parse(arguments: ["--language", "ja"])

        XCTAssertEqual(options.appLanguage, .japanese)
    }

    func testIgnoresUnknownAndInvalidLanguageOptions() {
        let options = LaunchOptions.parse(arguments: [
            "--unknown", "value",
            "--language", "fr"
        ])

        XCTAssertNil(options.appLanguage)
        XCTAssertNil(options.themeID)
    }
}
