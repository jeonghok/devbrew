#!/usr/bin/env python3
"""Synthesizer (T3-2 refactor) — deterministic finding aggregator.

Replaces agents/synthesizer.md Agent dispatch. The algorithm is fully
deterministic (no LLM judgment): apply Adversarial verdicts → group/dedup
by (file,line,severity) → suppress non-CRITICAL confidence<=4 (CRITICAL always
kept; confidence 5-6 shown with a `*` caveat) → sort severity-desc /
confidence-desc / file-asc → render Markdown table.

Inputs (CLI args):
  --adversarial PATH   YAML file with `verdicts: [...]` (or top-level list)
  --findings PATH      YAML file with list of raw findings

Output (stdout): Markdown matching agents/synthesizer.md schema.
"""
import argparse
import sys
import yaml
from collections import defaultdict

from adjudication import Ledger


SEV_ORDER = {"CRITICAL": 0, "IMPORTANT": 1, "SUGGESTION": 2}


def load_yaml(path, ledger=None):
    """Return `(list, dropped)` — 이 경로도 `_as_list` 초크포인트를 통과한다.

    예전에는 여기서만 `or []`로 끝나서 `findings: "CRITICAL: ..."` 같은 스칼라가
    그대로 반환되고 apply_verdicts가 **글자 단위로** 순회했다(문자 하나당 드롭 1건).
    `_as_list`의 docstring이 "ingestion 한 곳에서 타입을 확정한다"고 주장하는데
    정작 주 수집 경로가 그 한 곳을 우회하고 있었다.

    #7 — 「경로 없음」과 「경로는 있는데 파일이 없음」은 다른 사건이다. 전자는
    이 실행에서 그 소스를 쓰지 않기로 한 것이지 실패가 아니다. 후자는 입력
    실패다 — 예전엔 둘 다 `([], 0)`으로 합쳐져서, 파일이 사라져도 dropped=0 이라
    render()의 공지가 영원히 안 켜졌다.
    """
    if not path:
        # 경로가 아예 없다 — 실패가 아니다. 여기서 source_failed 를 올리면
        # 정상 실행이 degraded 가 된다.
        return [], 0
    try:
        with open(path, encoding="utf-8") as f:
            data = yaml.safe_load(f) or []
    except FileNotFoundError:
        # 경로는 주어졌는데 파일이 없다 — 입력 실패다.
        if ledger is not None:
            ledger.source_failed(str(path), "FileNotFoundError", primary=True)
        return [], 0
    if isinstance(data, dict) and "verdicts" in data:
        return _as_list(data.get("verdicts"), "verdicts")
    if isinstance(data, dict) and "findings" in data:
        return _as_list(data.get("findings"), "findings")
    return _as_list(data, "findings document")


def load_yaml_doc(path):
    """Load a YAML file and return the raw parsed document (no key flattening).

    load_yaml() flattens `{verdicts: [...]}` down to the list, which discards
    every sibling key. The adversarial document now carries a second top-level
    key (`new_findings`), so the raw document has to survive the load.
    """
    if not path:
        return None
    try:
        with open(path, encoding="utf-8") as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        return None


