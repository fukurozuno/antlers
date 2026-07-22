import Foundation

public enum FileOperationError: Error, Equatable {
    case emptyName
    case invalidName(String)
    case sourceDoesNotExist(URL)
    case destinationNotDirectory(URL)
    case destinationAlreadyExists(URL)
    case destinationInsideSource(source: URL, destination: URL)
    case failed(String)
}

extension FileOperationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "名前が空です。"
        case .invalidName(let name):
            return "名前として使用できません: \(name)"
        case .sourceDoesNotExist(let url):
            return "操作元が存在しません: \(url.lastPathComponent)"
        case .destinationNotDirectory(let url):
            return "操作先がフォルダではありません: \(url.lastPathComponent)"
        case .destinationAlreadyExists(let url):
            return "同名の項目が既に存在します: \(url.lastPathComponent)"
        case .destinationInsideSource(let source, let destination):
            return "操作先が操作元の配下です: \(source.lastPathComponent) -> \(destination.lastPathComponent)"
        case .failed(let message):
            return message
        }
    }
}

public enum FileCopyConflictResolution: Equatable {
    case copy
    case skip
    case copyIfSourceIsNewer
    case cancel
}

public struct FileCopyConflict: Equatable {
    public let sourceURL: URL
    public let destinationURL: URL
    public let sourceModificationDate: Date?
    public let destinationModificationDate: Date?
}

public struct FileCopyResult: Equatable {
    public let copiedCount: Int
    public let skippedCount: Int
    public let unprocessedCount: Int
    public let wasCancelled: Bool
    public let itemResults: [FileOperationItemResult]

    public init(
        copiedCount: Int = 0,
        skippedCount: Int = 0,
        unprocessedCount: Int = 0,
        wasCancelled: Bool = false,
        itemResults: [FileOperationItemResult] = []
    ) {
        self.copiedCount = copiedCount
        self.skippedCount = skippedCount
        self.unprocessedCount = unprocessedCount
        self.wasCancelled = wasCancelled
        self.itemResults = itemResults
    }
}

public enum FileMoveConflictResolution: Equatable {
    case move
    case skip
    case moveIfSourceIsNewer
    case cancel
}

public struct FileMoveConflict: Equatable {
    public let sourceURL: URL
    public let destinationURL: URL
    public let sourceModificationDate: Date?
    public let destinationModificationDate: Date?
}

public struct FileMoveResult: Equatable {
    public let movedCount: Int
    public let skippedCount: Int
    public let unprocessedCount: Int
    public let wasCancelled: Bool
    public let itemResults: [FileOperationItemResult]

    public init(
        movedCount: Int = 0,
        skippedCount: Int = 0,
        unprocessedCount: Int = 0,
        wasCancelled: Bool = false,
        itemResults: [FileOperationItemResult] = []
    ) {
        self.movedCount = movedCount
        self.skippedCount = skippedCount
        self.unprocessedCount = unprocessedCount
        self.wasCancelled = wasCancelled
        self.itemResults = itemResults
    }
}

public struct FileTrashResult: Equatable {
    public let trashedCount: Int
    public let itemResults: [FileOperationItemResult]

    public init(trashedCount: Int = 0, itemResults: [FileOperationItemResult] = []) {
        self.trashedCount = trashedCount
        self.itemResults = itemResults
    }
}

public struct FileOperationItemResult: Equatable {
    public let sourceURL: URL
    public let destinationURL: URL?
    public let outcome: FileOperationItemOutcome

    public init(sourceURL: URL, destinationURL: URL? = nil, outcome: FileOperationItemOutcome) {
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.outcome = outcome
    }
}

public enum FileOperationItemOutcome: Equatable {
    case copied
    case moved
    case trashed
    case skipped(reason: FileOperationSkipReason)
    case unprocessed
}

public enum FileOperationSkipReason: Equatable {
    case conflict
    case sourceIsNotNewer
}

