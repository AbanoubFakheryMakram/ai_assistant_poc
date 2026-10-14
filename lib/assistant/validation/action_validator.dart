import '../actions/action_registry.dart';
import '../models/action_prediction.dart';
import 'validation_result.dart';

/// Turns an untrusted [ActionPrediction] into a [ValidatedAction] or a
/// rejection. Has no knowledge of execution or of any AI model.
///
/// Policy (strict): unknown top-level fields, unknown parameters, wrong types
/// and out-of-enum values are all REJECTED, never ignored or coerced.
class ActionValidator {
  const ActionValidator(this._registry);
  final ActionRegistry _registry;

  ValidationResult validate(ActionPrediction p) {
    if (p.isMalformed) {
      return ValidationRejected(
        RejectionReason.malformedPrediction,
        p.malformedReason!,
      );
    }
    if (p.unexpectedKeys.isNotEmpty) {
      return ValidationRejected(
        RejectionReason.unexpectedField,
        'Unexpected field(s): ${p.unexpectedKeys.join(', ')}.',
      );
    }

    final status = PredictionStatus.fromWire(p.status);
    switch (status) {
      case null:
        return ValidationRejected(
          RejectionReason.unknownStatus,
          'Missing or unknown status: ${p.status}.',
        );
      case PredictionStatus.clarificationRequired:
        return const ValidationRejected(
          RejectionReason.clarificationRequired,
          'Clarification required; nothing to execute.',
        );
      case PredictionStatus.unsupported:
        return const ValidationRejected(
          RejectionReason.unsupportedRequest,
          'Request unsupported; nothing to execute.',
        );
      case PredictionStatus.success:
        break;
    }

    final name = p.action;
    if (name == null || (name is String && name.trim().isEmpty)) {
      return const ValidationRejected(
        RejectionReason.missingAction,
        'No action provided.',
      );
    }
    if (name is! String) {
      return ValidationRejected(
        RejectionReason.malformedPrediction,
        'Action must be a string, got ${name.runtimeType}.',
      );
    }
    final action = _registry.lookup(name);
    if (action == null) {
      return ValidationRejected(
        RejectionReason.unknownAction,
        'Unknown action "$name".',
      );
    }

    final params = p.parameters;
    if (params == null) {
      return const ValidationRejected(
        RejectionReason.nullParameters,
        'Parameters are required but were null.',
      );
    }
    if (params is! Map) {
      return ValidationRejected(
        RejectionReason.invalidParametersObject,
        'Parameters must be an object, got ${params.runtimeType}.',
      );
    }
    return action.validateParameters(params);
  }
}
