#!/usr/bin/env python3
"""Rebuilds JSON emitted by integration_test/phase_2_eval_test.dart.

usage: flutter test integration_test/phase_2_eval_test.dart -d <device> | tee run.log
       python3 tool/extract_eval_results.py run.log evaluation/results/phase_2_v1.json [chunk]

`chunk` defaults to `result`; multi-dataset runs emit `result_<dataset>`.
"""
import base64, json, re, sys
log, out = sys.argv[1], sys.argv[2]
name = sys.argv[3] if len(sys.argv) > 3 else 'result'
chunks = {}
for line in open(log, encoding="utf-8", errors="replace"):
    m = re.search(r"EVAL_CHUNK (\w+) (\d+) (\S+)", line)
    if m:
        chunks.setdefault(m[1], {})[int(m[2])] = m[3]
res = json.loads("".join(base64.b64decode(chunks[name][i]).decode() for i in sorted(chunks[name])))
if "sanity" in chunks:
    res["integrationSanity"] = json.loads("".join(base64.b64decode(chunks["sanity"][i]).decode() for i in sorted(chunks["sanity"])))["sanity"]
json.dump(res, open(out, "w"), ensure_ascii=False, indent=1)
print("wrote", out, "cases:", len(res["cases"]))