public protocol FileOperationProviding {
    func createDirectory(named name: String, in parentDirectory: URL) throws -> URL
    func renameItem(at sourceURL: URL, to newName: String, replacingExisting: Bool) throws -> URL
    func copyItem(at sourceURL: URL, to newName: String, replacingExisting: Bool) throws -> URL
    func copyItems(
        at sourceURLs: [URL],
        to destinationDirectory: URL,
        resolvingConflictWith conflictResolver: (FileCopyConflict) -> FileCopyConflictResolution
    ) throws -> FileCopyResult
    func moveItems(
        at sourceURLs: [URL],
        to destinationDirectory: URL,
        resolvingConflictWith conflictResolver: (FileMoveConflict) -> FileMoveConflictResolution
    ) throws -> FileMoveResult
    func trashItems(at sourceURLs: [URL]) throws -> FileTrashResult
}

public final class FileOperationService: FileOperationProviding {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func createDirectory(named name: String, in parentDirectory: URL) throws -> URL {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try validateSingleItemName(trimmedName)

        let directoryURL = parentDirectory.appendingPathComponent(trimmedName, isDirectory: true)
        guard !fileManager.fileExists(atPath: directoryURL.path) else {
            throw FileOperationError.destinationAlreadyExists(directoryURL)
        }

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: false)
            return directoryURL
        } catch let error as FileOperationError {
            throw error
        } catch {
            throw FileOperationError.failed(error.localizedDescription)
        }
    }

    public func renameItem(at sourceURL: URL, to newName: String, replacingExisting: Bool = false) throws -> URL {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        try validateSingleItemName(trimmedName)

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw FileOperationError.sourceDoesNotExist(sourceURL)
        }

        let destinationURL = sourceURL.deletingLastPathComponent().appendingPathComponent(trimmedName)
        if destinationURL.standardizedFileURL == sourceURL.standardizedFileURL {
            return sourceURL
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            guard replacingExisting else {
                throw FileOperationError.destinationAlreadyExists(destinationURL)
            }

            try replaceItem(at: destinationURL, withMovingItemAt: sourceURL)
            return destinationURL
        }

        try moveItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    public func copyItem(at sourceURL: URL, to newName: String, replacingExisting: Bool = false) throws -> URL {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        try validateSingleItemName(trimmedName)

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw FileOperationError.sourceDoesNotExist(sourceURL)
        }

        let destinationDirectory = sourceURL.deletingLastPathComponent()
        let destinationURL = destinationDirectory.appendingPathComponent(trimmedName)
        try validateCopyDestination(destinationURL, isNotInside: sourceURL)

        if fileManager.fileExists(atPath: destinationURL.path) {
            guard replacingExisting else {
                throw FileOperationError.destinationAlreadyExists(destinationURL)
            }

            try replaceItem(at: destinationURL, withCopyOf: sourceURL, in: destinationDirectory)
            return destinationURL
        }

        try copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    public func copyItems(
        at sourceURLs: [URL],
        to destinationDirectory: URL,
        resolvingConflictWith conflictResolver: (FileCopyConflict) -> FileCopyConflictResolution
    ) throws -> FileCopyResult {
        try validateDestinationDirectory(destinationDirectory)

        var copiedCount = 0
        var skippedCount = 0
        var itemResults: [FileOperationItemResult] = []

        let uniqueSourceURLs = uniqueURLsPreservingOrder(sourceURLs)
        for (index, sourceURL) in uniqueSourceURLs.enumerated() {
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                throw FileOperationError.sourceDoesNotExist(sourceURL)
            }

            let destinationURL = destinationDirectory.appendingPathComponent(sourceURL.lastPathComponent)
            try validateCopyDestination(destinationURL, isNotInside: sourceURL)

            if fileManager.fileExists(atPath: destinationURL.path) {
                let conflict = FileCopyConflict(
                    sourceURL: sourceURL,
                    destinationURL: destinationURL,
                    sourceModificationDate: modificationDate(of: sourceURL),
                    destinationModificationDate: modificationDate(of: destinationURL)
                )

                switch conflictResolver(conflict) {
                case .copy:
                    try replaceItem(at: destinationURL, withCopyOf: sourceURL, in: destinationDirectory)
                    copiedCount += 1
                    itemResults.append(FileOperationItemResult(
                        sourceURL: sourceURL,
                        destinationURL: destinationURL,
                        outcome: .copied
                    ))
                case .skip:
                    skippedCount += 1
                    itemResults.append(FileOperationItemResult(
                        sourceURL: sourceURL,
                        destinationURL: destinationURL,
                        outcome: .skipped(reason: .conflict)
                    ))
                case .copyIfSourceIsNewer:
                    if isSourceNewer(thanDestinationIn: conflict) {
                        try replaceItem(at: destinationURL, withCopyOf: sourceURL, in: destinationDirectory)
                        copiedCount += 1
                        itemResults.append(FileOperationItemResult(
                            sourceURL: sourceURL,
                            destinationURL: destinationURL,
                            outcome: .copied
                        ))
                    } else {
                        skippedCount += 1
                        itemResults.append(FileOperationItemResult(
                            sourceURL: sourceURL,
                            destinationURL: destinationURL,
                            outcome: .skipped(reason: .sourceIsNotNewer)
                        ))
                    }
                case .cancel:
                    itemResults += uniqueSourceURLs[index...].map {
                        FileOperationItemResult(sourceURL: $0, outcome: .unprocessed)
                    }
                    return FileCopyResult(
                        copiedCount: copiedCount,
                        skippedCount: skippedCount,
                        unprocessedCount: uniqueSourceURLs.count - index,
                        wasCancelled: true,
                        itemResults: itemResults
                    )
                }
            } else {
                try copyItem(at: sourceURL, to: destinationURL)
                copiedCount += 1
                itemResults.append(FileOperationItemResult(
                    sourceURL: sourceURL,
                    destinationURL: destinationURL,
                    outcome: .copied
                ))
            }
        }

        return FileCopyResult(copiedCount: copiedCount, skippedCount: skippedCount, itemResults: itemResults)
    }

    public func moveItems(
        at sourceURLs: [URL],
        to destinationDirectory: URL,
        resolvingConflictWith conflictResolver: (FileMoveConflict) -> FileMoveConflictResolution
    ) throws -> FileMoveResult {
        try validateDestinationDirectory(destinationDirectory)

        var movedCount = 0
        var skippedCount = 0
        var itemResults: [FileOperationItemResult] = []

        let uniqueSourceURLs = uniqueURLsPreservingOrder(sourceURLs)
        for (index, sourceURL) in uniqueSourceURLs.enumerated() {
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                throw FileOperationError.sourceDoesNotExist(sourceURL)
            }

            let destinationURL = destinationDirectory.appendingPathComponent(sourceURL.lastPathComponent)
            try validateCopyDestination(destinationURL, isNotInside: sourceURL)

            if fileManager.fileExists(atPath: destinationURL.path) {
                let conflict = FileMoveConflict(
                    sourceURL: sourceURL,
                    destinationURL: destinationURL,
                    sourceModificationDate: modificationDate(of: sourceURL),
                    destinationModificationDate: modificationDate(of: destinationURL)
                )

                switch conflictResolver(conflict) {
                case .move:
                    try replaceItem(at: destinationURL, withMovingItemAt: sourceURL)
                    movedCount += 1
                    itemResults.append(FileOperationItemResult(
                        sourceURL: sourceURL,
                        destinationURL: destinationURL,
                        outcome: .moved
                    ))
                case .skip:
                    skippedCount += 1
                    itemResults.append(FileOperationItemResult(
                        sourceURL: sourceURL,
                        destinationURL: destinationURL,
                        outcome: .skipped(reason: .conflict)
                    ))
                case .moveIfSourceIsNewer:
                    if isSourceNewer(sourceDate: conflict.sourceModificationDate, destinationDate: conflict.destinationModificationDate) {
                        try replaceItem(at: destinationURL, withMovingItemAt: sourceURL)
                        movedCount += 1
                        itemResults.append(FileOperationItemResult(
                            sourceURL: sourceURL,
                            destinationURL: destinationURL,
                            outcome: .moved
                        ))
                    } else {
                        skippedCount += 1
                        itemResults.append(FileOperationItemResult(
                            sourceURL: sourceURL,
                            destinationURL: destinationURL,
                            outcome: .skipped(reason: .sourceIsNotNewer)
                        ))
                    }
                case .cancel:
                    itemResults += uniqueSourceURLs[index...].map {
                        FileOperationItemResult(sourceURL: $0, outcome: .unprocessed)
                    }
                    return FileMoveResult(
                        movedCount: movedCount,
                        skippedCount: skippedCount,
                        unprocessedCount: uniqueSourceURLs.count - index,
                        wasCancelled: true,
                        itemResults: itemResults
                    )
                }
            } else {
                try moveItem(at: sourceURL, to: destinationURL)
                movedCount += 1
                itemResults.append(FileOperationItemResult(
                    sourceURL: sourceURL,
                    destinationURL: destinationURL,
                    outcome: .moved
                ))
            }
        }

        return FileMoveResult(movedCount: movedCount, skippedCount: skippedCount, itemResults: itemResults)
    }

    public func trashItems(at sourceURLs: [URL]) throws -> FileTrashResult {
        var trashedCount = 0
        var itemResults: [FileOperationItemResult] = []

        for sourceURL in uniqueURLsPreservingOrder(sourceURLs) {
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                throw FileOperationError.sourceDoesNotExist(sourceURL)
            }

            do {
                var resultingURL: NSURL?
                try fileManager.trashItem(at: sourceURL, resultingItemURL: &resultingURL)
                trashedCount += 1
                itemResults.append(FileOperationItemResult(
                    sourceURL: sourceURL,
                    destinationURL: resultingURL as URL?,
                    outcome: .trashed
                ))
            } catch {
                throw FileOperationError.failed(error.localizedDescription)
            }
        }

        return FileTrashResult(trashedCount: trashedCount, itemResults: itemResults)
    }

    private func validateSingleItemName(_ name: String) throws {
        guard !name.isEmpty else {
            throw FileOperationError.emptyName
        }

        guard name != ".", name != "..", !name.contains("/"), !name.contains("\0") else {
            throw FileOperationError.invalidName(name)
        }
    }

    private func validateDestinationDirectory(_ destinationDirectory: URL) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destinationDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw FileOperationError.destinationNotDirectory(destinationDirectory)
        }
    }

    private func validateCopyDestination(_ destinationURL: URL, isNotInside sourceURL: URL) throws {
        let sourcePath = sourceURL.standardizedFileURL.path
        let destinationPath = destinationURL.standardizedFileURL.path

        guard destinationPath != sourcePath else {
            throw FileOperationError.destinationAlreadyExists(destinationURL)
        }

        let sourcePrefix = sourcePath.hasSuffix("/") ? sourcePath : sourcePath + "/"
        guard !destinationPath.hasPrefix(sourcePrefix) else {
            throw FileOperationError.destinationInsideSource(source: sourceURL, destination: destinationURL)
        }
    }

    private func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func isSourceNewer(thanDestinationIn conflict: FileCopyConflict) -> Bool {
        isSourceNewer(
            sourceDate: conflict.sourceModificationDate,
            destinationDate: conflict.destinationModificationDate
        )
    }

    private func isSourceNewer(sourceDate: Date?, destinationDate: Date?) -> Bool {
        guard let sourceDate,
              let destinationDate else {
            return false
        }

        return sourceDate > destinationDate
    }

    private func replaceItem(at destinationURL: URL, withCopyOf sourceURL: URL, in destinationDirectory: URL) throws {
        let temporaryURL = destinationDirectory.appendingPathComponent(
            ".mafx-copy-\(UUID().uuidString)-\(sourceURL.lastPathComponent)"
        )

        do {
            try fileManager.copyItem(at: sourceURL, to: temporaryURL)
            _ = try fileManager.replaceItemAt(destinationURL, withItemAt: temporaryURL)
        } catch {
            if fileManager.fileExists(atPath: temporaryURL.path) {
                try? fileManager.removeItem(at: temporaryURL)
            }
            throw FileOperationError.failed(error.localizedDescription)
        }
    }

    private func copyItem(at sourceURL: URL, to destinationURL: URL) throws {
        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw FileOperationError.failed(error.localizedDescription)
        }
    }

    private func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        } catch {
            throw FileOperationError.failed(error.localizedDescription)
        }
    }

    private func replaceItem(at destinationURL: URL, withMovingItemAt sourceURL: URL) throws {
        do {
            _ = try fileManager.replaceItemAt(destinationURL, withItemAt: sourceURL)
        } catch {
            throw FileOperationError.failed(error.localizedDescription)
        }
    }

    private func uniqueURLsPreservingOrder(_ urls: [URL]) -> [URL] {
        var seenURLs: Set<URL> = []
        var uniqueURLs: [URL] = []

        for url in urls where !seenURLs.contains(url) {
            seenURLs.insert(url)
            uniqueURLs.append(url)
        }

        return uniqueURLs
    }
}
