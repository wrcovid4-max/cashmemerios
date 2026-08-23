import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen banner and Dynamic Island presentation for an in-flight receipt scan.
@available(iOS 16.1, *)
struct ScanLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScanActivityAttributes.self) { context in
            lockScreenBanner(context.state, source: context.attributes.source)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.phase.symbolName)
                        .font(.title2)
                        .foregroundStyle(tint(for: context.state))
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.itemsFound > 0 {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("\(context.state.itemsFound)")
                                .font(.title3.bold())
                            Text("items")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.trailing, 4)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.headline)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(context.state.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if !context.state.isTerminal {
                        ProgressView(value: context.state.progress)
                            .tint(tint(for: context.state))
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.phase.symbolName)
                    .foregroundStyle(tint(for: context.state))
            } compactTrailing: {
                if context.state.isTerminal {
                    Text(context.state.itemsFound > 0 ? "\(context.state.itemsFound)" : "")
                        .font(.caption2.bold())
                } else {
                    ProgressView(value: context.state.progress)
                        .progressViewStyle(.circular)
                        .tint(tint(for: context.state))
                }
            } minimal: {
                Image(systemName: context.state.phase.symbolName)
                    .foregroundStyle(tint(for: context.state))
            }
            .widgetURL(URL(string: "cashmemer://new"))
            .keylineTint(tint(for: context.state))
        }
    }

    private func lockScreenBanner(
        _ state: ScanActivityAttributes.ContentState,
        source: String
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint(for: state).opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: state.phase.symbolName)
                    .font(.title3)
                    .foregroundStyle(tint(for: state))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(state.headline)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(state.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !state.isTerminal {
                    ProgressView(value: state.progress)
                        .tint(tint(for: state))
                }
            }

            Spacer(minLength: 0)

            Text(source)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
    }

    private func tint(for state: ScanActivityAttributes.ContentState) -> Color {
        switch state.phase {
        case .failed: return .red
        case .finished: return .green
        default: return Color(red: 0.11, green: 0.48, blue: 0.14)
        }
    }
}
