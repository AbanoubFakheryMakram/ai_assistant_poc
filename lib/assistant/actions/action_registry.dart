import 'assistant_action.dart';
import 'change_language_action.dart';
import 'change_theme_action.dart';
import 'clarification.dart';
import 'navigate_action.dart';
import 'search_action.dart';
import 'tool_spec.dart';
import 'toggle_notifications_action.dart';

/// Single source of truth for executable actions. If an action is not listed
/// here it cannot be validated or executed, and no AI provider is ever offered
/// anything that is not generated from this list.
class ActionRegistry {
  ActionRegistry(Iterable<AssistantAction> actions)
    : _byName = {for (final a in actions) a.name: a} {
    assert(_byName.length == actions.length, 'Duplicate action names');
  }

  /// The explicit Phase 1 action list.
  factory ActionRegistry.standard() => ActionRegistry(const [
    ChangeThemeAction(),
    ChangeLanguageAction(),
    NavigateAction(),
    ToggleNotificationsAction(),
    SearchAction(),
  ]);

  /// Phase 2: the subset exposed to the AI. Anything else the model names
  /// (even a real Phase 1 action such as `change_language`) is rejected.
  factory ActionRegistry.phase2() =>
      ActionRegistry(const [ChangeThemeAction(), NavigateAction()]);

  final Map<String, AssistantAction> _byName;

  /// Name of the one function a model may call to say "ask the user".
  static const askUserToolName = 'ask_user';

  AssistantAction? lookup(String name) => _byName[name];

  Iterable<String> get names => _byName.keys;

  /// Every (action, parameter) the user can be asked about, keyed `action.param`.
  Map<String, ClarificationOffer> get clarificationOffers => {
    for (final a in _byName.values)
      for (final p in a.clarifiableParameters)
        '${a.name}.${p.name}': ClarificationOffer(
          actionName: a.name,
          parameterName: p.name,
          options: p.options,
        ),
  };

  /// The offer for [target] (e.g. `change_theme.mode`), or null if the registry
  /// does not allow asking about it. Used to turn a model's "ask the user"
  /// request into options the APPLICATION defines.
  ClarificationOffer? offerFor(Object? target) =>
      target is String ? clarificationOffers[target] : null;

  /// Function definitions for an AI provider, generated from this registry.
  /// With [allowClarification] a single extra function lets the model ask the
  /// user which value is meant; it cannot execute anything.
  List<ToolSpec> toolSpecs({bool allowClarification = false}) => [
    for (final a in _byName.values) a.toToolSpec(),
    if (allowClarification && clarificationOffers.isNotEmpty)
      ToolSpec(
        name: askUserToolName,
        description:
            'Ask the user to choose a missing value. Use it when the '
            'request clearly refers to one of the actions but does not say '
            'which value to use. It does not perform any action.',
        parameters: {
          'type': 'object',
          'properties': {
            'target': {
              'type': 'string',
              'description': 'The missing item the user must choose.',
              'enum': clarificationOffers.keys.toList(),
            },
          },
          'required': ['target'],
        },
      ),
  ];
}

/// The tools exposed to the AI in Phase 2 (no clarification function).
List<ToolSpec> get phase2ToolSpecs => ActionRegistry.phase2().toolSpecs();
