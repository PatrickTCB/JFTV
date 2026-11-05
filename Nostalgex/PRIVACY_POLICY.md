# Privacy Policy

Nostalgex turns your own **Jellyfin** library into live TV channels on **Apple TV**. It does not
host, supply, or stream any media. Everything you watch comes off your own Jellyfin server.

> **Fork note.** This is a Jellyfin-only Apple TV build. The upstream project's Roku, Android TV,
> web tuner and website surfaces are not part of it, and neither is Plex or Emby support.

## Summary

- No accounts. Nothing is sold or rented to anyone.
- Your server address and login token stay on your Apple TV.
- The app can send a small, fixed list of anonymous usage events so it is possible to tell whether
  things are working. No names, no library contents, no titles. (See the analytics note below; a
  personal fork should set its own TelemetryDeck id or remove it.)
- Nothing collected follows you into other companies' apps or across the web.

## What the app connects to

- **Your own Jellyfin server**, for sign-in, your library and playback. To find it, the app can send
  a short broadcast on your home network asking which Jellyfin servers are there (UDP port 7359),
  which only devices on that network receive. You can also type the server's address. Sign-in is a
  username and password, or a Quick Connect code you approve in Jellyfin; both go straight from the
  Apple TV to your server. The app keeps only the access token your server returns. Plain `http://`
  on a local address is allowed (this is a native app, not a browser).
- **TMDB / OMDb via a relay, and a Supabase cache** — optional metadata enrichment used to sort
  titles onto finer channels. This is **off unless you add Supabase values** at build time
  (`Nostalgex/Secrets.xcconfig`). When on, only the public TMDB or IMDb id of a title is sent; no
  library titles, account, device or server details. In this fork the relay URL still points at the
  upstream `nostalgex.app` proxy; point `Services/TMDBConfig.swift` at your own relay, or set a
  `TMDB_API_KEY` in the scheme for a direct connection, or leave enrichment off.
- **MusicBrainz, then Deezer** for any it cannot place — to find the genres and years of music
  videos for the music video channels. For each music video the app searches by song title and artist
  name, straight from your Apple TV. Nothing about you, your account or your server goes with it, and
  the answers are cached on the device.
- **iCloud**, only if you turn on SYNC WITH MY OTHER APPLE TVS in Settings. Off by default. When on,
  your channel packages, retro mode, guide text size, subtitle/audio/stream-quality settings and the
  playback-reporting switches are stored in your own iCloud account. That goes to Apple, not to us.
  Server addresses, tokens and user IDs stay in the Keychain on each device.

## Analytics

The app can send anonymous usage events to [TelemetryDeck](https://telemetrydeck.com), a
privacy-focused analytics service, to tell whether the app is working: installs and connects, whether
playback starts and stays up, and which settings are used. Events carry a `backend` value
(`jellyfin` or `demo`) and a `demo` flag. No event carries your name, library contents, titles,
server address, or token. Each event carries an anonymous device identifier derived from Apple's
vendor identifier, hashed on device before it leaves and again on arrival.

The TelemetryDeck app id lives in `Nostalgex/Info.plist` (`TelemetryDeckAppID`). **A personal fork
should replace it with its own or delete the key**, which turns analytics off. As shipped from
upstream it points at the original author's dashboard.

## What the app never sends

- Your name, email, or any account details.
- Your Jellyfin username, password, or token.
- Your server address, hostname, or IP address.
- Your library contents: no titles, filenames, posters, or watch history.
- Any name that came from your library (collections, servers, folders, titles). The only channel
  names ever sent are the built-in ones from the app's own shipped lineup.
- Any advertising identifier, or anything that tracks you across other apps or websites.

## What the app stores on your device

- Your server address and login token, in the device Keychain.
- Your Jellyfin user ID.
- Your channel and bundle preferences, retro mode, subtitle and audio language settings, and the date
  of your last library scan.
- A cached copy of your channel guide, and a short "what is on now" list for the Apple TV home screen
  (titles and artwork links from your own library), in the app's on-device cache.

This stays on your device. It is not synced to us, and it is removed when you delete the app or sign
out.

## Playback reporting

The app can report what you are watching back to **your own Jellyfin server**. Two separate switches,
both **off** by default, in Settings under PLAYBACK & PICTURE:

- **Show Now Playing** lets your server show what is playing.
- **Mark Watched** counts a film or episode as watched when you join it in its first 15% and watch at
  least 75% of it.

With both off, nothing is reported and nothing in your library changes; channel surfing never fills
your Continue Watching row. When on, the app first reads the watch state your server already has and
puts it back when the program ends, except that a watch Mark Watched counts stays counted. Reports go
only to the server you connected, never to us.

## Tracking

Nostalgex does not track you across apps or websites owned by other companies, and does not use data
for advertising or ad measurement.

## Your choices

- Deleting the app removes everything it stored on your Apple TV, including your server token.
- Playback reporting is off unless you turn it on, and you can turn it back off at any time.
- Analytics are off if the TelemetryDeck id is removed.

## Children's privacy

Nostalgex is not directed at children and does not knowingly collect personal information from
anyone, including children.
