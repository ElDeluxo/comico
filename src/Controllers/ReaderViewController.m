#import "ReaderViewController.h"
#import "APIService.h"
#import "TLSHTTPClient.h"

@interface ReaderViewController () <UIScrollViewDelegate>

@property (nonatomic, strong) Chapter *chapter;
@property (nonatomic, copy) NSString *comicTitle;
@property (nonatomic, assign) NSInteger chapterNumber;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *pageImageView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@property (nonatomic, strong) NSMutableDictionary *pageCache;
@property (nonatomic, strong) NSArray<NSString *> *pageURLs;
@property (nonatomic, assign) int currentPage;
@property (nonatomic, assign) int totalPages;

@property (nonatomic, strong) UIView *controlsOverlay;
@property (nonatomic, strong) UILabel *pageLabel;
@property (nonatomic, strong) UIButton *prevButton;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, assign) BOOL controlsHidden;

@end

@implementation ReaderViewController

- (instancetype)initWithChapter:(Chapter *)chapter comicTitle:(NSString *)comicTitle {
    return [self initWithChapter:chapter comicTitle:comicTitle chapterNumber:0];
}

- (instancetype)initWithChapter:(Chapter *)chapter comicTitle:(NSString *)comicTitle chapterNumber:(NSInteger)chapterNumber {
    self = [super init];
    if (self) {
        _chapter = chapter;
        _comicTitle = comicTitle ?: @"Cómic";
        _chapterNumber = chapterNumber;
        _pageCache = [NSMutableDictionary dictionary];
        _pageURLs = @[];
        _currentPage = 0;
        _totalPages = 0;
        _controlsHidden = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Título al estilo MangaBox: "%@ - Ch. %ld"
    if (self.chapter.title && self.chapter.title.length > 0) {
        self.title = self.chapter.title;
    } else if (self.chapter.chapterNumber && self.chapter.chapterNumber.length > 0) {
        self.title = [NSString stringWithFormat:@"%@ - Cap. %@", self.comicTitle, self.chapter.chapterNumber];
    } else {
        self.title = self.comicTitle;
    }
    
    self.view.backgroundColor = [UIColor blackColor];
    
    // 1. ScrollView con soporte de zoom
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.backgroundColor = [UIColor blackColor];
    self.scrollView.delegate = self;
    self.scrollView.minimumZoomScale = 1.0;
    self.scrollView.maximumZoomScale = 3.0;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];
    
    // 2. UIImageView de la página
    self.pageImageView = [[UIImageView alloc] initWithFrame:self.scrollView.bounds];
    self.pageImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.pageImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.pageImageView.userInteractionEnabled = YES;
    [self.scrollView addSubview:self.pageImageView];
    
    // 3. Indicador de carga
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0);
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    
    // 4. Gesto de toque táctil para navegación (izquierda: anterior, derecha: siguiente, centro: controles)
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self.view addGestureRecognizer:tap];
    
    // 5. Barra de controles inferior
    [self setupControlsOverlay];
    
    // 6. Cargar páginas del capítulo
    [self loadChapterPages];
}

- (void)setupControlsOverlay {
    CGFloat barH = 56.0;
    CGFloat barY = self.view.bounds.size.height - barH;
    
    self.controlsOverlay = [[UIView alloc] initWithFrame:CGRectMake(0, barY, self.view.bounds.size.width, barH)];
    self.controlsOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.controlsOverlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.75];
    [self.view addSubview:self.controlsOverlay];
    
    // Botón Anterior (estilo MangaBox PREVIOUS_PAGE)
    self.prevButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.prevButton.frame = CGRectMake(10, 8, 110, 40);
    [self.prevButton setTitle:@"◀ Anterior" forState:UIControlStateNormal];
    [self.prevButton setTitleColor:[UIColor colorWithRed:1.0 green:0.4 blue:0.5 alpha:1.0] forState:UIControlStateNormal];
    [self.prevButton setTitleColor:[UIColor colorWithWhite:0.35 alpha:1.0] forState:UIControlStateDisabled];
    self.prevButton.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
    [self.prevButton addTarget:self action:@selector(prevPage) forControlEvents:UIControlEventTouchUpInside];
    [self.controlsOverlay addSubview:self.prevButton];
    
    // Botón Siguiente (estilo MangaBox NEXT_PAGE)
    self.nextButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.nextButton.frame = CGRectMake(self.view.bounds.size.width - 120, 8, 110, 40);
    self.nextButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.nextButton setTitle:@"Siguiente ▶" forState:UIControlStateNormal];
    [self.nextButton setTitleColor:[UIColor colorWithRed:1.0 green:0.4 blue:0.5 alpha:1.0] forState:UIControlStateNormal];
    [self.nextButton setTitleColor:[UIColor colorWithWhite:0.35 alpha:1.0] forState:UIControlStateDisabled];
    self.nextButton.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
    [self.nextButton addTarget:self action:@selector(nextPage) forControlEvents:UIControlEventTouchUpInside];
    [self.controlsOverlay addSubview:self.nextButton];
    
    // Etiqueta indicador de páginas central (estilo MangaBox PAGE_INDICATOR: "1 / 24")
    CGFloat labelX = 120.0;
    CGFloat labelW = self.view.bounds.size.width - 240.0;
    self.pageLabel = [[UILabel alloc] initWithFrame:CGRectMake(labelX, 8, labelW, 40)];
    self.pageLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.pageLabel.textAlignment = NSTextAlignmentCenter;
    self.pageLabel.textColor = [UIColor whiteColor];
    self.pageLabel.font = [UIFont boldSystemFontOfSize:15.0];
    self.pageLabel.text = @"Cargando...";
    [self.controlsOverlay addSubview:self.pageLabel];
}

