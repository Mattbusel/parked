import SwiftUI
import UIKit
import CoreLocation

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        MainActor.assumeIsolated { Alerts.shared.setUp() }
        return true
    }
}

@main
struct ParkedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store: Store
    @State private var router: Router
    @State private var pro: Pro
    @Environment(\.scenePhase) private var phase

    init() {
        let a = ProcessInfo.processInfo.arguments
        let demo = a.contains("-shot") || a.contains("-demoAutoplay")
        let s = Store(demo: demo)
        _store = State(initialValue: s)
        let shot = a.firstIndex(of: "-shot").flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil }
        let p: Pro
        if shot == "paywall" { p = Pro(forced: false); p.paywall = .live }
        else if demo { p = Pro(forced: true) }
        else { p = Pro() }
        _pro = State(initialValue: p)
        _router = State(initialValue: Router())
        if demo {
            Locator.shared.demo = Demo.you
            Alerts.shared.demo = true
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView().environment(store).environment(router).environment(pro)
                .preferredColorScheme(.dark).tint(Curb.paint)
                .onAppear { router.applyShotArgs(store); Autopilot.shared.run(store, router, pro) }
        }
        .onChange(of: phase) { _, p in
            if p == .active { Locator.shared.startIfAllowed() }
            if p == .background { Locator.shared.stop() }
        }
    }
}

enum Tab: String, CaseIterable, Identifiable {
    case meter, map, log, rules
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .meter: return "gauge.with.needle.fill"
        case .map: return "map.fill"
        case .log: return "ticket.fill"
        case .rules: return "signpost.right.fill"
        }
    }
}

enum Sheet: Identifiable {
    case park(Session), photo(UUID), ticket(UUID), rule(Rule), garage(Garage), vehicle(Vehicle), extend(UUID)
    var id: String {
        switch self {
        case .park(let s): return "park-\(s.id)"
        case .photo(let id): return "photo-\(id)"
        case .ticket(let id): return "ticket-\(id)"
        case .rule(let r): return "rule-\(r.id)"
        case .garage(let g): return "garage-\(g.id)"
        case .vehicle(let v): return "vehicle-\(v.id)"
        case .extend(let id): return "extend-\(id)"
        }
    }
}

@MainActor
@Observable
final class Router {
    var tab: Tab = .meter
    var sheet: Sheet? = nil

    func applyShotArgs(_ s: Store) {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-shot"), i + 1 < a.count else { return }
        switch a[i + 1] {
        case "map": tab = .map
        case "park": sheet = .park(Demo.draft(s))
        case "photo": if let c = s.current { sheet = .photo(c.id) }
        case "history": tab = .log
        case "rules": tab = .rules
        default: break
        }
    }

    /// A fresh session for the chosen car, filled in from a garage if one was picked.
    func newPark(_ s: Store, garage: Garage? = nil) {
        var n = Session(vehicleID: s.vehicle.id, start: s.now, walkMins: s.db.settings.walkMins)
        if let g = garage {
            n.garageID = g.id; n.spot = g.spot; n.address = g.address.isEmpty ? g.name : g.address
            n.level = g.level; n.bay = g.bay; n.note = g.note
            if g.minutes > 0 { n.expires = s.now.addingTimeInterval(TimeInterval(g.minutes * 60)) }
            if let r = g.rate, g.minutes > 0 { n.cost = (r * Double(g.minutes) / 60 * 100).rounded() / 100 }
        }
        sheet = .park(n)
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro

    var body: some View {
        @Bindable var router = router
        @Bindable var pro = pro
        ZStack(alignment: .bottom) {
            Asphalt()
            Group {
                switch router.tab {
                case .meter: MeterView()
                case .map: MapTab()
                case .log: LogView()
                case .rules: RulesView()
                }
            }
            .transition(.opacity)
            RoadBar(selection: $router.tab) {
                if let c = store.current, router.tab != .map, c.spot != nil {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { router.tab = .map }
                } else if store.current == nil {
                    router.newPark(store)
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { router.tab = .meter }
                }
            }
        }
        .sheet(item: $router.sheet) { sheet in
            Group {
                switch sheet {
                case .park(let s): ParkSheet(draft: s)
                case .photo(let id): PhotoView(id: id)
                case .ticket(let id): TicketDetail(id: id)
                case .rule(let r): RuleEditor(rule: r)
                case .garage(let g): GarageEditor(garage: g)
                case .vehicle(let v): VehicleEditor(vehicle: v)
                case .extend(let id): ExtendSheet(id: id).presentationDetents([.height(360)])
                }
            }
            .presentationBackground(Curb.asphalt).presentationCornerRadius(32)
            .environment(store).environment(router).environment(pro)
        }
        .overlay {
            // A second presenter, so the paywall can come up whatever else is showing.
            Color.clear.allowsHitTesting(false)
                .sheet(item: $pro.paywall) { why in
                    PaywallView(reason: why).environment(pro).presentationBackground(Curb.asphalt).presentationCornerRadius(32)
                }
        }
        .onAppear { Locator.shared.startIfAllowed() }
    }
}

/// The tab bar is a strip of road: a dashed centre line, stencilled labels, and a painted
/// parking bay around the chosen tab. The P in the middle parks, or walks you to the car.
struct RoadBar: View {
    @Binding var selection: Tab
    var center: () -> Void
    @Environment(Store.self) private var store
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            item(.meter); item(.map)
            Button(action: center) {
                ZStack {
                    PSign(size: 58)
                    if store.current != nil {
                        Circle().fill(Curb.go).frame(width: 14, height: 14).overlay(Circle().strokeBorder(Curb.asphalt, lineWidth: 2.5))
                            .offset(x: 25, y: -25)
                    }
                }
                .offset(y: -14)
            }
            .buttonStyle(Press())
            .frame(width: 84)
            .accessibilityLabel(store.current == nil ? "Park here" : "Find the car")
            item(.log); item(.rules)
        }
        .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 2)
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26, style: .continuous)
                    .fill(Curb.asphalt2).ignoresSafeArea(edges: .bottom)
                    .shadow(color: .black.opacity(0.5), radius: 20, y: -4)
                RoadDash(color: Curb.paint.opacity(0.55)).frame(height: 2).padding(.horizontal, 40).padding(.top, 0.5).mask(
                    LinearGradient(colors: [.clear, .black, .black, .clear], startPoint: .leading, endPoint: .trailing))
            }
        }
    }

    func item(_ t: Tab) -> some View {
        Button {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) { selection = t }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: t.icon).font(.system(size: 18, weight: .bold))
                Text(t.title.uppercased()).font(.sign(11, .heavy)).tracking(1.2)
            }
            .foregroundStyle(selection == t ? Curb.paint : Curb.faint)
            .frame(maxWidth: .infinity).frame(height: 58)
            .background {
                if selection == t { Bay().stroke(Curb.paint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round)).padding(.horizontal, 12).padding(.vertical, 2).matchedGeometryEffect(id: "bay", in: ns) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// A parking bay painted on the road: two sides and a back line.
struct Bay: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        return p
    }
}
