import Foundation

public protocol PathCompletionProviding {
    func resolvedDirectoryURL(for input: String, relativeTo baseDirectory: URL) -> URL?
    func completedPath(for input: String, relativeTo baseDirectory: URL) -> String?
    func completionCandidates(for input: String, relativeTo baseDirectory: URL) -> [String]
}

public final class PathCompletionService: PathCompletionProviding {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func resolvedDirectoryURL(for input: String, relativeTo baseDirectory: URL) -> URL? {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            return nil
        }

        let url = resolvedURL(for: trimmedInput, relativeTo: baseDirectory)
        guard isDirectory(url) else {
            return nil
        }

        return url.standardizedFileURL
    }

    public func completedPath(for input: String, relativeTo baseDirectory: URL) -> String? {
        completionCandidates(for: input, relativeTo: baseDirectory).first
    }

    public func completionCandidates(for input: String, relativeTo baseDirectory: URL) -> [String] {
        if input.isEmpty {
            return [baseDirectory.standardizedFileURL.path + "/"]
        }

        let resolvedInput = resolvedURL(for: input, relativeTo: baseDirectory)
        let completesChildName = input.hasSuffix("/") == false
        let searchDirectory = completesChildName ? resolvedInput.deletingLastPathComponent() : resolvedInput
        let partialName = completesChildName ? resolvedInput.lastPathComponent : ""

        guard isDirectory(searchDirectory) else {
            return []
        }

        let matchingDirectories = directoryNames(in: searchDirectory)
            .filter { partialName.isEmpty || hasCaseInsensitivePrefix($0, prefix: partialName) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        guard !matchingDirectories.isEmpty else {
            return []
        }

        return matchingDirectories.map {
            searchDirectory.appendingPathComponent($0, isDirectory: true).standardizedFileURL.path + "/"
        }
    }

    private func resolvedURL(for input: String, relativeTo baseDirectory: URL) -> URL {
        let expandedInput = (input as NSString).expandingTildeInPath
        if expandedInput.hasPrefix("/") {
            return URL(fileURLWithPath: expandedInput, isDirectory: true).standardizedFileURL
        }

        return baseDirectory.appendingPathComponent(input, isDirectory: true).standardizedFileURL
    }

    private func directoryNames(in directory: URL) -> [String] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: []
        ) else {
            return []
        }

        return urls.compactMap { url in
            guard isDirectory(url) else {
                return nil
            }

            return url.lastPathComponent
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else {
            return false
        }

        return values.isDirectory == true && values.isSymbolicLink != true
    }

    private func hasCaseInsensitivePrefix(_ value: String, prefix: String) -> Bool {
        value.range(of: prefix, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
    }
}
