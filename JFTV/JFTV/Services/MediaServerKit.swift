import Foundation

/// Backend-agnostic helpers shared by the media server clients.
///
/// These used to live as static members on the Plex client, which every other
/// backend borrowed from. Now that Jellyfin is the only backend they live here,
/// under a neutral name, so nothing has to reach into a service it isn't using.
enum MediaServerKit {
    /// Stable per-install client identifier, sent to the server on every request so
    /// it can tell this device apart. Persisted under a legacy key name.
    static var clientID: String {
        if let id = AppDefaults.standard.string(forKey: "plex90_client_id") { return id }
        let id = UUID().uuidString
        AppDefaults.standard.set(id, forKey: "plex90_client_id")
        return id
    }

    /// Unique item id across servers. Item ids are only unique within one server, so
    /// prefix with the server id to avoid collisions in pools and lookups. With no
    /// server id (demo) the raw id is used, matching pre-multi-server snapshots.
    static func compositeID(serverID: String, ratingKey: String) -> String {
        serverID.isEmpty ? ratingKey : "\(serverID):\(ratingKey)"
    }

    /// Per-show batch progress during a TV section scan, so the loading view can show
    /// `60/130 shows` granularity instead of waiting on the whole section.
    typealias ShowProgress = @Sendable (_ showsCompleted: Int, _ totalShows: Int, _ episodesSoFar: Int) -> Void

    /// A supported codec name is not the whole question; see `CodecSupport.canDecodeVideo`.
    /// AVPlayer opens HEVC in MP4 only when the sample entry is `hvc1`. Most x265 rips
    /// carry `hev1` instead, and the server metadata does not say which; the file plays
    /// audio over a black screen. A server remux writes a playable stream and copies
    /// video, so it costs a session, not an encode. `.mov` is Apple's own container and
    /// is always `hvc1`.
    static func needsServerRemux(container: String?, videoCodec: String?) -> Bool {
        guard let container = container?.lowercased(), let codec = videoCodec?.lowercased() else { return false }
        return codec == "hevc" && (container == "mp4" || container == "m4v")
    }

    /// Parse a Dolby Vision profile out of a Jellyfin `videoExtendedSubType`
    /// ("doviprofile7" -> 7). Anything else ("Hdr10", "None", missing, one digit) is
    /// nil, an unknown profile, which keeps the item on channels.
    static func doviProfile(extendedVideoSubType value: String?) -> Int? {
        guard let value else { return nil }
        let prefix = "doviprofile"
        let lower = value.lowercased()
        guard lower.hasPrefix(prefix) else { return nil }
        let digits = lower.dropFirst(prefix.count)
        guard digits.count >= 2, digits.allSatisfy({ ("0"..."9").contains($0) }) else { return nil }
        return Int(digits.dropLast())
    }

    /// The shared error type across the server clients.
    enum APIError: Error, Equatable {
        case unauthorized
        case invalidResponse
        /// The server was listed, but never passed reachability + auth validation
        /// within the timeout. Distinct from `.unauthorized` so the UI can show an
        /// accurate "couldn't reach any server" message instead of "session expired".
        case noReachableServer
        /// Non-2xx from the server or an intermediate proxy (body is often HTML).
        case httpFailure(statusCode: Int)
        /// The server usually returns JSON; `<` typically means an HTML error page.
        case receivedMarkupInsteadOfJSON(statusCode: Int)
    }
}
