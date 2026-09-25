#!/usr/bin/env python3
"""Synthesizer (T3-2 refactor) — deterministic finding aggregator.

Replaces agents/synthesizer.md Agent dispatch. The algorithm is fully
deterministic (no LLM judgment): apply adjudicator verdicts → group/dedup
by (file,line,severity) → suppress non-CRITICAL confidence<=4 (CRITICAL always
kept; confidence 5-6 shown with a `*` caveat) → sort severity-desc /
confidence-desc / file-asc → render Markdown table.

Inputs (CLI args):
  --findings PATH      YAML file with list of raw findings
  --recritic PATH      재비판자(doc-recritic) 응답 원문 — `--recritic-map` 과 함께
  --recritic-map PATH  `recritic_bridge.py prepare` 가 쓴 역매핑 JSON
  --recritic-diff PATH 재비판자에게 준 diff (선택 — added 의 file 도출에만)
  --emit-verdict       본 보고서 뒤에 `angles:`(있으면) · `verdict:` 꼬리를 싣는다
  --differential PATH  diff-test-results.py 의 집계 YAML
  --reason R           호출자만 아는 사유(반복 가능, verdict.REASONS 안)
  --angles PATH        각도 상태 파일(`<각도>: <상태>` 세 줄)

Output (stdout): Markdown matching agents/synthesizer.md schema.
"""
import argparse
import sys
import yaml
from collections import defaultdict

from adjudication import Ledger
from render_disposition import disposition_lines
import angles as _angles
import verdict as _verdict          # 새 책임은 새 모듈 — 여기는 진입점일 뿐이다
import recritic_bridge as _bridge   # 재비판 변환 계층 — 같은 프로세스·같은 원장(PR4a R-N)


SEV_ORDER = {"CRITICAL": 0, "IMPORTANT": 1, "SUGGESTION": 2}


def _read_source(path, ledger=None):
    """경로가 «주어진» YAML 을 읽는다. Returns `(data, dead)`.

    못 읽는 것은 전부 **주 입력 실패**다 — 파일 없음·권한(`OSError`), 비-UTF-8
    (`UnicodeDecodeError` 는 `ValueError` 의 하위라 `OSError` 절이 안 잡는다),
    YAML 파손(`yaml.YAMLError`). 예전에는 `FileNotFoundError` 만 잡아 나머지 셋이
    raw traceback + exit 1 로 0/2/4 계약을 탈출했다.
    """
    try:
        with open(path, encoding="utf-8") as f:
            return yaml.safe_load(f), False
    except (OSError, UnicodeDecodeError, yaml.YAMLError) as exc:
        why = type(exc).__name__
        if ledger is not None:
            ledger.source_failed(str(path), why, primary=True)
        print(f"[synthesize_findings] 입력을 읽지 못했다: {path} ({why}) "
              "— 이 축의 주 입력 실패다", file=sys.stderr)
        return None, True


