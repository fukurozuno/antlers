import Foundation

struct AppVersionInfo: Equatable {
    let shortVersion: String
    let buildVersion: String?

    var aboutPanelVersion: String {
        shortVersion
    }

    static func current(bundle: Bundle = .main) -> AppVersionInfo {
        from(infoDictionary: bundle.infoDictionary)
    }

    static func from(infoDictionary: [String: Any]?) -> AppVersionInfo {
        let shortVersion = nonEmptyString(
            forKey: "CFBundleShortVersionString",
            in: infoDictionary
        ) ?? "Development"
        let buildVersion = nonEmptyString(
            forKey: "CFBundleVersion",
            in: infoDictionary
        )

        return AppVersionInfo(shortVersion: shortVersion, buildVersion: buildVersion)
    }

    private static func nonEmptyString(
        forKey key: String,
        in infoDictionary: [String: Any]?
    ) -> String? {
        guard let value = infoDictionary?[key] as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return value
    }
}
