import Foundation

public enum FileItemKind: Equatable {
    case regular
    case parentDirectory
}

public struct FileItem: Equatable, Identifiable {
    public let id: URL
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let byteSize: Int64?
    public let modificationDate: Date?
    public let tagNames: [String]
    public let kind: FileItemKind

    public var isSpecialItem: Bool {
        kind != .regular
    }

    public var isParentDirectoryItem: Bool {
        kind == .parentDirectory
    }

    public var fileExtension: String {
        guard !isDirectory, !isSpecialItem else {
            return ""
        }

        return (name as NSString).pathExtension
    }

    public var displayBaseName: String {
        guard !fileExtension.isEmpty else {
            return name
        }

        return (name as NSString).deletingPathExtension
    }

    public var displayFileExtension: String {
        guard !fileExtension.isEmpty else {
            return ""
        }

        return ".\(fileExtension)"
    }

    public init(
        url: URL,
        isDirectory: Bool,
        name: String? = nil,
        byteSize: Int64? = nil,
        modificationDate: Date? = nil,
        tagNames: [String] = [],
        kind: FileItemKind = .regular
    ) {
        self.id = url
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.isDirectory = isDirectory
        self.byteSize = byteSize
        self.modificationDate = modificationDate
        self.tagNames = tagNames
        self.kind = kind
    }

    public static func parentDirectoryItem(for directory: URL) -> FileItem? {
        let parentDirectory = directory.deletingLastPathComponent()
        guard parentDirectory != directory else {
            return nil
        }

        return FileItem(
            url: parentDirectory,
            isDirectory: true,
            name: "..",
            kind: .parentDirectory
        )
    }
}
