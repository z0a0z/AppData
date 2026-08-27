#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    p = ROOT / rel
    return p, p.read_text(encoding="utf-8")


def write(p, text):
    p.write_text(text, encoding="utf-8")


def replace(text, old, new):
    return text.replace(old, new) if old in text else text


def insert_after(text, marker, addition, guard):
    if guard in text:
        return text
    if marker not in text:
        raise SystemExit(f"PREP FAILED: marker missing: {marker[:80]}")
    return text.replace(marker, marker + addition, 1)


def require(rel, *tokens):
    text = (ROOT / rel).read_text(encoding="utf-8")
    missing = [t for t in tokens if t not in text]
    if missing:
        raise SystemExit(f"PREP FAILED [{rel}]: missing {missing}")


# ---------------------------------------------------------------------------
# Logos compatibility: accept already-fixed source, otherwise apply fixes.
# ---------------------------------------------------------------------------
p, s = read("AppData/AppData.xm")
s = replace(s, "    %log;\n", "")
s = replace(
    s,
    "        NSMutableArray *newItems = [NSMutableArray arrayWithArray:%orig?:@[]];",
    "        NSArray *originalItems = %orig;\n        NSMutableArray *newItems = [NSMutableArray arrayWithArray:originalItems ?: @[]];",
)
if "NSArray *originalItems = %orig;" not in s:
    raise SystemExit("PREP FAILED: Logos iOS12 original-items fix not present")
write(p, s)

# ---------------------------------------------------------------------------
# Rootless resource bundle + helper UI.
# ---------------------------------------------------------------------------
p, s = read("AppData/Classes/Helpers/ADHelper.m")
s = replace(
    s,
    '        _sharedInstance.resoucesBundle = [NSBundle bundleWithPath:@"/Library/Application Support/AppData/Resources.bundle"];',
    '        NSString *rootlessResourcesPath = @"/var/jb/Library/Application Support/AppData/Resources.bundle";\n'
    '        NSString *rootfulResourcesPath = @"/Library/Application Support/AppData/Resources.bundle";\n'
    '        NSString *resourcesPath = [[NSFileManager defaultManager] fileExistsAtPath:rootlessResourcesPath] ? rootlessResourcesPath : rootfulResourcesPath;\n'
    '        _sharedInstance.resoucesBundle = [NSBundle bundleWithPath:resourcesPath];',
)
s = replace(s, '@"Install Filza app to open the selected directory"', '@"يلزم تثبيت Filza لفتح المجلد المحدد"')
s = replace(s, '@"Okay"', '@"حسنًا"')
write(p, s)

# ---------------------------------------------------------------------------
# Appearance labels.
# ---------------------------------------------------------------------------
p, s = read("AppData/Classes/Helpers/ADSettings.m")
for old, new in [
    ('return @"Dark";', 'return @"داكن";'),
    ('return @"Light";', 'return @"فاتح";'),
    ('return @"Automatic";', 'return @"تلقائي";'),
    ('return @"N/A";', 'return @"غير متاح";'),
]:
    s = replace(s, old, new)
write(p, s)

# ---------------------------------------------------------------------------
# Main popup: complete Arabic text, force RTL for UI, preserve technical LTR.
# ---------------------------------------------------------------------------
p, s = read("AppData/Classes/Controller/ADDataViewController.m")
for old, new in [
    ('@"Could not fetch app data.\\n\\nError: Empty icon view."', '@"تعذر جلب بيانات التطبيق.\\n\\nالخطأ: واجهة الأيقونة فارغة."'),
    ('@"Could not fetch app data.\\n\\nError: could not find icon image view."', '@"تعذر جلب بيانات التطبيق.\\n\\nالخطأ: تعذر العثور على صورة الأيقونة."'),
    ('@"Could not fetch app data.\\n\\n%@ is not a valid icon class."', '@"تعذر جلب بيانات التطبيق.\\n\\n%@ ليست فئة أيقونة صالحة."'),
    ('@"Not an Application"', '@"ليس تطبيقًا"'),
    ('@"No Bundle Identifier"', '@"لا يوجد معرّف حزمة"'),
    ('@"Copied to clipboard"', '@"تم النسخ إلى الحافظة"'),
    ('alertControllerWithTitle:@"Rename" message:@"Enter an app icon name"', 'alertControllerWithTitle:@"إعادة تسمية" message:@"أدخل اسمًا جديدًا لأيقونة التطبيق"'),
    ('actionWithTitle:@"Cancel"', 'actionWithTitle:@"إلغاء"'),
    ('actionWithTitle:@"Change"', 'actionWithTitle:@"تغيير"'),
    ('actionWithTitle:@"Reset"', 'actionWithTitle:@"إعادة تعيين"'),
    ('textField.placeholder = @"Icon Name";', 'textField.placeholder = @"اسم الأيقونة";'),
    ('cancelTitle:@"Okay"', 'cancelTitle:@"حسنًا"'),
    ('@"حسناً"', '@"حسنًا"'),
]:
    s = replace(s, old, new)

