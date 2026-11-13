#import "DebugViewController.h"
#import "TLSHTTPClient.h"
#import <mach/mach.h>

NSString * const ComicoLogNotification = @"ComicoLogNotification";
NSString * const ComicoLogMessageKey = @"ComicoLogMessageKey";

static NSMutableArray<NSString *> *s_logHistory = nil;

void ComicoLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"HH:mm:ss.SSS"];
    NSString *timestamp = [df stringFromDate:[NSDate date]];
    NSString *entry = [NSString stringWithFormat:@"[%@] %@", timestamp, msg];
    
    NSLog(@"%@", entry);
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_logHistory = [NSMutableArray array];
    });
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [s_logHistory addObject:entry];
        if (s_logHistory.count > 200) {
            [s_logHistory removeObjectAtIndex:0];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:ComicoLogNotification
                                                            object:nil
                                                          userInfo:@{ComicoLogMessageKey: entry}];
    });
}

static double get_app_memory_mb(void) {
    mach_task_basic_info_data_t info;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count) == KERN_SUCCESS) {
        return info.resident_size / (1024.0 * 1024.0);
    }
    return 0.0;
}

@interface DebugViewController ()

@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *ramLabel;
@property (nonatomic, strong) UITextView *consoleView;
@property (nonatomic, strong) NSTimer *ramTimer;

@end

@implementation DebugViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Diagnóstico";
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:1.0];
    
    CGFloat topY = 70.0;
    CGFloat width = self.view.bounds.size.width;
    
    // Panel superior de estado
    UIView *statusPanel = [[UIView alloc] initWithFrame:CGRectMake(12, topY, width - 24, 76)];
    statusPanel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    statusPanel.backgroundColor = [UIColor colorWithRed:0.14 green:0.14 blue:0.18 alpha:1.0];
    statusPanel.layer.cornerRadius = 8.0;
    statusPanel.layer.masksToBounds = YES;
    [self.view addSubview:statusPanel];
    
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 10, statusPanel.bounds.size.width - 24, 24)];
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.statusLabel.textColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.4 alpha:1.0];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:14.0];
    self.statusLabel.text = @"● Conexión: Comprobando red...";
    [statusPanel addSubview:self.statusLabel];
    
    self.ramLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 40, statusPanel.bounds.size.width - 24, 24)];
    self.ramLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.ramLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    self.ramLabel.font = [UIFont systemFontOfSize:13.0];
    self.ramLabel.text = @"RAM en uso: Calculando...";
    [statusPanel addSubview:self.ramLabel];
    
    // Botones de prueba y control
    CGFloat btnY = topY + 86;
    CGFloat btnW = (width - 36) / 3.0;
    
    UIButton *btnTestMD = [self makeButtonWithTitle:@"Test MangaDex" frame:CGRectMake(12, btnY, btnW, 36) action:@selector(testMangaDex)];
    UIButton *btnTestIA = [self makeButtonWithTitle:@"Test Comics" frame:CGRectMake(12 + btnW + 6, btnY, btnW, 36) action:@selector(testInternetArchive)];
    UIButton *btnClear = [self makeButtonWithTitle:@"Limpiar Log" frame:CGRectMake(12 + (btnW + 6) * 2, btnY, btnW, 36) action:@selector(clearConsole)];
    
    [self.view addSubview:btnTestMD];
    [self.view addSubview:btnTestIA];
    [self.view addSubview:btnClear];
    
    // Consola de texto oscura
    CGFloat consoleY = btnY + 44;
    CGFloat consoleH = self.view.bounds.size.height - consoleY - 56;
    self.consoleView = [[UITextView alloc] initWithFrame:CGRectMake(12, consoleY, width - 24, consoleH)];
    self.consoleView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.consoleView.backgroundColor = [UIColor blackColor];
    self.consoleView.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.4 alpha:1.0];
    self.consoleView.font = [UIFont fontWithName:@"Courier" size:12.0] ?: [UIFont systemFontOfSize:12.0];
    self.consoleView.editable = NO;
    self.consoleView.layer.cornerRadius = 6.0;
    self.consoleView.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1.0].CGColor;
    self.consoleView.layer.borderWidth = 1.0;
    [self.view addSubview:self.consoleView];
    
    // Cargar historial
    if (s_logHistory.count > 0) {
        self.consoleView.text = [s_logHistory componentsJoinedByString:@"\n"];
    } else {
        self.consoleView.text = @"[Diagnóstico] Consola de procesos y red iniciada...\n";
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleLogNotification:)
                                                 name:ComicoLogNotification
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateRAMUsage];
    self.ramTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(updateRAMUsage) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.ramTimer invalidate];
    self.ramTimer = nil;
}

