import '../actions/action_registry.dart';
import '../actions/assistant_action.dart';
import '../validation/validation_result.dart';
import 'action_execution_result.dart';

/// Executes ONLY validated, registry-resolved actions. It accepts no raw JSON,
/// route names or callbacks, and has no dependency on any AI model.
class ActionExecutor {
  ActionExecutor(this._registry, this._env);
  final ActionRegistry _registry;
  final AssistantEnvironment _env;

  Future<ActionExecutionResult> execute(ValidatedAction validated) async {
    final registered = _registry.lookup(validated.name);
    if (registered == null || !identical(registered, validated.action)) {
      return ActionExecutionResult.failed(
        validated.name,
        'Action is not registered; refusing to execute.',
      );
    }
    try {
      return await registered.run(validated, _env);
    } catch (e) {
      return ActionExecutionResult.failed(
        validated.name,
        'Execution error: $e',
      );
    }
  }
}
