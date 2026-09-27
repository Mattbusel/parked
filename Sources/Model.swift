import Foundation
import CoreLocation
import SwiftUI
import UIKit

struct Vehicle: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var plate: String = ""
    var paint: Int = 0
}

struct Spot: Codable, Hashable {
    var lat: Double
    var lon: Double
    var accuracy: Double = 0
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
    var location: CLLocation { CLLocation(latitude: lat, longitude: lon) }
}

/// One time the car was left somewhere.
struct Session: Codable, Identifiable, Hashable {
    var id = UUID()
    var vehicleID: UUID
    var start: Date
    /// When the meter runs out. Nil when there is no meter, just a spot to remember.
    var expires: Date?
    var spot: Spot?
    var address: String = ""
    var level: String = ""
    var bay: String = ""
    var note: String = ""
    var photo: String? = nil
    var cost: Double? = nil
    /// How long the walk back is expected to take, used until the phone knows better.
    var walkMins: Int = 10
    var ended: Date? = nil
    var garageID: UUID? = nil

    var isActive: Bool { ended == nil }
    var place: String {
        let where_ = [level.isEmpty ? nil : "Level \(level)", bay.isEmpty ? nil : "Spot \(bay)"].compactMap { $0 }.joined(separator: " · ")
        if !where_.isEmpty && !address.isEmpty { return address + " · " + where_ }
        return address.isEmpty ? (where_.isEmpty ? "Pinned spot" : where_) : address
    }
    var shortPlace: String { address.isEmpty ? (level.isEmpty ? "Pinned spot" : "Level \(level)") : address }
}

/// A garage or lot you use often: one tap to park there.
struct Garage: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var spot: Spot? = nil
    var address: String = ""
    var level: String = ""
    var bay: String = ""
    var note: String = ""
    /// 0 means no meter.
    var minutes: Int = 0
    var rate: Double? = nil
}

/// A recurring restriction: street cleaning, a two-hour zone, alternate-side parking.
struct Rule: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String = "Street cleaning"
    var place: String = ""
    /// Calendar weekdays, 1 = Sunday.
    var days: Set<Int> = [3]
    var start: Int = 8 * 60
    var end: Int = 10 * 60
    var remindBefore: Int = 60
    var eveningBefore: Bool = true
    var on: Bool = true

    var dayText: String {
        let names = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        let d = days.sorted()
        if d == [2, 3, 4, 5, 6] { return "MON–FRI" }
        if d.count == 7 { return "EVERY DAY" }
        return d.map { names[($0 - 1) % 7] }.joined(separator: " ")
    }
    var timeText: String { "\(Rule.clock(start))–\(Rule.clock(end))" }
    static func clock(_ m: Int) -> String {
        let h = m / 60, mm = m % 60, h12 = h % 12 == 0 ? 12 : h % 12
        let ap = h < 12 ? "AM" : "PM"
        return mm == 0 ? "\(h12) \(ap)" : String(format: "%d:%02d %@", h12, mm, ap)
    }
    /// The next time this rule starts, from `now`.
    func next(after now: Date) -> Date? {
        let cal = Calendar.current
        var best: Date?
        for day in days {
            var c = DateComponents(); c.weekday = day; c.hour = start / 60; c.minute = start % 60
            if let d = cal.nextDate(after: now, matching: c, matchingPolicy: .nextTime) { if best == nil || d < best! { best = d } }
        }
        return best
    }
}

struct Settings: Codable, Hashable {
    var warnBefore: Int = 10
    var walkMins: Int = 10
    var live: Bool = true
}

struct DB: Codable {
    var vehicles: [Vehicle] = [Vehicle(name: "My car", paint: 1)]
    var sessions: [Session] = []
    var garages: [Garage] = []
    var rules: [Rule] = []
    var settings = Settings()
    var current: UUID? = nil
}

@MainActor
@Observable
final class Store {
    var db: DB
    let demo: Bool
    /// Screenshots run on a clock that starts at 9:41.
    private(set) var offset: TimeInterval = 0
    var now: Date { Date().addingTimeInterval(offset) }

    @ObservationIgnored private let url = URL.documentsDirectory.appending(path: "parked.json")
    static let photos = URL.documentsDirectory.appending(path: "photos")

    init(demo: Bool) {
        self.demo = demo
        if demo {
            db = DB()
            let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(9 * 3600 + 41 * 60)
            offset = start.timeIntervalSince(Date())
            Demo.fill(self)
        } else if let data = try? Data(contentsOf: url), let d = try? JSONDecoder().decode(DB.self, from: data) {
            db = d
        } else {
            db = DB()
        }
        if db.vehicles.isEmpty { db.vehicles = [Vehicle(name: "My car", paint: 1)] }
        if db.current == nil || !db.vehicles.contains(where: { $0.id == db.current }) { db.current = db.vehicles.first?.id }
    }

