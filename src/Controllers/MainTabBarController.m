#import "MainTabBarController.h"
#import "HomeViewController.h"
#import "FavoritesViewController.h"

@implementation MainTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Tab 1: Explorar
    HomeViewController *homeVC = [[HomeViewController alloc] init];
    UINavigationController *navHome = [[UINavigationController alloc] initWithRootViewController:homeVC];
    navHome.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Explorar" image:nil tag:0];
    
    // Tab 2: Favoritos
    FavoritesViewController *favVC = [[FavoritesViewController alloc] init];
    UINavigationController *navFav = [[UINavigationController alloc] initWithRootViewController:favVC];
    navFav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Favoritos" image:nil tag:1];
    
    self.viewControllers = @[navHome, navFav];
    
    // Styling
    self.tabBar.barStyle = UIBarStyleBlack;
    self.tabBar.barTintColor = [UIColor colorWithRed:0.10 green:0.10 blue:0.14 alpha:1.0];
    self.tabBar.tintColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.5 alpha:1.0];
}

@end
