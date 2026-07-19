#!/usr/bin/env python3
"""check-no-verdict-injection.py — the prompt contract's first rule, made mechanical.

§8 opens with "주입은 사실만 넣고, 판정은 넣지 않는다" — inject facts, never verdicts. That
rule has been broken twice, and both times prose was the only thing enforcing it:

  r7   the old C10 muzzle: "AGENTS.md-canonical is correct — do not recommend against it".
       It was deleted from the design and left alive in the text actually injected.
  r13  the spoilers: "3 of the 4 premises already turned out false", "the same class of claim
       has been wrong three times". Claude and codex receive the SAME contract, so a shared
       spoiler makes their agreement worthless — it is not two independent audits converging,
       it is two models re-reading one answer. That destroys LD4 exactly where D1–D5 live.

Prose cannot enforce itself. This does.

Scope is deliberately narrow: only the three surfaces that are actually injected into an
auditor's context. The design doc and the interview brief are NOT scanned — discussing a
banned phrase there is legitimate, and a gate that cannot tell a mention from a use will
flag its own documentation (repo lesson, ledger 36). Narrowing the scope is how the false
positives go away.

Honest limit: grep cannot catch a *novel* form of verdict injection. This pattern list is
induced from the two failures that actually happened, and it is not complete. What it does
buy is that the same mistake cannot land a third time — and recurrence is what this disease
is made of.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# The three injected surfaces (design §14). Nothing else is scanned.
SURFACES = [
    "scripts/audit-workflow.js",
    "scripts/smoke-workflow.js",
    "agents/plugin-auditor.md",
    "agents/audit-refuter.md",
    "agents/smoke-probe.md",
]

# Phrases that hand the auditor a verdict instead of a fact.
BANNED = [
    (r"이미\s*\d*\s*건?\s*중?\s*\d*\s*건?의?\s*전제가\s*틀렸", "D 단서의 판정을 미리 준다"),
    (r"전제가\s*이미\s*틀", "D 단서의 판정을 미리 준다"),
    (r"세\s*번\s*틀렸", "base-rate 앵커 — 판정을 withdrawn 쪽으로 민다"),
    (r"정면으로\s*겹친", "OQ3의 답을 미리 준다 (결론이지 사실이 아니다)"),
    (r"가장\s*값진\s*발견", "판정을 특정 방향으로 민다"),
    (r"낡음의\s*가장\s*큰\s*후보", "판정을 특정 방향으로 민다"),
    (r"재발견\s*금지", "재갈 — 감사자를 구조적으로 눈멀게 한다"),
    (r"반대\s*권고\s*금지", "재갈 — 구 C10의 형태"),
    (r"조건\s*\(?[a-d]\)?는?\s*미충족", "steelman 조건 판정을 대신 내린다"),
    # r15 — per-lead 판정. bare `철회`로 D2 "이미 철회됨" + D4 "주장은 철회됨" 양쪽을 잡는다
    # (`이미 철회` 앵커는 D4를 놓친다, codex #1). `결함이다`/`정답`은 주입 표면에 정당한 실등장이
    # 있어 bare로 넣지 않는다 (§16 line 1666-1673).
    (r"철회(됨|됐|된다)", "D 단서의 판정(철회)을 미리 준다"),
    (r"사실\s*오류", "D1 단서의 판정(사실 오류)을 미리 준다"),
    (r"다시\s*열지\s*마", "재갈 — settled 판정을 강제한다"),
]


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    hits: list[str] = []
    scanned = 0

    targets = list(SURFACES)
    targets += [a for a in sys.argv[1:]]          # extra surfaces (e.g. the codex prompt file)

    for rel in targets:
        p = Path(rel) if Path(rel).is_absolute() else root / rel
        if not p.is_file():
            continue                               # a surface that does not exist yet is not a leak
        scanned += 1
        text = p.read_text(encoding="utf-8", errors="replace")
        for i, line in enumerate(text.splitlines(), 1):
            for pat, why in BANNED:
                if re.search(pat, line):
                    hits.append(f"{p.relative_to(root) if root in p.parents else p}:{i}\n"
                                f"      {line.strip()[:110]}\n"
                                f"      → {why}")

    if not scanned:
        print("[check-no-verdict-injection] FATAL: no injected surface found — "
              "a scan that reads nothing passes by being blind.", file=sys.stderr)
        return 1

    if hits:
        print(f"[check-no-verdict-injection] RED — 판정이 주입 표면에 새어 있다 ({len(hits)}건)",
              file=sys.stderr)
        for h in hits:
            print(f"  ✗ {h}", file=sys.stderr)
        print("\n  주입하는 것: 단서의 *주장*과 인용된 file:line.\n"
              "  주입하지 않는 것: 그 주장이 참인지 거짓인지에 대한 어떤 사전 판정도.\n"
              "  두 모델이 같은 스포일러를 받으면, 그들의 일치는 독립 검증의 일치가 아니다.",
              file=sys.stderr)
        return 1

    print(f"[check-no-verdict-injection] GREEN — 주입 표면 {scanned}개, 판정 주입 0건",
          file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
