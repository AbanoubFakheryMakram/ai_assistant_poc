# Security model

The one rule: **the AI interprets; the application validates and executes.** A model's output is treated as untrusted input,
like text typed by a stranger.

```
User text -> local model -> raw output (untrusted)
          -> adapter -> ActionPrediction (untrusted)
          -> ActionValidator (strict schema, enums, types)
          -> ActionRegistry (the only list of executable actions)
          -> ActionExecutor -> AssistantEnvironment (a fixed, typed set of operations)
```

## What the model can and cannot do

| Can | Cannot |
|---|---|
| Return one function call, or prose, or nothing | Run code, call Dart methods, touch the filesystem, network or platform APIs |
| Name an action from the list it was given | Add an action: anything not in the registry is rejected |
| Propose a parameter value | Bypass validation: wrong type, missing, extra or out-of-enum values are rejected |
| Say "ask the user" about a registered `action.parameter` | Invent the options, choose among them, or execute: the app builds the options from its own enums and the user decides |
| Refuse (no function call) | Make the app show or run its own text: refusals are replaced by a fixed message |

## Guarantees and the tests that enforce them

| Guarantee | Enforced by |
|---|---|
| Rejected input is never executed (executor not called, app not touched) | `test/assistant/execution/pipeline_test.dart` (spy executor), `clarification_test.dart` |
| Unknown action, missing/invalid/extra parameters, malformed JSON, null parameters are rejected | `test/assistant/validation/validator_test.dart`, dataset `evaluation/phase_1_commands.json` (47 cases) |
| `clarification_required`, `unsupported` and unknown statuses never execute | validator tests |
| Several function calls are rejected; "first call wins" never happens | `model_output_adapter_test.dart`, `recovery_test.dart` |
| Prose is never parsed into an action | adapter tests |
| An actions that exists but is not exposed to the AI (for example `change_language` in Phase 2) is rejected | `model_output_adapter_test.dart`, `assistant_ui_test.dart` |
| A model's "ask the user" cannot add options, pick a value or target a non-allowed action | `clarification_test.dart` |
| The user's choice is validated like any other prediction | `clarification_test.dart` |
| Navigation only reaches `home`, `profile`, `settings` (an enum, never a route string) | validator and UI tests |
| Search text is plain data (never a route, command or function name) | `search_action.dart`, validator tests |
| The app does not depend on a specific model or on the inference package outside one file | `test/architecture_test.dart` |
| Frozen baseline files cannot change silently | hash test in `test/assistant/evaluation/recovery_test.dart` |

## Measured safety (all on-device runs)

Across every evaluation run (3 models x multiple datasets, several hundred model outputs): **0 uncontrolled executions and
0 invalid outputs executed.** The result files record this per run (`metrics.uncontrolledExecutions`,
`metrics.invalidOutputsExecuted`).

## What validation cannot protect against

Validation guarantees the app only does something from the allowed list with legal values. It cannot know the model
**misread the user**. Gemma 4 E2B, for example, executed `change_theme(system)` for "Change the theme" and
`navigate(settings)` for "delete my account": legal actions, wrong intent. These are correctness mistakes, not safety
violations. The clarification flow (`docs/phase-2-recovery-round3.md`) addresses the first kind by asking the user.

## Not covered (yet)

No risk levels, confirmation dialogs for sensitive actions, rate limiting or audit log (later phases). The five actions in this
project are all low-risk UI actions. The model files are downloaded from Hugging Face over HTTPS without a pinned
signature; the SHA-256 should be checked by hand (`docs/running-the-evaluation.md`).
