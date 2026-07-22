import Foundation

public struct FileTag: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let color: FileTagColor?

    public init(name: String, color: FileTagColor? = nil) {
        self.id = name
        self.name = name
        self.color = color
    }

    public init?(resourceValue: String) {
        let components = resourceValue.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        guard let name = components.first.map(String.init), !name.isEmpty else {
            return nil
        }

        self.init(
            name: name,
            color: components.dropFirst().first
                .flatMap { Int($0) }
                .flatMap(FileTagColor.init(rawValue:))
        )
    }
}

public enum FileTagColor: Int, Equatable, CaseIterable {
    case gray = 1
    case green = 2
    case purple = 3
    case blue = 4
    case yellow = 5
    case red = 6
    case orange = 7
}

public protocol FileTagProviding {
    func allTags() -> [FileTag]
    func tags(in items: [FileItem]) -> [FileTag]
    func tags(of url: URL) throws -> [FileTag]
    func items(matching tag: FileTag) throws -> [FileItem]
    func setTag(_ tag: FileTag, enabled: Bool, for url: URL) throws
}

public final class TagService: FileTagProviding {
    public enum Error: Swift.Error, Equatable {
        case metadataQueryTimedOut
    }

    public typealias TaggedURLProvider = (FileTag) throws -> [URL]

    private let finderUserDefaults: UserDefaults?
    private let fileManager: FileManager
    private let taggedURLProvider: TaggedURLProvider

    public init(
        finderUserDefaults: UserDefaults? = UserDefaults(suiteName: "com.apple.finder"),
        fileManager: FileManager = .default,
        taggedURLProvider: TaggedURLProvider? = nil
    ) {
        self.finderUserDefaults = finderUserDefaults
        self.fileManager = fileManager
        self.taggedURLProvider = taggedURLProvider ?? Self.spotlightURLs(matching:)
    }

    public func allTags() -> [FileTag] {
        Self.sortedTags(finderTags())
    }

    public func tags(in items: [FileItem]) -> [FileTag] {
        Self.sortedTags(finderTags() + items.flatMap(\.tagNames).compactMap(FileTag.init(resourceValue:)))
    }

    public func tags(of url: URL) throws -> [FileTag] {
        let values = try url.resourceValues(forKeys: [.tagNamesKey])
        return Self.sortedTags((values.tagNames ?? []).compactMap(FileTag.init(resourceValue:)))
    }

    public func items(matching tag: FileTag) throws -> [FileItem] {
        let urls = try taggedURLProvider(tag)
        let items = urls.compactMap { url -> FileItem? in
            try? fileItem(at: url)
        }

        return items.sorted { lhs, rhs in
            lhs.url.path.localizedStandardCompare(rhs.url.path) == .orderedAscending
        }
    }

    public func setTag(_ tag: FileTag, enabled: Bool, for url: URL) throws {
        let currentNames = try tags(of: url).map(\.name)
        var names = Set(currentNames)
        if enabled {
            names.insert(tag.name)
        } else {
            names.remove(tag.name)
        }

        try (url as NSURL).setResourceValue(Self.sortedNames(names), forKey: .tagNamesKey)
    }

    private func fileItem(at url: URL) throws -> FileItem? {
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        let values = try url.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey, .tagNamesKey]
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

    private static func sortedTags(_ tags: [FileTag]) -> [FileTag] {
        var tagsByName: [String: FileTag] = [:]
        for tag in tags where !tag.name.isEmpty {
            let existingColor = tagsByName[tag.name]?.color
            let color = existingColor ?? tag.color
            tagsByName[tag.name] = FileTag(name: tag.name, color: color)
        }

        return tagsByName.values.sorted { lhs, rhs in
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private static func sortedNames(_ names: Set<String>) -> [String] {
        names
            .filter { !$0.isEmpty }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func finderTags() -> [FileTag] {
        guard let finderUserDefaults else {
            return []
        }

        var tagsByName: [String: FileTag] = [:]
        if let favoriteTagNames = finderUserDefaults.array(forKey: "FavoriteTagNames") as? [String] {
            for (index, rawName) in favoriteTagNames.enumerated() {
                guard let tag = FileTag(resourceValue: rawName) else {
                    continue
                }

                tagsByName[tag.name] = FileTag(
                    name: tag.name,
                    color: tag.color ?? Self.favoriteTagColor(at: index, favoriteTagCount: favoriteTagNames.count)
                )
            }
        }

        collectFinderTags(from: finderUserDefaults.dictionaryRepresentation(), into: &tagsByName)
        return Array(tagsByName.values)
    }

    private static func favoriteTagColor(at index: Int, favoriteTagCount: Int) -> FileTagColor? {
        guard favoriteTagCount >= 8 else {
            return nil
        }

        switch index {
        case 1:
            return .red
        case 2:
            return .orange
        case 3:
            return .yellow
        case 4:
            return .green
        case 5:
            return .blue
        case 6:
            return .purple
        case 7:
            return .gray
        default:
            return nil
        }
    }

    private func collectFinderTags(from value: Any, into tagsByName: inout [String: FileTag]) {
        if let dictionary = value as? [String: Any] {
            for (key, nestedValue) in dictionary {
                if key.hasSuffix("_Tag_ViewSettings") {
                    let name = String(key.dropLast("_Tag_ViewSettings".count))
                    if !name.isEmpty, tagsByName[name] == nil {
                        tagsByName[name] = FileTag(name: name)
                    }
                }
                collectFinderTags(from: nestedValue, into: &tagsByName)
            }
            return
        }

        if let array = value as? [Any] {
            for nestedValue in array {
                collectFinderTags(from: nestedValue, into: &tagsByName)
            }
        }
    }

    private static func spotlightURLs(matching tag: FileTag) throws -> [URL] {
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(
            format: "%K == %@ || %K LIKE %@",
            "kMDItemUserTags",
            tag.name,
            "kMDItemUserTags",
            "\(tag.name)\n*"
        )
        query.searchScopes = [NSMetadataQueryLocalComputerScope]

        var didFinish = false
        var observer: NSObjectProtocol?
        observer = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: nil
        ) { _ in
            query.disableUpdates()
            didFinish = true
        }

        defer {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
            query.stop()
        }

        guard query.start() else {
            throw Error.metadataQueryTimedOut
        }

        let deadline = Date(timeIntervalSinceNow: 10)
        while !didFinish && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }

        guard didFinish else {
            throw Error.metadataQueryTimedOut
        }

        var urls: [URL] = []
        for index in 0..<query.resultCount {
            guard let item = query.result(at: index) as? NSMetadataItem else {
                continue
            }
            if let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                urls.append(url)
            } else if let path = item.value(forAttribute: NSMetadataItemPathKey) as? String {
                urls.append(URL(fileURLWithPath: path))
            }
        }

        return urls
    }
}
