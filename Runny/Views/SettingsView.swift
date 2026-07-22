import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RunStore.self) private var store
    @AppStorage("useMetric") private var metric = true

    @State private var healthConnected = HealthKitManager.shared.canSaveWorkouts
    @State private var requestingHealth = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    unitsCard
                    healthCard
                    lifetimeCard

                    Text("Runny 1.0")
                        .font(.label(11))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.heading(15))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private var unitsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Units")
            Picker("Units", selection: $metric) {
                Text("Kilometers").tag(true)
                Text("Miles").tag(false)
            }
            .pickerStyle(.segmented)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel("Apple Health")
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(healthConnected ? Theme.accent : Theme.textSecondary)
                        .frame(width: 8, height: 8)
                    Text(healthConnected ? "Connected" : "Not connected")
                        .font(.label(11))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Text("Runny reads your heart rate from Apple Health — your WHOOP band syncs it there through the WHOOP app — and saves finished runs back to Health with distance, calories and your route.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if HealthKitManager.shared.isAvailable {
                Button {
                    connectHealth()
                } label: {
                    HStack(spacing: 8) {
                        if requestingHealth {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "heart.text.square.fill")
                        }
                        Text(healthConnected ? "Review Health permissions" : "Connect Apple Health")
                    }
                    .font(.heading(15))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Theme.accent))
                }
                .buttonStyle(.plain)
                .disabled(requestingHealth)
            } else {
                Text("Health data isn't available on this device.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var lifetimeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("All time")
            HStack(spacing: 12) {
                StatTile(label: "Runs", value: "\(store.runs.count)")
                StatTile(label: "Distance",
                         value: Fmt.distanceShort(store.totalDistance, metric: metric),
                         unit: Fmt.distanceUnit(metric: metric))
                StatTile(label: "Time", value: Fmt.duration(store.totalDuration))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func connectHealth() {
        requestingHealth = true
        Task {
            try? await HealthKitManager.shared.requestAuthorization()
            healthConnected = HealthKitManager.shared.canSaveWorkouts
            requestingHealth = false
        }
    }
}
