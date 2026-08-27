#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(path):
    p = ROOT / path
    return p, p.read_text(encoding="utf-8")


def save(p, text):
    p.write_text(text, encoding="utf-8")


def once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"PATCH FAILED [{label}]: expected 1 occurrence, found {count}")
    return text.replace(old, new, 1)


def all_(text, old, new, label, minimum=1):
    count = text.count(old)
    if count < minimum:
        raise SystemExit(f"PATCH FAILED [{label}]: expected >= {minimum}, found {count}")
    return text.replace(old, new)


# 1) Logos source: remove obsolete debug expansion and make current Logos parser-safe.
p, s = load("AppData/AppData.xm")
s = once(s, "    %log;\n", "", "remove %log")
s = once(
    s,
    "        NSMutableArray *newItems = [NSMutableArray arrayWithArray:%orig?:@[]];",
    "        NSArray *originalItems = %orig;\n        NSMutableArray *newItems = [NSMutableArray arrayWithArray:(originalItems ?: @[])];",
    "iOS12 %orig parser safety",
)
save(p, s)

# 2) Rootless resources + helper messages.
p, s = load("AppData/Classes/Helpers/ADHelper.m")
s = once(
    s,
    '        _sharedInstance.resoucesBundle = [NSBundle bundleWithPath:@"/Library/Application Support/AppData/Resources.bundle"];',
    '        NSString *rootlessResourcesPath = @"/var/jb/Library/Application Support/AppData/Resources.bundle";\n'
    '        NSString *rootfulResourcesPath = @"/Library/Application Support/AppData/Resources.bundle";\n'
    '        NSString *resourcesPath = [[NSFileManager defaultManager] fileExistsAtPath:rootlessResourcesPath] ? rootlessResourcesPath : rootfulResourcesPath;\n'
    '        _sharedInstance.resoucesBundle = [NSBundle bundleWithPath:resourcesPath];',
    "rootless resources path",
)
s = once(s, '@"Install Filza app to open the selected directory"', '@"يلزم تثبيت Filza لفتح المجلد المحدد"', "Filza alert")
s = once(s, '@"Okay"', '@"حسنًا"', "helper OK")
save(p, s)

# 3) Appearance titles.
p, s = load("AppData/Classes/Helpers/ADSettings.m")
for old, new in [
    ('return @"Dark";', 'return @"داكن";'),
    ('return @"Light";', 'return @"فاتح";'),
    ('return @"Automatic";', 'return @"تلقائي";'),
    ('return @"N/A";', 'return @"غير متاح";'),
]:
    s = once(s, old, new, f"appearance {old}")
save(p, s)

# 4) Main popup controller: Arabic text + true RTL while keeping technical identifiers LTR.
p, s = load("AppData/Classes/Controller/ADDataViewController.m")
translations = [
    ('@"Could not fetch app data.\\n\\nError: Empty icon view."', '@"تعذر جلب بيانات التطبيق.\\n\\nالخطأ: واجهة الأيقونة فارغة."'),
    ('@"Could not fetch app data.\\n\\nError: could not find icon image view."', '@"تعذر جلب بيانات التطبيق.\\n\\nالخطأ: تعذر العثور على صورة الأيقونة."'),
    ('@"Could not fetch app data.\\n\\n%@ is not a valid icon class."', '@"تعذر جلب بيانات التطبيق.\\n\\n%@ ليست فئة أيقونة صالحة."'),
    ('cancelTitle:@"Okay"', 'cancelTitle:@"حسنًا"'),
    ('@"Not an Application"', '@"ليس تطبيقًا"'),
    ('@"No Bundle Identifier"', '@"لا يوجد معرّف حزمة"'),
    ('@"Copied to clipboard"', '@"تم النسخ إلى الحافظة"'),
    ('alertControllerWithTitle:@"Rename" message:@"Enter an app icon name"', 'alertControllerWithTitle:@"إعادة تسمية" message:@"أدخل اسمًا جديدًا لأيقونة التطبيق"'),
    ('actionWithTitle:@"Cancel"', 'actionWithTitle:@"إلغاء"'),
    ('actionWithTitle:@"Change"', 'actionWithTitle:@"تغيير"'),
    ('actionWithTitle:@"Reset"', 'actionWithTitle:@"إعادة تعيين"'),
    ('textField.placeholder = @"Icon Name";', 'textField.placeholder = @"اسم الأيقونة";'),
    ('cancelTitle:@"Okay"]', 'cancelTitle:@"حسنًا"]'),
]
for i, (old, new) in enumerate(translations):
    s = all_(s, old, new, f"controller translation {i}")
