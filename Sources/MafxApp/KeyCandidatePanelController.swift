import AppKit
import MafxCore

/// キー入力の焦点を奪わず、複数ストロークの候補をマウスで選べる補助パネルです。
final class KeyCandidatePanelController: NSWindowController {
    var onSelect: ((KeyBindingCandidate) -> Void)?

    init() {
        let panel = NonActivatingCandidatePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.auxiliary, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        super.init(window: panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(
        candidates: [KeyBindingCandidate],
        theme: DisplayTheme,
        relativeTo mainWindow: NSWindow?
    ) {
        guard let window, !candidates.isEmpty else {
            dismiss()
            return
        }

        let contentViewController = KeyCandidateListViewController(candidates: candidates, theme: theme)
        contentViewController.onSelect = { [weak self] candidate in
            self?.onSelect?(candidate)
        }
        _ = contentViewController.view
        window.contentViewController = contentViewController
        window.setContentSize(contentViewController.preferredContentSize)
        position(window, relativeTo: mainWindow)
        window.orderFront(nil)
    }

    func dismiss() {
        window?.orderOut(nil)
    }

    private func position(_ panel: NSWindow, relativeTo mainWindow: NSWindow?) {
        guard let mainWindow else {
            panel.center()
            return
        }

        let mainFrame = mainWindow.frame
        panel.setFrameOrigin(NSPoint(
            x: mainFrame.midX - panel.frame.width / 2,
            y: mainFrame.midY - panel.frame.height / 2
        ))
    }
}

private final class NonActivatingCandidatePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class KeyCandidateListViewController: NSViewController {
    var onSelect: ((KeyBindingCandidate) -> Void)?

    private let candidates: [KeyBindingCandidate]
    private let theme: DisplayTheme

    init(candidates: [KeyBindingCandidate], theme: DisplayTheme) {
        self.candidates = candidates
        self.theme = theme
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 4
        stackView.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        let colors = theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false)
        let background = colors.background.map {
            NSColor(calibratedRed: CGFloat($0.red), green: CGFloat($0.green), blue: CGFloat($0.blue), alpha: CGFloat($0.paneBackgroundAlpha))
        } ?? .windowBackgroundColor
        let foreground = colors.foreground.map {
            NSColor(calibratedRed: CGFloat($0.red), green: CGFloat($0.green), blue: CGFloat($0.blue), alpha: 1)
        } ?? .labelColor

        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = background.cgColor
        container.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: container.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        for candidate in candidates {
            let title = "\(candidate.remainingDisplayText)  —  \(L10n.string(candidate.commandID.localizationKey))"
            let button = NSButton(title: title, target: self, action: #selector(candidateClicked(_:)))
            button.attributedTitle = NSAttributedString(string: title, attributes: [.foregroundColor: foreground])
            button.tag = stackView.arrangedSubviews.count
            button.bezelStyle = .rounded
            button.alignment = .left
            button.setContentHuggingPriority(.defaultLow, for: .horizontal)
            stackView.addArrangedSubview(button)
        }

        view = container
        preferredContentSize = NSSize(width: 360, height: min(CGFloat(candidates.count) * 32 + 20, 300))
    }

    @objc private func candidateClicked(_ sender: NSButton) {
        guard candidates.indices.contains(sender.tag) else {
            return
        }
        onSelect?(candidates[sender.tag])
    }
}
