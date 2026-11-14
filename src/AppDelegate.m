#import "AppDelegate.h"
#import "MainTabBarController.h"
#include <signal.h>
#include <execinfo.h>

static void ComicoSignalHandler(int sig) {
    void *callstack[64];
    int frames = backtrace(callstack, 64);
    char **strs = backtrace_symbols(callstack, frames);
    
    NSMutableString *report = [NSMutableString stringWithFormat:@"[SIGNAL %d CRASH]\n", sig];
    if (strs) {
        for (int i = 0; i < frames; ++i) {
            [report appendFormat:@"%s\n", strs[i]];
        }
        free(strs);
    }
    NSLog(@"%@", report);
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDir = [paths firstObject];
    NSString *crashFile = [docDir stringByAppendingPathComponent:@"crash_log.txt"];
    [report writeToFile:crashFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    signal(sig, SIG_DFL);
    raise(sig);
}

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
    signal(SIGSEGV, ComicoSignalHandler);
    signal(SIGBUS, ComicoSignalHandler);
    signal(SIGABRT, ComicoSignalHandler);
    signal(SIGILL, ComicoSignalHandler);
    signal(SIGFPE, ComicoSignalHandler);
    
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

