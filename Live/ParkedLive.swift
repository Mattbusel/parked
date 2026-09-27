import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ParkedLiveBundle: WidgetBundle {
    var body: some Widget { MeterLive() }
}

private func hex(_ v: UInt32) -> Color {
    Color(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255, opacity: 1)
}
private let asphalt = hex(0x1C1D20)
private let paint = hex(0xF6C945)
private let flag = hex(0xE8432F)
private let blue = hex(0x2B63E3)
private let chalk = hex(0xEDEBE4)

private func clock(_ d: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: d)
}

struct PBadge: View {
    var size: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous).fill(blue)
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous).strokeBorder(.white, lineWidth: max(1, size * 0.06)).padding(size * 0.08)
            Text("P").font(.system(size: size * 0.64, weight: .heavy)).foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

struct MeterLive: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeterAttributes.self) { ctx in
            LockScreenMeter(attrs: ctx.attributes, state: ctx.state)
                .activityBackgroundTint(asphalt)
                .activitySystemActionForegroundColor(chalk)
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        PBadge(size: 30)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(ctx.attributes.vehicle).font(.system(size: 14, weight: .heavy).width(.condensed)).foregroundStyle(chalk).lineLimit(1)
                            Text(ctx.attributes.level.isEmpty ? ctx.attributes.place : "Level \(ctx.attributes.level)")
                                .font(.system(size: 11, weight: .semibold)).foregroundStyle(chalk.opacity(0.6)).lineLimit(1)
                        }
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...max(Date(), ctx.state.expires), countsDown: true)
                        .font(.system(size: 30, weight: .bold).width(.compressed).monospacedDigit())
                        .foregroundStyle(paint).multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110, alignment: .trailing).padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        ProgressView(timerInterval: ctx.state.started...max(ctx.state.started.addingTimeInterval(1), ctx.state.expires), countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                            .tint(paint)
                        HStack {
                            Text("LEAVE BY \(clock(ctx.state.leaveBy))").font(.system(size: 13, weight: .heavy).width(.condensed)).tracking(1).foregroundStyle(chalk)
                            Spacer()
                            Text("OUT AT \(clock(ctx.state.expires))").font(.system(size: 13, weight: .heavy).width(.condensed)).tracking(1).foregroundStyle(flag)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                PBadge(size: 20)
            } compactTrailing: {
                Text(timerInterval: Date()...max(Date(), ctx.state.expires), countsDown: true)
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                    .foregroundStyle(paint).frame(maxWidth: 52)
            } minimal: {
                PBadge(size: 20)
            }
            .keylineTint(paint)
        }
    }
}

struct LockScreenMeter: View {
    let attrs: MeterAttributes
    let state: MeterAttributes.ContentState
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                PBadge(size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(attrs.vehicle.uppercased()).font(.system(size: 13, weight: .heavy).width(.condensed)).tracking(1.4).foregroundStyle(chalk.opacity(0.7))
                    Text(attrs.place).font(.system(size: 15, weight: .semibold)).foregroundStyle(chalk).lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(timerInterval: Date()...max(Date(), state.expires), countsDown: true)
                    .font(.system(size: 40, weight: .bold).width(.compressed).monospacedDigit())
                    .foregroundStyle(paint).multilineTextAlignment(.trailing).frame(maxWidth: 140, alignment: .trailing)
            }
            ProgressView(timerInterval: state.started...max(state.started.addingTimeInterval(1), state.expires), countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                .tint(paint)
            HStack {
                Text("LEAVE BY \(clock(state.leaveBy))")
                    .font(.system(size: 14, weight: .heavy).width(.condensed)).tracking(1).foregroundStyle(asphalt)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(chalk))
                Spacer()
                Text("METER OUT \(clock(state.expires))").font(.system(size: 13, weight: .heavy).width(.condensed)).tracking(1).foregroundStyle(flag)
            }
        }
        .padding(16)
    }
}
