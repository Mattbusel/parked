import SwiftUI
import CoreLocation

/// Sample data for screenshots and the review recording. Never saved.
@MainActor
enum Demo {
    static let car = CLLocationCoordinate2D(latitude: 41.89052, longitude: -87.63418)
    static let you = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 41.88702, longitude: -87.62905), altitude: 180, horizontalAccuracy: 6, verticalAccuracy: 6, timestamp: Date())

    static func fill(_ s: Store) {
        let T = Calendar.current.startOfDay(for: Date())
        func at(_ day: Int, _ h: Double) -> Date { T.addingTimeInterval(TimeInterval(day) * 86400 + h * 3600) }
        let civic = Vehicle(name: "Civic", plate: "7KDR482", paint: 0)
        let outback = Vehicle(name: "Outback", plate: "BX 40217", paint: 3)
        s.db.vehicles = [civic, outback]
        s.db.current = civic.id

        func spot(_ dlat: Double, _ dlon: Double) -> Spot { Spot(lat: car.latitude + dlat, lon: car.longitude + dlon, accuracy: 5) }

        var now = Session(vehicleID: civic.id, start: at(0, 8 + 58.0 / 60), expires: at(0, 10 + 58.0 / 60), spot: Spot(lat: car.latitude, lon: car.longitude, accuracy: 5),
                          address: "412 N Wells St", note: "Across from the coffee place. Meter #2231, pay by plate.", photo: "demo-sign", cost: 5.50, walkMins: 10)
        now.id = UUID()

        let past: [Session] = [
            Session(vehicleID: civic.id, start: at(-1, 18.2), expires: at(-1, 20.2), spot: spot(0.004, 0.006), address: "1550 N Clybourn Ave", level: "B1", bay: "22", note: "Gym. Validate at the desk.", cost: 0, walkMins: 5, ended: at(-1, 19.6)),
            Session(vehicleID: civic.id, start: at(-2, 8.6), expires: at(-2, 18.6), spot: spot(-0.009, 0.002), address: "200 W Monroe St", level: "P3", bay: "Row F", note: "Work garage", photo: "demo-garage", cost: 25, walkMins: 4, ended: at(-2, 17.9)),
            Session(vehicleID: outback.id, start: at(-3, 13.1), expires: at(-3, 15.1), spot: spot(0.012, -0.01), address: "2945 N Broadway", cost: 4.25, walkMins: 8, ended: at(-3, 15.4)),
            Session(vehicleID: civic.id, start: at(-4, 8.5), expires: at(-4, 18.5), spot: spot(-0.009, 0.002), address: "200 W Monroe St", level: "P3", bay: "Row D", cost: 25, walkMins: 4, ended: at(-4, 18.1)),
            Session(vehicleID: civic.id, start: at(-6, 11.0), expires: at(-6, 13.0), spot: spot(0.002, -0.004), address: "600 N Michigan Ave", level: "P5", bay: "Blue 14", note: "Dentist", cost: 18, walkMins: 6, ended: at(-6, 12.6)),
            Session(vehicleID: outback.id, start: at(-8, 9.0), spot: spot(0.03, -0.05), address: "Home Depot, N Elston Ave", walkMins: 3, ended: at(-8, 10.4)),
            Session(vehicleID: civic.id, start: at(-9, 19.3), expires: at(-9, 21.3), spot: spot(0.006, 0.001), address: "1020 N Rush St", note: "Dinner with Sam", cost: 7.5, walkMins: 7, ended: at(-9, 21.6)),
            Session(vehicleID: civic.id, start: at(-11, 8.4), expires: at(-11, 18.4), spot: spot(-0.009, 0.002), address: "200 W Monroe St", level: "P2", bay: "Row B", cost: 25, walkMins: 4, ended: at(-11, 17.7)),
            Session(vehicleID: civic.id, start: at(-15, 6.1), spot: spot(0.07, -0.15), address: "O'Hare Economy Lot F", level: "F", bay: "Row 41", note: "Shuttle stop 41. Back Sunday.", photo: "demo-garage", cost: 52, walkMins: 12, ended: at(-12, 22.4)),
            Session(vehicleID: outback.id, start: at(-17, 10.2), expires: at(-17, 12.2), spot: spot(-0.02, 0.01), address: "Maxwell St Market", cost: 6, walkMins: 5, ended: at(-17, 12.0)),
            Session(vehicleID: civic.id, start: at(-19, 14.0), expires: at(-19, 15.0), spot: spot(0.001, 0.002), address: "455 N Park Dr", cost: 3.5, walkMins: 5, ended: at(-19, 15.3)),
        ]
        s.db.sessions = past + [now]

        s.db.garages = [
            Garage(name: "Work garage", spot: spot(-0.009, 0.002), address: "200 W Monroe St", level: "P3", bay: "Row F", note: "Take the east elevator", minutes: 600, rate: 2.5),
            Garage(name: "Gym", spot: spot(0.004, 0.006), address: "1550 N Clybourn Ave", level: "B1", minutes: 120, rate: 0),
            Garage(name: "O'Hare Economy", spot: spot(0.07, -0.15), address: "Lot F", level: "F", note: "Note the shuttle stop number"),
        ]
        s.db.rules = [
            Rule(name: "Street cleaning", place: "Elm St, north side", days: [3], start: 8 * 60, end: 10 * 60, remindBefore: 60, eveningBefore: true),
            Rule(name: "2-hour zone", place: "Wells St", days: [2, 3, 4, 5, 6], start: 8 * 60, end: 18 * 60, remindBefore: 0, eveningBefore: false),
            Rule(name: "Snow route", place: "Division St", days: [1, 2, 3, 4, 5, 6, 7], start: 3 * 60, end: 7 * 60, remindBefore: 0, eveningBefore: false, on: false),
        ]
    }

    /// The Park sheet as it looks in a garage.
    static func draft(_ s: Store) -> Session {
        var d = Session(vehicleID: s.vehicle.id, start: s.now, expires: s.now.addingTimeInterval(90 * 60), spot: Spot(lat: car.latitude + 0.0006, lon: car.longitude - 0.0009, accuracy: 6),
                        address: "Wells St Garage", level: "P3", bay: "F-12", note: "Take the east elevator. Blue level.", cost: 14, walkMins: 10)
        d.id = UUID()
        return d
    }

    // MARK: drawn photos

    static func photo(_ name: String) -> UIImage? {
        let view: AnyView = name == "demo-garage" ? AnyView(GaragePhoto()) : AnyView(SignPhoto())
        let r = ImageRenderer(content: view.frame(width: 600, height: 800))
        r.scale = 2
        return r.uiImage
    }
}

