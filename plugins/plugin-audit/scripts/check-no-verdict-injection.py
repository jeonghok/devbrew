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

Scope is deliberately narrow: only the six surfaces that are actually injected into an
auditor's (or codex co-auditor's) context. The design doc and the interview brief are NOT scanned — discussing a
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

# The injected surfaces (design §14). Nothing else is scanned. codex-prompt-preamble.md is
# injected into the codex co-auditor's prompt (SKILL pre-1), so a verdict phrase there must be
# scanned too.
SURFACES = [
    "scripts/audit-workflow.js",
    "scripts/smoke-workflow.js",
    "scripts/codex-prompt-preamble.md",
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

# Generic (target-무관) verdict 토큰 — Task 16 (component B). audit-workflow.js가 스캔하는
# 것과 seed(후보 단서 파일, parse-seed.py 산출물)가 스캔하는 것은 다른 위생 기준을 가진다:
# audit-workflow.js는 `d_verdicts.verdict`의 JSON-schema enum으로
# confirmed/withdrawn/reclassified를 **정당하게** 갖고, 감사자에게 그 중 하나를 *산출*하라고
# 지시한다 (판정을 미리 받는 게 아니라 판정을 내리라는 지시). 이 토큰들을 고정 SURFACES에
# 적용하면 그 스키마 자체가 오탐된다 — 그래서 BANNED에는 넣지 않는다.
#
# 반대로 seed는 invoker가 공급하는 "후보 단서"일 뿐이라 주장만 담아야 한다 — `D1 ... confirmed`
# 처럼 seed가 스스로 판정을 미리 내리면 감사자를 그 판정 쪽으로 앵커링한다. 그래서 이 토큰들은
# 고정 SURFACES가 아니라 argv로 넘어온 추가 표면(=seed)에만 적용한다.
SEED_EXTRA = [
    (r"\bconfirmed\b", "판정(confirmed)을 미리 준다 — 주장만 허용"),
    (r"\bwithdrawn\b", "판정(withdrawn)을 미리 준다"),
    (r"\breclassified\b", "판정(reclassified)을 미리 준다"),
    (r"입증(됨|됐|된다)", "판정(입증)을 미리 준다"),
    (r"확정(됨|됐|된다|적)", "판정(확정)을 미리 준다"),
]


def _scan(p: Path, root: Path, banned: list[tuple[str, str]]) -> list[str]:
    """p를 banned 패턴 목록으로 스캔해 히트(포맷된 문자열) 목록을 돌려준다."""
    found: list[str] = []
    text = p.read_text(encoding="utf-8", errors="replace")
    for i, line in enumerate(text.splitlines(), 1):
        for pat, why in banned:
            if re.search(pat, line):
                found.append(f"{p.relative_to(root) if root in p.parents else p}:{i}\n"
                             f"      {line.strip()[:110]}\n"
                             f"      → {why}")
    return found


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    hits: list[str] = []
    scanned = 0

    # 고정 주입 표면 (design §14) — BANNED만. audit-workflow.js의 verdict enum을
    # SEED_EXTRA로 오탐시키지 않기 위해 이 목록에는 절대 SEED_EXTRA를 섞지 않는다.
    for rel in SURFACES:
        p = root / rel
        if not p.is_file():
            continue                               # a surface that does not exist yet is not a leak
        scanned += 1
        hits += _scan(p, root, BANNED)

    # argv로 넘어온 추가 표면 — 감사 seed(또는 그 밖의 invoker 공급 후보-단서 파일).
    # BANNED + SEED_EXTRA로 스캔: seed는 주장만 담아야 하고 판정을 미리 주면 안 된다.
    for a in sys.argv[1:]:
        p = Path(a) if Path(a).is_absolute() else root / a
        if not p.is_file():
            continue                               # a surface that does not exist yet is not a leak
        scanned += 1
        hits += _scan(p, root, BANNED + SEED_EXTRA)

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
