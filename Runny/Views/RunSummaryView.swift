import SwiftUI
import CoreLocation

/// Shown right after a run finishes: review the stats, then save or discard.
struct RunSummaryView: View {
    @Environment(RunStore.self) private var store

    let run: Run
    var locations: [CLLocation] = []
    var isNew: Bool
    var onDone: () -> Void

    @State private var showDiscardConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                RunStatsContent(run: run)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle(run.title)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if isNew { actionBar }
            }
            .confirmationDialog("Discard this run?",
                                isPresented: $showDiscardConfirm,
                                titleVisibility: .visible) {
                Button("Discard run", role: .destructive) { onDone() }
                Button("Keep", role: .cancel) {}
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                showDiscardConfirm = true
            } label: {
                Text("Discard")
                    .font(.heading(16))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        Capsule().fill(Theme.surface)
                            .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)

            Button {
                save()
            } label: {
                Text("Save run")
                    .font(.heading(16))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Capsule().fill(Theme.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Theme.bg.opacity(0.96))
    }

    private func save() {
        store.add(run)
        // Write to Apple Health in the background; local save is the source of truth.
        let runToSave = run
        let routeLocations = locations
        Task.detached {
            try? await HealthKitManager.shared.saveRun(runToSave, locations: routeLocations)
        }
        onDone()
    }
}
