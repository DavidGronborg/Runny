import SwiftUI

struct StatTile: View {
    let label: String
    let value: String
    var unit: String?
    var tint: Color = .white

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.metric(22))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                if let unit {
                    Text(unit)
                        .font(.label(12))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Text(label.uppercased())
                .font(.label(10))
                .tracking(1.5)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.surfaceLight)
        )
    }
}
