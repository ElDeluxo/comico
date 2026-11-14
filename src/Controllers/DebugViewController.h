#import <UIKit/UIKit.h>

extern NSString * const ComicoLogNotification;
extern NSString * const ComicoLogMessageKey;
extern NSString * const ComicoSkipThumbnailsKey;
extern NSString * const ComicoSettingsChangedNotification;

BOOL ComicoIsSkipThumbnailsEnabled(void);
void ComicoSetSkipThumbnailsEnabled(BOOL enabled);

void ComicoLog(NSString *format, ...);

@interface DebugViewController : UIViewController

@end

