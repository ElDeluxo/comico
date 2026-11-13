import UIKit

class HomeViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UISearchBarDelegate {

    // MARK: - Properties

    private var comics: [Comic] = []
    private var currentPage = 0
    private var isLoading = false
    private var hasMorePages = true
    private var searchQuery: String?
    private let itemsPerPage = 20

    // MARK: - UI Elements

    private let searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.placeholder = "Search comics..."
        sb.searchBarStyle = .minimal
        sb.translatesAutoresizingMaskIntoConstraints = false
        return sb
    }()

    private var collectionView: UICollectionView!

    private let refreshControl = UIRefreshControl()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .gray)
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No comics found.\nTry a different search."
        label.font = AppFonts.body
        label.textColor = AppColors.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let footerActivityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .gray)
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        setupSearchBar()
        setupCollectionView()
        setupEmptyState()
        setupActivityIndicator()
        loadComics()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    }

    // MARK: - Setup

    private func setupNavigation() {
        title = "Comico"
        navigationController?.navigationBar.barTintColor = AppColors.dark
        navigationController?.navigationBar.tintColor = AppColors.primary
        navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: AppColors.primary,
            NSAttributedString.Key.font: AppFonts.titleLarge
        ]
        navigationController?.navigationBar.isTranslucent = false
    }

    private func setupSearchBar() {
        searchBar.delegate = self
        view.addSubview(searchBar)
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = AppSpacing.medium
        layout.minimumLineSpacing = AppSpacing.standard
        layout.sectionInset = UIEdgeInsets(top: AppSpacing.medium, left: AppSpacing.standard, bottom: AppSpacing.standard, right: AppSpacing.standard)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = AppColors.background
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(ComicCell.self, forCellWithReuseIdentifier: ComicCell.reuseIdentifier)
        collectionView.keyboardDismissMode = .onDrag

        refreshControl.tintColor = AppColors.primary
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.addSubview(refreshControl)

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupEmptyState() {
        view.addSubview(emptyStateLabel)
        NSLayoutConstraint.activate([
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppSpacing.large),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppSpacing.large)
        ])
    }

    private func setupActivityIndicator() {
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Data Loading

    private func loadComics() {
        guard !isLoading else { return }
        isLoading = true

        if comics.isEmpty {
            activityIndicator.startAnimating()
        }

        let completion: ([Comic], Bool) -> Void = { [weak self] newComics, hasMore in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async {
                strongSelf.isLoading = false
                strongSelf.hasMorePages = hasMore
                strongSelf.activityIndicator.stopAnimating()
                strongSelf.refreshControl.endRefreshing()
                strongSelf.footerActivityIndicator.stopAnimating()

                if strongSelf.currentPage == 0 {
                    strongSelf.comics = newComics
                } else {
                    strongSelf.comics.append(contentsOf: newComics)
                }

                strongSelf.emptyStateLabel.isHidden = !strongSelf.comics.isEmpty
                strongSelf.collectionView.reloadData()
            }
        }

        if let query = searchQuery, !query.isEmpty {
            APIService.shared.searchComics(query: query, page: currentPage) { result in
                switch result {
                case .success(let response):
                    let hasMore = (response.offset + response.limit) < response.total
                    completion(response.data, hasMore)
                case .failure:
                    completion([], false)
                }
            }
        } else {
            APIService.shared.fetchPopularComics(page: currentPage) { result in
                switch result {
                case .success(let response):
                    let hasMore = (response.offset + response.limit) < response.total
                    completion(response.data, hasMore)
                case .failure:
                    completion([], false)
                }
            }
        }
    }

    @objc private func handleRefresh() {
        currentPage = 0
        hasMorePages = true
        loadComics()
    }

    private func loadNextPage() {
        guard !isLoading, hasMorePages else { return }
        currentPage += 1
        footerActivityIndicator.startAnimating()
        loadComics()
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return comics.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ComicCell.reuseIdentifier, for: indexPath) as! ComicCell
        cell.configure(with: comics[indexPath.item])
        return cell
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let comic = comics[indexPath.item]
        let detailVC = ComicDetailViewController(comic: comic)
        navigationController?.pushViewController(detailVC, animated: true)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.size.height

        if offsetY > contentHeight - frameHeight - 200 {
            loadNextPage()
        }
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let isLandscape = view.bounds.width > view.bounds.height
        let columns: CGFloat = isLandscape ? 3 : 2
        let layout = collectionViewLayout as! UICollectionViewFlowLayout
        let totalSpacing = layout.sectionInset.left + layout.sectionInset.right + (layout.minimumInteritemSpacing * (columns - 1))
        let width = (collectionView.bounds.width - totalSpacing) / columns
        let height = width * 1.4 + 60 // image ratio + text area
        return CGSize(width: width, height: height)
    }

    // MARK: - UISearchBarDelegate

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchQuery = searchBar.text
        currentPage = 0
        hasMorePages = true
        comics.removeAll()
        collectionView.reloadData()
        loadComics()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            searchQuery = nil
            currentPage = 0
            hasMorePages = true
            comics.removeAll()
            collectionView.reloadData()
            loadComics()
        }
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = nil
        searchBar.resignFirstResponder()
        searchQuery = nil
        currentPage = 0
        hasMorePages = true
        comics.removeAll()
        collectionView.reloadData()
        loadComics()
    }
}
