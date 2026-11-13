import UIKit

class ChapterCell: UITableViewCell {

    static let reuseIdentifier = "ChapterCell"

    // MARK: - UI Elements

    private let chapterNumberLabel: UILabel = {
        let label = UILabel()
        label.font = AppFonts.bold(size: 14)
        label.textColor = AppColors.primary
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    private let chapterTitleLabel: UILabel = {
        let label = UILabel()
        label.font = AppFonts.medium(size: 14)
        label.textColor = AppColors.textPrimary
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let languageLabel: UILabel = {
        let label = UILabel()
        label.font = AppFonts.caption
        label.textColor = AppColors.cardBackground
        label.backgroundColor = AppColors.primary
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = AppFonts.small
        label.textColor = AppColors.textSecondary
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let separatorLine: UIView = {
        let view = UIView()
        view.backgroundColor = AppColors.lightGray
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupViews()
    }

    // MARK: - Setup

    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(chapterNumberLabel)
        contentView.addSubview(chapterTitleLabel)
        contentView.addSubview(languageLabel)
        contentView.addSubview(dateLabel)
        contentView.addSubview(separatorLine)

        NSLayoutConstraint.activate([
            chapterNumberLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.standard),
            chapterNumberLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chapterNumberLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),

            languageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.standard),
            languageLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppSpacing.medium),
            languageLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 28),
            languageLabel.heightAnchor.constraint(equalToConstant: 20),

            chapterTitleLabel.leadingAnchor.constraint(equalTo: chapterNumberLabel.trailingAnchor, constant: AppSpacing.small),
            chapterTitleLabel.trailingAnchor.constraint(equalTo: languageLabel.leadingAnchor, constant: -AppSpacing.small),
            chapterTitleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppSpacing.medium),

            dateLabel.leadingAnchor.constraint(equalTo: chapterNumberLabel.trailingAnchor, constant: AppSpacing.small),
            dateLabel.topAnchor.constraint(equalTo: chapterTitleLabel.bottomAnchor, constant: AppSpacing.tiny),
            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppSpacing.medium),

            separatorLine.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.standard),
            separatorLine.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separatorLine.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    // MARK: - Configuration

    func configure(with chapter: Chapter) {
        if let chapterNum = chapter.chapter {
            chapterNumberLabel.text = "Ch. \(chapterNum)"
        } else {
            chapterNumberLabel.text = "Ch. -"
        }

        chapterTitleLabel.text = chapter.title ?? "No Title"

        let lang = chapter.translatedLanguage ?? "?"
        languageLabel.text = " \(lang.uppercased()) "

        if let date = chapter.publishDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            dateLabel.text = formatter.string(from: date)
        } else {
            dateLabel.text = ""
        }
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        chapterNumberLabel.text = nil
        chapterTitleLabel.text = nil
        languageLabel.text = nil
        dateLabel.text = nil
    }
}
