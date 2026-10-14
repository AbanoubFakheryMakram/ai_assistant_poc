/// A parameter of an action whose value the USER may be asked to choose from a
/// closed set. The options come from the application's own enums.
class ClarifiableParameter {
  const ClarifiableParameter(this.name, this.options);
  final String name;
  final List<String> options;
}

/// "Which value do you mean?" for one action parameter, built by the
/// application from the registry. The model only names the target; it can
/// neither add options nor choose among them.
class ClarificationOffer {
  const ClarificationOffer({
    required this.actionName,
    required this.parameterName,
    required this.options,
  });
  final String actionName;
  final String parameterName;
  final List<String> options;

  /// Stable key such as `change_theme.mode`.
  String get target => '$actionName.$parameterName';
}