def _as_list(value, what):
    """Return `(list, dropped)` — `value` if it is a list, else `([], n)`.

    `or []` only rescues *falsy* values — `new_findings: 5` and
    `verdicts: {a: 1}` sail through it and reach a `for` loop, where a scalar
    raises `TypeError: 'int' object is not iterable` and kills the whole
    synthesis: exit 1, **stdout completely empty**, every other reviewer's real
    CRITICAL destroyed along with it (2026-08-05 재현).

    이것이 ingestion 한 곳에서 타입을 확정하는 이유다. 소비 지점마다 가드를
    덧대면 malformed가 한 겹씩 새고(`_conf`의 docstring과 같은 논거), 실제로
    `confidence`를 막은 뒤 컨테이너 타입이 그대로 열려 있었다.

    소실 **건수**까지 돌려주는 것이 이 함수의 절반이다. stderr만 찍고 0을
    돌려주면 `dropped_malformed`가 0으로 남고, 그 값을 읽는 render()의 공지가
    나가지 않으며, 그 공지에 keying하는 SKILL의 Dropped-finding override도
    발화하지 못한다 — 버려진 CRITICAL이 **다시 clean으로 렌더된다**. 라운드 2가
    이 함수를 만들면서 회계를 빼먹어 정확히 그 구멍이 남았다 (2026-08-05 재현).
    """
    if isinstance(value, list):
        return value, 0
    if not value:                                # falsy는 정상적인 "없음"이다
        return [], 0
    # 매핑이면 항목 수가 곧 소실 건수다(`new_findings: {a: {...}, b: {...}}` = 2건).
    # 스칼라는 주장 하나로 센다 — 문자열의 len()은 글자 수라 의미가 없다.
    lost = len(value) if isinstance(value, dict) else 1
    print(f"[synthesize_findings] {what} is {type(value).__name__}, "
          f"expected list — {lost}건 무시하고 계속한다"
          "(해당 입력은 심사되지 않았다)", file=sys.stderr)
    return [], lost


def extract_verdicts(doc):
    if isinstance(doc, dict):
        return _as_list(doc.get("verdicts"), "verdicts")
    return _as_list(doc, "adversarial document")


def extract_new_findings(doc):
    if isinstance(doc, dict):
        return _as_list(doc.get("new_findings"), "new_findings")
    return [], 0


def _norm_file(f):
    """`file`을 해시 가능한 문자열로 확정한다.

    dedup()의 그룹핑 키가 `(file, line, severity)` 튜플인데, 라운드 2는 그중
    `severity`만 `_norm_sev`로 총함수화하고 나머지 둘을 raw로 남겼다. `file: [a.py]`
    하나면 defaultdict 조회가 `TypeError: unhashable type: 'list'`를 던지고
    exit 1 + stdout 공백 — 다른 리뷰어의 진짜 CRITICAL까지 함께 소실된다
    (2026-08-05 재현). 같은 튜플의 형제 원소를 놓친 것이 결함의 전부였다.
    """
    v = f.get("file", "")
    if isinstance(v, str):
        return v
    if isinstance(v, (list, tuple)):
        return ", ".join(str(x) for x in v)
    return str(v)


def _norm_line(f):
    """`line`을 int로 확정한다 — 표시와 정렬 tiebreak에만 쓰이므로 실패는 0."""
    v = f.get("line", 0)
    if isinstance(v, bool):                      # bool은 int의 하위형이다
        return 0
    if isinstance(v, int):
        return v
    try:
        return int(str(v).strip())
    except (TypeError, ValueError):
        return 0


def _normalize_identity(f):
    """수집 지점에서 스칼라 정체성 필드를 확정한다(소비 지점마다 가드 금지).

    `_conf`/`_norm_sev`가 값 수준에서, `_as_list`가 컨테이너 수준에서 하는 일을
    정체성 필드에 대해 한다. 소비 지점(dedup 키·sort tiebreak·finding_id·render)
    마다 가드를 덧대면 malformed가 한 겹씩 새고, 라운드 2가 정확히 그렇게 새어서
    `severity`만 막고 `file`/`line`은 열어뒀다.
    """
    f["file"] = _norm_file(f)
    f["line"] = _norm_line(f)
    return f


def finding_id(f):
    return f"{f.get('agent', 'unknown')}-{f.get('file', '')}-{f.get('line', '')}"


NEW_FINDING_REQUIRED = ("file", "severity", "summary")
# 승격된 발견의 기본 confidence. suppress()의 바닥(<=4)보다는 위라 표에 실리고,
# render()의 caveat 임계(<=6) 아래라 `*`가 붙는다 — 이 발견은 어떤 리뷰어의
# 판정도 통과하지 않았다(adversarial 자신의 주장이다). 보이되 검증 안 됨으로
# 표시하는 것이 정직한 인코딩이다. 리뷰어가 명시적으로 confidence를 주면 그것을 쓴다.
NEW_FINDING_DEFAULT_CONFIDENCE = 5


