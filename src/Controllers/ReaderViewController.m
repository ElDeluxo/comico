#import "ReaderViewController.h"
#import "APIService.h"
#import "ImageCache.h"

@interface ReaderViewController () <UIScrollViewDelegate>

@property (nonatomic, strong) Chapter *chapter;
@property (nonatomic, copy) NSString *comicTitle;
@property (nonatomic, strong) NSArray<NSString *> *pageURLs;
@property (nonatomic, assign) NSInteger currentPageIndex;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *pageImageView;
@property (nonatomic, strong) UIActivityIndicatorView *pageSpinner;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UILabel *pageLabel;
@property (nonatomic, strong) UISlider *pageSlider;
@property (nonatomic, strong) UIButton *prevButton;
@property (nonatomic, strong) UIButton *nextButton;

@property (nonatomic, assign) BOOL controlsVisible;

@end

@implementation ReaderViewController

- (instancetype)initWithChapter:(Chapter *)chapter comicTitle:(NSString *)comicTitle {
    self = [super init];
    if (self) {
        _chapter = chapter;
        _comicTitle = comicTitle;
        _pageURLs = @[];
        _currentPageIndex = 0;
        _controlsVisible = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = self.chapter.title ?: [NSString stringWithFormat:@"Capítulo %@", self.chapter.chapterNumber];
    self.view.backgroundColor = [UIColor blackColor];
    
    [self setupScrollView];
    [self setupBottomBar];
    [self setupGestures];
    
    [self loadPages];
}

- (void)setupScrollView {
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.backgroundColor = [UIColor blackColor];
    self.scrollView.delegate = self;
    self.scrollView.minimumZoomScale = 1.0;
    self.scrollView.maximumZoomScale = 3.0;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];
    
    self.pageImageView = [[UIImageView alloc] initWithFrame:self.scrollView.bounds];
    self.pageImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.pageImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.scrollView addSubview:self.pageImageView];
    
    self.pageSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.pageSpinner.center = CGPointMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0);
    self.pageSpinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.pageSpinner.hidesWhenStopped = YES;
    [self.view addSubview:self.pageSpinner];
}

- (void)setupBottomBar {
    CGFloat barH = 70.0;
    CGFloat y = self.view.bounds.size.height - barH;
    self.bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, y, self.view.bounds.size.width, barH)];
    self.bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.bottomBar.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    [self.view addSubview:self.bottomBar];
    
    // Page count label
    self.pageLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, self.view.bounds.size.width - 20, 20)];
    self.pageLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.pageLabel.textAlignment = NSTextAlignmentCenter;
    self.pageLabel.textColor = [UIColor whiteColor];
    self.pageLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    self.pageLabel.text = @"Cargando páginas...";
    [self.bottomBar addSubview:self.pageLabel];
    
    // Prev Button
    self.prevButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.prevButton.frame = CGRectMake(10, 30, 44, 34);
    [self.prevButton setTitle:@"◀" forState:UIControlStateNormal];
    [self.prevButton setTitleColor:[UIColor colorWithRed:1.0 green:0.4 blue:0.5 alpha:1.0] forState:UIControlStateNormal];
    [self.prevButton setTitleColor:[UIColor colorWithWhite:0.4 alpha:1.0] forState:UIControlStateDisabled];
    [self.prevButton addTarget:self action:@selector(prevPageTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.prevButton];
    
    // Slider
    CGFloat sliderW = self.view.bounds.size.width - 120;
    self.pageSlider = [[UISlider alloc] initWithFrame:CGRectMake(60, 32, sliderW, 30)];
    self.pageSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.pageSlider.minimumValue = 0;
    self.pageSlider.maximumValue = 1;
    self.pageSlider.tintColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.5 alpha:1.0];
    [self.pageSlider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.bottomBar addSubview:self.pageSlider];
    
    // Next Button
    self.nextButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.nextButton.frame = CGRectMake(self.view.bounds.size.width - 54, 30, 44, 34);
    self.nextButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.nextButton setTitle:@"▶" forState:UIControlStateNormal];
    [self.nextButton setTitleColor:[UIColor colorWithRed:1.0 green:0.4 blue:0.5 alpha:1.0] forState:UIControlStateNormal];
    [self.nextButton setTitleColor:[UIColor colorWithWhite:0.4 alpha:1.0] forState:UIControlStateDisabled];
    [self.nextButton addTarget:self action:@selector(nextPageTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.nextButton];
}

