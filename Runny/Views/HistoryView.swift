import SwiftUI

struct HistoryView: View {
    @Environment(RunStore.self) private var store
    @AppStorage("useMetric") private var metric = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("History")
                        .font(.display(32))
                        .foregroundStyle(.white)

                    if store.runs.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.byMonth, id: \.month) { group in
                            monthSection(group.month, runs: group.runs)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationDestination(for: Run.self) { run in
                RunDetailView(run: run)
            }
        }
    }

    private func monthSection(_ month: Date, runs: [Run]) -> some View {
        let totalMeters = runs.reduce(0) { $0 + $1.distance }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(Fmt.month(month))
                Spacer()
                Text("\(Fmt.distanceShort(totalMeters, metric: metric)) \(Fmt.distanceUnit(metric: metric))")
                    .font(.label(12))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
            }

            VStack(spacing: 12) {
                ForEach(runs) { run in
                    NavigationLink(value: run) {
                        RunRow(run: run)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Theme.accent)
            Text("Nothing here yet")
                .font(.heading(17))
                .foregroundStyle(.white)
            Text("Your finished runs will show up here.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .card()
    }
}
