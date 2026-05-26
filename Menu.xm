// Menu.xm
#include <substrate.h>
#include <UIKit/UIKit.h>
#include "Header.h"
#include "Logger.h"


// Declare external functions
extern void SetFOV(float);
extern void ResetFOV();
extern float selectedFOV;


// ---------------- MenuController ----------------
@interface MenuController : NSObject
+ (void)openMenu:(id)sender;
+ (void)closeMenu:(id)sender;
+ (void)selectFOV:(UISegmentedControl *)sender;
+ (void)resetFOV:(id)sender;
+ (void)toggleESPLine2:(id)sender;
+ (void)toggleESPBoxes:(id)sender;
+ (void)toggleESPIcons:(id)sender;
+ (void)toggleESPHealth:(id)sender;
+ (void)toggleAllEntityHP:(id)sender;
+ (void)toggleMonstersHP:(id)sender;
+ (void)toggleESPMonsterIcons:(id)sender;
+ (void)toggleAllESP:(id)sender;
+ (void)handlePan:(UIPanGestureRecognizer *)gesture;
+ (void)handleButtonPan:(UIPanGestureRecognizer *)gesture;
+ (void)switchCategory:(UISegmentedControl *)sender;
+ (void)animateFloatingButton;
@end

// ====================== CONFIG SAVE & LOAD (Auto) ======================
static NSString *const kConfigFileName = @"ModConfig.plist";

NSString *GetConfigPath() {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = [paths firstObject];
    return [documentsDir stringByAppendingPathComponent:kConfigFileName];
}

void SaveConfig() {
    NSMutableDictionary *config = [NSMutableDictionary dictionary];
    
    [config setObject:@(showESPLine2) forKey:@"showESPLine2"];
    [config setObject:@(showESPBoxes) forKey:@"showESPBoxes"];
    [config setObject:@(showESPIcons) forKey:@"showESPIcons"];
    [config setObject:@(showESPHealth) forKey:@"showESPHealth"];
    [config setObject:@(showAllEntityHP) forKey:@"showAllEntityHP"];
    [config setObject:@(showMonstersHP) forKey:@"showMonstersHP"];
    [config setObject:@(showESPMonsterIcons) forKey:@"showESPMonsterIcons"];
    [config setObject:@(showAllESP) forKey:@"showAllESP"];
    [config setObject:@(updateInterval) forKey:@"updateInterval"];
    [config setObject:@(selectedFOV) forKey:@"selectedFOV"];
    
    NSString *path = GetConfigPath();
    [config writeToFile:path atomically:YES];
    NSLog(@"[Config] Auto Saved Successfully");
}

void LoadConfig() {
    NSString *path = GetConfigPath();
    NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:path];
    
    if (!config) return;
    
    if ([config objectForKey:@"showESPLine2"]) showESPLine2 = [[config objectForKey:@"showESPLine2"] boolValue];
    if ([config objectForKey:@"showESPBoxes"]) showESPBoxes = [[config objectForKey:@"showESPBoxes"] boolValue];
    if ([config objectForKey:@"showESPIcons"]) showESPIcons = [[config objectForKey:@"showESPIcons"] boolValue];
    if ([config objectForKey:@"showESPHealth"]) showESPHealth = [[config objectForKey:@"showESPHealth"] boolValue];
    if ([config objectForKey:@"showAllEntityHP"]) showAllEntityHP = [[config objectForKey:@"showAllEntityHP"] boolValue];
    if ([config objectForKey:@"showMonstersHP"]) showMonstersHP = [[config objectForKey:@"showMonstersHP"] boolValue];
    if ([config objectForKey:@"showESPMonsterIcons"]) showESPMonsterIcons = [[config objectForKey:@"showESPMonsterIcons"] boolValue];
    if ([config objectForKey:@"showAllESP"]) showAllESP = [[config objectForKey:@"showAllESP"] boolValue];
    if ([config objectForKey:@"updateInterval"]) updateInterval = [[config objectForKey:@"updateInterval"] intValue];
    if ([config objectForKey:@"selectedFOV"]) selectedFOV = [[config objectForKey:@"selectedFOV"] floatValue];
    
    NSLog(@"[Config] Auto Loaded Successfully");
}



@implementation MenuController
+ (void)openMenu:(id)sender {
    NSLog(@"[MenuController] openMenu called");
    if (menuView) { 
        menuView.alpha = 1.0; 
        if (floatingButton) floatingButton.alpha = 0.0; 
    }
}


