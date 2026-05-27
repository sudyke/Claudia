# Claudia

A macOS menu bar app that monitors three local dev services and lets you start them with one click when they're down.

![Status: works on my machine](https://img.shields.io/badge/status-works%20on%20my%20machine-orange)

## What it monitors

| Service | How it's checked |
|---|---|
| **Docker** | `docker info` (binary resolved at `/opt/homebrew/bin`, `/usr/local/bin`, or `/usr/bin`) |
| **Supabase** | `GET http://localhost:54321/health` |
| **Dev Server** | `HEAD http://localhost:3000` |

Polls every 5 seconds. Shows an orange Claude Code icon in the menu bar when everything's healthy, dark when something's down, grey exclamation triangle when status is unknown (sleep/wake/launch).

## Features

- **One-click start** — when a service is down, click the row to launch it. Docker opens directly; Supabase and your dev server open Terminal with `cd <path> && <cmd>` so you can see logs.
- **Configurable** — set your Supabase project folder, dev server folder, and start command (default `npm run dev`, change to `pnpm dev`, `bun run dev`, etc.) in Settings.
- **Smart notifications** — banner alerts when a service goes down unexpectedly. Toggle off ("Notifications" in the popover) while you're intentionally stopping things. Recovery alerts always fire.
- **Sleep-aware** — pauses polling on lid-close / fast-user-switch, forces an immediate refresh on wake, suppresses false "went down" alerts during the post-wake baseline cycle.
- **Launch at login** — toggle in the popover (uses `SMAppService`, no deprecated APIs).

## Build & install

Requires Xcode 16+ and macOS 14+.

```bash
git clone https://github.com/<your-username>/Claudia.git
cd Claudia
./reinstall.sh
```

`reinstall.sh` builds Release, copies the app to `/Applications`, and launches it.

To develop, open `Claudia.xcodeproj` in Xcode and Cmd+R.

## Architecture

See [`CLAUDE.md`](CLAUDE.md) for the project rules, file layout, and critical traps (App Sandbox stays off, status icon `isTemplate = false`, no ad-hoc `Process()`, etc.).

Short version: AppKit `NSStatusItem` + `NSPopover` hosting SwiftUI via `NSHostingController`, with a `@MainActor @Observable` `StatusMonitor` driving polling through a structured `Task` loop. Swift 6 strict concurrency. First-party Apple frameworks only.

## License

MIT
