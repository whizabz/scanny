import SwiftUI
import TipKit

/// Start screen tip about opening the scanner automatically. TipKit remembers when
/// someone dismisses it, so it doesn't come back.
struct AutoLaunchTip: Tip {
    var title: Text { Text("Skip the start screen") }
    var message: Text? { Text("Scanny can open straight into the scanner when it launches.") }
    var image: Image? { Image(systemName: "doc.viewfinder") }
    var actions: [Action] {
        Action(id: "settings", title: "Open Settings")
    }
}

/// Same tip, with the action as a plain text link instead of a filled button.
struct LinkTipStyle: TipViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 12) {
            configuration.image
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                configuration.title.font(.headline)
                configuration.message?.font(.subheadline).foregroundStyle(.secondary)
                ForEach(configuration.actions) { action in
                    Button(action: action.handler) { action.label() }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            Button("Dismiss", systemImage: "xmark") {
                configuration.tip.invalidate(reason: .tipClosed)
            }
            .labelStyle(.iconOnly)
            .font(.footnote.weight(.bold))
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}
