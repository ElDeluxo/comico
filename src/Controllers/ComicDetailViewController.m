#import "ComicDetailViewController.h"
#import "ReaderViewController.h"
#import "APIService.h"
#import "ImageCache.h"
#import "FavoritesManager.h"
#import "DebugViewController.h"

@interface ComicDetailViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) Comic *comic;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<Chapter *> *chapters;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIButton *favoriteButton;
@property (nonatomic, strong) UILabel *noChaptersLabel;

@end

static NSString *const kChapterCellId = @"ChapterCell";

@implementation ComicDetailViewController

- (instancetype)initWithComic:(Comic *)comic {
    self = [super init];
    if (self) {
        _comic = comic;
        _chapters = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    @try {
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.extendedLayoutIncludesOpaqueBars = NO;
        
        NSString *comicTitle = @"Detalle";
        if ([self.comic.title isKindOfClass:[NSString class]] && self.comic.title.length > 0) {
            comicTitle = self.comic.title;
        }
        self.title = comicTitle;
        self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:1.0];
        
        [self setupTableView];
        [self setupHeaderView];
        [self setupSpinner];
        
        [self loadChapters];
    } @catch (NSException *ex) {
        ComicoLog(@"❌ Error en viewDidLoad ComicDetail: %@", ex.reason);
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.tableView.frame = self.view.bounds;
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 60;
    
    [self.view addSubview:self.tableView];
}

- (void)setupHeaderView {
    CGFloat viewWidth = self.view.bounds.size.width;
    if (viewWidth < 100) viewWidth = 768.0;
    
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewWidth, 280)];
    header.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.17 alpha:1.0];
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    // Cover Image
    UIImageView *cover = [[UIImageView alloc] initWithFrame:CGRectMake(14, 14, 100, 145)];
    cover.layer.cornerRadius = 6.0;
    cover.layer.masksToBounds = YES;
    cover.contentMode = UIViewContentModeScaleAspectFill;
    cover.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    [header addSubview:cover];
    
    if (ComicoIsSkipThumbnailsEnabled()) {
        cover.backgroundColor = [UIColor colorWithRed:0.10 green:0.13 blue:0.20 alpha:1.0];
        cover.layer.borderColor = [UIColor colorWithRed:0.25 green:0.45 blue:0.75 alpha:0.4].CGColor;
        cover.layer.borderWidth = 1.0;
        
        UILabel *iconLbl = [[UILabel alloc] initWithFrame:cover.bounds];
        iconLbl.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        iconLbl.textAlignment = NSTextAlignmentCenter;
        iconLbl.font = [UIFont systemFontOfSize:38.0];
        iconLbl.text = @"📖";
        [cover addSubview:iconLbl];
    } else if ([self.comic.coverURL isKindOfClass:[NSString class]] && self.comic.coverURL.length > 0) {
        [[ImageCache sharedCache] loadImageForURL:self.comic.coverURL completion:^(UIImage *img) {
            if (img) cover.image = img;
        }];
    }
    
    // Title
    CGFloat infoX = 124;
    CGFloat infoW = viewWidth - infoX - 14;
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(infoX, 14, infoW, 44)];
    titleLbl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    titleLbl.numberOfLines = 2;
    titleLbl.textColor = [UIColor whiteColor];
    titleLbl.font = [UIFont boldSystemFontOfSize:15.0];
    titleLbl.text = [self.comic.title isKindOfClass:[NSString class]] ? self.comic.title : @"Cómic";
    [header addSubview:titleLbl];
    
    // Author
    UILabel *authorLbl = [[UILabel alloc] initWithFrame:CGRectMake(infoX, 60, infoW, 18)];
    authorLbl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    authorLbl.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    authorLbl.font = [UIFont systemFontOfSize:12.5];
    NSString *authorStr = [self.comic.author isKindOfClass:[NSString class]] ? self.comic.author : @"Desconocido";
    authorLbl.text = [NSString stringWithFormat:@"Por: %@", authorStr];
    [header addSubview:authorLbl];
    
    // Status and Origin Badge
    UILabel *statusLbl = [[UILabel alloc] initWithFrame:CGRectMake(infoX, 82, infoW, 18)];
    statusLbl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    statusLbl.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.5 alpha:1.0];
    statusLbl.font = [UIFont boldSystemFontOfSize:11.5];
    NSString *originStr = [self.comic.originBadge isKindOfClass:[NSString class]] ? self.comic.originBadge : @"Cómic";
    NSString *stStr = [self.comic.status isKindOfClass:[NSString class]] ? self.comic.status : @"";
    statusLbl.text = [NSString stringWithFormat:@"%@ • %@", originStr, stStr];
    [header addSubview:statusLbl];
    
    // Favorite Button
    self.favoriteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.favoriteButton.frame = CGRectMake(infoX, 106, 130, 34);
    self.favoriteButton.layer.cornerRadius = 6.0;
    self.favoriteButton.titleLabel.font = [UIFont boldSystemFontOfSize:12.5];
    [self.favoriteButton addTarget:self action:@selector(toggleFavoriteTapped) forControlEvents:UIControlEventTouchUpInside];
    [self updateFavoriteButtonState];
    [header addSubview:self.favoriteButton];
    
    // Tags
    CGFloat descY = 168.0;
    if (self.comic.tags && [self.comic.tags isKindOfClass:[NSArray class]] && self.comic.tags.count > 0) {
        NSMutableArray *safeTags = [NSMutableArray array];
        for (id tag in self.comic.tags) {
            if ([tag isKindOfClass:[NSString class]] && [tag length] > 0) {
                [safeTags addObject:tag];
            }
        }
        if (safeTags.count > 0) {
            UILabel *tagsLbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 164, viewWidth - 28, 18)];
            tagsLbl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            tagsLbl.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
            tagsLbl.font = [UIFont italicSystemFontOfSize:11.0];
            tagsLbl.text = [safeTags componentsJoinedByString:@" • "];
            [header addSubview:tagsLbl];
            descY = 186.0;
        }
    }
    
    // Description (UILabel ligero sin problemas de layout de UITextView en iOS 9)
    UILabel *descLbl = [[UILabel alloc] initWithFrame:CGRectMake(14, descY, viewWidth - 28, 80)];
    descLbl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    descLbl.backgroundColor = [UIColor clearColor];
    descLbl.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    descLbl.font = [UIFont systemFontOfSize:12.0];
    descLbl.numberOfLines = 4;
    descLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    NSString *descText = [self.comic.comicDescription isKindOfClass:[NSString class]] ? self.comic.comicDescription : @"Sin descripción disponible.";
    descLbl.text = descText;
    [header addSubview:descLbl];
    
    self.tableView.tableHeaderView = header;
}

