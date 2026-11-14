import UIKit

class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAppearance()
        setupViewControllers()
    }

    private func setupAppearance() {
        tabBar.tintColor = AppColors.primary
        tabBar.barTintColor = AppColors.dark
        tabBar.isTranslucent = false
        tabBar.unselectedItemTintColor = UIColor.gray
    }

    private func setupViewControllers() {
        // Home tab (MangaDex - Manga/Manhwa)
        let homeVC = HomeViewController()
        let homeNav = UINavigationController(rootViewController: homeVC)
        homeNav.tabBarItem = UITabBarItem(title: "Home", image: nil, tag: 0)
        homeNav.tabBarItem.setTitleTextAttributes([
            NSAttributedString.Key.font: AppFonts.caption
        ], for: .normal)
        homeNav.tabBarItem.title = "🏠 Manga"

        // Western Comics tab (Local files - CBZ, CBR, PDF, EPUB)
        let localComicsVC = LocalComicsViewController()
        let localComicsNav = UINavigationController(rootViewController: localComicsVC)
        localComicsNav.tabBarItem = UITabBarItem(title: "Western", image: nil, tag: 1)
        localComicsNav.tabBarItem.setTitleTextAttributes([
            NSAttributedString.Key.font: AppFonts.caption
        ], for: .normal)
        localComicsNav.tabBarItem.title = "📚 Western"

        // Favorites tab
        let favoritesVC = FavoritesViewController()
        let favoritesNav = UINavigationController(rootViewController: favoritesVC)
        favoritesNav.tabBarItem = UITabBarItem(title: "Favorites", image: nil, tag: 2)
        favoritesNav.tabBarItem.setTitleTextAttributes([
            NSAttributedString.Key.font: AppFonts.caption
        ], for: .normal)
        favoritesNav.tabBarItem.title = "❤️ Favorites"

        viewControllers = [homeNav, localComicsNav, favoritesNav]
    }
}
