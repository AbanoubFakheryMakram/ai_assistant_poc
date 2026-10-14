import '../actions/action_registry.dart';
import '../actions/clarification.dart';
import '../models/action_prediction.dart';
import '../validation/action_validator.dart';
import '../validation/validation_result.dart';
import 'action_execution_result.dart';
import 'action_executor.dart';

class PipelineOutcome {
  const PipelineOutcome(
    this.prediction,
    this.validation,
    this.execution, {
    this.clarification,
  });
  final ActionPrediction prediction;
  final ValidationResult validation;

  /// Null whenever validation rejected the prediction (nothing was executed).
  final ActionExecutionResult? execution;

  /// Set when the model asked the user to choose a missing value. The options
  /// come from the application's registry; nothing has been executed.
  final ClarificationOffer? clarification;
}

/// Prediction -> Validation -> Execution. The executor is reachable only
/// through an accepted validation result.
class AssistantPipeline {
  AssistantPipeline(this._validator, this._executor, {this.registry});
  final ActionValidator _validator;
  final ActionExecutor _executor;

  /// Optional: lets a model's "ask the user" request be turned into options.
  final ActionRegistry? registry;

  Future<PipelineOutcome> process(ActionPrediction prediction) async {
    final validation = _validator.validate(prediction);
    return switch (validation) {
      ValidationAccepted(:final validated) => PipelineOutcome(
        prediction,
        validation,
        await _executor.execute(validated),
      ),
      ValidationRejected() => PipelineOutcome(
        prediction,
        validation,
        null,
        clarification: _offerFor(prediction, validation),
      ),
    };
  }

  /// The USER's answer to a [ClarificationOffer]. It becomes an ordinary
  /// prediction and goes through the same validator, registry and executor as
  /// everything else, so a chosen value is checked exactly like a model's.
  Future<PipelineOutcome> resolveClarification(
    ClarificationOffer offer,
    String choice,
  ) => process(
    ActionPrediction(
      status: 'success',
      action: offer.actionName,
      parameters: <String, Object?>{offer.parameterName: choice},
    ),
  );

  ClarificationOffer? _offerFor(
    ActionPrediction p,
    ValidationRejected rejected,
  ) {
    if (rejected.reason != RejectionReason.clarificationRequired) return null;
    final params = p.parameters;
    if (params is! Map) return null;
    return registry?.offerFor(params['target']);
  }
}
