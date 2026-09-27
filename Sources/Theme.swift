import SwiftUI
import UIKit

/// Parked's look: a night street. Asphalt with grain, road paint yellow and white,
/// regulatory signs in black on white, the meter's red flag, and the blue P.
enum Curb {
    static let asphalt = Color(hex: 0x1C1D20)
    static let asphalt2 = Color(hex: 0x25272B)
    static let slab = Color(hex: 0x2E3035)
    static let kerb = Color(hex: 0x3A3D43)
    static let line = Color.white.opacity(0.09)
    static let paint = Color(hex: 0xF6C945)
    static let paintDeep = Color(hex: 0xD9A91C)
    static let chalk = Color(hex: 0xEDEBE4)
    static let dim = Color(hex: 0x9A9CA3)
    static let faint = Color(hex: 0x6B6E75)
    static let flag = Color(hex: 0xE8432F)
    static let blue = Color(hex: 0x2B63E3)
    static let go = Color(hex: 0x49C27F)
    static let sign = Color(hex: 0xF7F6F2)
    static let ink = Color(hex: 0x141416)

    /// Paint colours for vehicles.
    static let cars: [Color] = [Color(hex: 0xE8432F), Color(hex: 0x2B63E3), Color(hex: 0xF6C945), Color(hex: 0x49C27F),
                                Color(hex: 0xEDEBE4), Color(hex: 0x8E6CF0), Color(hex: 0xF08A3C), Color(hex: 0x5C6068)]
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
}

extension Font {
    /// Condensed signage type.
    static func sign(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font { .system(size: size, weight: weight).width(.condensed) }
    /// Compressed, for the big numbers.
    static func meter(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font { .system(size: size, weight: weight).width(.compressed).monospacedDigit() }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight) }
}

// MARK: - Surfaces

/// Asphalt: a dark base with a fixed scatter of aggregate, so it never shimmers between renders.
struct Asphalt: View {
    var body: some View {
        ZStack {
            Curb.asphalt
            Canvas { ctx, size in
                var seed: UInt64 = 0x9E3779B97F4A7C15
                func rnd() -> Double { seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17; return Double(seed % 10_000) / 10_000 }
                let n = Int(size.width * size.height / 260)
                for _ in 0..<n {
                    let x = rnd() * size.width, y = rnd() * size.height, r = 0.5 + rnd() * 1.3
                    let light = rnd()
                    let c = light > 0.62 ? Color.white.opacity(0.05 + rnd() * 0.06) : Color.black.opacity(0.18 + rnd() * 0.2)
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(c))
                }
            }
            RadialGradient(colors: [.clear, .black.opacity(0.35)], center: .init(x: 0.5, y: 0.3), startRadius: 120, endRadius: 700)
        }
        .ignoresSafeArea()
    }
}

/// A raised slab: the pavement cards sit on.
struct Slab: ViewModifier {
    var pad: CGFloat = 16
    var radius: CGFloat = 22
    func body(content: Content) -> some View {
        content.padding(pad)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Curb.asphalt2)
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Curb.line))
                    .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
            )
    }
}
extension View {
    func slab(_ pad: CGFloat = 16, radius: CGFloat = 22) -> some View { modifier(Slab(pad: pad, radius: radius)) }
}

/// Yellow and black hazard stripes.
struct Hazard: View {
    var a: Color = Curb.paint
    var b: Color = Curb.ink
    var width: CGFloat = 14
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(b))
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height)); p.addLine(to: CGPoint(x: x + size.height, y: 0))
                p.addLine(to: CGPoint(x: x + size.height + width, y: 0)); p.addLine(to: CGPoint(x: x + width, y: size.height)); p.closeSubpath()
                ctx.fill(p, with: .color(a))
                x += width * 2
            }
        }
    }
}

/// A painted dashed road line.
struct RoadDash: View {
    var color: Color = Curb.paint
    var body: some View {
        GeometryReader { g in
            Path { p in p.move(to: CGPoint(x: 0, y: g.size.height / 2)); p.addLine(to: CGPoint(x: g.size.width, y: g.size.height / 2)) }
                .stroke(color, style: StrokeStyle(lineWidth: g.size.height, dash: [18, 12]))
        }
    }
}

// MARK: - Signs

/// The blue parking sign.
struct PSign: View {
    var size: CGFloat = 44
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous).fill(Curb.blue)
            RoundedRectangle(cornerRadius: size * 0.15, style: .continuous).strokeBorder(.white, lineWidth: max(1.5, size * 0.05)).padding(size * 0.07)
            Text("P").font(.system(size: size * 0.66, weight: .heavy)).foregroundStyle(.white).offset(y: -size * 0.01)
        }
        .frame(width: size, height: size)
        .shadow(color: Curb.blue.opacity(0.35), radius: size * 0.18, y: size * 0.08)
    }
}

