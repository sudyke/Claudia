# Claudia

A macOS menu bar app that monitors your local dev services and lets you start them with one click when they're down. Pick from ~17 built-in presets (Docker, Postgres, Supabase, Redis, MySQL, MongoDB, Next.js, Vite, Astro, Storybook, Rails, Django, Mailpit, LocalStack, ngrok, OrbStack, Colima) or define your own.

![Status: works on my machine](https://img.shields.io/badge/status-works%20on%20my%20machine-orange)

## What it does

Polls every 5 seconds. Shows the Claude Code icon in the menu bar:

- **Orange** — all configured services are up
- **Dark** — at least one is down
- **Grey ⚠** — status unknown (just after sleep/wake/launch)

Click the icon for the popover: per-service status, a ▶ Start button on any downed service, a Notifications toggle, Refresh Now, Launch at Login, and Settings.

## Check types

- **HTTP** — `GET` or `HEAD` against a URL. Any response = up.
- **TCP** — open a socket to host:port. Connection accepted = up.
- **Shell** — run a command. Exit 0 = up. (`docker info`, `orb status`, `colima status`, etc.)

## Start action types

- **Open App** — runs `open -a "<name>"`. For Docker Desktop, OrbStack, etc.
- **Terminal** — opens Terminal.app and runs `cd <folder> && <command>`. For long-running dev servers — you see the logs.
- **Shell** — runs a one-shot command. For `brew services start postgresql`, `colima start`, etc.

## Features

- **17+ preset library** with sensible defaults; one click to add common services
- **Fully customizable** — name, check type, start action all editable; or build your own from scratch
- **Smart notifications** — banner alerts when a service goes down unexpectedly. Toggle off while you're intentionally stopping things. Recovery alerts always fire.
- **Sleep-aware** — pauses polling on lid-close / fast-user-switch, forces an immediate refresh on wake, suppresses false "went down" alerts during the post-wake baseline cycle.
- **Launch at login** — uses `SMAppService`, no deprecated APIs.

## Install

### Homebrew (recommended)

```bash
brew install --cask sudyke/tap/claudia-monitor
```

> Cask is named `claudia-monitor` (not `claudia`) because the unqualified `claudia` already resolves to a different cask in Homebrew's main repo.

### Direct download

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
