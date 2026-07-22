import SwiftUI
import MapKit
import UIKit

struct ActiveRunView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RunStore.self) private var store
    @AppStorage("useMetric") private var metric = true

    @State private var tracker = RunTracker()
    @State private var countdown: Int?
    @State private var heartRate: Double?
    @State private var finishedRun: Run?
    @State private var showEndConfirm = false
    @State private var isFinishing = false
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        ZStack(alignment: .bottom) {
            map
            metricsPanel
            if let countdown {
                countdownOverlay(countdown)
            }
            if tracker.authorizationDenied {
                locationDeniedOverlay
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .task { await begin() }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .fullScreenCover(item: $finishedRun) { run in
            RunSummaryView(run: run, locations: tracker.rawLocations, isNew: true) {
                finishedRun = nil
                dismiss()
            }
        }
        .confirmationDialog("Finish run?", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("Finish run", role: .destructive) { finish() }
            Button("Keep running", role: .cancel) {}
        }
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $camera, interactionModes: [.pan, .zoom]) {
            UserAnnotation()
            if tracker.coordinates.count > 1 {
                MapPolyline(coordinates: tracker.coordinates)
                    .stroke(Theme.accent,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            gpsChip
                .padding(.trailing, 16)
                .padding(.top, 8)
        }
    }

    private var gpsChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(gpsColor)
                .frame(width: 8, height: 8)
            Text("GPS")
                .font(.label(11))
                .tracking(1)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Theme.bg.opacity(0.85)))
    }

    private var gpsColor: Color {
        guard let accuracy = tracker.horizontalAccuracy, accuracy > 0 else { return Theme.danger }
        if accuracy <= 12 { return Theme.accent }
        if accuracy <= 25 { return Theme.warning }
        return Theme.danger
    }

    // MARK: - Metrics

    private var metricsPanel: some View {
        VStack(spacing: 22) {
            if tracker.state == .paused {
                Text("PAUSED")
                    .font(.label(12))
                    .tracking(3)
                    .foregroundStyle(Theme.warning)
            }

            VStack(spacing: 2) {
                Text(Fmt.distance(tracker.distance, metric: metric))
                    .font(.display(68))
                    .monospacedDigit()
                    .foregroundStyle(tracker.state == .paused ? Theme.textSecondary : .white)
                    .contentTransition(.numericText())
                Text(Fmt.distanceUnit(metric: metric).uppercased())
                    .font(.label(13))
                    .tracking(3)
                    .foregroundStyle(Theme.textSecondary)
            }

            HStack(spacing: 0) {
                liveMetric(value: Fmt.duration(tracker.elapsed), label: "Time")
                liveMetric(value: Fmt.pace(currentPaceForUnit), label: "Pace" + Fmt.paceUnit(metric: metric))
                liveMetric(value: heartRate.map { "\(Int($0))" } ?? "--",
                           label: "BPM",
                           tint: heartRate != nil ? Theme.heart : Theme.textSecondary)
            }

            controls
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Theme.bg.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Theme.stroke, lineWidth: 1)
                )
        )
        .padding(.horizontal, 10)
    }

    private var currentPaceForUnit: TimeInterval? {
        tracker.currentPaceSecPerKm.map { $0 * Fmt.unitMeters(metric: metric) / 1000 }
    }

    private func liveMetric(value: String, label: String, tint: Color = .white) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.metric(24))
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(label.uppercased())
                .font(.label(10))
                .tracking(1.5)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        HStack(spacing: 44) {
            if tracker.state == .paused {
                controlButton(icon: "play.fill", background: Theme.accent, foreground: .black) {
                    tracker.resume()
                }
                controlButton(icon: "stop.fill", background: Theme.danger, foreground: .white) {
                    finish()
                }
            } else {
                controlButton(icon: "pause.fill", background: Theme.surfaceLight, foreground: .white) {
                    tracker.pause()
                }
                controlButton(icon: "stop.fill", background: Theme.danger, foreground: .white) {
                    showEndConfirm = true
                }
            }
        }
    }

    private func controlButton(icon: String,
                               background: Color,
                               foreground: Color,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: 68, height: 68)
                .background(Circle().fill(background))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Countdown

    private func countdownOverlay(_ value: Int) -> some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("GET READY")
                    .font(.label(14))
                    .tracking(4)
                    .foregroundStyle(Theme.textSecondary)
                Text("\(value)")
                    .font(.system(size: 170, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText(countsDown: true))
                    .id(value)
                    .transition(.scale.combined(with: .opacity))
                HStack(spacing: 6) {
                    Circle().fill(gpsColor).frame(width: 8, height: 8)
                    Text(gpsColor == Theme.accent ? "GPS locked" : "Locking GPS…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var locationDeniedOverlay: some View {
        ZStack {
            Theme.bg.opacity(0.96).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.danger)
                Text("Location access needed")
                    .font(.heading(20))
                    .foregroundStyle(.white)
                Text("Runny can't track your route without location access. Enable it in Settings.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.heading(16))
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Capsule().fill(Theme.accent))
                Button("Cancel") { dismiss() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // MARK: - Lifecycle

    private func begin() async {
        tracker.prepare()
        try? await HealthKitManager.shared.requestAuthorization()

        for value in [3, 2, 1] {
            withAnimation(.snappy) { countdown = value }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            try? await Task.sleep(for: .seconds(1))
        }
        withAnimation(.easeOut(duration: 0.3)) { countdown = nil }
        tracker.start()
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        if let start = tracker.startDate {
            // WHOOP syncs to Health in batches, so also accept slightly older samples.
            HealthKitManager.shared.startHeartRateUpdates(from: start.addingTimeInterval(-600)) { bpm in
                heartRate = bpm
            }
        }
    }

    private func finish() {
        guard !isFinishing else { return }
        isFinishing = true
        HealthKitManager.shared.stopHeartRateUpdates()

        guard var run = tracker.stop() else {
            dismiss()
            return
        }
        Task {
            let samples = await HealthKitManager.shared.heartRateSamples(from: run.startDate, to: run.endDate)
            if !samples.isEmpty {
                run.heartRateSeries = samples.map {
                    HeartRatePoint(t: $0.date.timeIntervalSince(run.startDate), bpm: $0.bpm)
                }
                run.avgHeartRate = samples.map(\.bpm).reduce(0, +) / Double(samples.count)
                run.maxHeartRate = samples.map(\.bpm).max()
            }
            let kg = await HealthKitManager.shared.latestBodyMassKg() ?? 70
            run.calories = kg * (run.distance / 1000) * 1.036
            finishedRun = run
        }
    }
}
