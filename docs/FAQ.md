# FAQ and troubleshooting

## "Could not reach my server"

Work through these in order.

1. **Address.** Type the scheme, host and port exactly as another client uses them, for example
   `http://192.168.1.20:8096`. A `100.x.x.x` address is Tailscale.
2. **Read the error.** The connect screen names the cause: transport security, unknown host, wrong
   port, timeout, or certificate. Each points at a different fix.
3. **Does another app on the same Apple TV reach the same server?** If Swiftfin or the Jellyfin app
   connects and JFTV does not, the address and the exact error text are the useful detail. If
   nothing connects, it is the network or the server, not the app.
4. **Plain http to a non-local address** (VPN, Tailscale, a public IP) needs the app's App Transport
   Security setting to allow arbitrary loads, which this app does.

## A channel is empty, or a title is on the wrong channel

Channels are rules over your library's metadata, all in `channels.json`. An empty channel usually
means your library has nothing that matches, or the server's genres and ratings are missing. A title
in the wrong place is a rule that needs tightening. Edit `channels.json` (see `CHANNELS.md` for every
rule field), rebuild, and Rescan library on the device.

## It tunes but never plays, or plays sound over a black picture

First ask the server whether it can actually read the file. If the file exists and it still fails,
the container, video codec and audio codec plus the Apple TV model are the useful detail. Sound over
a black picture is usually a codec the device cannot render (for example 10-bit H.264, or Dolby
Vision profile 7); the app routes those to a server transcode, but a server that copies the stream
through will still fail.

## Sign-in options

Jellyfin sign-in supports a username and password, or Quick Connect (approve a code in the Jellyfin
app on your phone). Quick Connect must be enabled on the server (Jellyfin Dashboard -> General).

## Where to ask

This is a personal fork. Open an issue on this repository with the exact address and error text.
