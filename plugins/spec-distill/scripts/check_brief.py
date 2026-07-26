#!/usr/bin/env python3
"""spec-distill — interview brief structural gate.

집행하는 AC (2026-07-25-spec-distill-brief-format-producer-design.md §6):
AC4/AC5/AC6/AC7/AC9/AC10/AC11/AC12/AC15. 이 파일의 AC 번호는 **그 spec의 §6 표**를
가리킨다 — 옛 spec의 번호를 물려 쓰면 같은 숫자가 다른 뜻을 가리켜 traceability가 거짓이
된다(design doc Rejected Alternatives의 "AC↔T/V 편도 참조" 클래스). 이 spec에 대응 AC가
없는 검사(§4 인용 요구, `type`/`next_phase` 규약 등)는 AC 번호를 붙이지 않는다.

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
genuine counter-argument is not machine-checked at all (모델 + 독립 adversary의 몫).

CLI subcommands (all print JSON):
  check_brief.py sections <payload>            → {"missing": [...]}        (AC4)
  check_brief.py landscape-citations <payload> → {"uncited": [...]}        (§4 인용 요구)
  check_brief.py skepticism <payload>          → {"malformed": [...]}      (AC11)
  check_brief.py tried-discarded <payload>     → {"ok": bool}              (AC11, R4 이관)
  check_brief.py coverage <payload>            → {"failures": [...]}       (AC10, audit §1 해석)
  check_brief.py frontmatter <payload>         → {"errors": [...]}         (AC6/AC9 키 존재)
  check_brief.py items <payload>               → {"errors": [...], "bijection_c": [...],
                                                    "bijection_b": [...]}  (AC6/AC7)
  check_brief.py metrics <payload>              → {"payload_body_lines_excl_verbatim": int}
                                                    (AC15, advisory)
  check_brief.py gate <payload>                → {"pass": bool, "failures": [...],
                                                    "payload_body_lines_excl_verbatim": int,
                                                    "advisories": [...]}
                                                 exit 0 if pass else 1 (advisories never flip this)
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path


def _web_disabled() -> bool:
    """Graceful degradation (선재 동작 — 이 spec에 대응 AC 없음, T17이 검증): when web
    research is killed, URLs cannot be obtained, so the gate relaxes the citation
    requirement on §3/§4 (the SKILL's R2/R3 web-absent clauses). The judgment of
    whether the (URL-less) skepticism is genuine stays manual."""
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


LINE_TRIPWIRE = 150  # §5.3 절별 예산 합계 137 + slack 13. 목표이지 정확성 조건이 아니다.


def payload_body_lines_excl_verbatim(text: str) -> int:
    """분량 지표 (AC15, advisory).

    계수법: frontmatter 제외, `## 6.` 섹션 전체 제외, 빈 줄 제외, 나머지 줄 수.
    원문(§6)은 분량 무제한이므로 총량에서 빼야 인터뷰 길이가 지표를 오염시키지 않는다.
    """
    body = _body(text)
    m = re.search(r"^##\s+6\.\s+", body, re.MULTILINE)
    if m:
        rest = body[m.end():]
        nxt = re.search(r"^##\s+\d+\.", rest, re.MULTILINE)
        body = body[: m.start()] + (rest[nxt.start():] if nxt else "")
    return len([ln for ln in body.splitlines() if ln.strip()])


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


# 불릿 문자는 `-`와 `*`를 **둘 다** 받는다 — §2 본문을 읽는 `BODY_ITEM_RE`(`^\s*[-*]\s+`)와 반드시
# 같은 관례여야 한다. 같은 아티팩트를 두 규칙이 서로 다른 관례로 읽으면 불릿 한 글자로 검사를
# 우회할 수 있다: `- 인용된 항목` 하나와 `* 출처 없는 주장` 하나를 §4에 두면 `landscape_present`는
# 하이픈 항목으로 만족되고 `landscape_uncited`는 애스터리스크 항목을 아예 못 봐서, R2의 "출처 URL
# 필수"가 통째로 통과한다(리뷰 실증: 같은 줄을 `-`로 쓰면 red, `*`로 쓰면 green).
ENTRY_BULLET_RE = re.compile(r"^\s*[-*]\s")


def _entry_lines(section: str) -> list[str]:
    return [
        ln.strip()
        for ln in section.splitlines()
        if ENTRY_BULLET_RE.match(ln) and ln.strip() not in ("-", "*")
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


SESSION_ID_RE = re.compile(r"^session_id:\s*([^\s#]+)", re.MULTILINE)
TYPE_RE = re.compile(r"^type:\s*([^\s#]+)", re.MULTILINE)


def audit_pairing_errors(payload_fm: str, audit_text: str) -> list[str]:
    """audit이 *이 payload의* sidecar인지 확인한다 (fail-closed).

    `resolve_audit`은 basename이 같은 디렉토리에 존재하기만 하면 받아들이므로, payload가
    **다른 인터뷰의 audit**을 가리켜도 통과했다. audit §1 Coverage Ledger는 Law 1 종료 판정
    (floor 5 전부 closed)의 근거이므로, 끝나지 않은 인터뷰가 남의 원장을 상속해 green이 된다 —
    리뷰가 실행으로 실증했다: 같은 payload가 `audit_file: mine.audit.md`(floor 5 전부 open)에는
    exit 1, `audit_file: <남의 것>`(전부 closed)에는 exit 0. 한 줄 편집이 실패를 통과로 바꿨다.
    `bijection_a_errors`는 백스톱이 못 된다 — `ST<N>`은 인터뷰마다 1부터 매겨져 steelman 1건짜리
    인터뷰 둘은 양쪽 다 `ST1`이라 불일치가 발생하지 않는다.

    결합은 **파일명이 아니라 `session_id`**로 건다. 파일명 결합(`<payload stem>.audit.md` 강제)은
    payload 하나당 audit 하나를 요구해 fixture 코퍼스(payload 39개가 audit 1개를 공유)를 전부
    다시 쓰게 만들지만, `session_id`는 두 템플릿과 모든 fixture가 이미 담고 있어 churn이 0이다.
    SKILL이 payload에 기존 spec-distill 세션 id를 재사용하도록 이미 규정한다.

    부재는 불일치와 똑같이 red다 — 못 읽은 값을 "일치로 간주"하면 이 검사 자체가 fail-open이 되고,
    그건 이 함수가 막으려는 바로 그 실패 모드다.
    """
    errs: list[str] = []
    afm = _frontmatter(audit_text)
    atype = TYPE_RE.search(afm)
    if not atype:
        errs.append("audit frontmatter에 type 없음")
    elif atype.group(1) != "interview-audit":
        errs.append(f"audit type {atype.group(1)!r} != 'interview-audit'")
    psid = SESSION_ID_RE.search(payload_fm)
    asid = SESSION_ID_RE.search(afm)
    if not psid:
        errs.append("payload frontmatter에 session_id 없음")
    if not asid:
        errs.append("audit frontmatter에 session_id 없음")
    if psid and asid and psid.group(1) != asid.group(1):
        errs.append(
            f"audit session_id {asid.group(1)!r} != payload {psid.group(1)!r} "
            "(다른 인터뷰의 audit — Coverage Ledger 차용)"
        )
    return errs


VALID_SOURCES = ("verbatim", "chosen")
VALID_STATUSES = ("confirmed", "provisional", "open")
REQUIRED_ITEM_FIELDS = ("id", "source", "status", "statement", "evidence")
STATEMENT_MAX = 160
# AC12 sentinel — 축자 형태는 `# confirmed 0건 — 사용자가 전부 잠정으로 판단` 한 줄이다.
# **substring 검사를 쓰면 안 된다**: 템플릿이 이 문자열을 *사용법 안내 주석 안에* 그대로
# 인쇄하므로(`#   # confirmed 0건 — …`), 템플릿을 복사해 만든 brief는 sentinel을 실제로
# 선언하지 않고도 AC12를 만족시켜 확인 게이트 우회 검출이 통째로 fail-open된다(리뷰 실증).
# 그래서 **한 줄 전체**가 sentinel이어야 한다 — 줄 시작(들여쓰기 허용) + `#` + 문구 + 줄 끝.
# 이 앵커링은 인용값(`statement: "... # confirmed 0건 — …"`) 안에 숨은 문자열도 함께 거절한다.
CONFIRMED_SENTINEL_RE = re.compile(
    r"^[ \t]*#[ \t]*confirmed 0건 — 사용자가 전부 잠정으로 판단[ \t]*$", re.MULTILINE
)

ITEMS_KEY_RE = re.compile(r"^user_sourced_items\s*:", re.MULTILINE)
ITEM_START_RE = re.compile(r"^\s*-\s+id:\s*(\S+)\s*$")
ITEM_FIELD_RE = re.compile(r"^\s+(\w+):\s*(.*?)\s*$")
ITEM_BULLET_RE = re.compile(r"^\s*-\s")
ITEM_COMMENT_RE = re.compile(r"^\s*#")
EVIDENCE_RE = re.compile(r"^S\d+$")
# YAML 인라인 주석 시작: 공백 뒤의 `#`(또는 값 맨 앞의 `#`). `audit_file`이 쓰는
# `[^\s#]+` 컷과 달리 값에 공백이 있어도 안전해야 한다 — `statement`는 문장이다.
INLINE_COMMENT_RE = re.compile(r"(?:^|\s)#")


def _strip_inline_comment(v: str) -> str:
    """필드 값에서 YAML 인라인 주석을 제거한다.

    `audit_file`은 이미 `[^\\s#]`로 값을 끊는데(AUDIT_FILE_RE) 항목 필드는 끊지 않아,
    **같은 템플릿의 같은 frontmatter 블록**을 두 규칙이 반대로 읽는 상태였다 — 템플릿이
    상속시킨 `source: verbatim          # verbatim(…) | chosen(…)` 한 줄이 "source 값이
    allowlist 밖" + bijection B 4건이라는, 원인(값 뒤 주석)과 무관해 보이는 오류 벽을
    만든다(리뷰 실증). 원인과 증상이 어긋나면 디버깅 비용이 배로 든다.

    따옴표 스칼라 안의 `#`는 주석이 아니므로 보존한다 — 그러지 않으면 `#`를 담은 정상
    statement가 조용히 잘려 bijection B가 엉뚱한 drift를 보고한다.
    """
    if v[:1] in ('"', "'"):
        end = v.find(v[0], 1)
        if end != -1:
            return v[: end + 1]
        return v  # 닫히지 않은 따옴표 → 원문 유지(값을 임의로 자르지 않는다)
    m = INLINE_COMMENT_RE.search(v)
    return v[: m.start()] if m else v


def parse_user_sourced_items(fm: str):
    """frontmatter의 user_sourced_items 블록을 손으로 파싱한다.

    PyYAML을 쓰지 않는 이유: 이 플러그인의 어떤 스크립트도 third-party import를 하지
    않는다 — 훅은 임의 사용자 환경에서 실행되고, 게이트가 ImportError로 죽으면 Law 1
    구조 게이트가 통째로 fail-open된다.

    반환: (items, raw_bullets). raw_bullets는 블록 안 `- ` 줄 수로, items와 개수가
    다르면 파서-포맷 불일치이므로 호출자가 fail-closed로 처리한다(인라인 dict 형식 등).
    """
    lines = fm.splitlines()
    start = None
    for i, ln in enumerate(lines):
        if ITEMS_KEY_RE.match(ln):
            start = i
            break
    if start is None:
        return [], 0
    items = []
    raw = 0
    cur = None
    for ln in lines[start + 1:]:
        # 주석 줄은 데이터가 아니므로 건너뛴다 — 들여쓰지 않은 `#` 한 줄이 "다음 최상위 키"로
        # 오인돼 블록을 끊으면 **항목 전체가 사라지고** 게이트는 "C1: in body §2 but not in
        # frontmatter"라는 엉뚱한 말을 한다(리뷰 실증). 템플릿이 AC12 sentinel을 "이 블록 안에"
        # 쓰라고 지시하므로 그 지시를 따른 brief가 정확히 이 함정을 밟는다. 주석은 값을 나르지
        # 않으므로 이 관용이 결함 brief를 통과시킬 수는 없다(fail-closed 중립).
        if ITEM_COMMENT_RE.match(ln):
            continue
        if ln.strip() and not ln[0].isspace():
            break  # 다음 최상위 키 → 블록 종료
        if ITEM_BULLET_RE.match(ln):
            raw += 1
        m = ITEM_START_RE.match(ln)
        if m:
            cur = {"id": m.group(1).strip().strip('"').strip("'")}
            items.append(cur)
            continue
        if cur is None:
            continue
        f = ITEM_FIELD_RE.match(ln)
        if f:
            val = _strip_inline_comment(f.group(2)).strip()
            cur[f.group(1)] = val.strip('"').strip("'")
    return items, raw


def user_sourced_errors(text: str) -> list[str]:
    """user_sourced_items 스키마 검증 (AC6)."""
    fm = _frontmatter(text)
    if not ITEMS_KEY_RE.search(fm):
        return ["user_sourced_items key absent"]
    items, raw = parse_user_sourced_items(fm)
    errs: list[str] = []
    if raw != len(items):
        errs.append(f"user_sourced_items unparseable ({raw} bullets, {len(items)} parsed)")
    seen = set()
    for it in items:
        iid = it.get("id") or "<no-id>"
        if iid in seen:
            errs.append(f"{iid}: duplicate id")
        seen.add(iid)
        for field in REQUIRED_ITEM_FIELDS:
            if not it.get(field):
                errs.append(f"{iid}: {field} missing")
        src = it.get("source")
        if src and src not in VALID_SOURCES:
            # `inferred`는 이 리스트에 들어올 수 없다 — 모델 추론은 본문 ✎ 프로즈로만 산다.
            errs.append(f"{iid}: source {src!r} not in {VALID_SOURCES}")
        st = it.get("status")
        if st and st not in VALID_STATUSES:
            errs.append(f"{iid}: status {st!r} not in {VALID_STATUSES}")
        stmt = it.get("statement") or ""
        if len(stmt) > STATEMENT_MAX:
            errs.append(f"{iid}: statement {len(stmt)}자 > {STATEMENT_MAX} (hard cap)")
        ev = it.get("evidence") or ""
        if ev and not EVIDENCE_RE.match(ev):
            errs.append(f"{iid}: evidence {ev!r} is not S<N>")
    return errs


def confirmed_zero_unsentineled(text: str) -> bool:
    """빈 확정 금지 (AC12) — sentinel 없는 confirmed 0건은 확인 게이트를 건너뛴 신호다."""
    fm = _frontmatter(text)
    items, _ = parse_user_sourced_items(fm)
    if any(it.get("status") == "confirmed" for it in items):
        return False
    return not CONFIRMED_SENTINEL_RE.search(fm)


S_ANCHOR_RE = re.compile(r"^\s*-\s+\*\*(S\d+)\*\*", re.MULTILINE)


def verbatim_anchors(text: str) -> set:
    """§6 사용자 원문이 제공하는 S<N> 앵커 집합."""
    return set(S_ANCHOR_RE.findall(_section_text(text, "6", "사용자 원문")))


def bijection_c_errors(text: str) -> list[str]:
    """bijection C — 모든 evidence: S<N>이 §6에서 해석된다 (AC6).

    한계: 이 검사는 인용된 S<N>의 **존재**만 본다. 요약이 그 원문을 실제로 뒷받침하는지
    (의미적 정합)는 기계 검증하지 않는다 — V9 수동 spot-check가 그 갭을 맡는다.
    역방향(모든 S<N>이 인용될 것)은 요구하지 않는다: 제약으로 승격되지 않은 발화가 있다.
    """
    anchors = verbatim_anchors(text)
    items, _ = parse_user_sourced_items(_frontmatter(text))
    errs = []
    for it in items:
        ev = it.get("evidence")
        if ev and EVIDENCE_RE.match(ev) and ev not in anchors:
            errs.append(f"{it.get('id')}: evidence {ev} not found in §6")
    return errs


MARKER_SOURCE = {"🗣": "verbatim", "☑": "chosen"}

# `- 🗣 confirmed **C1** — <statement> ⟨S3⟩`
# 마커 뒤 U+FE0F(VS16, variation selector-16) 선택적 허용 — 대부분의 이모지 입력
# 경로가 내보내는 형태(예: 겉보기로 구별 안 되는 두 글자짜리 마커)를 거부하면 "D2:
# in frontmatter but not in body §2"처럼 원인과 무관해 보이는 오탐이 뜬다. 소스에
# 보이지 않는 문자를 직접 심지 않도록 정규식 이스케이프(re가 코드포인트로 해석)로
# 표기해 향후 편집 시 실수로 지워질 위험을 없앤다. 캡처 그룹은 맨 글리프만 잡아
# MARKER_SOURCE 조회가 그대로 동작한다. 불릿도 `-`/`*` 둘 다 허용(`[-*]`).
BODY_ITEM_RE = re.compile(
    r"^\s*[-*]\s+(🗣|☑)\uFE0F?\s+(\S+)\s+\*\*([^*]+)\*\*\s+—\s+(.*?)\s+⟨(S\d+)⟩\s*$"
)
# 기호로 시작하지만 위 문법에 맞지 않는 줄을 잡아내기 위한 느슨한 매처.
# 이게 없으면 오타 한 글자가 항목을 id 집합에서 조용히 지워 "frontmatter-only id"라는
# 엉뚱한 메시지로 나타난다 — 원인과 증상이 어긋나면 디버깅이 배로 든다.
BODY_ITEM_LOOSE_RE = re.compile(r"^\s*[-*]\s+(?:🗣|☑)\uFE0F?\s")
EMPH_RE = re.compile(r"[*`]")


def _norm_stmt(s: str) -> str:
    """정규화 = 앞뒤 공백 제거 + 연속 공백 1개로 축약 + 마크다운 강조 기호 제거."""
    return re.sub(r"\s+", " ", EMPH_RE.sub("", s)).strip()


def bijection_b_errors(text: str) -> list[str]:
    """bijection B — body §2 ↔ frontmatter (AC7).

    frontmatter가 canonical이고 body는 그 렌더다. id·기호·status·evidence만 맞추면
    두 표현이 같은 라벨을 달고 **서로 다른 제약을 말해도** 통과하므로 statement 내용까지
    정규화 후 대조한다. ✎ 항목은 이 문법을 쓰지 않으므로(프로즈 주석) 대상이 아니다.
    """
    items = {}
    for it in parse_user_sourced_items(_frontmatter(text))[0]:
        if it.get("id"):
            items[it["id"]] = it
    errs: list[str] = []
    body = {}
    for ln in _section_text(text, "2", "제약").splitlines():
        if not BODY_ITEM_LOOSE_RE.match(ln):
            continue
        m = BODY_ITEM_RE.match(ln)
        if not m:
            errs.append(f"malformed §2 item: {ln.strip()[:60]}")
            continue
        marker, status, iid, stmt, ev = m.groups()
        if iid in body:
            errs.append(f"{iid}: duplicate §2 item")
        body[iid] = {"marker": marker, "status": status, "statement": stmt, "evidence": ev}
    for iid in sorted(set(body) - set(items)):
        errs.append(f"{iid}: in body §2 but not in frontmatter")
    for iid in sorted(set(items) - set(body)):
        errs.append(f"{iid}: in frontmatter but not in body §2")
    for iid in sorted(set(body) & set(items)):
        b, f = body[iid], items[iid]
        if MARKER_SOURCE.get(b["marker"]) != f.get("source"):
            errs.append(f"{iid}: body marker {b['marker']} != frontmatter source {f.get('source')!r}")
        if b["status"] != f.get("status"):
            errs.append(f"{iid}: body status {b['status']!r} != frontmatter {f.get('status')!r}")
        if b["evidence"] != f.get("evidence"):
            errs.append(f"{iid}: body ⟨{b['evidence']}⟩ != frontmatter evidence {f.get('evidence')!r}")
        if _norm_stmt(b["statement"]) != _norm_stmt(f.get("statement") or ""):
            errs.append(f"{iid}: body statement != frontmatter statement (정규화 후)")
    return errs


def landscape_uncited(text: str) -> list[str]:
    if _web_disabled():
        return []  # web off → no URLs obtainable; citation requirement relaxed
    sec = _section_text(text, "4", "External Landscape")
    return [ln for ln in _entry_lines(sec) if not URL_RE.search(ln)]


def landscape_present(text: str) -> bool:
    """§4 External Landscape must carry >=1 entry, OR an explicit web-disabled
    sentinel (graceful degradation). Header presence alone is not research (F3)."""
    sec = _section_text(text, "4", "External Landscape").strip()
    if not sec:
        return False
    if re.search(r"\bN/?A\b|비활성|생략|web[ -]?disabled", sec, re.IGNORECASE):
        return True
    return bool(_entry_lines(sec))


def section5_entries(text: str) -> list[str]:
    return _entry_lines(_section_text(text, "5", "기각 · Blind Spots"))


ST_HEADING_RE = re.compile(r"^####\s+(ST\d+)\b", re.MULTILINE)
ST_REF_RE = re.compile(r"\b(ST\d+)\b")
ATTRIBUTION_MARKERS = ("🗣", "☑", "✎")
# skepticism_malformed의 statement<10c 측정에서 "verdict: defended" 같은 판정 어구 자체를
# 제외한다 — 이 어구(>=17자)를 남겨두면 PN4가 약속하는 ">=10자 statement" 검사가 항상
# has_verdict=True와 동시에 통과해버려 구조적으로 도달 불가능해진다(deadcode). Task 4에서
# ST 참조 요구를 추가하며 발견 — brief Step 3 원문 그대로는 이 분기가 절대 발화하지 않는다.
VERDICT_CLAUSE_RE = re.compile(r"verdict:\s*\S+", re.IGNORECASE)


def verdict_entries(entries: list[str]) -> list[str]:
    return [ln for ln in entries if "verdict:" in ln]


def bijection_a_errors(payload_text: str, audit_text: str) -> list[str]:
    """bijection A — payload §5 ↔ audit §3 (AC11).

    개수 비교가 아니라 **id 집합 비교**다. 실제 steelman 항목은 다단락 블록이지 단일
    불릿이 아니어서 "무엇을 한 항목으로 셀 것인가"가 미정이고, 그러면 집행이 불가능하다.
    양쪽 공집합(steelman 0건)은 그대로 허용한다 — 공집합 == 공집합은 정합이고 steelman은
    조건부 발동이라 0건이 정상이다. sentinel이 필요한 것은 R4(`기각` 0건)뿐이다.
    """
    refs = set()
    for ln in verdict_entries(section5_entries(payload_text)):
        # URL을 먼저 벗겨낸다 — 그러지 않으면 URL 경로 조각에 우연히 낀 word-bounded
        # ST<N> 토큰(예: `/ST9/`)이 실제 참조인 양 집합에 섞여든다(phantom ref).
        refs |= set(ST_REF_RE.findall(URL_RE.sub("", ln)))
    declared = set(ST_HEADING_RE.findall(_section_text(audit_text, "3", "Steelman 원문")))
    errs = []
    for st in sorted(refs - declared):
        errs.append(f"{st}: payload §5가 참조하지만 audit §3에 없음 (원문 없는 판정)")
    for st in sorted(declared - refs):
        errs.append(f"{st}: audit §3에 있지만 payload §5가 참조하지 않음 (판정 없는 steelman)")
    return errs


def attribution_block_missing(text: str) -> bool:
    """§6 상단 2줄 출처 표기 블록 존재 검사 (AC5/C3).

    템플릿이 상속시키지만 개별 brief에서 지워질 수 있으므로 게이트가 확인한다.
    """
    for ln in _section_text(text, "6", "사용자 원문").splitlines():
        if ln.lstrip().startswith(">") and all(m in ln for m in ATTRIBUTION_MARKERS):
            return False
    return True


def skepticism_malformed(text: str) -> list[str]:
    """§5의 `verdict:` 항목 형식 검사. PN4: 정확한 문자열 일치가 아니라 containment."""
    require_url = not _web_disabled()
    bad: list[str] = []
    for ln in section5_entries(text):
        if "verdict:" not in ln:
            continue
        has_url = bool(URL_RE.search(ln))
        has_verdict = bool(re.search(r"verdict:\s*(?:%s)\b" % "|".join(VALID_VERDICTS),
                                     ln, re.IGNORECASE))
        # URL을 먼저 벗겨낸 뒤 ST<N>을 찾는다 — 안 그러면 URL 경로 조각에 우연히 낀
        # word-bounded ST<N>(예: `/ST9/`)이 실제 참조인 양 요구를 충족시켜버린다.
        ln_no_url = URL_RE.sub("", ln)
        has_st = bool(ST_REF_RE.search(ln_no_url))
        stripped = VERDICT_CLAUSE_RE.sub("", ST_REF_RE.sub("", ln_no_url)).lstrip("- ").strip()
        has_stmt = len(stripped) >= 10
        if not (has_verdict and has_stmt and has_st and (has_url or not require_url)):
            miss = []
            if not has_stmt:
                miss.append("statement<10c")
            if require_url and not has_url:
                miss.append("no-url")
            if not has_verdict:
                miss.append("no-verdict")
            if not has_st:
                # web kill switch는 URL 요구만 완화한다 — ST 참조는 파일-축 drift-guard라
                # 웹 가용성과 무관하다.
                miss.append("no-ST-ref")
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
    """audit §1 Coverage Ledger form 검증 (AC10).

    입력은 **audit 텍스트**다 — 원장은 v0.23.0에서 payload §6을 떠나 audit §1로 옮겨갔다.
    Form-level only: floor 5행 각 존재 + status 토큰 'closed' + evidence 세그먼트
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

    ue = user_sourced_errors(text)
    if ue:
        failures.append(f"user_sourced_items: {ue}")
    if confirmed_zero_unsentineled(text):
        failures.append("confirmed 0건인데 명시 sentinel 없음 (확인 게이트 우회 신호)")
    sec6_absent = any(m.startswith("6.") for m in miss)
    if not sec6_absent:
        ce = bijection_c_errors(text)
        if ce:
            failures.append(f"bijection C (evidence→§6): {ce}")
    if not sec6_absent and attribution_block_missing(text):
        failures.append("§6 출처 표기 블록 부재 (🗣·☑·✎ 세 기호를 모두 담은 인용 줄 필요)")

    sec2_absent = any(m.startswith("2.") for m in miss)
    if not sec2_absent:
        be = bijection_b_errors(text)
        if be:
            failures.append(f"bijection B (body §2↔frontmatter): {be}")

    # payload §5 소비자가 여럿(landscape/skepticism/R4/bijection A)이라 한 번만 계산해
    # 공유한다 — bijection A만 이 가드를 빼먹으면 §5 부재 시 audit 쪽 ST가 전부
    # "판정 없는 steelman"으로 오탐된다(§5가 없으면 refs가 항상 공집합이므로).
    sec5_absent = any(m.startswith("5.") for m in miss)

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
            # 섹션 형태 검사보다 **먼저** 이 쌍이 같은 인터뷰인지 묻는다 — 형태가 완벽한 남의
            # audit이야말로 이 검사가 잡으려는 대상이다.
            pair = audit_pairing_errors(fm, audit_text)
            if pair:
                failures.append(f"audit pairing: {pair}")
            if not sec5_absent and not any(m.startswith("3.") for m in amiss):
                ae = bijection_a_errors(text, audit_text)
                if ae:
                    failures.append(f"bijection A (payload §5↔audit §3): {ae}")

    sec4_absent = any(m.startswith("4.") for m in miss)
    if not sec4_absent and not landscape_present(text):
        failures.append("External Landscape empty (no entries and no web-disabled sentinel)")
    unc = landscape_uncited(text)
    if unc:
        failures.append(f"uncited landscape entries: {len(unc)}")
    mal = skepticism_malformed(text)
    if mal:
        failures.append(f"malformed §5 verdict entries: {len(mal)}")

    if not sec5_absent and not tried_discarded_ok(text):
        failures.append("§5 기각 항목 0건 (N/A sentinel 없음)")

    # Coverage Ledger는 이제 audit에 산다 — audit을 못 열었으면 위에서 이미 red.
    if audit_text and not any(m.startswith("1.") for m in find_missing_sections(audit_text, AUDIT_SECTIONS)):
        cov = coverage_ledger_failures(audit_text)
        if cov:
            failures.append(f"coverage ledger: {cov}")

    ok = not failures
    metric = payload_body_lines_excl_verbatim(text)
    advisories: list[str] = []
    if metric > LINE_TRIPWIRE:
        advisories.append(
            f"[spec-distill] payload 본문 {metric}줄(§6 제외) — 예산 137 / 트립와이어 "
            f"{LINE_TRIPWIRE} 초과. 분량은 목표이지 정확성 조건이 아니므로 차단하지 않는다."
        )
    for a in advisories:
        print(a, file=sys.stderr)
    print(json.dumps({"pass": ok, "failures": failures,
                      "payload_body_lines_excl_verbatim": metric,
                      "advisories": advisories}, ensure_ascii=False))
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
    if sub == "items":
        print(json.dumps({"errors": user_sourced_errors(text),
                          "bijection_c": bijection_c_errors(text),
                          "bijection_b": bijection_b_errors(text)}, ensure_ascii=False))
        return 0
    if sub == "metrics":
        print(json.dumps({"payload_body_lines_excl_verbatim":
                          payload_body_lines_excl_verbatim(text)}, ensure_ascii=False))
        return 0
    print(f"unknown subcommand: {sub}", file=sys.stderr)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv))
