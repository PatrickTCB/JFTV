# Nostalgex - App Store Metadata

_Fork metadata. This is a Jellyfin-only Apple TV build; the copy below reflects that. Fill in your
own URLs, version and review details before submitting._

## App Name
Nostalgex

## Subtitle (30 chars max)
Jellyfin retro live TV

## Category
Entertainment

## Price
Free

---

## Description

Nostalgex turns your Jellyfin library into live TV. No more scrolling through a thousand titles
trying to pick one. Turn it on, flip through channels, land on something.

Your movies and shows get sorted into themed channels like a real cable lineup. Rewatchables,
Saturday Morning Cartoons, 90s Sitcoms, Kids & Family, True Crime, Arthouse, music video channels,
and a lot more. Every channel runs a continuous daily schedule, so there is always something already
playing when you tune in.

How it works:
- Connect your Jellyfin server
- Pick the channel packages you want in Settings
- Start watching

Channels are built from what is actually in your library. If it is on your server, it can show up on
a channel. Nostalgex does not host or supply any video. Everything plays from your own server.

Features:
- 130+ themed channels in 14 packages
- EPG-style channel guide with live schedules
- Channel surfing with Siri Remote swipe gestures
- Retro mode with CRT scanlines and 4:3 framing, or turn it off for a clean picture
- Now Playing panel while you watch, with closed captions, subtitle and audio language, stream
  quality, and a sleep timer
- Music video channels that build themselves from your music videos
- Your collections become their own channels
- Multi-part movies play straight through
- Kids and family channels with mature content filtered out
- Optional playback reporting, off by default, so Continue Watching and play counts stay accurate on
  your Jellyfin server if you want them to
- Your sign-in survives restarts, updates, and restores

Requires your own Jellyfin server. Nostalgex is a client. It does not provide any media of its own.

Not affiliated with Jellyfin or Apple.

---

## Keywords (100 chars max)
jellyfin,live tv,channels,retro,cable,epg,guide,nostalgia,media server,tuner,90s

## What's New in This Version
_(Write your own release notes here.)_

---

## Age Rating

**Rating: 17+**
Content is user-generated (it depends on what is in their own library). The app itself contains no
objectionable content, but users may have R-rated or mature content on their servers.

Applicable content descriptions:
- Frequent/Intense Mature/Suggestive Themes (user content)
- Frequent/Intense Horror/Fear Themes (user content)
- Frequent/Intense Realistic Violence (user content)

---

## Privacy Policy URL
_(Your own URL.)_

## Support URL
_(Your own URL.)_

## Support Email
_(Your own email.)_

---

## Privacy Nutrition Label

See `PRIVACY_POLICY.md` for the full, accurate description. Short version for the questionnaire:

- **Collected:** anonymous product interaction and diagnostic events, plus an anonymous, hashed,
  vendor-scoped device identifier used only to group one device's events. Analytics are off if the
  TelemetryDeck id is removed from `Info.plist`.
- **Not collected:** name, email, account details, server credentials, server address, library
  contents, titles, watch history, advertising identifiers.
- **Not used for tracking** across apps or websites owned by other companies. No advertising, no data
  brokers, no selling.

---

## Screenshots Needed (tvOS)

Required: 1920x1080 (at least 1, up to 10)

Recommended shots:
1. Channel guide (EPG view) with channels playing
2. Full screen playback with OSD overlay
3. Now Playing panel over live video
4. Retro mode with CRT effect
5. Settings page showing channel packages

---

## App Review Notes

**Quickest path to review: tap "demo mode" on the first screen.** This loads the app with bundled
sample channels and requires no account, no network, and no server connection. The full tuner UI,
channel guide, channel surfing, and settings are all reachable from Demo Mode. (Playback is disabled
in Demo Mode since the sample channels have no real media files.)

Nostalgex is a client for a Jellyfin server the user already runs. It does not host, stream, or
provide any media content of its own. All content comes from the user's own personal media library on
their own server.

How to test with real content (provide a demo Jellyfin server URL, username and password in the App
Store Connect "App Review Information" fields):
1. Launch the app on Apple TV
2. Select "CONNECT TO JELLYFIN"
3. Enter the server address, or pick it from the servers found on the network
4. Sign in with the username and password, or approve a Quick Connect code in Jellyfin
5. The app loads the library and channels populate based on its content

The app connects to:
- The user's own Jellyfin server (sign-in, library and playback)
- TMDB and OMDb, via a relay, and a Supabase cache — optional metadata enrichment, off unless
  enabled at build time
- MusicBrainz, then Deezer (public music metadata for the music video channels)
- TelemetryDeck (anonymous usage analytics; off if the app id is removed)

No credentials, server addresses, or library contents are transmitted to the app developer.
