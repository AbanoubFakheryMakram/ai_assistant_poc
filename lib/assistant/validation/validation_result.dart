import '../actions/assistant_action.dart';
import '../models/action_parameters.dart';

/// A prediction that passed every check, bound to its registered action.
final class ValidatedAction {
  const ValidatedAction(this.action, this.parameters);
  final AssistantAction action;
  final ActionParameters parameters;
  String get name => action.name;
}

enum RejectionReason {
  malformedPrediction,
  unknownStatus,
  clarificationRequired,
  unsupportedRequest,
  missingAction,
  unknownAction,
  nullParameters,
  invalidParametersObject,
  missingParameter,
  invalidParameterType,
  invalidParameterValue,
  emptyParameter,
  parameterTooLong,
  unexpectedParameter,
  unexpectedField,
}

sealed class ValidationResult {
  const ValidationResult();
}

final class ValidationAccepted extends ValidationResult {
  const ValidationAccepted(this.validated);
  final ValidatedAction validated;
}

final class ValidationRejected extends ValidationResult {
  const ValidationRejected(this.reason, this.message);
  final RejectionReason reason;
  final String message;
}
