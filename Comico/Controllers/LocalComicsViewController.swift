//
//  LocalComicsViewController.swift
//  Comico
//
//  Vista para navegar y leer comics locales (CBZ, CBR, PDF, EPUB)
//

import UIKit
import MobileCoreServices

class LocalComicsViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIDocumentPickerDelegate {

    // MARK: - Properties

    private var localComics: [LocalComic] = []
    private var isLoading = false

    // MARK: - UI Elements

    private var collectionView: UICollectionView!

    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No local comics yet.\nTap + to import CBZ, CBR, PDF, or EPUB files."
        label.font = AppFonts.body
        label.textColor = AppColors.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .gray)
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    private let importButton: UIBarButtonItem = {
        let btn = UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil)
        return btn
    }()

    private let scanButton: UIBarButtonItem = {
        let btn = UIBarButtonItem(title: "Scan", style: .plain, target: nil, action: nil)
        return btn
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.background
        setupNavigation()
        setupCollectionView()
        setupEmptyState()
        setupActivityIndicator()
        loadComics()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
        title = "Western Comics"
        navigationController?.navigationBar.barTintColor = AppColors.dark
        navigationController?.navigationBar.tintColor = AppColors.primary
        navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: AppColors.primary,
            NSAttributedString.Key.font: AppFonts.titleLarge
        ]
        navigationController?.navigationBar.isTranslucent = false

        importButton.target = self
        importButton.action = #selector(importComicTapped)
        scanButton.target = self
        scanButton.action = #selector(scanForComicsTapped)

        navigationItem.rightBarButtonItems = [importButton, scanButton]
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

    private func setupActivityIndicator() {
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Data Loading

    private func loadComics() {
        localComics = LocalComicLibrary.shared.getAllComics()
        emptyStateLabel.isHidden = !localComics.isEmpty
        collectionView.reloadData()
    }

    // MARK: - Actions

    @objc private func importComicTapped() {
        // Usar kUTType constants de MobileCoreServices (compatible con iOS 9+)
        let documentTypes = [
            kUTTypeArchive as String,        // CBZ, CBR, ZIP
            kUTTypePDF as String,            // PDF
            kUTTypeElectronicPublication as String, // EPUB
            "public.data" as String          // Fallback genérico
        ]

        let documentPicker = UIDocumentPickerViewController(documentTypes: documentTypes, in: .import)
        documentPicker.delegate = self
        if #available(iOS 11.0, *) {
            documentPicker.allowsMultipleSelection = true
        }
        present(documentPicker, animated: true, completion: nil)
    }

    @objc private func scanForComicsTapped() {
        activityIndicator.startAnimating()
        scanButton.isEnabled = false

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let newFiles = LocalComicLibrary.shared.scanForNewComics()

            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                self?.scanButton.isEnabled = true

                if newFiles.isEmpty {
                    let alert = UIAlertController(title: "Scan Complete", message: "No new comics found in the Comics folder.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                } else {
                    var importedCount = 0
                    for fileURL in newFiles {
                        if LocalComicLibrary.shared.importComic(from: fileURL) != nil {
                            importedCount += 1
                        }
                    }
                    self?.loadComics()

                    let alert = UIAlertController(title: "Scan Complete", message: "Imported \(importedCount) new comic(s).", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        let point = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }

        let comic = localComics[indexPath.item]

        let alert = UIAlertController(title: comic.title, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Read", style: .default) { [weak self] _ in
            self?.openReader(for: comic, atPage: comic.lastReadPage)
        })
        alert.addAction(UIAlertAction(title: "Read from Beginning", style: .default) { [weak self] _ in
            self?.openReader(for: comic, atPage: 0)
        })
        alert.addAction(UIAlertAction(title: "Remove from Library", style: .destructive) { [weak self] _ in
            self?.confirmRemoveComic(at: indexPath.item)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // Para iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = collectionView
            popover.sourceRect = CGRect(x: point.x, y: point.y, width: 1, height: 1)
        }

        present(alert, animated: true)
    }

    private func confirmRemoveComic(at index: Int) {
        let comic = localComics[index]
        let alert = UIAlertController(
            title: "Remove Comic",
            message: "Remove \"\(comic.title)\" from library? The file will not be deleted.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
            LocalComicLibrary.shared.removeComic(withId: comic.id)
            self?.loadComics()
        })
        present(alert, animated: true)
    }

    private func openReader(for comic: LocalComic, atPage page: Int) {
        let readerVC = LocalComicReaderViewController(comic: comic, startPage: page)
        navigationController?.pushViewController(readerVC, animated: true)
    }

    // MARK: - UIDocumentPickerDelegate

    // iOS 11+
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        var importedCount = 0
        for url in urls {
            if LocalComicLibrary.shared.importComic(from: url) != nil {
                importedCount += 1
            }
        }
        loadComics()

        if importedCount > 0 {
            let alert = UIAlertController(title: "Import Complete", message: "Imported \(importedCount) comic(s).", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    // iOS 8 - 10
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        documentPicker(controller, didPickDocumentsAt: [url])
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // Usuario canceló
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return localComics.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ComicCell.reuseIdentifier, for: indexPath) as! ComicCell
        let comic = localComics[indexPath.item]

        // Adaptar LocalComic para que funcione con ComicCell
        let displayComic = Comic(
            id: comic.id,
            title: comic.title,
            description: "",
            coverURL: comic.coverImagePath,
            author: comic.author,
            status: nil,
            tags: []
        )
        cell.configure(with: displayComic)

        // Mostrar progreso de lectura si existe
        if comic.lastReadPage > 0 && comic.pageCount > 0 {
            let progress = Float(comic.lastReadPage) / Float(comic.pageCount)
            let percent = Int(progress * 100)
            // Podríamos añadir una etiqueta de progreso aquí
        }

        return cell
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let comic = localComics[indexPath.item]
        openReader(for: comic, atPage: comic.lastReadPage)
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