def _conf(f):
    """Coerce a finding's confidence to an int without ever raising.

    `confidence` arrives from reviewer-authored YAML and is read wherever a
    finding is ordered, filtered, or displayed. 예전에는 그 자리마다 맨 `int()`가
    있었다: 어느 리뷰어든 `confidence: high`나 YAML null 하나를 실으면
    ValueError/TypeError로 합성 전체가 죽고 **stdout이 완전히 비었다**. 같이 죽는
    것에는 다른 리뷰어의 진짜 CRITICAL도 포함된다 (2026-08-04 재현).

    소비 지점마다 가드를 붙이지 않고 여기 한 곳에서 강제하는 이유: 부분 가드는
    malformed 입력 앞에서 한 겹씩 샌다 — 새 소비자가 생기면 그 자리에서 다시
    터진다. 실제로 이 수정을 처음 넣을 때 소비자 세 곳만 세고 네 번째
    (sort_findings)를 놓쳐 그대로 재현됐다. 값을 버리지 않고 기본값 + loud
    stderr로 낮추는 이유: 잘못된 숫자 하나 때문에 진짜 결함을 숨기는 것보다,
    보이되 검증 안 됨으로 표시하는 것이 정직하다.
    """
    raw = f.get("confidence", 0)
    try:
        return int(raw)
    except (TypeError, ValueError):
        print("[synthesize_findings] non-numeric confidence "
              f"{raw!r} on {f.get('file')}:{f.get('line')} — "
              f"treating as {NEW_FINDING_DEFAULT_CONFIDENCE}", file=sys.stderr)
        return NEW_FINDING_DEFAULT_CONFIDENCE


def promote_new_findings(raw_new, existing):
    """adversarial의 `new_findings:` 항목을 진짜 finding으로 승격한다.

    Returns (promoted, dropped_malformed).

    출처는 `agent`에 쓴다 — `source`(단수)가 **아니다**. dedup()은 `agent`를 모아
    `sources`를 만들고 render()는 `sources`/`agent`만 읽으므로, `source`로 쓰면
    Source 컬럼이 fallback `?`로 렌더된다.

    id는 verdict가 준 값을 믿지 않고 기존 finding_id() 헬퍼로 합성한다 — 그래야
    신규 발견이 다른 agent의 finding id를 참칭할 수 없다. 기존과 충돌하면 기존이
    이기고(신규를 버리고 loud 기록), 신규끼리 충돌하면 `-2`, `-3` … 를 붙여
    결정론적으로 분리한다.

    승격된 항목에는 `promoted: True`를 찍는다. dedup()은 이 표식을 보고 해당
    항목을 그룹핑에서 **제외**한다 — 승격 이전에는 (file, line, severity) 충돌이
    언제나 "두 리뷰어가 같은 것을 봤다"라 병합이 옳았지만, 승격이 생기면서 충돌이
    "같은 줄의 *다른* 결함"일 수 있게 됐기 때문이다. 병합되면 발견 하나가 조용히
    사라지고, 더 나쁘게는 살아남은 행의 `sources`에 adversarial이 붙어 **하지 않은
    주장을 보증한 것처럼** 렌더된다(2026-08-03 재현, `test_…_promoted_findings.sh`
    케이스 5·6). 실패 방향을 소실이 아니라 중복 쪽으로 돌리는 최소 봉쇄다.

    범위 밖(설계 §11 CHECKS-07): dedup() 자체의 키 설계와 `sources`가 "같은 좌표에
    보고한 agent"인지 "이 발견에 동의한 agent"인지의 의미론은 여전히 미해결이다.
    이 봉쇄는 승격 경로만 그 미해결에서 떼어낸다.
    """
    promoted, dropped = [], 0
    seen = {finding_id(f) for f in existing if isinstance(f, dict)}
    for item in raw_new:
        if not isinstance(item, dict):
            dropped += 1
            print("[synthesize_findings] dropped malformed adversarial finding: "
                  "not a mapping", file=sys.stderr)
            continue
        missing = [k for k in NEW_FINDING_REQUIRED if not item.get(k)]
        if missing:
            dropped += 1
            print("[synthesize_findings] dropped malformed adversarial finding: "
                  f"missing {', '.join(missing)}", file=sys.stderr)
            continue
        f = dict(item)
        # `sources`는 리뷰어가 준 값을 절대 믿지 않는다. render()가 Source 컬럼에
        # 그대로 찍는 유일한 키인데, 승격 항목은 dedup()의 그룹핑을 건너뛰므로
        # (`promoted: True` → passthrough) 병합이 이 값을 덮어쓸 기회조차 없다.
        # adversarial 출력에 `sources: [security-reviewer, code-reviewer]`가 실리면
        # **아무 리뷰어도 하지 않은 주장이 교차 보증을 받은 것처럼 렌더된다**
        # (2026-08-05 재현). `agent`만 강제하고 이 채널을 열어두면 id 참칭은 막고
        # 표시 계층의 참칭은 그대로 남는다 — 후자가 사용자에게 더 직접적이다.
        f.pop("sources", None)
        f["agent"] = "adversarial"
        f["promoted"] = True
        # 승격 경로도 같은 초크포인트를 쓴다 — `file: [a.py]`가 truthy라 필수-키
        # 검사를 통과한 뒤 sort_findings의 raw 비교에서 TypeError를 냈다.
        _normalize_identity(f)
        f.setdefault("confidence", NEW_FINDING_DEFAULT_CONFIDENCE)
        fid = finding_id(f)
        if fid in seen:
            base = fid
            suffix = 2
            while f"{base}-{suffix}" in seen:
                suffix += 1
            fid = f"{base}-{suffix}"
            print("[synthesize_findings] adversarial finding id collision on "
                  f"{base}; disambiguated to {fid}", file=sys.stderr)
        seen.add(fid)
        f["finding_id"] = fid
        promoted.append(f)
    return promoted, dropped


