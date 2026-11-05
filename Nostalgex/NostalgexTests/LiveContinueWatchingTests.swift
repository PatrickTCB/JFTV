import XCTest
@testable import Nostalgex

/// Runs the real `PlaybackTracker` and `JellyfinAPIService` against a real Jellyfin server
/// and checks Resume is left exactly as it was. Skipped unless these are set
/// (xcodebuild passes `TEST_RUNNER_`-prefixed variables through to the test process):
///
///   TEST_RUNNER_NOSTALGEX_LIVE_MS_URL, _MS_TOKEN, _MS_USER
///   TEST_RUNNER_NOSTALGEX_LIVE_MS_ITEM   an unplayed film with no resume point
///
/// It writes to that server, and puts it back afterwards.
@MainActor
final class LiveContinueWatchingTests: XCTestCase {

    // MARK: - Jellyfin
    //
    //   TEST_RUNNER_NOSTALGEX_LIVE_MS_URL, _MS_TOKEN, _MS_USER
    //   TEST_RUNNER_NOSTALGEX_LIVE_MS_ITEM   an unplayed film with no resume point

    private struct MediaServerLive {
        let reporter: any WatchActivityReporting
        let url: String
        let token: String
        let user: String
        let itemId: String
    }

    private func mediaServerLive() throws -> MediaServerLive {
        let env = ProcessInfo.processInfo.environment
        guard let url = env["NOSTALGEX_LIVE_MS_URL"],
              let token = env["NOSTALGEX_LIVE_MS_TOKEN"], let user = env["NOSTALGEX_LIVE_MS_USER"],
              let itemId = env["NOSTALGEX_LIVE_MS_ITEM"] else {
            throw XCTSkip("No live Jellyfin server configured")
        }
        let reporter: any WatchActivityReporting = JellyfinAPIService(serverURL: url, accessToken: token, userId: user)
        return MediaServerLive(reporter: reporter, url: url, token: token, user: user, itemId: itemId)
    }

    private struct UserDataSnapshot: Decodable, Equatable {
        let PlaybackPositionTicks: Int?
        let PlayCount: Int?
        let Played: Bool?
        let LastPlayedDate: String?
    }

    private func msGet(_ live: MediaServerLive, _ path: String) async throws -> Data {
        var c = try XCTUnwrap(URLComponents(string: "\(live.url)\(path)"))
        c.queryItems = [.init(name: "Recursive", value: "true"),
                        .init(name: "MediaTypes", value: "Video"), .init(name: "Limit", value: "200")]
        var req = URLRequest(url: try XCTUnwrap(c.url))
        // Jellyfin 10.11+ refuses api_key in the query; the header works on both servers.
        req.setValue(JellyfinAPIService.authorizationHeader(deviceID: "nostalgex-live-test", token: live.token),
                     forHTTPHeaderField: "Authorization")
        let response = await URLSessionReportTransport.shared.send(req)
        let (status, body) = try XCTUnwrap(response)
        XCTAssertEqual(status, 200, path)
        return body
    }

    private func msUserData(_ live: MediaServerLive) async throws -> UserDataSnapshot {
        struct Item: Decodable { let UserData: UserDataSnapshot }
        return try JSONDecoder().decode(Item.self, from: try await msGet(live, "/Users/\(live.user)/Items/\(live.itemId)")).UserData
    }

    private func msMinutes(_ live: MediaServerLive) async throws -> Int {
        struct Item: Decodable { let RunTimeTicks: Int? }
        let ticks = try JSONDecoder().decode(Item.self, from: try await msGet(live, "/Users/\(live.user)/Items/\(live.itemId)")).RunTimeTicks
        return max(1, (ticks ?? 0) / 600_000_000)
    }

    private func msResume(_ live: MediaServerLive) async throws -> [String] {
        struct Page: Decodable { struct I: Decodable { let Id: String }; let Items: [I] }
        return try JSONDecoder().decode(Page.self, from: try await msGet(live, "/Users/\(live.user)/Items/Resume")).Items.map(\.Id)
    }

