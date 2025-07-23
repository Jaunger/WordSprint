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
    @StateObject private var sm  = SoundManager.shared
    @StateObject private var router = NavRouter()

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    init() {
        DictionaryService.load()
    }
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
                    .environmentObject(router)
                    .environmentObject(tm)
                    .environmentObject(sm)
                    .accentColor(tm.theme.accent)
            }
        }
    }
}

final class NavRouter: ObservableObject {
    @Published var path = NavigationPath()
    func popToRoot() { path = NavigationPath() }
}
