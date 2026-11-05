import XCTest
@testable import Nostalgex

/// The rule these lock down: a sign-in, once made, is never lost by the app's own doing.
@MainActor
final class SessionDurabilityTests: XCTestCase {
    private final class InMemoryStore: Nostalgex.CredentialStoring, @unchecked Sendable {
        var values: [String: String] = [:]
        @discardableResult
        func save(key: String, value: String) -> Bool { values[key] = value; return true }
        func load(key: String) -> String? { values[key] }
        func delete(key: String) { values[key] = nil }
    }

    // MARK: - Keychain mirror

    // The simulator keychain always refuses (-34018), so a value that still round-trips
    // here proves the container mirror carries the sign-in when the keychain cannot.
    func testCredentialSurvivesWhenTheKeychainRefuses() {
        let key = "test_mirror_\(UUID().uuidString)"
        defer { KeychainService.delete(key: key) }

        XCTAssertTrue(KeychainService.save(key: key, value: "tok-1"))
        XCTAssertEqual(KeychainService.load(key: key), "tok-1")

        XCTAssertTrue(KeychainService.save(key: key, value: "tok-2"))
        XCTAssertEqual(KeychainService.load(key: key), "tok-2")

        KeychainService.delete(key: key)
        XCTAssertNil(KeychainService.load(key: key))
    }

    // MARK: - Token-only sign-in

    func testJellyfinNeedsAServerURL() {
        let state = AppState(credentialStore: InMemoryStore())
        state.backendKind = .jellyfin
        state.token = "abc"
        state.serverURL = ""
        state.selectedServers = []
        XCTAssertFalse(state.hasCredentials)
        state.serverURL = "https://jf.local"
        XCTAssertTrue(state.hasCredentials)
    }

    func testNoTokenIsNotSignedIn() {
        let state = AppState(credentialStore: InMemoryStore())
        state.backendKind = .jellyfin
        state.token = ""
        state.serverURL = "https://jf.local"
        XCTAssertFalse(state.hasCredentials)
    }

    // MARK: - A sign-in is actually written to disk

    // Regression: from 7fc1629 (2026-05-29) the sign-in flow persisted the server list but
    // not the account token, so a fresh sign-in never survived a relaunch.
    func testSignInPersistsTokenAndServers() {
        let store = InMemoryStore()
        let state = AppState(credentialStore: store)
        let server = AppState.ServerRef(machineIdentifier: "m1", name: "Den", baseURL: "https://jf.local:8096", owned: true, token: "srv")

        state.completeSignIn(token: "account-token", servers: [server])

        XCTAssertEqual(store.values["plex_token"], "account-token")
        XCTAssertNotNil(store.values[AppState.serversKey])

        let relaunched = AppState(credentialStore: store)
        relaunched.loadCredentials()
        XCTAssertEqual(relaunched.token, "account-token")
        XCTAssertEqual(relaunched.selectedServers.map(\.machineIdentifier), ["m1"])
        XCTAssertTrue(relaunched.hasCredentials)
    }

    // MARK: - 401 never signs out

    func testUnauthorizedMessagesKeepTheSessionAndPointAtDisconnect() {
        for validity in [TokenValidity.valid, .invalid, .unknown] {
            let msg = AppState.unauthorizedLoadMessage(tokenValidity: validity, backend: .jellyfin)
            XCTAssertFalse(msg.lowercased().contains("session expired"), "\(validity): a 401 must not declare the sign-in dead")
            XCTAssertFalse(msg.lowercased().contains("signed out"), "\(validity): the app never signs out on a 401")
        }
        // Both failure wordings say the saved sign-in survived, and name Disconnect as
        // the viewer's own way to start fresh (only after that may they sign in again).
        for validity in [TokenValidity.invalid, .unknown] {
            let msg = AppState.unauthorizedLoadMessage(tokenValidity: validity, backend: .jellyfin)
            XCTAssertTrue(msg.contains("kept"), "\(validity): \(msg)")
            XCTAssertTrue(msg.contains("Disconnect"), "\(validity): \(msg)")
        }
    }

    // MARK: - Error copy names the server the user actually connected to

    /// A Jellyfin user whose scan fails used to be told to check Plex: the shared
    /// `MediaServerKit.APIError` carried Plex-only wording for every backend. Issue #6 was
    /// reported with "Plex (or your network path) returned HTTP 404" on an Emby server.
    func testErrorCopyNamesTheConnectedBackendAndNeverTheWrongOne() {
        let cases: [MediaServerKit.APIError] = [
            .unauthorized,
            .invalidResponse,
            .noReachableServer,
            .httpFailure(statusCode: 404),
            .receivedMarkupInsteadOfJSON(statusCode: 200)
        ]

        for backend in [MediaBackendKind.jellyfin] {
            for error in cases {
                for fresh in [true, false] {
                    let msg = AppState.userFacingServerError(
                        error, justAuthenticated: fresh, backend: backend
                    )
                    XCTAssertFalse(
                        msg.contains("Plex"),
                        "\(backend) / \(error) / justAuthenticated=\(fresh) names Plex: \(msg)"
                    )
                }
            }
        }

        // The backend is named where there is a server to name. "Session expired" has no
        // server in it by design, so it is the one message that stays generic.
        let jellyfin = AppState.userFacingServerError(
            .httpFailure(statusCode: 404), backend: .jellyfin
        )
        XCTAssertTrue(jellyfin.contains("Jellyfin"), jellyfin)
        XCTAssertTrue(jellyfin.contains("404"), jellyfin)
    }
}
