import XCTest
@testable import MafxCore

final class WindowFrameRepositoryTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "MafxCoreTests.WindowFrameRepository.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testLoadReturnsNilWhenNoWindowFrameHasBeenSaved() {
        let repository = UserDefaultsWindowFrameRepository(userDefaults: userDefaults)

        XCTAssertNil(repository.load())
    }

    func testSaveAndLoadRoundTripsWindowFrame() {
        let repository = UserDefaultsWindowFrameRepository(userDefaults: userDefaults)
        let frame = WindowFrame(originX: 120, originY: 240, width: 980, height: 620)

        XCTAssertNotNil(frame)
        repository.save(frame!)

        XCTAssertEqual(repository.load(), frame)
    }

    func testWindowFrameRejectsInvalidDimensions() {
        XCTAssertNil(WindowFrame(originX: 0, originY: 0, width: 0, height: 620))
        XCTAssertNil(WindowFrame(originX: 0, originY: 0, width: 980, height: -.infinity))
    }

    func testWindowFrameDecodingRejectsInvalidDimensions() {
        let json = """
        {
          "originX": 120,
          "originY": 240,
          "width": -980,
          "height": 620
        }
        """

        XCTAssertThrowsError(try JSONDecoder().decode(WindowFrame.self, from: Data(json.utf8)))
    }
}
