#import "ComicGridCell.h"
#import "ImageCache.h"

@interface ComicGridCell ()
@property (nonatomic, strong) UIImageView *coverImageView;
@property (nonatomic, strong) UIView *gradientOverlay;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *statusBadge;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, copy) NSString *currentImageURL;
@end

@implementation ComicGridCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        self.layer.cornerRadius = 8.0;
        self.layer.masksToBounds = YES;
        
        _coverImageView = [[UIImageView alloc] initWithFrame:self.bounds];
        _coverImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _coverImageView.contentMode = UIViewContentModeScaleAspectFill;
        _coverImageView.clipsToBounds = YES;
        [self.contentView addSubview:_coverImageView];
        
        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _spinner.center = CGPointMake(frame.size.width / 2.0, frame.size.height / 2.0);
        _spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        _spinner.hidesWhenStopped = YES;
        [self.contentView addSubview:_spinner];
        
        // Translucent bottom banner
        CGFloat bannerHeight = 54.0;
        _gradientOverlay = [[UIView alloc] initWithFrame:CGRectMake(0, frame.size.height - bannerHeight, frame.size.width, bannerHeight)];
        _gradientOverlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.80];
        _gradientOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [self.contentView addSubview:_gradientOverlay];
        
        // Title
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(6, 4, frame.size.width - 12, 30)];
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.font = [UIFont boldSystemFontOfSize:11.5];
        _titleLabel.numberOfLines = 2;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [_gradientOverlay addSubview:_titleLabel];
        
        // Status Badge & Origin
        _statusBadge = [[UILabel alloc] initWithFrame:CGRectMake(6, 35, frame.size.width - 12, 14)];
        _statusBadge.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _statusBadge.font = [UIFont boldSystemFontOfSize:9.5];
        [_gradientOverlay addSubview:_statusBadge];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.coverImageView.image = nil;
    self.currentImageURL = nil;
    [self.spinner stopAnimating];
}

- (void)configureWithComic:(Comic *)comic {
    self.titleLabel.text = comic.title;
    
    // Display Origin + Status
    NSString *origin = comic.originBadge ?: @"Cómic";
    self.statusBadge.text = [NSString stringWithFormat:@"%@ • %@", origin, comic.status ?: @""];
    
    if ([comic.originalLanguage isEqualToString:@"en"]) {
        self.statusBadge.textColor = [UIColor colorWithRed:0.3 green:0.75 blue:1.0 alpha:1.0]; // Cyan para cómics occidentales
    } else if ([comic.originalLanguage isEqualToString:@"ko"]) {
        self.statusBadge.textColor = [UIColor colorWithRed:0.8 green:0.5 blue:1.0 alpha:1.0]; // Púrpura para Manhwa
    } else if ([comic.originalLanguage isEqualToString:@"ja"]) {
        self.statusBadge.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.5 alpha:1.0]; // Coral para Manga
    } else {
        self.statusBadge.textColor = [UIColor colorWithRed:1.0 green:0.75 blue:0.3 alpha:1.0]; // Ámbar para otros
    }
    
    if (!comic.coverURL || comic.coverURL.length == 0) {
        self.coverImageView.image = nil;
        self.coverImageView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
        return;
    }
    
    self.currentImageURL = comic.coverURL;
    
    UIImage *cached = [[ImageCache sharedCache] imageForURL:comic.coverURL];
    if (cached) {
        self.coverImageView.image = cached;
        [self.spinner stopAnimating];
        return;
    }
    
    [self.spinner startAnimating];
    self.coverImageView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    
    NSString *requestedURL = comic.coverURL;
    [[ImageCache sharedCache] loadImageForURL:requestedURL completion:^(UIImage *image) {
        if ([self.currentImageURL isEqualToString:requestedURL]) {
            [self.spinner stopAnimating];
            if (image) {
                self.coverImageView.image = image;
            }
        }
    }];
}

@end