s = insert_after(
    s,
    "- (void)viewDidLoad {\n    [super viewDidLoad];",
    "\n    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;",
    "self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;",
)
s = insert_after(
    s,
    "    UIView *containerView = [UIView new];",
    "\n    containerView.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;",
    "containerView.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;",
)
s = insert_after(
    s,
    "    self.nameLabel.titleLabel.font = [UIFont systemFontOfSize:17];",
    "\n    self.nameLabel.titleLabel.textAlignment = NSTextAlignmentRight;",
    "self.nameLabel.titleLabel.textAlignment = NSTextAlignmentRight;",
)
s = insert_after(
    s,
    "    self.identifierLabel.titleLabel.font = [UIFont systemFontOfSize:14];",
    "\n    self.identifierLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;\n    self.identifierLabel.titleLabel.textAlignment = NSTextAlignmentLeft;",
    "self.identifierLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;",
)
s = insert_after(
    s,
    "    self.versionLabel.font = [UIFont systemFontOfSize:13];",
    "\n    self.versionLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;\n    self.versionLabel.textAlignment = NSTextAlignmentLeft;",
    "self.versionLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;",
)
s = insert_after(
    s,
    "    tableView.backgroundColor = [UIColor clearColor];",
    "\n    tableView.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;",
    "tableView.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;",
)
old_anim = """    CGRect activeInitialFrame = activeTableView.frame;
    CGRect activeEndFrame = CGRectMake(0 - activeTableView.frame.size.width, activeTableView.frame.origin.y, activeTableView.frame.size.width, activeTableView.frame.size.height);
    
    CGRect inactiveInitialFrame = CGRectMake(activeTableView.frame.size.width, activeTableView.frame.origin.y, activeTableView.frame.size.width, activeTableView.frame.size.height);
    CGRect inactiveEndFrame = activeTableView.frame;"""
new_anim = """    CGRect activeInitialFrame = activeTableView.frame;
    BOOL isRTL = (self.view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);
    CGFloat direction = isRTL ? 1.0 : -1.0;
    CGRect activeEndFrame = CGRectMake(direction * activeTableView.frame.size.width, activeTableView.frame.origin.y, activeTableView.frame.size.width, activeTableView.frame.size.height);
    
    CGRect inactiveInitialFrame = CGRectMake(-direction * activeTableView.frame.size.width, activeTableView.frame.origin.y, activeTableView.frame.size.width, activeTableView.frame.size.height);
    CGRect inactiveEndFrame = activeTableView.frame;"""
s = replace(s, old_anim, new_anim)
write(p, s)

