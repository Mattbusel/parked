import SwiftUI

/// Drives the real screens for the App Review recording (-demoAutoplay).
@MainActor
final class Autopilot {
    static let shared = Autopilot()
    static var on: Bool { ProcessInfo.processInfo.arguments.contains("-demoAutoplay") }
    private var running = false
    private func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }

    func run(_ store: Store, _ router: Router, _ pro: Pro) {
        guard Autopilot.on, !running else { return }
        running = true
        Task { @MainActor in
            await wait(4)
            router.sheet = .extend(store.current!.id); await wait(3)
            router.sheet = nil; await wait(1.5)
            withAnimation { router.tab = .map }; await wait(4.5)
            if let c = store.current { router.sheet = .photo(c.id); await wait(3.5); router.sheet = nil; await wait(1.2) }
            withAnimation { router.tab = .log }; await wait(3)
            if let p = store.past.first { router.sheet = .ticket(p.id); await wait(3.5); router.sheet = nil; await wait(1.2) }
            withAnimation { router.tab = .rules }; await wait(4)
            withAnimation { router.tab = .meter }; await wait(1.2)
            router.sheet = .park(Demo.draft(store)); await wait(4.5)
            router.sheet = nil; await wait(1.5)
            // The one purchase, as a reviewer would reach it.
            pro.paywall = .settings; await wait(5)
            pro.paywall = nil; await wait(1.5)
            try? Data("ok".utf8).write(to: URL.documentsDirectory.appending(path: "demo_done"))
        }
    }
}
