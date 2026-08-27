#import <UIKit/UIKit.h>

static NSDictionary<NSString *, NSString *> *ADArabicMap(void) {
    static NSDictionary *map;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *paths = @[
            @"/var/jb/Library/Application Support/AppData/ArabicLocalization.plist",
            @"/Library/Application Support/AppData/ArabicLocalization.plist"
        ];
        for (NSString *path in paths) {
            NSDictionary *candidate = [NSDictionary dictionaryWithContentsOfFile:path];
            if ([candidate isKindOfClass:[NSDictionary class]] && candidate.count > 0) {
                map = candidate;
                break;
            }
        }
        if (!map) map = @{};
    });
    return map;
}

static BOOL ADContainsCJK(NSString *s) {
    if (![s isKindOfClass:[NSString class]] || s.length == 0) return NO;
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        if ((c >= 0x3400 && c <= 0x9FFF) || (c >= 0xF900 && c <= 0xFAFF)) return YES;
    }
    return NO;
}

static NSString *ADArabic(NSString *s) {
    if (![s isKindOfClass:[NSString class]] || s.length == 0 || !ADContainsCJK(s)) return s;
    NSString *exact = ADArabicMap()[s];
    if (exact.length) return exact;

    NSMutableString *out = [s mutableCopy];
    NSArray *keys = [[ADArabicMap() allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        if (a.length > b.length) return NSOrderedAscending;
        if (a.length < b.length) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    for (NSString *key in keys) {
        if ([out rangeOfString:key].location != NSNotFound) {
            [out replaceOccurrencesOfString:key withString:ADArabicMap()[key] options:0 range:NSMakeRange(0, out.length)];
        }
    }

    if (ADContainsCJK(out)) {
        NSMutableString *clean = [NSMutableString string];
        for (NSUInteger i = 0; i < out.length; i++) {
            unichar c = [out characterAtIndex:i];
            if (!((c >= 0x3400 && c <= 0x9FFF) || (c >= 0xF900 && c <= 0xFAFF))) {
                [clean appendFormat:@"%C", c];
            }
        }
        NSString *trim = [clean stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        return trim.length ? trim : @"AppData";
    }
    return out;
}

static BOOL ADChanged(NSString *a, NSString *b) {
    return (a != b && ![a isEqualToString:b]);
}

static void ADRTLView(UIView *view) {
    if (view) view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
}

%hook UILabel
- (void)setText:(NSString *)text {
    NSString *ar = ADArabic(text);
    %orig(ar);
    if (ADChanged(text, ar)) { self.textAlignment = NSTextAlignmentRight; ADRTLView(self); }
}
%end

%hook UITextView
- (void)setText:(NSString *)text {
    NSString *ar = ADArabic(text);
    %orig(ar);
    if (ADChanged(text, ar)) { self.textAlignment = NSTextAlignmentRight; ADRTLView(self); }
}
%end

%hook UITextField
- (void)setText:(NSString *)text {
    NSString *ar = ADArabic(text);
    %orig(ar);
    if (ADChanged(text, ar)) { self.textAlignment = NSTextAlignmentRight; ADRTLView(self); }
}
- (void)setPlaceholder:(NSString *)placeholder {
    NSString *ar = ADArabic(placeholder);
    %orig(ar);
    if (ADChanged(placeholder, ar)) { self.textAlignment = NSTextAlignmentRight; ADRTLView(self); }
}
%end

%hook UIButton
- (void)setTitle:(NSString *)title forState:(UIControlState)state {
    NSString *ar = ADArabic(title);
    %orig(ar, state);
    if (ADChanged(title, ar)) ADRTLView(self);
}
%end

%hook UIViewController
- (void)setTitle:(NSString *)title { %orig(ADArabic(title)); }
- (void)viewDidLoad {
    %orig;
    NSString *name = NSStringFromClass([self class]);
    if ([name hasPrefix:@"AD"] || [name rangeOfString:@"AppData" options:NSCaseInsensitiveSearch].location != NSNotFound) ADRTLView(self.view);
}
%end

%hook UINavigationItem
- (void)setTitle:(NSString *)title { %orig(ADArabic(title)); }
%end

%hook UIBarButtonItem
- (void)setTitle:(NSString *)title { %orig(ADArabic(title)); }
%end

%hook UISearchBar
- (void)setPlaceholder:(NSString *)placeholder {
    NSString *ar = ADArabic(placeholder);
    %orig(ar);
    if (ADChanged(placeholder, ar)) ADRTLView(self);
}
%end

%hook UIAlertAction
+ (instancetype)actionWithTitle:(NSString *)title style:(UIAlertActionStyle)style handler:(void (^)(UIAlertAction *action))handler {
    return %orig(ADArabic(title), style, handler);
}
%end

%hook UIAlertController
+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message preferredStyle:(UIAlertControllerStyle)preferredStyle {
    return %orig(ADArabic(title), ADArabic(message), preferredStyle);
}
%end

%hook UIMenu
+ (instancetype)menuWithTitle:(NSString *)title children:(NSArray<UIMenuElement *> *)children {
    return %orig(ADArabic(title), children);
}
%end

%hook UIAction
+ (instancetype)actionWithTitle:(NSString *)title image:(UIImage *)image identifier:(UIActionIdentifier)identifier handler:(UIActionHandler)handler {
    return %orig(ADArabic(title), image, identifier, handler);
}
%end
