import MafxCore

struct LaunchOptions: Equatable {
    var appLanguage: AppLanguage?
    var themeID: String?

    static func parse(arguments: [String]) -> LaunchOptions {
        var options = LaunchOptions(appLanguage: nil, themeID: nil)
        var index = 0

        while index < arguments.count {
            switch arguments[index] {
            case "--language":
                if index + 1 < arguments.count {
                    options.appLanguage = AppLanguage(rawValue: arguments[index + 1])
                    index += 1
                }
            case "--theme":
                if index + 1 < arguments.count {
                    options.themeID = arguments[index + 1]
                    index += 1
                }
            default:
                break
            }
            index += 1
        }

        return options
    }
}
