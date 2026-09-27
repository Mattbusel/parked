import SwiftUI
import MapKit
import PhotosUI

/// Park here: the pin, the meter, where in the garage, a photo and a note.
struct ParkSheet: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    @State var draft: Session
    @State private var mode: Mode
    @State private var minutes: Int
    @State private var until: Date
    @State private var locating = false
    @State private var camera = false
    @State private var pick: PhotosPickerItem?
    @State private var costText: String
    @State private var bump = 0

    enum Mode: String, CaseIterable { case meter = "Meter", until = "Until", none = "No meter" }

    init(draft: Session) {
        _draft = State(initialValue: draft)
        let mins = draft.expires.map { Int(($0.timeIntervalSince(draft.start) / 60).rounded()) } ?? 0
        _minutes = State(initialValue: mins)
        _mode = State(initialValue: draft.expires == nil && !(draft.spot == nil && draft.address.isEmpty) ? .none : .meter)
        _until = State(initialValue: draft.expires ?? draft.start.addingTimeInterval(7200))
        _costText = State(initialValue: draft.cost.map { String(format: "%.2f", $0) } ?? "")
    }

    var exists: Bool { store.session(draft.id) != nil }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 12) {
                    PSign(size: 42)
                    Text(exists ? "Edit spot" : "Park here").font(.sign(34)).foregroundStyle(Curb.chalk)
                    Spacer()
                    Knob(icon: "xmark", size: 36) { dismiss() }
                }
                .padding(.top, 22)

                pin
                if store.db.vehicles.count > 1 { carPicker }
                meter
                garage
                photo
                notes

                PaintButton(title: exists ? "Save" : (mode == .none ? "Save the spot" : "Start the meter"), icon: exists ? "checkmark" : "parkingsign") { save() }
                    .sensoryFeedback(.success, trigger: bump)
                if exists {
                    KerbButton(title: "Delete this spot", icon: "trash", tint: Curb.flag) {
                        store.delete(draft); Alerts.shared.cancel(draft.id); LiveMeter.end(draft.id); dismiss()
                    }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .task { if draft.spot == nil && !exists { await locate() } }
        .fullScreenCover(isPresented: $camera) {
            CameraPicker { img in if let img, let name = store.savePhoto(img) { draft.photo = name } }.ignoresSafeArea()
        }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data), let name = store.savePhoto(img) { draft.photo = name }
                pick = nil
            }
        }
    }

    // MARK: pin

    var pin: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                if let spot = draft.spot {
                    Map(initialPosition: .camera(MapCamera(centerCoordinate: spot.coordinate, distance: 450))) {
                        Annotation("", coordinate: spot.coordinate, anchor: .bottom) { SignPin(paint: store.vehicle(draft.vehicleID)?.paint ?? 0) }
                    }
                    .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                    .allowsHitTesting(false)
                    .id("\(spot.lat),\(spot.lon)")
                } else {
                    Curb.asphalt2
                    VStack(spacing: 10) {
                        if locating { ProgressView().tint(Curb.paint) }
                        Text(locating ? "Finding the spot…" : (Locator.shared.denied ? "Location is off for Parked" : "No pin yet"))
                            .font(.sign(17, .bold)).foregroundStyle(Curb.dim)
                        if Locator.shared.denied {
                            Button("Open Settings") { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } }
                                .font(.sign(15, .bold)).foregroundStyle(Curb.paint)
                        }
                    }
                }
            }
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Curb.line))
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    TextField("", text: $draft.address, prompt: Text("Street or place").foregroundColor(Curb.faint))
                        .font(.sign(19, .bold)).foregroundStyle(Curb.chalk)
                    if let s = draft.spot, s.accuracy > 0 {
                        Text("Pinned within \(Fmt.distance(s.accuracy))").font(.body(12)).foregroundStyle(Curb.faint)
                    }
                }
                Spacer()
                Knob(icon: "location.fill", tint: Curb.paint, size: 40) { Task { await locate() } }
                    .accessibilityLabel("Pin my location again")
            }
        }
    }

    func locate() async {
        locating = true
        defer { locating = false }
        guard let l = await Locator.shared.fix() else { return }
        withAnimation { draft.spot = Spot(lat: l.coordinate.latitude, lon: l.coordinate.longitude, accuracy: max(0, l.horizontalAccuracy)) }
        if draft.address.isEmpty { draft.address = await Locator.shared.address(for: l) }
    }

    // MARK: car

    var carPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Stencil("Car")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.db.vehicles) { v in
                        let on = v.id == draft.vehicleID
                        Button { draft.vehicleID = v.id } label: {
                            HStack(spacing: 8) {
                                CarGlyph(color: Curb.cars[v.paint % Curb.cars.count], size: 22)
                                Text(v.name).font(.sign(15, .bold))
                            }
                            .foregroundStyle(on ? Curb.ink : Curb.chalk)
                            .padding(.horizontal, 14).frame(height: 40)
                            .background(Capsule().fill(on ? Curb.paint : Curb.slab))
                        }
                        .buttonStyle(Press())
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    // MARK: meter

    var meter: some View {
        VStack(alignment: .leading, spacing: 12) {
            Stencil("Meter")
            HStack(spacing: 4) {
                ForEach(Mode.allCases, id: \.self) { m in
                    Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { mode = m } } label: {
                        Text(m.rawValue.uppercased()).font(.sign(14, .heavy)).tracking(1)
                            .foregroundStyle(mode == m ? Curb.ink : Curb.dim)
                            .frame(maxWidth: .infinity).frame(height: 38)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(mode == m ? Curb.paint : .clear))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4).background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Curb.slab))
            .sensoryFeedback(.selection, trigger: mode)

            switch mode {
            case .meter:
                VStack(spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(minutes == 0 ? "0:00" : Fmt.countdown(TimeInterval(minutes * 60)).dropLast(3).description)
                            .font(.meter(64)).foregroundStyle(minutes == 0 ? Curb.faint : Curb.paint)
                            .contentTransition(.numericText())
                        Text(minutes == 0 ? "" : (minutes >= 60 ? "h:mm" : "min")).font(.sign(14, .bold)).foregroundStyle(Curb.dim)
                        Spacer()
                        if minutes > 0 {
                            VStack(alignment: .trailing, spacing: 0) {
                                Stencil("Runs out")
                                Text(Fmt.clock(draft.start.addingTimeInterval(TimeInterval(minutes * 60)))).font(.sign(20)).foregroundStyle(Curb.chalk)
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        coin("+15", 15); coin("+30", 30); coin("+1h", 60); coin("+2h", 120)
                        Button { withAnimation { minutes = 0 } } label: {
                            Image(systemName: "arrow.counterclockwise").font(.system(size: 15, weight: .bold)).foregroundStyle(Curb.dim)
                                .frame(width: 46, height: 52).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Curb.slab))
                        }
                        .buttonStyle(Press()).accessibilityLabel("Reset the meter")
                    }
                }
                .slab(16, radius: 20)
            case .until:
                HStack {
                    Text("Time's up at").font(.sign(18, .bold)).foregroundStyle(Curb.chalk)
                    Spacer()
                    DatePicker("", selection: $until, in: draft.start.addingTimeInterval(300)..., displayedComponents: [.hourAndMinute]).labelsHidden()
                }
                .slab(16, radius: 20)
            case .none:
                Text("Just the spot. Handy for garages and free streets: no countdown, no reminders.")
                    .font(.body(13.5)).foregroundStyle(Curb.dim).slab(16, radius: 20)
            }

            if mode != .none {
                HStack(spacing: 12) {
                    Image(systemName: "figure.walk").font(.system(size: 16, weight: .bold)).foregroundStyle(Curb.go).frame(width: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Walk back").font(.sign(16, .bold)).foregroundStyle(Curb.chalk)
                        Text("Your \"head back now\" alert comes this early. Parked uses the real distance when it knows it.")
                            .font(.body(11.5)).foregroundStyle(Curb.faint).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Stepper("\(draft.walkMins) min", value: $draft.walkMins, in: 0...60, step: 5).labelsHidden()
                    Text("\(draft.walkMins)m").font(.sign(18)).foregroundStyle(Curb.chalk).frame(width: 40, alignment: .trailing)
                }
                .slab(14, radius: 18)
                HStack(spacing: 12) {
                    Image(systemName: "dollarsign.circle.fill").font(.system(size: 17, weight: .bold)).foregroundStyle(Curb.paint).frame(width: 26)
                    Text("Paid").font(.sign(16, .bold)).foregroundStyle(Curb.chalk)
                    Spacer()
                    TextField("", text: $costText, prompt: Text("0.00").foregroundColor(Curb.faint))
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        .font(.sign(20)).foregroundStyle(Curb.chalk).frame(width: 110)
                }
                .slab(14, radius: 18)
            }
        }
    }

    func coin(_ label: String, _ add: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { minutes = min(minutes + add, 24 * 60) }
            bump += 1
        } label: {
            Text(label).font(.sign(19)).foregroundStyle(Curb.ink)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0xF9DB7A), Curb.paint, Curb.paintDeep], startPoint: .top, endPoint: .bottom))
                )
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 1).padding(3))
        }
        .buttonStyle(Press())
        .sensoryFeedback(.impact(weight: .light), trigger: minutes)
    }

    // MARK: garage

    static let levels = ["G", "P1", "P2", "P3", "P4", "P5", "B1", "B2", "B3", "Roof"]

    var garage: some View {
        VStack(alignment: .leading, spacing: 10) {
            Stencil("In a garage?")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ParkSheet.levels, id: \.self) { l in
                        let on = draft.level == l
                        Button { withAnimation(.spring(response: 0.3)) { draft.level = on ? "" : l } } label: {
                            Text(l).font(.sign(17)).foregroundStyle(on ? .white : Curb.chalk)
                                .frame(minWidth: 50).frame(height: 44).padding(.horizontal, 4)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? Pillar.tint(l) : Curb.slab))
                        }
                        .buttonStyle(Press())
                    }
                }
            }
            .scrollClipDisabled()
            .sensoryFeedback(.selection, trigger: draft.level)
            HStack(spacing: 10) {
                field("Level", text: $draft.level, width: 110)
                field("Spot, row or colour", text: $draft.bay, width: nil)
            }
        }
    }

    func field(_ prompt: String, text: Binding<String>, width: CGFloat?) -> some View {
        TextField("", text: text, prompt: Text(prompt).foregroundColor(Curb.faint))
            .font(.sign(17, .bold)).foregroundStyle(Curb.chalk)
            .padding(.horizontal, 14).frame(height: 48)
            .frame(width: width)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Curb.slab))
    }

    // MARK: photo and note

    var photo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Stencil("Photo of the sign, meter or pillar")
            if let img = store.image(draft.photo) {
                Image(uiImage: img).resizable().scaledToFill().frame(height: 200).frame(maxWidth: .infinity).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Knob(icon: "trash", tint: Curb.flag, size: 36) { draft.photo = nil }.padding(10)
                    }
            }
            HStack(spacing: 10) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    KerbButton(title: "Take photo", icon: "camera.fill", tint: Curb.paint) { camera = true }
                }
                PhotosPicker(selection: $pick, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle").font(.system(size: 14, weight: .bold))
                        Text("From library").font(.sign(16, .bold))
                    }
                    .foregroundStyle(Curb.chalk).frame(maxWidth: .infinity).frame(height: 48)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Curb.slab))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Curb.line))
                }
            }
        }
    }

    var notes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Stencil("Note")
            TextField("", text: $draft.note, prompt: Text("Near the elevator, by the blue door…").foregroundColor(Curb.faint), axis: .vertical)
                .lineLimit(2...5).font(.body(15)).foregroundStyle(Curb.chalk)
                .padding(14).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Curb.slab))
        }
    }

    // MARK: save

    func save() {
        var s = draft
        switch mode {
        case .meter: s.expires = minutes > 0 ? s.start.addingTimeInterval(TimeInterval(minutes * 60)) : nil
        case .until:
            // A time earlier than now means tomorrow.
            var u = until
            if u <= s.start { u = u.addingTimeInterval(86400) }
            s.expires = u
        case .none: s.expires = nil
        }
        s.cost = Double(costText.replacingOccurrences(of: ",", with: "."))
        s.address = s.address.trimmingCharacters(in: .whitespaces)
        bump += 1
        if exists { store.update(s) } else {
            store.park(s)
            if let v = store.vehicle(s.vehicleID) { store.select(v) }
            if pro.unlocked && store.db.settings.live && s.expires != nil, let v = store.vehicle(s.vehicleID) {
                LiveMeter.start(s, vehicle: v, leaveBy: store.leaveBy(s, walk: nil))
            }
        }
        if exists, let v = store.vehicle(s.vehicleID), LiveMeter.isRunning(s.id) { LiveMeter.start(s, vehicle: v, leaveBy: store.leaveBy(s, walk: nil)) }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { router.tab = .meter }
        dismiss()
    }
}

