# Phase 2 evaluation: local AI intent recognition

> **Later changes.** This document describes the original Phase 2 implementation and results, which are frozen. The code was later
> refactored (`FlutterGemmaAssistantModel` is now driven by a `LocalModelConfig`, tool definitions come from the registry, prompts
> are versioned) without changing the FunctionGemma behaviour: re-running it reproduced the frozen outputs byte for byte. For the
> current structure see `architecture.md`; for what happened next see `phase-2-recovery.md`.

Scope: `change_theme` and `navigate` only. Everything below is measured, not estimated.
Machine-readable data: `evaluation/results/phase_2_v1.json` (final run) and
`evaluation/results/phase_2_v1_run1_cold.json` (first run). Dataset:
`evaluation/datasets/phase_2_v1.json`.

## Model

FunctionGemma 270M IT, `functiongemma-270M-it.litertlm` (int8, ~284 MB) from
`sasha-denisov/function-gemma-270M-it` on Hugging Face (public, no token). Used in
its native tool-calling mode (`ModelType.functionGemma`): only `change_theme` and
`navigate` are declared as tools, `topK=1` (greedy), `temperature=0.1`, a fresh
stateless chat per command.

## Runtime

* `flutter_gemma` 1.11.3 + `flutter_gemma_litertlm` 1.8.5 (LiteRT-LM engine, `.litertlm` format).
* Backend: CPU (`PreferredBackend.cpu`); the iOS Simulator cannot run GPU inference.
* Why `.litertlm` and not the `.task` build in the same repo: the package marks `.litertlm`
  as the recommended engine, routes FunctionGemma through LiteRT-LM's native tool-call
  channel (structured calls, not text parsing), runs on iOS 15+ and does not need MediaPipe (iOS 16).
* `flutter_gemma` types are confined to `lib/assistant/providers/flutter_gemma_assistant_model.dart`.

## How the model is obtained and loaded (offline claim)

The model file is **not bundled**. `FlutterGemmaAssistantModel.load()` downloads it once
over the network (~130-200 s on the dev machine) and caches it in the app's storage; after that,
loading and inference read only local files and use no network. There is no cloud fallback and
no remote inference endpoint anywhere in the code. I did **not** test inference with the network
disabled; "offline inference" is by design (no network calls in the inference path), not an
observed airplane-mode test. In these runs the simulator reinstalled the app each time, so the
model was re-downloaded each run.

## Test device (the only one tested)

| | |
|---|---|
| Device | iPhone 17 Pro Max **Simulator** on an Apple-silicon Mac (12 cores) |
| OS | iOS 26.2 (23C54) |
| Model format / backend | `.litertlm`, CPU |
| Model loading | succeeded |
| Inference | succeeded, deterministic (see below) |

**Not tested:** any physical iPhone, any Android device or emulator. Android is configured
(minSdk 30, INTERNET permission) but **no compatibility claim is made** for it, and simulator
latency is not representative of real devices.

## Dataset

68 commands, 17 per language group (English, MSA Arabic, Egyptian Arabic,
Mixed Arabic/English): 28 `change_theme`, 24 `navigate`, 16 requests that must NOT map to an
action (12 unsupported such as "Open Facebook" / "turn off notifications" / "change language",
4 missing-information such as "Change the theme"). Expected results were written before any
model ran and have not been edited. No dataset input is used as a few-shot example (unit-tested).

## Results

```
Total commands: 68

Action accuracy: 63.2%
Parameter accuracy: 51.9%   (over the 52 commands that expect parameters)
Full prediction accuracy: 54.4%
Invalid output rate: 4.4%   (3/68, all rejected, none executed)
Fabricated parameter rate: 8.8%   (6/68)
```

Parameter accuracy over all 68 cases (empty params on negatives count as correct): 54.4%.
Status accuracy: 77.9%.

Definitions: *action correct* = same action name (or no action when none expected);
*parameters correct* = exactly the expected parameters; *full* = status + action + parameters
all correct, no extras, and (for actions) accepted by the validator and executed;
*invalid output* = model output that could not become a valid prediction or was rejected by the
validator; *fabricated* = a parameter the request does not support: any argument on a request
with no basis (unsupported / missing info), an extra key, or a value outside the allowed enum.
A wrong but in-domain value (e.g. light instead of dark) is `wrong_parameter`, not fabricated.

### Language breakdown

| Language | Cases | Action acc. | Parameter acc. | Full prediction acc. |
|---|---|---|---|---|
| English | 17 | 88.2% | 84.6% | 82.4% |
| MSA Arabic | 17 | 58.8% | 30.8% | 41.2% |
| Egyptian Arabic | 17 | 35.3% | 23.1% | 29.4% |
| Mixed Arabic/English | 17 | 70.6% | 69.2% | 64.7% |