/// A photo of a street sign on a pole against brick, drawn rather than shot.
private struct SignPhoto: View {
    var body: some View {
        ZStack {
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x6E3B2E)))
                let bh: CGFloat = 34, bw: CGFloat = 92
                var row = 0
                var y: CGFloat = 0
                while y < size.height {
                    var x: CGFloat = row % 2 == 0 ? 0 : -bw / 2
                    while x < size.width {
                        let shade = 0.82 + Double((Int(x * 7 + y * 3) % 17)) / 70
                        ctx.fill(Path(roundedRect: CGRect(x: x + 3, y: y + 3, width: bw - 6, height: bh - 6), cornerRadius: 2),
                                 with: .color(Color(hex: 0x9A4F3A).opacity(shade)))
                        x += bw
                    }
                    y += bh; row += 1
                }
            }
            LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
            Rectangle().fill(LinearGradient(colors: [Color(hex: 0x8D9096), Color(hex: 0xD8DADF), Color(hex: 0x6C6F75)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 22)
            VStack(spacing: 26) {
                VStack(spacing: 6) {
                    HStack(spacing: 14) {
                        PSign(size: 70)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("2 HOUR").font(.system(size: 54, weight: .heavy).width(.condensed))
                            Text("PARKING").font(.system(size: 40, weight: .heavy).width(.condensed))
                        }
                    }
                    Text("8 AM – 6 PM").font(.system(size: 38, weight: .heavy).width(.condensed))
                    Text("MON – SAT").font(.system(size: 34, weight: .heavy).width(.condensed))
                    Text("PAY AT METER").font(.system(size: 24, weight: .bold).width(.condensed)).padding(.top, 4)
                }
                .foregroundStyle(Color(hex: 0x1D5A2E))
                .padding(26).frame(width: 360)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xF4F3EE)).overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hex: 0x1D5A2E), lineWidth: 5).padding(8)))
                VStack(spacing: 4) {
                    Text("NO PARKING").font(.system(size: 40, weight: .heavy).width(.condensed))
                    Text("TUE 8 AM – 10 AM").font(.system(size: 32, weight: .heavy).width(.condensed))
                    Text("STREET CLEANING").font(.system(size: 26, weight: .bold).width(.condensed))
                }
                .foregroundStyle(Color(hex: 0xC7271A))
                .padding(22).frame(width: 360)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xF4F3EE)).overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hex: 0xC7271A), lineWidth: 5).padding(8)))
            }
            .rotationEffect(.degrees(-1.5))
            .shadow(color: .black.opacity(0.45), radius: 16, x: 8, y: 12)
            RadialGradient(colors: [.clear, .black.opacity(0.35)], center: .center, startRadius: 200, endRadius: 520)
        }
    }
}

/// A garage level painted on a concrete pillar.
private struct GaragePhoto: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x8D8A83), Color(hex: 0x5E5C58)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 0) {
                Color(hex: 0xBDB9B0).frame(height: 240)
                ZStack {
                    Color(hex: 0x2B63E3)
                    VStack(spacing: -10) {
                        Text("P3").font(.system(size: 190, weight: .heavy).width(.condensed))
                        Text("ROW F").font(.system(size: 60, weight: .heavy).width(.condensed))
                    }
                    .foregroundStyle(.white)
                }
                .frame(height: 330)
                Color(hex: 0xA8A49B)
            }
            .frame(width: 420)
            .shadow(color: .black.opacity(0.4), radius: 20, x: 10)
            LinearGradient(colors: [.white.opacity(0.18), .clear, .black.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
