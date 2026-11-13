import UIKit

class ComicCell: UICollectionViewCell {

    static let reuseIdentifier = "ComicCell"

    // MARK: - UI Elements

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = AppColors.cardBackground
        view.layer.cornerRadius = AppSpacing.cellCornerRadius
        view.layer.masksToBounds = true
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

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = AppFonts.titleSmall
        label.textColor = AppColors.textPrimary
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let authorLabel: UILabel = {
        let label = UILabel()
        label.font = AppFonts.caption
        label.textColor = AppColors.textSecondary
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupShadow()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupViews()
        setupShadow()
    }

    // MARK: - Setup

    private func setupViews() {
        contentView.addSubview(containerView)
        containerView.addSubview(coverImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(authorLabel)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            coverImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            coverImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            coverImageView.heightAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1.4),

            titleLabel.topAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: AppSpacing.small),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: AppSpacing.small),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -AppSpacing.small),

            authorLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppSpacing.tiny),
            authorLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: AppSpacing.small),
            authorLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -AppSpacing.small),
            authorLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -AppSpacing.small)
        ])
    }

    private func setupShadow() {
        layer.shadowColor = AppColors.shadow.cgColor
        layer.shadowOpacity = AppSpacing.shadowOpacity
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = AppSpacing.shadowRadius
        layer.masksToBounds = false
    }

    // MARK: - Configuration

    func configure(with comic: Comic) {
        titleLabel.text = comic.title
        authorLabel.text = comic.author ?? "Unknown Author"
        coverImageView.image = nil

        if let coverURL = comic.coverURL {
            ImageCache.shared.loadImage(from: coverURL) { [weak self] image in
                DispatchQueue.main.async {
                    self?.coverImageView.image = image
                }
            }
        }
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        coverImageView.image = nil
        titleLabel.text = nil
        authorLabel.text = nil
    }
}