## Safety

* Uncontrolled executions: **0**. Invalid outputs executed: **0**.
* The 3 invalid outputs (the model emitted two function calls) were rejected as malformed.
* The model never produced an out-of-enum value (it always stayed within `profile/home/settings`
  and `light/dark/system`), so the validator's enum checks were not exercised by real model output.
  What the contract does *not* protect against: **49 actions were executed, only 27
  were correct.** 22 were valid-but-wrong (for example dark when light was asked, or
  `navigate(profile)` for "Open Facebook"). Validation guarantees the app only ever does something
  from the allowed set; it cannot know the model misread the user.

## Latency (CPU, iOS Simulator; baseline only, not a pass/fail criterion)

```
Model loading:        1016 ms (engine creation; the one-time download took 130 s, first run 197 s)
First inference:      1358 ms
Average subsequent:   1633 ms (min 1267, max 2643)
```

## Reproducibility

Two full runs produced byte-identical raw model outputs for all 68 commands (greedy decoding), so
the numbers above are reproducible on this setup. Command:

```bash
flutter test integration_test/phase_2_eval_test.dart -d <ios-simulator-id> \
  --dart-define=DEVICE_NAME="iPhone 17 Pro Max" --dart-define=DEVICE_KIND=simulator | tee run.log
python3 tool/extract_eval_results.py run.log evaluation/results/phase_2_v1.json
```

The integration sanity test also ran the 7 requested commands through the real model and pipeline
(see `integrationSanity` in the result file): 5 correct; "خلي التطبيق دارك" and
"يا عم خلّي التطبيق دارك" were mapped to `navigate(profile)` (wrong, but validated and executed as
a valid navigate, which is exactly the failure mode described under Safety).

## Failed cases (31), all listed

| Category | Count |
|---|---|
| wrong_action | 10 |
| wrong_parameter | 6 |
| language_failure | 6 |
| unsupported_request_mapped_to_action | 4 |
| malformed_output | 3 |
| fabricated_parameter | 2 |

| ID | Input | Expected | Model output | Category |
|---|---|---|---|---|
| theme-eng-006 | Follow my phone's appearance setting | change_theme(system) | call navigate({destination: profile}) | wrong_action |
| nav-eng-006 | Back to the main screen | navigate(home) | call navigate({destination: profile}) | wrong_parameter |
| unsupported-eng-001 | Open Facebook | unsupported | call navigate({destination: profile}) | unsupported_request_mapped_to_action |
| theme-msa-002 | أريد المظهر الغامق للتطبيق | change_theme(dark) | text "I can help with that! To assist you with the application them... | language_failure |
| theme-msa-003 | فعّل الثيم الغامق | change_theme(dark) | call navigate({destination: profile}) | wrong_action |
| theme-msa-004 | غيّر المظهر إلى الفاتح | change_theme(light) | call change_theme({mode: dark}) | wrong_parameter |
| theme-msa-005 | اجعل التطبيق بالوضع المضيء | change_theme(light) | call change_theme({mode: light}) \| call change_theme({mode: dark}) | malformed_output |
| theme-msa-006 | استخدم مظهر النظام | change_theme(system) | call navigate({destination: profile}) | wrong_action |
| theme-msa-007 | اتبع إعدادات المظهر في الجهاز | change_theme(system) | text "I can assist with managing app settings. Could you please spe... | language_failure |
| nav-msa-003 | اذهب إلى الصفحة الرئيسية | navigate(home) | call navigate({destination: profile}) | wrong_parameter |
| nav-msa-004 | أرني الإعدادات | navigate(settings) | text "I can help with that. What specific settings or preferences w... | language_failure |
| nav-msa-005 | افتح صفحة الإعدادات من فضلك | navigate(settings) | call navigate({destination: profile}) | wrong_parameter |
| unsupported-msa-001 | افتح فيسبوك | unsupported | call navigate({destination: profile}) | unsupported_request_mapped_to_action |
| theme-egy-001 | خلي التطبيق غامق | change_theme(dark) | call navigate({destination: profile}) | wrong_action |
| theme-egy-003 | ظبطلي الشكل على الليلي | change_theme(dark) | call change_theme({mode: light}) \| call change_theme({mode: dark}) | malformed_output |
| theme-egy-004 | نور الدنيا شوية، خليه فاتح | change_theme(light) | call navigate({destination: profile}) | wrong_action |
| theme-egy-005 | خليه لايت بقى | change_theme(light) | call navigate({destination: profile}) | wrong_action |
| theme-egy-006 | خلي الثيم زي ما التليفون | change_theme(system) | call navigate({destination: profile}) | wrong_action |
| theme-egy-007 | سيبه على حسب سيستم الموبايل | change_theme(system) | call navigate({destination: profile}) | wrong_action |
| nav-egy-001 | وديني على حسابي | navigate(profile) | text "I apologize, but I cannot assist with managing your account. ... | language_failure |
| nav-egy-003 | رجعني للصفحة الرئيسية | navigate(home) | text "I apologize, but I cannot assist with retrieving or modifying... | language_failure |
| nav-egy-004 | عايز الإعدادات | navigate(settings) | text "I can help with that. What specific settings or preferences w... | language_failure |
| nav-egy-006 | روح على الهوم | navigate(home) | call navigate({destination: profile}) | wrong_parameter |
| unsupported-egy-001 | افتحلي فيسبوك | unsupported | call navigate({destination: profile}) | unsupported_request_mapped_to_action |
| clarify-egy-001 | غير الثيم | clarification_required | call navigate({destination: profile}) | fabricated_parameter |
| theme-mix-002 | make it غامق | change_theme(dark) | call change_theme({mode: dark}) \| call change_theme({mode: dark}) | malformed_output |
| theme-mix-005 | خلي الـtheme زي الـsystem | change_theme(system) | call navigate({destination: profile}) | wrong_action |
| theme-mix-006 | use الوضع الليلي | change_theme(dark) | call navigate({destination: profile}) | wrong_action |
| nav-mix-005 | show me الإعدادات | navigate(settings) | call navigate({destination: profile}) | wrong_parameter |
| unsupported-mix-001 | open الـFacebook | unsupported | call navigate({destination: profile}) | unsupported_request_mapped_to_action |
| clarify-mix-001 | change الـtheme | clarification_required | call navigate({destination: profile}) | fabricated_parameter |

