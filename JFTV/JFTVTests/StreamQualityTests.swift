import XCTest
@testable import JFTV

final class StreamQualityTests: XCTestCase {

    // MARK: - Quality tiers

    /// Auto must reach 4K so users on fast connections aren't capped; slow ones are
    /// protected by the app's own starvation ladder, not by a low ceiling.
    func testAutoReaches4K() {
        XCTAssertEqual(StreamQuality.auto.width, 3840)
        XCTAssertEqual(StreamQuality.auto.height, 2160)
        XCTAssertEqual(StreamQuality.auto.maxBitrateKbps, 40_000)
    }

    /// Direct play has no adaptive fallback, so auto's ceiling there stays well below
    /// its transcode ceiling.
    func testAutoDirectPlayCeilingIsConservative() {
        XCTAssertLessThan(
            StreamQuality.auto.remoteDirectPlayCeilingKbps,
            StreamQuality.auto.maxBitrateKbps
        )
    }

    func testMaximumDoesNotCapDirectPlay() {
        XCTAssertEqual(StreamQuality.maximum.remoteDirectPlayCeilingKbps, .max)
    }

    func testTiersDescendMonotonically() {
        let ordered: [StreamQuality] = [.maximum, .high, .medium, .low]
        for (a, b) in zip(ordered, ordered.dropFirst()) {
            XCTAssertGreaterThan(a.maxBitrateKbps, b.maxBitrateKbps, "\(a) should exceed \(b)")
            XCTAssertGreaterThanOrEqual(a.width, b.width, "\(a) should be at least \(b)")
        }
    }

    func testPersistenceRoundTrip() {
        let original = StreamQuality.current
        defer { StreamQuality.current = original }

        StreamQuality.current = .low
        XCTAssertEqual(StreamQuality.current, .low)
        StreamQuality.current = .high
        XCTAssertEqual(StreamQuality.current, .high)
    }
}
