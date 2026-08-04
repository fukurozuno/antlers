import AppKit
@testable import MafxApp
import XCTest

final class FileListColumnMetricsTests: XCTestCase {
    func testModificationDateWidthUsesLargestTextMeasurementAndCellInsetsOnly() {
        let font = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        let text = "0000/00/00 00:00:00"
        let textField = NSTextField(labelWithString: text)
        textField.font = font
        let stringWidth = (text as NSString).size(withAttributes: [.font: font]).width
        let fittingWidth = textField.fittingSize.width

        XCTAssertEqual(
            FileListColumnMetrics.modificationDateWidth(font: font),
            ceil(max(stringWidth, fittingWidth)) + 16
        )
    }

    func testModificationDateWidthGrowsWithFontSize() {
        let small = FileListColumnMetrics.modificationDateWidth(
            font: .monospacedSystemFont(ofSize: 13, weight: .regular)
        )
        let large = FileListColumnMetrics.modificationDateWidth(
            font: .monospacedSystemFont(ofSize: 15, weight: .regular)
        )

        XCTAssertGreaterThan(large, small)
    }

    func testNameColumnWidthUsesAvailableColumnSpaceRemainingAfterFixedColumns() {
        XCTAssertEqual(
            FileListColumnMetrics.nameColumnWidth(
                availableColumnWidth: 674.5,
                nonNameColumnWidth: 558,
                minimumNameColumnWidth: 40
            ),
            116.5
        )
    }

    func testNameColumnWidthDoesNotDropBelowMinimum() {
        XCTAssertEqual(
            FileListColumnMetrics.nameColumnWidth(
                availableColumnWidth: 500,
                nonNameColumnWidth: 558,
                minimumNameColumnWidth: 40
            ),
            40
        )
    }
}
