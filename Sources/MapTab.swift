import SwiftUI
import MapKit
import CoreLocation

/// Find the car: the map, the walk, and an arrow that points at it when the map is no help.
struct MapTab: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @State private var position: MapCameraPosition = .automatic

    var session: Session? { store.current ?? store.past.first(where: { $0.vehicleID == store.vehicle.id }) }

    var body: some View {
        let loc = Locator.shared
        ZStack(alignment: .bottom) {
            Map(position: $position) {
                if store.demo, let you = loc.location {
                    Annotation("You", coordinate: you.coordinate) { YouDot() }
                } else {
                    UserAnnotation()
                }
                ForEach(store.activeSessions.filter { $0.spot != nil }) { s in
                    let v = store.vehicle(s.vehicleID)
                    Annotation(v?.name ?? "Car", coordinate: s.spot!.coordinate, anchor: .bottom) { SignPin(paint: v?.paint ?? 0) }
                }
                if let s = session, !s.isActive, let spot = s.spot {
                    Annotation("Last parked", coordinate: spot.coordinate, anchor: .bottom) { SignPin(paint: store.vehicle.paint).opacity(0.6) }
                }
                if let s = session, s.isActive, let spot = s.spot, let you = loc.location {
                    MapPolyline(coordinates: [you.coordinate, spot.coordinate])
                        .stroke(Curb.paint, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2, 9]))
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
            .mapControls { MapCompass(); MapScaleView() }
            .ignoresSafeArea(edges: .top)
            .onAppear { frame(animated: false) }

            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Knob(icon: "scope", tint: Curb.paint, size: 44) { frame(animated: true) }.accessibilityLabel("Show me and the car")
                }
                if let s = session { FindCard(session: s) } else { noCar }
            }
            .padding(.horizontal, 16).padding(.bottom, 104)
        }
    }

    var noCar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing parked yet").font(.sign(24)).foregroundStyle(Curb.chalk)
            Text("Tap the P when you leave the car, and it shows up here.").font(.body(13.5)).foregroundStyle(Curb.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .slab(18, radius: 24)
    }

    func frame(animated: Bool) {
        var coords: [CLLocationCoordinate2D] = store.activeSessions.compactMap { $0.spot?.coordinate }
        if coords.isEmpty, let c = session?.spot?.coordinate { coords = [c] }
        if let you = Locator.shared.location?.coordinate { coords.append(you) }
        guard !coords.isEmpty else { position = .userLocation(fallback: .automatic); return }
        let lats = coords.map(\.latitude), lons = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2 - (lats.max()! - lats.min()!) * 0.35, longitude: (lons.min()! + lons.max()!) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max(0.004, (lats.max()! - lats.min()!) * 2.6), longitudeDelta: max(0.004, (lons.max()! - lons.min()!) * 1.6))
        let p = MapCameraPosition.region(MKCoordinateRegion(center: center, span: span))
        if animated { withAnimation(.easeInOut(duration: 0.6)) { position = p } } else { position = p }
    }
}

struct YouDot: View {
    @State private var pulse = false
    var body: some View {
        ZStack {
            Circle().fill(Curb.blue.opacity(0.25)).frame(width: 44, height: 44).scaleEffect(pulse ? 1.1 : 0.6).opacity(pulse ? 0 : 1)
            Circle().fill(.white).frame(width: 20, height: 20)
            Circle().fill(Curb.blue).frame(width: 14, height: 14)
        }
        .onAppear { withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true } }
    }
}

/// Distance, the walk, a live arrow toward the car, and the hand-off to Apple Maps.
struct FindCard: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    let session: Session

    var body: some View {
        let loc = Locator.shared
        let v = store.vehicle(session.vehicleID) ?? store.vehicle
        let dist = loc.distance(to: session.spot)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle().fill(Curb.slab)
                    Circle().strokeBorder(Curb.line)
                    if let b = bearing(loc) {
                        Image(systemName: "location.north.fill").font(.system(size: 26, weight: .heavy)).foregroundStyle(Curb.paint)
                            .rotationEffect(.degrees(b - loc.heading))
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: loc.heading)
                    } else {
                        CarGlyph(color: Curb.cars[v.paint % Curb.cars.count], size: 34)
                    }
                }
                .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Stencil(session.isActive ? v.name : "Last parked · \(Fmt.day(session.start))", color: session.isActive ? Curb.paint : Curb.dim)
                    if let dist {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(Fmt.distance(dist)).font(.meter(40)).foregroundStyle(Curb.chalk)
                            Text("· \(Walk.minutes(dist)) min walk").font(.sign(17, .bold)).foregroundStyle(Curb.dim)
                        }
                    } else {
                        Text(session.shortPlace).font(.sign(24)).foregroundStyle(Curb.chalk).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            if dist != nil || !session.level.isEmpty || !session.bay.isEmpty {
                HStack(spacing: 8) {
                    if dist != nil { chip("mappin", session.address.isEmpty ? "Pinned spot" : session.address) }
                    if !session.level.isEmpty { chip("building.2", "Level \(session.level)") }
                    if !session.bay.isEmpty { chip("number", session.bay) }
                }
            }
            HStack(spacing: 10) {
                PaintButton(title: "Walk there", icon: "figure.walk") { Directions.walk(to: session, name: v.name) }
                if session.photo != nil {
                    Button { router.sheet = .photo(session.id) } label: {
                        Image(uiImage: store.image(session.photo) ?? UIImage()).resizable().scaledToFill()
                            .frame(width: 58, height: 58).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.2)))
                    }
                    .buttonStyle(Press()).accessibilityLabel("Photo of the spot")
                }
            }
        }
        .slab(18, radius: 26)
    }

    func chip(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(text).font(.sign(13, .bold)).lineLimit(1)
        }
        .foregroundStyle(Curb.chalk).padding(.horizontal, 10).frame(height: 28)
        .background(Capsule().fill(Curb.slab))
    }

    /// Compass bearing from the phone to the car, in degrees.
    func bearing(_ loc: Locator) -> Double? {
        guard let a = loc.location?.coordinate, let b = session.spot?.coordinate else { return nil }
        let φ1 = a.latitude * .pi / 180, φ2 = b.latitude * .pi / 180, Δλ = (b.longitude - a.longitude) * .pi / 180
        let y = sin(Δλ) * cos(φ2), x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
}
