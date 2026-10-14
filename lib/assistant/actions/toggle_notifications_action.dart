import '../execution/action_execution_result.dart';
import '../models/action_parameters.dart';
import 'assistant_action.dart';

class ToggleNotificationsAction
    extends AssistantAction<ToggleNotificationsParameters> {
  const ToggleNotificationsAction();
  @override
  String get description => 'Turn the application notifications on or off.';

  @override
  Map<String, Object?> get parametersSchema => {
    'type': 'object',
    'properties': {
      'enabled': {
        'type': 'boolean',
        'description': 'true to enable notifications, false to disable them.',
      },
    },
    'required': ['enabled'],
  };

  @override
  String get name => 'toggle_notifications';

  @override
  ToggleNotificationsParameters readParameters(ParameterReader r) =>
      ToggleNotificationsParameters(r.boolValue('enabled'));

  @override
  Future<ActionExecutionResult> execute(
    ToggleNotificationsParameters p,
    AssistantEnvironment env,
  ) async {
    env.setNotificationsEnabled(p.enabled);
    return ActionExecutionResult.executed(
      name,
      'Notifications ${p.enabled ? 'enabled' : 'disabled'}',
    );
  }
}
