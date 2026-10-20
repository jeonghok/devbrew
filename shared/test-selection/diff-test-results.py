#!/usr/bin/env python3
"""diff-test-results.py — 기준선 × HEAD 행을 짝지어 귀속하고 판정 입력 하나로 모은다.

    diff-test-results.py --assign <배정 파일> --rows <메모 디렉토리> --iter <N>
                         --baseline-commit <sha|-> --head-commit <sha|->

읽는 것 (전부 run-test-selection.sh 가 쓴 파일이다):
    <배정 파일>                         기대 unit 의 유일한 출처(R8)
    <메모>/baseline-<runner>.tsv        기준선 축 행 — 같은 실행의 iteration 사이에 재사용된다
    <메모>/head-<runner>-i<N>.tsv       이번 iteration 의 HEAD 축 행

출력은 verdict.py --differential 이 그대로 읽는다. 판정 펜스에는 verdict.py --emit-args 가
이 출력에서 낸 차등 결과 줄(qg-verdict-args:)이 글자 그대로 간다(R24).
종료: 0 정상 · 2 사용 오류 · 4 계약 위반.
표준 라이브러리만 쓴다.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path
from typing import NoReturn

STATUSES = {"pass", "fail", "error", "unrun", "absent"}
MODES = {"bulk", "per-unit", "flaky", "skip"}

# error 는 fail 축으로 접는다 — 비대칭 (pass, error) 는 확증 회귀다(R2). 대칭 error 는 아래에서
# 인증을 막는다.
AXIS = {"pass": "P", "fail": "F", "error": "F", "absent": "A", "unrun": "U"}
ATTR = {
    ("P", "P"): "STILL_GREEN",         ("P", "F"): "NEW_REGRESSION",
    ("P", "A"): "SILENT_DROP",         ("P", "U"): "SILENT_DROP",
    ("F", "P"): "FIXED",               ("F", "F"): "PRE_EXISTING",
    ("F", "A"): "SILENT_DROP",         ("F", "U"): "SILENT_DROP",
    ("A", "P"): "NEW_TEST_GREEN",      ("A", "F"): "NEW_TEST_RED",
    ("A", "A"): "SILENT_DROP",         ("A", "U"): "SILENT_DROP",
    ("U", "P"): "BASELINE_UNRUNNABLE", ("U", "F"): "BASELINE_UNRUNNABLE",
    ("U", "A"): "BASELINE_UNRUNNABLE", ("U", "U"): "BASELINE_UNRUNNABLE",
}
CATEGORIES = [
    "STILL_GREEN", "NEW_REGRESSION", "PRE_EXISTING", "FIXED",
    "NEW_TEST_GREEN", "NEW_TEST_RED", "SILENT_DROP", "BASELINE_UNRUNNABLE",
]
DEFECTS = {"NEW_REGRESSION", "NEW_TEST_RED"}
# verdict.py 의 CAUSE_TO_REASON 키와 같은 닫힌 열거다. 튜플 순서가 출력 정렬 키다.
DEGRADE_CAUSES = (
    "expected-empty", "baseline-unrunnable", "silent-drop",
    "error-axis", "bulk-pre-existing", "smeared", "no-adapters",
)
SHA = re.compile(r"[0-9a-f]{40}|[0-9a-f]{64}|-")


def fail4(msg: str) -> NoReturn:
    print(f"diff-test-results: {msg}", file=sys.stderr)
    raise SystemExit(4)


def read_text(path: Path, label: str) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        fail4(f"{label} 를 읽을 수 없다: {path} ({exc})")
    except UnicodeDecodeError as exc:
        fail4(f"{label} 가 UTF-8 이 아니다: {path} ({exc})")


def split_trailer(text: str, tag: str, path: Path) -> tuple[list[str], dict[str, str]]:
    """본문 줄들과 꼬리 줄의 키=값을 돌려준다. 꼬리 줄은 정확히 하나, 마지막 비어 있지 않은 줄이다."""
    lines = [ln for ln in text.splitlines() if ln.strip()]
    tails = [i for i, ln in enumerate(lines) if ln.startswith(tag + "\t")]
    if len(tails) != 1 or tails[0] != len(lines) - 1:
        fail4(f"{path}: 꼬리 줄 '{tag}' 가 정확히 하나의 마지막 줄이 아니다 — 생산자가 끝까지 쓰지 못했다")
    kv = {}
    for field in lines[-1].split("\t")[1:]:
        k, sep, v = field.partition("=")
        if not sep or k in kv:
            fail4(f"{path}: 꼬리 줄 필드를 읽을 수 없다: {field!r}")
        kv[k] = v
    body = lines[:-1]
    if kv.get("rows") != str(len(body)):
        fail4(f"{path}: 행 수 불일치 (꼬리 {kv.get('rows')!r} · 실제 {len(body)})")
    return body, kv


def read_assign(path: Path) -> tuple[list[tuple[str, str, str]], list[str]]:
    body, kv = split_trailer(read_text(path, "배정 파일"), "#qg-assign", path)
    adapters = [] if kv.get("adapters") in (None, "", "-") else kv["adapters"].split(",")
    rows, seen = [], set()
    for n, ln in enumerate(body, 1):
        parts = ln.split("\t")
        if len(parts) != 3:
            fail4(f"{path}:{n} 필드 수 {len(parts)} != 3")
        unit, runner, gran = parts
        if unit in seen:
            fail4(f"{path}:{n} 중복 unit '{unit}'")
        seen.add(unit)
        rows.append((unit, runner, gran))
    return rows, adapters


def read_rows(path: Path, runner: str, commit: str, axis: str = "head") -> dict[str, tuple[str, str, str]]:
    """행 파일 → {unit: (status, exit, mode)}. 다른 러너 · 다른 트리의 행 파일은 계약 위반이다(R5)."""
    try:
        path.stat()
    except FileNotFoundError:
        pass   # 없는 파일은 아래에서 같은 계약 위반으로 낸다
    except OSError as exc:
        fail4(f"행 파일을 확인할 수 없다: {path} ({exc})")
    if not path.is_file():
        fail4(f"행 파일이 없다: {path} — 그 축을 돌리지 않았으면 run-test-selection.sh unrun 으로 채워야 한다")
    body, kv = split_trailer(read_text(path, "행 파일"), "#qg-rows", path)
    if kv.get("flaky") not in ("0", "1"):
        fail4(f"{path}: 꼬리 flaky= 가 0·1 이 아니다: {kv.get('flaky')!r}")
    if not SHA.fullmatch(kv.get("commit", "")):
        fail4(f"{path}: 꼬리 commit= 가 sha 도 '-' 도 아니다: {kv.get('commit')!r}")
    if axis == "baseline" and kv.get("flaky") != "0":
        fail4(f"{path}: 기준선 행 파일에 flaky 재실행 표지가 있다 — flaky 는 HEAD 축 전용이다(R15)")
    if kv.get("runner") != runner:
        fail4(f"{path}: 러너 {kv.get('runner')!r} ≠ {runner!r}")
    if kv.get("commit") != commit:
        fail4(f"{path}: 행이 커밋 {kv.get('commit')!r} 에서 나왔다 — 이 축의 커밋은 {commit!r} 다")
    rows: dict[str, tuple[str, str, str]] = {}
    for n, ln in enumerate(body, 1):
        parts = ln.split("\t")
        if len(parts) != 4:
            fail4(f"{path}:{n} 필드 수 {len(parts)} != 4")
        unit, status, code, mode = parts
        if status not in STATUSES:
            fail4(f"{path}:{n} 알 수 없는 상태값 '{status}'")
        if mode not in MODES:
            fail4(f"{path}:{n} 알 수 없는 실행 방식 '{mode}'")
        if axis == "baseline" and mode == "flaky":
            fail4(f"{path}:{n} 기준선 행의 실행 방식이 flaky 다 — flaky 는 HEAD 축 전용이다(R15)")
        if unit in rows:
            fail4(f"{path}:{n} 중복 unit 행 '{unit}'")
        rows[unit] = (status, code, mode)
    return rows


def granularity_of(runner: str) -> str:
    """입도는 러너에서 도출한다 — 어댑터 표의 소유자에게 묻는다(R9)."""
    owner = Path(__file__).resolve().parent / "run-test-selection.sh"
    try:
        proc = subprocess.run(["bash", str(owner), "granularity", runner],
                              capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError) as exc:
        fail4(f"입도 소유자를 부를 수 없다 ({owner}): {exc}")
    gran = proc.stdout.strip()
    if proc.returncode != 0 or gran not in ("file", "package", "bulk"):
        fail4(f"러너 '{runner}' 의 입도를 얻지 못했다 (exit {proc.returncode}): {proc.stderr.strip()}")
    return gran


def same_tree(base: str, head: str) -> bool:
    """두 축이 같은 바이트면 차등이 성립하지 않는다(R12 · R13)."""
    if base == "-" or head == "-":
        return False
    trees = []
    for sha in (base, head):
        try:
            proc = subprocess.run(["git", "rev-parse", "--verify", "--quiet", f"{sha}^{{tree}}"],
                                  capture_output=True, text=True)
        except OSError as exc:
            fail4(f"git 을 부를 수 없다: {exc}")
        if proc.returncode != 0:
            fail4(f"커밋 {sha} 의 트리를 읽지 못했다 — 리포 루트에서 불러라")
        trees.append(proc.stdout.strip())
    return trees[0] == trees[1]


def yaml_str(s: str) -> str:
    escaped = (s.replace("\\", "\\\\").replace('"', '\\"')
               .replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t"))
    return '"' + escaped + '"'


def attribute(runner, gran, units, base, head, axes_equal):
    attributions, causes = [], []
    counts = {c.lower(): 0 for c in CATEGORIES}
    error_seen = smeared = False
    for unit in units:
        notes = []
        b, h = base.get(unit), head.get(unit)
        if b is None or h is None:
            verdict = "SILENT_DROP"   # 행이 없는 것은 계약 위반이다 — 부재를 추론으로 메우지 않는다(R7)
            notes.append("행 없음: " + ",".join(n for n, v in (("baseline", b), ("head", h)) if v is None))
        else:
            if h[2] == "flaky" and b[0] != "pass":
                fail4(f"{runner}: '{unit}' 의 flaky 재실행은 기준선 pass 인 unit 에만 허용된다(R15)")
            for side, row in (("baseline", b), ("head", h)):
                if row[0] == "error":
                    notes.append(f"{side}=(error)")
                    error_seen = True
            b_axis = "U" if axes_equal else AXIS[b[0]]
            if axes_equal:
                notes.append("기준선과 HEAD 의 트리가 같다 — 비교할 차이가 없다")
            verdict = ATTR[(b_axis, AXIS[h[0]])]
            if h[2] == "flaky":
                notes.append(f"flaky 재실행 1회 → {h[0]}")
            if (verdict == "PRE_EXISTING" and gran != "bulk"
                    and "bulk" in (b[2], h[2])):
                smeared = True   # 한 종료 코드가 여러 unit 에 찍힌 양측 red — 회귀를 가릴 수 있다(R9)
                notes.append("bulk 실행의 양측 red — unit 별로 판정되지 않았다")
        counts[verdict.lower()] += 1
        attributions.append((unit, verdict, "; ".join(notes)))
    if counts["baseline_unrunnable"]:
        causes.append("baseline-unrunnable")
    if counts["silent_drop"]:
        causes.append("silent-drop")
    if error_seen:
        causes.append("error-axis")
    if gran == "bulk" and counts["pre_existing"]:
        causes.append("bulk-pre-existing")
    if smeared:
        causes.append("smeared")
    return attributions, counts, causes


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--assign", required=True)
    ap.add_argument("--rows", required=True)
    ap.add_argument("--iter", required=True, type=int)
    ap.add_argument("--baseline-commit", required=True)
    ap.add_argument("--head-commit", required=True)
    args = ap.parse_args()
    for name in ("baseline_commit", "head_commit"):
        if not SHA.fullmatch(getattr(args, name)):
            print(f"diff-test-results: --{name.replace('_', '-')} 는 전체 sha 또는 '-' 다", file=sys.stderr)
            return 2

    assign, detected = read_assign(Path(args.assign))
    unclaimed = [u for u, r, _ in assign if r == "unclaimed"]
    by_runner: dict[str, list[tuple[str, str]]] = {}
    for unit, runner, gran in assign:
        if runner != "unclaimed":
            by_runner.setdefault(runner, []).append((unit, gran))
    axes_equal = same_tree(args.baseline_commit, args.head_commit)
    memo = Path(args.rows)

    causes: list[str] = []
    if not by_runner:
        causes.append("expected-empty")
    if not detected:
        causes.append("no-adapters")
    if unclaimed:
        causes.append("silent-drop")   # 고른 unit 을 어느 어댑터도 못 돌린다(R16)
    blocks, totals = [], {c.lower(): 0 for c in CATEGORIES}
    for runner in sorted(by_runner):
        gran = granularity_of(runner)
        units = [u for u, g in by_runner[runner]]
        if any(g != gran for _, g in by_runner[runner]):
            fail4(f"배정 파일의 입도가 러너 {runner} 의 입도 {gran} 와 다르다")
        base = read_rows(memo / f"baseline-{runner}.tsv", runner, args.baseline_commit, "baseline")
        head = read_rows(memo / f"head-{runner}-i{args.iter}.tsv", runner, args.head_commit)
        attributions, counts, adapter_causes = attribute(runner, gran, units, base, head, axes_equal)
        for k, v in counts.items():
            totals[k] += v
        for c in adapter_causes:
            if c not in causes:
                causes.append(c)
        blocks.append((runner, gran, attributions, counts, adapter_causes))
    causes.sort(key=DEGRADE_CAUSES.index)

    defect = any(totals[d.lower()] for d in DEFECTS)
    out = [f"adapters: [{', '.join(r for r, *_ in blocks)}]",
           "verdict_input:",
           f"  confirmed_product_defect: {'true' if defect else 'false'}",
           f"  silent_drop: {'true' if totals['silent_drop'] or unclaimed else 'false'}",
           f"  baseline_unrunnable: {'true' if totals['baseline_unrunnable'] else 'false'}",
           f"attribution_status: {'degraded' if causes else 'closed'}",
           f"degrade_causes: [{', '.join(causes)}]",
           f"new_failures: {totals['new_regression'] + totals['new_test_red']}"]
    out.append("unclaimed: [" + ", ".join(yaml_str(u) for u in unclaimed) + "]")
    if totals["pre_existing"]:
        # 양측 red 는 막지 않고 공시한다 — 그 안의 새 실패는 이 해상도에서 보이지 않는다(R10).
        out.append("resolution_disclosure: " + yaml_str(
            f"양측 빨강 unit {totals['pre_existing']}개 — 그 안의 새 실패는 "
            "이 해상도(unit 당 종료 코드 하나)에서 보이지 않는다"))
    out.append("per_adapter:" if blocks else "per_adapter: []")
    for runner, gran, attributions, counts, adapter_causes in blocks:
        out.append(f"  - runner: {runner}")
        out.append(f"    granularity: {gran}")
        out.append(f"    causes: [{', '.join(adapter_causes)}]")
        out.append("    counts: {" + ", ".join(f"{c.lower()}: {counts[c.lower()]}" for c in CATEGORIES) + "}")
        out.append("    attributions:" if attributions else "    attributions: []")
        for unit, verdict, note in attributions:
            out.append(f"      - unit: {yaml_str(unit)}")
            out.append(f"        verdict: {verdict}")
            out.append(f"        note: {yaml_str(note)}")
    print("\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