def load_findings(path, ledger=None):
    """Return `(list, dropped, dead)` — `dead` 는 «경로를 줬는데» 못 읽었다는 뜻이다.

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
        return [], 0, False
    data, dead = _read_source(path, ledger)
    if dead:
        return [], 0, True
    # 빈 finding 파일은 「발견 0」이다 — 실패가 아니다. 판정자 문서와 다르다
    # (재비판자 응답은 비어 있으면 사망이다 — `recritic_bridge.to_adjudication_doc`
    # 참고): 탐지 리뷰어는 정당하게 아무것도 안 낼 수 있다.
    data = data or []
    if isinstance(data, dict) and "verdicts" in data:
        items, dropped = _as_list(data.get("verdicts"), "verdicts", ledger)
    elif isinstance(data, dict) and "findings" in data:
        items, dropped = _as_list(data.get("findings"), "findings", ledger)
    else:
        items, dropped = _as_list(data, "findings document", ledger)
    return items, dropped, False


def load_yaml(path, ledger=None):
    """`load_findings` 의 앞 둘 — `(list, dropped)`. 기존 호출자의 계약."""
    items, dropped, _dead = load_findings(path, ledger)
    return items, dropped


def _as_list(value, what, ledger=None):
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
    발화하지 못한다 — 버려진 CRITICAL이 **다시 clean으로 렌더된다**.
    """
    if isinstance(value, list):
        return value, 0
    if not value:                                # falsy는 정상적인 "없음"이다
        return [], 0
    # 매핑이면 항목 수가 곧 소실 건수다(`new_findings: {a: {...}, b: {...}}` = 2건).
    # 스칼라는 주장 하나로 센다 — 문자열의 len()은 글자 수라 의미가 없다.
    lost = len(value) if isinstance(value, dict) else 1
    if ledger is not None:
        # primary=False — 이 컨테이너가 죽어도 «축»은 살아 있다(주 findings
        # 경로는 따로 돈다). primary=True 로 하면 blocks() 가 켜져 오늘 통과하는
        # 실행이 차단된다: 공시와 차단은 다른 술어다.
        ledger.source_failed(
            what, "expected list, got %s — %d건" % (type(value).__name__, lost),
            primary=False)
    print(f"[synthesize_findings] {what} is {type(value).__name__}, "
          f"expected list — {lost}건 무시하고 계속한다"
          "(해당 입력은 심사되지 않았다)", file=sys.stderr)
    return [], lost


def extract_verdicts(doc, ledger=None):
    if isinstance(doc, dict):
        return _as_list(doc.get("verdicts"), "verdicts", ledger)
    return _as_list(doc, "판정자 문서", ledger)


def extract_new_findings(doc, ledger=None):
    if isinstance(doc, dict):
        return _as_list(doc.get("new_findings"), "new_findings", ledger)
    return [], 0


