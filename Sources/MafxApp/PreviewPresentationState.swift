import Foundation

struct PreviewPresentationState {
    private(set) var generation = 0
    private(set) var presentedURL: URL?

    mutating func beginPresentation(of url: URL) -> Int {
        generation += 1
        presentedURL = url
        return generation
    }

    mutating func endPresentation() {
        generation += 1
        presentedURL = nil
    }

    func shouldRevealPreview(for url: URL, generation: Int) -> Bool {
        presentedURL == url && self.generation == generation
    }
}
