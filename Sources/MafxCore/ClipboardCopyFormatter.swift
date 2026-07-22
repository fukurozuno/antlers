import Foundation

public enum ClipboardCopyFormat: CaseIterable {
    case fileName
    case directoryPath
    case fullPath

    public func text(for items: [FileItem], in currentDirectory: URL) -> String {
        items.map { item in
            switch self {
            case .fileName:
                return item.isParentDirectoryItem ? "" : item.name
            case .directoryPath:
                if item.isParentDirectoryItem {
                    return currentDirectory.path
                }
                return item.url.deletingLastPathComponent().path
            case .fullPath:
                if item.isParentDirectoryItem {
                    return currentDirectory.path
                }
                return item.url.path
            }
        }.joined(separator: "\n")
    }
}
