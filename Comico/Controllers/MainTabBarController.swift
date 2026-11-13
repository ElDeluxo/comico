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
        // Home tab
        let homeVC = HomeViewController()
        let homeNav = UINavigationController(rootViewController: homeVC)
        homeNav.tabBarItem = UITabBarItem(title: "Home", image: nil, tag: 0)
        homeNav.tabBarItem.setTitleTextAttributes([
            NSAttributedString.Key.font: AppFonts.caption
        ], for: .normal)
        // Use text-based icon for iOS 9 compatibility
        homeNav.tabBarItem.title = "🏠 Home"

        // Favorites tab
        let favoritesVC = FavoritesViewController()
        let favoritesNav = UINavigationController(rootViewController: favoritesVC)
        favoritesNav.tabBarItem = UITabBarItem(title: "Favorites", image: nil, tag: 1)
        favoritesNav.tabBarItem.setTitleTextAttributes([
            NSAttributedString.Key.font: AppFonts.caption
        ], for: .normal)
        favoritesNav.tabBarItem.title = "❤️ Favorites"

        viewControllers = [homeNav, favoritesNav]
    }
}
