import ActivityKit
import Foundation

/// Parked Pro: the meter counting down on the Lock Screen and in the Dynamic Island.
@MainActor
enum LiveMeter {
    static var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    static func start(_ s: Session, vehicle: Vehicle, leaveBy: Date?) {
        guard enabled, let expires = s.expires, expires > Date() else { return }
        end(s.id)
        let attrs = MeterAttributes(session: s.id.uuidString, vehicle: vehicle.name, place: s.shortPlace, level: s.level, paint: vehicle.paint)
        let state = MeterAttributes.ContentState(started: s.start, expires: expires, leaveBy: leaveBy ?? expires)
        let content = ActivityContent(state: state, staleDate: expires.addingTimeInterval(15 * 60))
        do {
            _ = try Activity<MeterAttributes>.request(attributes: attrs, content: content, pushType: nil)
        } catch { print("live activity failed", error) }
    }

    static func update(_ s: Session, leaveBy: Date?) {
        guard let expires = s.expires, let a = activity(s.id) else { return }
        let state = MeterAttributes.ContentState(started: s.start, expires: expires, leaveBy: leaveBy ?? expires)
        Task { await a.update(ActivityContent(state: state, staleDate: expires.addingTimeInterval(15 * 60))) }
    }

    static func end(_ id: UUID) {
        guard let a = activity(id) else { return }
        Task { await a.end(nil, dismissalPolicy: .immediate) }
    }

    static func endAll() {
        for a in Activity<MeterAttributes>.activities { Task { await a.end(nil, dismissalPolicy: .immediate) } }
    }

    static func isRunning(_ id: UUID) -> Bool { activity(id) != nil }

    private static func activity(_ id: UUID) -> Activity<MeterAttributes>? {
        Activity<MeterAttributes>.activities.first(where: { $0.attributes.session == id.uuidString })
    }
}
