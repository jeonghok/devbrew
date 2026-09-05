#!/usr/bin/env python3
"""synthesize_artifact_findings.py — §10 deterministic artifact-finding pipeline.

Two phases (the same dedup_key/stagnation_key algorithm lives once here):

  --phase key --findings A [--findings B ...]
      Merge critic + codex findings, within-round dedup by dedup_key (first wins,
      merge `agent` into `sources`), inject dedup_key + stagnation_key, emit
      `findings: [...]` plus `sources_failed: <N>` (count of source files that
      failed to load — made visible instead of silently skipped, so a partial
      merge can't masquerade as a complete one). Runs BEFORE adversarial so
      adversarial can echo dedup_key.

  --phase synth --findings MERGED --adversarial VERDICTS
      Apply verdicts (confirm/downgrade/reject) by finding_key == dedup_key,
      compute the fail-closed kept set, and emit convergence / degraded /
      degraded_reason (adversarial|findings_load|sources_failed|none) /
      unadjudicated / severity counts / stagnation_keys / kept list. A
      findings-side load failure (missing/unparseable --findings file) or a
      nonzero `sources_failed` carried on the merged doc also forces
      degraded=true (fail-closed), symmetric to the adversarial-side guard —
      neither can silently false-converge.

Schema: see plan Global Constraints "데이터 계약".
"""
import argparse
import hashlib
import sys

import yaml

from adjudication import Ledger
from render_disposition import disposition_lines, disposition_report

SEV = {"CRITICAL", "IMPORTANT", "SUGGESTION"}


def _norm(s):
    return " ".join(str(s if s is not None else "").strip().lower().split())


def dedup_key(f):
    raw = _norm(f.get("category")) + "\0" + _norm(f.get("target_anchor")) + "\0" + _norm(f.get("summary"))
    return hashlib.sha1(raw.encode("utf-8")).hexdigest()[:12]


def stagnation_key(f):
    raw = _norm(f.get("category")) + "\0" + _norm(f.get("target_anchor"))
    return hashlib.sha1(raw.encode("utf-8")).hexdigest()[:12]


def _norm_sev(f):
    # fail-closed: an unknown or missing severity (a reviewer emitting BLOCKER/HIGH,
    # a typo like CRITCAL, or omitting the field) must NOT silently become the one
    # non-blocking level (SUGGESTION) -- that would let a mislabeled grave finding
    # pass convergence. Treat anything off-vocab as CRITICAL (blocking + surfaced).
    s = str(f.get("severity", "")).upper()
    return s if s in SEV else "CRITICAL"


_SEV_RANK = {"CRITICAL": 3, "IMPORTANT": 2, "SUGGESTION": 1}


def _sev_rank(s):
    return _SEV_RANK.get(str(s).upper(), 0)