+ (void)closeMenu:(id)sender {
    NSLog(@"[MenuController] closeMenu called");
    if (menuView) { 
        menuView.alpha = 0.0; 
        if (floatingButton) floatingButton.alpha = 1.0; 
    }
	SaveConfig();
}
+ (void)selectFOV:(UISegmentedControl *)sender {
    extern const float fovOptions[];
    float fovValue = fovOptions[sender.selectedSegmentIndex];
    SetFOV(fovValue);
}
+ (void)resetFOV:(id)sender {
    ResetFOV();
}
+ (void)toggleESPLine2:(id)sender {
    showESPLine2 = !showESPLine2;
    if (espLine2StatusLabel) {
        espLine2StatusLabel.text = @"ESP Line";
    }
    if (sender && [sender isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)sender;
        [button setTitle:showESPLine2 ? @"✓" : @"" forState:UIControlStateNormal];
    }
    if (espLine2View) espLine2View.hidden = !showESPLine2;
}
+ (void)toggleESPBoxes:(id)sender {
    showESPBoxes = !showESPBoxes;
    if (espBoxStatusLabel) {
        espBoxStatusLabel.text = @"ESP Boxes";
    }
    if (sender && [sender isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)sender;
        [button setTitle:showESPBoxes ? @"✓" : @"" forState:UIControlStateNormal];
    }
    if (espBoxView) espBoxView.hidden = !showESPBoxes;
}
+ (void)toggleESPIcons:(id)sender {
    showESPIcons = !showESPIcons;
    if (espIconStatusLabel) {
        espIconStatusLabel.text = @"Hero Icons";
    }
    if (sender && [sender isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)sender;
        [button setTitle:showESPIcons ? @"✓" : @"" forState:UIControlStateNormal];
    }
    if (espIconView) espIconView.hidden = !showESPIcons && !showESPMonsterIcons;
}
+ (void)toggleESPMonsterIcons:(id)sender {
    showESPMonsterIcons = !showESPMonsterIcons;
    if (espMonsterIconStatusLabel) {
        espMonsterIconStatusLabel.text = @"Monster Icons";
    }
    if (sender && [sender isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)sender;
        [button setTitle:showESPMonsterIcons ? @"✓" : @"" forState:UIControlStateNormal];
    }
    if (espIconView) espIconView.hidden = !showESPIcons && !showESPMonsterIcons;
}
+ (void)toggleESPHealth:(id)sender {
    showESPHealth = !showESPHealth;
    if (espHealthStatusLabel) {
        espHealthStatusLabel.text = @"Health Bar";
    }
    if (sender && [sender isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)sender;
        [button setTitle:showESPHealth ? @"✓" : @"" forState:UIControlStateNormal];
    }
    if (espHealthView) espHealthView.hidden = !showESPHealth && !showAllEntityHP && !showMonstersHP;
}
+ (void)toggleAllEntityHP:(id)sender {
    showAllEntityHP = !showAllEntityHP;
    if (espAllEntityHPStatusLabel) {
        espAllEntityHPStatusLabel.text = @"All Players HP";
    }
    if (sender && [sender isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)sender;
        [button setTitle:showAllEntityHP ? @"✓" : @"" forState:UIControlStateNormal];
    }
    if (espHealthView) espHealthView.hidden = !showESPHealth && !showAllEntityHP && !showMonstersHP;
}
+ (void)toggleMonstersHP:(id)sender {
    showMonstersHP = !showMonstersHP;
    if (espMonstersHPStatusLabel) {
        espMonstersHPStatusLabel.text = @"Monsters HP";
    }
    if (sender && [sender isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)sender;
        [button setTitle:showMonstersHP ? @"✓" : @"" forState:UIControlStateNormal];
    }
    if (espHealthView) espHealthView.hidden = !showESPHealth && !showAllEntityHP && !showMonstersHP;
}
+ (void)toggleAllESP:(id)sender {
    showAllESP = !showAllESP;
    if (showAllESP) {
        showESPLine2 = YES;
        showESPBoxes = YES;
        showESPIcons = YES;
        showESPHealth = YES;
        showAllEntityHP = YES;
        showMonstersHP = YES;
        showESPMonsterIcons = YES;
        if (espLine2View) espLine2View.hidden = NO;
        if (espBoxView) espBoxView.hidden = NO;
        if (espIconView) espIconView.hidden = NO;
        if (espHealthView) espHealthView.hidden = NO;
    } else {
        showESPLine2 = NO;
        showESPBoxes = NO;
        showESPIcons = NO;
        showESPHealth = NO;
        showAllEntityHP = NO;
        showMonstersHP = NO;
        showESPMonsterIcons = NO;
        if (espLine2View) espLine2View.hidden = YES;
        if (espBoxView) espBoxView.hidden = YES;
        if (espIconView) espIconView.hidden = YES;
        if (espHealthView) espHealthView.hidden = YES;
    }
    if (espAllStatusLabel) {
        espAllStatusLabel.text = @"Enable All";
    }
    if (sender && [sender isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)sender;
        [button setTitle:showAllESP ? @"✓" : @"" forState:UIControlStateNormal];
    }
}

