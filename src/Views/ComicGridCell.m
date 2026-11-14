#import "ComicGridCell.h"
#import "ImageCache.h"
#import "DebugViewController.h"

@interface ComicGridCell ()
@property (nonatomic, strong) UIImageView *coverImageView;
@property (nonatomic, strong) UIView *gradientOverlay;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *statusBadge;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, copy) NSString *currentImageURL;

// Modo sin miniaturas (Tarjeta estilizada de lectura rápida)
@property (nonatomic, strong) UIView *cardContainer;
@property (nonatomic, strong) UILabel *cardOriginBadge;
@property (nonatomic, strong) UILabel *cardIconLabel;
@property (nonatomic, strong) UILabel *cardTitleLabel;
@property (nonatomic, strong) UILabel *cardStatusBadge;
@end

@implementation ComicGridCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        self.layer.cornerRadius = 8.0;
        self.layer.masksToBounds = YES;
        
        // --- 1. Modo Normal con Miniatura ---
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
        
        // --- 2. Modo Seguro (Sin Miniatura - Tarjeta Estilizada) ---
        _cardContainer = [[UIView alloc] initWithFrame:self.bounds];
        _cardContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _cardContainer.layer.cornerRadius = 8.0;
        _cardContainer.layer.masksToBounds = YES;
        _cardContainer.hidden = YES;
        [self.contentView addSubview:_cardContainer];
        
        _cardOriginBadge = [[UILabel alloc] initWithFrame:CGRectMake(8, 8, frame.size.width - 16, 20)];
        _cardOriginBadge.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _cardOriginBadge.font = [UIFont boldSystemFontOfSize:10.0];
        _cardOriginBadge.textAlignment = NSTextAlignmentCenter;
        _cardOriginBadge.layer.cornerRadius = 4.0;
        _cardOriginBadge.layer.masksToBounds = YES;
        [_cardContainer addSubview:_cardOriginBadge];
        
        _cardIconLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, frame.size.height * 0.16, frame.size.width, 36)];
        _cardIconLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _cardIconLabel.textAlignment = NSTextAlignmentCenter;
        _cardIconLabel.font = [UIFont systemFontOfSize:28.0];
        _cardIconLabel.text = @"📖";
        [_cardContainer addSubview:_cardIconLabel];
        
        _cardTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, frame.size.height * 0.32, frame.size.width - 16, frame.size.height * 0.46)];
        _cardTitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _cardTitleLabel.textColor = [UIColor whiteColor];
        _cardTitleLabel.font = [UIFont boldSystemFontOfSize:13.0];
        _cardTitleLabel.textAlignment = NSTextAlignmentCenter;
        _cardTitleLabel.numberOfLines = 5;
        _cardTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [_cardContainer addSubview:_cardTitleLabel];
        
        _cardStatusBadge = [[UILabel alloc] initWithFrame:CGRectMake(6, frame.size.height - 26, frame.size.width - 12, 18)];
        _cardStatusBadge.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        _cardStatusBadge.font = [UIFont boldSystemFontOfSize:10.0];
        _cardStatusBadge.textAlignment = NSTextAlignmentCenter;
        [_cardContainer addSubview:_cardStatusBadge];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.coverImageView.image = nil;
    self.currentImageURL = nil;
    [self.spinner stopAnimating];
    self.cardContainer.hidden = YES;
    self.coverImageView.hidden = NO;
    self.gradientOverlay.hidden = NO;
}

- (void)configureWithComic:(Comic *)comic {
    @try {
        NSString *origLang = [comic.originalLanguage isKindOfClass:[NSString class]] ? comic.originalLanguage : @"";
        NSString *origin = [comic.originBadge isKindOfClass:[NSString class]] ? comic.originBadge : @"Cómic";
        NSString *title = [comic.title isKindOfClass:[NSString class]] ? comic.title : @"Cómic";
        NSString *status = [comic.status isKindOfClass:[NSString class]] ? comic.status : @"Disponible";
        
        UIColor *badgeColor = [UIColor colorWithRed:1.0 green:0.75 blue:0.3 alpha:1.0];
        UIColor *cardBgColor = [UIColor colorWithRed:0.14 green:0.13 blue:0.10 alpha:1.0];
        UIColor *cardBorderColor = [UIColor colorWithRed:0.5 green:0.4 blue:0.2 alpha:0.4];
        UIColor *originPillBg = [UIColor colorWithRed:0.40 green:0.30 blue:0.10 alpha:0.8];
        
        if ([origLang isEqualToString:@"en"]) {
            badgeColor = [UIColor colorWithRed:0.3 green:0.75 blue:1.0 alpha:1.0]; // Cyan cómics occidentales
            cardBgColor = [UIColor colorWithRed:0.10 green:0.13 blue:0.20 alpha:1.0];
            cardBorderColor = [UIColor colorWithRed:0.25 green:0.45 blue:0.75 alpha:0.4];
            originPillBg = [UIColor colorWithRed:0.15 green:0.30 blue:0.50 alpha:0.8];
        } else if ([origLang isEqualToString:@"ko"]) {
            badgeColor = [UIColor colorWithRed:0.8 green:0.5 blue:1.0 alpha:1.0]; // Púrpura Manhwa
            cardBgColor = [UIColor colorWithRed:0.14 green:0.10 blue:0.18 alpha:1.0];
            cardBorderColor = [UIColor colorWithRed:0.55 green:0.30 blue:0.75 alpha:0.4];
            originPillBg = [UIColor colorWithRed:0.35 green:0.15 blue:0.50 alpha:0.8];
        } else if ([origLang isEqualToString:@"ja"]) {
            badgeColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.5 alpha:1.0]; // Coral Manga
            cardBgColor = [UIColor colorWithRed:0.18 green:0.10 blue:0.14 alpha:1.0];
            cardBorderColor = [UIColor colorWithRed:0.70 green:0.30 blue:0.40 alpha:0.4];
            originPillBg = [UIColor colorWithRed:0.50 green:0.15 blue:0.25 alpha:0.8];
        }
        
        // Si la opción de omitir miniaturas está activada en Diagnóstico:
        if (ComicoIsSkipThumbnailsEnabled()) {
            self.coverImageView.hidden = YES;
            self.gradientOverlay.hidden = YES;
            [self.spinner stopAnimating];
            
            self.cardContainer.hidden = NO;
            self.cardContainer.backgroundColor = cardBgColor;
            self.cardContainer.layer.borderColor = cardBorderColor.CGColor;
            self.cardContainer.layer.borderWidth = 1.0;
            
            self.cardOriginBadge.text = origin;
            self.cardOriginBadge.textColor = badgeColor;
            self.cardOriginBadge.backgroundColor = originPillBg;
            
            self.cardTitleLabel.text = title;
            self.cardStatusBadge.text = [NSString stringWithFormat:@"● %@", status];
            self.cardStatusBadge.textColor = badgeColor;
            return;
        }
        
        // Modo Normal con Portadas
        self.cardContainer.hidden = YES;
        self.coverImageView.hidden = NO;
        self.gradientOverlay.hidden = NO;
        
        self.titleLabel.text = title;
        self.statusBadge.text = [NSString stringWithFormat:@"%@ • %@", origin, status];
        self.statusBadge.textColor = badgeColor;
        
        if (!comic.coverURL || ![comic.coverURL isKindOfClass:[NSString class]] || comic.coverURL.length == 0) {
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
    } @catch (NSException *ex) {
        // Ignorar excepciones de renderizado
    }
}

@end
