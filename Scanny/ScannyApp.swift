import SwiftUI
import TipKit

@main
struct ScannyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Remove exported scans left behind if the app was killed before it could clean up.
        ScanExport.clear()
        try? Tips.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
