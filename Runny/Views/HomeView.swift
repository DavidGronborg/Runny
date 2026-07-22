import SwiftUI

struct HomeView: View {
    @Environment(RunStore.self) private var store
    @AppStorage("useMetric") private var metric = true
    @State private var showSettings = false

    private var unitMeters: Double { Fmt.unitMeters(metric: metric) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    weeklyCard
                    recentSection
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
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Fmt.day(Date()).uppercased())
                    .font(.label(12))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)
                Text("Ready to run?")
                    .font(.display(32))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.surface))
                    .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var weeklyCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionLabel("This week")

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Fmt.distanceShort(store.thisWeekDistance, metric: metric))
                    .font(.display(64))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                Text(Fmt.distanceUnit(metric: metric))
                    .font(.heading(22))
                    .foregroundStyle(Theme.textSecondary)
            }

            HStack(spacing: 0) {
                weeklyStat(value: "\(store.thisWeek.count)", label: "Runs")
                divider
                weeklyStat(value: Fmt.duration(store.thisWeekDuration), label: "Time")
                divider
                weeklyStat(value: Fmt.pace(store.thisWeekAvgPace(unitMeters: unitMeters)),
                           label: "Avg pace")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(width: 1, height: 34)
    }

    private func weeklyStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.metric(18))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.label(10))
                .tracking(1.5)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent runs")
                .font(.heading(20))
                .foregroundStyle(.white)

            if store.runs.isEmpty {
                emptyState
            } else {
                VStack(spacing: 12) {
                    ForEach(store.runs.prefix(5)) { run in
                        NavigationLink(value: run) {
                            RunRow(run: run)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Theme.accent)
            Text("No runs yet")
                .font(.heading(17))
                .foregroundStyle(.white)
            Text("Hit the button below and get moving.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .card()
    }
}
