import Foundation
@testable import Nostalgex

extension AppState {
    /// Test seam standing in for the real Jellyfin auth commit path
    /// (`completeJellyfinAuth`, which is private and needs a canned `AuthResult`).
    /// Establishes a signed-in Jellyfin session over the given servers so a harness can
    /// drive library loads, schedules and snapshots without a network. Mirrors what the
    /// old `completePlexSignIn` did for the harnesses, minus the Plex backend.
    func completeSignIn(token authToken: String, servers: [ServerRef]) {
        token = authToken
        backendKind = .jellyfin
        setSelectedServers(servers)
        saveCredentials()
    }
}
