import '../assistant/models/action_parameters.dart';

/// Small en/ar string table. Everything the user sees goes through here, so
/// the `change_language` action visibly flips the whole UI (and its direction).
class Strings {
  const Strings(this.lang);
  final AppLanguage lang;
  bool get ar => lang == AppLanguage.ar;
  String _(String en, String arabic) => ar ? arabic : en;

  // Shell
  String get appTitle => _('Assistant', 'المساعد');
  String get tabHome => _('Home', 'الرئيسية');
  String get tabProfile => _('Profile', 'الملف الشخصي');
  String get tabSettings => _('Settings', 'الإعدادات');
  String destination(AppDestination d) => switch (d) {
    AppDestination.home => tabHome,
    AppDestination.profile => tabProfile,
    AppDestination.settings => tabSettings,
  };

  // Home
  String get homeTitle => _('What would you like to do?', 'ماذا تريد أن تفعل؟');
  String get homeSubtitle => _(
    'Ask in English or Arabic. I can change the theme or open a page.',
    'اطلب بالإنجليزية أو العربية. أستطيع تغيير المظهر أو فتح صفحة.',
  );
  String get tryThese => _('Try saying', 'جرّب أن تقول');
  String get appState => _('Right now', 'الحالة الحالية');
  String get theme => _('Theme', 'المظهر');
  String get language => _('Language', 'اللغة');
  String get notifications => _('Notifications', 'الإشعارات');
  String get currentPage => _('Page', 'الصفحة');
  String get lastSearch => _('Last search', 'آخر بحث');
  String get none => _('none', 'لا يوجد');
  String get on => _('On', 'مفعّلة');
  String get off => _('Off', 'متوقفة');
  String themeName(ThemeModeOption m) => switch (m) {
    ThemeModeOption.light => _('Light', 'فاتح'),
    ThemeModeOption.dark => _('Dark', 'داكن'),
    ThemeModeOption.system => _('System', 'النظام'),
  };
  String languageName(AppLanguage l) =>
      l == AppLanguage.ar ? 'العربية' : 'English';

  // Profile
  String get profileName => _('Demo User', 'مستخدم تجريبي');
  String get profileNote =>
      _('This is sample data for the demo.', 'هذه بيانات تجريبية للعرض فقط.');

  // Settings
  String get appearance => _('Appearance', 'المظهر');
  String get assistantModel => _('Assistant model', 'نموذج المساعد');
  String get developerTools => _('Developer tools', 'أدوات المطوّر');
  String get developerToolsHint => _(
    'Send a raw prediction to the validator',
    'أرسل تنبؤاً خاماً إلى أداة التحقق',
  );

  // Assistant dock
  String get inputHint => _('Ask the assistant…', 'اكتب طلبك…');
  String get send => _('Send', 'إرسال');
  String get assistantOff => _('Assistant is off', 'المساعد متوقف');

  /// "3.4 GB" / "3.4 جيجابايت": always a number with its unit.
  String size(int mb) {
    if (mb >= 1024) {
      final gb = (mb / 1024).toStringAsFixed(1);
      return ar ? '$gb جيجابايت' : '$gb GB';
    }
    return ar ? '$mb ميجابايت' : '$mb MB';
  }

  String firstTimeDownload(int mb) => _(
    'First time: about ${size(mb)} download, then offline.',
    'أول مرة: تنزيل حوالي ${size(mb)}، ثم يعمل بدون إنترنت.',
  );
  String get turnOn => _('Turn on', 'تشغيل');
  String get loading => _('Loading…', 'جارٍ التحميل…');
  String downloading(int p) => _('Downloading $p%', 'جارٍ التنزيل $p%');
  String get loadFailed => _('Could not load the model', 'تعذّر تحميل النموذج');
  String get retry => _('Retry', 'إعادة المحاولة');
  String get switchModel => _('Switch model', 'تبديل النموذج');
  String get ready => _('Ready', 'جاهز');
  String get thinking => _('Understanding…', 'جارٍ الفهم…');

  // Outcomes
  String doneTheme(ThemeModeOption m) => _(
    'Theme set to ${themeName(m).toLowerCase()}',
    'تم ضبط المظهر على ${themeName(m)}',
  );
  String doneNavigate(AppDestination d) =>
      _('Opened ${destination(d)}', 'تم فتح ${destination(d)}');
  String doneLanguage(AppLanguage l) => _(
    'Language set to ${languageName(l)}',
    'تم ضبط اللغة على ${languageName(l)}',
  );
  String doneNotifications(bool on) => _(
    'Notifications ${on ? 'turned on' : 'turned off'}',
    on ? 'تم تشغيل الإشعارات' : 'تم إيقاف الإشعارات',
  );
  String doneSearch(String q) => _('Searched for "$q"', 'تم البحث عن "$q"');
  String get askTheme => _('Which theme do you want?', 'أي مظهر تريد؟');
  String get askDestination =>
      _('Which page do you want to open?', 'أي صفحة تريد فتحها؟');
  String get askGeneric => _('Please choose one:', 'من فضلك اختر:');
  String get noneOfThese => _('None of these', 'لا شيء من هذه');
  String get cannotDo => _(
    "I can't do that. I can change the theme or open a page.",
    'لا أستطيع فعل ذلك. أستطيع تغيير المظهر أو فتح صفحة.',
  );
  String get rejected => _(
    "I understood something I can't safely do, so nothing was changed.",
    'فهمت شيئاً لا أستطيع تنفيذه بأمان، لذلك لم يتغير شيء.',
  );
  String get failed =>
      _('Something went wrong. Nothing was changed.', 'حدث خطأ. لم يتغير شيء.');
  String get dismissed => _('Okay, nothing changed.', 'حسناً، لم يتغير شيء.');

  // Details
  String get details => _('How this was handled', 'كيف تمت المعالجة');
  String get stepUnderstood => _('Understood', 'الفهم');
  String get stepChecked => _('Checked', 'التحقق');
  String get stepDone => _('Done', 'التنفيذ');
  String get youSaid => _('You said', 'قلتَ');
  String get modelOutput => _('Model output', 'ناتج النموذج');
  String get prediction => _('Prediction', 'التنبؤ');
  String get validation => _('Validation', 'التحقق');
  String get execution => _('Execution', 'التنفيذ');
  String get latency => _('Latency', 'الزمن');
  String get notExecuted => _('NOT EXECUTED', 'لم يُنفَّذ');
  String get executed => _('EXECUTED', 'نُفِّذ');
  String get valid => _('VALID', 'سليم');
  String get rejectedLabel => _('REJECTED', 'مرفوض');

  // Developer page
  String get devTitle => _('Developer tools', 'أدوات المطوّر');
  String get devIntro => _(
    'No AI here: paste a JSON prediction and watch it go through validation and execution.',
    'لا يوجد ذكاء اصطناعي هنا: ألصق تنبؤاً بصيغة JSON وشاهد كيف يمرّ بالتحقق والتنفيذ.',
  );
  String get submitPrediction => _('Submit prediction', 'إرسال التنبؤ');

  /// Example sentences shown as chips. They only fill the input box; the model
  /// decides what each one means.
  List<String> get suggestions => const [
    'Turn on dark mode',
    'خلي التطبيق دارك',
    'روح على البروفايل',
    'Open settings',
    'Change the theme',
    'ابعتلي إيميل',
  ];
}
