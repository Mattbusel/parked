import SwiftUI

/// Home: the car you're looking at, its meter, when to leave, and where exactly it is.
struct MeterView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                if store.db.vehicles.count > 1 { CarStrip() }
                if let s = store.current {
                    ActiveMeter(session: s).id(s.id)
                } else {
                    EmptyMeter()
                }
            }
            .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 130)
        }
    }

    var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Parked").font(.sign(40)).foregroundStyle(Curb.chalk)
            Spacer()
            if store.db.vehicles.count == 1 {
                HStack(spacing: 8) {
                    CarGlyph(color: Curb.cars[store.vehicle.paint % Curb.cars.count], size: 22)
                    Text(store.vehicle.name).font(.sign(15, .bold)).foregroundStyle(Curb.dim)
                }
                .onTapGesture { router.sheet = .vehicle(store.vehicle) }
            }
        }
    }
}

/// When there's more than one car: pick which one you're looking at.
struct CarStrip: View {
    @Environment(Store.self) private var store
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.db.vehicles) { v in
                    let on = v.id == store.vehicle.id
                    let parked = store.active(v.id) != nil
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { store.select(v) }
                    } label: {
                        HStack(spacing: 8) {
                            CarGlyph(color: Curb.cars[v.paint % Curb.cars.count], size: 22)
                            Text(v.name).font(.sign(15, .bold))
                            if parked { Circle().fill(Curb.go).frame(width: 7, height: 7) }
                        }
                        .foregroundStyle(on ? Curb.ink : Curb.chalk)
                        .padding(.horizontal, 14).frame(height: 40)
                        .background(Capsule().fill(on ? Curb.paint : Curb.slab))
                        .overlay(Capsule().strokeBorder(on ? .clear : Curb.line))
                    }
                    .buttonStyle(Press())
                    .sensoryFeedback(.selection, trigger: on)
                }
            }
        }
        .scrollClipDisabled()
    }
}

// MARK: - Active

struct ActiveMeter: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    let session: Session
    @State private var confirmEnd = false

    var body: some View {
        let loc = Locator.shared
        let dist = loc.distance(to: session.spot)
        let walk = dist.map { Walk.seconds($0) }
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Circle().fill(Curb.go).frame(width: 8, height: 8)
                Stencil("Parked \(Fmt.clock(session.start))", color: Curb.go)
                Spacer()
                if session.expires != nil { LiveBadge(session: session, walk: walk) }
            }
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let now = store.now
                if let e = session.expires {
                    let total = max(60, e.timeIntervalSince(session.start))
                    let left = e.timeIntervalSince(now)
                    VStack(spacing: 6) {
                        MeterHead(total: total, left: left)
                            .frame(height: 250)
                            .padding(.top, 4)
                        countdown(left)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Stopwatch(elapsed: now.timeIntervalSince(session.start))
                }
            }
            if let e = session.expires {
                leavePlate(expires: e, walk: walk, dist: dist)
            }
            actions
            WhereCards(session: session)
        }
        .confirmationDialog("Back at the car?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("I'm back. End parking") {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { store.end(session) }
            }
            Button("Keep it running", role: .cancel) {}
        } message: {
            Text("The spot moves to your log and the reminders are cancelled.")
        }
    }

    @ViewBuilder func countdown(_ left: TimeInterval) -> some View {
        if left > 0 {
            VStack(spacing: 0) {
                Text(Fmt.countdown(left)).font(.meter(92)).foregroundStyle(left < 600 ? Curb.flag : Curb.paint)
                    .contentTransition(.numericText(countsDown: true))
                    .shadow(color: (left < 600 ? Curb.flag : Curb.paint).opacity(0.35), radius: 18)
                Stencil("left on the meter")
            }
        } else {
            VStack(spacing: 0) {
                Text("+" + Fmt.countdown(-left)).font(.meter(92)).foregroundStyle(Curb.flag)
                Stencil("over the meter", color: Curb.flag)
            }
        }
    }

    func leavePlate(expires: Date, walk: TimeInterval?, dist: Double?) -> some View {
        let leave = store.leaveBy(session, walk: walk) ?? expires
        let walkText: String = {
            if let dist, walk != nil { return "\(Walk.minutes(dist)) min walk · you're \(Fmt.distance(dist)) away" }
            return "Allowing a \(session.walkMins) min walk back"
        }()
        let late = leave < store.now
        return SignPlate(tint: late ? Curb.flag : Curb.ink) {
            VStack(spacing: 2) {
                Text(late ? "LEAVE NOW" : "LEAVE BY").font(.sign(15, .heavy)).tracking(3)
                Text(late ? "Meter out \(Fmt.clock(expires))" : Fmt.clock(leave)).font(.sign(late ? 30 : 46)).monospacedDigit()
                Text(walkText).font(.body(12.5, .semibold)).opacity(0.7)
            }
        }
        .padding(.horizontal, 4)
    }

    var actions: some View {
        HStack(spacing: 10) {
            if session.expires != nil {
                ActionTile(title: "Add time", icon: "plus.circle.fill", tint: Curb.paint) { router.sheet = .extend(session.id) }
            }
            ActionTile(title: "Find car", icon: "figure.walk", tint: Curb.go) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { router.tab = .map }
            }
            ActionTile(title: "I'm back", icon: "flag.checkered", tint: Curb.chalk) { confirmEnd = true }
        }
    }
}