def _load(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return yaml.safe_load(fh)
    except (OSError, yaml.YAMLError, UnicodeError):
        # broadened from (FileNotFoundError, yaml.YAMLError): a source that is a
        # directory (IsADirectoryError), non-UTF-8 (UnicodeDecodeError), or
        # permission-denied (PermissionError) must degrade to the sentinel, not
        # raise uncaught and crash phase_key into a 0-byte merged doc (fail-closed).
        return "__ERR__"


def _findings_of(doc):
    if isinstance(doc, dict) and isinstance(doc.get("findings"), list):
        return doc["findings"]
    if isinstance(doc, list):
        return doc
    return []


def _is_findings_doc(doc):
    # A well-formed findings source/merged doc is a bare list of findings OR a dict
    # carrying a `findings:` list. Anything else -- "__ERR__", None, a scalar, or a
    # dict without a findings list (a bare `codex_failed: true`, or reviewer prose
    # parsed to a scalar) -- is malformed and must be counted as a load failure,
    # never silently read as a genuine zero-findings source (fail-closed).
    if isinstance(doc, list):
        return True
    return isinstance(doc, dict) and isinstance(doc.get("findings"), list)


def phase_key(paths, ledger=None):
    by_key = {}
    sources_failed = 0
    for p in paths:
        doc = _load(p)
        if not _is_findings_doc(doc):
            sources_failed += 1  # __ERR__/None/scalar/wrong-schema: count the loss, never a silent 0-findings
            if ledger is not None:
                ledger.source_failed(str(p), "findings 문서가 아니다", primary=False)
            continue
        for f in _findings_of(doc):
            if not isinstance(f, dict):
                sources_failed += 1  # a malformed (non-mapping) finding entry is a lost finding, not a silent skip
                if ledger is not None:
                    ledger.hold(repr(f)[:60], "항목 파손: not a mapping")
                continue
            g = dict(f)
            g["severity"] = _norm_sev(g)
            k = dedup_key(g)
            g["dedup_key"] = k
            g["stagnation_key"] = stagnation_key(g)
            if k in by_key:
                srcs = set(by_key[k].get("sources", [by_key[k].get("agent", "?")]))
                srcs.add(g.get("agent", "?"))
                by_key[k]["sources"] = sorted(srcs)
                # keep the STRICTEST severity across duplicate sources, so a higher-severity
                # duplicate (codex CRITICAL vs critic SUGGESTION on the same dedup_key) is
                # never discarded by first-wins (fail-closed severity merge).
                if _sev_rank(g["severity"]) > _sev_rank(by_key[k]["severity"]):
                    by_key[k]["severity"] = g["severity"]
            else:
                g["sources"] = [g.get("agent", "?")]
                by_key[k] = g
    fields = ("agent", "sources", "category", "target_anchor", "target_lines",
              "severity", "summary", "proposed_fix", "dedup_key", "stagnation_key")
    out = {
        "findings": [{k: f.get(k) for k in fields if f.get(k) is not None} for f in by_key.values()],
        "sources_failed": sources_failed,
    }
    sys.stdout.write(yaml.safe_dump(out, allow_unicode=True, sort_keys=False))


def phase_synth(findings_path, adversarial_path):
    merged_doc = _load(findings_path)
    # fail-closed: a missing / unparseable / empty / degenerate --findings file must
    # not silently read as "no findings". A genuine clean merge is ALWAYS a dict with
    # a `findings:` list (phase_key emits {findings, sources_failed}), so anything that
    # is not a findings doc ("__ERR__", None, scalar, wrong-schema) is a load failure.
    # An empty findings_path (synth invoked with no --findings at all) is itself a
    # failure -- it must never read as a clean zero-findings round.
    findings_load_failed = (not findings_path) or (not _is_findings_doc(merged_doc))
    findings = [dict(f) for f in _findings_of(merged_doc) if isinstance(f, dict)]
    for f in findings:
        f.setdefault("dedup_key", dedup_key(f))
        f["severity"] = _norm_sev(f)

    sources_failed = merged_doc.get("sources_failed", 0) if isinstance(merged_doc, dict) else 0
    # a malformed sources_failed (non-int, bool, or negative) means the merged doc is
    # corrupt -- treat it as a load failure rather than silently resetting the loss to 0.
    if not isinstance(sources_failed, int) or isinstance(sources_failed, bool) or sources_failed < 0:
        findings_load_failed = True
        sources_failed = 0

    L = Ledger(items="closed")   # 다음 소비자가 기계(자동 편집)다 — 미판정은 제외
    if findings_load_failed:
        # primary=True — 주 입력이 통째로 죽었으면 «아무도 안 봤다».
        L.source_failed(str(findings_path or "<no --findings>"),
                        "findings 문서 로드 실패", primary=True)
    if sources_failed > 0:
        L.source_failed("phase_key merge", "%d건 소실" % sources_failed,
                        primary=False)

    adv_doc = _load(adversarial_path) if adversarial_path else None
    adv_parse_failed = adv_doc == "__ERR__" or adv_doc is None
    adv_schema_failed = False
    verdicts, new_findings = [], []
    if isinstance(adv_doc, dict):
        # A present-but-non-list `verdicts`/`new_findings` is MALFORMED, not empty:
        # silently coercing it to [] would drop a real (mis-shaped) new_finding and,
        # when critic/codex were clean (had_findings False), read as converged. Absent
        # (None) is a legitimate empty; a non-list value is a schema failure -> degrade.
        # A list is not enough: every ELEMENT must be a mapping. A non-mapping entry
        # (e.g. new_findings: ["IMPORTANT: rollback unspecified"]) would be silently
        # skipped by the by_v / kept loops below and, with critic/codex clean, read as
        # converged -- so any malformed element degrades the round (fail-closed).
        _v = adv_doc.get("verdicts")
        if _v is None:
            verdicts = []
        elif isinstance(_v, list):
            verdicts = _v
            if any(not isinstance(x, dict) for x in _v):
                adv_schema_failed = True
        else:
            adv_schema_failed = True
        _nf = adv_doc.get("new_findings")
        if _nf is None:
            new_findings = []
        elif isinstance(_nf, list):
            new_findings = _nf
            if any(not isinstance(x, dict) for x in _nf):
                adv_schema_failed = True
        else:
            adv_schema_failed = True
    elif not adv_parse_failed:
        # adv_doc loaded but is a list/scalar, not a mapping -> malformed adversarial output.
        adv_schema_failed = True

    by_v = {v.get("finding_key"): v for v in verdicts if isinstance(v, dict)}

    kept = []
    for f in findings:
        v = by_v.get(f["dedup_key"])
        if v is None:
            L.hold(f["dedup_key"], "판정자 부재: adversarial 판정 없음")   # AC16: kept 에서 제외
            continue
        verdict = str(v.get("verdict", "")).lower()
        if verdict == "reject":
            L.reject(f["dedup_key"], "adversarial 기각")
            continue
        if verdict == "downgrade":
            ns = str(v.get("new_severity", "")).upper()
            if ns in SEV:
                f = dict(f)
                f["severity"] = ns
            # missing/invalid new_severity -> keep original severity (fail-closed: don't drop)
        L.accept(f["dedup_key"])
        kept.append(f)
    unadjudicated = L.report()["counts"]["held"]

    kept_keys = {f["dedup_key"] for f in kept}
    for nf in new_findings:
        if not isinstance(nf, dict):
            L.hold(repr(nf)[:60], "항목 파손: not a mapping")
            continue
        g = dict(nf)
        g["severity"] = _norm_sev(g)
        g["dedup_key"] = dedup_key(g)
        if g["dedup_key"] in kept_keys:
            L.absorbed(g["dedup_key"], g["dedup_key"])
            continue
        kept_keys.add(g["dedup_key"])
        kept.append(g)

    had_findings = len(findings) > 0
    # A parse/schema failure of the adversarial output degrades REGARDLESS of whether
    # there were prior findings (a malformed adversarial pass can't certify a clean
    # round). The "verdicts empty" case only degrades when there were findings to
    # adjudicate -- a genuine no-findings round with a well-formed empty verdicts list
    # is a real clean.
    adv_degraded = adv_parse_failed or adv_schema_failed or (had_findings and len(verdicts) == 0)
    # symmetric fail-closed guard: an adversarial-side failure, a findings-side load
    # failure, or a lossy phase-key merge (sources_failed>0) must each independently
    # force degraded=true — none of them may silently read as a genuine clean round.
    degraded = adv_degraded or findings_load_failed or (sources_failed > 0)
    # 원장이 독립으로 계산한 degrade. 위 4값 어휘는 소비자 계약이라 유지하고,
    # 원장은 «더해서» 낸다 — 둘이 갈리면 그 자체가 회귀 신호다.
    ledger_report = L.report()
    ledger_degraded = ledger_report["degraded"]
    if adv_degraded:
        degraded_reason = "adversarial"
    elif findings_load_failed:
        degraded_reason = "findings_load"
    elif sources_failed > 0:
        degraded_reason = "sources_failed"
    else:
        degraded_reason = "none"

    crit = sum(1 for f in kept if f["severity"] == "CRITICAL")
    imp = sum(1 for f in kept if f["severity"] == "IMPORTANT")
    sug = sum(1 for f in kept if f["severity"] == "SUGGESTION")
    # An un-adjudicated finding (adversarial never returned a verdict for it) is
    # excluded from kept fail-closed, so it can't inflate crit/imp -- but that
    # also means it must NOT be silently read as "resolved". Requiring
    # unadjudicated==0 closes that false-convergence gap: a persistently
    # un-adjudicated finding then makes no edit (kept is missing it) -> step 6b
    # reports changed:false -> stagnation(b) ends the loop as *stagnant*
    # (honest), never as *converged* (false-clean).
    converged = (not degraded) and (crit + imp == 0) and (unadjudicated == 0)
    skeys = sorted({stagnation_key(f) for f in kept})

    out = {
        "converged": converged,
        "degraded": degraded,
        "degraded_reason": degraded_reason,
        "unadjudicated": unadjudicated,
        "kept_critical": crit,
        "kept_important": imp,
        "kept_suggestion": sug,
        "stagnation_keys": ",".join(skeys),
        "ledger": dict(ledger_report["counts"], degraded=ledger_degraded),
        "adjudication": disposition_report(L.report(), L.held_by_class()),
        "kept": [
            {k: f.get(k) for k in ("category", "target_anchor", "target_lines",
                                   "severity", "summary", "proposed_fix", "dedup_key")
             if f.get(k) is not None}
            for f in kept
        ],
    }
    sys.stdout.write(yaml.safe_dump(out, allow_unicode=True, sort_keys=False))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--phase", choices=["key", "synth"], required=True)
    ap.add_argument("--findings", action="append", default=[])
    ap.add_argument("--adversarial", default="")
    args = ap.parse_args()
    if args.phase == "key":
        # `phase_key`의 입력 실패 배선(Task 9)은 `ledger` 인자를 받아야 도는데,
        # 이 호출부가 여태 `ledger=None`으로 불러 가드 안쪽이 영영 안 돌았다
        # (Task 9 브리프의 누락 — Task 10 이 메운다). key 단계의 다음 소비자는
        # 사람이다 — 미판정은 라벨을 달아 stderr 로 보인다(items="open").
        L = Ledger(items="open")
        phase_key(args.findings, ledger=L)
        disp_line, plumb_line, advisories = disposition_lines(
            L.report(), L.held_by_class())
        # stdout 이 아니라 stderr 다 — key 단계의 stdout 은 phase_synth 가 다시
        # 읽는 findings 문서라, 거기에 키를 더하면 `_is_findings_doc` 스키마
        # 판정을 건드린다.
        for line in (disp_line, plumb_line, *advisories):
            sys.stderr.write(line + "\n")
    else:
        findings_path = args.findings[0] if args.findings else ""
        phase_synth(findings_path, args.adversarial)


if __name__ == "__main__":
    main()
