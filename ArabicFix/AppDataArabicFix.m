#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString * const ADPrefsPath = @"/var/mobile/Library/Preferences/com.fouadraheb.appdata.plist";
static NSString * const ADArabicTablePath = @"/var/jb/Library/Application Support/AppDataArabic/ar.plist";
static NSDictionary<NSString *, NSString *> *ADArabicTable;

static BOOL ADArabicIsEnabled(void) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:ADPrefsPath];
    id enabled = prefs[@"ADArabicEnabled"];
    if ([enabled respondsToSelector:@selector(boolValue)] && [enabled boolValue]) return YES;

    id language = prefs[@"ADLanguage"];
    if ([language isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)language lowercaseString];
        if ([s isEqualToString:@"arabic"] || [s isEqualToString:@"ar"] || [s isEqualToString:@"العربية"]) return YES;
    }
    return NO;
}

static NSString *ADTranslateString(NSString *text) {
    if (!text || text.length == 0 || !ADArabicIsEnabled()) return text;
    if (!ADArabicTable) ADArabicTable = [NSDictionary dictionaryWithContentsOfFile:ADArabicTablePath];
    if (ADArabicTable.count == 0) return text;

    NSString *exact = ADArabicTable[text];
    if (exact.length > 0) return exact;

    NSMutableString *result = [text mutableCopy];
    __block BOOL changed = NO;
    [ADArabicTable enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        if (key.length == 0 || value.length == 0) return;
        NSRange r = [result rangeOfString:key options:0];
        if (r.location != NSNotFound) {
            [result replaceOccurrencesOfString:key withString:value options:0 range:NSMakeRange(0, result.length)];
            changed = YES;
        }
    }];
    return changed ? result : text;
}

static void ADSwizzle(Class cls, SEL original, SEL replacement) {
    Method m1 = class_getInstanceMethod(cls, original);
    Method m2 = class_getInstanceMethod(cls, replacement);
    if (m1 && m2) method_exchangeImplementations(m1, m2);
}

@interface UILabel (AppDataArabicFix)
- (void)adfix_setText:(NSString *)text;
- (void)adfix_setAttributedText:(NSAttributedString *)text;
@end

@implementation UILabel (AppDataArabicFix)
- (void)adfix_setText:(NSString *)text {
    [self adfix_setText:ADTranslateString(text)];
}

- (void)adfix_setAttributedText:(NSAttributedString *)text {
    if (!text || !ADArabicIsEnabled()) {
        [self adfix_setAttributedText:text];
        return;
    }
    NSString *translated = ADTranslateString(text.string);
    if (!translated || [translated isEqualToString:text.string]) {
        [self adfix_setAttributedText:text];
        return;
    }

    NSMutableAttributedString *mutable = [text mutableCopy];
    [mutable replaceCharactersInRange:NSMakeRange(0, mutable.length) withString:translated];
    [self adfix_setAttributedText:mutable];
}
@end

@interface UITextView (AppDataArabicFix)
- (void)adfix_tv_setText:(NSString *)text;
- (void)adfix_tv_setAttributedText:(NSAttributedString *)text;
@end

@implementation UITextView (AppDataArabicFix)
- (void)adfix_tv_setText:(NSString *)text {
    [self adfix_tv_setText:ADTranslateString(text)];
}

- (void)adfix_tv_setAttributedText:(NSAttributedString *)text {
    if (!text || !ADArabicIsEnabled()) {
        [self adfix_tv_setAttributedText:text];
        return;
    }
    NSString *translated = ADTranslateString(text.string);
    if (!translated || [translated isEqualToString:text.string]) {
        [self adfix_tv_setAttributedText:text];
        return;
    }
    NSMutableAttributedString *mutable = [text mutableCopy];
    [mutable replaceCharactersInRange:NSMakeRange(0, mutable.length) withString:translated];
    [self adfix_tv_setAttributedText:mutable];
}
@end

__attribute__((constructor)) static void ADInstallArabicFix(void) {
    @autoreleasepool {
        ADArabicTable = [NSDictionary dictionaryWithContentsOfFile:ADArabicTablePath];
        ADSwizzle([UILabel class], @selector(setText:), @selector(adfix_setText:));
        ADSwizzle([UILabel class], @selector(setAttributedText:), @selector(adfix_setAttributedText:));
        ADSwizzle([UITextView class], @selector(setText:), @selector(adfix_tv_setText:));
        ADSwizzle([UITextView class], @selector(setAttributedText:), @selector(adfix_tv_setAttributedText:));
    }
}