/// The car's pin on a map: a little blue P sign on a post with the car's paint at the foot.
struct SignPin: View {
    var paint: Int
    var body: some View {
        VStack(spacing: 0) {
            PSign(size: 34)
            Rectangle().fill(LinearGradient(colors: [Color(hex: 0xC9CBD0), Color(hex: 0x7C7F86)], startPoint: .leading, endPoint: .trailing)).frame(width: 4, height: 16)
            Ellipse().fill(Curb.cars[paint % Curb.cars.count]).frame(width: 18, height: 7)
                .overlay(Ellipse().strokeBorder(.black.opacity(0.4), lineWidth: 1))
        }
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }
}

/// Add time to a running meter.
struct ExtendSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var add = 0

    var body: some View {
        let s = store.session(id)
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Add time").font(.sign(30)).foregroundStyle(Curb.chalk)
                Spacer()
                Knob(icon: "xmark", size: 36) { dismiss() }
            }
            .padding(.top, 24)
            if let s, let e = s.expires {
                let base = max(e, store.now)
                HStack(alignment: .firstTextBaseline) {
                    Text(add == 0 ? Fmt.clock(e) : Fmt.clock(base.addingTimeInterval(TimeInterval(add * 60))))
                        .font(.meter(56)).foregroundStyle(add == 0 ? Curb.dim : Curb.paint).contentTransition(.numericText())
                    Spacer()
                    if add > 0 { Text("+\(Fmt.span(TimeInterval(add * 60)))").font(.sign(20)).foregroundStyle(Curb.chalk) }
                }
                HStack(spacing: 8) {
                    ForEach([10, 15, 30, 60], id: \.self) { m in
                        Button { withAnimation(.spring(response: 0.3)) { add += m } } label: {
                            Text(m < 60 ? "+\(m)" : "+1h").font(.sign(19)).foregroundStyle(Curb.ink)
                                .frame(maxWidth: .infinity).frame(height: 50)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Curb.paint))
                        }
                        .buttonStyle(Press())
                    }
                }
                .sensoryFeedback(.impact(weight: .light), trigger: add)
                PaintButton(title: add == 0 ? "Pick some time" : "Fed the meter", icon: "checkmark", color: add == 0 ? Curb.slab : Curb.go, text: add == 0 ? Curb.dim : Curb.ink) {
                    guard add > 0 else { return }
                    store.extend(s, minutes: add)
                    if let v = store.vehicle(s.vehicleID), let fresh = store.session(id), LiveMeter.isRunning(id) {
                        LiveMeter.start(fresh, vehicle: v, leaveBy: store.leaveBy(fresh, walk: nil))
                    }
                    dismiss()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }
}

