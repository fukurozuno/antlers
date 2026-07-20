import AppKit
import QuickLookUI

protocol PreviewService: AnyObject {
    var previewView: NSView { get }

    func showPreview(of url: URL)
    func endPreview()
}

final class QuickLookPreviewService: PreviewService {
    let previewView: NSView
    private let quickLookPreviewView: QLPreviewView?
    private var displayedURL: URL?

    init() {
        if let quickLookPreviewView = QLPreviewView(frame: .zero, style: .normal) {
            quickLookPreviewView.autostarts = true
            quickLookPreviewView.shouldCloseWithWindow = true
            self.quickLookPreviewView = quickLookPreviewView
            previewView = quickLookPreviewView
        } else {
            quickLookPreviewView = nil
            previewView = NSView(frame: .zero)
        }
    }

    func showPreview(of url: URL) {
        guard displayedURL != url else {
            return
        }

        displayedURL = url
        quickLookPreviewView?.previewItem = QuickLookPreviewItem(url: url)
    }

    func endPreview() {
        displayedURL = nil
        quickLookPreviewView?.previewItem = nil
    }
}

private final class QuickLookPreviewItem: NSObject, QLPreviewItem {
    let previewItemURL: URL!

    init(url: URL) {
        previewItemURL = url
    }
}
