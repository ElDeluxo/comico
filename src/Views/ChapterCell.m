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
        
        UIView *selectedBg = [[UIView alloc] init];
        selectedBg.backgroundColor = [UIColor colorWithRed:0.22 green:0.22 blue:0.28 alpha:1.0];
        self.selectedBackgroundView = selectedBg;
        
        _langBadge = [[UILabel alloc] init];
        _langBadge.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:1.0];
        _langBadge.textColor = [UIColor whiteColor];
        _langBadge.font = [UIFont boldSystemFontOfSize:11.0];
        _langBadge.textAlignment = NSTextAlignmentCenter;
        _langBadge.layer.cornerRadius = 4.0;
        _langBadge.layer.masksToBounds = YES;
        [self.contentView addSubview:_langBadge];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.font = [UIFont boldSystemFontOfSize:14.5];
        _titleLabel.numberOfLines = 1;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_titleLabel];
        
        _subLabel = [[UILabel alloc] init];
        _subLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        _subLabel.font = [UIFont systemFontOfSize:12.0];
        _subLabel.numberOfLines = 1;
        [self.contentView addSubview:_subLabel];
        
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat contentW = self.contentView.bounds.size.width;
    CGFloat contentH = self.contentView.bounds.size.height;
    if (contentH <= 0) contentH = 60.0;
    
    // Badge de idioma a la izquierda centrado verticalmente
    CGFloat badgeW = 34.0;
    CGFloat badgeH = 20.0;
    CGFloat badgeX = 14.0;
    CGFloat badgeY = floorf((contentH - badgeH) / 2.0);
    self.langBadge.frame = CGRectMake(badgeX, badgeY, badgeW, badgeH);
    
    // Título y subtítulo calculados manualmente sin AutoLayout
    CGFloat textX = badgeX + badgeW + 10.0;
    CGFloat textW = contentW - textX - 10.0;
    if (textW < 50) textW = 50;
    
    self.titleLabel.frame = CGRectMake(textX, 10.0, textW, 20.0);
    self.subLabel.frame = CGRectMake(textX, 32.0, textW, 16.0);
}

- (void)configureWithChapter:(Chapter *)chapter {
    self.titleLabel.text = chapter.title.length > 0 ? chapter.title : [NSString stringWithFormat:@"Capítulo %@", chapter.chapterNumber ?: @""];
    self.langBadge.text = [chapter.language uppercaseString] ?: @"ES";
    if ([chapter.language isEqualToString:@"es"] || [chapter.language isEqualToString:@"es-la"]) {
        self.langBadge.backgroundColor = [UIColor colorWithRed:0.85 green:0.35 blue:0.3 alpha:1.0];
    } else {
        self.langBadge.backgroundColor = [UIColor colorWithRed:0.25 green:0.5 blue:0.85 alpha:1.0];
    }
    
    if (chapter.pagesCount > 0) {
        self.subLabel.text = [NSString stringWithFormat:@"Capítulo %@ • %ld páginas", chapter.chapterNumber ?: @"", (long)chapter.pagesCount];
    } else {
        self.subLabel.text = [NSString stringWithFormat:@"Capítulo %@", chapter.chapterNumber ?: @""];
    }
}

@end
