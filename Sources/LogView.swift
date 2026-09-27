import SwiftUI
import MapKit

/// Every time you parked, as a stack of parking stubs.
struct LogView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro

    var body: some View {
        let past = store.past
        let shown = pro.unlocked ? past : Array(past.prefix(Pro.freeLog))
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Log").font(.sign(40)).foregroundStyle(Curb.chalk).padding(.top, 10)
                if pro.unlocked && !past.isEmpty { totals }
                if past.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "ticket").font(.system(size: 30, weight: .bold)).foregroundStyle(Curb.faint)
                        Text("No stubs yet").font(.sign(24)).foregroundStyle(Curb.chalk)
                        Text("When you tap I'm back, the spot lands here with its photo, time and cost.").font(.body(13.5)).foregroundStyle(Curb.dim)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).slab(18, radius: 22)
                }
                ForEach(Array(shown.enumerated()), id: \.element.id) { i, s in
                    Button { router.sheet = .ticket(s.id) } label: { Stub(session: s, tilt: i % 2 == 0 ? -0.6 : 0.5) }
                        .buttonStyle(Press())
                }
                if !pro.unlocked && past.count > Pro.freeLog { locked(past.count - Pro.freeLog) }
            }
            .padding(.horizontal, 18).padding(.bottom, 130)
        }
    }

    var totals: some View {
        let cal = Calendar.current
        let month = cal.dateInterval(of: .month, for: store.now)?.start ?? store.now
        let spent = store.spent(since: month), hours = store.hours(since: month)
        let count = store.past.filter { $0.start >= month }.count
        return HStack(spacing: 0) {
            stat("\(count)", "spots this month")
            Rectangle().fill(Curb.line).frame(width: 1, height: 40)
            stat(String(format: "%.0f h", hours), "parked")
            Rectangle().fill(Curb.line).frame(width: 1, height: 40)
            stat(Fmt.money(spent), "spent")
        }
        .slab(14, radius: 20)
    }

    func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.meter(30)).foregroundStyle(Curb.paint).lineLimit(1).minimumScaleFactor(0.6)
            Text(l.uppercased()).font(.sign(10.5, .heavy)).tracking(1).foregroundStyle(Curb.dim)
        }
        .frame(maxWidth: .infinity)
    }

    func locked(_ n: Int) -> some View {
        Button { pro.paywall = .log } label: {
            VStack(spacing: 10) {
                Image(systemName: "lock.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(Curb.paint)
                Text("\(n) older \(n == 1 ? "stub" : "stubs") in the glovebox").font(.sign(20)).foregroundStyle(Curb.chalk)
                Text("They're kept safe. Parked Pro shows the whole log with money and hours per month.").font(.body(13)).foregroundStyle(Curb.dim).multilineTextAlignment(.center)
                Text("SEE PRO").font(.sign(14, .heavy)).tracking(1.5).foregroundStyle(Curb.ink).padding(.horizontal, 16).frame(height: 34).background(Capsule().fill(Curb.paint))
            }
            .frame(maxWidth: .infinity).padding(22)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Curb.paint.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
        }
        .buttonStyle(Press())
    }
}

/// A paper parking stub: the date on the tear-off, the place and time on the body.
struct Stub: View {
    @Environment(Store.self) private var store
    let session: Session
    var tilt: Double = 0

