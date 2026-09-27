import SwiftUI

/// Street rules, saved garages, cars and reminder settings.
struct RulesView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro

    var body: some View {
        @Bindable var store = store
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                Text("Rules").font(.sign(40)).foregroundStyle(Curb.chalk).padding(.top, 10)

                section("Street rules", add: { if pro.allow(.rules) { router.sheet = .rule(Rule()) } }) {
                    if store.db.rules.isEmpty {
                        hint("Street cleaning Tuesday 8 to 10? Parked reminds you the night before and an hour before.", icon: "calendar.badge.exclamationmark")
                    }
                    ForEach(store.db.rules) { r in
                        Button { router.sheet = .rule(r) } label: { RuleSign(rule: r, now: store.now) }.buttonStyle(Press())
                    }
                }

                section("Saved garages", add: { if pro.allow(.garages) { router.sheet = .garage(Garage(name: "")) } }) {
                    if store.db.garages.isEmpty {
                        hint("Park at work, the gym or the airport with one tap, level and meter already filled in.", icon: "building.2")
                    }
                    ForEach(store.db.garages) { g in
                        GarageRow(garage: g)
                    }
                }

                section("Cars", add: { if pro.allow(.cars) { router.sheet = .vehicle(Vehicle(name: "", paint: store.db.vehicles.count % Curb.cars.count)) } }) {
                    ForEach(store.db.vehicles) { v in
                        Button { router.sheet = .vehicle(v) } label: {
                            HStack(spacing: 14) {
                                CarGlyph(color: Curb.cars[v.paint % Curb.cars.count], size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(v.name).font(.sign(18, .bold)).foregroundStyle(Curb.chalk)
                                    if !v.plate.isEmpty { Plate(text: v.plate) }
                                }
                                Spacer()
                                if store.active(v.id) != nil { Stencil("Parked", color: Curb.go) }
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Curb.faint)
                            }
                            .slab(14, radius: 18)
                        }
                        .buttonStyle(Press())
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Stencil("Reminders")
                    VStack(spacing: 0) {
                        stepRow("Heads-up before the meter runs out", value: $store.db.settings.warnBefore, range: 0...30, step: 5, unit: "min")
                        Divider().overlay(Curb.line)
                        stepRow("Usual walk back to the car", value: $store.db.settings.walkMins, range: 0...45, step: 5, unit: "min")
                        Divider().overlay(Curb.line)
                        Toggle(isOn: Binding(get: { store.db.settings.live && pro.unlocked }, set: { v in
                            if pro.allow(.live) { store.db.settings.live = v; store.save() }
                        })) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Meter on the Lock Screen").font(.sign(16, .bold)).foregroundStyle(Curb.chalk)
                                    if !pro.unlocked { Text("PRO").font(.sign(10, .heavy)).foregroundStyle(Curb.ink).padding(.horizontal, 5).padding(.vertical, 1).background(RoundedRectangle(cornerRadius: 4).fill(Curb.paint)) }
                                }
                                Text("Starts a live countdown each time you park.").font(.body(12)).foregroundStyle(Curb.faint)
                            }
                        }
                        .tint(Curb.paint).padding(.vertical, 12)
                    }
                    .padding(.horizontal, 16)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Curb.asphalt2))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Curb.line))
                    .onChange(of: store.db.settings) { _, _ in store.save() }
                }

                ProCard()

                Text("Parked keeps everything on this phone. No account, no tracking, no ads. Your location is only read while you park or look for the car.")
                    .font(.body(11.5)).foregroundStyle(Curb.faint).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18).padding(.bottom, 130)
        }
    }

    func section<C: View>(_ title: String, add: @escaping () -> Void, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Stencil(title)
                Spacer()
                Button(action: add) {
                    Label("Add", systemImage: "plus").font(.sign(14, .heavy)).foregroundStyle(Curb.paint)
                        .padding(.horizontal, 12).frame(height: 30).background(Capsule().fill(Curb.paint.opacity(0.12)))
                }
                .buttonStyle(Press())
            }
            content()
        }
    }

    func hint(_ text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(Curb.faint).frame(width: 26)
            Text(text).font(.body(13.5)).foregroundStyle(Curb.dim).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Curb.line, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
    }

    func stepRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        HStack {
            Text(label).font(.sign(16, .bold)).foregroundStyle(Curb.chalk)
            Spacer()
            Text("\(value.wrappedValue) \(unit)").font(.sign(16)).foregroundStyle(Curb.paint).monospacedDigit()
            Stepper("", value: value, in: range, step: step).labelsHidden()
        }
        .padding(.vertical, 10)
    }
}

