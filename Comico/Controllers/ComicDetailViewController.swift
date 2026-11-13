import UIKit

class ComicDetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: - Properties

    private let comic: Comic
    private var chapters: [Chapter] = []
    private var currentPage = 0
    private var isLoadingChapters = false
    private var hasMoreChapters = true
    private var isDescriptionExpanded = false

    // MARK: - UI Elements

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsVerticalScrollIndicator = true
        return sv
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let coverImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = AppColors.lightGray
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let coverOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = AppFonts.titleLarge
        label.textColor = .white
        label.numberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let authorLabel: UILabel = {
        let label = UILabel()
        label.font = AppFonts.body
        label.textColor = UIColor.white.withAlphaComponent(0.9)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statusBadge: UILabel = {
        let label = UILabel()
        label.font = AppFonts.caption
        label.textColor = .white
        label.backgroundColor = AppColors.primary
        label.textAlignment = .center
        label.layer.cornerRadius = AppSpacing.badgeCornerRadius
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = AppFonts.body
        label.textColor = AppColors.textPrimary
        label.numberOfLines = 4
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let readMoreButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Read more", for: .normal)
        button.setTitleColor(AppColors.primary, for: .normal)
        button.titleLabel?.font = AppFonts.medium(size: 13)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let tagsScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let tagsStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = AppSpacing.small
        sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let readButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("📖 Start Reading", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = AppColors.primary
        button.titleLabel?.font = AppFonts.bold(size: 16)
        button.layer.cornerRadius = AppSpacing.buttonCornerRadius
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let chaptersHeaderLabel: UILabel = {
        let label = UILabel()
        label.text = "Chapters"
        label.font = AppFonts.titleMedium
        label.textColor = AppColors.textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let chaptersTableView: UITableView = {
        let tv = UITableView()
        tv.separatorStyle = .none
        tv.isScrollEnabled = false
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private var tableViewHeightConstraint: NSLayoutConstraint!

    private let chapterActivityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .gray)
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    private let loadMoreButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Load More Chapters", for: .normal)
        button.setTitleColor(AppColors.primary, for: .normal)
        button.titleLabel?.font = AppFonts.medium(size: 14)
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let favoriteButton: UIBarButtonItem = {
        return UIBarButtonItem(title: "♡", style: .plain, target: nil, action: nil)
    }()

    // MARK: - Init

    init(comic: Comic) {
        self.comic = comic
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.background
        setupNavigation()
        setupLayout()
        configureWithComic()
        loadChapters()
    }

    // MARK: - Setup

    private func setupNavigation() {
        navigationController?.navigationBar.tintColor = AppColors.primary
        favoriteButton.target = self
        favoriteButton.action = #selector(toggleFavorite)
        navigationItem.rightBarButtonItem = favoriteButton
        updateFavoriteButton()
    }

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(coverImageView)
        contentView.addSubview(coverOverlay)
        contentView.addSubview(titleLabel)
        contentView.addSubview(authorLabel)
        contentView.addSubview(statusBadge)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(readMoreButton)
        contentView.addSubview(tagsScrollView)
        tagsScrollView.addSubview(tagsStackView)
        contentView.addSubview(readButton)
        contentView.addSubview(chaptersHeaderLabel)
        contentView.addSubview(chaptersTableView)
        contentView.addSubview(chapterActivityIndicator)
        contentView.addSubview(loadMoreButton)

        chaptersTableView.dataSource = self
        chaptersTableView.delegate = self
        chaptersTableView.register(ChapterCell.self, forCellReuseIdentifier: ChapterCell.reuseIdentifier)

        readMoreButton.addTarget(self, action: #selector(toggleDescription), for: .touchUpInside)
        readButton.addTarget(self, action: #selector(startReading), for: .touchUpInside)
        loadMoreButton.addTarget(self, action: #selector(loadMoreChapters), for: .touchUpInside)

        tableViewHeightConstraint = chaptersTableView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // Cover image
            coverImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            coverImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            coverImageView.heightAnchor.constraint(equalToConstant: 300),

            coverOverlay.topAnchor.constraint(equalTo: coverImageView.topAnchor),
            coverOverlay.leadingAnchor.constraint(equalTo: coverImageView.leadingAnchor),
            coverOverlay.trailingAnchor.constraint(equalTo: coverImageView.trailingAnchor),
            coverOverlay.bottomAnchor.constraint(equalTo: coverImageView.bottomAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.standard),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.standard),
            titleLabel.bottomAnchor.constraint(equalTo: authorLabel.topAnchor, constant: -AppSpacing.small),

            authorLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.standard),
            authorLabel.bottomAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: -AppSpacing.standard),

            statusBadge.leadingAnchor.constraint(equalTo: authorLabel.trailingAnchor, constant: AppSpacing.small),
            statusBadge.centerYAnchor.constraint(equalTo: authorLabel.centerYAnchor),
            statusBadge.heightAnchor.constraint(equalToConstant: 22),
            statusBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),

            // Description
            descriptionLabel.topAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: AppSpacing.standard),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.standard),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.standard),

            readMoreButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: AppSpacing.tiny),
            readMoreButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.standard),

            // Tags
            tagsScrollView.topAnchor.constraint(equalTo: readMoreButton.bottomAnchor, constant: AppSpacing.medium),
            tagsScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.standard),
            tagsScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.standard),
            tagsScrollView.heightAnchor.constraint(equalToConstant: 32),

            tagsStackView.topAnchor.constraint(equalTo: tagsScrollView.topAnchor),
            tagsStackView.leadingAnchor.constraint(equalTo: tagsScrollView.leadingAnchor),
            tagsStackView.trailingAnchor.constraint(equalTo: tagsScrollView.trailingAnchor),
            tagsStackView.bottomAnchor.constraint(equalTo: tagsScrollView.bottomAnchor),
            tagsStackView.heightAnchor.constraint(equalTo: tagsScrollView.heightAnchor),

            // Read button
            readButton.topAnchor.constraint(equalTo: tagsScrollView.bottomAnchor, constant: AppSpacing.standard),
            readButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.standard),
            readButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.standard),
            readButton.heightAnchor.constraint(equalToConstant: 48),

            // Chapters header
            chaptersHeaderLabel.topAnchor.constraint(equalTo: readButton.bottomAnchor, constant: AppSpacing.large),
            chaptersHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.standard),

            chapterActivityIndicator.centerYAnchor.constraint(equalTo: chaptersHeaderLabel.centerYAnchor),
            chapterActivityIndicator.leadingAnchor.constraint(equalTo: chaptersHeaderLabel.trailingAnchor, constant: AppSpacing.small),

            // Chapters table
            chaptersTableView.topAnchor.constraint(equalTo: chaptersHeaderLabel.bottomAnchor, constant: AppSpacing.small),
            chaptersTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            chaptersTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tableViewHeightConstraint,

            // Load more button
            loadMoreButton.topAnchor.constraint(equalTo: chaptersTableView.bottomAnchor, constant: AppSpacing.small),
            loadMoreButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loadMoreButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppSpacing.large)
        ])
    }

    // MARK: - Configure

    private func configureWithComic() {
        titleLabel.text = comic.title
        authorLabel.text = comic.author ?? "Unknown Author"
        statusBadge.text = " \(comic.status?.rawValue.capitalized ?? "Unknown") "
        descriptionLabel.text = comic.description

        if let coverURL = comic.coverURL {
            ImageCache.shared.loadImage(from: coverURL) { [weak self] image in
                DispatchQueue.main.async {
                    self?.coverImageView.image = image
                }
            }
        }

        // Setup tags
        for subview in tagsStackView.arrangedSubviews {
            tagsStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        for tag in comic.tags {
            let badge = createTagBadge(tag.name)
            tagsStackView.addArrangedSubview(badge)
        }
    }

    private func createTagBadge(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = " \(text) "
        label.font = AppFonts.small
        label.textColor = AppColors.primary
        label.backgroundColor = AppColors.primary.withAlphaComponent(0.15)
        label.layer.cornerRadius = AppSpacing.badgeCornerRadius
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    // MARK: - Actions

    @objc private func toggleDescription() {
        isDescriptionExpanded = !isDescriptionExpanded
        descriptionLabel.numberOfLines = isDescriptionExpanded ? 0 : 4
        readMoreButton.setTitle(isDescriptionExpanded ? "Show less" : "Read more", for: .normal)
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func startReading() {
        guard let firstChapter = chapters.first else { return }
        let readerVC = ReaderViewController(chapter: firstChapter, allChapters: chapters, currentIndex: 0)
        navigationController?.pushViewController(readerVC, animated: true)
    }

    @objc private func toggleFavorite() {
        var favorites = getFavoriteIds()
        if favorites.contains(comic.id) {
            favorites.remove(comic.id)
        } else {
            favorites.insert(comic.id)
            saveFavoriteComic(comic)
        }
        saveFavoriteIds(favorites)
        updateFavoriteButton()
    }

    private func updateFavoriteButton() {
        let isFav = getFavoriteIds().contains(comic.id)
        favoriteButton.title = isFav ? "♥" : "♡"
    }

    // MARK: - Favorites Persistence

    private func getFavoriteIds() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: "comico_favorite_ids") ?? []
        return Set(array)
    }

    private func saveFavoriteIds(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: "comico_favorite_ids")
        UserDefaults.standard.synchronize()
    }

    private func saveFavoriteComic(_ comic: Comic) {
        var dict = UserDefaults.standard.dictionary(forKey: "comico_favorites_data") as? [String: [String: Any]] ?? [:]
        dict[comic.id] = [
            "id": comic.id,
            "title": comic.title,
            "author": comic.author ?? "",
            "coverURL": comic.coverURL ?? "",
            "status": comic.status?.rawValue ?? ""
        ]
        UserDefaults.standard.set(dict, forKey: "comico_favorites_data")
        UserDefaults.standard.synchronize()
    }

    // MARK: - Load Chapters

    private func loadChapters() {
        guard !isLoadingChapters else { return }
        isLoadingChapters = true
        chapterActivityIndicator.startAnimating()

        APIService.shared.fetchChapters(mangaId: comic.id, page: currentPage) { [weak self] result in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async {
                strongSelf.isLoadingChapters = false
                strongSelf.chapterActivityIndicator.stopAnimating()

                switch result {
                case .success(let newChapters):
                    strongSelf.chapters.append(contentsOf: newChapters)
                    strongSelf.hasMoreChapters = newChapters.count >= 20
                    strongSelf.loadMoreButton.isHidden = !strongSelf.hasMoreChapters
                    strongSelf.chaptersTableView.reloadData()
                    strongSelf.updateTableViewHeight()
                case .failure:
                    break
                }
            }
        }
    }

    @objc private func loadMoreChapters() {
        currentPage += 1
        loadChapters()
    }

    private func updateTableViewHeight() {
        chaptersTableView.layoutIfNeeded()
        let height = CGFloat(chapters.count) * 60.0
        tableViewHeightConstraint.constant = height
        view.layoutIfNeeded()
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chapters.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChapterCell.reuseIdentifier, for: indexPath) as! ChapterCell
        cell.configure(with: chapters[indexPath.row])
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let chapter = chapters[indexPath.row]
        let readerVC = ReaderViewController(chapter: chapter, allChapters: chapters, currentIndex: indexPath.row)
        navigationController?.pushViewController(readerVC, animated: true)
    }
}
