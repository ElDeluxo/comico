#import "AppDelegate.h"
#import "MainTabBarController.h"

static void ComicoUncaughtExceptionHandler(NSException *exception) {
    NSString *report = [NSString stringWithFormat:@"[CRASH] %@: %@\n%@",
                        exception.name, exception.reason,
                        [exception.callStackSymbols componentsJoinedByString:@"\n"]];
    NSLog(@"%@", report);
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDir = [paths firstObject];
    NSString *crashFile = [docDir stringByAppendingPathComponent:@"crash_log.txt"];
    [report writeToFile:crashFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSSetUncaughtExceptionHandler(&ComicoUncaughtExceptionHandler);
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:1.0];
    
    // Global Navigation Bar styling for iOS 9
    [[UINavigationBar appearance] setBarStyle:UIBarStyleBlack];
    [[UINavigationBar appearance] setBarTintColor:[UIColor colorWithRed:0.10 green:0.10 blue:0.15 alpha:1.0]];
    [[UINavigationBar appearance] setTintColor:[UIColor colorWithRed:1.0 green:0.4 blue:0.5 alpha:1.0]];
    [[UINavigationBar appearance] setTitleTextAttributes:@{
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSFontAttributeName: [UIFont boldSystemFontOfSize:17.0]
    }];
    
    MainTabBarController *tabBarController = [[MainTabBarController alloc] init];
    self.window.rootViewController = tabBarController;
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end

