#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "rpc" / "internal" / "logic"
for p in root.glob("*memory*.go"):
    t = p.read_text(encoding="utf-8")
    if "l.svcCtx.Config.LLMInference" not in t:
        continue
    if "moeconfig" not in t:
        t = t.replace(
            '\tllmapp "backend/internal/service/llm"',
            '\t"backend/internal/adapter/moeconfig"\n\tllmapp "backend/internal/service/llm"',
        )
    t = t.replace(
        "llmapp.Deps{Inference: l.svcCtx.Config.LLMInference}",
        "llmapp.Deps{Inference: moeconfig.InferenceFromViper()}",
    )
    p.write_text(t, encoding="utf-8")
    print("fixed", p.name)