# ---------------------------------------------------------------------------
# Main data source: all management actions + mixed Arabic/technical direction.
# ---------------------------------------------------------------------------
p, s = read("AppData/Classes/Controller/DataSource/ADMainDataSource.m")
for old, new in [
    ('@"Bundle"', '@"حزمة التطبيق"'),
    ('@"Data"', '@"بيانات التطبيق"'),
    ('@"Update\\nBadge"', '@"تحديث\\nالشارة"'),
    ('@"Badges"', '@"شارات الإشعارات"'),
    ('@"Update or clear the app badges count"', '@"تحديث عدد شارات التطبيق أو تصفيره"'),
    ('@"Badge Count"', '@"عدد الشارات"'),
    ('@"Update"', '@"تحديث"'),
    ('@"Updated!"', '@"تم التحديث"'),
    ('@"Clear"', '@"تصفير"'),
    ('@"Cleared!"', '@"تم المسح"'),
    ('@"Cancel"', '@"إلغاء"'),
    ('@"Clear\\nCaches"', '@"مسح\\nالمؤقت"'),
    ('@"Loading..."', '@"جارٍ الحساب..."'),
    ('@"Clearing..."', '@"جارٍ المسح..."'),
    ('@"Clear App Data"', '@"مسح بيانات التطبيق"'),
    ('@"Clearing App data will only delete the app\'s \\"Library\\" and \\"Documents\\" folders inside Data bundle and not the App Groups."', '@"سيحذف هذا مجلدي Library وDocuments داخل حاوية بيانات التطبيق فقط، ولن يحذف مجموعات التطبيق."'),
    ('@"Reset Permissions"', '@"إعادة تعيين الأذونات"'),
    ('@"This will clear all the app permissions to access your Contacts, Photos, Camera, etc.\\nNext time you use the app it will ask you again to grant permissions."', '@"سيتم مسح أذونات وصول التطبيق إلى جهات الاتصال والصور والكاميرا وغيرها.\\nعند فتح التطبيق لاحقًا سيطلب منح الأذونات من جديد."'),
    ('@"Reset"', '@"إعادة تعيين"'),
    ('@"Reset!"', '@"تمت الإعادة"'),
    ('@"Offload\\nApp"', '@"تفريغ\\nالتطبيق"'),
    ('@"Offload App"', '@"تفريغ التطبيق"'),
    ('@"This will free up storage used by the app, but keep its documents and data. Reinstalling the app will reinstate your data if the app is still available in the AppStore."', '@"يوفر هذا مساحة التخزين المستخدمة مع الاحتفاظ بمستندات التطبيق وبياناته. عند إعادة التثبيت ستعود البيانات إذا كان التطبيق ما يزال متاحًا في App Store."'),
    ('@"Offload"', '@"تفريغ"'),
    ('@"More Info"', '@"معلومات إضافية"'),
    ('@"Containers"', '@"المسارات والحاويات"'),
    ('@"App Groups"', '@"مجموعات التطبيقات"'),
    ('@"Manage"', '@"إدارة التطبيق"'),
    ('@"Open in Filza"', '@"فتح في Filza"'),
    ('@"Copy Path"', '@"نسخ المسار"'),
    ('@"Copy Identifier"', '@"نسخ المعرّف"'),
    ('@"App Group"', '@"مجموعة التطبيق"'),
    ('@"مسح\\nالكاش"', '@"مسح\\nالمؤقت"'),
    ('@"جاري الحساب..."', '@"جارٍ الحساب..."'),
    ('@"جاري المسح..."', '@"جارٍ المسح..."'),
]:
    s = replace(s, old, new)
marker = "        [ADAppearance applyStylesToCell:cell];\n        \n        if ([self isContainersSection:indexPath.section]) {"
if "cell.detailTextLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;" not in s:
    if marker not in s:
        raise SystemExit("PREP FAILED: main mixed-direction marker missing")
    s = s.replace(marker, "        [ADAppearance applyStylesToCell:cell];\n        cell.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n        cell.textLabel.textAlignment = NSTextAlignmentRight;\n        cell.detailTextLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;\n        cell.detailTextLabel.textAlignment = NSTextAlignmentLeft;\n        \n        if ([self isContainersSection:indexPath.section]) {", 1)
write(p, s)

# ---------------------------------------------------------------------------
# More-info screen: Arabic section labels, technical values stay LTR.
# ---------------------------------------------------------------------------
p, s = read("AppData/Classes/Controller/DataSource/ADMoreDataSource.m")
for old, new in [
    ('@"Internal Version"', '@"الإصدار الداخلي"'),
    ('@"Minimum iOS Version"', '@"الحد الأدنى لإصدار iOS"'),
    ('@"Platform Build Version"', '@"إصدار بناء النظام"'),
    ('@"Dismiss"', '@"إغلاق"'),
    ('@"Copy"', '@"نسخ"'),
    ('@"MORE INFO"', '@"معلومات إضافية"'),
    ('@"URL SCHEMES (%td)"', '@"مخططات الروابط (URL Schemes) (%td)"'),
    ('@"QUERIES SCHEMES (%td)"', '@"مخططات الاستعلام (Query Schemes) (%td)"'),
    ('@"ACTIVITY TYPES (%td)"', '@"أنواع النشاط (Activity Types) (%td)"'),
    ('@"BACKGROUND MODES (%td)"', '@"أوضاع الخلفية (Background Modes) (%td)"'),
    ('@"ENTITLEMENTS (%td)"', '@"الاستحقاقات (Entitlements) (%td)"'),
    ('@"إصدار بنية النظام"', '@"إصدار بناء النظام"'),
    ('@"مسارات الروابط (URL SCHEMES) (%td)"', '@"مخططات الروابط (URL Schemes) (%td)"'),
    ('@"الاستعلامات (QUERIES SCHEMES) (%td)"', '@"مخططات الاستعلام (Query Schemes) (%td)"'),
    ('@"أنواع النشاط (ACTIVITY TYPES) (%td)"', '@"أنواع النشاط (Activity Types) (%td)"'),
    ('@"أوضاع الخلفية (BACKGROUND MODES) (%td)"', '@"أوضاع الخلفية (Background Modes) (%td)"'),
    ('@"الصلاحيات (ENTITLEMENTS) (%td)"', '@"الاستحقاقات (Entitlements) (%td)"'),
]:
    s = replace(s, old, new)