- (void)setupSpinner {
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0, 340);
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    
    self.noChaptersLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 320, self.view.bounds.size.width - 40, 40)];
    self.noChaptersLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.noChaptersLabel.textAlignment = NSTextAlignmentCenter;
    self.noChaptersLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    self.noChaptersLabel.font = [UIFont systemFontOfSize:14.0];
    self.noChaptersLabel.text = @"No hay capítulos disponibles.";
    self.noChaptersLabel.hidden = YES;
    [self.view addSubview:self.noChaptersLabel];
}

- (void)updateFavoriteButtonState {
    @try {
        if (![self.comic.comicId isKindOfClass:[NSString class]]) return;
        BOOL isFav = [[FavoritesManager sharedManager] isFavorite:self.comic.comicId];
        if (isFav) {
            [self.favoriteButton setTitle:@"★ En Favoritos" forState:UIControlStateNormal];
            self.favoriteButton.backgroundColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.5 alpha:1.0];
            [self.favoriteButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        } else {
            [self.favoriteButton setTitle:@"☆ Agregar" forState:UIControlStateNormal];
            self.favoriteButton.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1.0];
            [self.favoriteButton setTitleColor:[UIColor colorWithRed:1.0 green:0.4 blue:0.5 alpha:1.0] forState:UIControlStateNormal];
        }
    } @catch (NSException *ex) {
        // Ignorar
    }
}