struct ActionTile: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 22, weight: .bold)).foregroundStyle(tint)
                Text(title.uppercased()).font(.sign(13, .heavy)).tracking(1).foregroundStyle(Curb.chalk)
            }
            .frame(maxWidth: .infinity).frame(height: 84)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Curb.asphalt2))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Curb.line))
        }
        .buttonStyle(Press())
    }
}

/// A small pill that shows whether the meter is also on the Lock Screen (Pro).
struct LiveBadge: View {
    @Environment(Store.self) private var store
    @Environment(Pro.self) private var pro
    let session: Session
    let walk: TimeInterval?
    @State private var on = false
    var body: some View {
        Button {
            guard pro.allow(.live) else { return }
            if on { LiveMeter.end(session.id); on = false }
            else {
                LiveMeter.start(session, vehicle: store.vehicle(session.vehicleID) ?? store.vehicle, leaveBy: store.leaveBy(session, walk: walk))
                on = true
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: on ? "lock.iphone" : "lock.iphone").font(.system(size: 11, weight: .bold))
                Text(on ? "ON LOCK SCREEN" : "LOCK SCREEN").font(.sign(11, .heavy)).tracking(1)
            }
            .foregroundStyle(on ? Curb.ink : Curb.dim)
            .padding(.horizontal, 10).frame(height: 26)
            .background(Capsule().fill(on ? Curb.paint : Curb.slab))
            .overlay(Capsule().strokeBorder(on ? .clear : Curb.line))
        }
        .buttonStyle(Press())
        .onAppear {
            on = LiveMeter.isRunning(session.id) || (store.demo && pro.unlocked)
            if on && !store.demo { LiveMeter.update(session, leaveBy: store.leaveBy(session, walk: walk)) }
        }
    }
}

/// No meter: how long the car has been there.
struct Stopwatch: View {
    let elapsed: TimeInterval
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(Curb.slab, lineWidth: 14)
                Circle().trim(from: 0, to: CGFloat(elapsed.truncatingRemainder(dividingBy: 3600) / 3600))
                    .stroke(Curb.paint, style: StrokeStyle(lineWidth: 14, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(Fmt.countdown(elapsed)).font(.meter(64)).foregroundStyle(Curb.chalk)
                    Stencil("parked for")
                }
            }
            .frame(width: 240, height: 240)
            Text("No meter on this one. Parked just remembers where it is.").font(.body(13)).foregroundStyle(Curb.dim).padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - The meter head

/// A mechanical parking meter: a chrome dome, a cream dial, a needle that falls toward zero,
/// and a red flag that pops up when time runs out.
struct MeterHead: View {
    let total: TimeInterval
    let left: TimeInterval
    static let sweep: Double = 200