marker1 = "        [ADAppearance applyStylesToCell:cell];\n        if (indexPath.row == 0) {"
if "cell.detailTextLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;" not in s:
    if marker1 not in s:
        raise SystemExit("PREP FAILED: more mixed-direction marker missing")
    s = s.replace(marker1, "        [ADAppearance applyStylesToCell:cell];\n        cell.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n        cell.textLabel.textAlignment = NSTextAlignmentRight;\n        cell.detailTextLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;\n        cell.detailTextLabel.textAlignment = NSTextAlignmentLeft;\n        if (indexPath.row == 0) {", 1)
marker2 = "        [ADAppearance applyStylesToCell:cell];\n        if (indexPath.section == 1) {"
if "cell.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;\n        cell.textLabel.textAlignment = NSTextAlignmentLeft;" not in s:
    if marker2 not in s:
        raise SystemExit("PREP FAILED: technical rows marker missing")
    s = s.replace(marker2, "        [ADAppearance applyStylesToCell:cell];\n        cell.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;\n        cell.textLabel.textAlignment = NSTextAlignmentLeft;\n        if (indexPath.section == 1) {", 1)
write(p, s)

# ---------------------------------------------------------------------------
# Preferences UI + RTL.
# ---------------------------------------------------------------------------
p, s = read("AppDataPrefs/ADPreferencesController.m")
for old, new in [
    ('@"View & Manage Apps Data from Homescreen"', '@"عرض بيانات التطبيقات وإدارتها من الشاشة الرئيسية"'),
    ('@"Swipe Up"', '@"السحب للأعلى"'),
    ('@"Force Touch Menu"', '@"قائمة الضغط المطوّل"'),
    ('@"Appearance"', '@"المظهر"'),
    ('@"Info"', '@"معلومات"'),
    ('@"Twitter"', '@"تويتر"'),
    ('@"Source Code"', '@"الكود المصدري"'),
    ('@"Activation"', '@"طريقة التفعيل"'),
    ('@"Developer"', '@"المطور"'),
    ('@"The popup can be activated by either swiping up on the app icon or through a button in the force touch menu"', '@"يمكن فتح نافذة AppData بالسحب للأعلى على أيقونة التطبيق أو من خيار AppData في قائمة الضغط المطوّل."'),
    ('قائمة اللمس بالضغط (3D Touch)', 'قائمة الضغط المطوّل'),
]:
    s = replace(s, old, new)
old_footer = '''@"- Copy the app bundle Identifier by tapping it\\n\\
- Edit app icon name by tapping it\\n\\
- Filza is required to open folders\\n\\
- Clearing Caches will delete the app's \\"Caches\\" and \\"Tmp\\" folders\\n\\
- Clearing app data will delete Library/Documents/Tmp folders and reset permissions"'''
new_footer = '''@"• انسخ معرّف الحزمة بالضغط عليه\\n\\
• عدّل اسم أيقونة التطبيق بالضغط على الاسم\\n\\
• يلزم تثبيت Filza لفتح المجلدات\\n\\
• مسح الذاكرة المؤقتة يحذف Caches وTmp\\n\\
• مسح بيانات التطبيق يحذف Library وDocuments وTmp ويعيد تعيين الأذونات"'''
s = replace(s, old_footer, new_footer)
s = insert_after(
    s,
    "- (void)viewDidLoad {\n    [super viewDidLoad];",
    "\n    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n    self.navigationController.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;",
    "self.navigationController.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;",
)
s = insert_after(
    s,
    "    self.tableView.delegate = self;",
    "\n    self.tableView.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;",
    "self.tableView.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;",
)
write(p, s)

