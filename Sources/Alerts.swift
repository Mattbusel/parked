import Foundation
import UserNotifications

/// Local notifications only: "head back now", "meter runs out", and the street rules.
@MainActor
final class Alerts: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Alerts()
    private let center = UNUserNotificationCenter.current()
    var demo = false

    func setUp() { center.delegate = self }

    /// Asks the first time something needs a notification, never on launch.
    func ask() async -> Bool {
        if demo { return true }
        let s = await center.notificationSettings()
        switch s.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default: return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    func schedule(_ s: Session, vehicle: Vehicle?, settings: Settings) {
        guard !demo else { return }
        cancel(s.id)
        guard let expires = s.expires, s.isActive else { return }
        let name = vehicle?.name ?? "the car"
        Task {
            guard await ask() else { return }
            let leave = expires.addingTimeInterval(-TimeInterval(s.walkMins * 60))
            let warn = expires.addingTimeInterval(-TimeInterval(settings.warnBefore * 60))
            if leave > Date().addingTimeInterval(30) {
                add("\(s.id)-leave", at: leave, title: "Head back to \(name) now",
                    body: "The meter runs out at \(Fmt.clock(expires)). It's about a \(s.walkMins) min walk to \(s.shortPlace).")
            }
            if settings.warnBefore > 0, abs(warn.timeIntervalSince(leave)) > 120, warn > Date().addingTimeInterval(30) {
                add("\(s.id)-warn", at: warn, title: "\(settings.warnBefore) minutes left on the meter",
                    body: "\(name) at \(s.shortPlace) runs out at \(Fmt.clock(expires)).")
            }
            if expires > Date() {
                add("\(s.id)-out", at: expires, title: "The meter just ran out",
                    body: "\(name) at \(s.shortPlace). Open Parked to add time or find the car.")
            }
        }
    }

    func cancel(_ id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: ["\(id)-leave", "\(id)-warn", "\(id)-out"])
    }

    private func add(_ id: String, at date: Date, title: String, body: String) {
        let c = UNMutableNotificationContent()
        c.title = title; c.body = body; c.sound = .default
        c.interruptionLevel = .timeSensitive
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        center.add(UNNotificationRequest(identifier: id, content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }

    /// Weekly repeating reminders for every rule that is on.
    func scheduleRules(_ rules: [Rule]) {
        guard !demo else { return }
        Task {
            let pending = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("rule-") })
            guard rules.contains(where: \.on), await ask() else { return }
            for r in rules where r.on {
                for day in r.days {
                    let before = r.start - r.remindBefore
                    if r.remindBefore > 0 {
                        var dayOf = day, m = before
                        if m < 0 { m += 24 * 60; dayOf = day == 1 ? 7 : day - 1 }
                        weekly("rule-\(r.id)-\(day)-b", weekday: dayOf, minute: m, title: "\(r.name) at \(Rule.clock(r.start))",
                               body: r.place.isEmpty ? "Move the car before \(Rule.clock(r.start))." : "Move the car off \(r.place) before \(Rule.clock(r.start)).")
                    }
                    if r.eveningBefore {
                        weekly("rule-\(r.id)-\(day)-e", weekday: day == 1 ? 7 : day - 1, minute: 20 * 60, title: "\(r.name) tomorrow",
                               body: "\(Rule.clock(r.start))–\(Rule.clock(r.end))\(r.place.isEmpty ? "" : " on \(r.place)"). Park somewhere else tonight?")
                    }
                }
            }
        }
    }

    private func weekly(_ id: String, weekday: Int, minute: Int, title: String, body: String) {
        let c = UNMutableNotificationContent()
        c.title = title; c.body = body; c.sound = .default
        var comps = DateComponents(); comps.weekday = weekday; comps.hour = minute / 60; comps.minute = minute % 60
        center.add(UNNotificationRequest(identifier: id, content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
