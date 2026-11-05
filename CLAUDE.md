# Working in this repo

A fork of Nostalgex stripped down to one surface: a **Jellyfin-only Apple TV app**. The Plex
and Emby backends, the browser web tuner, the marketing site, the Docker container and the Roku
port from the upstream repo have all been removed. Only the native tvOS app (`Nostalgex/`) and
the shared channel config it reads remain.

## What is here

- `Nostalgex/` — the Xcode project and Swift sources. The app target is `Nostalgex` (tvOS 18+).
  There is also a `TopShelf` extension target.
- `channels.json`, `channels-memberships.json`, `franchises.json` — channel, bundle and
  franchise config at the repo root. A build phase ("Sync channel config") copies all three into
  every `.app`. After a rule change, rebuild and **Rescan library** on the device.
- `CHANNELS.md` — human-readable channel reference.
- `scripts/` — golden-vector JSON fixtures the Swift tests read (e.g. `filter-golden.json`,
  `schedule-parity-golden.json`), plus the tvOS release helpers (`release-tvos.sh`, `asc.mjs`).
- `docs/DEVLOG.md` — the upstream project's change log, kept as history. It describes work on
  surfaces that no longer exist here (web, Docker, Roku, Plex, Emby); read it for background on
  why the tvOS playback code is shaped the way it is, not as a description of this fork.

## Before changing playback or the guide

These are the product. A regression here is worse than a missing feature.

- Never diagnose by reasoning alone. Build a harness, measure, then name a cause.
- `NostalgexTests` must pass:
  `xcodebuild test -project Nostalgex/Nostalgex.xcodeproj -scheme Nostalgex \
   -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
   -only-testing:NostalgexTests CODE_SIGN_IDENTITY="-" \
   CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- The generic media model types keep their legacy `Plex`-prefixed names (`PlexMediaItem`,
  `PlexSection`, `PlexCollection`, the `[Plex90]` log prefix, the `Plex90App` entry point). These
  are internal names only; there is no Plex support. Renaming them is a separate mechanical pass.
- Backend-specific helpers that every client used to borrow from the Plex service now live in
  `Services/MediaServerKit.swift` (`APIError`, `clientID`, `compositeID`, `needsServerRemux`,
  `ShowProgress`, `doviProfile`).
- `channels.json` is the shared contract between the config, the app and the golden vectors under
  `scripts/`. The channel-filter semantics in `App/AppState+Channels.swift` and the golden vectors
  must agree; change them together.

## Conventions

- Match the existing code style and the doc-comment tone (plain, specific, measured numbers over
  adjectives). No em dashes in user-facing copy.
- Keep changes scoped to the Jellyfin tvOS app. Do not reintroduce web, Docker, Roku, Plex or Emby
  surfaces.
- Never commit real keys. `.gitignore` already covers `.env`, `Secrets.xcconfig` and the App Store
  Connect `.p8` keys.