# Preferences selection list RTL.
p, s = read("AppDataPrefs/Classes/Controllers/ADSelectListTableViewController.m")
if "self.tableView.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;" not in s:
    marker = "@implementation ADSelectListTableViewController\n"
    if marker not in s:
        raise SystemExit("PREP FAILED: select-list implementation marker missing")
    s = s.replace(marker, marker + "\n- (void)viewDidLoad {\n    [super viewDidLoad];\n    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n    self.tableView.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n}\n", 1)
if "cell.textLabel.textAlignment = NSTextAlignmentRight;" not in s:
    marker = "    cell.textLabel.text = [self.listItems objectAtIndex:[indexPath row]];"
    if marker not in s:
        raise SystemExit("PREP FAILED: select-list cell marker missing")
    s = s.replace(marker, "    cell.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n    cell.textLabel.textAlignment = NSTextAlignmentRight;\n" + marker, 1)
write(p, s)

# Reusable headers / manage bar RTL.
for rel, marker, addition in [
    ("AppData/Classes/Controller/Cells/ADTitleSectionHeaderView.m", "- (void)initialize {\n", "    self.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n"),
    ("AppData/Classes/Controller/Cells/ADExpandableSectionHeaderView.m", "- (void)initialize {\n", "    self.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n"),
    ("AppData/Classes/Controller/Cells/ADActionsBarView.m", "        self.axis = UILayoutConstraintAxisHorizontal;", "        self.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n"),
]:
    p, s = read(rel)
    if "UISemanticContentAttributeForceRightToLeft" not in s:
        if marker not in s:
            raise SystemExit(f"PREP FAILED: RTL marker missing in {rel}")
        if rel.endswith("ADActionsBarView.m"):
            s = s.replace(marker, addition + marker, 1)
        else:
            s = s.replace(marker, marker + addition, 1)
    if rel.endswith("ADExpandableSectionHeaderView.m") and "self.titleLabel.textAlignment = NSTextAlignmentRight;" not in s:
        fm = "    self.titleLabel.font = [UIFont systemFontOfSize:13];"
        if fm in s:
            s = s.replace(fm, fm + "\n    self.titleLabel.textAlignment = NSTextAlignmentRight;", 1)
    write(p, s)

# ---------------------------------------------------------------------------
# Final fail-closed audit.
# ---------------------------------------------------------------------------
require("AppData/AppData.xm", "NSArray *originalItems = %orig;")
require("AppData/Classes/Helpers/ADHelper.m", "/var/jb/Library/Application Support/AppData/Resources.bundle", "يلزم تثبيت Filza")
require("AppData/Classes/Helpers/ADSettings.m", '@"داكن"', '@"فاتح"', '@"تلقائي"')
require("AppData/Classes/Controller/ADDataViewController.m", "UISemanticContentAttributeForceRightToLeft", "UISemanticContentAttributeForceLeftToRight", "تم النسخ إلى الحافظة")
require("AppData/Classes/Controller/DataSource/ADMainDataSource.m", "إدارة التطبيق", "مسح بيانات التطبيق", "إعادة تعيين الأذونات", "معلومات إضافية")
require("AppData/Classes/Controller/DataSource/ADMoreDataSource.m", "معلومات إضافية", "الاستحقاقات (Entitlements)")
require("AppDataPrefs/ADPreferencesController.m", "طريقة التفعيل", "قائمة الضغط المطوّل", "UISemanticContentAttributeForceRightToLeft")

for rel in [
    "AppData/Classes/Controller/ADDataViewController.m",
    "AppData/Classes/Controller/DataSource/ADMainDataSource.m",
    "AppData/Classes/Controller/DataSource/ADMoreDataSource.m",
    "AppDataPrefs/ADPreferencesController.m",
    "AppData/Classes/Helpers/ADHelper.m",
    "AppData/Classes/Helpers/ADSettings.m",
]:
    text = (ROOT / rel).read_text(encoding="utf-8")
    forbidden = [
        "Could not fetch app data", "Clear App Data", "Reset Permissions",
        "More Info", "Swipe Up", "Force Touch Menu", "Install Filza app",
        'return @"Dark"', 'return @"Light"', 'return @"Automatic"',
    ]
    remaining = [x for x in forbidden if x in text]
    if remaining:
        raise SystemExit(f"ARABIC AUDIT FAILED [{rel}]: {remaining}")

print("ARABIC_RTL_ROOTLESS_PREPARATION_PASS")