s = once(
    s,
    "- (void)viewDidLoad {\n    [super viewDidLoad];\n    self.view.backgroundColor = [UIColor clearColor];",
    "- (void)viewDidLoad {\n    [super viewDidLoad];\n    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n    self.view.backgroundColor = [UIColor clearColor];",
    "controller RTL root",
)
s = once(
    s,
    "    UIView *containerView = [UIView new];\n    containerView.backgroundColor = [UIColor clearColor];",
    "    UIView *containerView = [UIView new];\n    containerView.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n    containerView.backgroundColor = [UIColor clearColor];",
    "controller RTL container",
)
s = once(s, "    self.nameLabel.titleLabel.font = [UIFont systemFontOfSize:17];", "    self.nameLabel.titleLabel.font = [UIFont systemFontOfSize:17];\n    self.nameLabel.titleLabel.textAlignment = NSTextAlignmentRight;", "name RTL")
s = once(s, "    self.identifierLabel.titleLabel.font = [UIFont systemFontOfSize:14];", "    self.identifierLabel.titleLabel.font = [UIFont systemFontOfSize:14];\n    self.identifierLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;\n    self.identifierLabel.titleLabel.textAlignment = NSTextAlignmentLeft;", "identifier LTR")
s = once(s, "    self.versionLabel.font = [UIFont systemFontOfSize:13];", "    self.versionLabel.font = [UIFont systemFontOfSize:13];\n    self.versionLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;\n    self.versionLabel.textAlignment = NSTextAlignmentLeft;", "version LTR")
s = once(s, "    tableView.backgroundColor = [UIColor clearColor];\n    tableView.delegate = dataSource;", "    tableView.backgroundColor = [UIColor clearColor];\n    tableView.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n    tableView.delegate = dataSource;", "tables RTL")
s = once(
    s,
    "    CGRect activeInitialFrame = activeTableView.frame;\n    CGRect activeEndFrame = CGRectMake(0 - activeTableView.frame.size.width, activeTableView.frame.origin.y, activeTableView.frame.size.width, activeTableView.frame.size.height);\n    \n    CGRect inactiveInitialFrame = CGRectMake(activeTableView.frame.size.width, activeTableView.frame.origin.y, activeTableView.frame.size.width, activeTableView.frame.size.height);\n    CGRect inactiveEndFrame = activeTableView.frame;",
    "    CGRect activeInitialFrame = activeTableView.frame;\n    BOOL isRTL = (self.view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);\n    CGFloat direction = isRTL ? 1.0 : -1.0;\n    CGRect activeEndFrame = CGRectMake(direction * activeTableView.frame.size.width, activeTableView.frame.origin.y, activeTableView.frame.size.width, activeTableView.frame.size.height);\n    \n    CGRect inactiveInitialFrame = CGRectMake(-direction * activeTableView.frame.size.width, activeTableView.frame.origin.y, activeTableView.frame.size.width, activeTableView.frame.size.height);\n    CGRect inactiveEndFrame = activeTableView.frame;",
    "RTL page transition",
)
save(p, s)

