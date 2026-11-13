import UIKit

class FavoritesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    // MARK: - Properties

    private var favoriteComics: [Comic] = []

    // MARK: - UI Elements

    private var collectionView: UICollectionView!

    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No favorites yet.\nStart exploring and save your\nfavorite comics! ♥"
        label.font = AppFonts.body
        label.textColor = AppColors.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.background
        setupNavigation()
        setupCollectionView()
        setupEmptyState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadFavorites()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    }

    // MARK: - Setup

    private func setupNavigation() {
        title = "Favorites"
        navigationController?.navigationBar.barTintColor = AppColors.dark
        navigationController?.navigationBar.tintColor = AppColors.primary
        navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: AppColors.primary,
            NSAttributedString.Key.font: AppFonts.titleLarge
        ]
        navigationController?.navigationBar.isTranslucent = false
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

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(longPress)

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
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

    // MARK: - Data

    private func loadFavorites() {
        let ids = UserDefaults.standard.stringArray(forKey: "comico_favorite_ids") ?? []
        let dataDict = UserDefaults.standard.dictionary(forKey: "comico_favorites_data") as? [String: [String: Any]] ?? [:]

        var comics: [Comic] = []
        for id in ids {
            if let info = dataDict[id] {
                let title = info["title"] as? String ?? ""
                let author = info["author"] as? String
                let coverURLString = info["coverURL"] as? String
                let status = info["status"] as? String
                let coverURL: URL? = coverURLString != nil && !coverURLString!.isEmpty ? URL(string: coverURLString!) : nil

                let comic = Comic(
                    id: id,
                    title: title,
                    description: nil,
                    coverURL: coverURL,
                    author: author,
                    status: status,
                    tags: nil
                )
                comics.append(comic)
            }
        }

        favoriteComics = comics
        emptyStateLabel.isHidden = !favoriteComics.isEmpty
        collectionView.reloadData()
    }

    private func removeFavorite(at index: Int) {
        let comic = favoriteComics[index]
        var ids = UserDefaults.standard.stringArray(forKey: "comico_favorite_ids") ?? []
        ids = ids.filter { $0 != comic.id }
        UserDefaults.standard.set(ids, forKey: "comico_favorite_ids")

        var dataDict = UserDefaults.standard.dictionary(forKey: "comico_favorites_data") as? [String: [String: Any]] ?? [:]
        dataDict.removeValue(forKey: comic.id)
        UserDefaults.standard.set(dataDict, forKey: "comico_favorites_data")
        UserDefaults.standard.synchronize()

        favoriteComics.remove(at: index)
        collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
        emptyStateLabel.isHidden = !favoriteComics.isEmpty
    }

    // MARK: - Long Press

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        let point = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }

        let comic = favoriteComics[indexPath.item]

        let alert = UIAlertController(
            title: "Remove Favorite",
            message: "Remove \"\(comic.title)\" from favorites?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
            self?.removeFavorite(at: indexPath.item)
        })
        present(alert, animated: true, completion: nil)
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return favoriteComics.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ComicCell.reuseIdentifier, for: indexPath) as! ComicCell
        cell.configure(with: favoriteComics[indexPath.item])
        return cell
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let comic = favoriteComics[indexPath.item]
        let detailVC = ComicDetailViewController(comic: comic)
        navigationController?.pushViewController(detailVC, animated: true)
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let isLandscape = view.bounds.width > view.bounds.height
        let columns: CGFloat = isLandscape ? 3 : 2
        let layout = collectionViewLayout as! UICollectionViewFlowLayout
        let totalSpacing = layout.sectionInset.left + layout.sectionInset.right + (layout.minimumInteritemSpacing * (columns - 1))
        let width = (collectionView.bounds.width - totalSpacing) / columns
        let height = width * 1.4 + 60
        return CGSize(width: width, height: height)
    }
}
