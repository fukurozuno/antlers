import Foundation

public protocol DirectoryListingProviding {
    func contents(of directory: URL, includingHiddenFiles: Bool) throws -> [FileItem]
}

public extension DirectoryListingProviding {
    func contents(of directory: URL) throws -> [FileItem] {
        try contents(of: directory, includingHiddenFiles: false)
    }
}

public final class DirectoryListingService: DirectoryListingProviding {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func contents(of directory: URL, includingHiddenFiles: Bool = false) throws -> [FileItem] {
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .tagNamesKey
            ],
            options: includingHiddenFiles ? [] : [.skipsHiddenFiles]
        )

        return try urls
            .map { url in
                let values = try url.resourceValues(
                    forKeys: [
                        .isDirectoryKey,
                        .isSymbolicLinkKey,
                        .fileSizeKey,
                        .contentModificationDateKey,
                        .tagNamesKey
                    ]
                )
                let isDirectory = values.isDirectory == true && values.isSymbolicLink != true
                let byteSize = isDirectory ? nil : values.fileSize.map(Int64.init)
                return FileItem(
                    url: url,
                    isDirectory: isDirectory,
                    byteSize: byteSize,
                    modificationDate: values.contentModificationDate,
                    tagNames: values.tagNames ?? []
                )
            }
            .sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory && !rhs.isDirectory
                }

                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }
}