def _norm_file(f):
    """`file`을 해시 가능한 문자열로 확정한다.

    dedup()의 그룹핑 키가 `(file, line, severity)` 튜플이다 — `severity`만
    `_norm_sev`로 총함수화하고 나머지 둘을 raw로 남기면, `file: [a.py]`
    하나에 defaultdict 조회가 `TypeError: unhashable type: 'list'`를 던지고
    exit 1 + stdout 공백 — 다른 리뷰어의 진짜 CRITICAL까지 함께 소실된다.
    같은 튜플의 형제 원소를 놓쳐서는 안 된다.
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


def _normalize_identity(f, ledger=None):
    """수집 지점에서 스칼라 정체성 필드를 확정한다(소비 지점마다 가드 금지).

    `_conf`/`_norm_sev`가 값 수준에서, `_as_list`가 컨테이너 수준에서 하는 일을
    정체성 필드에 대해 한다. 소비 지점(dedup 키·sort tiebreak·finding_id·render)
    마다 가드를 덧대면 malformed가 한 겹씩 샌다 — `severity`만 막고 `file`/`line`을
    열어두는 식으로.
    """
    for key, fn in (("file", _norm_file), ("line", _norm_line)):
        raw = f.get(key)
        new = fn(f)
        if ledger is not None and raw != new:
            # gate=False — 이 강제는 게이트 판정을 바꾸지 않는다(정체성 필드의
            # 표기만 바꾼다). gate=True 는 `>=3` 같은 임계 비교를 무력화하는
            # 대체에만 쓴다(adjudication.py 의 coerced()).
            ledger.coerced(key, raw, new, gate=False)
        f[key] = new
    return f


def finding_id(f):
    return f"{f.get('agent', 'unknown')}-{f.get('file', '')}-{f.get('line', '')}"


NEW_FINDING_REQUIRED = ("file", "severity", "summary")
# 승격된 발견의 기본 confidence. suppress()의 바닥(<=4)보다는 위라 표에 실리고,
# render()의 caveat 임계(<=6) 아래라 `*`가 붙는다 — 이 발견은 어떤 리뷰어의
# 판정도 통과하지 않았다(판정자 자신의 주장이다). 보이되 검증 안 됨으로
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


def promote_new_findings(raw_new, existing, *, author, ledger=None):
    """판정자 문서의 `new_findings:` 항목을 진짜 finding으로 승격한다.

    Returns (promoted, dropped_malformed). `author` 는 판정자 문서를 «낸» 쪽이다 —
    기본값을 두지 않는다(판정자 자리가 바뀌면 기본값이 유령 저자가 된다).

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
    사라지고, 더 나쁘게는 살아남은 행의 `sources`에 판정자가 붙어 **하지 않은
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
            if ledger is not None:
                ledger.hold(repr(item)[:60], "항목 파손: not a mapping")
            print("[synthesize_findings] dropped malformed promoted finding: "
                  "not a mapping", file=sys.stderr)
            continue
        missing = [k for k in NEW_FINDING_REQUIRED if not item.get(k)]
        if missing:
            dropped += 1
            if ledger is not None:
                ledger.hold(repr(item.get("summary", item))[:60],
                            "항목 파손: missing %s" % ", ".join(missing))
            print("[synthesize_findings] dropped malformed promoted finding: "
                  f"missing {', '.join(missing)}", file=sys.stderr)
            continue
        f = dict(item)
        # `sources`는 리뷰어가 준 값을 절대 믿지 않는다. render()가 Source 컬럼에
        # 그대로 찍는 유일한 키인데, 승격 항목은 dedup()의 그룹핑을 건너뛰므로
        # (`promoted: True` → passthrough) 병합이 이 값을 덮어쓸 기회조차 없다.
        # 판정자 출력에 `sources: [security-reviewer, code-reviewer]`가 실리면
        # **아무 리뷰어도 하지 않은 주장이 교차 보증을 받은 것처럼 렌더된다**
        # (2026-08-05 재현). `agent`만 강제하고 이 채널을 열어두면 id 참칭은 막고
        # 표시 계층의 참칭은 그대로 남는다 — 후자가 사용자에게 더 직접적이다.
        f.pop("sources", None)
        f["agent"] = author
        f["promoted"] = True
        # 승격 경로도 같은 초크포인트를 쓴다 — `file: [a.py]`가 truthy라 필수-키
        # 검사를 통과한 뒤 sort_findings의 raw 비교에서 TypeError를 냈다.
        _normalize_identity(f, ledger=ledger)
        f.setdefault("confidence", NEW_FINDING_DEFAULT_CONFIDENCE)
        fid = finding_id(f)
        if fid in seen:
            base = fid
            suffix = 2
            while f"{base}-{suffix}" in seen:
                suffix += 1
            fid = f"{base}-{suffix}"
            print("[synthesize_findings] promoted finding id collision on "
                  f"{base}; disambiguated to {fid}", file=sys.stderr)
        seen.add(fid)
        f["finding_id"] = fid
        promoted.append(f)
    return promoted, dropped


