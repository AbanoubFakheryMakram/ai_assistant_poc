import '../execution/action_execution_result.dart';
import '../models/action_parameters.dart';
import 'assistant_action.dart';
import 'clarification.dart';

class ChangeLanguageAction extends AssistantAction<ChangeLanguageParameters> {
  const ChangeLanguageAction();
  @override
  String get description =>
      "Change the application's UI language. It does not translate arbitrary text.";

  @override
  Map<String, Object?> get parametersSchema => {
    'type': 'object',
    'properties': {
      'language': {
        'type': 'string',
        'description': 'The interface language.',
        'enum': [for (final l in AppLanguage.values) l.name],
      },
    },
    'required': ['language'],
  };

  @override
  List<ClarifiableParameter> get clarifiableParameters => [
    ClarifiableParameter('language', [
      for (final l in AppLanguage.values) l.name,
    ]),
  ];

  @override
  String get name => 'change_language';

  @override
  ChangeLanguageParameters readParameters(ParameterReader r) =>
      ChangeLanguageParameters(r.enumValue('language', AppLanguage.values));

  @override
  Future<ActionExecutionResult> execute(
    ChangeLanguageParameters p,
    AssistantEnvironment env,
  ) async {
    env.setLanguage(p.language);
    return ActionExecutionResult.executed(
      name,
      'Language set to ${p.language.name}',
    );
  }
}
