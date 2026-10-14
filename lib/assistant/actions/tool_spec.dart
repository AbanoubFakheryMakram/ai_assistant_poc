/// Model-agnostic description of one function exposed to an AI provider. It is
/// generated from the application's action definitions (never hand-written per
/// model), so a provider can only ever be offered what the registry contains.
class ToolSpec {
  const ToolSpec({
    required this.name,
    required this.description,
    required this.parameters,
  });
  final String name;
  final String description;

  /// JSON-Schema object describing the arguments.
  final Map<String, Object?> parameters;
}
