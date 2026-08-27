#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>

// AppData 2.7.1 Arabic wrapper.
// Keep AppData's own localization engine on English when Arabic is selected,
// then translate the rendered English UI and apply RTL here.
static NSString * const ADPrefsPath = @"/var/mobile/Library/Preferences/com.fouadraheb.appdata.plist";
static NSString * const ADMapPath = @"/var/jb/Library/Application Support/AppDataArabic/ar.plist";
static NSString * const ADArabicFlagKey = @"ADArabicEnabled";

static NSMutableDictionary *ADMutablePrefs(void) {
    NSMutableDictionary *p = [NSMutableDictionary dictionaryWithContentsOfFile:ADPrefsPath];
    return p ?: [NSMutableDictionary dictionary];
}

static BOOL ADArabic(void) {
    NSDictionary *p = [NSDictionary dictionaryWithContentsOfFile:ADPrefsPath];
    return [p[ADArabicFlagKey] boolValue];
}

static void ADSetArabic(BOOL enabled) {
    NSMutableDictionary *p = ADMutablePrefs();
    p[ADArabicFlagKey] = @(enabled);
    if (enabled) p[@"ADLanguage"] = @"en";
    [p writeToFile:ADPrefsPath atomically:YES];
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

static void ADTranslateView(UIView *v) {
    if (!v || !ADArabic()) return;
    v.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    if ([v isKindOfClass:[UILabel class]]) {
        UILabel *l = (UILabel *)v;
        l.text = ADT(l.text);
        l.textAlignment = NSTextAlignmentRight;
    } else if ([v isKindOfClass:[UITextView class]]) {
        UITextView *t = (UITextView *)v;
        t.text = ADT(t.text);
        t.textAlignment = NSTextAlignmentRight;
    } else if ([v isKindOfClass:[UITextField class]]) {
        UITextField *t = (UITextField *)v;
        t.text = ADT(t.text);
        t.placeholder = ADT(t.placeholder);
        t.textAlignment = NSTextAlignmentRight;
    } else if ([v isKindOfClass:[UIButton class]]) {
        UIButton *b = (UIButton *)v;
        for (NSNumber *n in @[@(UIControlStateNormal), @(UIControlStateHighlighted), @(UIControlStateDisabled), @(UIControlStateSelected)]) {
            UIControlState state = (UIControlState)n.unsignedIntegerValue;
            NSString *title = [b titleForState:state];
            if (title) [b setTitle:ADT(title) forState:state];
        }
    }
    for (UIView *sub in v.subviews) ADTranslateView(sub);
}

static BOOL ADClassIsOurs(Class cls) {
    NSString *n = NSStringFromClass(cls);
    return [n hasPrefix:@"AD"];
}

typedef id (*ADSelectInitIMP)(id, SEL, UITableViewStyle, NSString *, NSArray *, NSArray *, NSString *, BOOL, void (^)(id));
static ADSelectInitIMP gSelectInit;

static id ADSelectInit(id self, SEL _cmd, UITableViewStyle style, NSString *title, NSArray *items, NSArray *values, NSString *currentValue, BOOL pop, void (^changeBlock)(id)) {
    BOOL isLanguage = ([title rangeOfString:@"Language" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                       [title containsString:@"语言"] || [title containsString:@"اللغة"]);
    if (!isLanguage) {
        return gSelectInit(self, _cmd, style, title, items, values, currentValue, pop, changeBlock);
    }

    NSMutableArray *newItems = [items mutableCopy] ?: [NSMutableArray array];
    NSMutableArray *newValues = [values mutableCopy] ?: [NSMutableArray array];
    if (![newValues containsObject:@"ar"]) {
        [newItems addObject:@"العربية"];
        [newValues addObject:@"ar"];
    }

    if (ADArabic()) {
        currentValue = @"ar";
        title = @"اللغة / Language";
    }

    void (^wrappedChange)(id) = ^(id value) {
        if ([value isKindOfClass:[NSString class]] && [(NSString *)value isEqualToString:@"ar"]) {
            ADSetArabic(YES);
            if (changeBlock) changeBlock(@"en");
        } else {
            ADSetArabic(NO);
            if (changeBlock) changeBlock(value);
        }
    };

    return gSelectInit(self, _cmd, style, title, newItems, newValues, currentValue, pop, wrappedChange);
}

typedef void (*ADViewDidAppearIMP)(id, SEL, BOOL);
static NSMutableDictionary<NSString *, NSValue *> *gOriginalViewDidAppear;

static void ADWrappedViewDidAppear(id self, SEL _cmd, BOOL animated) {
    NSString *key = NSStringFromClass([self class]);
    ADViewDidAppearIMP orig = (ADViewDidAppearIMP)[gOriginalViewDidAppear[key] pointerValue];
    if (orig) orig(self, _cmd, animated);
    if (!ADArabic()) return;
    UIViewController *vc = (UIViewController *)self;
    vc.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    vc.navigationItem.title = ADT(vc.navigationItem.title ?: vc.title);
    vc.title = ADT(vc.title);
    ADTranslateView(vc.view);
}

static void ADInstallControllerTranslation(void) {
    gOriginalViewDidAppear = [NSMutableDictionary dictionary];
    int count = objc_getClassList(NULL, 0);
    if (count <= 0) return;
    Class *classes = (__unsafe_unretained Class *)calloc((size_t)count, sizeof(Class));
    count = objc_getClassList(classes, count);
    SEL sel = @selector(viewDidAppear:);
    Method baseMethod = class_getInstanceMethod([UIViewController class], sel);
    const char *types = method_getTypeEncoding(baseMethod);
    for (int i = 0; i < count; i++) {
        Class cls = classes[i];
        if (!ADClassIsOurs(cls) || ![cls isSubclassOfClass:[UIViewController class]]) continue;
        Method ownMethod = class_getInstanceMethod(cls, sel);
        IMP orig = method_getImplementation(ownMethod);
        gOriginalViewDidAppear[NSStringFromClass(cls)] = [NSValue valueWithPointer:orig];
        if (class_addMethod(cls, sel, (IMP)ADWrappedViewDidAppear, types)) {
            continue;
        }
        Method installed = class_getInstanceMethod(cls, sel);
        method_setImplementation(installed, (IMP)ADWrappedViewDidAppear);
    }
    free(classes);
}

__attribute__((constructor)) static void ADWrapperLoad(void) {
    @autoreleasepool {
        NSString *origPath = @"/var/jb/Library/PreferenceBundles/AppDataPrefs.bundle/AppDataPrefsOriginal";
        void *h = dlopen(origPath.UTF8String, RTLD_NOW | RTLD_GLOBAL);
        if (!h) {
            origPath = @"/Library/PreferenceBundles/AppDataPrefs.bundle/AppDataPrefsOriginal";
            h = dlopen(origPath.UTF8String, RTLD_NOW | RTLD_GLOBAL);
        }
        if (!h) return;

        Class selectCls = NSClassFromString(@"ADSelectListTableViewController");
        SEL initSel = NSSelectorFromString(@"initWithStyle:title:items:values:currentValue:popViewOnSelect:changeBlock:");
        Method initMethod = class_getInstanceMethod(selectCls, initSel);
        if (initMethod) {
            gSelectInit = (ADSelectInitIMP)method_getImplementation(initMethod);
            method_setImplementation(initMethod, (IMP)ADSelectInit);
        }
        ADInstallControllerTranslation();
    }
}
