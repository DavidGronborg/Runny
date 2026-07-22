import SwiftUI
import Charts

struct HeartRateChart: View {
    let run: Run

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel("Heart rate")
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.heart)
                    Text("via Apple Health")
                        .font(.label(10))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            if run.heartRateSeries.isEmpty {
                VStack(spacing: 8) {
                    Text("No heart-rate data yet")
                        .font(.heading(15))
                        .foregroundStyle(.white)
                    Text("WHOOP syncs to Apple Health in batches — check back once it has synced.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                chart

                HStack(spacing: 24) {
                    if let avg = run.avgHeartRate {
                        hrStat(label: "Avg", value: Int(avg))
                    }
                    if let max = run.maxHeartRate {
                        hrStat(label: "Max", value: Int(max))
                    }
                    Spacer()
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var chart: some View {
        Chart(run.heartRateSeries, id: \.t) { point in
            AreaMark(x: .value("Minutes", point.t / 60),
                     y: .value("BPM", point.bpm))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(colors: [Theme.heart.opacity(0.35), Theme.heart.opacity(0.02)],
                                   startPoint: .top,
                                   endPoint: .bottom)
                )
            LineMark(x: .value("Minutes", point.t / 60),
                     y: .value("BPM", point.bpm))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .foregroundStyle(Theme.heart)
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine().foregroundStyle(Theme.stroke)
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text("\(Int(minutes))m")
                            .font(.label(10))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Theme.stroke)
                AxisValueLabel {
                    if let bpm = value.as(Double.self) {
                        Text("\(Int(bpm))")
                            .font(.label(10))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .frame(height: 160)
    }

    private var yDomain: ClosedRange<Double> {
        let values = run.heartRateSeries.map(\.bpm)
        let low = (values.min() ?? 60) - 10
        let high = (values.max() ?? 180) + 10
        return max(30, low)...high
    }

    private func hrStat(label: String, value: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(label.uppercased())
                .font(.label(10))
                .tracking(1)
                .foregroundStyle(Theme.textSecondary)
            Text("\(value)")
                .font(.metric(17))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text("bpm")
                .font(.label(10))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
