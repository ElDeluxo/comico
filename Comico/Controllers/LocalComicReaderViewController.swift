//
//  LocalComicReaderViewController.swift
//  Comico
//
//  Lector para comics locales (CBZ, CBR, PDF, EPUB) con modo horizontal por defecto
//

import UIKit

class LocalComicReaderViewController: UIViewController, UIScrollViewDelegate {

    // MARK: - Types

    private enum ReadingMode {
        case horizontal  // Western comics: left-to-right paging
        case vertical    // Manga: continuous vertical scroll
    }

    // MARK: - Properties

    private let comic: LocalComic
    private var startPage: Int
    private var pages: [LocalComicPage] = []
    private var pageImageViews: [UIImageView] = []
    private var currentPageIndex = 0
    private var readingMode: ReadingMode = .horizontal  // Default to horizontal for Western comics
    private var isBarsHidden = false
    private var isLoadingPages = false

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

    private let prevPageButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("◀ Prev", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = AppFonts.medium(size: 14)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let nextPageButton: UIButton = {
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

    private let pageSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = 0
        slider.minimumTrackTintColor = AppColors.primary
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()

    // MARK: - Init

    init(comic: LocalComic, startPage: Int = 0) {
        self.comic = comic
        self.startPage = startPage
        self.currentPageIndex = startPage
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
        updateNavigationButtons()
        extractAndLoadPages()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.barTintColor = UIColor.black
        navigationController?.navigationBar.tintColor = AppColors.primary
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Actualizar layout de páginas cuando el view ya tiene tamaño
        if !pages.isEmpty && pageImageViews.isEmpty {
            setupPageViews()
        }
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
        bottomBar.addSubview(prevPageButton)
        bottomBar.addSubview(nextPageButton)
        bottomBar.addSubview(modeToggleButton)
        bottomBar.addSubview(pageSlider)

        pagingScrollView.delegate = self
        verticalScrollView.delegate = self

        prevPageButton.addTarget(self, action: #selector(goToPreviousPage), for: .touchUpInside)
        nextPageButton.addTarget(self, action: #selector(goToNextPage), for: .touchUpInside)
        modeToggleButton.addTarget(self, action: #selector(toggleReadingMode), for: .touchUpInside)
        pageSlider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)

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
            bottomBar.heightAnchor.constraint(equalToConstant: 60),

            prevPageButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: AppSpacing.standard),
            prevPageButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            nextPageButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -AppSpacing.standard),
            nextPageButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            modeToggleButton.leadingAnchor.constraint(equalTo: prevPageButton.trailingAnchor, constant: AppSpacing.medium),
            modeToggleButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            pageSlider.leadingAnchor.constraint(equalTo: modeToggleButton.trailingAnchor, constant: AppSpacing.medium),
            pageSlider.trailingAnchor.constraint(equalTo: nextPageButton.leadingAnchor, constant: -AppSpacing.medium),
            pageSlider.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            pageSlider.heightAnchor.constraint(equalToConstant: 30)
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

    // MARK: - Page Extraction & Loading

    private func extractAndLoadPages() {
        isLoadingPages = true
        activityIndicator.startAnimating()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let extractedPages = ComicFileExtractor.extractPages(from: self.comic)

            DispatchQueue.main.async {
                self.isLoadingPages = false
                self.activityIndicator.stopAnimating()

                if extractedPages.isEmpty {
                    self.showError("Could not extract pages from this comic.\nFormat may not be supported.")
                    return
                }

                self.pages = extractedPages
                self.pageSlider.maximumValue = Float(max(0, self.pages.count - 1))
                self.setupPageViews()
                self.scrollToPage(self.startPage, animated: false)
                self.updatePageIndicator()
                self.preloadAdjacentPages()
            }
        }
    }

    private func setupPageViews() {
        // Clear existing
        for iv in pageImageViews {
            iv.removeFromSuperview()
        }
        pageImageViews.removeAll()

        let pageCount = pages.count
        guard pageCount > 0 else { return }

        // Horizontal paging setup
        let scrollWidth = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        let scrollHeight = pagingScrollView.bounds.height > 0 ? pagingScrollView.bounds.height : (view.bounds.height > 60 ? view.bounds.height - 60 : UIScreen.main.bounds.height - 60)

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

            // Vertical page
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
                vImageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
            ])

            if i == pageCount - 1 {
                vImageView.bottomAnchor.constraint(equalTo: verticalContentView.bottomAnchor).isActive = true
            }

            prevVerticalAnchor = vImageView.bottomAnchor
        }

