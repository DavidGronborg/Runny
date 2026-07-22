import SwiftUI

struct RunDetailView: View {
    @Environment(RunStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State var run: Run
    @State private var showDeleteConfirm = false
    @State private var syncingHeartRate = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                RunStatsContent(run: run)

                if run.heartRateSeries.isEmpty && HealthKitManager.shared.isAvailable {
                    syncHeartRateButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(run.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Theme.danger)
                }
            }
        }
        .confirmationDialog("Delete this run?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete run", role: .destructive) {
                store.delete(run)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var syncHeartRateButton: some View {
        Button {
            syncHeartRate()
        } label: {
            HStack(spacing: 8) {
                if syncingHeartRate {
                    ProgressView().tint(.black)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath.heart.fill")
                }
                Text("Sync heart rate from Health")
            }
            .font(.heading(15))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Capsule().fill(Theme.accent))
        }
        .buttonStyle(.plain)
        .disabled(syncingHeartRate)
    }

    private func syncHeartRate() {
        syncingHeartRate = true
        Task {
            let samples = await HealthKitManager.shared.heartRateSamples(from: run.startDate,
                                                                         to: run.endDate)
            if !samples.isEmpty {
                var updated = run
                updated.heartRateSeries = samples.map {
                    HeartRatePoint(t: $0.date.timeIntervalSince(run.startDate), bpm: $0.bpm)
                }
                updated.avgHeartRate = samples.map(\.bpm).reduce(0, +) / Double(samples.count)
                updated.maxHeartRate = samples.map(\.bpm).max()
                run = updated
                store.update(updated)
            }
            syncingHeartRate = false
        }
    }
}