def apply_verdicts(findings, verdicts, ledger=None, adjudicator_dead=False):
    """판정자 판정을 적용한다. Returns (out, dropped_malformed).

    - 매핑이 아닌 finding 은 버리되 **센다**(`dropped`) — 세지 않으면 버려진 CRITICAL 이
      clean 으로 렌더된다.
    - 판정 없는 finding 은 유지하고(다음 소비자가 사람이다) 원장에 `hold` 로 센다.
      판정자가 통째로 죽었으면(`adjudicator_dead`) 항목마다 세지 않는다 — 그 사망은
      원장에 이미 한 번 있고 `angle-absent` 로 나간다. 항목마다 세면 `findings-lost` 가
      사유 순서상 앞서 사유가 뒤바뀐다.
    - `raise` 는 severity 를 «올리기만» 한다(`_apply_raise`).
    """
    by_id = {v.get("finding_id"): v for v in verdicts if isinstance(v, dict)}
    out = []
    dropped = 0
    for f in findings:
        if not isinstance(f, dict):
            dropped += 1
            if ledger is not None:
                ledger.hold(repr(f)[:60], "항목 파손: not a mapping")
            print("[synthesize_findings] dropped malformed finding "
                  f"({type(f).__name__}, expected mapping): {str(f)[:80]!r}",
                  file=sys.stderr)
            continue
        # 수집 지점 정규화 — dedup 키 · sort · finding_id 가 모두 이 값을 만진다.
        f = _normalize_identity(dict(f), ledger=ledger)
        v = by_id.get(finding_id(f))
        if v is None:
            if ledger is not None and not adjudicator_dead:
                ledger.hold(finding_id(f), "판정자 부재: 판정자 판정 없음")
            out.append(f)
            continue
        verdict = v.get("verdict", "confirm")
        if verdict == "reject":
            if ledger is not None:
                ledger.reject(finding_id(f), "판정자 기각")
            continue
        if verdict == "raise" and "adjusted_severity" in v:
            f = _apply_raise(f, v["adjusted_severity"], ledger)
        if ledger is not None:
            ledger.accept(finding_id(f))
        out.append(f)
    return out, dropped


def _apply_raise(f, adjusted, ledger):
    """`raise` — 지금보다 «진짜로» 높을 때만 severity 를 바꾼다.

    판정자 쪽 매핑(`recritic-map.json`)이 낡아 이 finding 의 실제 severity 보다 낮은 값을
    가리키면, 그대로 적용하는 것은 CRITICAL 을 조용히 내리는 raise 다. 적용하지 않고
    원장에 강제로 남긴다 — 내렸을 것이면 판정을 바꾼 강제(`gate=True`), 같은 등급이면
    표기 강제(`gate=False`).
    """
    new_sev = _fold_sev(adjusted)
    cur_sev = _norm_sev(f)
    if isinstance(new_sev, str) and new_sev in SEV_ORDER:
        new_rank = SEV_ORDER[new_sev]
    else:
        new_rank = SEV_ORDER["SUGGESTION"]
    cur_rank = SEV_ORDER[cur_sev]
    if new_rank < cur_rank:
        f = dict(f)
        f["severity"] = new_sev
    elif ledger is not None:
        ledger.coerced("adjusted_severity", new_sev, cur_sev, gate=new_rank > cur_rank)
    return f


def dedup(findings, ledger=None):
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
        if ledger is not None:
            # 그룹의 첫 항목만 살아남는다. 나머지는 «소실이 아니라 귀속»이다 —
            # absorbed 는 degrade 가 아니다(adjudication.py 모듈 docstring).
            for g in group[1:]:
                ledger.absorbed(finding_id(g), finding_id(merged))
        deduped.append(merged)
    return deduped + passthrough


def suppress(findings, ledger=None):
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
            if ledger is not None:
                ledger.suppressed(finding_id(f),
                                  "non-CRITICAL conf=%d <= 4 (C30 rubric)" % conf)
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


def _fold_sev(value):
    """severity 값 하나의 표기를 접는다(앞뒤 공백 · 대소문자). 문자열이 아니면 그대로.

    `_norm_sev` 와 `raise` 가드가 **같은 접기**를 쓴다 — 둘이 갈리면 소문자 `critical`
    이 한쪽에서만 SUGGESTION 랭크로 떨어진다.
    """
    return value.strip().upper() if isinstance(value, str) else value