        // Load first few pages
        loadPageImage(at: currentPageIndex)
        preloadAdjacentPages()
    }

    private func loadPageImage(at index: Int) {
        guard index >= 0, index < pages.count, index < pageImageViews.count else { return }
        guard comic.fileFormat == .pdf else {
            // Para CBZ/CBR, necesitaríamos librería de extracción
            // Por ahora mostramos placeholder
            DispatchQueue.main.async { [weak self] in
                self?.setPlaceholderImage(at: index)
            }
            return
        }

        ComicFileExtractor.renderPage(pages[index], from: comic) { [weak self] image in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if index < self.pageImageViews.count {
                    self.pageImageViews[index].image = image

                    // Stop page activity indicator
                    if let ai = self.pagingScrollView.viewWithTag(3000 + index) as? UIActivityIndicatorView {
                        ai.stopAnimating()
                    }

                    // Also set vertical image
                    if let vImageView = self.verticalContentView.viewWithTag(4000 + index) as? UIImageView {
                        vImageView.image = image
                    }
                }
            }
        }
    }

    private func setPlaceholderImage(at index: Int) {
        guard index < pageImageViews.count else { return }
        let imageView = pageImageViews[index]

        // Crear imagen placeholder con número de página
        let renderer = UIGraphicsImageRenderer(size: imageView.bounds.size)
        let image = renderer.image { context in
            UIColor.darkGray.setFill()
            context.fill(imageView.bounds)

            let text = "Page \(index + 1)\n\(comic.fileFormat.displayName) - Tap to extract"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: AppFonts.body,
                .foregroundColor: UIColor.white.withAlphaComponent(0.7)
            ]
            let textSize = text.size(withAttributes: attrs)
            let textRect = CGRect(
                x: (imageView.bounds.width - textSize.width) / 2,
                y: (imageView.bounds.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attrs)
        }

        imageView.image = image

        if let ai = pagingScrollView.viewWithTag(3000 + index) as? UIActivityIndicatorView {
            ai.stopAnimating()
        }

        if let vImageView = verticalContentView.viewWithTag(4000 + index) as? UIImageView {
            vImageView.image = image
        }
    }

    private func preloadAdjacentPages() {
        let range = max(0, currentPageIndex - 2)...min(pages.count - 1, currentPageIndex + 2)
        for i in range {
            if pageImageViews[i].image == nil {
                loadPageImage(at: i)
            }
        }
    }

    // MARK: - Actions

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        let third = view.bounds.width / 3

        if location.x < third {
            goToPreviousPage()
        } else if location.x > third * 2 {
            goToNextPage()
        } else {
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
        scrollToPage(currentPageIndex, animated: true)
    }

    private func goToNextPage() {
        guard currentPageIndex < pages.count - 1 else { return }
        currentPageIndex += 1
        scrollToPage(currentPageIndex, animated: true)
    }

    private func scrollToPage(_ page: Int, animated: Bool) {
        guard page >= 0, page < pages.count else { return }
        currentPageIndex = page

        if readingMode == .horizontal {
            let pageWidth = pagingScrollView.bounds.width > 0 ? pagingScrollView.bounds.width : view.bounds.width
            let x = CGFloat(page) * pageWidth
            pagingScrollView.setContentOffset(CGPoint(x: x, y: 0), animated: animated)
        }
        updatePageIndicator()
        updateNavigationButtons()
        preloadAdjacentPages()

        // Guardar progreso
        LocalComicLibrary.shared.updateReadingProgress(for: comic.id, page: page)
    }

    @objc private func sliderValueChanged(_ slider: UISlider) {
        let page = Int(round(slider.value))
        scrollToPage(page, animated: true)
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
            scrollToPage(currentPageIndex, animated: false)
        }
    }

    private func updateNavigationButtons() {
        prevPageButton.isEnabled = currentPageIndex > 0
        prevPageButton.alpha = currentPageIndex > 0 ? 1.0 : 0.4
        nextPageButton.isEnabled = currentPageIndex < pages.count - 1
        nextPageButton.alpha = currentPageIndex < pages.count - 1 ? 1.0 : 0.4

        pageSlider.value = Float(currentPageIndex)
        title = comic.title
    }

    private func updatePageIndicator() {
        let total = pages.count
        pageIndicatorLabel.text = " \(currentPageIndex + 1) / \(total) "
        pageSlider.maximumValue = Float(max(0, total - 1))
        pageSlider.value = Float(currentPageIndex)
    }

    private func showError(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.textAlignment = .center
        label.font = AppFonts.body
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppSpacing.large),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppSpacing.large)
        ])
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView === pagingScrollView {
            let pageWidth = scrollView.bounds.width > 0 ? scrollView.bounds.width : view.bounds.width
            let page = Int(scrollView.contentOffset.x / pageWidth)
            if page != currentPageIndex && page >= 0 && page < pages.count {
                currentPageIndex = page
                updatePageIndicator()
                updateNavigationButtons()
                preloadAdjacentPages()

                LocalComicLibrary.shared.updateReadingProgress(for: comic.id, page: page)
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

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // Centrar imagen al hacer zoom
        if let zoomView = scrollView.delegate as? UIScrollView,
           let imageView = viewForZooming(in: scrollView) {
            let boundsSize = scrollView.bounds.size
            var frameToCenter = imageView.frame

            if frameToCenter.size.width < boundsSize.width {
                frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
            } else {
                frameToCenter.origin.x = 0
            }

            if frameToCenter.size.height < boundsSize.height {
                frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
            } else {
                frameToCenter.origin.y = 0
            }

            imageView.frame = frameToCenter
        }
    }
}