import Foundation
import HealthKit
import CoreLocation

/// Bridges Runny and Apple Health.
///
/// Heart rate is *read* from Health — your WHOOP band writes its samples there
/// via the WHOOP app — and finished runs are *written* back as running workouts
/// with distance, calories and the GPS route attached.
final class HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?
    private let bpmUnit = HKUnit.count().unitDivided(by: .minute())

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// True once the user has granted permission to save workouts.
    var canSaveWorkouts: Bool {
        store.authorizationStatus(for: .workoutType()) == .sharingAuthorized
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        let share: Set<HKSampleType> = [
            .workoutType(),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
            HKSeriesType.workoutRoute(),
        ]
        let read: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.bodyMass),
        ]
        try await store.requestAuthorization(toShare: share, read: read)
    }

    // MARK: - Heart rate

    /// Streams the most recent heart-rate sample written to Health after `start`.
    /// WHOOP syncs in batches, so updates can trail live effort by a few minutes.
    func startHeartRateUpdates(from start: Date, handler: @escaping (Double) -> Void) {
        stopHeartRateUpdates()
        guard isAvailable else { return }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: [])
        let process: ([HKSample]?) -> Void = { [bpmUnit] samples in
            guard let latest = (samples as? [HKQuantitySample])?
                .max(by: { $0.endDate < $1.endDate }) else { return }
            let bpm = latest.quantity.doubleValue(for: bpmUnit)
            DispatchQueue.main.async { handler(bpm) }
        }

        let query = HKAnchoredObjectQuery(type: HKQuantityType(.heartRate),
                                          predicate: predicate,
                                          anchor: nil,
                                          limit: HKObjectQueryNoLimit) { _, samples, _, _, _ in
            process(samples)
        }
        query.updateHandler = { _, samples, _, _, _ in
            process(samples)
        }
        store.execute(query)
        heartRateQuery = query
    }

    func stopHeartRateUpdates() {
        if let heartRateQuery {
            store.stop(heartRateQuery)
        }
        heartRateQuery = nil
    }

    func heartRateSamples(from start: Date, to end: Date) async -> [(date: Date, bpm: Double)] {
        guard isAvailable else { return [] }
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: HKQuantityType(.heartRate),
                                      predicate: predicate,
                                      limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [sort]) { [bpmUnit] _, samples, _ in
                let result = (samples as? [HKQuantitySample])?.map {
                    (date: $0.startDate, bpm: $0.quantity.doubleValue(for: bpmUnit))
                } ?? []
                continuation.resume(returning: result)
            }
            store.execute(query)
        }
    }

    // MARK: - Body mass

    func latestBodyMassKg() async -> Double? {
        guard isAvailable else { return nil }
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: HKQuantityType(.bodyMass),
                                      predicate: nil,
                                      limit: 1,
                                      sortDescriptors: [sort]) { _, samples, _ in
                let kg = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            store.execute(query)
        }
    }

    // MARK: - Saving runs

    func saveRun(_ run: Run, locations: [CLLocation]) async throws {
        guard isAvailable, canSaveWorkouts else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: store,
                                       configuration: configuration,
                                       device: .local())
        let end = max(run.endDate, run.startDate.addingTimeInterval(1))
        try await builder.beginCollection(at: run.startDate)

        var samples: [HKSample] = []
        if run.distance > 0 {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.distanceWalkingRunning),
                quantity: HKQuantity(unit: .meter(), doubleValue: run.distance),
                start: run.startDate,
                end: end))
        }
        if let kcal = run.calories, kcal > 0 {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.activeEnergyBurned),
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                start: run.startDate,
                end: end))
        }
        if !samples.isEmpty {
            try await builder.addSamples(samples)
        }

        try await builder.endCollection(at: end)
        guard let workout = try await builder.finishWorkout() else { return }

        if !locations.isEmpty {
            let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: .local())
            try await routeBuilder.insertRouteData(locations)
            try await routeBuilder.finishRoute(with: workout, metadata: nil)
        }
    }
}
