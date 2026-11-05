import XCTest
@testable import Nostalgex

/// The Settings rail: five tabs in a fixed order, SUPPORT NOSTALGEX pinned at the top.
final class SettingsFeaturesTests: XCTestCase {

    func testRailKeepsOrder() {
        XCTAssertEqual(
            SettingsCategory.allCases,
            [.support, .playback, .channels, .servers, .about]
        )
    }

    func testPinnedAndUnpinnedCoverEveryTab() {
        XCTAssertEqual(SettingsCategory.pinned, [.support])
        XCTAssertEqual(SettingsCategory.pinned + SettingsCategory.unpinned, SettingsCategory.allCases)
    }
}
