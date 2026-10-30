# 2026-10-27 Direct-device presence

## Problem and environment

RustDesk SX 2.1.0 on Ubuntu 26.04 / GNOME Wayland queried direct IP endpoints
through an unavailable ID server. A working direct connection could therefore
appear unavailable in the device list. Tailscale membership alone does not
establish that the remote-desktop port is reachable or that login succeeds.

## Fix

`src/client/peer_online/direct.rs` recognizes the real connector's IP and
host:port forms, with default port 21118. It opens and drops a TCP stream;
it does not authenticate, capture the screen or send input. Each probe has a
1.5-second timeout and at most eight probes run concurrently. Mixed ID queries
have a three-second budget so an ID server cannot delay direct results.

The client retains the callback shape. Device cards distinguish direct-port
reachability from confirmed ID-server presence, and unknown/failed probes do
not claim the entire computer is offline. Visible direct entries refresh every
six seconds; the existing public-ID query budget remains bounded. Only existing
user device entries are probed, with no network sweep or coordinator enumeration.

## Verification and rollback

The original native tests cover endpoint routing and a real loopback listener
transitioning from reachable to closed. UI tests cover labels and device cards.
The 2026-10-30 publication checks repeat the related Flutter tests on the new
stable SDK; see the direct-only incident note for commands and current results.

Runtime surface: presence routing, direct-port probing, card labels and
visible-list polling; no video, input, authentication or network-policy change.
Revert these scoped changes to restore the previous presence behavior. No server
or remote-connection configuration rollback is required.

## Account boundary

Network membership, listener reachability and remote-session authentication are
separate states. A future multi-user directory must derive device ownership
from authenticated server-side identity and filter lists, lookups and presence.
Do not expose coordinator management credentials to clients or trust a
client-supplied owner ID. This presence patch alone does not implement or verify
multi-user isolation.
