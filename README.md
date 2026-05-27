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

## Install

### Quick install (no Xcode needed)

Grab the latest `.dmg` from the [Releases page](https://github.com/sudyke/Claudia/releases/latest), open it, and drag **Claudia** into Applications. Then launch it from Spotlight or Launchpad.

**First-launch quirk:** the build is ad-hoc signed (no paid Apple Developer ID), so macOS Gatekeeper will block it the first time. Right-click `Claudia.app` in Finder → **Open** → confirm. After that, double-click works normally.

### Default ports

| Service | Probed at |
|---|---|
| Supabase | `http://localhost:54321/health` |
| Dev Server | `http://localhost:3000` |

Both ports are configurable in **Settings…** (in the popover). Project folders and the dev server command (`npm run dev` by default → `pnpm dev`, `bun run dev`, etc.) live there too.

### Build from source

Requires Xcode 16+ and macOS 14+.

```bash
git clone https://github.com/sudyke/Claudia.git
cd Claudia
./reinstall.sh        # builds Release, installs to /Applications, launches
```

To develop, open `Claudia.xcodeproj` in Xcode and Cmd+R.

To cut a new release `.dmg`:

```bash
./release.sh 0.1.1    # writes dist/Claudia-0.1.1.dmg
```

## Architecture

See [`CLAUDE.md`](CLAUDE.md) for the project rules, file layout, and critical traps (App Sandbox stays off, status icon `isTemplate = false`, no ad-hoc `Process()`, etc.).

Short version: AppKit `NSStatusItem` + `NSPopover` hosting SwiftUI via `NSHostingController`, with a `@MainActor @Observable` `StatusMonitor` driving polling through a structured `Task` loop. Swift 6 strict concurrency. First-party Apple frameworks only.

## License

MIT
