import XCTest
@testable import JFTV

/// The Settings rail: four tabs in a fixed order, starting on PLAYBACK & PICTURE.
final class SettingsFeaturesTests: XCTestCase {

    func testRailKeepsOrder() {
        XCTAssertEqual(
            SettingsCategory.allCases,
            [.playback, .channels, .servers, .about]
        )
    }

    func testDefaultTabIsPlayback() {
        // The container opens on the first tab; nothing may quietly depend on a
        // removed category still existing.
        XCTAssertEqual(SettingsCategory.allCases.first, .playback)
    }
}
