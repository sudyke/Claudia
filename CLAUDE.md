# Claudia — macOS Menu Bar Dev Monitor

A menu bar app that monitors a user-configurable list of local services. Default presets cover Docker, Postgres, Supabase, Redis, MySQL, MongoDB, Next.js/Vite/Astro/Storybook/Rails/Django dev servers, Mailpit, LocalStack, and ngrok. Custom services can be defined for anything else.

---

## Project Facts (do not "improve" these)

- **Target:** macOS 14+ (Sonoma). Modern APIs encouraged: `SMAppService`, `@Observable`, structured concurrency.
- **Single app target.** No widget extension, no App Group, no XPC.
- **Distribution:** Direct (Developer ID → notarize → staple). **App Sandbox is intentionally OFF.**
- **Concurrency:** Swift 6 language mode, strict concurrency `complete`. Default actor isolation: `MainActor`.
- **UI:** AppKit `NSStatusItem` + `NSPopover` hosting SwiftUI via `NSHostingController`, wired through an `AppDelegate` (`@NSApplicationDelegateAdaptor`). Not `MenuBarExtra` — the colored icon needs full `NSImage` control.
- **Dependencies:** First-party Apple frameworks only.

---

## Critical Rules

| Rule | Detail |
|---|---|
| **Sandbox stays OFF** | Never add `com.apple.security.app-sandbox`. It silently breaks every shell check (Process is blocked). Hardened Runtime is on, which is required for notarization and is fine for Process. |
| **`isTemplate = false`** | Template mode forces monochrome and discards palette colors. The status icon is intentionally colored — `StatusIcon.image(for:)` sets `isTemplate = false`. Never flip it. |
| **No ad-hoc `Process()`** | Every shell command goes through `runShell` in `ShellRunner.swift`. Zero exceptions. |
| **No `Timer`** | Polling uses a structured `Task` + `Task.sleep`. Timers stall in menu-tracking / popover-open run-loop modes. |
| **No `@unchecked Sendable` on user types** | The one exception is `ProcessHolder` in `ShellRunner.swift` because Foundation's `Process` lacks Sendable annotations and the wrapped APIs are documented thread-safe. |
| **Value-type extension properties need `nonisolated`** | Project defaults to MainActor isolation. Pure-computation properties on enums/structs (e.g. `CheckSpec.summary`, `StartSpec.isExecutable`) must be marked `nonisolated` so they're callable from background contexts. |

---

## Architecture

```
ClaudiaApp.swift          ← @main, NSApplicationDelegateAdaptor, Settings scene
AppDelegate.swift         ← owns StatusItem, Popover, NSHostingController, welcome window
StatusIconView.swift      ← StatusIcon.image(for:) — pure ServiceStatus → NSImage

Service.swift             ← Service value type, CheckSpec/StartSpec enums, kind helpers, BinaryResolver
Presets.swift             ← Preset library (~17 entries) + Presets.defaults() seed
CheckRunner.swift         ← Dispatches CheckSpec → http/tcp/shell probe (nonisolated)
ActionRunner.swift        ← Dispatches StartSpec → open/terminal/shell launch (nonisolated)
ShellRunner.swift         ← runShell() with watchdog timeout

AppSettings.swift         ← @MainActor @Observable: services array, notifications toggle, first-run flag, legacy migration
StatusMonitor.swift       ← @MainActor @Observable: per-service state dict, TaskGroup-based parallel poll, transition detection
LifecycleObserver.swift   ← NSWorkspace sleep/wake/user-switch → monitor.pause()/resume()
NotificationManager.swift ← UNUserNotificationCenter wrapper

PopoverView.swift         ← Menu bar popover; ForEach over enabled services
SettingsView.swift        ← TabView (Services + General); list of services with edit/delete/toggle
PresetPickerSheet.swift   ← "Add service" → pick from preset library (or Custom)
ServiceEditorSheet.swift  ← Full edit form: name, check type, start action with dynamic fields per type
WelcomeSheet.swift        ← First-run picker; user selects which presets to seed
Info.plist                ← LSUIElement=YES, NSUserNotificationUsageDescription
```

**Data flow:** poll loop → writes → `StatusMonitor.states` → SwiftUI reads. UI never mutates monitoring state directly; controls call store methods (`pollNow`, `notificationsEnabled` toggle, `AppSettings.add/update/delete`).

**Actor isolation:** `StatusMonitor` and `AppSettings` are `@MainActor`. Shell/HTTP/TCP work runs `nonisolated` via `CheckRunner` / `ActionRunner` / `runShell`. `poll()` snapshots service specs on the main actor, kicks off a `TaskGroup` of nonisolated checks, and applies results on main when they return.

---

## Polling & Lifecycle

- **Loop:** `Task { while !cancelled { try? await Task.sleep(...); if shouldPoll { await poll() } } }` at ~5s with ±0.5s jitter.
- **Concurrent checks per cycle:** `withTaskGroup` over enabled services so one slow check doesn't delay others.
- **Pause/resume:** `LifecycleObserver` translates `NSWorkspace.willSleepNotification` / `didWakeNotification` / fast-user-switch into `monitor.pause()` / `resume()`.
  - `pause()` sets all states to `.unknown` (visible) and flips `shouldPoll = false`.
  - `resume()` sets `suppressNextDownAlert = true`, then triggers an immediate `poll()`. The next cycle is a baseline — UP→DOWN alerts are suppressed once. Recovery alerts always fire.
- **Transition detection:** per-service previous-status tracked in `ServiceState.previous`. First observation out of `.unknown` is silent baseline. UP→DOWN notifies unless maintenance or suppress-flag set. DOWN→UP always notifies.

---

## Adding a New Preset

1. Add a `ServicePreset` entry to `Presets.all` in `Presets.swift`.
2. Pick the right `PresetCategory`.
3. Construct a `Service` in `makeService` with the appropriate `check` and (optionally) `startCommand`.
4. For shell binaries, use `BinaryResolver.resolveOrFirst("name")` — Homebrew install paths vary by arch.
5. For services that need a project path (workdir for Terminal commands), set `needsPath: true` — the editor will hint to the user that they need to fill it in.

That's it. The preset appears in the picker, can be added with one click, and is freely editable afterward.

---

## Adding a New Check Type

If you need a new probe (e.g. `.grpc`, `.websocket`), add a case to `CheckSpec`, handle it in `CheckRunner.run`, and add a case to `CheckKind` + the editor's `checkKind` switch in `ServiceEditorSheet`. Three files, mechanical.

---

## Storage

- `claudia.services.v1` — `Data` (JSON-encoded `[Service]`)
- `claudia.notificationsEnabled` — `Bool`
- `claudia.firstRunComplete` — `Bool`
- (Legacy keys from < v0.2.0 are migrated on first launch then removed.)

---

## Build & Verify

1. Open in Xcode 16+. Cmd+R to build & run.
2. First launch shows the Welcome sheet (preset checkboxes) — pick a starter set or skip.
3. Menu bar shows the orange Claude Code icon when all up, dark icon when something's down, grey exclamation when status is unknown.
4. Settings → Services to add/edit/delete/reorder/disable services.
5. Click a downed service's ▶ Start button to launch it (Docker.app, Terminal with `npm run dev`, etc.).
