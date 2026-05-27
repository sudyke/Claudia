# Claudia — macOS Menu Bar Dev Monitor

A menu bar app that monitors three local dev services: Docker, Supabase (`localhost:54321`), and a Next.js dev server (`localhost:3000`). Polls every 5 seconds, shows a colored SF Symbol in the menu bar, sends notifications when services go down unexpectedly, suppresses noise via a Maintenance Mode toggle.

---

## Project Facts (do not "improve" these)

- **Target:** macOS 14+ (Sonoma). Modern APIs encouraged: `SMAppService`, `@Observable`, structured concurrency.
- **Single app target.** No widget extension, no App Group, no XPC.
- **Distribution:** Direct (Developer ID → notarize → staple). **App Sandbox is intentionally OFF.**
- **Concurrency:** Swift 6 language mode, strict concurrency `complete`. Default actor isolation: `MainActor`.
- **UI:** AppKit `NSStatusItem` + `NSPopover` hosting SwiftUI via `NSHostingController`, wired through an `AppDelegate` (`@NSApplicationDelegateAdaptor`). Not `MenuBarExtra` — the colored icon needs full `NSImage` control.
- **Dependencies:** First-party Apple frameworks only. Adding an SPM dependency requires written justification.

---

## Critical Rules

| Rule | Detail |
|---|---|
| **Sandbox stays OFF** | Never add `com.apple.security.app-sandbox`. It silently breaks every health check (Process is blocked). Hardened Runtime is on, which is required for notarization and is fine for Process. |
| **`isTemplate = false`** | The #1 trap. Template mode forces monochrome and discards palette colors. The status icon is intentionally colored — `StatusIcon.image(for:)` sets `isTemplate = false`. Never flip it. |
| **No ad-hoc `Process()`** | Every shell command goes through `runShell` in `ShellRunner.swift`. Zero exceptions. |
| **No `Timer`** | Polling uses a structured `Task` + `Task.sleep`. Timers stall in menu-tracking / popover-open run-loop modes. |
| **No `HealthCheck` protocol (yet)** | Intentional for three fixed services. If services grow past ~5 or need shared retry/config, introduce a protocol + array then. |
| **Aggregate logic in `StatusMonitor`** | `overallStatus` (worst-of-three) lives in the store. The icon consumes it; never recompute. |
| **Don't add `@unchecked Sendable` to user types** | `ProcessHolder` in `ShellRunner.swift` is the one exception — Foundation's `Process` lacks Sendable annotations and the wrapped APIs (`isRunning`, `terminate`) are documented thread-safe. |

---

## Architecture

```
ClaudiaApp.swift          ← @main, NSApplicationDelegateAdaptor, empty Settings scene
AppDelegate.swift         ← owns StatusItem, Popover, NSHostingController, click-toggle
StatusIconView.swift      ← StatusIcon.image(for:) — pure ServiceStatus → NSImage
StatusMonitor.swift       ← @MainActor @Observable: state + polling + transition detection
ServiceCheckers.swift     ← nonisolated check functions (Docker shell, HTTP probes)
ShellRunner.swift         ← nonisolated runShell() with watchdog timeout
LifecycleObserver.swift   ← NSWorkspace sleep/wake/user-switch → monitor.pause()/resume()
NotificationManager.swift ← UNUserNotificationCenter wrapper
PopoverView.swift         ← SwiftUI popover content
Info.plist                ← LSUIElement=YES, NSUserNotificationUsageDescription
```

**Data flow:** poll loop → writes → `StatusMonitor` → SwiftUI reads. UI never mutates monitoring state directly; controls call store methods (`pollNow`, `maintenanceMode` toggle).

**Actor isolation:** `StatusMonitor` is `@MainActor`. Shell/HTTP work is `nonisolated` — `async let` parallelism in `poll()` runs the three checks off the main actor; results hop back to main for state updates.

---

## Polling & Lifecycle

- **Loop:** `Task { while !cancelled { try? await Task.sleep(...); if shouldPoll { await poll() } } }` at ~5s with ±0.5s jitter.
- **Concurrent checks:** `async let d/s/v` so one slow check doesn't delay the others.
- **Pause/resume:** `LifecycleObserver` translates `NSWorkspace.willSleepNotification` / `didWakeNotification` / fast-user-switch into `monitor.pause()` / `resume()`.
  - `pause()` sets statuses to `.unknown` (visible) and flips `shouldPoll = false`.
  - `resume()` sets `suppressNextDownAlert = true`, then triggers an immediate `poll()`. The next cycle is a baseline — UP→DOWN alerts are suppressed once (services may still be spinning up after wake). Recovery alerts always fire.
- **Transition detection:** per-service previous-state tracked in `@ObservationIgnored` fields. First observation out of `.unknown` is silent baseline. UP→DOWN notifies unless maintenance or suppress-flag set. DOWN→UP always notifies.

---

## Adding a New Health Check

1. Add an `async -> Bool` function to `ServiceCheckers.swift` mirroring `checkSupabase` (HTTP probe) or `checkDocker` (`runShell`).
2. Add a `ServiceStatus` field and a `ServiceKind` case in `StatusMonitor.swift`. Include in `overallStatus` and the `async let` cycle in `poll()`.
3. Add a `ServiceRow` in `PopoverView.swift`.

If a new check forces changes to `runShell`, the polling loop, or `LifecycleObserver`, the abstraction is wrong — fix the shape, not the call sites.

---

## Service Port Configuration

| Service | Probe |
|---|---|
| Docker | `docker info --format '{{.ServerVersion}}'` via resolved binary path (`/opt/homebrew/bin/docker` → `/usr/local/bin/docker` → `/usr/bin/docker`) |
| Supabase | HTTP GET `http://localhost:54321/health` |
| Dev Server | HTTP HEAD `http://localhost:3000` |

HTTP checks: any `HTTPURLResponse` (regardless of status code) = up. Thrown error = down. 3s timeout.

**PATH note:** menu bar apps launched at login inherit a minimal environment. `docker` is rarely on `PATH`. Always resolve the binary explicitly — never rely on `/bin/sh -c "docker ..."`.

---

## Build & Verify

1. Open in Xcode 16+. Cmd+R to build & run.
2. Menu bar shows orange `?` (unknown) on first launch, then resolves green ✓ / red ✗ within ~1s.
3. Click the icon → popover shows three service rows + Maintenance Mode + Launch at Login + Quit.
4. Stop Docker Desktop → red ✗ in menu bar, notification banner fires ("Docker went down").
5. Restart Docker → green ✓, recovery notification fires.
6. Enable Maintenance Mode, stop a service → no down notification. Restart it → recovery notification still fires.
7. Close laptop lid 5+ minutes, reopen → icon corrects within ~1s, **no false "went down" alert**.
8. Leave popover open across a 5s tick → status still updates (proves Task loop runs during popover-open).
