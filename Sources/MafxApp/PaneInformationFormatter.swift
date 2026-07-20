import MafxCore

enum PaneInformationField: Hashable {
    case markedItems
}

struct PaneInformationDisplayConfiguration: Equatable {
    let fields: [PaneInformationField]

    static let standard = PaneInformationDisplayConfiguration(fields: [.markedItems])
}

struct PaneInformationFormatter {
    let configuration: PaneInformationDisplayConfiguration
    private let fileSizeFormatter: FileSizeFormatter

    init(
        configuration: PaneInformationDisplayConfiguration = .standard,
        fileSizeFormatter: FileSizeFormatter = FileSizeFormatter()
    ) {
        self.configuration = configuration
        self.fileSizeFormatter = fileSizeFormatter
    }

    func string(for state: PaneState) -> String {
        configuration.fields.compactMap { text(for: $0, state: state) }.joined(separator: "  ")
    }

    private func text(for field: PaneInformationField, state: PaneState) -> String? {
        switch field {
        case .markedItems:
            let markedItems = state.markedItems
            let markedFiles = markedItems.filter { !$0.isDirectory }
            let filesWithKnownSize = markedFiles.compactMap(\.byteSize)
            let totalByteSize = filesWithKnownSize
                .lazy
                .reduce(0, +)
            let unknownFileCount = markedFiles.count - filesWithKnownSize.count
            let directoryCount = markedItems.count - markedFiles.count
            var details: [String] = []

            if !filesWithKnownSize.isEmpty || markedItems.isEmpty {
                details.append(
                    L10n.format(
                        "pane.information.fileTotalSize",
                        fileSizeFormatter.string(fromByteCount: totalByteSize)
                    )
                )
            }
            if unknownFileCount > 0 {
                details.append(L10n.format("pane.information.unknownFileCount", Int64(unknownFileCount)))
            }
            if directoryCount > 0 {
                details.append(L10n.format("pane.information.directoryCount", Int64(directoryCount)))
            }

            return L10n.format(
                "pane.information.markedItems",
                Int64(markedItems.count),
                details.joined(separator: L10n.string("pane.information.separator"))
            )
        }
    }
}
