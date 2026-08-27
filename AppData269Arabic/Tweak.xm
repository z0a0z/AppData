#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static NSString * const ADPrefsPath = @"/var/mobile/Library/Preferences/com.fouadraheb.appdata.plist";
static NSString * const ADMapPath = @"/var/jb/Library/Application Support/AppDataArabic/ar.plist";
static NSString * const ADArabicFlagKey = @"ADArabicEnabled";

static BOOL ADArabic(void) {
    NSDictionary *p = [NSDictionary dictionaryWithContentsOfFile:ADPrefsPath];
    return [p[ADArabicFlagKey] boolValue];
}

static NSDictionary *ADMap(void) {
    static NSDictionary *map;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ map = [NSDictionary dictionaryWithContentsOfFile:ADMapPath] ?: @{}; });
    return map;
}

static NSString *ADT(NSString *s) {
    if (!ADArabic() || ![s isKindOfClass:[NSString class]]) return s;
    return ADMap()[s] ?: s;
}

static BOOL ADIsAppDataController(UIResponder *r) {
    UIResponder *node = r;
    for (NSInteger i = 0; node && i < 24; i++, node = [node nextResponder]) {
        NSString *name = NSStringFromClass([node class]);
        if ([name hasPrefix:@"AD"]) return YES;
    }
    return NO;
}

static void ADRTL(UIView *v) {
    if (!ADArabic() || !v) return;
    v.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    if ([v isKindOfClass:[UILabel class]]) ((UILabel *)v).textAlignment = NSTextAlignmentRight;
    if ([v isKindOfClass:[UITextView class]]) ((UITextView *)v).textAlignment = NSTextAlignmentRight;
    if ([v isKindOfClass:[UITextField class]]) ((UITextField *)v).textAlignment = NSTextAlignmentRight;
}

static void ADLocalizeLabel(UILabel *label) {
    if (!ADArabic() || !ADIsAppDataController(label)) return;
    NSString *translated = ADT(label.text);
    if (translated && ![translated isEqualToString:label.text]) label.text = translated;
    ADRTL(label);
}

%hook UILabel
- (void)didMoveToWindow {
    %orig;
    ADLocalizeLabel(self);
}
%end

%hook UITextView
- (void)didMoveToWindow {
    %orig;
    if (ADArabic() && ADIsAppDataController(self)) {
        NSString *translated = ADT(self.text);
        if (translated && ![translated isEqualToString:self.text]) self.text = translated;
        ADRTL(self);
    }
}
%end

%hook UITextField
- (void)didMoveToWindow {
    %orig;
    if (ADArabic() && ADIsAppDataController(self)) {
        NSString *translated = ADT(self.text);
        if (translated && ![translated isEqualToString:self.text]) self.text = translated;
        NSString *placeholder = ADT(self.placeholder);
        if (placeholder && ![placeholder isEqualToString:self.placeholder]) self.placeholder = placeholder;
        ADRTL(self);
    }
}
%end

%hook UIButton
- (void)didMoveToWindow {
    %orig;
    if (ADArabic() && ADIsAppDataController(self)) {
        for (NSNumber *n in @[@(UIControlStateNormal), @(UIControlStateHighlighted), @(UIControlStateDisabled), @(UIControlStateSelected)]) {
            UIControlState state = (UIControlState)n.unsignedIntegerValue;
            NSString *title = [self titleForState:state];
            NSString *translated = ADT(title);
            if (translated && ![translated isEqualToString:title]) [self setTitle:translated forState:state];
        }
        ADRTL(self);
    }
}
%end

%hook UINavigationItem
- (void)setTitle:(NSString *)title {
    if (ADArabic()) title = ADT(title);
    %orig;
}
%end

%hook UIAlertAction
+ (instancetype)actionWithTitle:(NSString *)title style:(UIAlertActionStyle)style handler:(void (^)(UIAlertAction *))handler {
    if (ADArabic()) title = ADT(title);
    return %orig;
}
%end

%hook UIAlertController
+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message preferredStyle:(UIAlertControllerStyle)style {
    if (ADArabic()) {
        title = ADT(title);
        message = ADT(message);
    }
    return %orig;
}
%end
