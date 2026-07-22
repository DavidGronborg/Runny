# Runny 🏃

A sleek, minimal run-tracking app for iPhone. Map your route, track distance and pace live, and see your heart rate from your WHOOP band via Apple Health — wrapped in a clean, dark, Strava-meets-Nike-Run-Club design.

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
