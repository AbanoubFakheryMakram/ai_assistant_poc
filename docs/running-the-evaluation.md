# Running the evaluation

Everything here was run on an **iOS Simulator** (iPhone 17 Pro Max, iOS 26.2) on an Apple-silicon Mac, CPU backend.
Nothing has been run on a physical device or on Android.

## Prerequisites

* Flutter 3.44.x (Dart 3.12). `flutter doctor` must be clean for iOS.
* Disk space for the model you choose (see the table). Models are **never** committed (`*.litertlm` is git-ignored).
* A booted iOS Simulator (`xcrun simctl list devices booted`).

| Model id (`MODEL=`) | Model | File size |
|---|---|---:|
| `functiongemma` | FunctionGemma 270M | 284 MB |
| `qwen3` | Qwen3 0.6B (does not load on the iOS Simulator; kept for reproducibility) | 614 MB |
| `gemma4` | Gemma 4 E2B | 2.59 GB |
| `gemma4e4b` | Gemma 4 E4B | 3.66 GB |

The catalog is `lib/assistant/providers/model_catalog.dart`. Adding a model means adding an entry there.

## 1. Unit and widget tests (no model needed)

```bash
flutter analyze
flutter test
```

These cover the action contract, validator, executor, adapter, clarification flow, scoring logic, dataset hygiene,
the frozen-file hash and the architecture rules (`test/architecture_test.dart`).

## 2. Download a model (optional but faster for repeated runs)

By default the app downloads the model into its own storage on first load (about 130 to 260 s for the smaller ones), and a
simulator test run starts from a clean install, so it downloads **every run**. To avoid that, download once and pass the
file:

```bash
curl -L --fail -C - -o gemma-4-E2B-it.litertlm \
  https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm
shasum -a 256 gemma-4-E2B-it.litertlm   # compare with the published checksum
```

Notes from experience: large downloads can stall without failing. Use `-C -` to resume and
`--speed-limit 50000 --speed-time 30` so curl aborts a stalled transfer and you can retry. Always check the size and SHA-256
before use; a truncated file fails at engine creation with `Failed to create engine. Model may be invalid`.

## 3. On-device evaluation

```bash
flutter test integration_test/phase_2_eval_test.dart -d <simulator-id> \
  --dart-define=DEVICE_NAME="iPhone 17 Pro Max" --dart-define=DEVICE_KIND=simulator \
  --dart-define=MODEL=gemma4 \
  --dart-define=PROMPT=clarify_prompt_v4 \
  --dart-define=DATASETS=phase_2_v1,phase_2_recovery_heldout_v3 \
  --dart-define=MODEL_FILE=/absolute/path/gemma-4-E2B-it.litertlm | tee run.log

python3 tool/extract_eval_results.py run.log evaluation/results/gemma4_x.json result_phase_2_v1
python3 tool/summarize_eval.py evaluation/results/gemma4_x.json v      # quick console summary
```

| Define | Meaning |
|---|---|
| `MODEL` | catalog id (table above); default `functiongemma` |
| `PROMPT` | prompt version id (`functiongemma_prompt_v1`, `recovery_prompt_v1/v2/v3`, `clarify_prompt_v4`); default = the model's own |
| `DATASETS` | comma-separated dataset names from `evaluation/datasets/` (without `.json`) |
| `MODEL_FILE` | absolute path of a downloaded model file (skips the download) |
| `DEVICE_NAME`, `DEVICE_KIND` | recorded in the result file |

The `ask_user` function is offered to the model only for `clarify_prompt_v4`. Tool definitions are always generated from the
action registry.

The test prints the result JSON as base64 chunks (`EVAL_CHUNK`); `tool/extract_eval_results.py` rebuilds the file. Chunk names
are `result_<dataset>`.

### What you see on the device

Instead of the harness's blank "Test starting…" screen, the device shows a live progress screen:

* a five-step indicator (Get model, Load, Check, Evaluate, Results) with the active step animated;
* chips with the model, the prompt version and the device;
* a plain-language explanation of the current stage (for example "each command goes model -> validator -> registry -> executor, a
  counting stand-in, never the real app");
* the **quick check** (7 sample commands end to end), collapsed to one line once it passes;
* one card per dataset with a progress bar, running action accuracy, full accuracy, how many times the model asked the user, how many
  actions executed, the command being interpreted right now and the last results (green/amber, raw model output, latency);
* a safety badge ("0 uncontrolled executions");
* the finished metrics for each dataset, and an error card if the model fails to load.

The screen scrolls (touch, with a scrollbar) and follows the active dataset automatically. After the last dataset it stays up for
`HOLD_SECONDS` (default 12) so the results can be read. The implementation is `integration_test/support/eval_progress*.dart`.

| Define | Meaning |
|---|---|
| `HOLD_SECONDS` | how long to keep the final screen up (default 12) |

## 4. Reading a result file

`metrics` holds the headline numbers (action, parameter and full-prediction accuracy, invalid-output rate, fabricated-parameter
rate, multiple-call and prose rates, how often the model asked the user, uncontrolled executions). `languageBreakdown`,
`latency`, `failureSummary`, `failures` and one entry per case (`rawModelOutput`, `expected`, `actual`, validation result,
`executed`, failure category and tags) make every number traceable. See `docs/dataset-guide.md` for the scoring definitions.

## 5. Running the app by hand

```bash
flutter run -d <simulator-id> \
  --dart-define=MODEL=gemma4 --dart-define=MODEL_FILE=/absolute/path/gemma-4-E2B-it.litertlm
```

Tap **Turn on**, then type or tap a suggestion. Results show the plain-language outcome; **How this was handled** shows the raw
model output, prediction, validation and execution.

## Determinism

Sampling is greedy (`topK=1`, temperature 0.1). Every model/prompt/dataset combination that was run twice produced
byte-identical raw outputs. Latency varies between runs.
