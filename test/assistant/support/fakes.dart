import 'package:assistant_poc/assistant/actions/assistant_action.dart';
import 'package:assistant_poc/assistant/execution/action_execution_result.dart';
import 'package:assistant_poc/assistant/execution/action_executor.dart';
import 'package:assistant_poc/assistant/models/action_parameters.dart';
import 'package:assistant_poc/assistant/validation/validation_result.dart';

/// Records every environment call so tests can prove nothing happened.
class RecordingEnvironment implements AssistantEnvironment {
  final List<String> calls = [];
  ThemeModeOption? themeMode;
  AppLanguage? language;
  AppDestination? destination;
  bool? notificationsEnabled;
  String? lastSearchQuery;

  @override
  void setThemeMode(ThemeModeOption mode) {
    calls.add('theme');
    themeMode = mode;
  }

  @override
  void setLanguage(AppLanguage l) {
    calls.add('language');
    language = l;
  }

  @override
  void navigateTo(AppDestination d) {
    calls.add('navigate');
    destination = d;
  }

  @override
  void setNotificationsEnabled(bool enabled) {
    calls.add('notifications');
    notificationsEnabled = enabled;
  }

  @override
  void setSearchQuery(String query) {
    calls.add('search');
    lastSearchQuery = query;
  }
}

/// Counts how many times the execution layer is reached.
class SpyExecutor extends ActionExecutor {
  SpyExecutor(super.registry, super.env);
  int executeCalls = 0;

  @override
  Future<ActionExecutionResult> execute(ValidatedAction validated) {
    executeCalls++;
    return super.execute(validated);
  }
}