- (void)toggleFavoriteTapped {
    @try {
        [[FavoritesManager sharedManager] toggleFavorite:self.comic];
        [self updateFavoriteButtonState];
    } @catch (NSException *ex) {
        // Ignorar
    }
}

- (void)loadChapters {
    [self.spinner startAnimating];
    self.noChaptersLabel.hidden = YES;
    
    NSString *comicId = self.comic.comicId;
    if (![comicId isKindOfClass:[NSString class]] || comicId.length == 0) {
        [self.spinner stopAnimating];
        self.noChaptersLabel.hidden = NO;
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    [[APIService sharedService] fetchChaptersForComicId:comicId page:0 completion:^(NSArray<Chapter *> *chapters, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            @try {
                [strongSelf.spinner stopAnimating];
                
                if (error) {
                    strongSelf.noChaptersLabel.text = @"Error al cargar capítulos.";
                    strongSelf.noChaptersLabel.hidden = NO;
                    return;
                }
                
                @autoreleasepool {
                    [strongSelf.chapters removeAllObjects];
                    if (chapters && [chapters isKindOfClass:[NSArray class]] && chapters.count > 0) {
                        for (id ch in chapters) {
                            if ([ch isKindOfClass:[Chapter class]]) {
                                [strongSelf.chapters addObject:ch];
                            }
                        }
                    }
                }
                
                strongSelf.noChaptersLabel.hidden = (strongSelf.chapters.count > 0);
                [strongSelf.tableView reloadData];
            } @catch (NSException *ex) {
                ComicoLog(@"❌ Error procesando capítulos: %@", ex.reason);
            }
        });
    }];
}

#pragma mark - UITableViewDataSource & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.chapters.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"ChapterCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.16 alpha:1.0];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:14.0];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        UIView *selBg = [[UIView alloc] init];
        selBg.backgroundColor = [UIColor colorWithRed:0.22 green:0.22 blue:0.28 alpha:1.0];
        cell.selectedBackgroundView = selBg;
    }
    
    if (indexPath.row < self.chapters.count) {
        Chapter *ch = self.chapters[indexPath.row];
        
        // Título seguro
        NSString *title = @"Capítulo";
        if ([ch.title isKindOfClass:[NSString class]] && ch.title.length > 0) {
            title = ch.title;
        } else if ([ch.chapterNumber isKindOfClass:[NSString class]]) {
            title = [NSString stringWithFormat:@"Capítulo %@", ch.chapterNumber];
        }
        cell.textLabel.text = title;
        
        // Idioma seguro
        NSString *lang = @"ES";
        if ([ch.language isKindOfClass:[NSString class]] && ch.language.length > 0) {
            lang = [ch.language uppercaseString];
        }
        
        // Número de capítulo
        NSString *num = @"-";
        if ([ch.chapterNumber isKindOfClass:[NSString class]]) {
            num = ch.chapterNumber;
        }
        
        if (ch.pagesCount > 0) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"[%@] Capítulo %@ • %ld páginas", lang, num, (long)ch.pagesCount];
        } else {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"[%@] Capítulo %@", lang, num];
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.navigationController.topViewController != self) return;
    
    @try {
        if (indexPath.row < self.chapters.count) {
            Chapter *ch = self.chapters[indexPath.row];
            ReaderViewController *readerVC = [[ReaderViewController alloc] initWithChapter:ch
                                                                                comicTitle:self.comic.title
                                                                             chapterNumber:indexPath.row + 1];
            [self.navigationController pushViewController:readerVC animated:YES];
        }
    } @catch (NSException *ex) {
        ComicoLog(@"❌ Error al abrir lector: %@", ex.reason);
    }
}

@end
