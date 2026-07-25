#!/usr/bin/env python3
"""spec-distill — interview brief structural gate (AC2/AC4/AC5, V2/V3/V6, PN4).

The Law 1 termination gate for the conducting-interview problem-space stage,
made mechanical. conducting-interview runs `check_brief.py gate <payload>` before
finalizing the brief / before any optional brainstorming invoke; a non-zero exit
BLOCKS termination (one of the 5 통과 의례 unmet).

v0.23.0부터 brief는 payload + audit 2파일 쌍이다. `gate <payload>`는 payload 경로만
받고, payload frontmatter의 `audit_file`(basename-only, P21 계보)로 audit을 스스로
해석한다(AC9, fail-closed) — audit_file 부재·traversal·파일 부재는 전부 red다.

This is NOT a Law 2 reviewer (NG3) — the brief gets no separated review. It is a
structural self-check (Law 1), analogous to parse_spec_structure.py for specs.

PN4: the steelman "verbatim" guarantee is checked by substring containment — each
§5 기각 `verdict:` entry must contain >=1 URL + a >=10-char statement + a valid
verdict — NOT exact-string match (avoids flakiness). Whether the steelman is a
genuine counter-argument is V10 manual.

CLI subcommands (all print JSON):
  check_brief.py sections <payload>            → {"missing": [...]}        (AC2)
  check_brief.py landscape-citations <payload> → {"uncited": [...]}        (AC4/V6)
  check_brief.py skepticism <payload>          → {"malformed": [...]}      (AC5/V3)
  check_brief.py tried-discarded <payload>     → {"ok": bool}              (V2/R4, §5 기각)
  check_brief.py coverage <payload>            → {"failures": [...]}       (AC2/C9, audit §1 해석)
  check_brief.py frontmatter <payload>         → {"errors": [...]}         (AC1)
  check_brief.py gate <payload>                → {"pass": bool, "failures": [...]}
                                                 exit 0 if pass else 1
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path


def _web_disabled() -> bool:
    """AC8 graceful degradation: when web research is killed, URLs cannot be
    obtained, so the gate relaxes the citation requirement on §3/§4 (the SKILL's
    R2/R3 web-absent clauses). The judgment of whether the (URL-less) skepticism
    is genuine stays V10 manual."""
    return os.environ.get("DEVBREW_SPEC_DISTILL_DISABLE_WEB") == "1"

FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)
URL_RE = re.compile(r"https?://\S+")
VALID_VERDICTS = ("defended", "switched", "deferred")
# Fenced code blocks are illustrative, not authored content — strip them before
# section/entry detection so headers quoted inside ``` cannot satisfy the gate (F4).
FENCE_RE = re.compile(r"^[ \t]*```.*?^[ \t]*```[^\n]*$", re.DOTALL | re.MULTILINE)

SECTIONS = [
    ("0", "한눈에"),
    ("1", "Goal · Non-goal"),
    ("2", "제약"),
    ("3", "Open Questions"),
    ("4", "External Landscape"),
    ("5", "기각 · Blind Spots"),
    ("6", "사용자 원문"),
    ("7", "Next Action"),
]

# audit 섹션도 계약이다 — coverage_ledger_failures()와 steelman 대조가 섹션 번호+제목으로
# 본문을 잘라내므로, audit 쪽 번호가 바뀌면 검증이 조용히 빈 문자열을 읽고 통과한다.
AUDIT_SECTIONS = [
    ("1", "Coverage Ledger"),
    ("2", "Budget"),
    ("3", "Steelman 원문"),
    ("4", "게이트 실행 기록"),
    ("5", "프로세스 로그"),
]

FLOOR_KEYS = ["root_problem", "landscape", "skepticism", "blind_spot", "open_questions"]


def _body(text: str) -> str:
    m = FRONTMATTER_RE.match(text)
    body = text[m.end():] if m else text
    return FENCE_RE.sub("", body)


def find_missing_sections(text: str, sections: list = SECTIONS) -> list[str]:
    body = _body(text)
    missing = []
    for num, title in sections:
        pat = re.compile(
            rf"^##\s+{num}\.\s+{re.escape(title)}\b",
            re.MULTILINE | re.IGNORECASE,
        )
        if not pat.search(body):
            missing.append(f"{num}. {title}")
    return missing


def _section_text(text: str, num: str, title: str) -> str:
    body = _body(text)
    start = re.search(
        rf"^##\s+{num}\.\s+{re.escape(title)}\b", body, re.MULTILINE | re.IGNORECASE
    )
    if not start:
        return ""
    rest = body[start.end():]
    nxt = re.search(r"^##\s+\d+\.", rest, re.MULTILINE)
    return rest[: nxt.start()] if nxt else rest


def _entry_lines(section: str) -> list[str]:
    return [
        ln.strip()
        for ln in section.splitlines()
        if ln.lstrip().startswith("- ") and ln.strip() != "-"
    ]


def _frontmatter(text: str) -> str:
    m = FRONTMATTER_RE.match(text)
    return m.group(1) if m else ""


# 값은 첫 공백 또는 `#`(YAML 인라인 주석)에서 끊는다 — 템플릿의
# `audit_file: <...>.md   # basename만 (같은 디렉토리)` 라인 자체가 파싱 대상이다.
AUDIT_FILE_RE = re.compile(r"^audit_file:\s*([^\s#]+)", re.MULTILINE)


def resolve_audit(payload: Path, fm: str):
    """payload frontmatter의 audit_file을 해석한다 (AC9, fail-closed).

    audit_file은 신뢰 경계 밖 입력이므로 **basename만** 허용한다(P21 계보) — `../x.md`,
    `/etc/x.md`, `a/b.md`는 전부 Path(...).name != 원문이라 거부된다. 부재·미해석은
    전부 게이트 red이며, 조용히 payload-only 검사로 degrade하지 않는다(2파일 fail-open 봉쇄).
    """
    m = AUDIT_FILE_RE.search(fm)
    if not m:
        return None, "audit_file key absent"
    name = m.group(1).strip().strip('"').strip("'")
    if Path(name).name != name:
        return None, f"audit_file {name!r} is not a basename (traversal rejected)"
    p = payload.parent / name
    if not p.exists():
        return None, f"audit file not found: {name}"
    return p, None


def landscape_uncited(text: str) -> list[str]:
    if _web_disabled():
        return []  # web off → no URLs obtainable; citation requirement relaxed (AC8)
    sec = _section_text(text, "4", "External Landscape")
    return [ln for ln in _entry_lines(sec) if not URL_RE.search(ln)]


def landscape_present(text: str) -> bool:
    """§4 External Landscape must carry >=1 entry, OR an explicit web-disabled
    sentinel (AC8 graceful degradation). Header presence alone is not research (F3)."""
    sec = _section_text(text, "4", "External Landscape").strip()
    if not sec:
        return False
    if re.search(r"\bN/?A\b|비활성|생략|web[ -]?disabled", sec, re.IGNORECASE):
        return True
    return bool(_entry_lines(sec))


def section5_entries(text: str) -> list[str]:
    return _entry_lines(_section_text(text, "5", "기각 · Blind Spots"))


def skepticism_malformed(text: str) -> list[str]:
    """§5의 `verdict:` 항목 형식 검사. PN4: 정확한 문자열 일치가 아니라 containment."""
    require_url = not _web_disabled()
    bad: list[str] = []
    for ln in section5_entries(text):
        if "verdict:" not in ln:
            continue
        has_url = bool(URL_RE.search(ln))
        has_verdict = any(v in ln.lower() for v in VALID_VERDICTS)
        stripped = URL_RE.sub("", ln).lstrip("- ").strip()
        has_stmt = len(stripped) >= 10
        if not (has_verdict and has_stmt and (has_url or not require_url)):
            miss = []
            if not has_stmt:
                miss.append("statement<10c")
            if require_url and not has_url:
                miss.append("no-url")
            if not has_verdict:
                miss.append("no-verdict")
            bad.append(f"{ln[:60]} :: {','.join(miss)}")
    return bad


REJECT_NA_RE = re.compile(r"^-\s*기각\s*—\s*N/?A\b", re.IGNORECASE)


def tried_discarded_ok(text: str) -> bool:
    """R4 통과 의례 이관 — 구 §7 Tried & Discarded가 §5로 병합됐다.

    병합은 표현의 통합이지 의례의 폐기가 아니다: `기각` 항목이 0건이면 명시 N/A sentinel
    없이는 통과할 수 없다. steelman과 무관하게 사용자가 폐기한 방향도 여기 남는다.
    """
    rej = [ln for ln in section5_entries(text) if ln.lstrip("- ").startswith("기각")]
    sentinel = any(REJECT_NA_RE.match(ln) for ln in rej)
    real = [ln for ln in rej if not REJECT_NA_RE.match(ln)]
    return bool(real) or sentinel


def coverage_ledger_failures(text: str) -> list[str]:
    """§6 Coverage Ledger form 검증 (C9 직렬화 / AC2 / AC3).
    Form-level only (C2): floor 5행 각 존재 + status 토큰 'closed' + evidence 세그먼트
    non-empty; derived는 >=1 derived 행 OR N/A sentinel. 'closed'가 실질적으로 참인지는
    검사하지 않는다(모델 + 독립 adversary의 몫 — 게이트는 이 한계를 숨기지 않는다)."""
    sec = _section_text(text, "1", "Coverage Ledger")
    if not sec.strip():
        return ["Coverage Ledger empty or absent"]
    fails: list[str] = []
    floor_rows: dict[str, tuple[str, str]] = {}
    derived_rows = 0
    derived_sentinel = False
    for ln in _entry_lines(sec):
        body = ln.lstrip("- ").strip()
        fm = re.match(r"^floor:(\w+)\s*—\s*(\S+)\s*—\s*(.*)$", body)
        if fm:
            floor_rows[fm.group(1)] = (fm.group(2).strip(), fm.group(3).strip())
            continue
        if re.match(r"^derived:\s*N/?A\b", body, re.IGNORECASE):
            derived_sentinel = True
            continue
        if body.startswith("derived:"):
            derived_rows += 1
    for key in FLOOR_KEYS:
        if key not in floor_rows:
            fails.append(f"floor:{key} row missing")
            continue
        status, evidence = floor_rows[key]
        if status != "closed":
            fails.append(f"floor:{key} status {status!r} != closed")
        if not evidence:
            fails.append(f"floor:{key} evidence empty")
    if derived_rows == 0 and not derived_sentinel:
        fails.append("derived: no derived row and no N/A sentinel")
    return fails


def frontmatter_errors(text: str) -> list[str]:
    m = FRONTMATTER_RE.match(text)
    if not m:
        return ["frontmatter absent"]
    fm = m.group(1)
    errs: list[str] = []
    if not re.search(r"^type:\s*interview-brief\s*$", fm, re.MULTILINE):
        errs.append("type != interview-brief")
    if not re.search(r"^next_phase:\s*superpowers:brainstorming\s*$", fm, re.MULTILINE):
        errs.append("next_phase != superpowers:brainstorming")
    if not AUDIT_FILE_RE.search(fm):
        errs.append("audit_file key absent")
    if not re.search(r"^user_sourced_items\s*:", fm, re.MULTILINE):
        errs.append("user_sourced_items key absent")
    return errs


def gate(path: Path) -> int:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(json.dumps({"pass": False, "failures": [f"brief unreadable: {exc}"]},
                         ensure_ascii=False))
        return 1
    failures: list[str] = []
    fm = _frontmatter(text)

    miss = find_missing_sections(text)
    if miss:
        failures.append(f"missing payload sections: {miss}")
    fe = frontmatter_errors(text)
    if fe:
        failures.append(f"frontmatter: {fe}")

    # --- audit 해석 (fail-closed): 못 열면 audit 측 검증 전체를 skip하지 않고 red ---
    audit_path, audit_err = resolve_audit(path, fm)
    audit_text = ""
    if audit_err:
        failures.append(f"audit: {audit_err}")
    else:
        try:
            audit_text = audit_path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            failures.append(f"audit unreadable: {exc}")
        else:
            amiss = find_missing_sections(audit_text, AUDIT_SECTIONS)
            if amiss:
                failures.append(f"missing audit sections: {amiss}")

    sec4_absent = any(m.startswith("4.") for m in miss)
    if not sec4_absent and not landscape_present(text):
        failures.append("External Landscape empty (no entries and no web-disabled sentinel)")
    unc = landscape_uncited(text)
    if unc:
        failures.append(f"uncited landscape entries: {len(unc)}")
    mal = skepticism_malformed(text)
    if mal:
        failures.append(f"malformed §5 verdict entries: {len(mal)}")

    sec5_absent = any(m.startswith("5.") for m in miss)
    if not sec5_absent and not tried_discarded_ok(text):
        failures.append("§5 기각 항목 0건 (N/A sentinel 없음)")

    # Coverage Ledger는 이제 audit에 산다 — audit을 못 열었으면 위에서 이미 red.
    if audit_text and not any(m.startswith("1.") for m in find_missing_sections(audit_text, AUDIT_SECTIONS)):
        cov = coverage_ledger_failures(audit_text)
        if cov:
            failures.append(f"coverage ledger: {cov}")

    ok = not failures
    print(json.dumps({"pass": ok, "failures": failures}, ensure_ascii=False))
    return 0 if ok else 1


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print("usage: check_brief.py <subcommand> <brief.md>", file=sys.stderr)
        return 64
    sub, path = argv[1], Path(argv[2])
    if sub == "gate":
        return gate(path)
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(f"brief unreadable: {exc}", file=sys.stderr)
        return 1
    if sub == "sections":
        print(json.dumps({"missing": find_missing_sections(text)}, ensure_ascii=False))
        return 0
    if sub == "landscape-citations":
        print(json.dumps({"uncited": landscape_uncited(text)}, ensure_ascii=False))
        return 0
    if sub == "skepticism":
        print(json.dumps({"malformed": skepticism_malformed(text)}, ensure_ascii=False))
        return 0
    if sub == "tried-discarded":
        print(json.dumps({"ok": tried_discarded_ok(text)}, ensure_ascii=False))
        return 0
    if sub == "coverage":
        audit_path, audit_err = resolve_audit(path, _frontmatter(text))
        if audit_err:
            print(json.dumps({"failures": [audit_err]}, ensure_ascii=False))
            return 1
        try:
            audit_text = audit_path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            print(json.dumps({"failures": [f"audit unreadable: {exc}"]}, ensure_ascii=False))
            return 1
        print(json.dumps({"failures": coverage_ledger_failures(audit_text)},
                         ensure_ascii=False))
        return 0
    if sub == "frontmatter":
        print(json.dumps({"errors": frontmatter_errors(text)}, ensure_ascii=False))
        return 0
    print(f"unknown subcommand: {sub}", file=sys.stderr)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv))
