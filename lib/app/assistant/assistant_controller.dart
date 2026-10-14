import 'package:flutter/foundation.dart';

import '../../assistant/actions/clarification.dart';
import '../../assistant/execution/assistant_pipeline.dart';
import '../../assistant/providers/assistant_model.dart';
import '../../assistant/validation/validation_result.dart';
import '../model_host.dart';

enum TurnStatus {
  /// The model is working.
  thinking,

  /// A validated action ran.
  executed,

  /// The user must choose a missing value. Nothing has run yet.
  needsChoice,

  /// The request is not something the application can do. Nothing ran.
  cannotDo,

  /// The model proposed something the validator refused. Nothing ran.
  rejected,

  /// The model or pipeline failed. Nothing ran.
  failed,

  /// The user dismissed a question. Nothing ran.
  dismissed,
}

/// One request and everything that happened to it.
class AssistantTurn {
  AssistantTurn(this.input);
  final String input;
  TurnStatus status = TurnStatus.thinking;
  ModelInterpretation? interpretation;
  PipelineOutcome? outcome;
  ClarificationOffer? offer;

  /// Outcome of the user's choice, if they answered a question.
  PipelineOutcome? resolution;
  String? chosen;
  String? error;

  /// The outcome that actually decided the result.
  PipelineOutcome? get finalOutcome => resolution ?? outcome;
}

/// Runs the pipeline for the UI. It depends on the model only through
/// [ModelHost] (abstractions) and never executes anything itself: execution
/// happens inside [AssistantPipeline] after validation.
class AssistantController extends ChangeNotifier {
  AssistantController({required this.pipeline, required this.host});

  final AssistantPipeline pipeline;
  final ModelHost host;

  AssistantTurn? current;
  bool get busy => current?.status == TurnStatus.thinking;

  Future<void> submit(String text) async {
    final input = text.trim();
    final model = host.model;
    if (input.isEmpty || model == null || busy) return;
    final turn = AssistantTurn(input);
    current = turn;
    notifyListeners();
    try {
      final interp = await model.interpretWithTrace(input);
      final outcome = await pipeline.process(interp.prediction);
      turn
        ..interpretation = interp
        ..outcome = outcome
        ..offer = outcome.clarification
        ..status = _statusOf(outcome);
    } catch (e) {
      turn
        ..error = '$e'
        ..status = TurnStatus.failed;
    }
    notifyListeners();
  }

  /// The user's answer to a question. Goes through the same pipeline as any
  /// other prediction, so the chosen value is validated before anything runs.
  Future<void> choose(String option) async {
    final turn = current;
    final offer = turn?.offer;
    if (turn == null ||
        offer == null ||
        turn.status != TurnStatus.needsChoice) {
      return;
    }
    turn.chosen = option;
    try {
      final r = await pipeline.resolveClarification(offer, option);
      turn
        ..resolution = r
        ..status = r.execution?.isExecuted == true
            ? TurnStatus.executed
            : TurnStatus.rejected;
    } catch (e) {
      turn
        ..error = '$e'
        ..status = TurnStatus.failed;
    }
    notifyListeners();
  }

  void dismissQuestion() {
    final turn = current;
    if (turn == null || turn.status != TurnStatus.needsChoice) return;
    turn.status = TurnStatus.dismissed;
    notifyListeners();
  }

  void clear() {
    current = null;
    notifyListeners();
  }

  static TurnStatus _statusOf(PipelineOutcome o) {
    final v = o.validation;
    if (v is ValidationAccepted) {
      return o.execution?.isExecuted == true
          ? TurnStatus.executed
          : TurnStatus.failed;
    }
    if (o.clarification != null) return TurnStatus.needsChoice;
    if (v is ValidationRejected) {
      return switch (v.reason) {
        RejectionReason.unsupportedRequest ||
        RejectionReason.clarificationRequired => TurnStatus.cannotDo,
        _ => TurnStatus.rejected,
      };
    }
    return TurnStatus.failed;
  }
}
