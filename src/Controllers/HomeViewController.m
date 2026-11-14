#import "HomeViewController.h"
#import "ComicGridCell.h"
#import "ComicDetailViewController.h"
#import "APIService.h"

@interface HomeViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UISearchBarDelegate>

@property (nonatomic, strong) UIView *headerContainerView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UISegmentedControl *categoryControl;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, strong) UIButton *serverConfigButton;

@property (nonatomic, strong) NSMutableArray<Comic *> *comics;
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasMore;
@property (nonatomic, copy) NSString *activeSearchQuery;
@property (nonatomic, assign) ComicCategory currentCategory;

@end

static NSString *const kCellIdentifier = @"ComicGridCell";

@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Comico";
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:1.0];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"⚙️ Servidor" style:UIBarButtonItemStylePlain target:self action:@selector(showServerSettings)];
    
    // Evita que los elementos queden ocultos debajo de la barra de navegación en iOS 9
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.extendedLayoutIncludesOpaqueBars = NO;
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    self.comics = [NSMutableArray array];
    self.currentPage = 0;
    self.hasMore = YES;
    self.currentCategory = ComicCategoryAll;
    
    [self setupHeaderAndSearchBar];
    [self setupCollectionView];
    [self setupLoadingIndicator];
    
    [self loadComicsResetting:YES];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    
    CGFloat headerH = 44 + 40;
    self.headerContainerView.frame = CGRectMake(0, 0, w, headerH);
    self.searchBar.frame = CGRectMake(0, 0, w, 44);
    self.categoryControl.frame = CGRectMake(8, 48, w - 16, 30);
    
    self.collectionView.frame = CGRectMake(0, headerH, w, h - headerH);
    self.emptyLabel.frame = CGRectMake(20, 80, w - 40, 90);
    self.retryButton.center = CGPointMake(w / 2.0, 195);
    self.serverConfigButton.center = CGPointMake(w / 2.0, 245);
    self.loadingIndicator.center = CGPointMake(w / 2.0, (h - headerH) / 2.0 + headerH);
}

- (void)setupHeaderAndSearchBar {
    CGFloat w = self.view.bounds.size.width;
    self.headerContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 84)];
    self.headerContainerView.backgroundColor = [UIColor colorWithRed:0.10 green:0.10 blue:0.15 alpha:1.0];
    [self.view addSubview:self.headerContainerView];
    
    // Search Bar
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, w, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Buscar cómics (occidentales, manga, etc.)...";
    self.searchBar.barStyle = UIBarStyleBlack;
    self.searchBar.barTintColor = [UIColor colorWithRed:0.10 green:0.10 blue:0.15 alpha:1.0];
    self.searchBar.tintColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.5 alpha:1.0];
    [self.headerContainerView addSubview:self.searchBar];
    
    // Category Tabs
    NSArray *items = @[@"Todos", @"Occidentales", @"Manhwa", @"Manga"];
    self.categoryControl = [[UISegmentedControl alloc] initWithItems:items];
    self.categoryControl.frame = CGRectMake(8, 48, w - 16, 30);
    self.categoryControl.selectedSegmentIndex = 0;
    self.categoryControl.tintColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.5 alpha:1.0];
    [self.categoryControl setTitleTextAttributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:12.0]} forState:UIControlStateNormal];
    [self.categoryControl addTarget:self action:@selector(categoryChanged:) forControlEvents:UIControlEventValueChanged];
    [self.headerContainerView addSubview:self.categoryControl];
}

