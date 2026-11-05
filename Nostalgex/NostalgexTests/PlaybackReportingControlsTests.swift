import XCTest
@testable import Nostalgex

@MainActor
final class PlaybackReportingControlsTests: XCTestCase {
    typealias Recorder = WatchStateGuardTests.RecordingTransport
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)

    private func item(type: MediaType = .movie, minutes: Int = 1) -> PlexMediaItem {
        PlexMediaItem(id: "42", title: "Synthetic program", artist: nil, episodeTitle: nil, seTag: nil,
                      summary: "", year: 1999, originallyAvailableAt: nil, contentRating: nil,
                      duration: minutes, ratingKey: "42", partKey: "source", container: "mp4",
                      videoCodec: nil, audioCodec: nil, videoProfile: nil, bitrate: nil, genres: [],
                      rating: 0, userRating: 0, type: type, thumb: nil, art: nil, viewCount: 0,
                      addedAt: 0, studio: nil, tmdbID: nil, imdbID: nil, librarySource: .movie)
    }
    private func play(_ tracker: PlaybackTracker, seconds: Int) {
        tracker.onPlaybackReady()
        for _ in 0..<(seconds / 10) { clock += 10; tracker.timelineTickForTesting() }
    }

    private final class WatchReporter: WatchActivityReporting, @unchecked Sendable {
        let transport: any ReportTransport
        let watchStateGuard: any WatchStateGuarding
        init(_ transport: any ReportTransport) {
            self.transport = transport
            self.watchStateGuard = MediaServerWatchStateGuard(serverURL: "http://jf.test", authorization: "synthetic",
                                                             userId: "user", transport: transport)
        }
        func reportWatchActivity(itemId: String, mediaSourceId: String, playSessionId: String,
                                 positionTicks: Int, event: MediaServerPlaybackReport.Event) async -> Bool {
            var req = URLRequest(url: URL(string: "http://jf.test" + event.path)!)
            req.httpMethod = "POST"
            req.httpBody = try? JSONSerialization.data(withJSONObject: ["PositionTicks": positionTicks])
            return await transport.send(req)?.status == 200
        }
        func markWatched(itemId: String) async {
            var req = URLRequest(url: URL(string: "http://jf.test/Users/user/PlayedItems/" + itemId)!)
            req.httpMethod = "POST"
            _ = await transport.send(req)
        }
    }
    private func mediaServer(_ transport: any ReportTransport, queue: ReportQueue, show: Bool, mark: Bool,
                             scope: PlaybackReportingControlScope? = nil) -> PlaybackTracker {
        PlaybackTracker(item: item(), seekOffset: 0, watchReporter: WatchReporter(transport),
                        showNowPlaying: show, markWatched: mark, controlScope: scope, queue: queue,
                        now: { [unowned self] in self.clock })
    }
    private func knownPrior(_ transport: Recorder) {
        transport.respond("GET /Users/user/Items/42", 200,
                          "{\"UserData\":{\"PlaybackPositionTicks\":123400,\"PlayCount\":3,\"Played\":true,\"LastPlayedDate\":\"2026-10-01T00:00:00Z\"}}")
    }

    func testTrackerDefaultsOffEvenWithARealBackendAvailable() async {
        let transport = Recorder(), queue = ReportQueue()
        let tracker = PlaybackTracker(item: item(), seekOffset: 0, watchReporter: WatchReporter(transport),
                                      queue: queue, now: { [unowned self] in self.clock })
        play(tracker, seconds: 50)
        tracker.stop()
        await queue.drain()
        XCTAssertTrue(transport.calls.isEmpty)
        XCTAssertEqual(tracker.watchedSecondsSoFar, 50, accuracy: 0.01)
    }

    func testJellyfinAllFourModesRestoreKnownPriorOrOneCountedWatch() async {
        for show in [false, true] {
            for mark in [false, true] {
                let transport = Recorder(), queue = ReportQueue()
                knownPrior(transport)
                let tracker = mediaServer(transport, queue: queue, show: show, mark: mark)
                play(tracker, seconds: 50)
                tracker.stop()
                await queue.drain()
                let calls = transport.calls
                XCTAssertEqual(calls.contains { $0.path.hasPrefix("/Sessions/Playing") }, show)
                XCTAssertEqual(calls.filter { $0.path == "/Users/user/PlayedItems/42" && $0.method == "POST" }.count, mark ? 1 : 0)
                let restore = calls.last { $0.path == "/Users/user/Items/42/UserData" }
                if show || mark {
                    XCTAssertEqual(restore?.body?["PlayCount"] as? Int, mark ? 4 : 3)
                    XCTAssertEqual(restore?.body?["PlaybackPositionTicks"] as? Int, mark ? 0 : 123400)
                } else { XCTAssertTrue(calls.isEmpty) }
            }
        }
    }

    func testMediaServerMarkOnlyPastNinetyPercentStillExplicitlyMarks() async {
        let transport = Recorder(), queue = ReportQueue()
        knownPrior(transport)
        let tracker = mediaServer(transport, queue: queue, show: false, mark: true)
        tracker.onPlaybackReady()
        clock += 55
        tracker.stop()
        await queue.drain()
        XCTAssertFalse(transport.calls.contains { $0.path.hasPrefix("/Sessions/Playing") })
        XCTAssertEqual(transport.calls.filter { $0.path == "/Users/user/PlayedItems/42" && $0.method == "POST" }.count, 1)
    }

    func testMediaServerNowPlayingOnlyCapsStopAndRestoresWithoutExplicitMark() async {
        let transport = Recorder(), queue = ReportQueue()
        knownPrior(transport)
        let tracker = mediaServer(transport, queue: queue, show: true, mark: false)
        tracker.onPlaybackReady()
        clock += 59
        tracker.stop()
        await queue.drain()
        let stopped = transport.calls.first { $0.path == "/Sessions/Playing/Stopped" }
        XCTAssertEqual(stopped?.body?["PositionTicks"] as? Int, 534_000_000)
        XCTAssertFalse(transport.calls.contains { $0.path == "/Users/user/PlayedItems/42" })
        XCTAssertEqual(transport.calls.last?.body?["PlayCount"] as? Int, 3)
    }

    func testMediaServerUnreadablePriorSkipsEveryReportingModeWithoutChangingAccounting() async {
        for show in [false, true] {
            for mark in [false, true] {
                let transport = Recorder(), queue = ReportQueue()
                transport.respond("GET /Users/user/Items/42", 500, "")
                let tracker = mediaServer(transport, queue: queue, show: show, mark: mark)
                play(tracker, seconds: 50)
                tracker.stop()
                await queue.drain()
                XCTAssertTrue(transport.calls.allSatisfy { $0.method == "GET" },
                              "unreadable state must not cause a report, watched write or zero-position cleanup")
                XCTAssertEqual(transport.calls.count, show || mark ? 1 : 0)
                XCTAssertEqual(tracker.watchedSecondsSoFar, 50, accuracy: 0.01)
            }
        }
    }

    private actor Blocker {
        private var open = false
        private var holding = false
        private var releaseWaiter: CheckedContinuation<Void, Never>?
        private var entryWaiter: CheckedContinuation<Void, Never>?
        func hold() async {
            holding = true
            entryWaiter?.resume(); entryWaiter = nil
            if open { return }
            await withCheckedContinuation { releaseWaiter = $0 }
        }
        func waitUntilHolding() async {
            if holding { return }
            await withCheckedContinuation { entryWaiter = $0 }
        }
        func release() { open = true; releaseWaiter?.resume(); releaseWaiter = nil }
    }

    func testDisableDropsBlockedActivityAndScrobbleWithoutInventingCountedCleanup() async {
        let transport = Recorder(), queue = ReportQueue(), blocker = Blocker()
        knownPrior(transport)
        queue.enqueue { await blocker.hold() }
        let tracker = mediaServer(transport, queue: queue, show: true, mark: true)
        play(tracker, seconds: 50)
        tracker.updateReporting(showNowPlaying: false, markWatched: false)
        await blocker.release()
        await queue.drain()
        XCTAssertTrue(transport.calls.isEmpty)
        XCTAssertFalse(tracker.scrobbled)
        clock += 10
        tracker.timelineTickForTesting()
        XCTAssertEqual(tracker.watchedSecondsSoFar, 60, accuracy: 0.01, "analytics clock survives toggles")
        tracker.stop()
        await queue.drain()
    }

    func testOffOnDoesNotReviveAnOldQueuedActivityOrMark() async {
        let transport = Recorder(), queue = ReportQueue(), blocker = Blocker()
        knownPrior(transport)
        queue.enqueue { await blocker.hold() }
        let tracker = mediaServer(transport, queue: queue, show: true, mark: true)
        play(tracker, seconds: 50)
        tracker.updateReporting(showNowPlaying: false, markWatched: false)
        tracker.updateReporting(showNowPlaying: true, markWatched: true)
        await blocker.release()
        await queue.drain()
        XCTAssertEqual(transport.calls.filter { $0.path.hasPrefix("/Sessions/Playing") }.map(\.path),
                       ["/Sessions/Playing"], "only the fresh activity after the toggle runs")
        XCTAssertFalse(transport.calls.contains { $0.path == "/Users/user/PlayedItems/42" }, "the old queued mark stayed revoked")
        tracker.timelineTickForTesting()
        tracker.stop()
        await queue.drain()
        XCTAssertEqual(transport.calls.filter { $0.path == "/Users/user/PlayedItems/42" }.count, 1)
        XCTAssertTrue(transport.calls.contains { $0.path == "/Sessions/Playing/Stopped" })
    }

    func testSharedScopeRevokesOutgoingChannelWritesAndMarks() async {
        let transport = Recorder(), queue = ReportQueue(), blocker = Blocker()
        let scope = PlaybackReportingControlScope(showNowPlaying: true, markWatched: true)
        queue.enqueue { await blocker.hold() }
        let outgoing = mediaServer(transport, queue: queue, show: true, mark: true, scope: scope)
        play(outgoing, seconds: 50)
        outgoing.stop()
        let current = mediaServer(transport, queue: queue, show: true, mark: true, scope: scope)
        current.onPlaybackReady()
        current.updateReporting(showNowPlaying: false, markWatched: false)
        await blocker.release()
        await queue.drain()
        XCTAssertTrue(transport.calls.isEmpty, "OFF also revokes work retained by the previous channel")
        XCTAssertFalse(scope.hasAttemptedReporting, "revoked queued writes do not request cleanup grace")
        current.stop()
        await queue.drain()
    }

    func testBackgroundGraceSurvivesAnOutgoingAttemptAndNewAllOffTracker() async {
        let transport = Recorder(), queue = ReportQueue(), blocker = Blocker()
        let scope = PlaybackReportingControlScope(showNowPlaying: true, markWatched: false)
        knownPrior(transport)
        queue.enqueue { await blocker.hold() }
        let outgoing = mediaServer(transport, queue: queue, show: true, mark: false, scope: scope)
        outgoing.onPlaybackReady()
        XCTAssertFalse(scope.hasAttemptedReporting, "queueing is not an attempt")
        await blocker.release()
        await queue.drain()
        XCTAssertTrue(scope.hasAttemptedReporting)
        outgoing.stop() // The final stop is queued and still needs suspension grace.
        let current = mediaServer(transport, queue: queue, show: false, mark: false, scope: scope)
        XCTAssertTrue(current.hasReportingWork, "the new tracker inherits outgoing cleanup work")
        await queue.drain()
        XCTAssertTrue(transport.calls.contains { $0.path == "/Sessions/Playing/Stopped" })
        current.stop()
        await queue.drain()
    }

    private final class HeldTransport: ReportTransport, @unchecked Sendable {
        let recorder = Recorder()
        let blocker = Blocker()
        private let lock = NSLock()
        private var held = false
        func send(_ request: URLRequest) async -> (status: Int, body: Data)? {
            let response = await recorder.send(request)
            let shouldHold = lock.withLock {
                guard !held, request.url?.path == "/Sessions/Playing" else { return false }
                held = true
                return true
            }
            if shouldHold { await blocker.hold() }
            return response
        }
    }

    func testInFlightSessionStillGetsItsFinalStopAfterDisable() async {
        let transport = HeldTransport(), queue = ReportQueue()
        knownPrior(transport.recorder)
        let tracker = mediaServer(transport, queue: queue, show: true, mark: false)
        tracker.onPlaybackReady()
        await transport.blocker.waitUntilHolding()
        clock += 10
        tracker.timelineTickForTesting()
        tracker.updateReporting(showNowPlaying: false, markWatched: false)
        await transport.blocker.release()
        await queue.drain()
        XCTAssertEqual(transport.recorder.calls.filter { $0.path.hasPrefix("/Sessions/Playing") }.map(\.path),
                       ["/Sessions/Playing", "/Sessions/Playing/Stopped"])
        tracker.stop()
        await queue.drain()
    }
}