+ (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (!menuView) return;
    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    if (!window) return;
    CGPoint translation = [gesture translationInView:window];
    CGPoint newCenter = CGPointMake(menuView.center.x + translation.x, menuView.center.y + translation.y);
    CGFloat minX = menuView.frame.size.width / 2;
    CGFloat maxX = window.frame.size.width - menuView.frame.size.width / 2;
    CGFloat minY = menuView.frame.size.height / 2;
    CGFloat maxY = window.frame.size.height - menuView.frame.size.height / 2;
    newCenter.x = fmax(minX, fmin(maxX, newCenter.x));
    newCenter.y = fmax(minY, fmin(maxY, newCenter.y));
    menuView.center = newCenter;
    [gesture setTranslation:CGPointZero inView:window];
    NSLog(@"[MenuController] Menu panned to: %@", NSStringFromCGPoint(newCenter));
}
+ (void)handleButtonPan:(UIPanGestureRecognizer *)gesture {
    if (!floatingButton) return;
    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    if (!window) return;
    CGPoint translation = [gesture translationInView:window];
    CGPoint newCenter = CGPointMake(floatingButton.center.x + translation.x, floatingButton.center.y + translation.y);
    CGFloat minX = floatingButton.frame.size.width / 2;
    CGFloat maxX = window.frame.size.width - floatingButton.frame.size.width / 2;
    CGFloat minY = floatingButton.frame.size.height / 2;
    CGFloat maxY = window.frame.size.height - floatingButton.frame.size.height / 2;
    newCenter.x = fmax(minX, fmin(maxX, newCenter.x));
    newCenter.y = fmax(minY, fmin(maxY, newCenter.y));
    floatingButton.center = newCenter;
    [gesture setTranslation:CGPointZero inView:window];
    NSLog(@"[MenuController] Button panned to: %@", NSStringFromCGPoint(newCenter));
}
+ (void)switchCategory:(UISegmentedControl *)sender {
    generalView.hidden = YES;
    miniMapView.hidden = YES;
    fovView.hidden = YES;
    
    switch (sender.selectedSegmentIndex) {
        case 0: generalView.hidden = NO; break;
        case 1: miniMapView.hidden = NO; break;
        case 2: fovView.hidden = NO; break;
        default: break;
    }
}
+ (void)animateFloatingButton {
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"backgroundColor"];
    animation.fromValue = (id)[UIColor colorWithRed:0.95 green:0.71 blue:0.82 alpha:0.95].CGColor;
    animation.toValue = (id)[UIColor colorWithRed:1.0 green:0.84 blue:0.0 alpha:0.95].CGColor;
    animation.duration = 0.2;
    animation.autoreverses = YES;
    animation.repeatCount = HUGE_VALF;
    animation.removedOnCompletion = NO;
    [floatingButton.layer addAnimation:animation forKey:@"blink"];
}
@end

// ---------------- ثوابت الألوان (لسهولة التعديل) ----------------
static UIColor * const kPinkSoft       = [UIColor colorWithRed:0.95 green:0.71 blue:0.82 alpha:0.97];
static UIColor * const kPinkMedium     = [UIColor colorWithRed:0.80 green:0.55 blue:0.71 alpha:1.00];
static UIColor * const kPinkDark       = [UIColor colorWithRed:0.55 green:0.27 blue:0.44 alpha:1.00];
static UIColor * const kBgVeryLight    = [UIColor colorWithRed:0.96 green:0.88 blue:0.92 alpha:0.96];
static UIColor * const kBgLightOverlay = [UIColor colorWithRed:0.98 green:0.90 blue:0.94 alpha:0.35];

// ---------------- UI Creation ----------------
void CreateUI() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *mainWindow = [UIApplication sharedApplication].windows.firstObject;
        if (!mainWindow) {
            NSLog(@"[MenuController] Error: No main window found!");
            return;
        }
        
        if (floatingButton || menuView) {
            NSLog(@"[MenuController] UI already created, skipping...");
            return;
        }
        
    // ───────────────────────────────
