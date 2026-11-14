import UIKit

class ReaderViewController: UIViewController, UIScrollViewDelegate {

    // MARK: - Types

    private enum ReadingMode {
        case horizontal // Western paging
        case vertical   // Manga continuous scroll
    }

    // MARK: - Properties

    private var chapter: Chapter
    private var allChapters: [Chapter]
    private var currentChapterIndex: Int
    private var pageURLs: [String] = []
    private var pageImageViews: [UIImageView] = []
    private var currentPageIndex = 0
    private var readingMode: ReadingMode = .horizontal
    private var isBarsHidden = false

    // MARK: - UI Elements

    private let pagingScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.isPagingEnabled = true
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.bounces = true
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let verticalScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.isPagingEnabled = false
        sv.showsVerticalScrollIndicator = true
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.isHidden = true
        return sv
    }()

    private let verticalContentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let pageIndicatorLabel: UILabel = {
        let label = UILabel()
        label.font = AppFonts.medium(size: 14)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .whiteLarge)
        ai.color = AppColors.primary
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    private let bottomBar: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let prevChapterButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("◀ Prev", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = AppFonts.medium(size: 14)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let nextChapterButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Next ▶", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = AppFonts.medium(size: 14)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let modeToggleButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("↕ Vertical", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = AppFonts.medium(size: 13)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    // MARK: - Init

    init(chapter: Chapter, allChapters: [Chapter], currentIndex: Int) {
        self.chapter = chapter
        self.allChapters = allChapters
        self.currentChapterIndex = currentIndex
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupLayout()
        setupGestures()
        updateChapterButtons()
        loadPages()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.barTintColor = UIColor.black
        navigationController?.navigationBar.tintColor = AppColors.primary
    }

    override var prefersStatusBarHidden: Bool {
        return isBarsHidden
    }

    // MARK: - Setup

    private func setupLayout() {
        view.addSubview(pagingScrollView)
        view.addSubview(verticalScrollView)
        verticalScrollView.addSubview(verticalContentView)
        view.addSubview(pageIndicatorLabel)
        view.addSubview(activityIndicator)
        view.addSubview(bottomBar)
        bottomBar.addSubview(prevChapterButton)
        bottomBar.addSubview(nextChapterButton)
        bottomBar.addSubview(modeToggleButton)

        pagingScrollView.delegate = self
        verticalScrollView.delegate = self

        prevChapterButton.addTarget(self, action: #selector(goToPrevChapter), for: .touchUpInside)
        nextChapterButton.addTarget(self, action: #selector(goToNextChapter), for: .touchUpInside)
        modeToggleButton.addTarget(self, action: #selector(toggleReadingMode), for: .touchUpInside)

        NSLayoutConstraint.activate([
            pagingScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            pagingScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pagingScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pagingScrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            verticalScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            verticalScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            verticalScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            verticalScrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            verticalContentView.topAnchor.constraint(equalTo: verticalScrollView.topAnchor),
            verticalContentView.leadingAnchor.constraint(equalTo: verticalScrollView.leadingAnchor),
            verticalContentView.trailingAnchor.constraint(equalTo: verticalScrollView.trailingAnchor),
            verticalContentView.bottomAnchor.constraint(equalTo: verticalScrollView.bottomAnchor),
            verticalContentView.widthAnchor.constraint(equalTo: verticalScrollView.widthAnchor),

            pageIndicatorLabel.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: AppSpacing.small),
            pageIndicatorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageIndicatorLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            pageIndicatorLabel.heightAnchor.constraint(equalToConstant: 28),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 50),

            prevChapterButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: AppSpacing.standard),
            prevChapterButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            nextChapterButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -AppSpacing.standard),
            nextChapterButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            modeToggleButton.centerXAnchor.constraint(equalTo: bottomBar.centerXAnchor),
            modeToggleButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor)
        ])
    }

    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tapGesture)

        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTapGesture)

        tapGesture.require(toFail: doubleTapGesture)
    }

    // MARK: - Load Pages

    private func loadPages() {
        activityIndicator.startAnimating()

        APIService.shared.fetchPages(chapterId: chapter.id) { [weak self] result in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async {
                strongSelf.activityIndicator.stopAnimating()

                switch result {
                case .success(let pages):
                    strongSelf.pageURLs = pages.map { $0.imageURL }
                    if strongSelf.pageURLs.isEmpty {
                        strongSelf.showError("No pages found for this chapter")
                    } else {
                        strongSelf.setupPages()
                        strongSelf.updatePageIndicator()
                        strongSelf.preloadAdjacentPages()
                    }
                case .failure(let error):
                    strongSelf.showError("Failed to load pages: \(error.localizedDescription)")
                }
            }
        }
    }

    private func setupPages() {
        // Clear existing
        for iv in pageImageViews {
            iv.removeFromSuperview()
        }
        pageImageViews.removeAll()

        let pageCount = pageURLs.count
        guard pageCount > 0 else {
            showError("No pages available for this chapter")
            return
        }

        // Use view.bounds safely - ensure layout has happened
        let scrollWidth = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        let scrollHeight = pagingScrollView.bounds.height > 0 ? pagingScrollView.bounds.height : (view.bounds.height > 50 ? view.bounds.height - 50 : UIScreen.main.bounds.height - 50)

        pagingScrollView.contentSize = CGSize(width: scrollWidth * CGFloat(pageCount), height: scrollHeight)

        // Vertical mode: clear old subviews
        for subview in verticalContentView.subviews { subview.removeFromSuperview() }

        var prevVerticalAnchor: NSLayoutAnchor<NSLayoutYAxisAnchor> = verticalContentView.topAnchor

        for i in 0..<pageCount {
            // Horizontal page (inside a zoom scroll view)
            let zoomContainer = UIScrollView(frame: CGRect(x: scrollWidth * CGFloat(i), y: 0, width: scrollWidth, height: scrollHeight))
            zoomContainer.minimumZoomScale = 1.0
            zoomContainer.maximumZoomScale = 3.0
            zoomContainer.delegate = self
            zoomContainer.tag = 1000 + i
            zoomContainer.showsHorizontalScrollIndicator = false
            zoomContainer.showsVerticalScrollIndicator = false

            let imageView = UIImageView(frame: zoomContainer.bounds)
            imageView.contentMode = .scaleAspectFit
            imageView.backgroundColor = .black
            imageView.tag = 2000 + i
            imageView.clipsToBounds = true
            zoomContainer.addSubview(imageView)
            pagingScrollView.addSubview(zoomContainer)

            // Per-page activity indicator
            let pageAI = UIActivityIndicatorView(style: .white)
            pageAI.center = CGPoint(x: scrollWidth / 2, y: scrollHeight / 2)
            pageAI.tag = 3000 + i
            pageAI.startAnimating()
            zoomContainer.addSubview(pageAI)

            pageImageViews.append(imageView)

            // Vertical page - use intrinsic content size with aspect fit, don't force aspect ratio
            let vImageView = UIImageView()
            vImageView.contentMode = .scaleAspectFit
            vImageView.backgroundColor = .black
            vImageView.tag = 4000 + i
            vImageView.clipsToBounds = true
            vImageView.translatesAutoresizingMaskIntoConstraints = false
            verticalContentView.addSubview(vImageView)

            NSLayoutConstraint.activate([
                vImageView.topAnchor.constraint(equalTo: prevVerticalAnchor, constant: i == 0 ? 0 : 2),
                vImageView.leadingAnchor.constraint(equalTo: verticalContentView.leadingAnchor),
                vImageView.trailingAnchor.constraint(equalTo: verticalContentView.trailingAnchor),
                // Use a reasonable default height, actual image will scale to fit
                vImageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
            ])

            if i == pageCount - 1 {
                vImageView.bottomAnchor.constraint(equalTo: verticalContentView.bottomAnchor).isActive = true
            }

            prevVerticalAnchor = vImageView.bottomAnchor
        }

        // Load first page
        loadPageImage(at: 0)
    }

    private func loadPageImage(at index: Int) {
        guard index >= 0, index < pageURLs.count else { return }

        let urlString = pageURLs[index]
        ImageCache.shared.loadImage(from: urlString) { [weak self] image in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async {
                if index < strongSelf.pageImageViews.count {
                    strongSelf.pageImageViews[index].image = image

                    // Stop page activity indicator
                    if let ai = strongSelf.pagingScrollView.viewWithTag(3000 + index) as? UIActivityIndicatorView {
                        ai.stopAnimating()
                    }

                    // Also set vertical image
                    if let vImageView = strongSelf.verticalContentView.viewWithTag(4000 + index) as? UIImageView {
                        vImageView.image = image
                    }
                }
            }
        }
    }

    private func preloadAdjacentPages() {
        let range = max(0, currentPageIndex - 2)...min(pageURLs.count - 1, currentPageIndex + 2)
        for i in range {
            loadPageImage(at: i)
        }
    }

    // MARK: - Actions

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        let third = view.bounds.width / 3

        if location.x < third {
            // Left third: previous page
            goToPreviousPage()
        } else if location.x > third * 2 {
            // Right third: next page
            goToNextPage()
        } else {
            // Center: toggle bars
            toggleBars()
        }
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard readingMode == .horizontal else { return }
        let index = currentPageIndex
        guard let zoomContainer = pagingScrollView.viewWithTag(1000 + index) as? UIScrollView else { return }

        if zoomContainer.zoomScale > 1.0 {
            zoomContainer.setZoomScale(1.0, animated: true)
        } else {
            let point = gesture.location(in: zoomContainer)
            let zoomRect = CGRect(x: point.x - 50, y: point.y - 50, width: 100, height: 100)
            zoomContainer.zoom(to: zoomRect, animated: true)
        }
    }

    private func goToPreviousPage() {
        guard currentPageIndex > 0 else { return }
        currentPageIndex -= 1
        scrollToCurrentPage(animated: true)
    }

    private func goToNextPage() {
        guard currentPageIndex < pageURLs.count - 1 else { return }
        currentPageIndex += 1
        scrollToCurrentPage(animated: true)
    }

    private func scrollToCurrentPage(animated: Bool) {
        if readingMode == .horizontal {
            let pageWidth = pagingScrollView.bounds.width > 0 ? pagingScrollView.bounds.width : view.bounds.width
            let x = CGFloat(currentPageIndex) * pageWidth
            pagingScrollView.setContentOffset(CGPoint(x: x, y: 0), animated: animated)
        }
        updatePageIndicator()
        preloadAdjacentPages()
    }

    private func toggleBars() {
        isBarsHidden = !isBarsHidden
        navigationController?.setNavigationBarHidden(isBarsHidden, animated: true)

        UIView.animate(withDuration: 0.3) {
            self.bottomBar.alpha = self.isBarsHidden ? 0 : 1
            self.pageIndicatorLabel.alpha = self.isBarsHidden ? 0 : 1
        }

        setNeedsStatusBarAppearanceUpdate()
    }

    @objc private func toggleReadingMode() {
        if readingMode == .horizontal {
            readingMode = .vertical
            modeToggleButton.setTitle("↔ Horizontal", for: .normal)
            pagingScrollView.isHidden = true
            verticalScrollView.isHidden = false
        } else {
            readingMode = .horizontal
            modeToggleButton.setTitle("↕ Vertical", for: .normal)
            pagingScrollView.isHidden = false
            verticalScrollView.isHidden = true
            scrollToCurrentPage(animated: false)
        }
    }

    @objc private func goToPrevChapter() {
        guard currentChapterIndex > 0 else { return }
        currentChapterIndex -= 1
        chapter = allChapters[currentChapterIndex]
        currentPageIndex = 0
        updateChapterButtons()
        loadPages()
    }

    @objc private func goToNextChapter() {
        guard currentChapterIndex < allChapters.count - 1 else { return }
        currentChapterIndex += 1
        chapter = allChapters[currentChapterIndex]
        currentPageIndex = 0
        updateChapterButtons()
        loadPages()
    }

    private func updateChapterButtons() {
        prevChapterButton.isEnabled = currentChapterIndex > 0
        prevChapterButton.alpha = currentChapterIndex > 0 ? 1.0 : 0.4
        nextChapterButton.isEnabled = currentChapterIndex < allChapters.count - 1
        nextChapterButton.alpha = currentChapterIndex < allChapters.count - 1 ? 1.0 : 0.4

        if let chapterNum = chapter.chapter {
            title = "Chapter \(chapterNum)"
        } else {
            title = "Reader"
        }
    }

    private func updatePageIndicator() {
        let total = pageURLs.count
        pageIndicatorLabel.text = " \(currentPageIndex + 1) / \(total) "
    }

    private func showError(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.textAlignment = .center
        label.font = AppFonts.body
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView === pagingScrollView {
            let pageWidth = scrollView.bounds.width > 0 ? scrollView.bounds.width : view.bounds.width
            let page = Int(scrollView.contentOffset.x / pageWidth)
            if page != currentPageIndex && page >= 0 && page < pageURLs.count {
                currentPageIndex = page
                updatePageIndicator()
                preloadAdjacentPages()
            }
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        let tag = scrollView.tag
        if tag >= 1000 && tag < 2000 {
            let pageIndex = tag - 1000
            return scrollView.viewWithTag(2000 + pageIndex)
        }
        return nil
    }
}