    var body: some View {
        let frac = max(0, min(1, left / total))
        let expired = left <= 0
        GeometryReader { g in
            let w = min(g.size.width, 300), h = g.size.height
            ZStack {
                // Housing.
                DomeShape()
                    .fill(LinearGradient(colors: [Color(hex: 0x5A5E66), Color(hex: 0x2C2F35), Color(hex: 0x40444B)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(DomeShape().stroke(LinearGradient(colors: [.white.opacity(0.35), .clear, .black.opacity(0.4)], startPoint: .top, endPoint: .bottom), lineWidth: 2))
                    .shadow(color: .black.opacity(0.55), radius: 22, y: 14)
                // Window.
                DomeShape()
                    .fill(Color(hex: 0xF2EFE6))
                    .overlay(dial(frac: frac))
                    .overlay(flag(expired: expired))
                    .clipShape(DomeShape())
                    .overlay(DomeShape().stroke(Color.black.opacity(0.45), lineWidth: 5))
                    // Glass.
                    .overlay(DomeShape().fill(LinearGradient(colors: [.white.opacity(0.28), .clear, .clear], startPoint: .topLeading, endPoint: .center)).allowsHitTesting(false))
                    .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 44)
                // Coin slot and the label plate.
                VStack(spacing: 6) {
                    Spacer()
                    HStack(spacing: 10) {
                        Capsule().fill(Color.black.opacity(0.75)).frame(width: 36, height: 6)
                        Text("TIME REMAINING").font(.sign(10.5, .heavy)).tracking(2).foregroundStyle(.white.opacity(0.55))
                        Capsule().fill(Color.black.opacity(0.75)).frame(width: 36, height: 6)
                    }
                    .padding(.bottom, 16)
                }
            }
            .frame(width: w, height: h)
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement()
        .accessibilityLabel(expired ? "Meter expired" : "\(Fmt.span(left)) left on the meter")
    }

    func dial(frac: Double) -> some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height * 0.6)
            let r = min(size.width * 0.4, size.height * 0.5)
            let start = 90 + MeterHead.sweep / 2  // zero on the left
            func ang(_ f: Double) -> Double { (start + MeterHead.sweep * f) * .pi / 180 }
            func pt(_ f: Double, _ rr: Double) -> CGPoint { CGPoint(x: c.x + cos(ang(f)) * rr, y: c.y + sin(ang(f)) * rr) }

            // Time left, painted yellow from zero up to the needle.
            if frac > 0 {
                var band = Path()
                band.addArc(center: c, radius: r * 0.8, startAngle: .radians(ang(0)), endAngle: .radians(ang(frac)), clockwise: false)
                ctx.stroke(band, with: .color(Color(hex: 0xF6C945)), style: StrokeStyle(lineWidth: r * 0.16, lineCap: .butt))
            }
            // The red zone: the last tenth.
            var red = Path()
            red.addArc(center: c, radius: r * 0.96, startAngle: .radians(ang(0)), endAngle: .radians(ang(0.1)), clockwise: false)
            ctx.stroke(red, with: .color(Color(hex: 0xE8432F)), style: StrokeStyle(lineWidth: r * 0.07))

            // Ticks and minute labels.
            let mins = total / 60
            let step = MeterHead.step(for: mins)
            let minor = step / 5
            var m = 0.0
            while m <= mins + 0.01 {
                let f = m / mins
                let major = abs(m.truncatingRemainder(dividingBy: step)) < 0.01
                var t = Path()
                t.move(to: pt(f, r * (major ? 0.88 : 0.93))); t.addLine(to: pt(f, r))
                ctx.stroke(t, with: .color(Color(hex: 0x1C1D20)), lineWidth: major ? 2.4 : 1.1)
                if major {
                    let label = m >= 60 && m.truncatingRemainder(dividingBy: 60) == 0 ? "\(Int(m / 60))h" : "\(Int(m))"
                    ctx.draw(Text(label).font(.system(size: 12, weight: .heavy).width(.condensed)).foregroundColor(Color(hex: 0x1C1D20)), at: pt(f, r * 0.62))
                }
                m += minor
            }
            ctx.draw(Text("MIN").font(.system(size: 10, weight: .heavy).width(.condensed)).foregroundColor(Color(hex: 0x6B6E75)), at: CGPoint(x: c.x, y: c.y - r * 0.38))

            // The needle.
            let tip = pt(frac, r * 0.9)
            var needle = Path()
            let back = CGPoint(x: c.x - cos(ang(frac)) * r * 0.16, y: c.y - sin(ang(frac)) * r * 0.16)
            needle.move(to: back); needle.addLine(to: tip)
            ctx.stroke(needle, with: .color(Color(hex: 0xC0301F)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 9, y: c.y - 9, width: 18, height: 18)), with: .color(Color(hex: 0x1C1D20)))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 3.5, y: c.y - 3.5, width: 7, height: 7)), with: .color(Color(hex: 0x9A9CA3)))
        }
    }

    /// The red EXPIRED flag swings up from behind the dial when time runs out.
    func flag(expired: Bool) -> some View {
        GeometryReader { g in
            let pivot = CGPoint(x: g.size.width * 0.5, y: g.size.height * 0.6)
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0xE8432F))
                    .overlay(Text("EXPIRED").font(.system(size: 26, weight: .heavy).width(.condensed)).tracking(3).foregroundStyle(.white))
                    .frame(width: g.size.width * 0.72, height: 50)
                    .offset(y: -g.size.height * 0.2)
            }
            .frame(width: g.size.width, height: g.size.height)
            .rotationEffect(.degrees(expired ? 0 : 100), anchor: UnitPoint(x: pivot.x / max(1, g.size.width), y: pivot.y / max(1, g.size.height)))
            .opacity(expired ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.55), value: expired)
        }
    }

    static func step(for mins: Double) -> Double {
        if mins <= 20 { return 5 }
        if mins <= 45 { return 10 }
        if mins <= 90 { return 15 }
        if mins <= 180 { return 30 }
        if mins <= 480 { return 60 }
        return 120
    }
}