Notes on failures:
* **Collapse to `navigate(profile)`**: 28 of 68 outputs were `navigate(profile)` regardless of
  input. This is the dominant failure: theme requests in Arabic/Egyptian ("خليه لايت بقى",
  "سيبه على حسب سيستم الموبايل"), unsupported requests ("Open Facebook", "افتحلي فيسبوك"), and
  missing-info requests ("غير الثيم") all land there. The model has a strong prior to that call.
* **Prose instead of a call** (6 cases, all Arabic): the model answered in English text
  ("could you please specify...") instead of calling a function. Classified `language_failure`
  by rule (missed intent on a non-English command); that label is a heuristic, not proof of the cause.
* **Two calls** (3 cases): e.g. `change_theme(light)` and `change_theme(dark)` for "اجعل التطبيق
  بالوضع المضيء". The adapter allows exactly one call, so these are rejected. One of them
  ("make it غامق") was two identical calls; the strict policy still rejects it, and I did not
  loosen it to improve the score.
* `fabricated_parameter` is counted both as a category (2 missing-info cases) and as a flag on
  the 4 unsupported requests classified `unsupported_request_mapped_to_action`; total flagged = 6.

## Conclusion

* **What worked:** the architecture. The real model runs on-device behind `AssistantModel`,
  every output (including wrong, malformed and multi-call output) passes the adapter, validator
  and registry, nothing executed without validation (0 uncontrolled executions), and Phase 1
  still passes. Model load ~1 s; ~1.6 s per command on a simulator CPU. English theme/navigation worked well.
* **What failed:** accuracy. FunctionGemma 270M with this prompt does not reliably choose the
  action: it over-predicts `navigate(profile)`, often does not abstain on out-of-scope or underspecified
  requests (correct refusals: 8/12 unsupported, 2/4 missing-info), and often fails on Arabic.
* **Languages that performed well:** English (88% action, 82% full). Mixed is middling (71% / 65%).
* **Languages that performed poorly:** Egyptian Arabic (35% / 29%) and MSA Arabic (59% / 41%).
* **Did FunctionGemma meet the >=90% target?** **No.** Action accuracy 63.2% and
  parameter accuracy 51.9%, both well below 90%. Even English alone (88% action) is under target.
  The "100% safe handling / 0% uncontrolled execution" criteria were met.
* **Ready for Phase 3?** **No.** Expanding the action surface on a model that misroutes ~37% of
  two-action commands would not be informative. See the Phase gate in the final report for what to change.

## Limitations of this evaluation

Single device (simulator), single prompt/few-shot configuration, single dataset of 68 commands
(17 per language; one command is 1.5 percentage points), greedy decoding. Some expected
labels are judgment calls (e.g. "Back to the main screen" = home; "ظبطلي الشكل على الليلي" = dark).
Prompt variants were deliberately **not** tuned against this dataset, to avoid overfitting it.
