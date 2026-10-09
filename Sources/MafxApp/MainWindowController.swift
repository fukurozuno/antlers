import AppKit
import MafxCore

final class MainWindowController: NSWindowController {
    private var paletteAccessory: NSTitlebarAccessoryViewController?

    init(settings: AppSettings = AppSettings(), savedFrame: WindowFrame? = nil, fileSystemScope: FileSystemScope = .unrestricted, initialLeftPath: URL? = nil, initialRightPath: URL? = nil) {
        let contentViewController = DualPaneViewController(settings: settings, fileSystemScope: fileSystemScope, initialLeftPath: initialLeftPath, initialRightPath: initialRightPath)
        let window = NSWindow(contentViewController: contentViewController)

        window.title = fileSystemScope.confinedRootURL == nil
            ? "Antlers"
            : L10n.string("window.title.confined")
        window.setContentSize(NSSize(width: 980, height: 620))
        window.minSize = NSSize(width: 680, height: 420)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        let paletteButton = NSButton(title: "?", target: contentViewController,
                                     action: #selector(DualPaneViewController.showCommandPaletteAction(_:)))
        paletteButton.bezelStyle = .rounded
        paletteButton.controlSize = .small
        paletteButton.font = .systemFont(ofSize: 12, weight: .semibold)
        paletteButton.frame = NSRect(x: 0, y: 3, width: 28, height: 18)
        paletteButton.toolTip = L10n.string("commandPalette.openButtonTooltip")
        paletteButton.setAccessibilityLabel(L10n.string("commandPalette.openButtonTooltip"))
        let accessory = NSTitlebarAccessoryViewController()
        accessory.layoutAttribute = .right
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 38, height: 24))
        accessoryView.addSubview(paletteButton)
        accessory.view = accessoryView
        if settings.showsCommandPaletteButton {
            window.addTitlebarAccessoryViewController(accessory)
        }
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
        paletteAccessory = accessory
    }

    func setCommandPaletteButtonVisible(_ visible: Bool) {
        guard let window, let paletteAccessory else { return }
        if let index = window.titlebarAccessoryViewControllers.firstIndex(of: paletteAccessory) {
            if !visible { window.removeTitlebarAccessoryViewController(at: index) }
        } else if visible {
            window.addTitlebarAccessoryViewController(paletteAccessory)
        }
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
