# Assistant POC: on-device AI that proposes, the app decides

A Flutter proof of concept that lets users give natural-language commands in **English, Modern Standard Arabic, Egyptian
Arabic and mixed Arabic/English** ("Turn on dark mode", "خلي التطبيق دارك", "روح على البروفايل") to a small **on-device**
model, with one hard rule:

> **The AI interprets. The code validates. The application executes.**

The model never runs code. Its output is untrusted input that must pass a strict validator and the action registry before the
application does anything. When a request is unclear, the app **asks the user** which value they mean instead of guessing.

```
text -> local model -> raw output -> adapter -> ActionPrediction -> validator -> registry -> executor -> app
                                                                       |
                                              missing value? -> ask the user (options come from the registry)
```

## What is in the repository

* **Action contract** with five actions (`change_theme`, `change_language`, `navigate`, `toggle_notifications`, `search`), strict
  schema validation and a single action registry.
* **Pluggable local models** (via `flutter_gemma`, `.litertlm`): FunctionGemma 270M, Gemma 4 E2B and E4B (Qwen3 0.6B is
  included but does not load on the iOS Simulator). Models are data in `model_catalog.dart`; the inference package is imported by
  exactly one file.
* **A reproducible evaluation harness**: fixed datasets in four language groups, frozen baselines, held-out sets, scored
  results with raw model output for every case, failure analysis and determinism checks.
* **A clarification flow**: the model may call `ask_user`; the app turns it into options from its own enums and the user decides.
* **A demo app** (Material 3, English/Arabic with RTL, light/dark) with Home, Profile, Settings, a developer tools page and an
  assistant dock that shows how each request was handled.
* **Documentation** of every phase, decision and measurement (`docs/`).

## Status

Phase-gated. **Phase 1** (deterministic contract, no AI) is complete. **Phase 2** (local AI, two actions) was run on several
models and prompts. Its gate is action >= 90%, parameters >= 90%, invalid output rejected 100%, uncontrolled execution 0.

* **FunctionGemma 270M** failed the gate (63.2% action on the frozen set).
* **Gemma 4 E2B** came close but guessed values the user never gave (88.2%; a prompt change reached 91.2% only by luck and did not hold
  up on unseen data).
* **Gemma 4 E4B + the clarification flow** (the model may call `ask_user`; the app shows options and the user decides) **meets the gate**
  on the frozen set (100% action, 100% parameters) and on an unseen held-out set (100% / 100%), with 0 uncontrolled executions. The same
  E4B without the question flow scored 79.7% on that unseen set, so the interaction design, not model size, fixed the guessing.
  Details and caveats: [`docs/phase-2-recovery-round3.md`](docs/phase-2-recovery-round3.md).

**Phases 3 to 9 are not started.** All measurements are from an **iOS Simulator (CPU)** only: no physical device and no Android device,
and memory was not measured. The best model is 3.5 GB.

## Quick start

```bash
flutter pub get
flutter analyze
flutter test            # unit + widget tests, no model needed
```

Run the app on an iOS Simulator (the model downloads on first use; see sizes in `docs/running-the-evaluation.md`):

```bash
flutter run -d <simulator-id> --dart-define=MODEL=gemma4e4b
# or reuse a model you already downloaded:
flutter run -d <simulator-id> --dart-define=MODEL=gemma4e4b --dart-define=MODEL_FILE=/absolute/path/gemma-4-E4B-it.litertlm
```

Tap **Turn on** (the default model is E2B; pass `MODEL=gemma4e4b` for E4B), then try "Turn on dark mode", "خلي التطبيق دارك", "Change the theme" (the app will ask which theme), or "ابعتلي إيميل"
(it will say it can't do that).

Run the on-device evaluation: `docs/running-the-evaluation.md`.

## Repository layout

```
lib/
  main.dart                      composition root (the only place concrete choices are made)
  assistant/
    models/ actions/ validation/ execution/   the core: contract, registry, validator, executor (pure Dart)
    providers/                   model interface, adapter, prompts, catalog, the one runtime file
    evaluation/                  dataset loader, scorer
  app/                           UI (pages, assistant dock, strings en/ar, theme)
evaluation/
  datasets/                      fixed command sets (frozen / development / held-out)
  results/                       measured results, one JSON per model x prompt x dataset
  phase_1_commands.json          Phase 1 deterministic cases
integration_test/                on-device evaluation runner
test/                            unit, widget and architecture tests
tool/                            scripts to extract, summarise and document results
docs/                            architecture, security model, every phase and its results
```

## Documentation

Start at [`docs/README.md`](docs/README.md). Highlights: [architecture](docs/architecture.md),
[security model](docs/security-model.md), [project history](docs/project-history.md),
[model comparison](docs/model-comparison.md), [clarification flow](docs/phase-2-recovery-round3.md),
[running the evaluation](docs/running-the-evaluation.md).

## Models and licences

Models are **not** in this repository. They are downloaded from Hugging Face on first use (public repositories, no token) and are
governed by their own licences (Gemma terms of use, Apache-2.0 for Qwen). Check them before shipping anything.

Repository licence: **not chosen yet.** Add a `LICENSE` file before publishing if you want others to be able to use the code.

## Known limitations

* Tested only on an iOS Simulator on CPU; latency and memory on real phones are unknown (memory was not measured at all).
* The model that meets the gate is 3.5 GB (E4B): heavy for a phone. Whether the 2.6 GB E2B also works with the question flow is untested.
* Only English and Arabic UI strings; five actions; no risk levels, confirmations or cloud fallback (later phases).
* Datasets are small (48 to 68 commands each, 17 per language group at most), so one case is 1.5 to 2 percentage points.
