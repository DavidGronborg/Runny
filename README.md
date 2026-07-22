# Runny 🏃

A sleek, minimal run-tracking app. Map your route, track distance and pace live — wrapped in a clean, dark, Strava-meets-Nike-Run-Club design.

The project has two parts:

| Part | Status | Purpose |
|---|---|---|
| **`webapp/` — web MVP** | Testable now | Route mapping + distance/pace/splits in the browser, deployable to GitHub Pages. No integrations. |
| **iOS app (`Runny.xcodeproj`)** | Saved for a later phase | Full native app with Apple Health / WHOOP heart-rate integration. |

## Web MVP (`webapp/`)

Plain HTML/CSS/JS + [Leaflet](https://leafletjs.com) with free CARTO dark map tiles — no build step, no API keys, no backend.

- **Live GPS tracking** in the browser (Geolocation API): route drawn on a dark map, distance, moving time, smoothed current pace, GPS-signal indicator, 3-2-1 countdown, pause/resume.
- **Post-run summary**: fitted route map, time / avg pace / speed, per-km splits with pace bars (fastest highlighted).
- **Home dashboard** (weekly totals + recent runs) and **monthly history**, stored in `localStorage`.
- **Log past runs manually** — trace the route you ran by tapping the map, distance and pace are computed automatically; type in the duration from your WHOOP (or watch) and save it like any other run.
- **km/mi toggle**, screen wake-lock during runs, installable as a home-screen app.
- **Demo mode** — "Try a demo run" on the home screen simulates a 6× time-lapse GPS feed through the exact same pipeline (filters, pace, splits), so you can test everything from a desk.

### Deploy to GitHub Pages

A workflow (`.github/workflows/pages.yml`) deploys `webapp/` automatically on every push to `main`. One-time setup: repo **Settings → Pages → Source: GitHub Actions**. The app then lives at `https://<user>.github.io/Runny/`.

To try it locally: `cd webapp && python3 -m http.server`, then open `http://localhost:8000` (geolocation works on `localhost`; elsewhere it requires HTTPS).

Notes for phone testing: keep the screen on while tracking (browsers suspend GPS in background tabs — the app requests a wake lock to help), and GPS accuracy in browsers is a bit coarser than native.

## iOS app (later phase)

The full native SwiftUI app with Apple Health integration — heart rate from your WHOOP band, workouts + GPS routes written back to Health.

## Features

- **Live GPS tracking** — your route drawn on the map in real time, with distance, moving time and a smoothed current pace. Runs keep tracking with the screen off (background location).
- **Countdown start, pause & resume** — 3-2-1 start with GPS-lock indicator; pausing freezes the clock and doesn't count the distance you walk in the meantime.
- **Apple Health integration**
  - *Reads* heart rate — WHOOP syncs your pulse to Apple Health, and Runny picks it up live during the run (WHOOP syncs in batches, so it can trail by a few minutes) and attaches the full heart-rate curve to the finished run.
  - *Writes* every saved run back to Health as an outdoor running workout with distance, calories and the GPS route.
- **Post-run summary** — route map, headline stats (time, avg pace, calories, avg/max HR), per-km splits with pace bars (fastest split highlighted), and a heart-rate chart.
- **Home dashboard** — this week's distance, runs, time and average pace, plus your recent runs.
- **History** — all runs grouped by month with monthly distance totals.
- **Units** — kilometers or miles, switchable anytime (splits recompute on the fly).

## Getting started

1. Open `Runny.xcodeproj` in **Xcode 16 or newer** (iOS 17+ deployment target).
2. Select the *Runny* target → *Signing & Capabilities* → pick your team. The HealthKit capability and background-location mode are already configured.
3. Change the bundle identifier (`dk.dsgit.Runny`) if you like.
4. Build and run **on a real iPhone** — GPS and HealthKit don't work meaningfully in the simulator.
5. On first run start, grant **location access** and **Apple Health permissions** (read heart rate & body weight, write workouts/routes).

### Getting WHOOP pulse data in

In the WHOOP app, make sure Apple Health syncing is enabled (WHOOP profile → integrations → Apple Health, with heart rate sharing on). Runny then reads those samples straight from Health — no WHOOP API keys needed. If a run finishes before WHOOP has synced, open the run later and tap **Sync heart rate from Health**.

## Architecture

```
Runny/
├── RunnyApp.swift          # App entry, dark theme, environment setup
├── Models/
│   ├── Run.swift           # Run, TrackPoint, HeartRatePoint, on-demand splits
│   └── Formatters.swift    # Distance / pace / duration / date formatting
├── Services/
│   ├── RunTracker.swift    # Core Location: filtered GPS trail, moving time, pace
│   ├── HealthKitManager.swift  # HR reads, workout + route writes
│   └── RunStore.swift      # JSON persistence + weekly/monthly stats
├── Theme/Theme.swift       # Colors, typography, card styles
└── Views/                  # Home, ActiveRun, Summary, Detail, History, Settings
    └── Components/         # Map, splits, HR chart, stat tiles, run rows
```

- Pure SwiftUI + Observation (`@Observable`), MapKit for SwiftUI, Swift Charts. No third-party dependencies.
- GPS noise handling: fixes with poor horizontal accuracy (> 25 m) and implausible jumps (> ~43 km/h) are discarded.
- Calories are estimated from distance and your body weight from Health (`kcal ≈ kg × km × 1.036`).
