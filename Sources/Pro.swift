import SwiftUI
import StoreKit

/// Parked Pro: one non-consumable. Parking, the photo, the meter, the "head back now"
/// notification and the map are free forever. Pro adds the Lock Screen countdown, more
/// cars, the full log, saved garages and street rules.
@MainActor
@Observable
final class Pro {
    static let productID = "com.mattbusel.parked.pro"
    /// How many past sessions the free log shows. Older ones are kept, never deleted.
    static let freeLog = 3

    enum Reason: String, Identifiable { case live, cars, log, garages, rules, settings; var id: String { rawValue } }

    private(set) var unlocked: Bool
    private(set) var product: Product?
    var busy = false
    var message: String?
    var paywall: Reason? = nil

    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private let key = "parked.pro.unlocked"
    @ObservationIgnored private let forced: Bool

    /// `forced` is for screenshots and the review recording, which must not touch StoreKit.
    init(forced: Bool? = nil) {
        self.forced = forced != nil
        if let forced { unlocked = forced; return }
        unlocked = UserDefaults.standard.bool(forKey: key)
        updates = Task { [weak self] in
            for await result in Transaction.updates { await self?.apply(result) }
        }
        Task { await refresh() }
    }

    var price: String { product?.displayPrice ?? "$2.99" }

    /// True when the action may go ahead; otherwise shows the paywall.
    @discardableResult
    func allow(_ why: Reason) -> Bool {
        if unlocked { return true }
        paywall = why
        return false
    }

    func refresh() async {
        guard !forced else { return }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        for await result in Transaction.currentEntitlements { await apply(result) }
    }

    func buy() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        guard let product else {
            message = "The App Store did not answer. Check your connection and try again."
            return
        }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await apply(result)
                if !unlocked { message = "Apple could not confirm the purchase. Try Restore in a minute." }
            case .pending:
                message = "Waiting for approval. Pro unlocks by itself once it is approved."
            case .userCancelled:
                break
            @unknown default:
                message = "Something unexpected happened. You were not charged."
            }
        } catch {
            message = "The purchase did not go through: \(error.localizedDescription)"
        }
    }

    func restore() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do { try await AppStore.sync() } catch {
            if let e = error as? StoreKitError, case .userCancelled = e { return }
            message = "Could not reach the App Store. Check your connection and try again."
            return
        }
        await refresh()
        message = unlocked ? "Pro is unlocked. Welcome back." : "No Pro purchase found on this Apple ID."
    }

    private func apply(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = result, t.productID == Pro.productID else { return }
        if t.revocationDate == nil { grant() } else { revoke() }
        await t.finish()
    }

    private func grant() {
        guard !unlocked else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { unlocked = true }
        paywall = nil
        UserDefaults.standard.set(true, forKey: key)
    }

    private func revoke() {
        unlocked = false
        UserDefaults.standard.set(false, forKey: key)
    }
}

// MARK: - Paywall

/// A yellow resident permit hanging off a rear-view mirror.
struct PaywallView: View {
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    let reason: Pro.Reason
    @State private var swing = false

