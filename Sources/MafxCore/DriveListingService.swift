import Foundation

public struct DriveVolume: Equatable, Identifiable {
    public let id: URL
    public let url: URL
    public let displayName: String
    /// Mafx が安全なアンマウント対象として扱う外部ローカルボリュームか。
    public let isUnmountable: Bool

    public init(url: URL, displayName: String, isUnmountable: Bool = false) {
        self.id = url
        self.url = url
        self.displayName = displayName
        self.isUnmountable = isUnmountable
    }
}

public protocol DriveListingProviding {
    func locations() throws -> [DriveVolume]
}

public final class DriveListingService: DriveListingProviding {
    private let fileManager: FileManager
    private let homeDirectory: URL
    private let volumesDirectory: URL
    private let mountedVolumeURLsProvider: () -> [URL]?
    private let mountedVolumeMetadataProvider: (URL) throws -> MountedVolumeMetadata

    public init(
        fileManager: FileManager = .default,
        homeDirectory: URL? = nil,
        volumesDirectory: URL = URL(fileURLWithPath: "/Volumes", isDirectory: true),
        mountedVolumeURLsProvider: (() -> [URL]?)? = nil,
        mountedVolumeMetadataProvider: ((URL) throws -> MountedVolumeMetadata)? = nil
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
        self.volumesDirectory = volumesDirectory
        self.mountedVolumeURLsProvider = mountedVolumeURLsProvider ?? {
            fileManager.mountedVolumeURLs(
                includingResourceValuesForKeys: [.volumeLocalizedNameKey, .volumeIsInternalKey, .volumeIsLocalKey, .volumeIsRootFileSystemKey],
                options: [.skipHiddenVolumes]
            )
        }
        self.mountedVolumeMetadataProvider = mountedVolumeMetadataProvider ?? { url in
            let values = try url.resourceValues(forKeys: [.volumeLocalizedNameKey, .volumeIsInternalKey, .volumeIsLocalKey, .volumeIsRootFileSystemKey])
            return MountedVolumeMetadata(
                localizedName: values.volumeLocalizedName,
                isInternal: values.volumeIsInternal == true,
                isLocal: values.volumeIsLocal == true,
                isRootFileSystem: values.volumeIsRootFileSystem == true
            )
        }
    }

    public func locations() throws -> [DriveVolume] {
        let volumes = try mountedVolumeLocations()
        let volumeDirectoryLocations = try volumeDirectoryLocations()
        let cloudStorageLocations = try cloudStorageLocations()
        let iCloudDriveLocations = iCloudDriveLocation()

        return deduplicated(iCloudDriveLocations + cloudStorageLocations + volumes + volumeDirectoryLocations)
            .sorted { lhs, rhs in
                lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
    }

    private func mountedVolumeLocations() throws -> [DriveVolume] {
        guard let urls = mountedVolumeURLsProvider() else {
            return []
        }

        return try urls.map { url in
            let metadata = try mountedVolumeMetadataProvider(url)
            return DriveVolume(
                url: url,
                displayName: Self.displayName(for: url, localizedName: metadata.localizedName),
                isUnmountable: metadata.isUnmountable
            )
        }
    }

    private func volumeDirectoryLocations() throws -> [DriveVolume] {
        guard directoryExists(at: volumesDirectory) else {
            return []
        }

        let urls = try fileManager.contentsOfDirectory(
            at: volumesDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )

        return try urls.compactMap { url in
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                return nil
            }

            return DriveVolume(url: url, displayName: url.lastPathComponent)
        }
    }

    private func iCloudDriveLocation() -> [DriveVolume] {
        let url = homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Mobile Documents", isDirectory: true)
            .appendingPathComponent("com~apple~CloudDocs", isDirectory: true)

        guard directoryExists(at: url) else {
            return []
        }

        return [DriveVolume(url: url, displayName: "iCloud Drive")]
    }

    private func cloudStorageLocations() throws -> [DriveVolume] {
        let cloudStorageDirectory = homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("CloudStorage", isDirectory: true)

        guard directoryExists(at: cloudStorageDirectory) else {
            return []
        }

        let urls = try fileManager.contentsOfDirectory(
            at: cloudStorageDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return try urls.compactMap { url in
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else {
                return nil
            }

            return DriveVolume(url: url, displayName: url.lastPathComponent)
        }
    }

    private func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func deduplicated(_ volumes: [DriveVolume]) -> [DriveVolume] {
        var seenPaths: Set<String> = []
        var result: [DriveVolume] = []

        for volume in volumes {
            let path = volume.url.resolvingSymlinksInPath().standardizedFileURL.path
            guard seenPaths.insert(path).inserted else {
                continue
            }

            result.append(volume)
        }

        return result
    }

    private static func displayName(for url: URL, localizedName: String?) -> String {
        if let localizedName, !localizedName.isEmpty {
            return localizedName
        }

        let lastPathComponent = url.lastPathComponent
        return lastPathComponent.isEmpty ? url.path : lastPathComponent
    }
}

public struct MountedVolumeMetadata: Equatable {
    public let localizedName: String?
    public let isInternal: Bool
    public let isLocal: Bool
    public let isRootFileSystem: Bool

    public init(localizedName: String?, isInternal: Bool, isLocal: Bool, isRootFileSystem: Bool) {
        self.localizedName = localizedName
        self.isInternal = isInternal
        self.isLocal = isLocal
        self.isRootFileSystem = isRootFileSystem
    }

    public var isUnmountable: Bool {
        isLocal && !isInternal && !isRootFileSystem
    }
}
