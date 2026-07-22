import SwiftUI

struct RunRow: View {
    let run: Run
    @AppStorage("useMetric") private var metric = true

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text(Fmt.weekday(run.startDate))
                    .font(.label(11))
                    .foregroundStyle(Theme.accent)
                Text("\(Calendar.current.component(.day, from: run.startDate))")
                    .font(.metric(18))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.surfaceLight)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(run.title)
                    .font(.heading(16))
                    .foregroundStyle(.white)
                HStack(spacing: 8) {
                    Text(Fmt.duration(run.duration))
                    if let avg = run.avgHeartRate {
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.heart)
                            Text("\(Int(avg))")
                        }
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(Fmt.distance(run.distance, metric: metric))
                        .font(.metric(18))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(Fmt.distanceUnit(metric: metric))
                        .font(.label(12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(Fmt.pace(run.avgPace(unitMeters: Fmt.unitMeters(metric: metric))) + Fmt.paceUnit(metric: metric))
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(16)
        .card(corner: 20)
    }
}