/// The photo, big, with pinch to zoom.
struct PhotoView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var scale: CGFloat = 1
    @State private var base: CGFloat = 1

    var body: some View {
        let s = store.session(id)
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            if let img = store.image(s?.photo) {
                Image(uiImage: img).resizable().scaledToFit()
                    .scaleEffect(scale)
                    .gesture(MagnifyGesture().onChanged { v in scale = max(1, min(5, base * v.magnification)) }.onEnded { _ in base = scale })
                    .onTapGesture(count: 2) { withAnimation(.spring) { scale = scale > 1 ? 1 : 2.5; base = scale } }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Stencil(s.map { Fmt.day($0.start) + " · " + Fmt.clock($0.start) } ?? "", color: Curb.paint)
                        Text(s?.place ?? "").font(.sign(20, .bold)).foregroundStyle(.white).lineLimit(2)
                    }
                    Spacer()
                    Knob(icon: "xmark", size: 38) { dismiss() }
                }
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 30)
                .background(LinearGradient(colors: [.black.opacity(0.85), .clear], startPoint: .top, endPoint: .bottom))
                Spacer()
                if let note = s?.note, !note.isEmpty {
                    Text(note).font(.body(15)).foregroundStyle(.white).padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                }
            }
        }
    }
}

/// The system camera, for a quick photo of the sign.
struct CameraPicker: UIViewControllerRepresentable {
    var done: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.done(info[.originalImage] as? UIImage)
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.done(nil); parent.dismiss() }
    }
}
