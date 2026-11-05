import XCTest
@testable import JFTV

/// Tests for "pick the highest-quality version" (Change: prefer best media instead of the
/// first). Mirrors the decode-based style of JellyfinAPITests.
final class VersionPickerTests: XCTestCase {

    // MARK: - Jellyfin

    private func decodeJellyfin(_ json: String) throws -> JellyfinItem {
        try JSONDecoder().decode(JellyfinItem.self, from: Data(json.utf8))
    }
    private func jfService() -> JellyfinAPIService {
        JellyfinAPIService(serverURL: "http://jelly.local:8096", accessToken: "TKN", userId: "u", serverID: "s")
    }

    func testJellyfinPicksHighestBitrateSource() throws {
        let item = try decodeJellyfin("""
        { "Id": "m1", "Name": "Heat", "RunTimeTicks": 60000000000,
          "MediaSources": [
            { "Id": "sd",  "Container": "mp4", "Bitrate": 4000000,  "MediaStreams": [ {"Type":"Video","Codec":"h264","Height":1080} ] },
            { "Id": "uhd", "Container": "mkv", "Bitrate": 20000000, "MediaStreams": [ {"Type":"Video","Codec":"hevc","Height":2160} ] }
          ] }
        """)
        let mapped = try XCTUnwrap(jfService().parseMovieItem(item, isMusicSection: false))
        XCTAssertEqual(mapped.partKey, "uhd")   // MediaSourceId of the chosen high-bitrate source
        XCTAssertEqual(mapped.bitrate, 20000)   // bps -> kbps
        XCTAssertEqual(mapped.container, "mkv")
        XCTAssertEqual(mapped.videoCodec, "hevc")
    }

    func testJellyfinTieBreaksByHeight() throws {
        let item = try decodeJellyfin("""
        { "Id":"m","Name":"X","MediaSources":[
          {"Id":"a","Bitrate":5000000,"MediaStreams":[{"Type":"Video","Height":720}]},
          {"Id":"b","Bitrate":5000000,"MediaStreams":[{"Type":"Video","Height":1080}]}
        ]}
        """)
        XCTAssertEqual(JellyfinItem.bestMediaSource(item.MediaSources)?.Id, "b")
    }

    func testJellyfinFallsBackToFirstWhenNoBitrate() throws {
        let item = try decodeJellyfin("""
        { "Id":"m","Name":"X","MediaSources":[
          {"Id":"a","MediaStreams":[{"Type":"Video","Height":480}]},
          {"Id":"b","MediaStreams":[{"Type":"Video","Height":1080}]}
        ]}
        """)
        XCTAssertEqual(JellyfinItem.bestMediaSource(item.MediaSources)?.Id, "a")
    }
}
