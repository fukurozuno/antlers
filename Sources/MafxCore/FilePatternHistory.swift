import Foundation

/// ファイルマスクとワイルドカードマークで共有する最近使用したパターンの履歴です。
public struct FilePatternHistory: Codable, Equatable {
    public static let maximumEntryCount = 50

    public private(set) var entries: [String]

    public init(entries: [String] = []) {
        self.entries = Self.normalized(entries)
    }

    public mutating func record(_ pattern: String) {
        let normalizedPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPattern.isEmpty else {
            return
        }

        entries.removeAll { $0 == normalizedPattern }
        entries.insert(normalizedPattern, at: 0)
        entries = Array(entries.prefix(Self.maximumEntryCount))
    }

    private static func normalized(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return Array(values.compactMap { value in
            let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedValue.isEmpty, seen.insert(normalizedValue).inserted else {
                return nil
            }
            return normalizedValue
        }.prefix(maximumEntryCount))
    }
}
