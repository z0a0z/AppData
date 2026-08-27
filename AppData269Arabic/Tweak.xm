#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <notify.h>

static NSString * const ADPrefsPath = @"/var/mobile/Library/Preferences/com.fouadraheb.appdata.plist";
static NSString * const ADMapPath = @"/var/jb/Library/Application Support/AppDataArabic/ar.plist";

static NSString *ADLanguage(void) {
    NSDictionary *p = [NSDictionary dictionaryWithContentsOfFile:ADPrefsPath];
    NSString *v = p[@"ADLanguage"];
    return [v isKindOfClass:[NSString class]] ? v : @"en";
}

static BOOL ADArabic(void) { return [ADLanguage() isEqualToString:@"ar"]; }

static void ADSetLanguage(NSString *lang) {
    NSMutableDictionary *p = [NSMutableDictionary dictionaryWithContentsOfFile:ADPrefsPath];
    if (!p) p = [NSMutableDictionary dictionary];
    p[@"ADLanguage"] = lang;
    [p writeToFile:ADPrefsPath atomically:YES];
    notify_post("com.fouadraheb.appdata.preferences-changed");
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

static void ADRTL(UIView *v) {
    if (!ADArabic() || !v) return;
    v.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    if ([v isKindOfClass:[UILabel class]]) ((UILabel *)v).textAlignment = NSTextAlignmentRight;
    if ([v isKindOfClass:[UITextView class]]) ((UITextView *)v).textAlignment = NSTextAlignmentRight;
    if ([v isKindOfClass:[UITextField class]]) ((UITextField *)v).textAlignment = NSTextAlignmentRight;
}

@interface ADArabicLanguageTarget : NSObject
+ (instancetype)shared;
- (void)changed:(UISegmentedControl *)sender;
@end

@implementation ADArabicLanguageTarget
+ (instancetype)shared {
    static ADArabicLanguageTarget *v;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ v = [ADArabicLanguageTarget new]; });
    return v;
}
- (void)changed:(UISegmentedControl *)sender {
    NSArray *langs = @[@"en", @"zh", @"ar"];
    if (sender.selectedSegmentIndex >= 0 && sender.selectedSegmentIndex < (NSInteger)langs.count)
        ADSetLanguage(langs[sender.selectedSegmentIndex]);
}
@end

%hook UILabel
- (void)setText:(NSString *)text {
    NSString *originalText = text;
    text = ADT(text);
    %orig;
    if (![text isEqual:originalText]) ADRTL(self);
}
%end

%hook UITextView
- (void)setText:(NSString *)text {
    NSString *originalText = text;
    text = ADT(text);
    %orig;
    if (![text isEqual:originalText]) ADRTL(self);
}
%end

%hook UITextField
- (void)setText:(NSString *)text {
    NSString *originalText = text;
    text = ADT(text);
    %orig;
    if (![text isEqual:originalText]) ADRTL(self);
}
- (void)setPlaceholder:(NSString *)text {
    NSString *originalText = text;
    text = ADT(text);
    %orig;
    if (![text isEqual:originalText]) ADRTL(self);
}
%end

%hook UIButton
- (void)setTitle:(NSString *)title forState:(UIControlState)state {
    NSString *originalTitle = title;
    title = ADT(title);
    %orig;
    if (![title isEqual:originalTitle]) ADRTL(self);
}
%end

%hook UINavigationItem
- (void)setTitle:(NSString *)title {
    title = ADT(title);
    %orig;
}
%end

%hook UIAlertAction
+ (instancetype)actionWithTitle:(NSString *)title style:(UIAlertActionStyle)style handler:(void (^)(UIAlertAction *))handler {
    title = ADT(title);
    return %orig;
}
%end

%hook UIAlertController
+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message preferredStyle:(UIAlertControllerStyle)style {
    title = ADT(title);
    message = ADT(message);
    return %orig;
}
%end

%hook ADPreferencesController
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = %orig;
    NSString *title = cell.textLabel.text ?: @"";
    if ([title containsString:@"Language"] || [title containsString:@"语言"] || [title isEqualToString:@"اللغة"]) {
        UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[@"EN", @"中文", @"العربية"]];
        NSString *lang = ADLanguage();
        seg.selectedSegmentIndex = [lang isEqualToString:@"zh"] ? 1 : ([lang isEqualToString:@"ar"] ? 2 : 0);
        [seg addTarget:[ADArabicLanguageTarget shared] action:@selector(changed:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = seg;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        if ([lang isEqualToString:@"ar"]) { cell.textLabel.text = @"اللغة"; ADRTL(cell); }
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if ([cell.accessoryView isKindOfClass:[UISegmentedControl class]]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    %orig;
}
%end
