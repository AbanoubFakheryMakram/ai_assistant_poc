# Architecture

## The one rule

**The AI interprets. The application validates and executes.** A model's output is untrusted data, never code and never a
reference to code.

```
                         +-----------------------------------------------------------+
 User text --> UI --->   |  AssistantModel (interface)   <-- any local model         |
                         +----------------------+------------------------------------+
                                                | raw output (function call / prose / nothing)
                                                v
                                       ModelOutputAdapter
                                                | ActionPrediction (untrusted)
                                                v
                  ActionValidator --rejects--> (nothing runs; maybe a question for the user)
                                                | ValidatedAction
                                                v
                     ActionRegistry --> ActionExecutor --> AssistantEnvironment (typed operations on AppState)
```

## Layers and what each may depend on

| Layer | Path | Depends on | Must not depend on |
|---|---|---|---|
| Core | `lib/assistant/{models,actions,validation,execution}` | itself (pure Dart) | providers, evaluation, UI, Flutter, the inference package |
| Providers | `lib/assistant/providers/` | core | UI; the inference package (except one file) |
| Runtime | `providers/flutter_gemma_assistant_model.dart` | everything above, the inference package | anything model-specific (it is driven by `LocalModelConfig`) |
| Catalog | `providers/model_catalog.dart`, `local_model_config.dart`, `model_prompt.dart` | nothing but each other | any package type |
| Evaluation | `lib/assistant/evaluation/` | core, provider interfaces | runtime, factory, UI |
| UI | `lib/app/` | core, provider interfaces, catalog data | runtime, factory, inference package |
| Composition root | `lib/main.dart`, `providers/local_model_factory.dart` | everything | n/a |

`test/architecture_test.dart` fails the build if any of these rules is broken, if a model name appears outside the data files,
or if a second file imports the inference package.

## Core concepts

**`ActionPrediction`** (`models/action_prediction.dart`). What an interpreter returned:
`{"status": "success|clarification_required|unsupported", "action": ..., "parameters": ...}`. Every field is `Object?`; invalid JSON
becomes a "malformed" prediction instead of throwing.

**`AssistantAction`** (`actions/assistant_action.dart`). One class per action: name, one-sentence description, the JSON schema
of its parameters, a strict `readParameters` (typed result), the clarifiable parameters, and `execute`. The schema sits next to the
validation code so they cannot drift.

**`ActionRegistry`** (`actions/action_registry.dart`). The single source of truth. `standard()` has all five actions;
`phase2()` has the two exposed to the AI. It also generates the tool definitions for any provider (`toolSpecs`) and resolves
"ask the user" targets into options (`offerFor`). Nothing outside the registry is ever offered to a model or executed.

**`ActionValidator`** (`validation/`). Rejects: malformed input, unexpected fields, unknown or missing status, non-success
status, missing/unknown action, null or non-object parameters, missing / wrong-type / out-of-enum / empty / too-long values, and
**any unexpected parameter** (reject, never ignore). Returns a typed `ValidatedAction` or a `ValidationRejected` with a reason.

**`ActionExecutor`** (`execution/`). Accepts only a `ValidatedAction`, re-resolves it through the registry, and runs the
registered implementation against `AssistantEnvironment`, a small interface of typed operations (`setThemeMode`,
`navigateTo`, ...). No raw JSON, route strings or callbacks cross this boundary.

**`AssistantPipeline`** (`execution/assistant_pipeline.dart`). Prediction -> validation -> execution. The executor is reachable
only from an accepted validation result. It also turns a model's "ask the user" into a `ClarificationOffer` (options from the
registry) and runs the user's answer back through the same validation (`resolveClarification`).

## Models behind an interface

`AssistantModel.interpret(String)` is the whole contract. `TracedAssistantModel` adds raw output and latency (for
evaluation); `LoadableAssistantModel` adds `load()` / `dispose()` (for the UI).

* `LocalModelConfig` is plain data: id, display name, model family (`ModelFamily` enum), file/URL, size, prompt version, backend,
  token limits, sampling. No package types.
* `ModelCatalog` lists the models evaluated so far as `LocalModelConfig` constants. Adding a model is one entry.
* `FlutterGemmaAssistantModel(config)` is the **only** file that imports `flutter_gemma`. It maps the family and backend enums to
  the package's types, installs/loads the model, opens a fresh stateless chat per request, and converts the response into a
  provider-neutral `RawModelOutput`.
* `createLocalModel(id, ...)` builds a loadable model from a catalog id. Only `main.dart` and the integration test use it.
* `PromptVersion` objects are versioned and immutable; a prompt is built from the tools actually exposed, so it can never name
  an action the application did not register.

## The clarification flow (round 3)

```
"Change the theme"
   -> model calls ask_user(target = "change_theme.mode")        (a question, not an action)
   -> adapter: ActionPrediction(status: clarification_required, parameters: {target})
   -> validator: rejects (nothing to execute)
   -> pipeline: registry.offerFor(target) -> options [light, dark, system]   (application's enums)
   -> UI shows the question and the options; NOTHING has run
   -> user taps "Dark"
   -> pipeline.resolveClarification -> ordinary prediction -> validator -> registry -> executor
```

The model can name only a target the registry allows. It cannot add options or pick a value. Requests with no matching action
(no function call) get a fixed "I can't do that" message; the model's text is not shown. Details and measurements:
`docs/phase-2-recovery-round3.md`.

## Evaluation module

`lib/assistant/evaluation/` loads a dataset, runs each input through a `TracedAssistantModel`, the adapter, the real validator and
executor (against a counting environment, never the real app), and scores it. It has no dataset-specific rules.
`integration_test/phase_2_eval_test.dart` runs it on a device; `tool/` has the helpers that extract and summarise results.
Scoring definitions: `docs/dataset-guide.md`.

## UI

`lib/app/`: `HomeShell` (three pages plus the assistant dock), `AssistantController` (runs the pipeline for the UI; never
executes anything itself), `ModelHost` (model status over the abstractions), `TurnCard` (outcome, question, stepper, details).
See `docs/ui-guide.md`.

## Platform notes

iOS deployment target 15 (`.litertlm`), file sharing enabled; Android `minSdk 30` and the INTERNET permission (used only for the
one-time model download). The model is downloaded on first use and cached; inference does not use the network and there is no
cloud fallback. Tested only on an iOS Simulator (CPU).
