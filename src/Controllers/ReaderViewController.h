#import <UIKit/UIKit.h>
#import "Chapter.h"

@interface ReaderViewController : UIViewController

- (instancetype)initWithChapter:(Chapter *)chapter comicTitle:(NSString *)comicTitle;
- (instancetype)initWithChapter:(Chapter *)chapter comicTitle:(NSString *)comicTitle chapterNumber:(NSInteger)chapterNumber;

@end
