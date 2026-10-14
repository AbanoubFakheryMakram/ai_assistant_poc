import '../actions/action_registry.dart';
import '../models/action_prediction.dart';
import 'assistant_model.dart';

/// Provider-neutral view of what a model emitted: function calls (if any)
/// and plain text. No flutter_gemma types here.
class RawModelOutput {
  const RawModelOutput({this.calls = const [], this.text = ''});
  final List<RawFunctionCall> calls;
  final String text;

  ModelOutputKind get kind {
    if (calls.length == 1) return ModelOutputKind.functionCall;
    if (calls.length > 1) return ModelOutputKind.multipleCalls;
    return text.trim().isEmpty ? ModelOutputKind.empty : ModelOutputKind.prose;
  }

  /// Human/debug representation stored in evaluation logs.
  String describe() {
    final parts = <String>[
      for (final c in calls) 'call ${c.name}(${c.args})',
      if (text.trim().isNotEmpty) 'text "${text.trim()}"',
    ];
    return parts.isEmpty ? '(empty output)' : parts.join(' | ');
  }
}

class RawFunctionCall {
  const RawFunctionCall(this.name, this.args);
  final String name;
  final Map<String, Object?> args;
}

/// Converts untrusted model output into an untrusted [ActionPrediction].
///
/// It deliberately does NOT repair or interpret anything: names and argument
/// values are passed through unchanged so the validator sees exactly what the
/// model said. Whether a function is allowed is decided by the validator's
/// registry, not here.
class ModelOutputAdapter {
  const ModelOutputAdapter();

  ActionPrediction adapt(RawModelOutput out) {
    if (out.calls.isEmpty) {
      // The model chose not to call any function (prose or silence). No text
      // is parsed or interpreted; this is simply "no action".
      return const ActionPrediction(
        status: 'unsupported',
        action: null,
        parameters: <String, Object?>{},
      );
    }
    if (out.calls.length > 1) {
      return ActionPrediction(
        malformedReason:
            'multiple_function_calls: model emitted ${out.calls.length} function calls; exactly one is allowed (none executed).',
      );
    }
    final call = out.calls.single;
    if (call.name == ActionRegistry.askUserToolName) {
      // "Ask the user which value is meant." It carries no value and executes
      // nothing; the application decides whether the target is allowed.
      return ActionPrediction(
        status: 'clarification_required',
        action: null,
        parameters: <String, Object?>{'target': call.args['target']},
      );
    }
    if (call.name.trim().isEmpty) {
      return const ActionPrediction(
        malformedReason: 'Function call without a name.',
      );
    }
    return ActionPrediction(
      status: 'success',
      action: call.name,
      parameters: call.args,
    );
  }
}
