#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>

static NSString * const ADPrefsPath = @"/var/mobile/Library/Preferences/com.fouadraheb.appdata.plist";
static NSString * const ADMapPath = @"/var/jb/Library/Application Support/AppDataArabic/ar.plist";

static NSDictionary *ADMap(void) {
    static NSDictionary *map;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ map = [NSDictionary dictionaryWithContentsOfFile:ADMapPath] ?: @{}; });
    return map;
}

static NSString *ADLanguage(void) {
    NSDictionary *p = [NSDictionary dictionaryWithContentsOfFile:ADPrefsPath];
    NSString *v = p[@"ADLanguage"];
    return [v isKindOfClass:[NSString class]] ? v : @"en";
}

static BOOL ADArabic(void) { return [ADLanguage() isEqualToString:@"ar"]; }
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
            UIControlState s = (UIControlState)n.unsignedIntegerValue;
            NSString *title = [b titleForState:s];
            if (title) [b setTitle:ADT(title) forState:s];
        }
    }
    for (UIView *sub in v.subviews) ADTranslateView(sub);
}

static BOOL ADClassIsOurs(Class cls) {
    NSString *n = NSStringFromClass(cls);
    return [n hasPrefix:@"AD"];
}

// ---- Language selector initializer ----
typedef id (*ADSelectInitIMP)(id, SEL, UITableViewStyle, NSString *, NSArray *, NSArray *, NSString *, BOOL, void (^)(id));
static ADSelectInitIMP gSelectInit;

static id ADSelectInit(id self, SEL _cmd, UITableViewStyle style, NSString *title, NSArray *items, NSArray *values, NSString *currentValue, BOOL pop, void (^changeBlock)(id)) {
    BOOL isLanguage = ([title rangeOfString:@"Language" options:NSCaseInsensitiveSearch].location != NSNotFound || [title containsString:@"语言"] || [title containsString:@"اللغة"]);
    if (isLanguage) {
        NSMutableArray *newItems = [items mutableCopy] ?: [NSMutableArray array];
        NSMutableArray *newValues = [values mutableCopy] ?: [NSMutableArray array];
        if (![newValues containsObject:@"ar"]) {
            [newItems addObject:@"العربية"];
            [newValues addObject:@"ar"];
        }
        items = newItems;
        values = newValues;
        if (ADArabic()) title = @"اللغة";
    }
    return gSelectInit(self, _cmd, style, title, items, values, currentValue, pop, changeBlock);
}

// ---- Translate AD view controllers after rendering ----
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
        Method m = class_getInstanceMethod(cls, sel);
        IMP orig = method_getImplementation(m);
        gOriginalViewDidAppear[NSStringFromClass(cls)] = [NSValue valueWithPointer:orig];
        class_addMethod(cls, sel, (IMP)ADWrappedViewDidAppear, types);
        Method own = class_getInstanceMethod(cls, sel);
        method_setImplementation(own, (IMP)ADWrappedViewDidAppear);
    }
    free(classes);
}

__attribute__((constructor)) static void ADWrapperLoad(void) {
    @autoreleasepool {
        NSString *bundlePath = [[NSBundle bundleForClass:NSClassFromString(@"NSBundle")] bundlePath];
        // bundleForClass above can point at Preferences; use the known AppData bundle path first.
        NSString *origPath = @"/var/jb/Library/PreferenceBundles/AppDataPrefs.bundle/AppDataPrefsOriginal";
        void *h = dlopen(origPath.UTF8String, RTLD_NOW | RTLD_GLOBAL);
        if (!h) {
            // Fallback for environments where /var/jb is symlinked/resolved differently.
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