def _norm_sev(f):
    """finding 의 severity 를 아는 버킷으로. 모르는 값(목록 · 해시 불가 포함)은 SUGGESTION.

    dedup · suppress · sort · render 네 곳이 부른다 — 총(total)이어야 한다. 모르는 값을
    버킷에 못 넣으면 표에는 행이 서는데 counts 줄에서 빠져 kept=0(clean)으로 읽힌다.
    """
    folded = _fold_sev(f.get("severity", "SUGGESTION"))
    if isinstance(folded, str) and folded in SEV_ORDER:
        return folded
    print(
        f"[synthesize_findings] unknown severity {f.get('severity')!r}; treating as SUGGESTION",
        file=sys.stderr,
    )
    return "SUGGESTION"


# degrade 공시의 고정 마커. 소실(`dropped as malformed`)과 **다른 사건**이다:
# 저쪽은 개별 주장이 버려진 것이고, 이쪽은 판정 «경로» 자체가 온전하지 않았던 것
# (주 입력 사망·셀 수 없음·게이트를 바꾼 강제). 둘을 한 문구로 합치면 어느 쪽이
# 났는지 stdout 에서 구별할 수 없다.
DEGRADE_MARKER = "판정 degrade"

RECRITIC_ZERO_LINE = "탐지 0 · 재비판 0 — 재비판자가 돌았고 더한 finding 이 없다."


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


