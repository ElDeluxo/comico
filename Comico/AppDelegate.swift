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

        // Handle launch from URL (e.g. opening a comic file)
        if let url = launchOptions?[.url] as? URL {
            handleIncomingURL(url)
        }

        return true
    }

    // MARK: - Open URL Handling

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return handleIncomingURL(url)
    }

    func application(_ application: UIApplication, handleOpen url: URL) -> Bool {
        return handleIncomingURL(url)
    }

    private func handleIncomingURL(_ url: URL) -> Bool {
        // Security-scoped resource access for iOS 11+
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Copiar archivo al directorio de comics de la app
        let fileManager = FileManager.default
        let comicsDir = LocalComicLibrary.shared.importDirectoryURL
        let fileName = url.lastPathComponent
        let destinationURL = comicsDir.appendingPathComponent(fileName)

        var finalURL = destinationURL
        var counter = 1
        while fileManager.fileExists(atPath: finalURL.path) {
            let nameWithoutExt = (fileName as NSString).deletingPathExtension
            let ext = fileName.pathExtension
            finalURL = comicsDir.appendingPathComponent("\(nameWithoutExt) (\(counter)).\(ext)")
            counter += 1
        }

        do {
            try fileManager.copyItem(at: url, to: finalURL)

            // Importar a la biblioteca
            if let comic = LocalComicLibrary.shared.importComic(from: finalURL) {
                // Cambiar a la pestaña de Western Comics y abrir el lector
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.openComicInReader(comic)
                }
            }
            return true
        } catch {
            print("Error importing comic from URL: \(error)")
            return false
        }
    }

    private func openComicInReader(_ comic: LocalComic) {
        guard let window = window,
              let tabBar = window.rootViewController as? UITabBarController,
              let navControllers = tabBar.viewControllers as? [UINavigationController],
              navControllers.count >= 2 else { return }

        // Cambiar a la pestaña de Western Comics (índice 1)
        tabBar.selectedIndex = 1

        // Presentar el lector
        let localComicsNav = navControllers[1]
        let readerVC = LocalComicReaderViewController(comic: comic, startPage: 0)
        localComicsNav.pushViewController(readerVC, animated: true)
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