// Floating Button (24×24) - تصميم عصري 2026
// ───────────────────────────────
floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
floatingButton.frame = CGRectMake(30, 60, 24, 24);
floatingButton.backgroundColor = kPinkSoft;

// تصميم عصري: زوايا ناعمة + تأثير Glassmorphism
floatingButton.layer.cornerRadius = 12;
floatingButton.layer.masksToBounds = NO;

// Shadow عصري
floatingButton.layer.shadowColor = [UIColor blackColor].CGColor;
floatingButton.layer.shadowOffset = CGSizeMake(0, 3);
floatingButton.layer.shadowOpacity = 0.35;
floatingButton.layer.shadowRadius = 8;

// Border رقيق ولامع
floatingButton.layer.borderWidth = 1.8;
floatingButton.layer.borderColor = [kPinkMedium colorWithAlphaComponent:0.6].CGColor;

// Gradient داخلي (تم تغيير الاسم لتجنب التعارض)
CAGradientLayer *buttonGradient = [CAGradientLayer layer];
buttonGradient.frame = floatingButton.bounds;
buttonGradient.colors = @[(id)[kPinkSoft colorWithAlphaComponent:0.95].CGColor,
                          (id)[kPinkMedium colorWithAlphaComponent:0.85].CGColor];
buttonGradient.cornerRadius = 12;
[floatingButton.layer insertSublayer:buttonGradient atIndex:0];

UILabel *lbl = [[UILabel alloc] initWithFrame:floatingButton.bounds];
lbl.text = @"M";
lbl.textAlignment = NSTextAlignmentCenter;
lbl.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightSemibold];
lbl.textColor = [UIColor whiteColor];
lbl.shadowColor = [UIColor blackColor];
lbl.shadowOffset = CGSizeMake(0, 1);
lbl.adjustsFontSizeToFitWidth = YES;
lbl.minimumScaleFactor = 0.7;
lbl.userInteractionEnabled = NO;
[floatingButton addSubview:lbl];

// Action
[floatingButton addTarget:[MenuController class] action:@selector(openMenu:) 
         forControlEvents:UIControlEventTouchUpInside];

// Pan Gesture
UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:[MenuController class] 
                                                                          action:@selector(handleButtonPan:)];
[floatingButton addGestureRecognizer:panGesture];

// طبقة عالية
floatingButton.layer.zPosition = 2000;

[mainWindow addSubview:floatingButton];
[mainWindow bringSubviewToFront:floatingButton];

// أنيميشن
[MenuController animateFloatingButton];

NSLog(@"[MenuController] Modern Floating Button 24x24 created");

  // ───────────────────────────────
// Menu View (القائمة الرئيسية) - تصميم كرتوني جميل
// ───────────────────────────────
CGFloat menuW = 360;
CGFloat menuH = 520;

menuView = [[UIScrollView alloc] initWithFrame:CGRectMake(30, 90, menuW, menuH)];
menuView.backgroundColor = [UIColor colorWithRed:0.98 green:0.93 blue:0.97 alpha:0.98];
menuView.layer.cornerRadius = 26;
menuView.clipsToBounds = YES;
menuView.layer.masksToBounds = NO;

menuView.layer.shadowColor = [UIColor blackColor].CGColor;
menuView.layer.shadowOffset = CGSizeMake(0, 10);
menuView.layer.shadowOpacity = 0.22;
menuView.layer.shadowRadius = 18;

menuView.layer.borderWidth = 3.5;
menuView.layer.borderColor = [kPinkMedium colorWithAlphaComponent:0.65].CGColor;

menuView.alpha = 0.0;
menuView.contentSize = CGSizeMake(menuW, 780);
menuView.layer.zPosition = 1500;
menuView.showsVerticalScrollIndicator = YES;

// ───────────────────────────────
// Title Bar
// ───────────────────────────────
UIView *titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, menuW, 58)];

CAGradientLayer *gradient = [CAGradientLayer layer];
gradient.frame = titleBar.bounds;
gradient.colors = @[(id)[UIColor colorWithRed:1.0 green:0.75 blue:0.88 alpha:1.0].CGColor,
                    (id)[UIColor colorWithRed:0.96 green:0.55 blue:0.82 alpha:1.0].CGColor];
gradient.startPoint = CGPointMake(0, 0);
gradient.endPoint = CGPointMake(1, 1);
[titleBar.layer insertSublayer:gradient atIndex:0];

UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(45, 12, menuW-110, 34)];
title.text = @"✨ Mod Menu ✨";
title.textColor = [UIColor whiteColor];
title.textAlignment = NSTextAlignmentCenter;
title.font = [UIFont systemFontOfSize:21.5 weight:UIFontWeightBold];
[titleBar addSubview:title];

UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
closeBtn.frame = CGRectMake(menuW-50, 12, 38, 38);
[closeBtn setTitle:@"✕" forState:UIControlStateNormal];
[closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
closeBtn.titleLabel.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBold];
closeBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.35 blue:0.45 alpha:0.95];
closeBtn.layer.cornerRadius = 19;
[closeBtn addTarget:[MenuController class] action:@selector(closeMenu:) forControlEvents:UIControlEventTouchUpInside];
[titleBar addSubview:closeBtn];

UIPanGestureRecognizer *titlePan = [[UIPanGestureRecognizer alloc] initWithTarget:[MenuController class] action:@selector(handlePan:)];
[titleBar addGestureRecognizer:titlePan];
[menuView addSubview:titleBar];

// ───────────────────────────────
// Category Segmented Control
// ───────────────────────────────
UISegmentedControl *categoryControl = [[UISegmentedControl alloc] initWithItems:@[@"General", @"ESP", @"FOV"]];
categoryControl.frame = CGRectMake(12, 68, menuW-24, 38);
categoryControl.selectedSegmentIndex = 0;
[categoryControl addTarget:[MenuController class] action:@selector(switchCategory:) forControlEvents:UIControlEventValueChanged];
[categoryControl setTitleTextAttributes:@{
    NSFontAttributeName: [UIFont systemFontOfSize:14.5 weight:UIFontWeightSemibold],
    NSForegroundColorAttributeName: kPinkDark
} forState:UIControlStateNormal];
categoryControl.backgroundColor = [UIColor colorWithRed:0.97 green:0.90 blue:0.95 alpha:1.0];
categoryControl.selectedSegmentTintColor = kPinkMedium;
categoryControl.layer.cornerRadius = 12;
[menuView addSubview:categoryControl];

// ───────────────────────────────
// General View
// ───────────────────────────────
generalView = [[UIView alloc] initWithFrame:CGRectMake(0, 118, menuW, 110)];
generalView.backgroundColor = [UIColor clearColor];
[menuView addSubview:generalView];

enemyCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, menuW-24, 34)];
enemyCountLabel.text = @"Enemies Detected: 0";
enemyCountLabel.textColor = kPinkDark;
enemyCountLabel.textAlignment = NSTextAlignmentCenter;
enemyCountLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
enemyCountLabel.backgroundColor = [UIColor colorWithRed:1.0 green:0.96 blue:0.98 alpha:0.9];
enemyCountLabel.layer.cornerRadius = 12;
enemyCountLabel.clipsToBounds = YES;
[generalView addSubview:enemyCountLabel];

updateStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 52, menuW-24, 34)];
updateStatusLabel.text = @"Update: Idle";
updateStatusLabel.textColor = kPinkDark;
updateStatusLabel.textAlignment = NSTextAlignmentCenter;
updateStatusLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
updateStatusLabel.backgroundColor = [UIColor colorWithRed:1.0 green:0.96 blue:0.98 alpha:0.9];
updateStatusLabel.layer.cornerRadius = 12;
updateStatusLabel.clipsToBounds = YES;
[generalView addSubview:updateStatusLabel];

// ───────────────────────────────
// MiniMap / ESP View - كل الأزرار بالتفصيل
// ───────────────────────────────
miniMapView = [[UIView alloc] initWithFrame:CGRectMake(0, 118, menuW, 380)];
miniMapView.backgroundColor = [UIColor clearColor];
miniMapView.hidden = YES;
[menuView addSubview:miniMapView];

// Divider
UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(menuW/2, 18, 2, 340)];
divider.backgroundColor = [kPinkMedium colorWithAlphaComponent:0.3];
[miniMapView addSubview:divider];

// ─── Left Column ───
UIButton *espLine2Btn = [UIButton buttonWithType:UIButtonTypeCustom];
espLine2Btn.frame = CGRectMake(12, 20, 28, 28);
[espLine2Btn setTitle:showESPLine2 ? @"✅" : @"" forState:0];
[espLine2Btn setTitleColor:kPinkDark forState:0];
espLine2Btn.backgroundColor = [UIColor colorWithRed:0.97 green:0.90 blue:0.95 alpha:1.0];
espLine2Btn.layer.cornerRadius = 8;
espLine2Btn.layer.borderWidth = 1.5;
espLine2Btn.layer.borderColor = kPinkMedium.CGColor;
[espLine2Btn addTarget:[MenuController class] action:@selector(toggleESPLine2:) forControlEvents:UIControlEventTouchUpInside];
[miniMapView addSubview:espLine2Btn];

