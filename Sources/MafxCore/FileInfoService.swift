import Foundation

public struct FileInfo: Equatable {
    public let name: String
    public let url: URL
    public let isDirectory: Bool
    public let byteSize: Int64?
    public let modificationDate: Date?
    public let directorySize: DirectorySize?

    public init(
        name: String,
        url: URL,
        isDirectory: Bool,
        byteSize: Int64?,
        modificationDate: Date?,
        directorySize: DirectorySize?
    ) {
        self.name = name
        self.url = url
        self.isDirectory = isDirectory
        self.byteSize = byteSize
        self.modificationDate = modificationDate
        self.directorySize = directorySize
    }
}

public struct DirectorySize: Equatable {
    public let byteSize: Int64
    public let skippedItemCount: Int

    public init(byteSize: Int64, skippedItemCount: Int = 0) {
        self.byteSize = byteSize
        self.skippedItemCount = skippedItemCount
    }
}

public protocol FileInfoProviding {
    func info(for item: FileItem) throws -> FileInfo
}

public final class FileInfoService: FileInfoProviding {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func info(for item: FileItem) throws -> FileInfo {
        FileInfo(
            name: item.name,
            url: item.url,
            isDirectory: item.isDirectory,
            byteSize: item.byteSize,
            modificationDate: item.modificationDate,
            directorySize: item.isDirectory ? try directorySize(of: item.url) : nil
        )
    }

    private func directorySize(of directory: URL) throws -> DirectorySize {
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileSizeKey
        ]
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: nil
        ) else {
            throw CocoaError(.fileReadUnknown)
        }

        var byteSize: Int64 = 0
        var skippedItemCount = 0

        for case let url as URL in enumerator {
            do {
                let values = try url.resourceValues(forKeys: keys)
                if values.isSymbolicLink == true {
                    if values.isDirectory == true {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                if values.isDirectory == true {
                    continue
                }

                if let fileSize = values.fileSize {
                    byteSize += Int64(fileSize)
                }
            } catch {
                skippedItemCount += 1
                enumerator.skipDescendants()
            }
        }

        return DirectorySize(byteSize: byteSize, skippedItemCount: skippedItemCount)
    }
}