def apply_verdicts(findings, verdicts, ledger=None):
    """Apply adversarial verdicts. Returns (out, dropped_malformed).

    `dropped`를 세는 이유: 예전에는 non-mapping finding을 맨 `continue`로 버렸다 —
    카운터도, stderr도, stdout 공지도 없이. 리뷰어가 발견을 문자열로 내면
    (`- "CRITICAL: hardcoded key in config.py:11"`) 주장이 통째로 증발하고
    stdout은 `No high-confidence findings.`, exit 0이었다. 즉 **버려진 CRITICAL이
    clean으로 렌더**됐다 (2026-08-05 재현).

    같은 결함을 adversarial 승격 경로에서는 이미 막아놨었다. 이 함수만 계측
    밖이었다 — 한쪽 출처만 세는 drop 채널은 반쪽짜리 정직성이다.

    #8 — `ledger`가 주어지면 판정이 없는 finding(fail-open으로 keep)을
    `hold()`로 센다. 이 채널은 위 `dropped`(non-mapping)와 다르다: 건드리지
    않고 그대로 둔다.
    """
    by_id = {v.get("finding_id"): v for v in verdicts if isinstance(v, dict)}
    out = []
    dropped = 0
    for f in findings:
        if not isinstance(f, dict):
            dropped += 1
            print("[synthesize_findings] dropped malformed finding "
                  f"({type(f).__name__}, expected mapping): {str(f)[:80]!r}",
                  file=sys.stderr)
            continue
        # 수집 지점 정규화 — dedup 키(해시)·sort tiebreak(비교)·finding_id가 모두
        # 이 값을 raw로 만지므로, 여기서 확정하지 않으면 하류 어디서든 터진다.
        f = _normalize_identity(dict(f))
        v = by_id.get(finding_id(f))
        if v is None:
            # 유지한다(fail-open — 다음 소비자가 사람이다). 다만 «세지 않으면»
            # 판정이 있었던 것과 구별되지 않는다. 형제
            # synthesize_artifact_findings.py:197 에 unadjudicated += 1 이 있다.
            if ledger is not None:
                ledger.hold(finding_id(f), "adversarial 판정 부재")
            out.append(f)
            continue
        verdict = v.get("verdict", "confirm")
        if verdict == "reject":
            continue
        if verdict == "downgrade":
            f = dict(f)
            if "adjusted_severity" in v:
                f["severity"] = v["adjusted_severity"]
            if "adjusted_confidence" in v:
                f["confidence"] = v["adjusted_confidence"]
        out.append(f)
    return out, dropped


