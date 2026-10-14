import 'package:flutter/material.dart';

import '../assistant/actions/assistant_action.dart';
import '../assistant/models/action_parameters.dart';

/// Demo app state. Also the [AssistantEnvironment] the actions operate on: the
/// only thing an executed action can touch.
class AppState extends ChangeNotifier implements AssistantEnvironment {
  ThemeModeOption themeMode = ThemeModeOption.light;
  AppLanguage language = AppLanguage.en;
  AppDestination destination = AppDestination.home;
  bool notificationsEnabled = true;
  String? lastSearchQuery;

  ThemeMode get flutterThemeMode => switch (themeMode) {
    ThemeModeOption.light => ThemeMode.light,
    ThemeModeOption.dark => ThemeMode.dark,
    ThemeModeOption.system => ThemeMode.system,
  };

  Locale get locale => Locale(language.name);

  @override
  void setThemeMode(ThemeModeOption mode) {
    themeMode = mode;
    notifyListeners();
  }

  @override
  void setLanguage(AppLanguage l) {
    language = l;
    notifyListeners();
  }

  @override
  void navigateTo(AppDestination d) {
    destination = d;
    notifyListeners();
  }

  @override
  void setNotificationsEnabled(bool enabled) {
    notificationsEnabled = enabled;
    notifyListeners();
  }

  @override
  void setSearchQuery(String query) {
    lastSearchQuery = query;
    notifyListeners();
  }
}