    private func msWatch(_ live: MediaServerLive, minutes: Int, seconds: Int, seekOffset: Int,
                         beforeStop: () async throws -> Void) async rethrows -> Bool {
        var clock = Date()
        let queue = ReportQueue()
        let item = PlexMediaItem(
            id: live.itemId, title: "live", artist: nil, episodeTitle: nil, seTag: nil, summary: "",
            year: nil, originallyAvailableAt: nil, contentRating: nil, duration: minutes,
            ratingKey: live.itemId, partKey: nil, container: nil, videoCodec: nil, audioCodec: nil,
            videoProfile: nil, bitrate: nil, genres: [], rating: 0, userRating: 0, type: .movie,
            thumb: nil, art: nil, viewCount: 0, addedAt: 0, studio: nil, tmdbID: nil, imdbID: nil,
            librarySource: .movie
        )
        let tracker = PlaybackTracker(item: item, seekOffset: seekOffset,
                                      watchReporter: live.reporter, showNowPlaying: true, markWatched: true, queue: queue, now: { clock })
        tracker.onPlaybackReady()
        for _ in 0..<(seconds / 10) {
            clock += 10
            tracker.timelineTickForTesting()
        }
        await queue.drain()
        try await beforeStop()
        tracker.stop()
        await queue.drain()
        return tracker.scrobbled
    }

    func testMediaServerSurfAndWatchLeaveResumeAlone() async throws {
        let live = try mediaServerLive()
        let resumeBefore = try await msResume(live)
        let before = try await msUserData(live)
        XCTAssertEqual(before.PlayCount ?? 0, 0, "pick an unplayed item")
        let minutes = try await msMinutes(live)

        // Surf: tune in 10 minutes in, two minutes of pulses.
        let surfCounted = try await msWatch(live, minutes: minutes, seconds: 120, seekOffset: 600) {
            let during = try await msUserData(live)
            print("[Live] ms surf during=\(during)")
            XCTAssertGreaterThan(during.PlaybackPositionTicks ?? 0, 0, "the reports really land")
        }
        XCTAssertFalse(surfCounted)
        let afterSurf = try await msUserData(live)
        let resumeAfterSurf = try await msResume(live)
        print("[Live] ms surf before=\(before) after=\(afterSurf) resume \(resumeBefore.count) -> \(resumeAfterSurf.count)")
        XCTAssertEqual(afterSurf, before)
        XCTAssertEqual(resumeAfterSurf, resumeBefore)

        // A real watch: 80% from the start counts once and leaves no resume point.
        let counted = try await msWatch(live, minutes: minutes, seconds: minutes * 60 * 8 / 10, seekOffset: 0) {}
        XCTAssertTrue(counted)
        let watched = try await msUserData(live)
        let resumeAfterWatch = try await msResume(live)
        print("[Live] ms watch after=\(watched) resume \(resumeAfterWatch.count)")
        XCTAssertEqual(watched.Played, true)
        XCTAssertEqual(watched.PlayCount, (before.PlayCount ?? 0) + 1)
        XCTAssertEqual(watched.PlaybackPositionTicks ?? 0, 0)
        XCTAssertEqual(resumeAfterWatch, resumeBefore)

        // Put the server back: the item was unplayed before the test.
        let guardian = MediaServerWatchStateGuard(
            serverURL: live.url,
            authorization: JellyfinAPIService.authorizationHeader(deviceID: "nostalgex-live-test", token: live.token),
            userId: live.user,
            transport: URLSessionReportTransport.shared)
        let reset = try XCTUnwrap(guardian.request(for: .markUnplayed, itemId: live.itemId))
        _ = await URLSessionReportTransport.shared.send(reset)
        let restored = try await msUserData(live)
        print("[Live] ms restored=\(restored)")
        XCTAssertEqual(restored, before)
    }
}
