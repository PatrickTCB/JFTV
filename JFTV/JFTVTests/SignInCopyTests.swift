import XCTest
@testable import JFTV

/// Sign-in messages have to point at things the screen actually has. "Code expired. Tap
/// Connect to try again." named a Connect button that no code screen has, and "tap"
/// is a touch word on a TV that's driven with a remote.
@MainActor
final class SignInCopyTests: XCTestCase {

    /// Lands on the Jellyfin password screen, which has USE QUICK CONNECT and the fields.
    func testQuickConnectExpiryNamesThatScreensButtons() {
        XCTAssertTrue(AppState.quickConnectCodeExpiredMessage.contains(SignInFlow.Copy.useQuickConnect))
        XCTAssertTrue(AppState.quickConnectCodeExpiredMessage.contains("password"))
    }

    private var everySignInLine: [String] {
        let urlErrors: [URLError.Code] = [.appTransportSecurityRequiresSecureConnection, .cannotFindHost, .cannotConnectToHost,
                                          .timedOut, .notConnectedToInternet, .serverCertificateUntrusted, .badServerResponse]
        let unreachable = urlErrors.map { AppState.serverUnreachableMessage(URLError($0), backend: "Jellyfin") }
            + [AppState.serverUnreachableMessage(NSError(domain: "x", code: 1), backend: "Jellyfin")]
        let quickConnectErrors: [Error] = [MediaServerKit.APIError.unauthorized, MediaServerKit.APIError.httpFailure(statusCode: 404),
                                           MediaServerKit.APIError.invalidResponse, URLError(.cannotConnectToHost)]
        let quickConnect = quickConnectErrors.map { AppState.quickConnectFailureMessage($0) }
        return unreachable + quickConnect
            + [AppState.quickConnectCodeExpiredMessage]
            + SignInFlow.Copy.all + LANServerDiscovery.Copy.all
    }

    /// The remote has no tap, and the screens say "address", never "URL".
    func testNoTouchWordsAndNoURL() {
        for line in everySignInLine {
            let words = line.lowercased().split(whereSeparator: { !$0.isLetter })
            XCTAssertFalse(words.contains("tap"), "tap in: \(line)")
            XCTAssertFalse(words.contains("url"), "URL in: \(line)")
            XCTAssertFalse(line.contains("\u{2014}"), "em dash in: \(line)")
        }
    }
}