espLine2StatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(48, 20, 140, 28)];
espLine2StatusLabel.text = @"ESP Line";
espLine2StatusLabel.textColor = kPinkDark;
espLine2StatusLabel.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightMedium];
[miniMapView addSubview:espLine2StatusLabel];

// ESP Boxes
UIButton *espBoxBtn = [UIButton buttonWithType:UIButtonTypeCustom];
espBoxBtn.frame = CGRectMake(12, 65, 28, 28);
[espBoxBtn setTitle:showESPBoxes ? @"✅" : @"" forState:0];
[espBoxBtn setTitleColor:kPinkDark forState:0];
espBoxBtn.backgroundColor = [UIColor colorWithRed:0.97 green:0.90 blue:0.95 alpha:1.0];
espBoxBtn.layer.cornerRadius = 8;
espBoxBtn.layer.borderWidth = 1.5;
espBoxBtn.layer.borderColor = kPinkMedium.CGColor;
[espBoxBtn addTarget:[MenuController class] action:@selector(toggleESPBoxes:) forControlEvents:UIControlEventTouchUpInside];
[miniMapView addSubview:espBoxBtn];

espBoxStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(48, 65, 140, 28)];
espBoxStatusLabel.text = @"ESP Boxes";
espBoxStatusLabel.textColor = kPinkDark;
espBoxStatusLabel.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightMedium];
[miniMapView addSubview:espBoxStatusLabel];

// Hero Icons
UIButton *espIconBtn = [UIButton buttonWithType:UIButtonTypeCustom];
espIconBtn.frame = CGRectMake(12, 110, 28, 28);
[espIconBtn setTitle:showESPIcons ? @"✅" : @"" forState:0];
[espIconBtn setTitleColor:kPinkDark forState:0];
espIconBtn.backgroundColor = [UIColor colorWithRed:0.97 green:0.90 blue:0.95 alpha:1.0];
espIconBtn.layer.cornerRadius = 8;
espIconBtn.layer.borderWidth = 1.5;
espIconBtn.layer.borderColor = kPinkMedium.CGColor;
[espIconBtn addTarget:[MenuController class] action:@selector(toggleESPIcons:) forControlEvents:UIControlEventTouchUpInside];
[miniMapView addSubview:espIconBtn];

espIconStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(48, 110, 140, 28)];
espIconStatusLabel.text = @"Hero Icons";
espIconStatusLabel.textColor = kPinkDark;
espIconStatusLabel.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightMedium];
[miniMapView addSubview:espIconStatusLabel];

// Monster Icons
UIButton *espMonsterIconBtn = [UIButton buttonWithType:UIButtonTypeCustom];
espMonsterIconBtn.frame = CGRectMake(12, 155, 28, 28);
[espMonsterIconBtn setTitle:showESPMonsterIcons ? @"✅" : @"" forState:0];
[espMonsterIconBtn setTitleColor:kPinkDark forState:0];
espMonsterIconBtn.backgroundColor = [UIColor colorWithRed:0.97 green:0.90 blue:0.95 alpha:1.0];
espMonsterIconBtn.layer.cornerRadius = 8;
espMonsterIconBtn.layer.borderWidth = 1.5;
espMonsterIconBtn.layer.borderColor = kPinkMedium.CGColor;
[espMonsterIconBtn addTarget:[MenuController class] action:@selector(toggleESPMonsterIcons:) forControlEvents:UIControlEventTouchUpInside];
[miniMapView addSubview:espMonsterIconBtn];

espMonsterIconStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(48, 155, 140, 28)];
espMonsterIconStatusLabel.text = @"Monster Icons";
espMonsterIconStatusLabel.textColor = kPinkDark;
espMonsterIconStatusLabel.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightMedium];
[miniMapView addSubview:espMonsterIconStatusLabel];

