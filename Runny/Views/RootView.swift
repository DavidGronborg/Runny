import SwiftUI

struct RootView: View {
    enum Tab {
        case home, history
    }

    @State private var tab: Tab = .home
    @State private var showRun = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .home: HomeView()
                case .history: HistoryView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
        .background(Theme.bg.ignoresSafeArea())
        .fullScreenCover(isPresented: $showRun) {
            ActiveRunView()
        }
    }

    private var tabBar: some View {
        HStack(spacing: 44) {
            tabButton(.home, icon: "house.fill")
            startButton
            tabButton(.history, icon: "calendar")
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Theme.surface.opacity(0.96))
                .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
                .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
        )
        .padding(.bottom, 6)
    }

    private func tabButton(_ target: Tab, icon: String) -> some View {
        Button {
            tab = target
        } label: {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tab == target ? Theme.accent : Theme.textSecondary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

    private var startButton: some View {
        Button {
            showRun = true
        } label: {
            Image(systemName: "figure.run")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Theme.accent))
                .shadow(color: Theme.accent.opacity(0.45), radius: 14, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RootView()
        .environment(RunStore())
        .preferredColorScheme(.dark)
}
