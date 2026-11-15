import SwiftUI
import UIKit

/// Home Screen quick actions (long press on the app icon). The "Scan a document"
/// item sets a flag that ContentView turns into opening the scanner.
@Observable
final class QuickActions {
    static let shared = QuickActions()
    static let scanType = "xyz.saltedchips.scanny.scan"
    static let importType = "xyz.saltedchips.scanny.import"

    var scanRequested = false
    var importRequested = false

    @discardableResult
    static func handle(_ item: UIApplicationShortcutItem) -> Bool {
        switch item.type {
        case scanType:
            DispatchQueue.main.async { shared.scanRequested = true }
            return true
        case importType:
            DispatchQueue.main.async { shared.importRequested = true }
            return true
        default:
            return false
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let item = options.shortcutItem { QuickActions.handle(item) }
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        completionHandler(QuickActions.handle(shortcutItem))
    }
}
