import XCTest
@testable import Nostalgex

/// Report Playback must never leave a program in Continue Watching. These drive the real
/// `MediaServerWatchStateGuard` request builders through a recording transport, so the
/// exact calls a watch makes are checked in milliseconds. The live-server version is
/// `LiveContinueWatchingTests`; numbers in docs/watch-state-guard.md.
@MainActor
final class WatchStateGuardTests: XCTestCase {

    // MARK: - Fakes

    final class RecordingTransport: ReportTransport, @unchecked Sendable {
        struct Call {
            let method: String
            let path: String
            let query: [String: String]
            let body: [String: Any]?
        }

        private let lock = NSLock()
        private var recorded: [Call] = []
        /// "METHOD /path" -> responses served in order; the last one repeats.
        private var scripted: [String: [(Int, String)]] = [:]

        func respond(_ route: String, _ status: Int, _ body: String) {
            lock.lock(); defer { lock.unlock() }
            scripted[route, default: []].append((status, body))
        }

        var calls: [Call] {
            lock.lock(); defer { lock.unlock() }
            return recorded
        }

        func send(_ request: URLRequest) async -> (status: Int, body: Data)? {
            guard let url = request.url,
                  let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
            var query: [String: String] = [:]
            comps.queryItems?.forEach { query[$0.name] = $0.value ?? "" }
            let body = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            let method = request.httpMethod ?? "GET"
            lock.lock(); defer { lock.unlock() }
            recorded.append(Call(method: method, path: comps.path, query: query, body: body))
            let route = "\(method) \(comps.path)"
            guard var queue = scripted[route], !queue.isEmpty else { return (200, Data()) }
            let next = queue.count > 1 ? queue.removeFirst() : queue[0]
            scripted[route] = queue
            return (next.0, Data(next.1.utf8))
        }
    }

    private func item(rk: String, minutes: Int, type: MediaType) -> PlexMediaItem {
        PlexMediaItem(
            id: rk, title: "Item \(rk)", artist: nil, episodeTitle: nil, seTag: nil,
            summary: "", year: 1999, originallyAvailableAt: nil, contentRating: nil,
            duration: minutes, ratingKey: rk, partKey: "/library/parts/\(rk)/file.mkv",
            container: "mkv", videoCodec: nil, audioCodec: nil, videoProfile: nil, bitrate: nil,
            genres: [], rating: 0, userRating: 0, type: type, thumb: nil, art: nil,
            viewCount: 0, addedAt: 0, studio: nil, tmdbID: nil, imdbID: nil,
            librarySource: type == .episode ? .tv : .movie
        )
    }

    func testPulseBackoffGrowsAndCaps() {
        let backoff = PulseBackoff()
        var skipped: [Int] = []
        for _ in 0..<8 {
            backoff.record(success: false)
            var n = 0
            while !backoff.allowPulse() { n += 1 }
            skipped.append(n)
        }
        XCTAssertEqual(skipped, [1, 2, 4, 8, 16, 30, 30, 30])
        backoff.record(success: true)
        XCTAssertTrue(backoff.allowPulse())
    }

    // MARK: - Jellyfin guard

    private func mediaServerGuard(_ transport: RecordingTransport) -> MediaServerWatchStateGuard {
        MediaServerWatchStateGuard(serverURL: "http://jf.test", authorization: "MediaBrowser Token=\"t\"",
                                   userId: "u1", transport: transport)
    }

    func testMediaServerCapture_readsUserData() async {
        let transport = RecordingTransport()
        transport.respond("GET /Users/u1/Items/i1", 200,
                          "{\"UserData\":{\"PlaybackPositionTicks\":6000000000,\"PlayCount\":2,\"Played\":true,\"LastPlayedDate\":\"2026-10-11T18:03:04.0000000Z\"}}")
        let prior = await mediaServerGuard(transport).captureWatchState(for: item(rk: "i1", minutes: 90, type: .movie))
        XCTAssertEqual(prior, PriorWatchState(resumePosition: 6_000_000_000, playCount: 2, played: true,
                                              lastPlayedDate: "2026-10-11T18:03:04.0000000Z"))
    }

