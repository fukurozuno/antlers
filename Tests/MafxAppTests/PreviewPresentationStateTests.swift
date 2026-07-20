@testable import MafxApp
import XCTest

final class PreviewPresentationStateTests: XCTestCase {
    func testEndingPresentationInvalidatesPendingReveal() {
        var state = PreviewPresentationState()
        let url = temporaryURL(named: "first-preview.txt")
        let generation = state.beginPresentation(of: url)

        state.endPresentation()

        XCTAssertFalse(state.shouldRevealPreview(for: url, generation: generation))
    }

    func testBeginningAnotherPresentationInvalidatesPreviousReveal() {
        var state = PreviewPresentationState()
        let firstURL = temporaryURL(named: "first-preview.txt")
        let secondURL = temporaryURL(named: "second-preview.txt")
        let firstGeneration = state.beginPresentation(of: firstURL)
        let secondGeneration = state.beginPresentation(of: secondURL)

        XCTAssertFalse(state.shouldRevealPreview(for: firstURL, generation: firstGeneration))
        XCTAssertTrue(state.shouldRevealPreview(for: secondURL, generation: secondGeneration))
    }

    private func temporaryURL(named name: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(name)
    }
}
