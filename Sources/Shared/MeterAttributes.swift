import ActivityKit
import Foundation

/// What the Lock Screen and Dynamic Island show while a meter is running. Shared by the app and the Live extension.
struct MeterAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var started: Date
        var expires: Date
        var leaveBy: Date
    }
    var session: String
    var vehicle: String
    var place: String
    var level: String
    var paint: Int
}

/// Paint colours shared with the extension (the extension cannot see the app's theme).
enum SharedPaint {
    static let rgb: [UInt32] = [0xE8432F, 0x2B63E3, 0xF6C945, 0x49C27F, 0xEDEBE4, 0x8E6CF0, 0xF08A3C, 0x5C6068]
}