def dedup(findings):
    """(file, line, severity)가 같은 발견을 한 행으로 합치고 `sources`를 모은다.

    **승격된 발견(`promoted: True`)은 그룹핑에서 제외한다** — 근거는
    promote_new_findings()의 docstring. 요약하면: 승격 이전에는 좌표 충돌이 항상
    "두 리뷰어가 같은 것을 봤다"였지만 이제는 "같은 줄의 다른 결함"일 수 있고,
    합치면 발견이 조용히 사라지는 데다 `sources`가 허위 보증을 만든다.
    """
    passthrough = [f for f in findings if f.get("promoted")]
    by_key = defaultdict(list)
    for f in findings:
        if f.get("promoted"):
            continue
        key = (f.get("file"), f.get("line"), _norm_sev(f))
        by_key[key].append(f)
    deduped = []
    for key, group in by_key.items():
        group.sort(key=_conf, reverse=True)
        merged = dict(group[0])
        merged["sources"] = sorted({g.get("agent", "?") for g in group})
        deduped.append(merged)
    return deduped + passthrough


def suppress(findings):
    """C30 rubric (R4): kept vs suppressed.

    - CRITICAL: always kept (any confidence).
    - non-CRITICAL: confidence <= 4 -> suppressed; else kept.

    The caveat marker (`*`) is NOT decided here; it is a pure function of
    `confidence <= 6` on any *shown* finding, computed in render().
    """
    kept, suppressed = [], []
    for f in findings:
        # render()와 같은 정규화를 쓴다 — 예전에는 여기만 raw였고 render만
        # 정규화해서, 같은 발견이 억제 판정과 표시 판정에서 다른 severity로
        # 읽혔다(표기가 다른 CRITICAL이 여기서 비-CRITICAL로 취급됨).
        sev = _norm_sev(f)
        conf = _conf(f)
        if sev != "CRITICAL" and conf <= 4:
            suppressed.append(f)
        else:
            kept.append(f)
    return kept, suppressed


def sort_findings(findings):
    return sorted(findings, key=lambda f: (
        SEV_ORDER.get(_norm_sev(f), 9),
        -_conf(f),
        f.get("file", ""),
    ))


def _cell(value):
    """Escape Markdown-table-breaking characters in a single table cell.

    Cell values (summary, source, file) originate from reviewer-agent (LLM)
    output and can contain `|` or newlines, which would split or break a
    pipe-delimited table row. Escape `|` and collapse CR/LF to a space.
    """
    return str(value).replace("\r", "").replace("\n", " ").replace("|", "\\|")


def _norm_sev(f):
    """Return a finding's severity normalized to a known bucket.

    Reviewer personas constrain severity to {CRITICAL, IMPORTANT, SUGGESTION},
    but nothing enforces it at runtime. An unrecognized severity would render
    a table row yet be omitted from the counts line — and the SKILL boundary
    keys on that counts line, so a visible finding could be read as clean
    (kept=0). Normalize to SUGGESTION (warn to stderr) so counts == rows.

    대소문자를 먼저 접는 이유: 멤버십 검사가 정확 일치였을 때 `severity: Critical`
    한 글자 차이가 진짜 CRITICAL을 SUGGESTION으로 **강등**시켰다(2026-08-04 재현).
    강등은 조용하지 않았지만(stderr) 판정에 쓰이는 counts line은 이미 틀린 뒤였다.
    버킷을 못 알아본 것과 표기가 다른 것은 다른 사건이므로 다르게 다룬다.
    """
    sev = f.get("severity", "SUGGESTION")
    if isinstance(sev, str) and sev.strip().upper() in SEV_ORDER:
        return sev.strip().upper()
    # 가드는 **총(total)** 이어야 한다. 예전에는 여기서 `if sev not in SEV_ORDER`로
    # 떨어졌고, `severity: [CRITICAL]` 같은 비-해시가능 값이 오면 멤버십 검사 자체가
    # `TypeError: unhashable type: 'list'`를 던졌다 — exit 1, stdout 공백, 다른
    # 리뷰어의 진짜 CRITICAL 동반 소실 (2026-08-05 재현). `_norm_sev`는 dedup·
    # suppress·sort·render 네 곳에서 불리므로 폭발 반경이 파이프라인 전체다.
    print(
        f"[synthesize_findings] unknown severity {sev!r}; treating as SUGGESTION",
        file=sys.stderr,
    )
    return "SUGGESTION"


