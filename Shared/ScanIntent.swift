import AppIntents
import Observation

/// Set by the Control Center control's intent and observed by ContentView.
@Observable
final class ScanSignal {
    static let shared = ScanSignal()
    var requested = false
}

/// The Control Center control's action. It runs inside the app (it opens the
/// app in the foreground) and asks it to start the scanner.
struct ScanIntent: AppIntent {
    static let title: LocalizedStringResource = "New Scan"
    static let description = IntentDescription("Open Scanny straight into the scanner.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        ScanSignal.shared.requested = true
        return .result()
    }
}
