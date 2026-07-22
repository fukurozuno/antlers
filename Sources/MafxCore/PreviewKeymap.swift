import Foundation

public enum PreviewCommand: Equatable {
    case endPreview
}

/// プレビュー表示中だけに適用する固定キーを解決する。
///
/// 一覧操作用の `KeymapResolver` とは分離し、プレビュー中に許可する
/// コマンドを明示的に追加できるようにする。
public struct PreviewKeymapResolver {
    public init() {}

    public func resolve(_ stroke: KeyStroke) -> PreviewCommand? {
        guard stroke.modifiers.isEmpty else {
            return nil
        }

        switch stroke.key {
        case "Q":
            return .endPreview
        default:
            return nil
        }
    }
}
