import Foundation

// Library section and collection models shared by the backend protocol and its
// Jellyfin implementation. The `Plex`-prefixed names are legacy: these are the
// generic section/collection types every backend maps into, kept for back-compat
// with persisted snapshots.

/// A library section (view) on the server.
struct PlexSection: Decodable {
    let key: String
    let title: String
    let type: String
    var scannedAt: Int? = nil
    var updatedAt: Int? = nil
    var contentChangedAt: Int? = nil
}

/// A collection within a library section.
struct PlexCollection: Decodable {
    let ratingKey: String
    let title: String
    let childCount: Int?
    let thumb: String?
}
