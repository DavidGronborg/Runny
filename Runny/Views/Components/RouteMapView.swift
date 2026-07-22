import SwiftUI
import MapKit

/// Static route preview: the run's trail with start/finish markers,
/// framed to fit the whole route.
struct RouteMapView: View {
    let coordinates: [CLLocationCoordinate2D]
    var interactive = false

    var body: some View {
        Map(initialPosition: .rect(fittedRect), interactionModes: interactive ? [.pan, .zoom] : []) {
            if coordinates.count > 1 {
                MapPolyline(coordinates: coordinates)
                    .stroke(Theme.accent,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            if let first = coordinates.first {
                Annotation("", coordinate: first) {
                    marker(color: Theme.accent)
                }
            }
            if coordinates.count > 1, let last = coordinates.last {
                Annotation("", coordinate: last) {
                    marker(color: .white)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
    }

    private func marker(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .overlay(Circle().stroke(Theme.bg, lineWidth: 3))
    }

    private var fittedRect: MKMapRect {
        guard !coordinates.isEmpty else { return MKMapRect.world }
        var rect = MKMapRect.null
        for coordinate in coordinates {
            let point = MKMapPoint(coordinate)
            rect = rect.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
        }
        // Give the route breathing room; guard against a degenerate single-point rect.
        let minSpan: Double = 1500
        if rect.width < minSpan || rect.height < minSpan {
            rect = rect.insetBy(dx: -minSpan / 2, dy: -minSpan / 2)
        }
        return rect.insetBy(dx: -rect.width * 0.18, dy: -rect.height * 0.18)
    }
}
