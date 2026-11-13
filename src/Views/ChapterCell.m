#import "ChapterCell.h"

@interface ChapterCell ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subLabel;
@property (nonatomic, strong) UILabel *langBadge;
@end

@implementation ChapterCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.16 alpha:1.0];
        self.selectionStyle = UITableViewCellSelectionStyleGray;
        
        _langBadge = [[UILabel alloc] init];
        _langBadge.translatesAutoresizingMaskIntoConstraints = NO;
        _langBadge.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:1.0];
        _langBadge.textColor = [UIColor whiteColor];
        _langBadge.font = [UIFont boldSystemFontOfSize:11.0];
        _langBadge.textAlignment = NSTextAlignmentCenter;
        _langBadge.layer.cornerRadius = 4.0;
        _langBadge.layer.masksToBounds = YES;
        [self.contentView addSubview:_langBadge];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
        _titleLabel.numberOfLines = 1;
        [self.contentView addSubview:_titleLabel];
        
        _subLabel = [[UILabel alloc] init];
        _subLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        _subLabel.font = [UIFont systemFontOfSize:12.0];
        [self.contentView addSubview:_subLabel];
        
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        [NSLayoutConstraint activateConstraints:@[
            [_langBadge.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:14],
            [_langBadge.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_langBadge.widthAnchor constraintEqualToConstant:32],
            [_langBadge.heightAnchor constraintEqualToConstant:20],
            
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_langBadge.trailingAnchor constant:10],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-10],
            [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            
            [_subLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_subLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
            [_subLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:3],
            [_subLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10]
        ]];
    }
    return self;
}

- (void)configureWithChapter:(Chapter *)chapter {
    self.titleLabel.text = chapter.title;
    self.langBadge.text = [chapter.language uppercaseString] ?: @"ES";
    if ([chapter.language isEqualToString:@"es"] || [chapter.language isEqualToString:@"es-la"]) {
        self.langBadge.backgroundColor = [UIColor colorWithRed:0.85 green:0.35 blue:0.3 alpha:1.0];
    } else {
        self.langBadge.backgroundColor = [UIColor colorWithRed:0.25 green:0.5 blue:0.85 alpha:1.0];
    }
    
    if (chapter.pagesCount > 0) {
        self.subLabel.text = [NSString stringWithFormat:@"Capítulo %@ • %ld páginas", chapter.chapterNumber, (long)chapter.pagesCount];
    } else {
        self.subLabel.text = [NSString stringWithFormat:@"Capítulo %@", chapter.chapterNumber];
    }
}

@end