- (void)setupGestures {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self.view addGestureRecognizer:tap];
    
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(nextPageTapped)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.view addGestureRecognizer:swipeLeft];
    
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(prevPageTapped)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:swipeRight];
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    CGPoint loc = [gesture locationInView:self.view];
    CGFloat w = self.view.bounds.size.width;
    
    if (loc.x < w * 0.28) {
        // Tap Left 28% -> Prev page
        [self prevPageTapped];
    } else if (loc.x > w * 0.72) {
        // Tap Right 28% -> Next page
        [self nextPageTapped];
    } else {
        // Tap Center -> Toggle UI
        [self toggleControls];
    }
}

- (void)toggleControls {
    self.controlsVisible = !self.controlsVisible;
    [UIView animateWithDuration:0.25 animations:^{
        self.bottomBar.alpha = self.controlsVisible ? 1.0 : 0.0;
        self.navigationController.navigationBar.alpha = self.controlsVisible ? 1.0 : 0.0;
    }];
}

#pragma mark - Page Loading

- (void)loadPages {
    [self.pageSpinner startAnimating];
    self.pageImageView.image = nil;
    
    [[APIService sharedService] fetchPagesForChapterId:self.chapter.chapterId completion:^(NSArray<NSString *> *urls, NSError *error) {
        [self.pageSpinner stopAnimating];
        if (error || urls.count == 0) {
            self.pageLabel.text = @"Error al cargar páginas.";
            return;
        }
        
        self.pageURLs = urls;
        self.currentPageIndex = 0;
        self.pageSlider.maximumValue = urls.count - 1;
        self.pageSlider.value = 0;
        
        [self displayCurrentPage];
    }];
}

- (void)displayCurrentPage {
    if (self.pageURLs.count == 0) return;
    
    [self.scrollView setZoomScale:1.0 animated:NO];
    
    self.prevButton.enabled = (self.currentPageIndex > 0);
    self.nextButton.enabled = (self.currentPageIndex < self.pageURLs.count - 1);
    self.pageSlider.value = self.currentPageIndex;
    self.pageLabel.text = [NSString stringWithFormat:@"Página %ld de %lu", (long)(self.currentPageIndex + 1), (unsigned long)self.pageURLs.count];
    
    NSString *currentURL = self.pageURLs[self.currentPageIndex];
    UIImage *cached = [[ImageCache sharedCache] imageForURL:currentURL];
    if (cached) {
        self.pageImageView.image = cached;
        [self.pageSpinner stopAnimating];
    } else {
        self.pageImageView.image = nil;
        [self.pageSpinner startAnimating];
        
        [[ImageCache sharedCache] loadImageForURL:currentURL completion:^(UIImage *img) {
            if ([self.pageURLs[self.currentPageIndex] isEqualToString:currentURL]) {
                [self.pageSpinner stopAnimating];
                self.pageImageView.image = img;
            }
        }];
    }
    
    // Preload next page
    if (self.currentPageIndex + 1 < self.pageURLs.count) {
        [[ImageCache sharedCache] loadImageForURL:self.pageURLs[self.currentPageIndex + 1] completion:nil];
    }
    // Preload previous page
    if (self.currentPageIndex > 0) {
        [[ImageCache sharedCache] loadImageForURL:self.pageURLs[self.currentPageIndex - 1] completion:nil];
    }
}

- (void)prevPageTapped {
    if (self.currentPageIndex > 0) {
        self.currentPageIndex--;
        [self displayCurrentPage];
    }
}

- (void)nextPageTapped {
    if (self.currentPageIndex < self.pageURLs.count - 1) {
        self.currentPageIndex++;
        [self displayCurrentPage];
    }
}

- (void)sliderValueChanged:(UISlider *)slider {
    NSInteger target = (NSInteger)roundf(slider.value);
    if (target != self.currentPageIndex && target < self.pageURLs.count) {
        self.currentPageIndex = target;
        [self displayCurrentPage];
    }
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.pageImageView;
}

@end

