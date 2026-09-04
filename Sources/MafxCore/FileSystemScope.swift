import Foundation

/// Mafx が参照・変更できるファイルシステムの範囲です。
public enum FileSystemScope: Equatable {
    case unrestricted
    case confined(rootURL: URL)

    public init?(confinedRootURL: URL, fileManager: FileManager = .default) {
        let canonicalURL = confinedRootURL.resolvingSymlinksInPath().standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: canonicalURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        self = .confined(rootURL: canonicalURL)
    }

    public var confinedRootURL: URL? {
        guard case .confined(let rootURL) = self else { return nil }
        return rootURL
    }

    public func contains(_ url: URL) -> Bool {
        guard case .confined(let rootURL) = self else { return true }
        let candidate = Self.resolvedURLIncludingExistingSymlinkComponents(url)
        let rootPath = rootURL.standardizedFileURL.path
        let candidatePath = candidate.path
        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath.hasSuffix("/") ? rootPath : rootPath + "/")
    }

    private static func resolvedURLIncludingExistingSymlinkComponents(_ url: URL) -> URL {
        let fileManager = FileManager.default
        var existing = url.standardizedFileURL
        var suffix: [String] = []
        while !fileManager.fileExists(atPath: existing.path), existing.path != "/" {
            suffix.insert(existing.lastPathComponent, at: 0)
            existing.deleteLastPathComponent()
        }

        var resolved = existing.resolvingSymlinksInPath().standardizedFileURL
        for component in suffix {
            resolved.appendPathComponent(component)
        }
        return resolved.standardizedFileURL
    }

    public func validate(_ url: URL) throws {
        guard contains(url) else {
            throw FileSystemScopeError.outsideScope(url)
        }
    }

    public func relativePath(_ path: String) -> URL? {
        guard let rootURL = confinedRootURL,
              !path.isEmpty,
              !path.hasPrefix("/") else { return nil }
        let url = rootURL.appendingPathComponent(path)
        return contains(url) ? url : nil
    }
}

public enum FileSystemScopeError: Error, Equatable {
    case outsideScope(URL)
    case invalidConfinedRoot(URL)
}

extension FileSystemScopeError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .outsideScope(let url):
            return "操作対象が許可された範囲外です: \(url.lastPathComponent)"
        case .invalidConfinedRoot(let url):
            return "Confined root が存在しないフォルダです: \(url.path)"
        }
    }
}
