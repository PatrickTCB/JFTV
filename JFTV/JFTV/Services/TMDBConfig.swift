import Foundation

enum TMDBConfig {
    /// Prefer `Info.plist` keys in production builds; fall back to environment for CI/dev.
    /// Keep these empty by default so the app still compiles without secrets.
    private static let configuredTMDBAPIKey: String = value(forEnv: "TMDB_API_KEY", infoPlistKey: "TMDBApiKey")
    private static let configuredOMDBAPIKey: String = value(forEnv: "OMDB_API_KEY", infoPlistKey: "OMDBApiKey")
    private static let configuredSupabaseURL: String = value(forEnv: "SUPABASE_URL", infoPlistKey: "SupabaseURL")
    private static let configuredSupabaseAnonKey: String = value(forEnv: "SUPABASE_ANON_KEY", infoPlistKey: "SupabaseAnonKey")

    #if DEBUG
    /// Test harnesses only: send TMDB, OMDb (both through the proxy route) and Supabase to
    /// local stand-ins, with no keys, so a run never reaches the real services or the shared
    /// cache. Nil in the app.
    struct HarnessEndpoints {
        let proxyURL: String
        let supabaseURL: String
    }
    nonisolated(unsafe) static var harnessEndpoints: HarnessEndpoints?
    static var tmdbAPIKey: String { harnessEndpoints == nil ? configuredTMDBAPIKey : "" }
    static var omdbAPIKey: String { harnessEndpoints == nil ? configuredOMDBAPIKey : "" }
    static var supabaseURL: String { harnessEndpoints?.supabaseURL ?? configuredSupabaseURL }
    static var supabaseAnonKey: String { harnessEndpoints == nil ? configuredSupabaseAnonKey : "harness" }
    #else
    static var tmdbAPIKey: String { configuredTMDBAPIKey }
    static var omdbAPIKey: String { configuredOMDBAPIKey }
    static var supabaseURL: String { configuredSupabaseURL }
    static var supabaseAnonKey: String { configuredSupabaseAnonKey }
    #endif

    /// Optional metadata relay for TMDB/OMDb lookups (an `api/tmdb`-style edge proxy that
    /// holds the API key server-side). Upstream used the author's own site for this; this
    /// fork ships none — empty by default, so enrichment only runs when the build sets a
    /// direct `TMDB_API_KEY`/`OMDB_API_KEY`, and nothing is ever sent to the original
    /// author's servers. To run your own relay, set this constant to its URL.
    #if DEBUG
    static var tmdbProxyURL: String { harnessEndpoints?.proxyURL ?? "" }
    #else
    static let tmdbProxyURL = ""
    #endif

    private static func value(forEnv envKey: String, infoPlistKey: String) -> String {
        if let v = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String, !v.isEmpty {
            return v
        }
        if let v = ProcessInfo.processInfo.environment[envKey], !v.isEmpty {
            return v
        }
        return ""
    }
}