    func save() {
        guard !demo else { return }
        do {
            let data = try JSONEncoder().encode(db)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch { print("save failed", error) }
    }

    // MARK: vehicles

    var vehicle: Vehicle { db.vehicles.first(where: { $0.id == db.current }) ?? db.vehicles[0] }
    func vehicle(_ id: UUID) -> Vehicle? { db.vehicles.first(where: { $0.id == id }) }
    func select(_ v: Vehicle) { db.current = v.id; save() }
    func upsert(_ v: Vehicle) {
        if let i = db.vehicles.firstIndex(where: { $0.id == v.id }) { db.vehicles[i] = v } else { db.vehicles.append(v); db.current = v.id }
        save()
    }
    func remove(_ v: Vehicle) {
        guard db.vehicles.count > 1 else { return }
        for s in db.sessions where s.vehicleID == v.id && s.isActive { end(s) }
        db.vehicles.removeAll { $0.id == v.id }
        if db.current == v.id { db.current = db.vehicles.first?.id }
        save()
    }

    // MARK: sessions

    func active(_ vehicleID: UUID) -> Session? { db.sessions.last(where: { $0.vehicleID == vehicleID && $0.isActive }) }
    var current: Session? { active(vehicle.id) }
    var activeSessions: [Session] { db.sessions.filter(\.isActive) }
    var past: [Session] { db.sessions.filter { !$0.isActive }.sorted { $0.start > $1.start } }
    func session(_ id: UUID) -> Session? { db.sessions.first(where: { $0.id == id }) }

    func park(_ s: Session) {
        // One car can only be in one place.
        for old in db.sessions where old.vehicleID == s.vehicleID && old.isActive && old.id != s.id { end(old, silently: true) }
        if let i = db.sessions.firstIndex(where: { $0.id == s.id }) { db.sessions[i] = s } else { db.sessions.append(s) }
        save()
        Alerts.shared.schedule(s, vehicle: vehicle(s.vehicleID), settings: db.settings)
    }

    func update(_ s: Session) {
        guard let i = db.sessions.firstIndex(where: { $0.id == s.id }) else { return }
        db.sessions[i] = s
        save()
        if s.isActive { Alerts.shared.schedule(s, vehicle: vehicle(s.vehicleID), settings: db.settings) }
    }

    func end(_ s: Session, silently: Bool = false) {
        guard let i = db.sessions.firstIndex(where: { $0.id == s.id }) else { return }
        db.sessions[i].ended = now
        save()
        Alerts.shared.cancel(s.id)
        LiveMeter.end(s.id)
    }

    func extend(_ s: Session, minutes: Int) {
        guard let i = db.sessions.firstIndex(where: { $0.id == s.id }) else { return }
        let base = max(db.sessions[i].expires ?? now, now)
        db.sessions[i].expires = base.addingTimeInterval(TimeInterval(minutes * 60))
        save()
        let s2 = db.sessions[i]
        Alerts.shared.schedule(s2, vehicle: vehicle(s2.vehicleID), settings: db.settings)
    }

    func delete(_ s: Session) {
        if let p = s.photo { try? FileManager.default.removeItem(at: Store.photos.appending(path: p)) }
        db.sessions.removeAll { $0.id == s.id }
        save()
    }

    /// When to start walking back: the meter's end, less the walk.
    func leaveBy(_ s: Session, walk: TimeInterval?) -> Date? {
        guard let e = s.expires else { return nil }
        return e.addingTimeInterval(-(walk ?? TimeInterval(s.walkMins * 60)))
    }

    // MARK: garages and rules

    func upsert(_ g: Garage) {
        if let i = db.garages.firstIndex(where: { $0.id == g.id }) { db.garages[i] = g } else { db.garages.append(g) }
        save()
    }
    func remove(_ g: Garage) { db.garages.removeAll { $0.id == g.id }; save() }
    func upsert(_ r: Rule) {
        if let i = db.rules.firstIndex(where: { $0.id == r.id }) { db.rules[i] = r } else { db.rules.append(r) }
        save(); Alerts.shared.scheduleRules(db.rules)
    }
    func remove(_ r: Rule) { db.rules.removeAll { $0.id == r.id }; save(); Alerts.shared.scheduleRules(db.rules) }

    // MARK: photos

    func savePhoto(_ image: UIImage) -> String? {
        try? FileManager.default.createDirectory(at: Store.photos, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".jpg"
        let img = image.downscaled(to: 1800)
        guard let data = img.jpegData(compressionQuality: 0.82) else { return nil }
        do { try data.write(to: Store.photos.appending(path: name), options: .completeFileProtection); return name } catch { return nil }
    }

    @ObservationIgnored private var cache: [String: UIImage] = [:]
    func image(_ name: String?) -> UIImage? {
        guard let name else { return nil }
        if let c = cache[name] { return c }
        let img: UIImage?
        if name.hasPrefix("demo-") { img = Demo.photo(name) } else { img = UIImage(contentsOfFile: Store.photos.appending(path: name).path) }
        if let img { cache[name] = img }
        return img
    }

    // MARK: stats

    func spent(since: Date) -> Double { past.filter { $0.start >= since }.compactMap(\.cost).reduce(0, +) }
    func hours(since: Date) -> Double { past.filter { $0.start >= since }.reduce(0) { $0 + (($1.ended ?? $1.start).timeIntervalSince($1.start)) } / 3600 }
}

extension UIImage {
    func downscaled(to maxSide: CGFloat) -> UIImage {
        let s = max(size.width, size.height)
        guard s > maxSide else { return self }
        let k = maxSide / s
        let target = CGSize(width: size.width * k, height: size.height * k)
        let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
        return UIGraphicsImageRenderer(size: target, format: f).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}

/// Walking at an unhurried 4.8 km/h, with streets 30% longer than a straight line.
enum Walk {
    static func seconds(_ meters: Double) -> TimeInterval { meters * 1.3 / 1.33 }
    static func minutes(_ meters: Double) -> Int { max(1, Int((seconds(meters) / 60).rounded(.up))) }
}
