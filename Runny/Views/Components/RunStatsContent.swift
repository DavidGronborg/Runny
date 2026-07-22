import SwiftUI

/// The shared body of the post-run summary and the history detail screen:
/// route map, headline stats, splits and heart rate.
struct RunStatsContent: View {
    let run: Run
    @AppStorage("useMetric") private var metric = true

    private var unitMeters: Double { Fmt.unitMeters(metric: metric) }

    var body: some View {
        VStack(spacing: 20) {
            if run.coordinates.count > 1 {
                RouteMapView(coordinates: run.coordinates)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Theme.stroke, lineWidth: 1)
                    )
            }

            headline

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                      spacing: 12) {
                StatTile(label: "Time", value: Fmt.duration(run.duration))
                StatTile(label: "Avg pace",
                         value: Fmt.pace(run.avgPace(unitMeters: unitMeters)),
                         unit: Fmt.paceUnit(metric: metric))
                StatTile(label: "Calories",
                         value: run.calories.map { "\(Int($0))" } ?? "--",
                         unit: "kcal")
                StatTile(label: "Avg HR",
                         value: run.avgHeartRate.map { "\(Int($0))" } ?? "--",
                         unit: "bpm",
                         tint: run.avgHeartRate != nil ? Theme.heart : Theme.textSecondary)
                StatTile(label: "Max HR",
                         value: run.maxHeartRate.map { "\(Int($0))" } ?? "--",
                         unit: "bpm",
                         tint: run.maxHeartRate != nil ? Theme.heart : Theme.textSecondary)
                StatTile(label: "Elapsed",
                         value: Fmt.duration(run.endDate.timeIntervalSince(run.startDate)))
            }

            SplitsView(run: run)

            HeartRateChart(run: run)
        }
    }

    private var headline: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Fmt.distance(run.distance, metric: metric))
                    .font(.display(58))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(Fmt.distanceUnit(metric: metric))
                    .font(.heading(20))
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(Fmt.shortDate(run.startDate))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 4)
    }
}
