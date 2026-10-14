/// Short, strict instructions for the interpreter. Safety does NOT rely on
/// this text; the validator is the authority.
const String assistantSystemInstruction =
    'You translate the user\'s request into one of the explicitly provided '
    'application functions. Never invent functions. Never invent parameter '
    'values. If the request cannot be confidently mapped to an available '
    'function, or a required value is missing, do not call a function.';

/// A few hand-picked examples (not taken from the evaluation dataset; a unit
/// test enforces zero overlap). Rendered into the system instruction because
/// FunctionGemma is driven by the tool-declaration template.
const List<(String, String)> assistantFewShotExamples = [
  // English
  ('Turn on dark mode', 'change_theme(mode="dark")'),
  ('Switch to light theme', 'change_theme(mode="light")'),
  ('Open my profile', 'navigate(destination="profile")'),
  ('Go to settings', 'navigate(destination="settings")'),
  // Arabic
  ('خلي التطبيق دارك', 'change_theme(mode="dark")'),
  ('حول للوضع الليلي', 'change_theme(mode="dark")'),
  ('افتح البروفايل', 'navigate(destination="profile")'),
  ('روح للإعدادات', 'navigate(destination="settings")'),
  // Egyptian Arabic
  ('يا عم خلّي التطبيق دارك', 'change_theme(mode="dark")'),
  ('خلي الثيم فاتح', 'change_theme(mode="light")'),
  ('روح على البروفايل', 'navigate(destination="profile")'),
  ('افتحلي الإعدادات', 'navigate(destination="settings")'),
  // Mixed
  ('خلي الـtheme dark', 'change_theme(mode="dark")'),
  ('افتح الـprofile', 'navigate(destination="profile")'),
  ('روح على settings', 'navigate(destination="settings")'),
  ('خلي التطبيق light', 'change_theme(mode="light")'),
  // Must NOT call a function
  ('Call my brother', '(no function call)'),
];

/// The full instruction text sent to the model.
String buildSystemInstruction() {
  final b = StringBuffer(assistantSystemInstruction)..writeln('\n\nExamples:');
  for (final (input, output) in assistantFewShotExamples) {
    b.writeln('"$input" -> $output');
  }
  return b.toString().trimRight();
}

/// A named, immutable instruction configuration. Prompts are versioned so
/// results can always be traced to the exact text the model saw.
class PromptVersion {
  const PromptVersion(this.id, this.build);
  final String id;

  /// Builds the system instruction from the tools actually exposed, so the
  /// text can never mention an action the application did not register.
  final String Function(List<String> toolNames) build;
}

/// The instruction used for the FunctionGemma 270M baseline (frozen).
final PromptVersion promptFunctionGemmaV1 = PromptVersion(
  'functiongemma_prompt_v1',
  (_) => buildSystemInstruction(),
);

/// Recovery experiment, version 1: the simplest valid prompt (zero-shot).
/// Model-neutral, so every candidate in the recovery experiment sees the same text.
final PromptVersion promptRecoveryV1 = PromptVersion('recovery_prompt_v1', (
  tools,
) {
  final actions = tools.map((t) => '- $t').join('\n');
  return 'You translate the user\'s request into exactly one supported '
      'application action.\n\n'
      'Available actions:\n$actions\n\n'
      'Never invent actions.\n'
      'Never invent parameter values.\n'
      'Do not call an action when the user\'s intent is unclear.\n'
      'If the request does not correspond to a supported action, do not '
      'produce an unrelated action.\n\n'
      'Return a single structured function call when the request clearly maps '
      'to an available action.';
});

/// Round 2, version 2: version 1 plus an explicit abstention rule. No examples.
final PromptVersion promptRecoveryV2 = PromptVersion('recovery_prompt_v2', (
  tools,
) {
  return '${promptRecoveryV1.build(tools)}\n\n'
      'Never guess a parameter value the user did not state. If a value the '
      'action needs (for example which theme, or which page) is missing, do '
      'not call a function.\n'
      'If the user asks for something the available actions cannot do, do not '
      'call a function, and do not pick the closest available action instead.';
});

/// Negative examples used by version 3: requests that must NOT produce a
/// function call. Written by category (capability the app lacks, missing
/// value); a unit test guarantees none of them appears in any dataset.
const List<String> recoveryNegativeExamples = [
  'Send a message to my sister',
  'Pay my electricity bill',
  'Make the app prettier',
  'Show me another screen',
  'احجز لي تذكرة طيران',
  'حدّث مظهر الواجهة',
  'اطلبلي أكل',
  'غيّرلي الستايل',
  'ابعت message لـmama',
  'افتحلي صفحة تانية',
];

/// Round 2, version 3: version 2 plus negative examples.
final PromptVersion promptRecoveryV3 = PromptVersion('recovery_prompt_v3', (
  tools,
) {
  final b = StringBuffer(promptRecoveryV2.build(tools))
    ..writeln('\n\nThese requests must NOT call any function:');
  for (final e in recoveryNegativeExamples) {
    b.writeln('- "$e"');
  }
  return b.toString().trimRight();
});

/// Round 3, version 4: instead of asking the model to stay silent when a value
/// is missing (which it did not do), give it a legitimate way to say "ask the
/// user". The application then shows options taken from its own registry and the
/// USER decides. Zero-shot, no examples.
final PromptVersion promptClarifyV4 = PromptVersion('clarify_prompt_v4', (
  tools,
) {
  const ask = 'ask_user';
  final actions = tools.where((t) => t != ask).map((t) => '- $t').join('\n');
  final b = StringBuffer(
    'You translate the user\'s request into exactly one supported '
    'application action.\n\n'
    'Available actions:\n$actions\n\n'
    'Never invent actions.\n'
    'Never invent parameter values.\n\n',
  );
  if (tools.contains(ask)) {
    b.write(
      'If the request clearly refers to one of the actions but does not say '
      'which value to use (for example which theme, or which page), call '
      '$ask with the missing item. Do not guess the value.\n',
    );
  }
  b.write(
    'If the request is something the available actions cannot do, answer '
    'without calling any function.\n'
    'Otherwise, return a single structured function call.',
  );
  return b.toString();
});

/// Every prompt version ever evaluated, by id (so a result file's
/// `promptVersion` can always be traced back to the exact text).
final List<PromptVersion> allPromptVersions = [
  promptFunctionGemmaV1,
  promptRecoveryV1,
  promptRecoveryV2,
  promptRecoveryV3,
  promptClarifyV4,
];

PromptVersion promptVersionById(String id) => allPromptVersions.firstWhere(
  (p) => p.id == id,
  orElse: () => throw ArgumentError(
    'Unknown prompt "$id". Known: ${allPromptVersions.map((p) => p.id).join(', ')}',
  ),
);
