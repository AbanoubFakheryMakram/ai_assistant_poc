import '../execution/action_execution_result.dart';
import '../models/action_parameters.dart';
import 'assistant_action.dart';
import 'clarification.dart';

class ChangeThemeAction extends AssistantAction<ChangeThemeParameters> {
  const ChangeThemeAction();
  @override
  String get description =>
      'Change the app theme (light, dark or follow the system).';

  @override
  Map<String, Object?> get parametersSchema => {
    'type': 'object',
    'properties': {
      'mode': {
        'type': 'string',
        'description': 'The theme to apply.',
        'enum': [for (final m in ThemeModeOption.values) m.name],
      },
    },
    'required': ['mode'],
  };

  @override
  List<ClarifiableParameter> get clarifiableParameters => [
    ClarifiableParameter('mode', [
      for (final m in ThemeModeOption.values) m.name,
    ]),
  ];

  @override
  String get name => 'change_theme';

  @override
  ChangeThemeParameters readParameters(ParameterReader r) =>
      ChangeThemeParameters(r.enumValue('mode', ThemeModeOption.values));

  @override
  Future<ActionExecutionResult> execute(
    ChangeThemeParameters p,
    AssistantEnvironment env,
  ) async {
    env.setThemeMode(p.mode);
    return ActionExecutionResult.executed(name, 'Theme set to ${p.mode.name}');
  }
}
