import SwiftUI
import FirebaseCore

// 1. Delegate stays, ready for future services
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct WordSprintApp: App {
    @StateObject private var tm = ThemeManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    init() {
        DictionaryService.load()
    }
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
                    .environmentObject(tm)  
            }
        }
    }
}
