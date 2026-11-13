#import "FavoritesViewController.h"
#import "ComicGridCell.h"
#import "ComicDetailViewController.h"
#import "FavoritesManager.h"

@interface FavoritesViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) NSArray<Comic *> *favorites;

@end

static NSString *const kFavCellId = @"ComicGridCell";

@implementation FavoritesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.extendedLayoutIncludesOpaqueBars = NO;
    
    self.title = @"Favoritos";
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:1.0];
    
    [self setupCollectionView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadFavorites];
}

- (void)setupCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.minimumInteritemSpacing = 10;
    layout.minimumLineSpacing = 14;
    layout.sectionInset = UIEdgeInsetsMake(14, 12, 16, 12);
    
    self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
    self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.alwaysBounceVertical = YES;
    
    [self.collectionView registerClass:[ComicGridCell class] forCellWithReuseIdentifier:kFavCellId];
    [self.view addSubview:self.collectionView];
    
    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 150, self.view.bounds.size.width - 40, 80)];
    self.emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    self.emptyLabel.font = [UIFont systemFontOfSize:15.0];
    self.emptyLabel.numberOfLines = 3;
    self.emptyLabel.text = @"Aún no tienes favoritos.\nExplora los cómics y pulsa ☆ Agregar\npara leerlos cuando quieras.";
    [self.view addSubview:self.emptyLabel];
}

- (void)reloadFavorites {
    self.favorites = [[FavoritesManager sharedManager] allFavorites];
    self.emptyLabel.hidden = (self.favorites.count > 0);
    [self.collectionView reloadData];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.favorites.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    ComicGridCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kFavCellId forIndexPath:indexPath];
    if (indexPath.item < self.favorites.count) {
        [cell configureWithComic:self.favorites[indexPath.item]];
    }
    return cell;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat totalWidth = collectionView.bounds.size.width - 24;
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
    if (indexPath.item < self.favorites.count) {
        Comic *comic = self.favorites[indexPath.item];
        ComicDetailViewController *detailVC = [[ComicDetailViewController alloc] initWithComic:comic];
        [self.navigationController pushViewController:detailVC animated:YES];
    }
}

@end

