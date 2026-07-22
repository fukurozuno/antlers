import AppKit
import MafxCore

/// メインウィンドウの前面に表示する、移動可能な一覧用補助パネルを管理する。
final class FloatingListPanelController: NSWindowController, NSWindowDelegate {
    private var onDismiss: (() -> Void)?

    init() {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.auxiliary, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false

        super.init(window: panel)
        panel.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(
        contentViewController: NSViewController,
        title: String,
        theme: DisplayTheme,
        relativeTo mainWindow: NSWindow?,
        onDismiss: @escaping () -> Void
    ) {
        guard let window else {
            return
        }

        self.onDismiss = onDismiss
        window.title = title
        window.contentViewController = contentViewController
        window.setContentSize(contentViewController.preferredContentSize)
        let colors = theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false)
        window.backgroundColor = colors.background.map { Self.nsColor(from: $0) } ?? .windowBackgroundColor

        position(window, centeredIn: mainWindow)

        window.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        guard let window, window.isVisible else {
            return
        }

        window.orderOut(nil)
        notifyDismissed()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        dismiss()
        return false
    }

    private func notifyDismissed() {
        let handler = onDismiss
        onDismiss = nil
        handler?()
    }

    private func position(_ panel: NSWindow, centeredIn mainWindow: NSWindow?) {
        guard let mainWindow else {
            panel.center()
            return
        }

        let mainFrame = mainWindow.frame
        panel.setFrameOrigin(
            NSPoint(
                x: mainFrame.midX - panel.frame.width / 2,
                y: mainFrame.midY - panel.frame.height / 2
            )
        )
    }

    private static func nsColor(from color: DisplayColor) -> NSColor {
        NSColor(
            calibratedRed: CGFloat(color.red),
            green: CGFloat(color.green),
            blue: CGFloat(color.blue),
            alpha: CGFloat(color.paneBackgroundAlpha)
        )
    }
}
