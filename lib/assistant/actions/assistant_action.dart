import '../execution/action_execution_result.dart';
import 'clarification.dart';
import 'tool_spec.dart';
import '../models/action_parameters.dart';
import '../validation/validation_result.dart';

/// The only surface through which actions touch the application.
/// Every method is a fixed, typed operation - no routes, callbacks or
/// arbitrary strings cross this boundary.
abstract interface class AssistantEnvironment {
  void setThemeMode(ThemeModeOption mode);
  void setLanguage(AppLanguage language);
  void navigateTo(AppDestination destination);
  void setNotificationsEnabled(bool enabled);
  void setSearchQuery(String query);
}

/// Definition of one supported action: its name, its strict parameter schema
/// and its implementation. Registered explicitly in [ActionRegistry].
abstract class AssistantAction<P extends ActionParameters> {
  const AssistantAction();

  String get name;

  /// One sentence describing what the action does, for the AI provider.
  String get description;

  /// JSON-Schema of the parameters, for the AI provider. Kept next to the
  /// validation code so the two cannot drift apart.
  Map<String, Object?> get parametersSchema;

  /// Parameters the user can be asked to choose when a request omits them.
  List<ClarifiableParameter> get clarifiableParameters => const [];

  ToolSpec toToolSpec() => ToolSpec(
    name: name,
    description: description,
    parameters: parametersSchema,
  );

  /// Reads typed parameters from the strict [reader]. Throw
  /// [ParameterException] (via the reader) on any problem.
  P readParameters(ParameterReader reader);

  Future<ActionExecutionResult> execute(P parameters, AssistantEnvironment env);

  /// Schema validation: raw map -> typed parameters, or a rejection.
  ValidationResult validateParameters(Map<Object?, Object?> raw) {
    try {
      final reader = ParameterReader(raw);
      final params = readParameters(reader);
      reader.finish();
      return ValidationAccepted(ValidatedAction(this, params));
    } on ParameterException catch (e) {
      return ValidationRejected(_reasonFor(e.problem), e.message);
    }
  }

  /// Runs a validated action. Only [ActionExecutor] should call this.
  Future<ActionExecutionResult> run(
    ValidatedAction validated,
    AssistantEnvironment env,
  ) {
    final p = validated.parameters;
    if (p is! P) {
      return Future.value(
        ActionExecutionResult.failed(
          name,
          'Parameter type mismatch for "$name".',
        ),
      );
    }
    return execute(p, env);
  }

  static RejectionReason _reasonFor(ParameterProblem p) => switch (p) {
    ParameterProblem.missing => RejectionReason.missingParameter,
    ParameterProblem.wrongType => RejectionReason.invalidParameterType,
    ParameterProblem.invalidValue => RejectionReason.invalidParameterValue,
    ParameterProblem.emptyString => RejectionReason.emptyParameter,
    ParameterProblem.tooLong => RejectionReason.parameterTooLong,
    ParameterProblem.unexpected => RejectionReason.unexpectedParameter,
  };
}