/// A licence plate.
struct Plate: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.system(size: 12, weight: .heavy, design: .monospaced)).foregroundStyle(Curb.ink)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(Curb.sign))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Curb.ink.opacity(0.6), lineWidth: 1).padding(1.5))
    }
}

/// A street rule drawn as the sign itself: NO PARKING, the days and hours, and when it next bites.
struct RuleSign: View {
    let rule: Rule
    let now: Date
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Curb.sign)
                Text("P").font(.system(size: 30, weight: .heavy)).foregroundStyle(Curb.ink)
                Circle().strokeBorder(Curb.flag, lineWidth: 5)
                Rectangle().fill(Curb.flag).frame(width: 5, height: 50).rotationEffect(.degrees(-45))
            }
            .frame(width: 54, height: 54).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name.uppercased()).font(.sign(14, .heavy)).tracking(1).foregroundStyle(Curb.flag)
                Text("\(rule.dayText) \(rule.timeText)").font(.sign(21)).foregroundStyle(Curb.ink)
                if !rule.place.isEmpty { Text(rule.place).font(.body(12.5, .semibold)).foregroundStyle(Curb.ink.opacity(0.6)) }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                if rule.on, let n = rule.next(after: now) {
                    Text("NEXT").font(.sign(10, .heavy)).tracking(1).foregroundStyle(Curb.ink.opacity(0.5))
                    Text(RuleSign.until(n, now)).font(.sign(15, .heavy)).foregroundStyle(Curb.ink)
                } else {
                    Text("OFF").font(.sign(13, .heavy)).foregroundStyle(Curb.ink.opacity(0.45))
                }
            }
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Curb.sign)
                RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Curb.flag.opacity(0.9), lineWidth: 2.5).padding(5)
            }
        )
        .opacity(rule.on ? 1 : 0.55)
    }
    static func until(_ d: Date, _ now: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: d)).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        let f = DateFormatter(); f.dateFormat = "EEE"
        return days < 7 ? f.string(from: d) : "\(days) days"
    }
}

struct GarageRow: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    let garage: Garage
    var body: some View {
        HStack(spacing: 14) {
            Button { router.sheet = .garage(garage) } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(garage.level.isEmpty ? Curb.blue : Pillar.tint(garage.level))
                        Text(garage.level.isEmpty ? "P" : garage.level).font(.sign(garage.level.count > 2 ? 16 : 22)).foregroundStyle(.white).minimumScaleFactor(0.5)
                    }
                    .frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(garage.name).font(.sign(18, .bold)).foregroundStyle(Curb.chalk)
                        Text([garage.address.isEmpty ? nil : garage.address, garage.minutes > 0 ? Fmt.span(TimeInterval(garage.minutes * 60)) : "No meter", garage.rate.map { Fmt.money($0) + "/h" }].compactMap { $0 }.joined(separator: " · "))
                            .font(.body(12.5)).foregroundStyle(Curb.dim).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            Button { router.newPark(store, garage: garage) } label: {
                Text("PARK").font(.sign(14, .heavy)).tracking(1).foregroundStyle(Curb.ink).padding(.horizontal, 14).frame(height: 36).background(Capsule().fill(Curb.paint))
            }
            .buttonStyle(Press())
        }
        .slab(14, radius: 18)
    }
}

// MARK: - Editors

struct EditorScaffold<C: View>: View {
    let title: String
    var canDelete = false
    var delete: () -> Void = {}
    let save: () -> Void
    @ViewBuilder var content: C
    @Environment(\.dismiss) private var dismiss
    @State private var confirm = false
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(title).font(.sign(32)).foregroundStyle(Curb.chalk)
                    Spacer()
                    Knob(icon: "xmark", size: 36) { dismiss() }
                }
                .padding(.top, 24)
                content
                PaintButton(title: "Save", icon: "checkmark") { save(); dismiss() }
                if canDelete {
                    KerbButton(title: "Delete", icon: "trash", tint: Curb.flag) { confirm = true }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .confirmationDialog("Delete?", isPresented: $confirm) {
            Button("Delete", role: .destructive) { delete(); dismiss() }
        }
    }
}

