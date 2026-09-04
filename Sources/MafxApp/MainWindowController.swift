import AppKit
import MafxCore

final class MainWindowController: NSWindowController {
    init(settings: AppSettings = AppSettings(), savedFrame: WindowFrame? = nil, fileSystemScope: FileSystemScope = .unrestricted, initialLeftPath: URL? = nil, initialRightPath: URL? = nil) {
        let contentViewController = DualPaneViewController(settings: settings, fileSystemScope: fileSystemScope, initialLeftPath: initialLeftPath, initialRightPath: initialRightPath)
        let window = NSWindow(contentViewController: contentViewController)

        window.title = fileSystemScope.confinedRootURL == nil
            ? "Antlers"
            : L10n.string("window.title.confined")
        window.setContentSize(NSSize(width: 980, height: 620))
        window.minSize = NSSize(width: 680, height: 420)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        let usesContentTransparency = settings.displayThemeSet.selectedTheme.usesContentTransparency
        window.titlebarAppearsTransparent = !usesContentTransparency
        window.titleVisibility = .visible
        window.isOpaque = !usesContentTransparency
        window.backgroundColor = usesContentTransparency ? .clear : .windowBackgroundColor
        if let savedFrame {
            window.setFrame(
                NSRect(
                    x: savedFrame.originX,
                    y: savedFrame.originY,
                    width: savedFrame.width,
                    height: savedFrame.height
                ),
                display: false
            )
        } else {
            window.center()
        }

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension DisplayTheme {
    var usesContentTransparency: Bool {
        base.background?.paneBackgroundAlpha ?? 1.0 < 1.0
            || message.background?.paneBackgroundAlpha ?? 1.0 < 1.0
    }
}
