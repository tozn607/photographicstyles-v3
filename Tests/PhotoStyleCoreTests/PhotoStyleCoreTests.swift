import XCTest
@testable import PhotoStyleCore

final class PhotoStyleCoreTests: XCTestCase {
    func testVersion() {
        XCTAssertFalse(PhotoStyleBridge.version.isEmpty)
        XCTAssertEqual(PhotoStyleBridge.version, "0.4.2")
    }
}