    func testMediaServerRestore_untouchedItemIsMarkedUnplayed() async {
        let transport = RecordingTransport()
        await mediaServerGuard(transport).restoreWatchState(
            for: item(rk: "i1", minutes: 90, type: .movie),
            prior: PriorWatchState(resumePosition: 0, playCount: 0, played: false), countedWatch: false)
        XCTAssertEqual(transport.calls.map { "\($0.method) \($0.path)" }, ["DELETE /Users/u1/PlayedItems/i1"])
    }

    func testMediaServerRestore_writesPriorUserDataBack() async {
        let transport = RecordingTransport()
        await mediaServerGuard(transport).restoreWatchState(
            for: item(rk: "i1", minutes: 90, type: .movie),
            prior: PriorWatchState(resumePosition: 6_000_000_000, playCount: 1, played: false, lastPlayedDate: "2026-10-01T00:00:00Z"),
            countedWatch: false)
        let call = transport.calls.first
        XCTAssertEqual(transport.calls.count, 1)
        XCTAssertEqual(call?.method, "POST")
        XCTAssertEqual(call?.path, "/Users/u1/Items/i1/UserData")
        XCTAssertEqual(call?.body?["PlaybackPositionTicks"] as? Int, 6_000_000_000)
        XCTAssertEqual(call?.body?["PlayCount"] as? Int, 1)
        XCTAssertEqual(call?.body?["Played"] as? Bool, false)
        XCTAssertEqual(call?.body?["LastPlayedDate"] as? String, "2026-10-01T00:00:00Z")
    }

    func testMediaServerRestore_countedWatchIsPlayedOnceWithNoResumePoint() async {
        let transport = RecordingTransport()
        await mediaServerGuard(transport).restoreWatchState(
            for: item(rk: "i1", minutes: 90, type: .movie),
            prior: PriorWatchState(resumePosition: 0, playCount: 0, played: false), countedWatch: true)
        let body = transport.calls.first?.body
        XCTAssertEqual(body?["PlaybackPositionTicks"] as? Int, 0)
        XCTAssertEqual(body?["PlayCount"] as? Int, 1)
        XCTAssertEqual(body?["Played"] as? Bool, true)
    }

    func testMediaServerRestoreWithoutPriorNeverWritesAResumeReset() async {
        let transport = RecordingTransport()
        for counted in [false, true] {
            await mediaServerGuard(transport).restoreWatchState(
                for: item(rk: "i1", minutes: 90, type: .movie), prior: nil, countedWatch: counted)
        }
        XCTAssertTrue(transport.calls.isEmpty)
    }

    // MARK: - Shared decision table (web tuner reads the same file)

    private struct Golden: Decodable {
        struct Prior: Decodable {
            let resumePosition: Int
            let playCount: Int
            let played: Bool
            let lastPlayedDate: String?
            let showKey: String?
            let showInContinueWatching: Bool
        }
        struct Case: Decodable {
            let name: String
            let backend: String
            let counted: Bool
            let prior: Prior?
            let steps: [String]
        }
        let cases: [Case]
    }

    func testCleanupPlanMatchesSharedGoldenVectors() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("scripts/watch-cleanup-golden.json"))
        let golden = try JSONDecoder().decode(Golden.self, from: data)
        XCTAssertGreaterThan(golden.cases.count, 10)
        // The golden file still carries the retired Plex rows for the web tuner's history;
        // the app only implements the media-server plan now.
        let mediaServerCases = golden.cases.filter { $0.backend != "plex" }
        XCTAssertFalse(mediaServerCases.isEmpty)
        for c in mediaServerCases {
            let prior = c.prior.map {
                PriorWatchState(resumePosition: $0.resumePosition, playCount: $0.playCount, played: $0.played,
                                lastPlayedDate: $0.lastPlayedDate, showKey: $0.showKey,
                                showInContinueWatching: $0.showInContinueWatching)
            }
            let steps = WatchCleanupPlan.mediaServer(prior: prior, countedWatch: c.counted)
            XCTAssertEqual(steps.map(\.goldenDescription), c.steps, c.name)
        }
    }
}
