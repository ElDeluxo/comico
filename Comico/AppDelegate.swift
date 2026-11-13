import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Configure global appearance
        configureAppearance()

        // Create image cache directory
        createImageCacheDirectory()

        // Setup window
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = MainTabBarController()
        window?.makeKeyAndVisible()

        return true
    }

    // MARK: - Appearance

    private func configureAppearance() {
        let orangeColor = UIColor(red: 255.0/255.0, green: 107.0/255.0, blue: 53.0/255.0, alpha: 1.0)

        UINavigationBar.appearance().barTintColor = orangeColor
        UINavigationBar.appearance().tintColor = .white
        UINavigationBar.appearance().titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.white
        ]
        UINavigationBar.appearance().isTranslucent = false

        if #available(iOS 11.0, *) {
            UINavigationBar.appearance().largeTitleTextAttributes = [
                NSAttributedString.Key.foregroundColor: UIColor.white
            ]
        }

        UITabBar.appearance().tintColor = orangeColor

        UIApplication.shared.statusBarStyle = .lightContent
    }

    // MARK: - Cache Directory

    private func createImageCacheDirectory() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let cacheURL = documentsURL.appendingPathComponent("ImageCache")
        if !fileManager.fileExists(atPath: cacheURL.path) {
            do {
                try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating image cache directory: \(error)")
            }
        }
    }

    // MARK: - Application Lifecycle

    func applicationWillResignActive(_ application: UIApplication) {}

    func applicationDidEnterBackground(_ application: UIApplication) {}

    func applicationWillEnterForeground(_ application: UIApplication) {}

    func applicationDidBecomeActive(_ application: UIApplication) {}

    func applicationWillTerminate(_ application: UIApplication) {}
}