    var body: some View {
        ZStack {
            Asphalt()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Stencil("Parked Pro", color: Curb.paint)
                        Spacer()
                        Knob(icon: "xmark", size: 36) { dismiss() }.accessibilityLabel("Close")
                    }
                    permit
                        .rotationEffect(.degrees(swing ? 3.5 : -3.5), anchor: .top)
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(headline).font(.sign(38)).foregroundStyle(Curb.chalk).fixedSize(horizontal: false, vertical: true)
                        Text("Parking, the photo, the meter, the map and the \"head back now\" alert stay free. Pro is for people who park a lot.")
                            .font(.body(14.5)).foregroundStyle(Curb.dim).fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        feature("lock.iphone", Curb.paint, "Countdown on the Lock Screen", "The meter ticks down on the Lock Screen and in the Dynamic Island, with your leave-by time.")
                        feature("car.2.fill", Curb.flag, "Every car in the family", "Each car keeps its own spot, meter and photo.")
                        feature("list.bullet.rectangle.portrait.fill", Curb.go, "The whole parking log", "Every spot, photo and receipt, with hours and money spent each month.")
                        feature("building.2.fill", Curb.blue, "Saved garages", "Work, the gym, the airport: park there with one tap, level and all.")
                        feature("calendar.badge.exclamationmark", Curb.chalk, "Street rules", "Street cleaning and alternate-side reminders the night before and the hour before.")
                    }
                    .slab(18, radius: 24)
                    VStack(spacing: 4) {
                        Text(pro.price).font(.meter(52)).foregroundStyle(Curb.chalk)
                        Text("ONE TIME · NO SUBSCRIPTION · FAMILY SHARING").font(.sign(12, .bold)).tracking(1.2).foregroundStyle(Curb.dim)
                    }
                    .frame(maxWidth: .infinity)
                    if let m = pro.message {
                        Text(m).font(.body(13, .semibold)).foregroundStyle(Curb.flag)
                            .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    }
                    PaintButton(title: pro.busy ? "One moment" : "Unlock Pro for \(pro.price)", icon: "lock.open.fill") {
                        Task { await pro.buy() }
                    }
                    .disabled(pro.busy)
                    HStack(spacing: 10) {
                        KerbButton(title: "Restore purchase", icon: "arrow.clockwise") { Task { await pro.restore() } }
                        KerbButton(title: "Not now") { dismiss() }
                    }
                    Text("Your spot, meter, photo and reminders keep working without Pro. Nothing you save is ever deleted.")
                        .font(.body(11.5)).foregroundStyle(Curb.faint).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 40)
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { swing = true } }
        .onChange(of: pro.unlocked) { _, now in if now { dismiss() } }
    }

    var headline: String {
        switch reason {
        case .live: return "Watch the meter from your Lock Screen."
        case .cars: return "Room for every car in the family."
        case .log: return "Every spot you've ever parked."
        case .garages: return "Your regular spots, one tap away."
        case .rules: return "Never get the street-cleaning ticket."
        case .settings: return "Park like a regular."
        }
    }

    /// The permit: a mirror hang tag with a hook, a hole and a big P.
    var permit: some View {
        VStack(spacing: 0) {
            // The hook over the mirror.
            Capsule().fill(Curb.dim).frame(width: 5, height: 26)
            ZStack(alignment: .top) {
                PermitShape().fill(Curb.paint)
                    .overlay(PermitShape().stroke(Curb.ink.opacity(0.9), lineWidth: 2.5).padding(8))
                    .shadow(color: Curb.paint.opacity(0.28), radius: 24, y: 10)
                Circle().fill(Curb.asphalt).frame(width: 30, height: 30).padding(.top, 18)
                VStack(spacing: 6) {
                    Spacer().frame(height: 62)
                    Text("RESIDENT").font(.sign(14, .heavy)).tracking(4).foregroundStyle(Curb.ink.opacity(0.7))
                    PSign(size: 64)
                    Text("PRO").font(.sign(44)).tracking(6).foregroundStyle(Curb.ink)
                    Text("PERMIT Nº 0001").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Curb.ink.opacity(0.65))
                    Hazard(width: 9).frame(height: 14).clipShape(RoundedRectangle(cornerRadius: 3)).padding(.horizontal, 26).padding(.top, 8)
                }
            }
            .frame(width: 190, height: 300)
        }
    }

    func feature(_ icon: String, _ tint: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(tint)
                .frame(width: 40, height: 40).background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(tint.opacity(0.14)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.sign(18, .bold)).foregroundStyle(Curb.chalk)
                Text(detail).font(.body(13)).foregroundStyle(Curb.dim).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A hang tag: rounded rectangle with a domed top.
struct PermitShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let dome = r.width * 0.5
        p.move(to: CGPoint(x: r.minX, y: r.minY + dome))
        p.addArc(center: CGPoint(x: r.midX, y: r.minY + dome), radius: r.width / 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 18))
        p.addQuadCurve(to: CGPoint(x: r.maxX - 18, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + 18, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - 18), control: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// In Settings: what Pro adds, or a thank-you. Restore lives here too.
struct ProCard: View {
    @Environment(Pro.self) private var pro
    var body: some View {
        if pro.unlocked {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(Curb.go)
                Text("Parked Pro is unlocked. Thank you.").font(.sign(16, .bold)).foregroundStyle(Curb.chalk)
                Spacer()
            }
            .slab(14, radius: 18)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    PSign(size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PARKED PRO").font(.sign(20)).foregroundStyle(Curb.paint)
                        Text("Lock Screen countdown, every car, the full log, garages and street rules. \(pro.price) once.")
                            .font(.body(12.5)).foregroundStyle(Curb.dim).fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack(spacing: 10) {
                    KerbButton(title: "See Pro", icon: "sparkles", tint: Curb.paint) { pro.paywall = .settings }
                    KerbButton(title: "Restore", icon: "arrow.clockwise") { Task { await pro.restore() } }
                }
                if let m = pro.message, pro.paywall == nil {
                    Text(m).font(.body(12, .semibold)).foregroundStyle(Curb.flag)
                }
            }
            .slab(16, radius: 22)
        }
    }
}
