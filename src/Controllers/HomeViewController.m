#import "HomeViewController.h"
#import "ComicGridCell.h"
#import "ComicDetailViewController.h"
#import "APIService.h"

@interface HomeViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UISearchBarDelegate>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UILabel *emptyLabel;

@property (nonatomic, strong) NSMutableArray<Comic *> *comics;
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasMore;
@property (nonatomic, copy) NSString *activeSearchQuery;

@end

static NSString *const kCellIdentifier = @"ComicGridCell";

@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Comico";
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:1.0];
    
    self.comics = [NSMutableArray array];
    self.currentPage = 0;
    self.hasMore = YES;
    
    [self setupSearchBar];
    [self setupCollectionView];
    [self setupLoadingIndicator];
    
    [self loadComicsResetting:YES];
}

- (void)setupSearchBar {
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Buscar cómics o manga...";
    self.searchBar.barStyle = UIBarStyleBlack;
    self.searchBar.barTintColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.16 alpha:1.0];
    self.searchBar.tintColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.5 alpha:1.0];
    [self.view addSubview:self.searchBar];
}

- (void)setupCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.minimumInteritemSpacing = 10;
    layout.minimumLineSpacing = 14;
    layout.sectionInset = UIEdgeInsetsMake(12, 12, 16, 12);
    
    CGRect cvFrame = CGRectMake(0, 44, self.view.bounds.size.width, self.view.bounds.size.height - 44);
    self.collectionView = [[UICollectionView alloc] initWithFrame:cvFrame collectionViewLayout:layout];
    self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.alwaysBounceVertical = YES;
    
    [self.collectionView registerClass:[ComicGridCell class] forCellWithReuseIdentifier:kCellIdentifier];
    [self.view addSubview:self.collectionView];
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.5 alpha:1.0];
    [self.refreshControl addTarget:self action:@selector(handleRefresh) forControlEvents:UIControlEventValueChanged];
    [self.collectionView addSubview:self.refreshControl];
    
    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 150, self.view.bounds.size.width - 40, 60)];
    self.emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    self.emptyLabel.font = [UIFont systemFontOfSize:15.0];
    self.emptyLabel.numberOfLines = 2;
    self.emptyLabel.text = @"No se encontraron cómics.";
    self.emptyLabel.hidden = YES;
    [self.collectionView addSubview:self.emptyLabel];
}

- (void)setupLoadingIndicator {
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.loadingIndicator.center = CGPointMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0);
    self.loadingIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.loadingIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.loadingIndicator];
}

#pragma mark - Data Loading

- (void)handleRefresh {
    [self loadComicsResetting:YES];
}

- (void)loadComicsResetting:(BOOL)reset {
    if (self.isLoading) return;
    self.isLoading = YES;
    
    if (reset) {
        self.currentPage = 0;
        self.hasMore = YES;
        if (!self.refreshControl.isRefreshing) {
            [self.loadingIndicator startAnimating];
        }
    }
    
    void (^completionBlock)(NSArray<Comic *> *, NSError *) = ^(NSArray<Comic *> *newComics, NSError *error) {
        self.isLoading = NO;
        [self.refreshControl endRefreshing];
        [self.loadingIndicator stopAnimating];
        
        if (error) {
            if (reset && self.comics.count == 0) {
                self.emptyLabel.text = @"Error de conexión.\nDesliza hacia abajo para reintentar.";
                self.emptyLabel.hidden = NO;
            }
            return;
        }
        
        if (reset) {
            [self.comics removeAllObjects];
        }
        
        if (newComics.count < 20) {
            self.hasMore = NO;
        }
        
        [self.comics addObjectsFromArray:newComics];
        self.emptyLabel.hidden = (self.comics.count > 0);
        [self.collectionView reloadData];
    };
    
    if (self.activeSearchQuery && self.activeSearchQuery.length > 0) {
        [[APIService sharedService] searchComicsWithQuery:self.activeSearchQuery page:self.currentPage completion:completionBlock];
    } else {
        [[APIService sharedService] fetchPopularComicsPage:self.currentPage completion:completionBlock];
    }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.comics.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    ComicGridCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kCellIdentifier forIndexPath:indexPath];
    if (indexPath.item < self.comics.count) {
        [cell configureWithComic:self.comics[indexPath.item]];
    }
    return cell;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat totalWidth = collectionView.bounds.size.width - 24; // 12 margin on each side
    int columns = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 4 : 2;
    CGFloat itemSpacing = 10 * (columns - 1);
    CGFloat width = floor((totalWidth - itemSpacing) / columns);
    CGFloat height = floor(width * 1.48); // Standard comic cover aspect ratio
    return CGSizeMake(width, height);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item < self.comics.count) {
        Comic *comic = self.comics[indexPath.item];
        ComicDetailViewController *detailVC = [[ComicDetailViewController alloc] initWithComic:comic];
        [self.navigationController pushViewController:detailVC animated:YES];
    }
}

#pragma mark - Infinite Pagination

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentHeight = scrollView.contentSize.height;
    CGFloat frameHeight = scrollView.frame.size.height;
    
    if (offsetY > contentHeight - frameHeight - 300) {
        if (!self.isLoading && self.hasMore) {
            self.currentPage++;
            [self loadComicsResetting:NO];
        }
    }
}

#pragma mark - UISearchBarDelegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    self.activeSearchQuery = [searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    [self loadComicsResetting:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    [searchBar setShowsCancelButton:NO animated:YES];
    self.activeSearchQuery = nil;
    [self loadComicsResetting:YES];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.activeSearchQuery = nil;
        [self loadComicsResetting:YES];
    }
}

@end