// ─── Right Column ───
UIButton *espHealthBtn = [UIButton buttonWithType:UIButtonTypeCustom];
espHealthBtn.frame = CGRectMake(menuW-40, 20, 28, 28);
[espHealthBtn setTitle:showESPHealth ? @"✅" : @"" forState:0];
[espHealthBtn setTitleColor:kPinkDark forState:0];
espHealthBtn.backgroundColor = [UIColor colorWithRed:0.97 green:0.90 blue:0.95 alpha:1.0];
espHealthBtn.layer.cornerRadius = 8;
espHealthBtn.layer.borderWidth = 1.5;
espHealthBtn.layer.borderColor = kPinkMedium.CGColor;
[espHealthBtn addTarget:[MenuController class] action:@selector(toggleESPHealth:) forControlEvents:UIControlEventTouchUpInside];
[miniMapView addSubview:espHealthBtn];

espHealthStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(menuW/2+6, 20, 140, 28)];
espHealthStatusLabel.text = @"Health Bar";
espHealthStatusLabel.textColor = kPinkDark;
espHealthStatusLabel.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightMedium];
espHealthStatusLabel.textAlignment = NSTextAlignmentRight;
[miniMapView addSubview:espHealthStatusLabel];

// All Players HP
UIButton *espAllEntityHPBtn = [UIButton buttonWithType:UIButtonTypeCustom];
espAllEntityHPBtn.frame = CGRectMake(menuW-40, 65, 28, 28);
[espAllEntityHPBtn setTitle:showAllEntityHP ? @"✅" : @"" forState:0];
[espAllEntityHPBtn setTitleColor:kPinkDark forState:0];
espAllEntityHPBtn.backgroundColor = [UIColor colorWithRed:0.97 green:0.90 blue:0.95 alpha:1.0];
espAllEntityHPBtn.layer.cornerRadius = 8;
espAllEntityHPBtn.layer.borderWidth = 1.5;
espAllEntityHPBtn.layer.borderColor = kPinkMedium.CGColor;
[espAllEntityHPBtn addTarget:[MenuController class] action:@selector(toggleAllEntityHP:) forControlEvents:UIControlEventTouchUpInside];
[miniMapView addSubview:espAllEntityHPBtn];

espAllEntityHPStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(menuW/2+6, 65, 140, 28)];
espAllEntityHPStatusLabel.text = @"All Players HP";
espAllEntityHPStatusLabel.textColor = kPinkDark;
espAllEntityHPStatusLabel.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightMedium];
espAllEntityHPStatusLabel.textAlignment = NSTextAlignmentRight;
[miniMapView addSubview:espAllEntityHPStatusLabel];

// Monsters HP
UIButton *espMonstersHPBtn = [UIButton buttonWithType:UIButtonTypeCustom];
espMonstersHPBtn.frame = CGRectMake(menuW-40, 110, 28, 28);
[espMonstersHPBtn setTitle:showMonstersHP ? @"✅" : @"" forState:0];
[espMonstersHPBtn setTitleColor:kPinkDark forState:0];
espMonstersHPBtn.backgroundColor = [UIColor colorWithRed:0.97 green:0.90 blue:0.95 alpha:1.0];
espMonstersHPBtn.layer.cornerRadius = 8;
espMonstersHPBtn.layer.borderWidth = 1.5;
espMonstersHPBtn.layer.borderColor = kPinkMedium.CGColor;
[espMonstersHPBtn addTarget:[MenuController class] action:@selector(toggleMonstersHP:) forControlEvents:UIControlEventTouchUpInside];
[miniMapView addSubview:espMonstersHPBtn];

espMonstersHPStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(menuW/2+6, 110, 140, 28)];
espMonstersHPStatusLabel.text = @"Monsters HP";
espMonstersHPStatusLabel.textColor = kPinkDark;
espMonstersHPStatusLabel.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightMedium];
espMonstersHPStatusLabel.textAlignment = NSTextAlignmentRight;
[miniMapView addSubview:espMonstersHPStatusLabel];

// Enable All
UIButton *espAllBtn = [UIButton buttonWithType:UIButtonTypeCustom];
espAllBtn.frame = CGRectMake(menuW-40, 155, 28, 28);
[espAllBtn setTitle:showAllESP ? @"✅" : @"" forState:0];
[espAllBtn setTitleColor:kPinkDark forState:0];
espAllBtn.backgroundColor = [UIColor colorWithRed:0.97 green:0.90 blue:0.95 alpha:1.0];
espAllBtn.layer.cornerRadius = 8;
espAllBtn.layer.borderWidth = 1.5;
espAllBtn.layer.borderColor = kPinkMedium.CGColor;
[espAllBtn addTarget:[MenuController class] action:@selector(toggleAllESP:) forControlEvents:UIControlEventTouchUpInside];
[miniMapView addSubview:espAllBtn];

espAllStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(menuW/2+6, 155, 140, 28)];
espAllStatusLabel.text = @"Enable All";
espAllStatusLabel.textColor = kPinkDark;
espAllStatusLabel.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightMedium];
espAllStatusLabel.textAlignment = NSTextAlignmentRight;
[miniMapView addSubview:espAllStatusLabel];

// ───────────────────────────────
// FOV View - تصميم كرتوني
// ───────────────────────────────
fovView = [[UIView alloc] initWithFrame:CGRectMake(0, 118, menuW, 170)];
fovView.backgroundColor = [UIColor clearColor];
fovView.hidden = YES;
[menuView addSubview:fovView];

UILabel *fovTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, menuW, 28)];
fovTitle.text = @"🎯 Field of View";
fovTitle.textColor = kPinkDark;
fovTitle.textAlignment = NSTextAlignmentCenter;
fovTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
[fovView addSubview:fovTitle];

UISegmentedControl *fovControl = [[UISegmentedControl alloc] initWithItems:@[@"30", @"40", @"45", @"50", @"60", @"70", @"80", @"90"]];
fovControl.frame = CGRectMake(12, 45, menuW-24, 40);
fovControl.selectedSegmentIndex = 2; // 45 افتراضي
fovControl.backgroundColor = [UIColor colorWithRed:0.97 green:0.90 blue:0.95 alpha:1.0];
fovControl.selectedSegmentTintColor = kPinkMedium;
fovControl.layer.cornerRadius = 12;
[fovControl addTarget:[MenuController class] action:@selector(selectFOV:) forControlEvents:UIControlEventValueChanged];
[fovView addSubview:fovControl];

UIButton *resetFovBtn = [UIButton buttonWithType:UIButtonTypeCustom];
resetFovBtn.frame = CGRectMake(12, 95, menuW-24, 42);
[resetFovBtn setTitle:@"🔄 Reset to Default" forState:0];
[resetFovBtn setTitleColor:[UIColor whiteColor] forState:0];
resetFovBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
resetFovBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.45 blue:0.55 alpha:0.95];
resetFovBtn.layer.cornerRadius = 12;
[resetFovBtn addTarget:[MenuController class] action:@selector(resetFOV:) forControlEvents:UIControlEventTouchUpInside];
[fovView addSubview:resetFovBtn];

fovStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 145, menuW-24, 32)];
fovStatusLabel.text = @"FOV: 45.0";
fovStatusLabel.textColor = kPinkDark;
fovStatusLabel.textAlignment = NSTextAlignmentCenter;
fovStatusLabel.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightMedium];
fovStatusLabel.backgroundColor = [UIColor colorWithRed:1.0 green:0.96 blue:0.98 alpha:0.9];
fovStatusLabel.layer.cornerRadius = 10;
fovStatusLabel.clipsToBounds = YES;
[fovView addSubview:fovStatusLabel];



// ───────────────────────────────
// Overlay Views (ESP Layers)
// ───────────────────────────────
espLine2View = [[ESPLine2View alloc] initWithFrame:mainWindow.bounds];
espLine2View.hidden = !showESPLine2;
espLine2View.layer.zPosition = 10;
[mainWindow addSubview:espLine2View];

espBoxView = [[ESPBoxView alloc] initWithFrame:mainWindow.bounds];
espBoxView.hidden = !showESPBoxes;
espBoxView.layer.zPosition = 20;
[mainWindow addSubview:espBoxView];

espIconView = [[ESPIconView alloc] initWithFrame:mainWindow.bounds];
espIconView.hidden = !showESPIcons && !showESPMonsterIcons;
espIconView.layer.zPosition = 30;
[mainWindow addSubview:espIconView];

espHealthView = [[ESPHealthView alloc] initWithFrame:mainWindow.bounds];
espHealthView.hidden = !showESPHealth && !showAllEntityHP && !showMonstersHP;
espHealthView.layer.zPosition = 40;
[mainWindow addSubview:espHealthView];

// ───────────────────────────────
// Final Layer Order
// ───────────────────────────────
[mainWindow addSubview:menuView];
[mainWindow bringSubviewToFront:menuView];
[mainWindow bringSubviewToFront:floatingButton];

LoadConfig();
NSLog(@"[MenuController] ✨ Kawaii Full Cartoon UI Setup Completed ✨");

	
    });
}


// ---------------- Constructor ----------------
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CreateUI();
		
    });
}