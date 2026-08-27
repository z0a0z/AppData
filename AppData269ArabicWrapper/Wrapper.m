#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>

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
static BOOL ADIsAppDataResponder(UIResponder *r) {
    UIResponder *n = r;
    for (NSInteger i=0; n && i<30; i++, n=[n nextResponder]) {
        if ([NSStringFromClass([n class]) hasPrefix:@"AD"]) return YES;
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
static void ADTranslateView(UIView *v) {
    if (!v || !ADArabic()) return;
    ADRTL(v);
    if ([v isKindOfClass:[UILabel class]]) {
        UILabel *l=(UILabel *)v; NSString *t=ADT(l.text); if (t) l.text=t;
    } else if ([v isKindOfClass:[UITextView class]]) {
        UITextView *t=(UITextView *)v; t.text=ADT(t.text);
    } else if ([v isKindOfClass:[UITextField class]]) {
        UITextField *t=(UITextField *)v; t.text=ADT(t.text); t.placeholder=ADT(t.placeholder);
    } else if ([v isKindOfClass:[UIButton class]]) {
        UIButton *b=(UIButton *)v;
        for (NSNumber *n in @[@(UIControlStateNormal),@(UIControlStateHighlighted),@(UIControlStateDisabled),@(UIControlStateSelected)]) {
            UIControlState s=(UIControlState)n.unsignedIntegerValue; NSString *title=[b titleForState:s];
            if (title) [b setTitle:ADT(title) forState:s];
        }
    } else if ([v isKindOfClass:[UITableViewCell class]]) {
        UITableViewCell *c=(UITableViewCell *)v;
        NSString *main=c.textLabel.text ?: @"";
        if ([main rangeOfString:@"Language" options:NSCaseInsensitiveSearch].location!=NSNotFound || [main containsString:@"اللغة"] || [main containsString:@"语言"]) {
            c.textLabel.text=@"اللغة";
            if (c.detailTextLabel) c.detailTextLabel.text=@"العربية";
        }
    }
    for (UIView *sub in v.subviews) ADTranslateView(sub);
}

typedef id (*ADSelectInitIMP)(id,SEL,UITableViewStyle,NSString*,NSArray*,NSArray*,NSString*,BOOL,void(^)(id));
static ADSelectInitIMP gSelectInit;
static id ADSelectInit(id self, SEL _cmd, UITableViewStyle style, NSString *title, NSArray *items, NSArray *values, NSString *currentValue, BOOL pop, void (^changeBlock)(id)) {
    BOOL isLanguage=([title rangeOfString:@"Language" options:NSCaseInsensitiveSearch].location!=NSNotFound || [title containsString:@"语言"] || [title containsString:@"اللغة"]);
    if (!isLanguage) return gSelectInit(self,_cmd,style,title,items,values,currentValue,pop,changeBlock);
    NSMutableArray *ni=[items mutableCopy] ?: [NSMutableArray array];
    NSMutableArray *nv=[values mutableCopy] ?: [NSMutableArray array];
    if (![nv containsObject:@"ar"]) { [ni addObject:@"العربية"]; [nv addObject:@"ar"]; }
    if (ADArabic()) { currentValue=@"ar"; title=@"اللغة"; }
    void (^wrapped)(id)=^(id value){
        if ([value isKindOfClass:[NSString class]] && [(NSString*)value isEqualToString:@"ar"]) {
            ADSetArabic(YES);
            if (changeBlock) changeBlock(@"en");
            ADSetArabic(YES); // reassert after the original preference writer refreshes its dictionary
        } else {
            ADSetArabic(NO);
            if (changeBlock) changeBlock(value);
        }
    };
    return gSelectInit(self,_cmd,style,title,ni,nv,currentValue,pop,wrapped);
}

typedef void (*ADViewDidAppearIMP)(id,SEL,BOOL);
static NSMutableDictionary<NSString*,NSValue*> *gOrigAppear;
static void ADWrappedAppear(id self, SEL _cmd, BOOL animated) {
    ADViewDidAppearIMP orig=(ADViewDidAppearIMP)[gOrigAppear[NSStringFromClass([self class])] pointerValue];
    if (orig) orig(self,_cmd,animated);
    if (ADArabic()) {
        UIViewController *vc=(UIViewController*)self;
        vc.title=ADT(vc.title); vc.navigationItem.title=ADT(vc.navigationItem.title ?: vc.title);
        ADTranslateView(vc.view);
        dispatch_async(dispatch_get_main_queue(), ^{ ADTranslateView(vc.view); });
    }
}
static void ADInstallControllerHooks(void) {
    gOrigAppear=[NSMutableDictionary dictionary];
    int count=objc_getClassList(NULL,0); if (count<=0) return;
    Class *classes=(__unsafe_unretained Class*)calloc((size_t)count,sizeof(Class)); count=objc_getClassList(classes,count);
    SEL sel=@selector(viewDidAppear:); Method base=class_getInstanceMethod([UIViewController class],sel); const char *types=method_getTypeEncoding(base);
    for(int i=0;i<count;i++){
        Class cls=classes[i]; NSString *n=NSStringFromClass(cls);
        if (![n hasPrefix:@"AD"] || ![cls isSubclassOfClass:[UIViewController class]]) continue;
        Method m=class_getInstanceMethod(cls,sel); IMP orig=method_getImplementation(m);
        gOrigAppear[n]=[NSValue valueWithPointer:orig];
        if (!class_addMethod(cls,sel,(IMP)ADWrappedAppear,types)) method_setImplementation(class_getInstanceMethod(cls,sel),(IMP)ADWrappedAppear);
    }
    free(classes);
}

static void (*origLabelSetText)(id,SEL,NSString*);
static void ADLabelSetText(id self, SEL _cmd, NSString *text) {
    if (ADArabic() && (ADIsAppDataResponder(self) || [(UIView*)self window])) text=ADT(text);
    origLabelSetText(self,_cmd,text); if (ADArabic() && ADIsAppDataResponder(self)) ADRTL(self);
}
static void (*origLabelMove)(id,SEL);
static void ADLabelMove(id self, SEL _cmd) {
    origLabelMove(self,_cmd);
    if (ADArabic() && ADIsAppDataResponder(self)) { UILabel *l=self; NSString *t=ADT(l.text); if (t) origLabelSetText(l,@selector(setText:),t); ADRTL(l); }
}
static void ADInstallPersistentLabelHooks(void) {
    Method m=class_getInstanceMethod([UILabel class],@selector(setText:)); origLabelSetText=(void*)method_getImplementation(m); method_setImplementation(m,(IMP)ADLabelSetText);
    Method d=class_getInstanceMethod([UILabel class],@selector(didMoveToWindow)); origLabelMove=(void*)method_getImplementation(d); method_setImplementation(d,(IMP)ADLabelMove);
}

__attribute__((constructor)) static void ADWrapperLoad(void) {
    @autoreleasepool {
        NSString *path=@"/var/jb/Library/PreferenceBundles/AppDataPrefs.bundle/AppDataPrefsOriginal";
        void *h=dlopen(path.UTF8String,RTLD_NOW|RTLD_GLOBAL);
        if(!h){ path=@"/Library/PreferenceBundles/AppDataPrefs.bundle/AppDataPrefsOriginal"; h=dlopen(path.UTF8String,RTLD_NOW|RTLD_GLOBAL); }
        if(!h) return;
        Class c=NSClassFromString(@"ADSelectListTableViewController");
        SEL s=NSSelectorFromString(@"initWithStyle:title:items:values:currentValue:popViewOnSelect:changeBlock:");
        Method m=class_getInstanceMethod(c,s);
        if(m){ gSelectInit=(ADSelectInitIMP)method_getImplementation(m); method_setImplementation(m,(IMP)ADSelectInit); }
        ADInstallPersistentLabelHooks();
        ADInstallControllerHooks();
    }
}
