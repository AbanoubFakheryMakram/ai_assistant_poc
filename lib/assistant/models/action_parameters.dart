/// Typed, already-validated parameters. Only the actions create these.
sealed class ActionParameters {
  const ActionParameters();
}

enum ThemeModeOption { light, dark, system }

enum AppLanguage { en, ar }

/// The ONLY places the assistant may navigate to. Raw strings from a
/// prediction are mapped onto this enum; anything else is rejected.
enum AppDestination { home, profile, settings }

final class ChangeThemeParameters extends ActionParameters {
  const ChangeThemeParameters(this.mode);
  final ThemeModeOption mode;
}

final class ChangeLanguageParameters extends ActionParameters {
  const ChangeLanguageParameters(this.language);
  final AppLanguage language;
}

final class NavigateParameters extends ActionParameters {
  const NavigateParameters(this.destination);
  final AppDestination destination;
}

final class ToggleNotificationsParameters extends ActionParameters {
  const ToggleNotificationsParameters(this.enabled);
  final bool enabled;
}

final class SearchParameters extends ActionParameters {
  const SearchParameters(this.query);
  final String query;
}

/// Why a parameter map was refused.
enum ParameterProblem {
  missing,
  wrongType,
  invalidValue,
  emptyString,
  tooLong,
  unexpected,
}

class ParameterException implements Exception {
  const ParameterException(this.problem, this.message);
  final ParameterProblem problem;
  final String message;
  @override
  String toString() => message;
}

/// Strict reader over a raw parameter map. Throws [ParameterException] on the
/// first problem; call [finish] last to reject any unexpected keys.
class ParameterReader {
  ParameterReader(this._raw);
  final Map<Object?, Object?> _raw;
  final Set<String> _consumed = {};

  Object _require(String key) {
    _consumed.add(key);
    final v = _raw[key];
    if (!_raw.containsKey(key) || v == null) {
      throw ParameterException(
        ParameterProblem.missing,
        'Missing required parameter "$key".',
      );
    }
    return v;
  }

  /// Reads a string that must exactly equal one of the enum names.
  T enumValue<T extends Enum>(String key, List<T> values) {
    final v = _require(key);
    if (v is! String) {
      throw ParameterException(
        ParameterProblem.wrongType,
        'Parameter "$key" must be a string, got ${v.runtimeType}.',
      );
    }
    for (final e in values) {
      if (e.name == v) return e;
    }
    throw ParameterException(
      ParameterProblem.invalidValue,
      'Invalid value "$v" for "$key". Allowed: ${values.map((e) => e.name).join(', ')}.',
    );
  }

  /// Strict boolean: the strings "true"/"yes" are NOT accepted.
  bool boolValue(String key) {
    final v = _require(key);
    if (v is! bool) {
      throw ParameterException(
        ParameterProblem.wrongType,
        'Parameter "$key" must be a boolean, got ${v.runtimeType}.',
      );
    }
    return v;
  }

  /// Non-empty (after trim) string of at most [maxLength] characters.
  String nonEmptyString(String key, {int maxLength = 200}) {
    final v = _require(key);
    if (v is! String) {
      throw ParameterException(
        ParameterProblem.wrongType,
        'Parameter "$key" must be a string, got ${v.runtimeType}.',
      );
    }
    final t = v.trim();
    if (t.isEmpty) {
      throw ParameterException(
        ParameterProblem.emptyString,
        'Parameter "$key" must not be empty.',
      );
    }
    if (t.length > maxLength) {
      throw ParameterException(
        ParameterProblem.tooLong,
        'Parameter "$key" exceeds $maxLength characters.',
      );
    }
    return t;
  }

  /// Rejects any key that was not read. Unknown fields are never trusted.
  void finish() {
    final extra = _raw.keys.where((k) => !_consumed.contains(k)).toList();
    if (extra.isNotEmpty) {
      throw ParameterException(
        ParameterProblem.unexpected,
        'Unexpected parameter(s): ${extra.join(', ')}.',
      );
    }
  }
}
