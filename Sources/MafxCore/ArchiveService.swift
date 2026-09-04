import Foundation
import ZIPFoundation

public enum ArchiveServiceError: Error, Equatable {
    case sourceDoesNotExist(URL)
    case sourceIsNotZIP(URL)
    case destinationAlreadyExists(URL)
    case destinationNotDirectory(URL)
    case invalidEntryPath(String)
    case symbolicLinkNotSupported(String)
    case archiveTooLarge
    case emptySources
    case destinationInsideSource
    case readFailed
    case failed(String)
}

extension ArchiveServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .sourceDoesNotExist(let url): return "操作元が存在しません: \(url.lastPathComponent)"
        case .sourceIsNotZIP(let url): return "ZIP ファイルではありません: \(url.lastPathComponent)"
        case .destinationAlreadyExists(let url): return "出力先は既に存在します: \(url.lastPathComponent)"
        case .destinationNotDirectory(let url): return "展開先がフォルダではありません: \(url.lastPathComponent)"
        case .invalidEntryPath(let path): return "危険なアーカイブ内パスです: \(path)"
        case .symbolicLinkNotSupported(let path): return "symlink は初期対応では扱えません: \(path)"
        case .archiveTooLarge: return "アーカイブの展開サイズまたは項目数が上限を超えています。"
        case .emptySources: return "圧縮する項目がありません。"
        case .destinationInsideSource: return "出力 ZIP を圧縮元の配下には作成できません。"
        case .readFailed: return "ZIP を読み取れません。"
        case .failed(let message): return message
        }
    }
}

public struct ArchiveEntryInfo: Equatable {
    public let path: String
    public let isDirectory: Bool
    public let uncompressedSize: Int64
    public let compressedSize: Int64

    public init(path: String, isDirectory: Bool, uncompressedSize: Int64, compressedSize: Int64) {
        self.path = path
        self.isDirectory = isDirectory
        self.uncompressedSize = uncompressedSize
        self.compressedSize = compressedSize
    }
}

/// ZIP 内項目を実ファイル URL と区別して表す参照です。
public struct ArchiveEntryReference: Equatable {
    public let archiveURL: URL
    public let entryPath: String
    public let isDirectory: Bool

    public init(archiveURL: URL, entryPath: String, isDirectory: Bool) {
        self.archiveURL = archiveURL
        self.entryPath = entryPath
        self.isDirectory = isDirectory
    }
}

public struct ArchiveExtractionResult: Equatable {
    public let destinationURL: URL
    public let extractedItemCount: Int
}

public protocol ArchiveProviding {
    func entries(in archiveURL: URL) throws -> [ArchiveEntryInfo]
    func suggestedZIPDestination(for sourceURLs: [URL], in destinationDirectory: URL) throws -> URL
    func createZIP(from sourceURLs: [URL], to destinationURL: URL) throws
    func extractZIP(at archiveURL: URL, to destinationURL: URL) throws -> ArchiveExtractionResult
}

/// ZIP の読み取り・作成・展開を集約するサービスです。UI はこの型を直接のファイル操作に置き換えません。
public final class ArchiveService: ArchiveProviding {
    private let fileManager: FileManager
    private let maximumEntryCount: Int
    private let maximumUncompressedSize: UInt64

    public init(
        fileManager: FileManager = .default,
        maximumEntryCount: Int = 100_000,
        maximumUncompressedSize: UInt64 = 20 * 1024 * 1024 * 1024
    ) {
        self.fileManager = fileManager
        self.maximumEntryCount = maximumEntryCount
        self.maximumUncompressedSize = maximumUncompressedSize
    }

    public func entries(in archiveURL: URL) throws -> [ArchiveEntryInfo] {
        let archive = try openArchive(at: archiveURL)
        return try validatedEntries(in: archive).map {
            ArchiveEntryInfo(
                path: $0.path,
                isDirectory: $0.entry.type == .directory,
                uncompressedSize: Int64(clamping: $0.entry.uncompressedSize),
                compressedSize: Int64(clamping: $0.entry.compressedSize)
            )
        }
    }

    public func suggestedZIPDestination(for sourceURLs: [URL], in destinationDirectory: URL) throws -> URL {
        let sources = uniqueURLs(sourceURLs)
        guard let firstSource = sources.first else { throw ArchiveServiceError.emptySources }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destinationDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ArchiveServiceError.destinationNotDirectory(destinationDirectory)
        }