    var body: some View {
        let v = store.vehicle(session.vehicleID)
        let paper = Color(hex: 0xF3EFE3), ink = Color(hex: 0x23252A)
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(month).font(.sign(13, .heavy)).tracking(1.5).foregroundStyle(Curb.flag)
                Text(day).font(.meter(42)).foregroundStyle(ink)
                Text(weekday).font(.sign(12, .bold)).foregroundStyle(ink.opacity(0.55))
            }
            .frame(width: 84)
            Perforation().stroke(ink.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [3, 4])).frame(width: 1).padding(.vertical, 10)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if let v { Circle().fill(Curb.cars[v.paint % Curb.cars.count]).frame(width: 8, height: 8); Text(v.name.uppercased()).font(.sign(11.5, .heavy)).tracking(1).foregroundStyle(ink.opacity(0.55)) }
                    Spacer()
                    if let c = session.cost { Text(Fmt.money(c)).font(.sign(15, .heavy)).foregroundStyle(ink) }
                }
                Text(session.place).font(.sign(19, .bold)).foregroundStyle(ink).lineLimit(2).multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    Text("\(Fmt.clock(session.start)) – \(Fmt.clock(session.ended ?? session.start))").font(.system(size: 12.5, weight: .semibold, design: .monospaced)).foregroundStyle(ink.opacity(0.6))
                    Text(Fmt.span((session.ended ?? session.start).timeIntervalSince(session.start))).font(.sign(12.5, .heavy)).foregroundStyle(ink.opacity(0.8))
                    if let e = session.expires, let end = session.ended, end > e.addingTimeInterval(60) {
                        Text("OVER").font(.sign(11, .heavy)).foregroundStyle(.white).padding(.horizontal, 5).padding(.vertical, 1).background(RoundedRectangle(cornerRadius: 3).fill(Curb.flag))
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 14)
            if let img = store.image(session.photo) {
                Image(uiImage: img).resizable().scaledToFill().frame(width: 64, height: 76).clipShape(RoundedRectangle(cornerRadius: 8)).padding(.trailing, 12)
                    .rotationEffect(.degrees(2.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StubShape().fill(paper).shadow(color: .black.opacity(0.4), radius: 10, y: 6))
        .rotationEffect(.degrees(tilt))
    }

    var month: String { let f = DateFormatter(); f.dateFormat = "MMM"; return f.string(from: session.start).uppercased() }
    var day: String { let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: session.start) }
    var weekday: String { let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: session.start).uppercased() }
}

struct Perforation: Shape {
    func path(in r: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.midX, y: r.maxY)); return p }
}

/// A stub with notches bitten out where the perforation meets the edges.
struct StubShape: Shape {
    func path(in r: CGRect) -> Path {
        let x = r.minX + 84.5, n: CGFloat = 9, rad: CGFloat = 8
        var p = Path()
        p.move(to: CGPoint(x: r.minX + rad, y: r.minY))
        p.addLine(to: CGPoint(x: x - n, y: r.minY))
        p.addArc(center: CGPoint(x: x, y: r.minY), radius: n, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
        p.addLine(to: CGPoint(x: r.maxX - rad, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + rad), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - rad))
        p.addQuadCurve(to: CGPoint(x: r.maxX - rad, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: x + n, y: r.maxY))
        p.addArc(center: CGPoint(x: x, y: r.maxY), radius: n, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: true)
        p.addLine(to: CGPoint(x: r.minX + rad, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - rad), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + rad))
        p.addQuadCurve(to: CGPoint(x: r.minX + rad, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.closeSubpath()
        return p
    }
}

/// One past spot: the map, the photo, the details, and park-here-again.
struct TicketDetail: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var confirmDelete = false

    var body: some View {
        if let s = store.session(id) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Stencil(Fmt.day(s.start), color: Curb.paint)
                        Spacer()
                        Knob(icon: "xmark", size: 36) { dismiss() }
                    }
                    .padding(.top, 22)
                    Stub(session: s)
                    if let spot = s.spot {
                        Map(initialPosition: .camera(MapCamera(centerCoordinate: spot.coordinate, distance: 600))) {
                            Annotation("", coordinate: spot.coordinate, anchor: .bottom) { SignPin(paint: store.vehicle(s.vehicleID)?.paint ?? 0) }
                        }
                        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
                        .frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    if let img = store.image(s.photo) {
                        Button { router.sheet = .photo(s.id) } label: {
                            Image(uiImage: img).resizable().scaledToFill().frame(height: 220).frame(maxWidth: .infinity).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(Press())
                    }
                    if !s.note.isEmpty { Text(s.note).font(.body(15)).foregroundStyle(Curb.chalk).slab(16, radius: 18) }
                    if s.isActive {
                        PaintButton(title: "Back to the meter", icon: "gauge.with.needle") { dismiss(); router.tab = .meter }
                    } else {
                        PaintButton(title: "Park here again", icon: "arrow.uturn.backward") {
                            var n = Session(vehicleID: s.vehicleID, start: store.now, spot: s.spot, address: s.address, level: s.level, bay: s.bay, walkMins: s.walkMins)
                            n.note = s.note
                            router.sheet = .park(n)
                        }
                        if s.spot != nil { KerbButton(title: "Walk there", icon: "figure.walk") { Directions.walk(to: s, name: "Parked here") } }
                    }
                    KerbButton(title: "Delete", icon: "trash", tint: Curb.flag) { confirmDelete = true }
                }
                .padding(.horizontal, 20).padding(.bottom, 40)
            }
            .confirmationDialog("Delete this stub?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { store.delete(s); dismiss() }
            }
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }
}