# degrade 공시의 고정 마커. 소실(`dropped as malformed`)과 **다른 사건**이다:
# 저쪽은 개별 주장이 버려진 것이고, 이쪽은 판정 «경로» 자체가 온전하지 않았던 것
# (주 입력 사망·셀 수 없음·게이트를 바꾼 강제). 둘을 한 문구로 합치면 어느 쪽이
# 났는지 stdout 에서 구별할 수 없다.
DEGRADE_MARKER = "판정 degrade"


def _degrade_block(degraded, degrade_reasons):
    """degrade 공시 줄들. 사유가 하나도 없어도 degraded 면 머리줄은 나간다.

    사유 문자열은 Ledger 가 만들지만 그 안의 item 이름은 리뷰어 저작 YAML 에서
    온다(`finding_id` = agent-file-line). 표 셀과 같은 문을 통과시킨다 — 개행이
    raw 로 나가면 이 블록 아래에 가짜 머리줄을 심을 수 있다.
    """
    if not degraded:
        return []
    out = [
        f"{DEGRADE_MARKER} — **이 실행은 clean이 아니다**: "
        "판정 경로가 온전하지 않았다.",
    ]
    out.extend(f"- {_cell(r)}" for r in degrade_reasons)
    return out


def render(findings, suppressed_count, dropped_malformed=0, held_count=0,
           degraded=False, degrade_reasons=()):
    if not findings:
        # drop 공지는 이 분기에도 반드시 나가야 한다. 예전에는 아래 표-있는
        # 경로에만 있었고, 살아남은 발견이 0이면 여기서 먼저 return해 공지가
        # 도달 불가였다. 그 조합(전부 malformed → kept 0 → suppressed 0)에서
        # SKILL은 stdout만 읽어 counts=0을 보고 `## Review gate: clean`을
        # 찍었다 — 버려진 CRITICAL 주장이 **깨끗함으로 렌더**됐다는 뜻이다
        # (2026-08-04 재현, exit 0). 소실을 stdout에서 볼 수 있게 만든다.
        out = [
            "## Review Findings (Synthesized)",
            "",
            f"No high-confidence findings. {suppressed_count} low-confidence "
            "findings suppressed.",
        ]
        if dropped_malformed > 0:
            out.append(
                f"{dropped_malformed} finding(s) dropped as "
                "malformed (not a mapping, wrong container type, or missing "
                "file/severity/summary) — see stderr. "
                "**이 실행은 clean이 아니다**: 버려진 주장은 심사되지 않았다."
            )
        if held_count > 0:
            # 이 줄은 개수만 싣는다 — finding summary 는 여기 들어오지 않는다.
            out.append(f"미판정 {held_count}건 — adversarial 판정이 없어 유지됐다.")
        out.extend(_degrade_block(degraded, degrade_reasons))
        return "\n".join(out) + "\n"

    counts = {"CRITICAL": 0, "IMPORTANT": 0, "SUGGESTION": 0}
    rows = []
    any_caveat = False
    for f in findings:
        sev = _norm_sev(f)
        counts[sev] += 1
        conf = _conf(f)
        if conf <= 6:
            conf_cell = f"{conf} *"
            any_caveat = True
        else:
            conf_cell = f"{conf}"
        path_line = _cell(f"{f.get('file')}:{f.get('line')}")
        summary = _cell(f.get("summary", ""))
        # `sources`는 리뷰어 YAML에서 온다 — 리스트라는 보장도, 원소가 문자열이라는
        # 보장도 없다. 맨 `", ".join(...)`은 `sources: [1, 2]` 하나에
        # `TypeError: sequence item 0: expected str` 로 렌더 전체를 죽였다.
        srcs = f.get("sources") or [f.get("agent", "?")]
        if not isinstance(srcs, (list, tuple)):
            srcs = [srcs]
        source = _cell(", ".join(str(s) for s in srcs))
        rows.append(f"| {sev} | {path_line} | {conf_cell} | {summary} | {source} |")

    counts_line = (
        f"**Findings:** {counts['CRITICAL']} CRITICAL / "
        f"{counts['IMPORTANT']} IMPORTANT / {counts['SUGGESTION']} SUGGESTION"
    )
    if suppressed_count > 0:
        counts_line += f" — {suppressed_count} suppressed (conf <= 4)"
    if held_count > 0:
        # 이 줄은 개수만 싣는다 — finding summary 는 여기 들어오지 않는다.
        counts_line += f" — 미판정 {held_count}건"

    out = ["## Review Findings (Synthesized)", "", counts_line, ""]
    degrade_lines = _degrade_block(degraded, degrade_reasons)
    if degrade_lines:
        out.extend(degrade_lines)
        out.append("")
    out.append("| Sev | Path:Line | Conf | Summary | Source |")
    out.append("|---|---|---|---|---|")
    out.extend(rows)
    out.append("")
    if any_caveat:
        out.append("`*` = confidence <= 6 (treat with caution).")
    if suppressed_count > 0:
        out.append(
            f"{suppressed_count} finding(s) suppressed (conf <= 4); "
            "re-run with `/qg --show-low-confidence` to see all."
        )
    if dropped_malformed > 0:
        out.append(
            f"{dropped_malformed} finding(s) dropped as malformed "
            "(not a mapping, wrong container type, or missing "
            "file/severity/summary) — see stderr."
        )
    out.append("")
    out.append("**Suggested fixes:**")
    for f in findings:
        fix = str(f.get("proposed_fix", "(none)")).replace("\r", " ").replace("\n", " ")
        out.append(f"- `{f.get('file')}:{f.get('line')}` — {fix}")
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--adversarial", default="")
    ap.add_argument("--findings", default="")
    args = ap.parse_args()

    ledger = Ledger(items="open")

    doc = load_yaml_doc(args.adversarial) if args.adversarial else None
    verdicts, dropped_verdicts = extract_verdicts(doc)
    raw, dropped_raw = (load_yaml(args.findings, ledger=ledger)
                        if args.findings else ([], 0))

    findings, dropped_primary = apply_verdicts(raw, verdicts, ledger=ledger)
    new_raw, dropped_newlist = extract_new_findings(doc)
    promoted, dropped_promoted = promote_new_findings(new_raw, findings)
    # 모든 출처의 소실을 **한 채널로** 합친다. 하나라도 빠지면 stdout 공지가
    # 반쪽이 되고, 반쪽짜리 공지는 "이 실행은 clean이 아니다"를 말할 자격이 없다.
    # 컨테이너 수준(dropped_raw / dropped_verdicts / dropped_newlist)과 항목
    # 수준(dropped_primary / dropped_promoted)이 **둘 다** 여기 들어와야 한다 —
    # 라운드 2는 항목 수준만 세어서 컨테이너 소실이 0으로 보고됐다.
    dropped_malformed = (dropped_raw + dropped_verdicts + dropped_newlist
                         + dropped_primary + dropped_promoted)
    findings = findings + promoted          # 기존 뒤에 append — 기존 표 순서를 흔들지 않는다
    findings = dedup(findings)
    kept, suppressed = suppress(findings)
    kept = sort_findings(kept)

    # 원장은 «회계»만 한다 — 읽어서 stdout 에 싣는 것은 이 소비자의 책임이다.
    # 라운드 4 이전에는 `held` 만 꺼내 갔고 `degraded`/`reasons` 는 어디로도 가지
    # 않았다: 주 입력이 통째로 죽어도 출력이 clean 과 **바이트 동일**이었다.
    report = ledger.report()
    held_count = report["counts"]["held"]
    sys.stdout.write(render(kept, len(suppressed), dropped_malformed, held_count,
                            report["degraded"], report["reasons"]))


if __name__ == "__main__":
    main()
