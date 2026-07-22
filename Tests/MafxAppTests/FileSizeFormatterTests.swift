@testable import MafxApp
import XCTest

final class FileSizeFormatterTests: XCTestCase {
    func testBytesUsePaddedBUnit() {
        let formatter = FileSizeFormatter()

        XCTAssertEqual(formatter.string(fromByteCount: 0), "0  B")
        XCTAssertEqual(formatter.string(fromByteCount: 1), "1  B")
        XCTAssertEqual(formatter.string(fromByteCount: 999), "999  B")
    }

    func testKilobytesAndMegabytesKeepTwoCharacterUnits() {
        let formatter = FileSizeFormatter()

        XCTAssertEqual(formatter.string(fromByteCount: 1_000), "1 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 1_000_000), "1 MB")
    }
}
