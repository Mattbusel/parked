import Foundation
import CoreLocation
import MapKit

/// Where the phone is. Asks for when-in-use permission the first time you park, never before.
@MainActor
@Observable
final class Locator: NSObject, CLLocationManagerDelegate {
    static let shared = Locator()

    private(set) var location: CLLocation?
    private(set) var status: CLAuthorizationStatus
    private(set) var heading: Double = 0
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var waiters: [CheckedContinuation<CLLocation?, Never>] = []
    @ObservationIgnored var demo: CLLocation?

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 3
    }

    var denied: Bool { status == .denied || status == .restricted }
    var allowed: Bool { status == .authorizedWhenInUse || status == .authorizedAlways }

    /// Start following the phone, asking first if needed.
    func start() {
        if let demo { location = demo; return }
        switch status {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
        default: break
        }
    }

    /// Only keep following while something on screen needs it.
    func startIfAllowed() { if allowed || demo != nil { start() } }
    func stop() { manager.stopUpdatingLocation(); manager.stopUpdatingHeading() }

    /// A good fix, waiting up to `timeout` seconds for one within 25 m.
    func fix(timeout: Double = 8) async -> CLLocation? {
        if let demo { return demo }
        if let l = location, l.horizontalAccuracy >= 0, l.horizontalAccuracy <= 25, -l.timestamp.timeIntervalSinceNow < 10 { return l }
        start()
        let got: CLLocation? = await withCheckedContinuation { c in
            waiters.append(c)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(timeout))
                self.flush()
            }
        }
        return got ?? location
    }

    private func flush() {
        let w = waiters; waiters = []
        for c in w { c.resume(returning: location) }
    }

    /// A street address for a spot, from Apple's geocoder.
    func address(for l: CLLocation) async -> String {
        if demo != nil { return "412 N Wells St" }
        guard let p = try? await CLGeocoder().reverseGeocodeLocation(l).first else { return "" }
        let street = [p.subThoroughfare, p.thoroughfare].compactMap { $0 }.joined(separator: " ")
        if !street.isEmpty { return street }
        return p.name ?? p.locality ?? ""
    }

    func distance(to spot: Spot?) -> Double? {
        guard let spot, let location else { return nil }
        return location.distance(from: spot.location)
    }

    // MARK: delegate

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let s = m.authorizationStatus
        Task { @MainActor in
            self.status = s
            if s == .authorizedWhenInUse || s == .authorizedAlways { self.start() } else if s == .denied { self.flush() }
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last else { return }
        Task { @MainActor in
            self.location = l
            if l.horizontalAccuracy >= 0 && l.horizontalAccuracy <= 25 { self.flush() }
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateHeading h: CLHeading) {
        let v = h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading
        Task { @MainActor in self.heading = v }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.flush() }
    }
}

enum Directions {
    /// Hand the walk to Apple Maps.
    static func walk(to s: Session, name: String) {
        guard let spot = s.spot else { return }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: spot.coordinate))
        item.name = name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}
