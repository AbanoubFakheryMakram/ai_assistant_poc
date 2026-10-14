# Model comparison (everything tried so far)

All numbers are measured on the iPhone 17 Pro Max **Simulator** (iOS 26.2, CPU) with the same action contract
(`change_theme`, `navigate`), the same validator and the same datasets. Source: `evaluation/results/` and
`docs/phase-2-recovery.md`. A dash means "not measured".

| | FunctionGemma 270M | Qwen3 0.6B | Gemma 4 E2B |
|---|---|---|---|
| File | `functiongemma-270M-it.litertlm` | `Qwen3-0.6B.litertlm` (INT8) | `gemma-4-E2B-it.litertlm` |
| Size on disk | 284 MB | 614 MB | 2.59 GB |
| Tool-call path | Native (LiteRT-LM) | flutter_gemma `<tool_call>` parser | Native (LiteRT-LM) |
| Prompt | `functiongemma_prompt_v1` (17 few-shot) | `recovery_prompt_v1` (zero-shot) | `recovery_prompt_v1` (zero-shot) |
| Loads on iOS Simulator | Yes | **No** (`Failed to create engine`) | Yes |
| Model loading time | 1.3 s | n/a | 5.5 s |
| First / avg inference | 1.3 s / 1.6 s | n/a | 1.9 s / 2.0 s |
| Memory | not measured | n/a | not measured |

## Accuracy (action / parameters / full)

| Dataset | FunctionGemma 270M | Qwen3 0.6B | Gemma 4 E2B |
|---|---|---|---|
| Frozen Phase 2 (68), **the gate** | 63.2% / 51.9% / 54.4% | not measured | **88.2% / 100% / 88.2%** |
| Development (48) | 66.7% / 55.6% / 58.3% | not measured | 91.7% / 100% / 91.7% |
| Held-out (64) | 70.3% / 45.8% / 56.2% | not measured | 90.6% / 100% / 90.6% |
| All 180 combined (informational) | 66.7% / 50.7% / 56.1% | not measured | 90.0% / 100% / 90.0% |

## Action accuracy by language (frozen set)

| Language | FunctionGemma 270M | Gemma 4 E2B |
|---|---|---|
| English | 88.2% | 88.2% |
| MSA Arabic | 58.8% | 88.2% |
| Egyptian Arabic | 35.3% | 94.1% |
| Mixed Arabic/English | 70.6% | 82.4% |

## Gemma 4 E2B with the round-2 prompts (see `docs/phase-2-recovery-round2.md`)

| Prompt | Frozen (68) | Development (48) | Held-out v2 (64, new) |
|---|---|---|---|
| `recovery_prompt_v1` (zero-shot) | 88.2% / 100% / 88.2% | 91.7% / 100% / 91.7% | 73.4% / 96.9% / 73.4% |
| `recovery_prompt_v2` (+ abstention rule) | **91.2% / 100% / 91.2%** | 91.7% / 100% / 91.7% | 73.4% / 96.9% / 73.4% |
| `recovery_prompt_v3` (+ negative examples) | not run (not selected) | 91.7% / 100% / 91.7% | not run |

Held-out v2 by kind (both prompts): theme 15/16, navigate 16/16, out-of-scope 16/16, **vague requests 0/16**.

## Round 3: Gemma 4 E4B and the clarification flow (see `docs/phase-2-recovery-round3.md`)

| Configuration | Frozen (68) | Development (48) | Held-out v3 (64, unseen) |
|---|---|---|---|
| Gemma 4 E4B + `clarify_prompt_v4` (model may ask the user) | **100.0% / 100.0% / 97.1%** | 100.0% / 100.0% / 100.0% | **100.0% / 100.0% / 100.0%** |
| Gemma 4 E4B + `recovery_prompt_v2` (no question function, control) | not run | not run | 79.7% / 100.0% / 79.7% |

Held-out v3, vague requests answered with a question: 16 of 16 (15 about the right value). Same model without the question function:
3 of 16 handled, 13 guessed. Only mistakes with the question flow: two out-of-scope requests ("Open Facebook") answered with a
question instead of a refusal (frozen set). Cost: 3.49 GB file, about 33 s to load, about 4 to 6 s per command on a simulator CPU
(memory not measured, nothing run on a real device). Gemma 4 E2B with the question function was not run.

## Failure behaviour (frozen set)

| | FunctionGemma 270M | Gemma 4 E2B |
|---|---|---|
| `navigate(profile)` collapse | 21 of 68 | 0 |
| Prose instead of a call | 6 | 0 (refusals in prose are scored as correct) |
| Multiple function calls | 3 | 0 |
| Wrong action / wrong parameter | 10 / 6 | 0 / 0 |
| Fabricated parameter (guessed or invented values) | 8.8% | 11.8% |
| Out-of-scope request mapped to an action | 4 | 4 |
| Vague request answered with a guessed value | 2 | 4 |

## Safety (all runs)

Uncontrolled executions: 0. Invalid outputs executed: 0. For all three models the model has no path to
application code; only the validated pipeline executes.

## Verdict against the Phase 2 gate (action >= 90% and parameters >= 90% on the frozen set)

| Model | Verdict |
|---|---|
| FunctionGemma 270M | Fails (63.2% action, 51.9% parameters) |
| Qwen3 0.6B | Not evaluated (does not load on the iOS Simulator) |
| Gemma 4 E4B | With `clarify_prompt_v4` (round 3): meets the gate on the frozen set (100% action / 100% parameters) and on an unseen held-out set (100% / 100%). Verdict: ready under the pre-declared rule. Not measured: memory, real devices. |
| Gemma 4 E2B | v1 prompt: fails narrowly (88.2% action). v2 prompt: meets the numbers on the frozen set (91.2%, one case of margin) but only 73.4% on an unseen held-out set, because all vague requests are guessed. Not ready. |

## Not tried

Qwen3 0.6B INT4 variants (345 MB and 498 MB), Qwen2.5 0.5B/1.5B, Gemma 3 1B, Gemma 3n, Phi-4 mini, any model on a
physical device or Android. Gemma 4 E2B with the question function (`clarify_prompt_v4`) was also not run. No claim is made about them.