# 5) Main data table and destructive/manage actions.
p, s = load("AppData/Classes/Controller/DataSource/ADMainDataSource.m")
translations = [
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
    ('@"Clearing App data will only delete the app\'s \\"Library\\" and \\"Documents\\" folders inside Data bundle and not the App Groups."', '@"سيحذف مسح بيانات التطبيق مجلدي Library وDocuments داخل حاوية بيانات التطبيق فقط، ولن يحذف مجموعات التطبيق."'),
    ('@"Reset Permissions"', '@"إعادة تعيين الأذونات"'),
    ('@"This will clear all the app permissions to access your Contacts, Photos, Camera, etc.\\nNext time you use the app it will ask you again to grant permissions."', '@"سيؤدي هذا إلى مسح أذونات وصول التطبيق إلى جهات الاتصال والصور والكاميرا وغيرها.\\nعند فتح التطبيق لاحقًا سيطلب منك منح الأذونات من جديد."'),
    ('@"Reset"', '@"إعادة تعيين"'),
    ('@"Reset!"', '@"تمت الإعادة"'),
    ('@"Offload\\nApp"', '@"تفريغ\\nالتطبيق"'),
    ('@"Offload App"', '@"تفريغ التطبيق"'),
    ('@"This will free up storage used by the app, but keep its documents and data. Reinstalling the app will reinstate your data if the app is still available in the AppStore."', '@"يوفر هذا مساحة التخزين التي يستخدمها التطبيق مع الاحتفاظ بمستنداته وبياناته. عند إعادة تثبيت التطبيق ستعود بياناته إذا كان ما يزال متاحًا في App Store."'),
    ('@"Offload"', '@"تفريغ"'),
    ('@"More Info"', '@"معلومات إضافية"'),
    ('@"Containers"', '@"المسارات والحاويات"'),
    ('@"App Groups"', '@"مجموعات التطبيقات"'),
    ('@"Manage"', '@"إدارة التطبيق"'),
    ('@"Open in Filza"', '@"فتح في Filza"'),
    ('@"Copy Path"', '@"نسخ المسار"'),
    ('@"Copy Identifier"', '@"نسخ المعرّف"'),
    ('@"App Group"', '@"مجموعة التطبيق"'),
]
for i, (old, new) in enumerate(translations):
    s = all_(s, old, new, f"main translation {i}")
s = once(
    s,
    "        [ADAppearance applyStylesToCell:cell];\n        \n        if ([self isContainersSection:indexPath.section]) {",
    "        [ADAppearance applyStylesToCell:cell];\n        cell.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n        cell.textLabel.textAlignment = NSTextAlignmentRight;\n        cell.detailTextLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;\n        cell.detailTextLabel.textAlignment = NSTextAlignmentLeft;\n        \n        if ([self isContainersSection:indexPath.section]) {",
    "main mixed direction",
)
save(p, s)

# 6) More-info screen.
p, s = load("AppData/Classes/Controller/DataSource/ADMoreDataSource.m")
translations = [
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
]
for i, (old, new) in enumerate(translations):
    s = all_(s, old, new, f"more translation {i}")
s = once(s, "        [ADAppearance applyStylesToCell:cell];\n        if (indexPath.row == 0) {", "        [ADAppearance applyStylesToCell:cell];\n        cell.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n        cell.textLabel.textAlignment = NSTextAlignmentRight;\n        cell.detailTextLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;\n        cell.detailTextLabel.textAlignment = NSTextAlignmentLeft;\n        if (indexPath.row == 0) {", "more mixed direction")
s = once(s, "        [ADAppearance applyStylesToCell:cell];\n        if (indexPath.section == 1) {", "        [ADAppearance applyStylesToCell:cell];\n        cell.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;\n        cell.textLabel.textAlignment = NSTextAlignmentLeft;\n        if (indexPath.section == 1) {", "technical rows LTR")
save(p, s)

