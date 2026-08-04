import AppKit
import DiskArbitration
import MafxCore

protocol VolumeEjecting {
    var safeFallbackDirectory: URL { get }
    func unmount(
        _ volume: DriveVolume,
        force: Bool,
        completion: @escaping (Result<Void, Swift.Error>) -> Void
    )
}

/// ボリュームのアンマウントを Disk Arbitration に限定するインフラストラクチャサービスです。
final class VolumeEjectionService: VolumeEjecting {
    enum Error: LocalizedError {
        case notUnmountable
        case diskNotFound
        case refused(String)

        var errorDescription: String? {
            switch self {
            case .notUnmountable:
                return L10n.string("error.volumeNotUnmountable")
            case .diskNotFound:
                return L10n.string("error.volumeNotFound")
            case .refused(let reason):
                return reason
            }
        }

        var canForceRetry: Bool {
            if case .refused = self {
                return true
            }
            return false
        }
    }

    let safeFallbackDirectory = FileManager.default.homeDirectoryForCurrentUser

    func unmount(
        _ volume: DriveVolume,
        force: Bool,
        completion: @escaping (Result<Void, Swift.Error>) -> Void
    ) {
        guard volume.isUnmountable else {
            completion(.failure(Error.notUnmountable))
            return
        }

        guard let session = DASessionCreate(kCFAllocatorDefault),
              let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, volume.url as CFURL) else {
            completion(.failure(Error.diskNotFound))
            return
        }

        let operation = UnmountOperation(session: session, completion: completion)
        DASessionSetDispatchQueue(session, DispatchQueue.global(qos: .userInitiated))
        let options = force ? kDADiskUnmountOptionForce : kDADiskUnmountOptionDefault
        DADiskUnmount(disk, DADiskUnmountOptions(options), { _, dissenter, context in
            let operation = Unmanaged<UnmountOperation>.fromOpaque(context!).takeRetainedValue()
            DASessionSetDispatchQueue(operation.session, nil)

            if let dissenter {
                let reason = DADissenterGetStatusString(dissenter) as String? ?? L10n.string("error.volumeUnmountFailed")
                operation.completion(.failure(Error.refused(reason)))
            } else {
                operation.completion(.success(()))
            }
        }, Unmanaged.passRetained(operation).toOpaque())
    }
}

private final class UnmountOperation {
    let session: DASession
    let completion: (Result<Void, Swift.Error>) -> Void

    init(session: DASession, completion: @escaping (Result<Void, Swift.Error>) -> Void) {
        self.session = session
        self.completion = completion
    }
}