/// A regulatory sign: black type on a white plate with a black inner border.
struct SignPlate<Content: View>: View {
    var tint: Color = Curb.ink
    @ViewBuilder var content: Content
    var body: some View {
        content
            .foregroundStyle(tint)
            .padding(.vertical, 12).padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Curb.sign)
                    RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(tint, lineWidth: 3).padding(5)
                }
                .shadow(color: .black.opacity(0.45), radius: 12, y: 8)
            )
            .overlay(alignment: .top) { bolts }
            .overlay(alignment: .bottom) { bolts }
    }
    var bolts: some View {
        HStack { bolt; Spacer(); bolt }.padding(.horizontal, 18).padding(.vertical, 12).allowsHitTesting(false)
    }
    var bolt: some View {
        Circle().fill(LinearGradient(colors: [Color(hex: 0xC9CBD0), Color(hex: 0x7C7F86)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 6, height: 6).opacity(0.9)
    }
}

/// Small caps label.
struct Stencil: View {
    let text: String
    var color: Color = Curb.dim
    init(_ text: String, color: Color = Curb.dim) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased()).font(.sign(12.5, .bold)).tracking(1.6).foregroundStyle(color)
    }
}

// MARK: - Buttons

/// Road paint on a button: yellow, heavy, pressed down into the asphalt.
struct PaintButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = Curb.paint
    var text: Color = Curb.ink
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon).font(.system(size: 17, weight: .heavy)) }
                Text(title.uppercased()).font(.sign(19)).tracking(1)
            }
            .foregroundStyle(text)
            .frame(maxWidth: .infinity).frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(color)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center)))
                    .shadow(color: color.opacity(0.35), radius: 16, y: 8)
            )
        }
        .buttonStyle(Press())
    }
}

/// A quieter outline button on the asphalt.
struct KerbButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = Curb.chalk
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 14, weight: .bold)) }
                Text(title).font(.sign(16, .bold))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity).frame(height: 48)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Curb.slab))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Curb.line))
        }
        .buttonStyle(Press())
    }
}

struct Press: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A round icon button.
struct Knob: View {
    let icon: String
    var tint: Color = Curb.chalk
    var size: CGFloat = 40
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: size * 0.38, weight: .bold)).foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(Circle().fill(Curb.slab)).overlay(Circle().strokeBorder(Curb.line))
        }
        .buttonStyle(Press())
    }
}

// MARK: - Car

/// A little top-down car in the vehicle's paint.
struct CarGlyph: View {
    var color: Color
    var size: CGFloat = 30
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, h = s.height
            let body = Path(roundedRect: CGRect(x: w * 0.22, y: h * 0.04, width: w * 0.56, height: h * 0.92), cornerRadius: w * 0.2)
            ctx.fill(body, with: .color(color))
            ctx.stroke(body, with: .color(.black.opacity(0.35)), lineWidth: 1)
            let glass = Path(roundedRect: CGRect(x: w * 0.29, y: h * 0.24, width: w * 0.42, height: h * 0.17), cornerRadius: w * 0.06)
            ctx.fill(glass, with: .color(.black.opacity(0.55)))
            let rear = Path(roundedRect: CGRect(x: w * 0.3, y: h * 0.7, width: w * 0.4, height: h * 0.1), cornerRadius: w * 0.05)
            ctx.fill(rear, with: .color(.black.opacity(0.45)))
            ctx.fill(Path(roundedRect: CGRect(x: w * 0.31, y: h * 0.45, width: w * 0.38, height: h * 0.2), cornerRadius: w * 0.05), with: .color(.white.opacity(0.14)))
        }
        .frame(width: size * 0.62, height: size)
    }
}

// MARK: - Formatting

enum Fmt {
    static func clock(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; f.amSymbol = "AM"; f.pmSymbol = "PM"
        return f.string(from: d)
    }
    static func clockShort(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "h:mm"; return f.string(from: d)
    }
    static func ampm(_ d: Date) -> String { Calendar.current.component(.hour, from: d) < 12 ? "AM" : "PM" }
    static func day(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInYesterday(d) { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = cal.isDate(d, equalTo: Date(), toGranularity: .year) ? "EEE d MMM" : "d MMM yyyy"
        return f.string(from: d)
    }
    /// 1:17:04 or 42:18
    static func countdown(_ s: TimeInterval) -> String {
        let t = max(0, Int(s.rounded(.down)))
        let h = t / 3600, m = (t % 3600) / 60, sec = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }
    /// 2 h 15 min
    static func span(_ s: TimeInterval) -> String {
        let m = Int((s / 60).rounded())
        if m < 60 { return "\(m) min" }
        return m % 60 == 0 ? "\(m / 60) h" : "\(m / 60) h \(m % 60) min"
    }
    static func distance(_ m: Double) -> String {
        let miles = Locale.current.measurementSystem == .us
        if miles {
            let ft = m * 3.28084
            return ft < 900 ? "\(Int((ft / 10).rounded() * 10)) ft" : String(format: "%.1f mi", m / 1609.34)
        }
        return m < 950 ? "\(Int((m / 10).rounded() * 10)) m" : String(format: "%.1f km", m / 1000)
    }
    static func money(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)
    }
}