struct Field: View {
    let label: String
    @Binding var text: String
    var prompt: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Stencil(label)
            TextField("", text: $text, prompt: Text(prompt).foregroundColor(Curb.faint))
                .font(.sign(18, .bold)).foregroundStyle(Curb.chalk)
                .padding(.horizontal, 14).frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Curb.slab))
        }
    }
}

struct RuleEditor: View {
    @Environment(Store.self) private var store
    @State var rule: Rule
    static let presets = ["Street cleaning", "No parking", "2-hour zone", "Alternate side", "Permit only", "Snow route"]
    var body: some View {
        let exists = store.db.rules.contains(where: { $0.id == rule.id })
        EditorScaffold(title: exists ? "Street rule" : "New street rule", canDelete: exists, delete: { store.remove(rule) }, save: {
            if rule.name.trimmingCharacters(in: .whitespaces).isEmpty { rule.name = "Street cleaning" }
            store.upsert(rule)
        }) {
            RuleSign(rule: rule, now: store.now)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RuleEditor.presets, id: \.self) { p in
                        Button { rule.name = p } label: {
                            Text(p).font(.sign(14, .bold)).foregroundStyle(rule.name == p ? Curb.ink : Curb.chalk)
                                .padding(.horizontal, 12).frame(height: 36).background(Capsule().fill(rule.name == p ? Curb.paint : Curb.slab))
                        }
                        .buttonStyle(Press())
                    }
                }
            }
            .scrollClipDisabled()
            Field(label: "What", text: $rule.name, prompt: "Street cleaning")
            Field(label: "Where", text: $rule.place, prompt: "Elm St, north side")
            VStack(alignment: .leading, spacing: 8) {
                Stencil("Days")
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { d in
                        let on = rule.days.contains(d)
                        Button {
                            if on { if rule.days.count > 1 { rule.days.remove(d) } } else { rule.days.insert(d) }
                        } label: {
                            Text(["S", "M", "T", "W", "T", "F", "S"][d - 1]).font(.sign(17)).foregroundStyle(on ? Curb.ink : Curb.chalk)
                                .frame(maxWidth: .infinity).frame(height: 44)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? Curb.paint : Curb.slab))
                        }
                        .buttonStyle(Press())
                    }
                }
                .sensoryFeedback(.selection, trigger: rule.days)
            }
            HStack(spacing: 12) {
                timePick("From", minutes: $rule.start)
                timePick("To", minutes: $rule.end)
            }
            VStack(spacing: 0) {
                HStack {
                    Text("Remind me before").font(.sign(16, .bold)).foregroundStyle(Curb.chalk)
                    Spacer()
                    Picker("", selection: $rule.remindBefore) {
                        Text("Off").tag(0); Text("30 min").tag(30); Text("1 hour").tag(60); Text("2 hours").tag(120)
                    }
                    .tint(Curb.paint)
                }
                .padding(.vertical, 8)
                Divider().overlay(Curb.line)
                Toggle("The evening before, at 8 PM", isOn: $rule.eveningBefore).font(.sign(16, .bold)).foregroundStyle(Curb.chalk).tint(Curb.paint).padding(.vertical, 10)
                Divider().overlay(Curb.line)
                Toggle("On", isOn: $rule.on).font(.sign(16, .bold)).foregroundStyle(Curb.chalk).tint(Curb.paint).padding(.vertical, 10)
            }
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Curb.asphalt2))
        }
    }

    func timePick(_ label: String, minutes: Binding<Int>) -> some View {
        let b = Binding<Date>(get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(TimeInterval(minutes.wrappedValue * 60)) },
                              set: { d in let c = Calendar.current.dateComponents([.hour, .minute], from: d); minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0) })
        return HStack {
            Stencil(label)
            Spacer()
            DatePicker("", selection: b, displayedComponents: .hourAndMinute).labelsHidden()
        }
        .padding(.horizontal, 14).frame(height: 56)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Curb.slab))
    }
}

