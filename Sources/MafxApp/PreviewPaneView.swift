import AppKit
import MafxCore

/// ファイル一覧の選択内容を補助的に表示する、フォーカスを受けないプレビューペインです。
final class PreviewPaneView: NSView {
    private let titleLabel = NSTextField(labelWithString: "Preview")
    private let nameLabel = NSTextField(wrappingLabelWithString: "")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private let previewService: PreviewService = QuickLookPreviewService()
    private let previewContainer = NSView()
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private var pendingPreview: DispatchWorkItem?
    private var displayedURL: URL?

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        buildView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(state: PaneState, theme: DisplayTheme, isInPreviewMode: Bool) {
        let colors = theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false)
        let background = colors.background.map(makeColor) ?? .textBackgroundColor
        let foreground = colors.foreground.map(makeColor) ?? .labelColor
        layer?.backgroundColor = background.cgColor
        layer?.borderWidth = isInPreviewMode ? 2 : 1
        layer?.borderColor = (isInPreviewMode
            ? (theme.resolvedFocusColorPair.background.map(makeColor) ?? .controlAccentColor)
            : .separatorColor).cgColor
        [titleLabel, nameLabel, detailLabel, statusLabel].forEach {
            $0.backgroundColor = background
            $0.textColor = foreground
        }

        titleLabel.stringValue = L10n.string("previewPane.title")
        let item = state.selectedItem
        if let item, !item.isDirectory {
            nameLabel.stringValue = item.name
            detailLabel.stringValue = fileDetail(for: item)
            if displayedURL == item.url, pendingPreview == nil {
                previewContainer.isHidden = false
                statusLabel.stringValue = ""
            } else {
                statusLabel.stringValue = L10n.string("previewPane.loading")
                schedulePreview(of: item.url)
            }
        } else {
            cancelPreview()
            nameLabel.stringValue = state.currentDirectory.lastPathComponent.isEmpty
                ? state.currentDirectory.path
                : state.currentDirectory.lastPathComponent
            detailLabel.stringValue = directoryDetail(for: state)
            statusLabel.stringValue = item == nil
                ? L10n.string("previewPane.noSelection")
                : L10n.string("previewPane.directory")
        }
    }

    /// ペインを一度取り外した後は、同じ選択項目でも Quick Look を再要求する。
    func resetPresentation() {
        pendingPreview?.cancel()
        pendingPreview = nil
        displayedURL = nil
        previewService.endPreview()
        previewContainer.isHidden = true
        statusLabel.stringValue = ""
    }

    private func schedulePreview(of url: URL) {
        guard displayedURL != url else { return }
        pendingPreview?.cancel()
        previewService.endPreview()
        displayedURL = url
        previewContainer.isHidden = true
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.displayedURL == url else { return }
            self.pendingPreview = nil
            self.previewService.showPreview(of: url)
            self.previewContainer.isHidden = false
            self.statusLabel.stringValue = ""
        }
        pendingPreview = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(180), execute: workItem)
    }

    private func cancelPreview() {
        resetPresentation()
    }

    private func fileDetail(for item: FileItem) -> String {
        let type = item.fileExtension.isEmpty ? L10n.string("previewPane.file") : item.fileExtension.uppercased()
        let size = item.byteSize.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
            ?? L10n.string("previewPane.unknown")
        let modified = item.modificationDate.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .short) }
            ?? L10n.string("previewPane.unknown")
        return "\(type) · \(size)\n\(modified)\n\(item.url.path)"
    }

    private func directoryDetail(for state: PaneState) -> String {
        let regularItems = state.items.filter { !$0.isSpecialItem }
        let directories = regularItems.filter(\.isDirectory).count
        let files = regularItems.count - directories
        return L10n.format("previewPane.directoryDetail", directories, files) + "\n" + state.currentDirectory.path
    }

    private func makeColor(_ color: DisplayColor) -> NSColor {
        NSColor(calibratedRed: CGFloat(color.red), green: CGFloat(color.green), blue: CGFloat(color.blue), alpha: 1)
    }

    private func buildView() {
        let header = NSStackView(views: [titleLabel, nameLabel, detailLabel])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 5
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        nameLabel.font = .systemFont(ofSize: 14, weight: .medium)
        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.alignment = .center
        statusLabel.font = .systemFont(ofSize: 12)

        [header, previewContainer, statusLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        previewService.previewView.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(previewService.previewView)

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            header.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            previewContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            previewContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            previewContainer.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            previewContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            previewService.previewView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            previewService.previewView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),
            previewService.previewView.topAnchor.constraint(equalTo: previewContainer.topAnchor),
            previewService.previewView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            statusLabel.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor)
        ])
    }
}