#pragma mark - Page Loading & Rendering (MangaBox Architecture)

- (void)loadChapterPages {
    [self.spinner startAnimating];
    self.pageImageView.image = nil;
    self.pageLabel.text = @"Cargando páginas...";
    
    [[APIService sharedService] fetchPagesForChapterId:self.chapter.chapterId completion:^(NSArray<NSString *> *urls, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            if (error || !urls || urls.count == 0) {
                self.pageLabel.text = @"Error al cargar páginas";
                return;
            }
            
            self.pageURLs = urls;
            self.totalPages = (int)urls.count;
            self.currentPage = 0;
            
            [self renderCurrentPage];
        });
    }];
}

- (void)renderCurrentPage {
    if (self.totalPages > 0) {
        self.pageLabel.text = [NSString stringWithFormat:@"%d / %d", self.currentPage + 1, self.totalPages];
    } else {
        self.pageLabel.text = @"";
    }
    
    self.prevButton.enabled = (self.currentPage > 0);
    self.nextButton.enabled = (self.currentPage < self.totalPages - 1);
    
    [self.scrollView setZoomScale:1.0 animated:NO];
    
    if (self.currentPage < 0 || self.currentPage >= (int)self.pageURLs.count) {
        [self.spinner stopAnimating];
        return;
    }
    
    // 1. Comprobar caché en memoria al estilo MangaBox (_pageCache)
    UIImage *cachedImg = self.pageCache[@(self.currentPage)];
    if (cachedImg) {
        [self.spinner stopAnimating];
        self.pageImageView.image = cachedImg;
        [self prefetchSurroundingPages];
        return;
    }
    
    // 2. Si no está en caché, mostrar spinner y descargar con TLSHTTPClient
    self.pageImageView.image = nil;
    [self.spinner startAnimating];
    
    int requestedIndex = self.currentPage;
    NSString *urlString = self.pageURLs[requestedIndex];
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        [self.spinner stopAnimating];
        return;
    }
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setValue:@"Comico/1.0 (iOS 9.0; iPad; +https://github.com/ElDeluxo/comico)" forHTTPHeaderField:@"User-Agent"];
    [req setValue:@"https://mangadex.org/" forHTTPHeaderField:@"Referer"];
    
    [[TLSHTTPClient sharedClient] performRequest:req completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!error && data.length > 0) {
                UIImage *img = [UIImage imageWithData:data];
                if (img) {
                    self.pageCache[@(requestedIndex)] = img;
                    if (self.currentPage == requestedIndex) {
                        self.pageImageView.image = img;
                        [self.spinner stopAnimating];
                    }
                }
            } else {
                if (self.currentPage == requestedIndex) {
                    [self.spinner stopAnimating];
                }
            }
            [self prefetchSurroundingPages];
        });
    }];
}

- (void)prefetchSurroundingPages {
    // Precargar página siguiente en segundo plano
    int nextIdx = self.currentPage + 1;
    if (nextIdx < self.totalPages && !self.pageCache[@(nextIdx)]) {
        NSString *nextUrlStr = self.pageURLs[nextIdx];
        NSURL *nextUrl = [NSURL URLWithString:nextUrlStr];
        if (nextUrl) {
            NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:nextUrl];
            [req setValue:@"Comico/1.0 (iOS 9.0; iPad; +https://github.com/ElDeluxo/comico)" forHTTPHeaderField:@"User-Agent"];
            [req setValue:@"https://mangadex.org/" forHTTPHeaderField:@"Referer"];
            [[TLSHTTPClient sharedClient] performRequest:req completion:^(NSData *d, NSHTTPURLResponse *r, NSError *e) {
                if (!e && d.length > 0) {
                    UIImage *img = [UIImage imageWithData:d];
                    if (img) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            self.pageCache[@(nextIdx)] = img;
                        });
                    }
                }
            }];
        }
    }
    
    // Limpiar páginas lejanas de la caché de RAM para evitar que iOS 9 mate el proceso por memoria (OOM Jetsam)
    for (NSNumber *key in [self.pageCache allKeys]) {
        int idx = [key intValue];
        if (abs(idx - self.currentPage) > 3) {
            [self.pageCache removeObjectForKey:key];
        }
    }
}

#pragma mark - Navigation Actions

- (void)prevPage {
    if (self.currentPage > 0) {
        self.currentPage--;
        [self renderCurrentPage];
    }
}

- (void)nextPage {
    if (self.currentPage < self.totalPages - 1) {
        self.currentPage++;
        [self renderCurrentPage];
    }
}

- (void)handleTap:(UITapGestureRecognizer *)tap {
    CGPoint loc = [tap locationInView:self.view];
    CGFloat w = self.view.bounds.size.width;
    
    if (loc.x < w * 0.3) {
        // Toque en el tercio izquierdo: Página anterior
        [self prevPage];
    } else if (loc.x > w * 0.7) {
        // Toque en el tercio derecho: Página siguiente
        [self nextPage];
    } else {
        // Toque en el centro: Alternar barra de controles y navegación
        self.controlsHidden = !self.controlsHidden;
        [UIView animateWithDuration:0.25 animations:^{
            self.controlsOverlay.alpha = self.controlsHidden ? 0.0 : 1.0;
            self.navigationController.navigationBar.alpha = self.controlsHidden ? 0.0 : 1.0;
        }];
    }
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.pageImageView;
}

@end
