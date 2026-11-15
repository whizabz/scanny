import SwiftUI
import WidgetKit

/// Lock screen widget. Tapping it opens Scanny straight into the scanner
/// (the app handles the scanny://scan link).
struct ScanEntry: TimelineEntry {
    let date: Date
}

struct ScanProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScanEntry { ScanEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (ScanEntry) -> Void) {
        completion(ScanEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScanEntry>) -> Void) {
        // Static content, so there is nothing to refresh.
        completion(Timeline(entries: [ScanEntry(date: .now)], policy: .never))
    }
}

struct ScanWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                HStack(spacing: 8) {
                    ScanMark(bracketWeight: 0.045).frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scanny").font(.headline)
                        Text("Scan a document").font(.caption)
                    }
                    Spacer(minLength: 0)
                }
            case .accessoryInline:
                Label("Scan a document", systemImage: "doc.viewfinder")
            case .systemSmall:
                VStack(spacing: 8) {
                    AppIconElements(knockout: renderingMode != .fullColor).padding(8)
                    Text("Scan Document")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                }
            default:
                ZStack {
                    AccessoryWidgetBackground()
                    ScanMark(bracketWeight: 0.05).padding(11)
                }
            }
        }
        .widgetURL(URL(string: "scanny://scan"))
        .containerBackground(for: .widget) {
            if family == .systemSmall {
                ZStack {
                    if colorScheme == .dark {
                        // Dark appearance: the app icon's dark background. On the Home
                        // Screen it shows as a grey from about 18% to 8% white, but the
                        // system lifts a widget's dark colours (0.26 showed as 0.43), so
                        // these are set lower to land on the icon's.
                        LinearGradient(colors: [Color(white: 0.06), Color(white: 0.016)],
                                       startPoint: .top, endPoint: .bottom)
                    } else {
                        LinearGradient(
                            colors: [Color(.displayP3, red: 1.0, green: 0.74, blue: 0.30),
                                     Color(.displayP3, red: 0.90, green: 0.26, blue: 0.30)],
                            startPoint: .top, endPoint: .bottom)
                    }
                    MatGrid(opacity: colorScheme == .dark ? 0.035 : 0.08)
                }
            } else {
                Color.clear
            }
        }
    }
}

@main
struct ScanWidget: Widget {
    let kind = "ScanWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScanProvider()) { _ in
            ScanWidgetView()
        }
        .configurationDisplayName("Scan")
        .description("Open Scanny straight into the scanner.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