/// The meter's glass: a rectangle with a round top.
struct DomeShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let dome = min(r.width / 2, r.height * 0.6)
        let k: CGFloat = 0.5523
        p.move(to: CGPoint(x: r.minX, y: r.maxY - 14))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + dome))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY), control1: CGPoint(x: r.minX, y: r.minY + dome * (1 - k)), control2: CGPoint(x: r.midX - r.width / 2 * k, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + dome), control1: CGPoint(x: r.midX + r.width / 2 * k, y: r.minY), control2: CGPoint(x: r.maxX, y: r.minY + dome * (1 - k)))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 14))
        p.addQuadCurve(to: CGPoint(x: r.maxX - 14, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + 14, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - 14), control: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Where

/// The photo, the level and bay, and the note: everything that finds the car in a garage.
struct WhereCards: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    let session: Session

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if let img = store.image(session.photo) {
                    Button { router.sheet = .photo(session.id) } label: {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(maxWidth: .infinity).frame(height: 150).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(alignment: .bottomLeading) {
                                Label("Photo", systemImage: "camera.fill").font(.sign(12, .heavy)).foregroundStyle(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 5).background(Capsule().fill(.black.opacity(0.55))).padding(8)
                            }
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Curb.line))
                    }
                    .buttonStyle(Press())
                }
                if !session.level.isEmpty || !session.bay.isEmpty {
                    Pillar(level: session.level, bay: session.bay).frame(maxWidth: session.photo == nil ? .infinity : 130).frame(height: 150)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse").font(.system(size: 14, weight: .bold)).foregroundStyle(Curb.paint)
                    Text(session.address.isEmpty ? "Pinned on the map" : session.address).font(.sign(18, .bold)).foregroundStyle(Curb.chalk)
                    Spacer()
                    if let cost = session.cost, cost > 0 { Text(Fmt.money(cost)).font(.sign(16, .bold)).foregroundStyle(Curb.dim) }
                }
                if !session.note.isEmpty {
                    Text(session.note).font(.body(14)).foregroundStyle(Curb.dim).fixedSize(horizontal: false, vertical: true)
                }
                if let e = session.expires {
                    Text("Meter from \(Fmt.clock(session.start)) to \(Fmt.clock(e)) · \(Fmt.span(e.timeIntervalSince(session.start)))")
                        .font(.body(12.5)).foregroundStyle(Curb.faint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .slab(16, radius: 18)
            .contentShape(Rectangle())
            .onTapGesture { router.sheet = .park(session) }
        }
    }
}

