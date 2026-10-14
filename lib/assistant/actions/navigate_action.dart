import '../execution/action_execution_result.dart';
import '../models/action_parameters.dart';
import 'assistant_action.dart';
import 'clarification.dart';

class NavigateAction extends AssistantAction<NavigateParameters> {
  const NavigateAction();
  @override
  String get description => 'Open one of the app pages.';

  @override
  Map<String, Object?> get parametersSchema => {
    'type': 'object',
    'properties': {
      'destination': {
        'type': 'string',
        'description': 'The page to open.',
        'enum': [for (final d in AppDestination.values) d.name],
      },
    },
    'required': ['destination'],
  };

  @override
  List<ClarifiableParameter> get clarifiableParameters => [
    ClarifiableParameter('destination', [
      for (final d in AppDestination.values) d.name,
    ]),
  ];

  @override
  String get name => 'navigate';

  /// Only [AppDestination] values are reachable; raw route strings are never
  /// passed to the app.
  @override
  NavigateParameters readParameters(ParameterReader r) =>
      NavigateParameters(r.enumValue('destination', AppDestination.values));

  @override
  Future<ActionExecutionResult> execute(
    NavigateParameters p,
    AssistantEnvironment env,
  ) async {
    env.navigateTo(p.destination);
    return ActionExecutionResult.executed(
      name,
      'Navigated to ${p.destination.name}',
    );
  }
}
