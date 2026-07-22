import Foundation

final class FileSizeFormatter {
    private let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter
    }()

    func string(fromByteCount byteCount: Int64) -> String {
        if byteCount > -1000 && byteCount < 1000 {
            return "\(byteCount)  B"
        }

        return byteCountFormatter.string(fromByteCount: byteCount)
    }
}
