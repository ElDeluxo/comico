#import <UIKit/UIKit.h>

extern NSString * const ComicoLogNotification;
extern NSString * const ComicoLogMessageKey;

void ComicoLog(NSString *format, ...);

@interface DebugViewController : UIViewController

@end

