import Foundation
import CoreLocation
import Observation

/// Records a run with Core Location: filtered GPS trail, moving time,
/// distance and a smoothed current pace.
@Observable
final class RunTracker: NSObject, CLLocationManagerDelegate {
    enum State: Equatable {
        case idle, running, paused, finished
    }

    var state: State = .idle
    var distance: Double = 0
    var elapsed: TimeInterval = 0
    /// Smoothed current pace in seconds per kilometer, nil until reliable.
    var currentPaceSecPerKm: TimeInterval?
    var coordinates: [CLLocationCoordinate2D] = []
    var horizontalAccuracy: Double?
    var authorizationDenied = false

    private(set) var points: [TrackPoint] = []
    private(set) var rawLocations: [CLLocation] = []
    private(set) var startDate: Date?

    private let manager = CLLocationManager()
    private var timer: Timer?
    private var segmentStart: Date?
    private var accumulated: TimeInterval = 0
    private var lastLocation: CLLocation?
    private var recentSamples: [(t: TimeInterval, d: Double)] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .fitness
        manager.distanceFilter = 3
        manager.pausesLocationUpdatesAutomatically = false
    }

    /// Ask for permission and warm up the GPS fix before the run starts.
    func prepare() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
    }

    func start() {
        startDate = Date()
        segmentStart = Date()
        accumulated = 0
        distance = 0
        elapsed = 0
        points = []
        rawLocations = []
        coordinates = []
        recentSamples = []
        lastLocation = nil
        state = .running
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
        startTimer()
    }

    func pause() {
        guard state == .running else { return }
        accumulated = movingTime
        segmentStart = nil
        // Drop the anchor so the gap walked while paused isn't counted.
        lastLocation = nil
        recentSamples = []
        currentPaceSecPerKm = nil
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        segmentStart = Date()
        state = .running
    }

    /// Stops tracking and returns the finished run, or nil if nothing was recorded.
    func stop() -> Run? {
        timer?.invalidate()
        timer = nil
        accumulated = movingTime
        segmentStart = nil
        elapsed = accumulated
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        state = .finished
        guard let startDate, !points.isEmpty, distance > 10 else { return nil }
        return Run(id: UUID(),
                   startDate: startDate,
                   endDate: Date(),
                   duration: accumulated,
                   distance: distance,
                   points: points)
    }

    private var movingTime: TimeInterval {
        accumulated + (segmentStart.map { Date().timeIntervalSince($0) } ?? 0)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, self.state == .running else { return }
            self.elapsed = self.movingTime
            self.updateCurrentPace()
        }
    }

    private func updateCurrentPace() {
        let cutoff = elapsed - 30
        recentSamples.removeAll { $0.t < cutoff }
        guard let first = recentSamples.first, let last = recentSamples.last,
              last.t - first.t > 5, last.d - first.d > 8 else {
            currentPaceSecPerKm = nil
            return
        }
        currentPaceSecPerKm = (last.t - first.t) / (last.d - first.d) * 1000
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        authorizationDenied = status == .denied || status == .restricted
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            horizontalAccuracy = location.horizontalAccuracy
            guard state == .running,
                  location.horizontalAccuracy > 0,
                  location.horizontalAccuracy <= 25 else { continue }

            if let last = lastLocation {
                let delta = location.distance(from: last)
                let dt = location.timestamp.timeIntervalSince(last.timestamp)
                guard dt > 0 else { continue }
                // Discard implausible jumps (> ~43 km/h) — GPS noise, not running.
                guard delta / dt < 12 else { continue }
                distance += delta
            }
            lastLocation = location
            rawLocations.append(location)
            coordinates.append(location.coordinate)
            let t = movingTime
            points.append(TrackPoint(lat: location.coordinate.latitude,
                                     lon: location.coordinate.longitude,
                                     t: t,
                                     d: distance))
            recentSamples.append((t: t, d: distance))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient GPS errors are fine to ignore; tracking resumes on the next fix.
    }
}