- (UIButton *)makeButtonWithTitle:(NSString *)title frame:(CGRect)frame action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = frame;
    btn.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
    btn.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.26 alpha:1.0];
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:12.0];
    btn.layer.cornerRadius = 6.0;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)updateRAMUsage {
    double ramMB = get_app_memory_mb();
    self.ramLabel.text = [NSString stringWithFormat:@"RAM de la App: %.1f MB (Límite seguro: 150 MB)", ramMB];
    if (ramMB > 120.0) {
        self.ramLabel.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.3 alpha:1.0];
    } else {
        self.ramLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    }
}

- (void)handleLogNotification:(NSNotification *)note {
    NSString *entry = note.userInfo[ComicoLogMessageKey];
    if (entry) {
        NSString *curr = self.consoleView.text ?: @"";
        self.consoleView.text = [curr stringByAppendingFormat:@"\n%@", entry];
        
        // Auto scroll
        if (self.consoleView.text.length > 0) {
            NSRange bottom = NSMakeRange(self.consoleView.text.length - 1, 1);
            [self.consoleView scrollRangeToVisible:bottom];
        }
    }
}

- (void)clearConsole {
    [s_logHistory removeAllObjects];
    self.consoleView.text = @"[Diagnóstico] Consola limpiada.\n";
}

- (void)testMangaDex {
    ComicoLog(@"--- PROBANDO CONEXIÓN MANGADEX (TLS 1.3) ---");
    self.statusLabel.text = @"● Conectando a MangaDex...";
    self.statusLabel.textColor = [UIColor colorWithRed:0.9 green:0.8 blue:0.2 alpha:1.0];
    
    NSURL *url = [NSURL URLWithString:@"https://api.mangadex.org/ping"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setValue:@"Comico/1.0" forHTTPHeaderField:@"User-Agent"];
    
    NSTimeInterval t0 = [NSDate timeIntervalSinceReferenceDate];
    [[TLSHTTPClient sharedClient] performRequest:req completion:^(NSData *d, NSHTTPURLResponse *r, NSError *e) {
        NSTimeInterval elapsed = ([NSDate timeIntervalSinceReferenceDate] - t0) * 1000.0;
        if (e) {
            ComicoLog(@"❌ MangaDex Falló: %@ (Tiempo: %.0f ms)", e.localizedDescription, elapsed);
            self.statusLabel.text = @"● Error: Sin conexión a MangaDex";
            self.statusLabel.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
        } else {
            NSString *body = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
            ComicoLog(@"✅ MangaDex OK: Código %ld, Respuesta: '%@' (Tiempo: %.0f ms)", (long)r.statusCode, body, elapsed);
            self.statusLabel.text = @"● MangaDex: Conectado (TLS 1.3 Activo)";
            self.statusLabel.textColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.4 alpha:1.0];
        }
    }];
}

- (void)testInternetArchive {
    ComicoLog(@"--- PROBANDO CONEXIÓN INTERNET ARCHIVE (CÓMICS) ---");
    self.statusLabel.text = @"● Conectando a Internet Archive...";
    self.statusLabel.textColor = [UIColor colorWithRed:0.9 green:0.8 blue:0.2 alpha:1.0];
    
    NSURL *url = [NSURL URLWithString:@"https://archive.org/advancedsearch.php?q=watchmen&output=json&rows=1"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setValue:@"Comico/1.0" forHTTPHeaderField:@"User-Agent"];
    
    NSTimeInterval t0 = [NSDate timeIntervalSinceReferenceDate];
    [[TLSHTTPClient sharedClient] performRequest:req completion:^(NSData *d, NSHTTPURLResponse *r, NSError *e) {
        NSTimeInterval elapsed = ([NSDate timeIntervalSinceReferenceDate] - t0) * 1000.0;
        if (e) {
            ComicoLog(@"❌ Internet Archive Falló: %@ (Tiempo: %.0f ms)", e.localizedDescription, elapsed);
            self.statusLabel.text = @"● Error: Sin conexión a Internet Archive";
            self.statusLabel.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
        } else {
            ComicoLog(@"✅ Internet Archive OK: Código %ld, Bytes: %lu (Tiempo: %.0f ms)", (long)r.statusCode, (unsigned long)d.length, elapsed);
            self.statusLabel.text = @"● Internet Archive: Conectado";
            self.statusLabel.textColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.4 alpha:1.0];
        }
    }];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
