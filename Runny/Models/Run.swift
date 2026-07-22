import Foundation
import CoreLocation

/// A single recorded GPS point. `t` is the moving-time offset (pauses excluded)
/// and `d` the cumulative distance in meters at that point.
struct TrackPoint: Codable, Hashable {
    let lat: Double
    let lon: Double
    let t: TimeInterval
    let d: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct HeartRatePoint: Codable, Hashable {
    /// Seconds since the run started (wall clock).
    let t: TimeInterval
    let bpm: Double
}

struct Split: Identifiable {
    let index: Int
    let seconds: TimeInterval
    let meters: Double

    var id: Int { index }

    /// Pace in seconds per `unitMeters` of the split itself.
    func pace(unitMeters: Double) -> TimeInterval {
        guard meters > 0 else { return 0 }
        return seconds / (meters / unitMeters)
    }
}

struct Run: Codable, Identifiable, Hashable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    /// Moving time in seconds (pauses excluded).
    let duration: TimeInterval
    /// Distance in meters.
    let distance: Double
    let points: [TrackPoint]
    var heartRateSeries: [HeartRatePoint] = []
    var avgHeartRate: Double? = nil
    var maxHeartRate: Double? = nil
    var calories: Double? = nil

    var coordinates: [CLLocationCoordinate2D] { points.map(\.coordinate) }

    /// Average pace in seconds per `unitMeters` (1000 for km, 1609.34 for miles).
    func avgPace(unitMeters: Double) -> TimeInterval? {
        guard distance > 50 else { return nil }
        return duration / (distance / unitMeters)
    }

    var title: String {
        switch Calendar.current.component(.hour, from: startDate) {
        case 5..<11: return "Morning Run"
        case 11..<14: return "Lunch Run"
        case 14..<18: return "Afternoon Run"
        case 18..<22: return "Evening Run"
        default: return "Night Run"
        }
    }

    /// Splits computed on demand so the unit setting (km/mi) can change freely.
    func splits(unitMeters: Double) -> [Split] {
        guard let last = points.last, last.d > 0 else { return [] }
        var result: [Split] = []
        var nextMark = unitMeters
        var lastCrossTime: TimeInterval = 0
        var prev: TrackPoint?
        for p in points {
            while let pr = prev, pr.d < nextMark, p.d >= nextMark {
                let frac = (nextMark - pr.d) / max(p.d - pr.d, 0.001)
                let tCross = pr.t + frac * (p.t - pr.t)
                result.append(Split(index: result.count + 1,
                                    seconds: tCross - lastCrossTime,
                                    meters: unitMeters))
                lastCrossTime = tCross
                nextMark += unitMeters
            }
            prev = p
        }
        let remainingMeters = last.d - (nextMark - unitMeters)
        if remainingMeters > unitMeters * 0.05 {
            result.append(Split(index: result.count + 1,
                                seconds: last.t - lastCrossTime,
                                meters: remainingMeters))
        }
        return result
    }
}

extension Run {
    static var sample: Run {
        let points = stride(from: 0.0, through: 1800.0, by: 10.0).map { t in
            TrackPoint(lat: 55.6761 + t * 0.000012,
                       lon: 12.5683 + sin(t / 200) * 0.003,
                       t: t,
                       d: t * 2.9)
        }
        let hr = stride(from: 0.0, through: 1800.0, by: 30.0).map {
            HeartRatePoint(t: $0, bpm: 128 + 30 * sin($0 / 400) + Double(Int($0) % 7))
        }
        return Run(id: UUID(),
                   startDate: Date().addingTimeInterval(-4000),
                   endDate: Date().addingTimeInterval(-2200),
                   duration: 1800,
                   distance: 5220,
                   points: points,
                   heartRateSeries: hr,
                   avgHeartRate: 146,
                   maxHeartRate: 172,
                   calories: 402)
    }
}