# 7) Preferences screen.
p, s = load("AppDataPrefs/ADPreferencesController.m")
translations = [
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
    ('@"- Copy the app bundle Identifier by tapping it\\n\\\n- Edit app icon name by tapping it\\n\\\n- Filza is required to open folders\\n\\\n- Clearing Caches will delete the app\'s \\"Caches\\" and \\"Tmp\\" folders\\n\\\n- Clearing app data will delete Library/Documents/Tmp folders and reset permissions"', '@"• انسخ معرّف الحزمة بالضغط عليه\\n\\\n• عدّل اسم أيقونة التطبيق بالضغط على الاسم\\n\\\n• يلزم تثبيت Filza لفتح المجلدات\\n\\\n• مسح الذاكرة المؤقتة يحذف Caches وTmp\\n\\\n• مسح بيانات التطبيق يحذف Library وDocuments وTmp ويعيد تعيين الأذونات"'),
]
for i, (old, new) in enumerate(translations):
    s = all_(s, old, new, f"prefs translation {i}")
s = once(s, "- (void)viewDidLoad {\n    [super viewDidLoad];", "- (void)viewDidLoad {\n    [super viewDidLoad];\n    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n    self.navigationController.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;", "prefs RTL root")
s = once(s, "    self.tableView.delegate = self;", "    self.tableView.delegate = self;\n    self.tableView.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;", "prefs table RTL")
save(p, s)

# 8) Preferences selection list RTL.
p, s = load("AppDataPrefs/Classes/Controllers/ADSelectListTableViewController.m")
s = once(s, "@implementation ADSelectListTableViewController\n", "@implementation ADSelectListTableViewController\n\n- (void)viewDidLoad {\n    [super viewDidLoad];\n    self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n    self.tableView.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n}\n", "list RTL root")
s = once(s, "    cell.textLabel.text = [self.listItems objectAtIndex:[indexPath row]];", "    cell.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n    cell.textLabel.textAlignment = NSTextAlignmentRight;\n    cell.textLabel.text = [self.listItems objectAtIndex:[indexPath row]];", "list RTL cell")
save(p, s)

# 9) Reusable headers/actions RTL.
for path, old, new, label in [
    ("AppData/Classes/Controller/Cells/ADTitleSectionHeaderView.m", "- (void)initialize {\n", "- (void)initialize {\n    self.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n", "title header RTL"),
    ("AppData/Classes/Controller/Cells/ADExpandableSectionHeaderView.m", "- (void)initialize {\n", "- (void)initialize {\n    self.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n", "expand header RTL"),
    ("AppData/Classes/Controller/Cells/ADActionsBarView.m", "        self.axis = UILayoutConstraintAxisHorizontal;", "        self.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;\n        self.axis = UILayoutConstraintAxisHorizontal;", "actions RTL"),
]:
    p, s = load(path)
    s = once(s, old, new, label)
    if path.endswith("ADExpandableSectionHeaderView.m"):
        s = once(s, "    self.titleLabel.font = [UIFont systemFontOfSize:13];", "    self.titleLabel.font = [UIFont systemFontOfSize:13];\n    self.titleLabel.textAlignment = NSTextAlignmentRight;", "expand title alignment")
    save(p, s)

# Build-time audit: these user-facing English phrases must be gone.
for path in [
    "AppData/Classes/Controller/ADDataViewController.m",
    "AppData/Classes/Controller/DataSource/ADMainDataSource.m",
    "AppData/Classes/Controller/DataSource/ADMoreDataSource.m",
    "AppDataPrefs/ADPreferencesController.m",
    "AppData/Classes/Helpers/ADHelper.m",
    "AppData/Classes/Helpers/ADSettings.m",
]:
    text = (ROOT / path).read_text(encoding="utf-8")
    forbidden = ["Could not fetch app data", "Clear App Data", "Reset Permissions", "More Info", "Swipe Up", "Force Touch Menu", "Install Filza app", 'return @"Dark"', 'return @"Light"', 'return @"Automatic"']
    remaining = [x for x in forbidden if x in text]
    if remaining:
        raise SystemExit(f"ARABIC AUDIT FAILED {path}: {remaining}")

print("ARABIC_RTL_ROOTLESS_PREPARATION_PASS")