- (void)setupCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.minimumInteritemSpacing = 10;
    layout.minimumLineSpacing = 14;
    layout.sectionInset = UIEdgeInsetsMake(12, 12, 20, 12);
    
    CGFloat headerH = 84;
    CGRect cvFrame = CGRectMake(0, headerH, self.view.bounds.size.width, self.view.bounds.size.height - headerH);
    self.collectionView = [[UICollectionView alloc] initWithFrame:cvFrame collectionViewLayout:layout];
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
    
    // Empty / Error Label
    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, self.view.bounds.size.width - 40, 80)];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
    self.emptyLabel.font = [UIFont systemFontOfSize:14.0];
    self.emptyLabel.numberOfLines = 3;
    self.emptyLabel.hidden = YES;
    [self.collectionView addSubview:self.emptyLabel];
    
    // Retry Button
    self.retryButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.retryButton.frame = CGRectMake((self.view.bounds.size.width - 150) / 2.0, 180, 150, 38);
    self.retryButton.layer.cornerRadius = 6.0;
    self.retryButton.backgroundColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.5 alpha:1.0];
    [self.retryButton setTitle:@"Reintentar" forState:UIControlStateNormal];
    [self.retryButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.retryButton.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
    [self.retryButton addTarget:self action:@selector(handleRefresh) forControlEvents:UIControlEventTouchUpInside];
    self.retryButton.hidden = YES;
    [self.collectionView addSubview:self.retryButton];
    
    // Server Config Button (para iPad con iOS 9)
    self.serverConfigButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.serverConfigButton.frame = CGRectMake((self.view.bounds.size.width - 230) / 2.0, 226, 230, 36);
    self.serverConfigButton.layer.cornerRadius = 6.0;
    self.serverConfigButton.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    [self.serverConfigButton setTitle:@"⚙️ Configurar Servidor / Proxy" forState:UIControlStateNormal];
    [self.serverConfigButton setTitleColor:[UIColor colorWithRed:0.3 green:0.75 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    self.serverConfigButton.titleLabel.font = [UIFont systemFontOfSize:13.0];
    [self.serverConfigButton addTarget:self action:@selector(showServerSettings) forControlEvents:UIControlEventTouchUpInside];
    self.serverConfigButton.hidden = YES;
    [self.collectionView addSubview:self.serverConfigButton];
}

- (void)setupLoadingIndicator {
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.loadingIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.loadingIndicator];
}

#pragma mark - Actions

- (void)categoryChanged:(UISegmentedControl *)sender {
    switch (sender.selectedSegmentIndex) {
        case 0:
            self.currentCategory = ComicCategoryAll;
            break;
        case 1:
            self.currentCategory = ComicCategoryWestern;
            break;
        case 2:
            self.currentCategory = ComicCategoryManhwa;
            break;
        case 3:
            self.currentCategory = ComicCategoryManga;
            break;
        default:
            self.currentCategory = ComicCategoryAll;
            break;
    }
    
    [self loadComicsResetting:YES];
}

- (void)handleRefresh {
    [self loadComicsResetting:YES];
}

- (void)showServerSettings {
    NSString *current = [[APIService sharedService] customServerURL];
    NSString *msg = @"Si tu iPad tiene errores de SSL / TLS en iOS 9, ejecuta 'iniciar_servidor.bat' en tu PC e introduce la IP de tu PC (ej: http://192.168.0.147:8080):";
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Servidor / Proxy Comico"
                                                                   message:msg
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"http://192.168.0.147:8080";
        textField.text = current.length > 0 ? current : @"http://192.168.0.147:8080";
        textField.keyboardType = UIKeyboardTypeURL;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    
    UIAlertAction *saveAction = [UIAlertAction actionWithTitle:@"Guardar y Conectar" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *tf = alert.textFields.firstObject;
        [[APIService sharedService] saveCustomServerURL:tf.text];
        [self handleRefresh];
    }];
    
    UIAlertAction *resetAction = [UIAlertAction actionWithTitle:@"Restablecer (Directo)" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[APIService sharedService] saveCustomServerURL:nil];
        [self handleRefresh];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil];
    
    [alert addAction:saveAction];
    [alert addAction:resetAction];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Data Loading

- (void)loadComicsResetting:(BOOL)reset {
    if (self.isLoading) return;
    self.isLoading = YES;
    
    if (reset) {
        self.currentPage = 0;
        self.hasMore = YES;
        self.emptyLabel.hidden = YES;
        self.retryButton.hidden = YES;
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
                self.emptyLabel.text = [NSString stringWithFormat:@"Error al conectar:\n%@\n\nToca para reintentar o configura un servidor opcional abajo.", error.localizedDescription ?: @"Error de red"];
                self.emptyLabel.hidden = NO;
                self.retryButton.hidden = NO;
                self.serverConfigButton.hidden = NO;
            }
            return;
        }
        
        self.retryButton.hidden = YES;
        self.serverConfigButton.hidden = YES;
        
        if (reset) {
            [self.comics removeAllObjects];
        }
        
        if (newComics.count < 20) {
            self.hasMore = NO;
        }
        
        [self.comics addObjectsFromArray:newComics];
        
        if (self.comics.count == 0) {
            self.emptyLabel.text = @"No se encontraron cómics en esta sección.";
            self.emptyLabel.hidden = NO;
        } else {
            self.emptyLabel.hidden = YES;
        }
        
        [self.collectionView reloadData];
    };
    
    if (self.activeSearchQuery && self.activeSearchQuery.length > 0) {
        [[APIService sharedService] searchComicsWithQuery:self.activeSearchQuery page:self.currentPage completion:completionBlock];
    } else {
        [[APIService sharedService] fetchComicsForCategory:self.currentCategory page:self.currentPage completion:completionBlock];
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
    CGFloat totalWidth = collectionView.bounds.size.width - 24;
    if (totalWidth < 100) totalWidth = 744.0;
    
    int columns = 2;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        columns = (collectionView.bounds.size.width > 800) ? 4 : 3;
    }
    
    CGFloat itemSpacing = 10 * (columns - 1);
    CGFloat width = floor((totalWidth - itemSpacing) / columns);
    CGFloat height = floor(width * 1.50);
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
