import Foundation
import MafxCore

func localizedErrorDescription(_ error: Error) -> String {
    if let error = error as? FileOperationError {
        switch error {
        case .emptyName: return L10n.string("error.fileOperation.emptyName")
        case .invalidName(let name): return L10n.format("error.fileOperation.invalidName", name)
        case .sourceDoesNotExist(let url): return L10n.format("error.fileOperation.sourceDoesNotExist", url.lastPathComponent)
        case .destinationNotDirectory(let url): return L10n.format("error.fileOperation.destinationNotDirectory", url.lastPathComponent)
        case .destinationAlreadyExists(let url): return L10n.format("error.fileOperation.destinationAlreadyExists", url.lastPathComponent)
        case .destinationInsideSource(let source, let destination):
            return L10n.format("error.fileOperation.destinationInsideSource", source.lastPathComponent, destination.lastPathComponent)
        case .outsideScope(let url): return L10n.format("error.fileOperation.outsideScope", url.lastPathComponent)
        case .failed(let message): return message
        }
    }

    if let error = error as? ArchiveServiceError {
        switch error {
        case .sourceDoesNotExist(let url): return L10n.format("error.archive.sourceDoesNotExist", url.lastPathComponent)
        case .sourceIsNotZIP(let url): return L10n.format("error.archive.sourceIsNotZIP", url.lastPathComponent)
        case .destinationAlreadyExists(let url): return L10n.format("error.archive.destinationAlreadyExists", url.lastPathComponent)
        case .destinationNotDirectory(let url): return L10n.format("error.archive.destinationNotDirectory", url.lastPathComponent)
        case .invalidEntryPath(let path): return L10n.format("error.archive.invalidEntryPath", path)
        case .symbolicLinkNotSupported(let path): return L10n.format("error.archive.symbolicLinkNotSupported", path)
        case .archiveTooLarge: return L10n.string("error.archive.tooLarge")
        case .emptySources: return L10n.string("error.archive.emptySources")
        case .destinationInsideSource: return L10n.string("error.archive.destinationInsideSource")
        case .readFailed: return L10n.string("error.archive.readFailed")
        case .failed(let message): return message
        }
    }

    return error.localizedDescription
}