def render(kept, suppressed_count, dropped_malformed, report, held_classes,
           recritic_zero=False):
    findings = kept
    if not findings:
        # drop 공지는 이 분기에도 반드시 나가야 한다. 예전에는 아래 표-있는
        # 경로에만 있었고, 살아남은 발견이 0이면 여기서 먼저 return해 공지가
        # 도달 불가였다. 그 조합(전부 malformed → kept 0 → suppressed 0)에서
        # SKILL은 stdout만 읽어 counts=0을 보고 `## Review gate: clean`을
        # 찍었다 — 버려진 CRITICAL 주장이 **깨끗함으로 렌더**됐다는 뜻이다
        # (2026-08-04 재현, exit 0). 소실을 stdout에서 볼 수 있게 만든다.
        disp_line, plumb_line, gloss_line, advisories = disposition_lines(report, held_classes)
        for a in advisories:
            print(a, file=sys.stderr)
        out = [
            "## Review Findings (Synthesized)",
            "",
            f"No high-confidence findings. {suppressed_count} low-confidence "
            "findings suppressed.",
            disp_line, plumb_line, gloss_line,
        ]
        if recritic_zero:
            # AC17 — 침묵과 0 은 다른 사실이다. 재비판자가 «돌았고» 아무것도 더하지
            # 않았다는 것을 본 보고서가 말한다. 판정자가 죽은 실행에는 이 줄이 없다
            # (그 사실은 아래 degrade 블록이 말한다).
            out.append(RECRITIC_ZERO_LINE)
        if dropped_malformed > 0:
            out.append(
                f"{dropped_malformed} finding(s) dropped as "
                "malformed (not a mapping, wrong container type, or missing "
                "file/severity/summary) — see stderr. "
                "**이 실행은 clean이 아니다**: 버려진 주장은 심사되지 않았다."
            )
        out.extend(_degrade_block(report["degraded"], report["reasons"]))
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

    disp_line, plumb_line, gloss_line, advisories = disposition_lines(report, held_classes)
    for a in advisories:
        print(a, file=sys.stderr)

    out = ["## Review Findings (Synthesized)", "", counts_line,
           disp_line, plumb_line, gloss_line, ""]
    degrade_lines = _degrade_block(report["degraded"], report["reasons"])
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
    ap.add_argument("--findings", default="")
    # 판정 어휘는 `verdict.py` 가 갖는다. 여기서는 입력을 모아 넘기기만 한다.
    # 기본 off — 켜지 않으면 `verdict:`(와 `angles:`) 꼬리 없이 본 보고서만 나가고,
    # 그것은 성공한 켠 출력의 바이트 접두다(계획 R-J). 소비자 이주는 PR4.
    ap.add_argument("--emit-verdict", action="store_true")
    # 기본값을 `""` 로 두면 "플래그를 안 줬다" 와 "빈 경로를 줬다" 가 같은 값이
    # 된다 — 값을 못 구한 호출자가 `--differential "$DIFF_YAML"` 을 빈 변수로
    # 호출하면 차등 축이 조용히 사라지고 `clean` 으로 인증된다(`verdict.py` 의
    # `read_or_none()` docstring 이 금지한 바로 그 새는 경로 — Ruling T5-a. 한 층
    # 아래가 막은 결함을 이 층에서 되살리지 않는다). 기본값을 `None`
    # 으로 둬 두 경우를 구별하고, 명시적으로 빈 문자열을 주면 usage 오류(exit 2)다.
    ap.add_argument("--differential", default=None)
    ap.add_argument("--reason", action="append", default=[])
    # 각도 상태 — 기본 off. 오케스트레이터 배선은 PR4 다(계획 R-E). 안 주면
    # `angles:` 블록을 싣지 않는다. 다만 주 판정자 사망은 `--angles` 유무와
    # 무관하게 `--emit-verdict` 아래서 `angle-absent` 로 보고된다.
    ap.add_argument("--angles", default=None)
    # 재비판 경로(PR4a R-N) — 판정자는 한 실행에 하나다.
    ap.add_argument("--recritic", default=None)
    ap.add_argument("--recritic-map", default=None)
    ap.add_argument("--recritic-diff", default=None)
    args = ap.parse_args()

    if args.differential is not None and args.differential == "":
        print("synthesize_findings.py: --differential 은 빈 문자열을 받지 않는다 "
              "(플래그를 생략하거나 실제 경로를 줘라)", file=sys.stderr)
        sys.exit(2)
    if args.angles is not None and args.angles == "":
        print("synthesize_findings.py: --angles 는 빈 문자열을 받지 않는다 "
              "(플래그를 생략하거나 실제 경로를 줘라)", file=sys.stderr)
        sys.exit(2)

    for flag, val in (("--recritic", args.recritic), ("--recritic-map", args.recritic_map),
                      ("--recritic-diff", args.recritic_diff)):
        if val is not None and val == "":
            print(f"synthesize_findings.py: {flag} 는 빈 문자열을 받지 않는다", file=sys.stderr)
            sys.exit(2)
    if (args.recritic is None) != (args.recritic_map is None):
        print("synthesize_findings.py: --recritic 과 --recritic-map 은 함께 준다",
              file=sys.stderr)
        sys.exit(2)
    if args.recritic_diff is not None and args.recritic is None:
        print("synthesize_findings.py: --recritic-diff 는 --recritic 없이 의미가 없다",
              file=sys.stderr)
        sys.exit(2)

    # 판정 입력 플래그는 `--emit-verdict` 없이는 의미가 없다 — 조용히 버리면 판정축이
    # 빠진 실행이 완전해 보이는 보고서 + rc 0 을 낸다. exit 2(잘못된 호출)로 막는다.
    if not args.emit_verdict:
        if args.differential is not None:
            print("synthesize_findings.py: --differential 은 --emit-verdict "
                  "없이는 의미가 없다 (함께 주거나 --differential 을 빼라)",
                  file=sys.stderr)
            sys.exit(2)
        if args.reason:
            print("synthesize_findings.py: --reason 은 --emit-verdict 없이는 "
                  "의미가 없다 (함께 주거나 --reason 을 빼라)",
                  file=sys.stderr)
            sys.exit(2)
        if args.angles is not None:
            print("synthesize_findings.py: --angles 는 --emit-verdict "
                  "없이는 의미가 없다 (함께 주거나 --angles 를 빼라)",
                  file=sys.stderr)
            sys.exit(2)

    ledger = Ledger(items="open")

    if args.recritic is not None:
        doc, adjudicator_dead = _bridge.load_recritic(
            args.recritic, args.recritic_map, args.recritic_diff, ledger)
    else:
        doc, adjudicator_dead = None, False
    verdicts, dropped_verdicts = extract_verdicts(doc, ledger=ledger)
    raw, dropped_raw, findings_dead = load_findings(args.findings, ledger=ledger)

    findings, dropped_primary = apply_verdicts(raw, verdicts, ledger=ledger,
                                               adjudicator_dead=adjudicator_dead)
    new_raw, dropped_newlist = extract_new_findings(doc, ledger=ledger)
    promoted, dropped_promoted = promote_new_findings(new_raw, findings,
                                                      author=_bridge.ADJUDICATOR, ledger=ledger)
    # 모든 출처의 소실을 **한 채널로** 합친다. 하나라도 빠지면 stdout 공지가
    # 반쪽이 되고, 반쪽짜리 공지는 "이 실행은 clean이 아니다"를 말할 자격이 없다.
    # 컨테이너 수준(dropped_raw / dropped_verdicts / dropped_newlist)과 항목
    # 수준(dropped_primary / dropped_promoted)이 **둘 다** 여기 들어와야 한다 —
    # 항목 수준만 세면 컨테이너 소실이 0으로 보고된다.
    dropped_malformed = (dropped_raw + dropped_verdicts + dropped_newlist
                         + dropped_primary + dropped_promoted)
    findings = findings + promoted          # 기존 뒤에 append — 기존 표 순서를 흔들지 않는다
    findings = dedup(findings, ledger=ledger)
    kept, suppressed = suppress(findings, ledger=ledger)
    kept = sort_findings(kept)

    # 판정 «계산» 은 본 보고서를 쓰기 «전» 에 한다 — fail4 가 터지면 stdout 이 비어 있어야
    # 한다(원자적 실패 계약).
    decision = None
    angle_states = None
    if args.emit_verdict:
        # `report["degraded"]`(공시)가 아니라 차단 쪽 술어다 — 헌장은 모델 다양성
        # 손실 같은 degrade 를 공시만 하고 막지 않는다. 여기서 둘을 섞으면 이
        # 합성기가 조용히 게이트를 넓힌다.
        #
        # 차단 셋을 **두 사유로** 가른다(설계 §6.4.3): 항목 소실·미상은
        # `findings-lost`, 주 판정자 사망은 `angle-absent` — 아무도 그 축을 «안 본»
        # 것이라 각도가 `absent` 인 것과 같은 사실이다(§6.3.5 의 표).
        angle_absent = ledger.primary_source_failed()
        if args.angles is not None:
            declared = _angles.parse(_angles.read_or_fail4(args.angles))
            # AC10a — 수행자 집합은 이 실행이 실제로 «낸» finding 에서 도출한다
            # (계획 R-H). 각도 파일 자신에서 뽑으면 자기-일관성 검사이지 Law 2
            # 검사가 아니다. 판정 적용 «전» 의 입력(`raw`)과 dedup 뒤의 `findings`
            # (승격분 포함)를 함께 본다: 기각·억제된 것도 「낸 것」이다(냈기
            # 때문에 기각·억제된 것이다).
            #
            # 항목마다 `agent` 는 **항상** 센다. `sources` 는 거기에 «더할» 뿐
            # `agent` 를 대신하지 않는다 — `raw` 의 `sources` 는 리뷰어가 준
            # 비신뢰 값이라, 그것이 `agent` 를 가리면 저자가 이름을 달리 적는
            # 것만으로 AC10a 가 조용해진다. dedup 뒤 항목의 `sources` 는 dedup 이
            # `agent` 들로 만든 목록이다. 더 세는 쪽은 AC10a 를 엄격하게 할
            # 뿐이다(fail-closed).
            # 이중 계수 — 한 finding 이 raw(판정 전)와 findings(판정 뒤) 둘 다에
            # 있으면 missing_agent 가 두 번 센다. 검사는 > 0 만 보므로 판정에는
            # 영향이 없다 — 메시지의 건수는 「관측한 항목 수」로 읽힌다.
            authors = set()
            missing_agent = 0
            for f in findings + raw:
                if isinstance(f, dict):
                    # `agent: null` 은 agent 없음과 같은 사건이다(YAML 의 null · ~ · 빈 값).
                    a = f.get("agent")
                    if a is None or str(a) in ("", "?"):
                        missing_agent += 1
                    else:
                        authors.add(str(a))
                    srcs = f.get("sources") or []
                    if not isinstance(srcs, (list, tuple)):
                        srcs = [srcs]
                    for s in srcs:
                        # dedup() 이 `agent: null` 에서 파생시킨 None 만 건너뛴다 — 리뷰어가
                        # 적은 `sources: [null]` 은 문법 밖 저자로 흘려 검사한다(비신뢰 필드).
                        if not (s is None and a is None):
                            s = str(s)
                            if s and s != "?":
                                authors.add(s)
            # 부채 B — 저자 쪽 신원 계약. AC10a 비교 «전»에 둔다: 문법 밖 이름이
            # 섞인 집합으로 비교하면 그 비교 자체가 무의미하다.
            _angles.check_author_identity(authors, missing_agent)
            _angles.check_self_adjudication(declared, authors)
            # 계획 R-L — 관측된 주 입력 사망을 선언 위에 얹는다. AC10a 는 «선언»에
            # 걸었다(선언 자체가 Law 2 를 어기면 판정자 생사와 무관하게 거부).
            # 차단과 렌더는 «실효»에 건다 — 꼬리가 자기모순이 되지 않게.
            dead_angles = []
            if findings_dead:
                dead_angles.append("security")
            if adjudicator_dead:
                dead_angles.append("adjudication")
            angle_states = _angles.with_dead_sources(declared, dead_angles)
            angle_absent = angle_absent or _angles.blocks(angle_states)
        decision = _verdict.decide(
            defect=bool(kept),                    # 계획 R-B — severity 를 묻지 않는다
            review_blocked=ledger.items_unaccounted(),
            angle_absent=angle_absent,
            differential_text=_verdict.read_or_none(args.differential),
            extra_reasons=args.reason,
        )

    # 원장은 «회계»만 한다 — 읽어서 stdout 에 싣는 것은 이 소비자의 책임이다.
    # `held` 만 꺼내고 `degraded`/`reasons` 를 안 실으면, 주 입력이 통째로 죽어도
    # 출력이 clean 과 **바이트 동일**이 된다.
    report = ledger.report()
    # 「재비판 0」은 변환 «전» 원문 길이가 둘 다 0 일 때만 참이다(파손된 원문이 0 으로 접히지 않게).
    raw_verdict_count = doc.get("_raw_verdict_count", 0) if isinstance(doc, dict) else 0
    raw_added_count = doc.get("_raw_added_count", 0) if isinstance(doc, dict) else 0
    recritic_zero = (args.recritic is not None and not adjudicator_dead
                     and not raw and dropped_raw == 0
                     and not verdicts and not new_raw
                     and raw_verdict_count == 0 and raw_added_count == 0)
    sys.stdout.write(render(kept, len(suppressed), dropped_malformed,
                            report, ledger.held_by_class(), recritic_zero=recritic_zero))

    if args.emit_verdict:
        # `render()` 가 낸 Markdown 본문 **뒤**의 평문 꼬리다 — PR2 가 `verdict:`
        # 를 같은 자리에 같은 모양으로 붙였고(계획 R-J), 그래야 「off 출력은 on
        # 출력의 바이트 접두」가 유지된다. 각도가 판정보다 **앞**인 것은 읽는
        # 순서다: 무엇을 봤는지가 그 판정의 근거다.
        if angle_states is not None:
            sys.stdout.write(_angles.render(angle_states))
        sys.stdout.write(_verdict.render(decision))


if __name__ == "__main__":
    main()
