# Documentation index

Read in this order if you are new to the project.

| Document | What it covers |
|---|---|
| [architecture.md](architecture.md) | Layers, the registry/validator/executor pipeline, models behind an interface, the clarification flow |
| [security-model.md](security-model.md) | What the model can and cannot do, the guarantees and the tests that enforce them |
| [project-history.md](project-history.md) | Every phase and step in order, with decisions, dead ends and mistakes |
| [phase-1-evaluation.md](phase-1-evaluation.md) | Phase 1 (no AI): the deterministic action contract and its tests |
| [phase-2-evaluation.md](phase-2-evaluation.md) | Phase 2 baseline: FunctionGemma 270M, 68 commands, gate failed |
| [phase-2-recovery.md](phase-2-recovery.md) | Round 1: a larger model (Qwen3 failed to load; Gemma 4 E2B) |
| [phase-2-recovery-round2.md](phase-2-recovery-round2.md) | Round 2: do prompt rules and examples stop the model guessing? |
| [phase-2-recovery-round3.md](phase-2-recovery-round3.md) | Round 3: let the user decide (the `ask_user` clarification flow) |
| [model-comparison.md](model-comparison.md) | Every model and prompt tried, side by side |
| [dataset-guide.md](dataset-guide.md) | Datasets, the frozen/development/held-out rules and the scoring definitions |
| [running-the-evaluation.md](running-the-evaluation.md) | How to run the tests, download models and run the on-device evaluation |
| [ui-guide.md](ui-guide.md) | The demo app: pages, the assistant, the question flow |

Result files live in `evaluation/results/`. Documents that contain tables of numbers were generated from those files
(`tool/make_recovery_doc.py` for round 1); every other number was copied from a result file and can be re-checked there.
