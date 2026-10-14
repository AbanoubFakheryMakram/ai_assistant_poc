#!/usr/bin/env python3
"""Prints a compact summary of an evaluation result JSON (dev use)."""
import json, sys
from collections import Counter
r = json.load(open(sys.argv[1]))
m = r["metrics"]
keys = ["actionAccuracyPct","parameterAccuracyPct","fullPredictionAccuracyPct","fullPredictionAccuracyProseAsInvalidPct","invalidOutputRatePct","fabricatedParameterRatePct","multipleFunctionCallRatePct","proseOutputRatePct","navigateProfileCollapseCases","uncontrolledExecutions","invalidOutputsExecuted"]
print(r["dataset"], r["model"].get("model"), r["model"].get("promptVersion"))
print({k: (round(m[k],1) if isinstance(m[k], float) else m[k]) for k in keys if k in m})
for l, v in r["languageBreakdown"].items():
    print(" ", l, {k: round(x,1) for k, x in v.items()})
print("latency", {k: (round(x) if x else x) for k, x in r["latency"].items()}, "load", r["modelLoad"])
print("categories", r["failureSummary"]["byCategory"])
print("tags", Counter(t for c in r["cases"] for t in c.get("failureTags", [])))
if len(sys.argv) > 2:
    for f in r["failures"]:
        print(f["id"], "|", f["input"], "|", f["rawModelOutput"][:110], "|", f["failureCategory"])