final class PlaybackReportingMigrationTests: XCTestCase {
    func testDefaultsAndLegacyMigration() {
        let P = PlaybackReportingPreferences.self
        XCTAssertEqual(P.resolve(nowPlaying: nil, markWatched: nil, legacy: nil), P.init(showNowPlaying: false, markWatched: false))
        XCTAssertEqual(P.resolve(nowPlaying: nil, markWatched: nil, legacy: true), P.init(showNowPlaying: true, markWatched: true))
        XCTAssertEqual(P.resolve(nowPlaying: nil, markWatched: nil, legacy: false), P.init(showNowPlaying: false, markWatched: false))
        XCTAssertEqual(P.resolve(nowPlaying: false, markWatched: true, legacy: true), P.init(showNowPlaying: false, markWatched: true))
        XCTAssertEqual(P.resolve(nowPlaying: true, markWatched: false, legacy: true), P.init(showNowPlaying: true, markWatched: false))
        XCTAssertEqual(P.resolve(nowPlaying: nil, markWatched: nil, legacy: "true"), P.init(showNowPlaying: false, markWatched: false))
    }
    func testMigrationMaterializesLegacyOnceButDoesNotSeedFreshDefaults() {
        let name = "PlaybackReportingMigrationTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let P = PlaybackReportingPreferences.self
        _ = P.loadAndMigrate(from: defaults)
        XCTAssertNil(defaults.object(forKey: P.nowPlayingKey))
        XCTAssertNil(defaults.object(forKey: P.markWatchedKey))
        defaults.set(true, forKey: P.legacyKey)
        defaults.set(false, forKey: P.markWatchedKey)
        XCTAssertEqual(P.loadAndMigrate(from: defaults), P.init(showNowPlaying: true, markWatched: false))
        defaults.set(false, forKey: P.legacyKey)
        XCTAssertEqual(P.loadAndMigrate(from: defaults), P.init(showNowPlaying: true, markWatched: false))
    }
}
