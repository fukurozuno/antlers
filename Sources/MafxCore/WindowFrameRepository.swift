import Foundation

public struct WindowFrame: Codable, Equatable {
    public let originX: Double
    public let originY: Double
    public let width: Double
    public let height: Double

    public init?(originX: Double, originY: Double, width: Double, height: Double) {
        guard originX.isFinite,
              originY.isFinite,
              width.isFinite,
              height.isFinite,
              width > 0,
              height > 0 else {
            return nil
        }

        self.originX = originX
        self.originY = originY
        self.width = width
        self.height = height
    }

    private enum CodingKeys: String, CodingKey {
        case originX
        case originY
        case width
        case height
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let originX = try container.decode(Double.self, forKey: .originX)
        let originY = try container.decode(Double.self, forKey: .originY)
        let width = try container.decode(Double.self, forKey: .width)
        let height = try container.decode(Double.self, forKey: .height)

        guard let frame = Self(originX: originX, originY: originY, width: width, height: height) else {
            throw DecodingError.dataCorruptedError(
                forKey: .width,
                in: container,
                debugDescription: "Window frame dimensions must be finite and positive."
            )
        }

        self = frame
    }
}

public protocol WindowFrameRepository {
    func load() -> WindowFrame?
    func save(_ frame: WindowFrame)
}

public final class UserDefaultsWindowFrameRepository: WindowFrameRepository {
    private enum Key {
        static let mainWindowFrame = "window.main.frame"
    }

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func load() -> WindowFrame? {
        guard let data = userDefaults.data(forKey: Key.mainWindowFrame) else {
            return nil
        }

        return try? JSONDecoder().decode(WindowFrame.self, from: data)
    }

    public func save(_ frame: WindowFrame) {
        guard let data = try? JSONEncoder().encode(frame) else {
            return
        }

        userDefaults.set(data, forKey: Key.mainWindowFrame)
    }
}
