import SwiftUI

/// Per-kilometer (or mile) splits with pace bars; the fastest split pops in volt.
struct SplitsView: View {
    let run: Run
    @AppStorage("useMetric") private var metric = true

    private var unitMeters: Double { Fmt.unitMeters(metric: metric) }

    var body: some View {
        let splits = run.splits(unitMeters: unitMeters)
        if splits.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel("Splits")

                let paces = splits.map { $0.pace(unitMeters: unitMeters) }
                let fastest = paces.min() ?? 1

                VStack(spacing: 10) {
                    HStack {
                        Text(Fmt.distanceUnit(metric: metric).uppercased())
                            .frame(width: 34, alignment: .leading)
                        Text("PACE")
                            .frame(width: 52, alignment: .leading)
                        Spacer()
                    }
                    .font(.label(10))
                    .tracking(1.5)
                    .foregroundStyle(Theme.textSecondary)

                    ForEach(splits) { split in
                        let pace = split.pace(unitMeters: unitMeters)
                        let isFastest = pace <= fastest + 0.5 && splits.count > 1
                        let isPartial = split.meters < unitMeters * 0.95

                        HStack(spacing: 0) {
                            Text(isPartial
                                 ? String(format: "%.1f", split.meters / unitMeters)
                                 : "\(split.index)")
                                .font(.metric(14))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .frame(width: 34, alignment: .leading)

                            Text(Fmt.pace(pace))
                                .font(.metric(14))
                                .monospacedDigit()
                                .foregroundStyle(isFastest ? Theme.accent : .white)
                                .frame(width: 52, alignment: .leading)

                            GeometryReader { geo in
                                Capsule()
                                    .fill(isFastest ? Theme.accent : Theme.surfaceLight)
                                    .frame(width: max(12, geo.size.width * (fastest / max(pace, 1))))
                                    .frame(maxHeight: .infinity, alignment: .center)
                            }
                            .frame(height: 10)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }
}