/// A concrete garage pillar with the level painted in a colour band, the way garages do it.
struct Pillar: View {
    let level: String
    let bay: String
    static func tint(_ level: String) -> Color {
        let palette: [Color] = [Color(hex: 0xE8432F), Color(hex: 0x2B63E3), Color(hex: 0x49C27F), Color(hex: 0xF6C945), Color(hex: 0x8E6CF0), Color(hex: 0xF08A3C)]
        let n = level.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[abs(n) % palette.count]
    }
    var body: some View {
        let tint = Pillar.tint(level)
        VStack(spacing: 0) {
            Color(hex: 0xB9B6AE)
            ZStack {
                tint
                VStack(spacing: -4) {
                    if !level.isEmpty {
                        Text(level).font(.sign(level.count > 3 ? 30 : 46)).foregroundStyle(.white).minimumScaleFactor(0.5).lineLimit(1)
                    }
                    if !bay.isEmpty {
                        Text(bay).font(.sign(level.isEmpty ? 40 : 18, .heavy)).foregroundStyle(.white.opacity(level.isEmpty ? 1 : 0.85)).lineLimit(1).minimumScaleFactor(0.5)
                    }
                }
                .padding(.horizontal, 6)
            }
            .frame(height: 96)
            Color(hex: 0xA9A69E)
        }
        .overlay(alignment: .topLeading) {
            Text(level.isEmpty ? "SPOT" : "LEVEL").font(.sign(10, .heavy)).tracking(1.5).foregroundStyle(Color(hex: 0x5C5A55)).padding(.leading, 10).padding(.top, 6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Curb.line))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Empty

struct EmptyMeter: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            EmptyBay().frame(height: 300)
            VStack(alignment: .leading, spacing: 6) {
                Text("Where are you leaving \(store.vehicle.name.lowercased() == "my car" ? "the car" : store.vehicle.name)?").font(.sign(28)).foregroundStyle(Curb.chalk)
                Text("Tap Park here as you walk away. Parked pins the spot, starts the meter and tells you when to head back, allowing for the walk.")
                    .font(.body(14)).foregroundStyle(Curb.dim).fixedSize(horizontal: false, vertical: true)
            }
            PaintButton(title: "Park here", icon: "parkingsign") { router.newPark(store) }
            if !store.db.garages.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Stencil("Or park at")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(store.db.garages) { g in
                                Button { router.newPark(store, garage: g) } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "building.2.fill").foregroundStyle(Curb.blue)
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text(g.name).font(.sign(15, .bold)).foregroundStyle(Curb.chalk)
                                            Text(g.level.isEmpty ? (g.minutes > 0 ? Fmt.span(TimeInterval(g.minutes * 60)) : "No meter") : "Level \(g.level)").font(.body(11.5)).foregroundStyle(Curb.dim)
                                        }
                                    }
                                    .padding(.horizontal, 14).frame(height: 54)
                                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Curb.asphalt2))
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Curb.line))
                                }
                                .buttonStyle(Press())
                            }
                        }
                    }
                    .scrollClipDisabled()
                }
            }
            if let last = store.past.first(where: { $0.vehicleID == store.vehicle.id }) {
                Button { router.sheet = .ticket(last.id) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath").font(.system(size: 16, weight: .bold)).foregroundStyle(Curb.dim)
                        VStack(alignment: .leading, spacing: 2) {
                            Stencil("Last parked")
                            Text(last.place).font(.sign(16, .bold)).foregroundStyle(Curb.chalk).lineLimit(1)
                        }
                        Spacer()
                        Text(Fmt.day(last.start)).font(.body(12.5)).foregroundStyle(Curb.faint)
                    }
                    .slab(14, radius: 18)
                }
                .buttonStyle(Press())
            }
        }
    }
}

/// An empty painted bay seen from above, waiting for the car.
struct EmptyBay: View {
    @State private var glow = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Curb.asphalt2)
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Curb.line))
            HStack(spacing: 0) {
                ForEach(0..<3) { i in
                    ZStack {
                        Bay().stroke(Curb.chalk.opacity(0.8), style: StrokeStyle(lineWidth: 4, lineCap: .square))
                            .rotationEffect(.degrees(180))
                            .padding(.vertical, 26)
                        if i == 1 {
                            VStack(spacing: 8) {
                                Text("PARK").font(.sign(30)).foregroundStyle(Curb.paint)
                                Text("HERE").font(.sign(30)).foregroundStyle(Curb.paint)
                            }
                            .opacity(glow ? 1 : 0.55)
                        } else {
                            CarGlyph(color: i == 0 ? Curb.cars[1] : Curb.cars[7], size: 150).opacity(0.9)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onAppear { withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { glow = true } }
    }
}
