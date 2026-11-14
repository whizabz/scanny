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

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                HStack(spacing: 8) {
                    Image(systemName: "doc.viewfinder")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scanny").font(.headline)
                        Text("Scan a document").font(.caption)
                    }
                    Spacer(minLength: 0)
                }
            case .accessoryInline:
                Label("Scan a document", systemImage: "doc.viewfinder")
            default:
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "doc.viewfinder")
                        .font(.title2)
                }
            }
        }
        .widgetURL(URL(string: "scanny://scan"))
        .containerBackground(for: .widget) { Color.clear }
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
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
