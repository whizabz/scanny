import SwiftUI

@main
struct ScannyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Remove exported scans left behind if the app was killed before it could clean up.
        ScanExport.clear()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
