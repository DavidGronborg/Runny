import Foundation
import Observation

/// Persists runs as JSON in the app's documents directory. Newest first.
@Observable
final class RunStore {
    private(set) var runs: [Run] = []

    private let fileURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("runs.json")
    }()

    init() {
        load()
    }

    func add(_ run: Run) {
        runs.insert(run, at: 0)
        runs.sort { $0.startDate > $1.startDate }
        save()
    }

    func update(_ run: Run) {
        guard let index = runs.firstIndex(where: { $0.id == run.id }) else { return }
        runs[index] = run
        save()
    }

    func delete(_ run: Run) {
        runs.removeAll { $0.id == run.id }
        save()
    }

    // MARK: - Stats

    var thisWeek: [Run] {
        runs.filter {
            Calendar.current.isDate($0.startDate, equalTo: Date(), toGranularity: .weekOfYear)
        }
    }

    var thisWeekDistance: Double { thisWeek.reduce(0) { $0 + $1.distance } }
    var thisWeekDuration: TimeInterval { thisWeek.reduce(0) { $0 + $1.duration } }

    func thisWeekAvgPace(unitMeters: Double) -> TimeInterval? {
        guard thisWeekDistance > 50 else { return nil }
        return thisWeekDuration / (thisWeekDistance / unitMeters)
    }

    var totalDistance: Double { runs.reduce(0) { $0 + $1.distance } }
    var totalDuration: TimeInterval { runs.reduce(0) { $0 + $1.duration } }

    /// Runs grouped by month, newest month first.
    var byMonth: [(month: Date, runs: [Run])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: runs) { run in
            calendar.date(from: calendar.dateComponents([.year, .month], from: run.startDate)) ?? run.startDate
        }
        return grouped
            .map { (month: $0.key, runs: $0.value.sorted { $0.startDate > $1.startDate }) }
            .sorted { $0.month > $1.month }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        runs = (try? JSONDecoder().decode([Run].self, from: data)) ?? []
    }

    private func save() {
        let snapshot = runs
        let url = fileURL
        DispatchQueue.global(qos: .utility).async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