        let baseName = firstSource.lastPathComponent
        var candidateName = baseName + ".zip"
        var suffix = 2
        while fileManager.fileExists(atPath: destinationDirectory.appendingPathComponent(candidateName).path) {
            candidateName = "\(baseName)_\(suffix).zip"
            suffix += 1
        }
        return destinationDirectory.appendingPathComponent(candidateName)
    }

    public func createZIP(from sourceURLs: [URL], to destinationURL: URL) throws {
        let sources = uniqueURLs(sourceURLs)
        guard !sources.isEmpty else { throw ArchiveServiceError.emptySources }
        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            throw ArchiveServiceError.destinationAlreadyExists(destinationURL)
        }
        let parentURL = destinationURL.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: parentURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ArchiveServiceError.destinationNotDirectory(parentURL)
        }

        for sourceURL in sources {
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                throw ArchiveServiceError.sourceDoesNotExist(sourceURL)
            }
            try validateSourceTree(at: sourceURL)
            guard !destinationURL.standardizedFileURL.path.hasPrefix(sourceURL.standardizedFileURL.path + "/") else {
                throw ArchiveServiceError.destinationInsideSource
            }
        }

        let temporaryURL = parentURL.appendingPathComponent(".mafx-archive-\(UUID().uuidString).zip")
        defer { try? fileManager.removeItem(at: temporaryURL) }
        do {
            let archive = try Archive(url: temporaryURL, accessMode: .create)
            for sourceURL in sources {
                try addRecursively(sourceURL, archive: archive, rootPath: sourceURL.lastPathComponent)
            }
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        } catch let error as ArchiveServiceError {
            throw error
        } catch {
            throw ArchiveServiceError.failed(error.localizedDescription)
        }
    }

    public func extractZIP(at archiveURL: URL, to destinationURL: URL) throws -> ArchiveExtractionResult {
        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            throw ArchiveServiceError.destinationAlreadyExists(destinationURL)
        }
        let parentURL = destinationURL.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: parentURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ArchiveServiceError.destinationNotDirectory(parentURL)
        }

        let archive = try openArchive(at: archiveURL)
        let entries = try validatedEntries(in: archive)
        let temporaryURL = parentURL.appendingPathComponent(".mafx-extract-\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: temporaryURL, withIntermediateDirectories: false)
            for validated in entries {
                let outputURL = temporaryURL.appendingPathComponent(validated.path)
                _ = try archive.extract(validated.entry, to: outputURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            return ArchiveExtractionResult(destinationURL: destinationURL, extractedItemCount: entries.count)
        } catch let error as ArchiveServiceError {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw ArchiveServiceError.failed(error.localizedDescription)
        }
    }

    private func openArchive(at url: URL) throws -> Archive {
        guard fileManager.fileExists(atPath: url.path) else { throw ArchiveServiceError.sourceDoesNotExist(url) }
        guard url.pathExtension.caseInsensitiveCompare("zip") == .orderedSame else {
            throw ArchiveServiceError.sourceIsNotZIP(url)
        }
        do {
            return try Archive(url: url, accessMode: .read)
        } catch {
            throw ArchiveServiceError.readFailed
        }
    }

    private func validatedEntries(in archive: Archive) throws -> [(entry: Entry, path: String)] {
        var entries: [(entry: Entry, path: String)] = []
        var totalSize: UInt64 = 0
        for entry in archive {
            guard entries.count < maximumEntryCount else { throw ArchiveServiceError.archiveTooLarge }
            let path = decodedPath(for: entry)
            try validateArchivePath(path)
            guard entry.type != .symlink else { throw ArchiveServiceError.symbolicLinkNotSupported(path) }
            let (newTotal, overflow) = totalSize.addingReportingOverflow(entry.uncompressedSize)
            guard !overflow, newTotal <= maximumUncompressedSize else { throw ArchiveServiceError.archiveTooLarge }
            totalSize = newTotal
            entries.append((entry, path))
        }
        return entries
    }

    /// ZIP の UTF-8 フラグがない古い日本語 ZIP にも対応します。
    ///
    /// ZIPFoundation の `Entry.path` はフラグなしの場合に CP437 を使いますが、
    /// 日本語圏の既存 ZIP では Shift_JIS が使われていることがあります。
    /// UTF-8 として復号できる名前は UTF-8 を優先し、それ以外だけ Shift_JIS
    /// を試します。どちらでも復号できない場合は空文字列として扱い、通常の
    /// エントリパス検証で安全に拒否します。
    private func decodedPath(for entry: Entry) -> String {
        let utf8Path = entry.path(using: .utf8)
        if !utf8Path.isEmpty {
            return utf8Path
        }
        return entry.path(using: .shiftJIS)
    }

    private func validateArchivePath(_ path: String) throws {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.hasPrefix("\\") else {
            throw ArchiveServiceError.invalidEntryPath(path)
        }
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.split(separator: "/").contains("..") else {
            throw ArchiveServiceError.invalidEntryPath(path)
        }
    }

    private func validateSourceTree(at sourceURL: URL) throws {
        let values = try sourceURL.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        if values.isSymbolicLink == true { throw ArchiveServiceError.symbolicLinkNotSupported(sourceURL.path) }
        guard values.isDirectory == true else { return }
        guard let enumerator = fileManager.enumerator(at: sourceURL, includingPropertiesForKeys: [.isSymbolicLinkKey]) else { return }
        for case let itemURL as URL in enumerator {
            if try itemURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true {
                throw ArchiveServiceError.symbolicLinkNotSupported(itemURL.path)
            }
        }
    }

    private func addRecursively(_ sourceURL: URL, archive: Archive, rootPath: String) throws {
        try archive.addEntry(with: rootPath, fileURL: sourceURL, compressionMethod: .deflate)
        let values = try sourceURL.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { return }
        let children = try fileManager.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )
        for childURL in children {
            try addRecursively(childURL, archive: archive, rootPath: rootPath + "/" + childURL.lastPathComponent)
        }
    }

    private func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<URL>()
        return urls.filter { seen.insert($0.standardizedFileURL).inserted }
    }
}
