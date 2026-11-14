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
@property (nonatomic, strong) UIRefreshControl *refreshControl;
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
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.extendedLayoutIncludesOpaqueBars = NO;
    
    self.title = self.comic.title ?: @"Detalle";
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:1.0];
    
    [self setupTableView];
    [self setupHeaderView];
    [self setupSpinner];
    
    [self loadChapters];
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
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.5 alpha:1.0];
    [self.refreshControl addTarget:self action:@selector(loadChapters) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];
}

- (void)setupHeaderView {
    CGFloat viewWidth = self.view.bounds.size.width;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewWidth, 290)];
    header.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.17 alpha:1.0];
    
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
    } else if (self.comic.coverURL) {
        [[ImageCache sharedCache] loadImageForURL:self.comic.coverURL completion:^(UIImage *img) {
            if (img) cover.image = img;
        }];
    }
    
    // Title
    CGFloat infoX = 124;
    CGFloat infoW = viewWidth - infoX - 14;
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(infoX, 14, infoW, 44)];
    titleLbl.numberOfLines = 2;
    titleLbl.textColor = [UIColor whiteColor];
    titleLbl.font = [UIFont boldSystemFontOfSize:16.0];
    titleLbl.text = self.comic.title;
    [header addSubview:titleLbl];
    
    // Author
    UILabel *authorLbl = [[UILabel alloc] initWithFrame:CGRectMake(infoX, 62, infoW, 18)];
    authorLbl.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    authorLbl.font = [UIFont systemFontOfSize:13.0];
    authorLbl.text = [NSString stringWithFormat:@"Por: %@", self.comic.author ?: @"Desconocido"];
    [header addSubview:authorLbl];
    
    // Status and Origin Badge
    UILabel *statusLbl = [[UILabel alloc] initWithFrame:CGRectMake(infoX, 84, infoW, 18)];
    statusLbl.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.5 alpha:1.0];
    statusLbl.font = [UIFont boldSystemFontOfSize:12.0];
    statusLbl.text = [NSString stringWithFormat:@"%@ • %@", self.comic.originBadge ?: @"Cómic", self.comic.status ?: @""];
    [header addSubview:statusLbl];
    
    // Favorite Button
    self.favoriteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.favoriteButton.frame = CGRectMake(infoX, 110, 130, 36);
    self.favoriteButton.layer.cornerRadius = 6.0;
    self.favoriteButton.titleLabel.font = [UIFont boldSystemFontOfSize:13.0];
    [self.favoriteButton addTarget:self action:@selector(toggleFavoriteTapped) forControlEvents:UIControlEventTouchUpInside];
    [self updateFavoriteButtonState];
    [header addSubview:self.favoriteButton];
    
    // Tags
    if (self.comic.tags && self.comic.tags.count > 0) {
        UILabel *tagsLbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 168, viewWidth - 28, 20)];
        tagsLbl.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
        tagsLbl.font = [UIFont italicSystemFontOfSize:11.0];
        tagsLbl.text = [self.comic.tags componentsJoinedByString:@" • "];
        [header addSubview:tagsLbl];
    }
    
    // Description
    UITextView *descView = [[UITextView alloc] initWithFrame:CGRectMake(10, 192, viewWidth - 20, 88)];
    descView.backgroundColor = [UIColor clearColor];
    descView.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    descView.font = [UIFont systemFontOfSize:12.0];
    descView.editable = NO;
    descView.scrollEnabled = NO;
    descView.text = self.comic.comicDescription;
    [header addSubview:descView];
    
    self.tableView.tableHeaderView = header;
}

- (void)setupSpinner {
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0, 360);
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    
    self.noChaptersLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 340, self.view.bounds.size.width - 40, 40)];
    self.noChaptersLabel.textAlignment = NSTextAlignmentCenter;
    self.noChaptersLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    self.noChaptersLabel.font = [UIFont systemFontOfSize:14.0];
    self.noChaptersLabel.text = @"No hay capítulos disponibles en español o inglés.";
    self.noChaptersLabel.hidden = YES;
    [self.view addSubview:self.noChaptersLabel];
}

- (void)updateFavoriteButtonState {
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
}

- (void)toggleFavoriteTapped {
    [[FavoritesManager sharedManager] toggleFavorite:self.comic];
    [self updateFavoriteButtonState];
}

- (void)loadChapters {
    [self.spinner startAnimating];
    self.noChaptersLabel.hidden = YES;
    
    [[APIService sharedService] fetchChaptersForComicId:self.comic.comicId page:0 completion:^(NSArray<Chapter *> *chapters, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            [self.refreshControl endRefreshing];
            
            if (error) {
                self.noChaptersLabel.text = @"Error al cargar capítulos.";
                self.noChaptersLabel.hidden = NO;
                return;
            }
            
            [self.chapters removeAllObjects];
            if (chapters && chapters.count > 0) {
                [self.chapters addObjectsFromArray:chapters];
            }
            
            self.noChaptersLabel.hidden = (self.chapters.count > 0);
            [self.tableView reloadData];
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
        cell.textLabel.font = [UIFont boldSystemFontOfSize:14.5];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        UIView *selBg = [[UIView alloc] init];
        selBg.backgroundColor = [UIColor colorWithRed:0.22 green:0.22 blue:0.28 alpha:1.0];
        cell.selectedBackgroundView = selBg;
    }
    
    if (indexPath.row < self.chapters.count) {
        Chapter *ch = self.chapters[indexPath.row];
        cell.textLabel.text = ch.title;
        
        NSString *lang = [ch.language uppercaseString] ?: @"ES";
        if (ch.pagesCount > 0) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"[%@] Capítulo %@ • %ld páginas", lang, ch.chapterNumber ?: @"-", (long)ch.pagesCount];
        } else {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"[%@] Capítulo %@", lang, ch.chapterNumber ?: @"-"];
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row < self.chapters.count) {
        Chapter *ch = self.chapters[indexPath.row];
        ReaderViewController *readerVC = [[ReaderViewController alloc] initWithChapter:ch
                                                                            comicTitle:self.comic.title
                                                                         chapterNumber:indexPath.row + 1];
        [self.navigationController pushViewController:readerVC animated:YES];
    }
}

@end