struct GarageEditor: View {
    @Environment(Store.self) private var store
    @State var garage: Garage
    @State private var rate = ""
    @State private var locating = false
    var body: some View {
        let exists = store.db.garages.contains(where: { $0.id == garage.id })
        EditorScaffold(title: exists ? "Garage" : "New garage", canDelete: exists, delete: { store.remove(garage) }, save: {
            if garage.name.trimmingCharacters(in: .whitespaces).isEmpty { garage.name = garage.address.isEmpty ? "Garage" : garage.address }
            garage.rate = Double(rate.replacingOccurrences(of: ",", with: "."))
            store.upsert(garage)
        }) {
            Field(label: "Name", text: $garage.name, prompt: "Work garage")
            Field(label: "Address", text: $garage.address, prompt: "200 W Monroe St")
            Button {
                Task {
                    locating = true
                    if let l = await Locator.shared.fix() {
                        garage.spot = Spot(lat: l.coordinate.latitude, lon: l.coordinate.longitude, accuracy: l.horizontalAccuracy)
                        if garage.address.isEmpty { garage.address = await Locator.shared.address(for: l) }
                    }
                    locating = false
                }
            } label: {
                HStack {
                    Image(systemName: garage.spot == nil ? "location" : "checkmark.circle.fill")
                    Text(locating ? "Finding you…" : (garage.spot == nil ? "Pin it where I'm standing" : "Pinned. Tap to pin again"))
                }
                .font(.sign(16, .bold)).foregroundStyle(garage.spot == nil ? Curb.paint : Curb.go)
                .frame(maxWidth: .infinity).frame(height: 48).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Curb.slab))
            }
            .buttonStyle(Press())
            HStack(spacing: 12) {
                Field(label: "Usual level", text: $garage.level, prompt: "P3")
                Field(label: "Spot", text: $garage.bay, prompt: "Row F")
            }
            HStack {
                Stencil("Meter")
                Spacer()
                Picker("", selection: $garage.minutes) {
                    Text("No meter").tag(0); Text("30 min").tag(30); Text("1 hour").tag(60); Text("2 hours").tag(120); Text("3 hours").tag(180); Text("4 hours").tag(240); Text("8 hours").tag(480); Text("10 hours").tag(600)
                }
                .tint(Curb.paint)
            }
            .padding(.horizontal, 14).frame(height: 56).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Curb.slab))
            Field(label: "Rate per hour", text: $rate, prompt: "4.00").keyboardType(.decimalPad)
            Field(label: "Note", text: $garage.note, prompt: "Take the east elevator")
        }
        .onAppear { rate = garage.rate.map { String(format: "%.2f", $0) } ?? "" }
    }
}

struct VehicleEditor: View {
    @Environment(Store.self) private var store
    @State var vehicle: Vehicle
    var body: some View {
        let exists = store.db.vehicles.contains(where: { $0.id == vehicle.id })
        EditorScaffold(title: exists ? "Car" : "New car", canDelete: exists && store.db.vehicles.count > 1, delete: { store.remove(vehicle) }, save: {
            if vehicle.name.trimmingCharacters(in: .whitespaces).isEmpty { vehicle.name = "Car \(store.db.vehicles.count + (exists ? 0 : 1))" }
            store.upsert(vehicle)
        }) {
            HStack {
                Spacer()
                CarGlyph(color: Curb.cars[vehicle.paint % Curb.cars.count], size: 130)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: vehicle.paint)
                Spacer()
            }
            .padding(.vertical, 8)
            Field(label: "Name", text: $vehicle.name, prompt: "Civic")
            Field(label: "Plate", text: $vehicle.plate, prompt: "7ABC123")
            VStack(alignment: .leading, spacing: 8) {
                Stencil("Paint")
                HStack(spacing: 10) {
                    ForEach(0..<Curb.cars.count, id: \.self) { i in
                        Button { vehicle.paint = i } label: {
                            Circle().fill(Curb.cars[i]).frame(width: 34, height: 34)
                                .overlay(Circle().strokeBorder(.white, lineWidth: vehicle.paint == i ? 3 : 0))
                                .overlay(Circle().strokeBorder(.black.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(Press())
                    }
                }
                .sensoryFeedback(.selection, trigger: vehicle.paint)
            }
        }
    }
}
