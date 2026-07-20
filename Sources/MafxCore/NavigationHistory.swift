import Foundation

public struct NavigationHistory: Codable, Equatable {
    public private(set) var paths: [String]
    public private(set) var currentIndex: Int

    public init(paths: [String] = [], currentIndex: Int = 0) {
        let normalizedPaths = paths.map(Self.normalizedPath)
        self.paths = Self.deduplicatedConsecutivePaths(normalizedPaths)

        if self.paths.isEmpty {
            self.currentIndex = 0
        } else {
            self.currentIndex = max(0, min(currentIndex, self.paths.count - 1))
        }
    }

    public var currentPath: String? {
        guard paths.indices.contains(currentIndex) else {
            return nil
        }

        return paths[currentIndex]
    }

    public var canMoveBackward: Bool {
        currentIndex > 0
    }

    public var canMoveForward: Bool {
        currentIndex < paths.count - 1
    }

    public func prepared(for currentDirectory: URL) -> NavigationHistory {
        var history = self
        history.record(currentDirectory)
        return history
    }

    public mutating func record(_ directory: URL) {
        let path = Self.normalizedPath(directory.path)

        if currentPath == path {
            return
        }

        if canMoveForward {
            paths.removeSubrange((currentIndex + 1)..<paths.count)
        }

        paths.append(path)
        currentIndex = paths.count - 1
    }

    public mutating func moveBackward() -> URL? {
        guard canMoveBackward else {
            return nil
        }

        currentIndex -= 1
        return URL(fileURLWithPath: paths[currentIndex], isDirectory: true)
    }

    public mutating func moveForward() -> URL? {
        guard canMoveForward else {
            return nil
        }

        currentIndex += 1
        return URL(fileURLWithPath: paths[currentIndex], isDirectory: true)
    }

    public mutating func moveToPath(at index: Int) -> URL? {
        guard paths.indices.contains(index) else {
            return nil
        }

        currentIndex = index
        return URL(fileURLWithPath: paths[index], isDirectory: true)
    }

    public static func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private static func deduplicatedConsecutivePaths(_ paths: [String]) -> [String] {
        paths.reduce(into: []) { result, path in
            if result.last != path {
                result.append(path)
            }
        }
    }
}
