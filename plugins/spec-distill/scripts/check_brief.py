#!/usr/bin/env python3
"""spec-distill — interview brief structural gate.

집행하는 AC (2026-07-25-spec-distill-brief-format-producer-design.md §6):
AC4/AC5/AC6/AC7/AC9/AC10/AC11/AC12/AC15. 이 파일의 AC 번호는 **그 spec의 §6 표**를
가리킨다 — 옛 spec의 번호를 물려 쓰면 같은 숫자가 다른 뜻을 가리켜 traceability가 거짓이
된다(design doc Rejected Alternatives의 "AC↔T/V 편도 참조" 클래스). 이 spec에 대응 AC가
없는 검사(§4 «출처키» 요구, `type`/`next_phase` 규약 등)는 AC 번호를 붙이지 않는다.

The Law 1 termination gate for the conducting-interview problem-space stage,
made mechanical. conducting-interview runs `check_brief.py gate <payload>` before
finalizing the brief / before any optional brainstorming invoke; a non-zero exit
BLOCKS termination (one of the 5 통과 의례 unmet).

v0.23.0부터 brief는 payload + audit 2파일 쌍이다. `gate <payload>`는 payload 경로만
받고, payload frontmatter의 `audit_file`(basename-only, P21 계보)로 audit을 스스로
해석한다(AC9, fail-closed) — audit_file 부재·traversal·파일 부재는 전부 red다.

이 게이트는 **Law 1 구조 자기검사**다 (specs의 parse_spec_structure.py와 같은 층).
Law 2 분리 리뷰는 v0.24.0부터 그 위에 얹혔다 — `skills/reviewing-brief/`가 격리된
brief-critic(충실도) · brief-direction-reviewer(방향성) · brief-readback(냉독) + codex
축별 2회를 돌린다. 즉 "brief는 분리 리뷰를 받지 않는다"는 더 이상 사실이 아니다(NG3 교정,
Spec B AC17).

**불변식: 이 스크립트는 brief 파일만 읽는다** (payload + 그것이 가리키는 audit). conducting-interview의
세션 상태 파일에 대한 의존을 여기에 절대 넣지 않는다 — 넣으면 임의의 brief 파일에 게이트를 돌릴 수
없게 된다. state 원장 대조(§6 원문 완전성)는 별 모듈 `scripts/check_verbatim_coverage.py`의
몫이다(Spec B AC16 · E12).

PN4: the steelman "verbatim" guarantee is checked by substring containment — each
§5 기각 `verdict:` entry must contain a >=10-char statement + a valid verdict + a
`ST<N>` 참조 — NOT exact-string match (avoids flakiness). v0.44.0부터 URL 요구는
없다(N1a가 payload 외부 URL을 §6 예외만 두고 전면 금지하므로 여기서 따로 요구할
이유가 없다). Whether the steelman is a genuine counter-argument is not
machine-checked at all (모델 + 독립 adversary의 몫).

CLI subcommands (all print JSON):
  check_brief.py sections <payload>            → {"missing": [...]}        (AC4)
  check_brief.py landscape-keys <payload>      → {"unkeyed": [...]}        (§4 «출처키» 요구)
  check_brief.py skepticism <payload>          → {"malformed": [...]}      (AC11)
  check_brief.py tried-discarded <payload>     → {"ok": bool}              (AC11, R4 이관)
  check_brief.py coverage <payload>            → {"failures": [...]}       (AC10, audit §1 해석)
  check_brief.py frontmatter <payload>         → {"errors": [...]}         (AC6/AC9 키 존재)
  check_brief.py items <payload>               → {"errors": [...], "bijection_c": [...],
                                                    "bijection_b": [...]}  (AC6/AC7)
  check_brief.py gate <payload>                → {"pass": bool, "failures": [...],
                                                    "advisories": [...]}
                                                 exit 0 if pass else 1 (advisories never flip this)
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path


WEB_DISABLED_ADVISORY = (
    "[spec-distill] DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 — 이 게이트 실행에서 완화된 것은 "
    "**하나**다: §4 External Landscape가 항목 없이 web-disabled sentinel로 만족될 수 있다. "
    "payload 외부 URL 금지(N1a)·§4 «출처키» 요구(#13)·audit §7 결속(N2)은 완화되지 않는다."
)


def _web_disabled() -> bool:
    """Graceful degradation — v0.44.0 N1a 이후 이 스위치가 완화하는 것은 정확히 **하나**,
    `landscape_present`의 §4 sentinel 경로(#12)뿐이다. §4 «출처키» 요구(#13)·§5 verdict
    형식(URL 요구는 이 커밋에서 지웠다)·payload 외부 URL 금지(N1a)·audit §7 결속(N2)은
    이 스위치로 완화되지 않는다 — 웹이 꺼져 있어도 출처를 말로 댈 수 있고, payload에
    URL을 넣을 이유가 web 상태와 무관하게 생기지 않는다."""
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
    ("6", "사용자 원문"),
    ("7", "확산 원자료"),
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


# 불릿 문자는 `-`와 `*`를 **둘 다** 받는다 — §2 본문을 읽는 `BODY_ITEM_RE`(`^\s*[-*]\s+`)와 반드시
# 같은 관례여야 한다. 같은 아티팩트를 두 규칙이 서로 다른 관례로 읽으면 불릿 한 글자로 검사를
# 우회할 수 있다: `- 인용된 항목` 하나와 `* 출처 없는 주장` 하나를 §4에 두면 `landscape_present`는
# 하이픈 항목으로 만족되고 `landscape_unkeyed`는 애스터리스크 항목을 아예 못 봐서, R2의 "출처 «키»
# 필수"가 통째로 통과한다(리뷰 실증: 같은 줄을 `-`로 쓰면 red, `*`로 쓰면 green).
ENTRY_BULLET_RE = re.compile(r"^\s*[-*]\s")


def _entry_lines(section: str) -> list[str]:
    return [
        ln.strip()
        for ln in section.splitlines()
        if ENTRY_BULLET_RE.match(ln) and ln.strip() not in ("-", "*")
    ]


# 불릿을 떼는 곳은 여기 하나다. 소비자들이 각자 `lstrip("- ")`를 쓰면 안 된다 — 그건 **문자 집합**
# strip이라 `*`를 벗기지 않아서, `_entry_lines`가 `*`를 받아들인 직후 소비자는 그 줄을 못 알아본다
# (`* 기각 — …`이 R4에 안 세지고, `* floor:root_problem — …`이 원장 행 부재로 읽힌다). 방향은
# fail-closed라 우회는 안 되지만, 항목을 받아들이는 규칙과 해석하는 규칙이 어긋나는 건 이 커밋이
# 방금 닫은 바로 그 결함이다 — 한 층 아래에서 되풀이하지 않는다.
BULLET_PREFIX_RE = re.compile(r"^\s*[-*]\s+")


def _strip_bullet(ln: str) -> str:
    """항목 줄에서 선행 불릿(`-` 또는 `*`) **하나**와 뒤따르는 공백을 뗀다."""
    return BULLET_PREFIX_RE.sub("", ln, count=1)


def _frontmatter(text: str) -> str:
    m = FRONTMATTER_RE.match(text)
    return m.group(1) if m else ""


def frontmatter_value(key: str, text: str):
    """frontmatter에서 키 하나의 값을 읽는다. `(값, 오류)` — 둘 중 하나만 non-None.

    frontmatter 키를 읽는 곳은 **여기 하나**다. 이 규칙들은 각각 실제 우회로를 닫은 것이고,
    한 곳에 모아두지 않으면 키마다 규칙이 갈려 고친 키만 안전해진다(실측: 세 키 중 둘만
    하드닝하고 `audit_file`을 남겨두자 그 키가 자기 docstring이 금지한 두 패턴을 그대로 썼다):

    1. **개수는 값이 아니라 키 라인으로 센다.** 값 추출 패턴으로 세면 값이 빈 중복 키가 카운트에서
       빠진다 — `session_id:` + `session_id: <맞는 값>`이면 hit이 1개라 중복 거부를 통과한다.
    2. **키와 값 사이로 개행을 넘지 않는다.** `\\s`는 개행을 포함하므로 `\\s*`를 쓰면 값이 빈 키가
       **다음 줄 토큰을 값으로 포획한다** — payload와 audit이 둘 다 `session_id:`를 비우면 양쪽이
       똑같이 아래 `source:`로 읽혀 페어링이 상수로 붕괴했다(실행 실증: exit 0).
    3. **값은 라인 끝까지 읽고 주석만 뗀다.** 첫 공백에서 끊으면 `shared payload`와 `shared audit`이
       둘 다 `shared`로 읽혀 서로 다른 인터뷰가 동일 비교로 통과한다.
    4. **공백이 남은 값은 거부한다.** 이 키들은 전부 단일 토큰이다. 모호한 입력에서 값을 하나
       골라주지 않는 것이 이 함수의 존재 이유다.
    """
    raw = re.findall(rf"^{re.escape(key)}:([^\n]*)$", text, re.MULTILINE)
    if not raw:
        return None, f"{key} key absent"
    if len(raw) > 1:
        return None, f"{key} 중복 {len(raw)}건 (모호 — 거부)"
    val = _strip_inline_comment(raw[0]).strip().strip('"').strip("'")
    if not val:
        return None, f"{key} key absent"
    if len(val.split()) > 1:
        return None, f"{key} 값에 공백 {val!r} (단일 토큰이어야 함 — 부분 비교 금지)"
    return val, None


def resolve_audit(payload: Path, fm: str):
    """payload frontmatter의 audit_file을 해석한다 (AC9, fail-closed).

    audit_file은 신뢰 경계 밖 입력이므로 **basename만** 허용한다(P21 계보) — `../x.md`,
    `/etc/x.md`, `a/b.md`는 전부 Path(...).name != 원문이라 거부된다. 부재·미해석은
    전부 게이트 red이며, 조용히 payload-only 검사로 degrade하지 않는다(2파일 fail-open 봉쇄).

    값 읽기는 `frontmatter_value`에 위임한다 — `audit_file`은 **다른 모든 audit-측 검사가
    무엇을 검증할지 고르는** 키라, 중복·빈 값·개행 포획 규칙에서 제외될 이유가 가장 없다.

    이름은 **payload 파일명에서 유도**된다 (`<payload stem>.audit.md`). 신뢰하지 않는 값을
    *검증*하는 대신 아예 *받지 않는* 것이다 — audit §1 Coverage Ledger가 Law 1 종료 판정의
    근거이므로, payload가 어떤 audit을 자기 것이라 부를지 스스로 고르게 두면 끝나지 않은
    인터뷰가 남의 완료된 원장을 상속한다(실행 실증: `audit_file:` 한 줄 편집으로 exit 1 → 0).
    `session_id` 동등성 검사만으로는 부족했다 — SKILL이 세션 id 재사용을 규정해 한 세션의 두
    인터뷰가 같은 id를 갖기 때문이다. 유도는 그 구멍까지 닫는다: 한 payload가 가리킬 수 있는
    audit은 정의상 하나뿐이다. `session_id`/`type` 검사는 그대로 남는다 — 파일이 옮겨지거나
    이름이 바뀌는 경우의 2차 방어다.

    검사 순서는 basename → 유도 → 존재다. traversal은 유도 실패로 뭉개지 말고 자기 메시지로
    거절해야 원인과 증상이 어긋나지 않는다.
    """
    name, err = frontmatter_value("audit_file", fm)
    if err:
        return None, err
    if Path(name).name != name:
        return None, f"audit_file {name!r} is not a basename (traversal rejected)"
    expected = payload.stem + ".audit.md"
    if name != expected:
        return None, (
            f"audit_file {name!r} is not this payload's sidecar (expected {expected!r} — "
            "다른 인터뷰의 audit 채택 금지)"
        )
    p = payload.parent / name
    if not p.exists():
        return None, f"audit file not found: {name}"
    return p, None


def audit_pairing_errors(payload_fm: str, audit_text: str, payload_name: str) -> list[str]:
    """audit이 *이 payload의* sidecar인지 확인한다 (fail-closed).

    `resolve_audit`은 basename이 같은 디렉토리에 존재하기만 하면 받아들이므로, payload가
    **다른 인터뷰의 audit**을 가리켜도 통과했다. audit §1 Coverage Ledger는 Law 1 종료 판정
    (floor 5 전부 closed)의 근거이므로, 끝나지 않은 인터뷰가 남의 원장을 상속해 green이 된다 —
    리뷰가 실행으로 실증했다: 같은 payload가 `audit_file: mine.audit.md`(floor 5 전부 open)에는
    exit 1, `audit_file: <남의 것>`(전부 closed)에는 exit 0. 한 줄 편집이 실패를 통과로 바꿨다.
    `bijection_a_errors`는 백스톱이 못 된다 — `ST<N>`은 인터뷰마다 1부터 매겨져 steelman 1건짜리
    인터뷰 둘은 양쪽 다 `ST1`이라 불일치가 발생하지 않는다.

    부재는 불일치와 똑같이 red다 — 못 읽은 값을 "일치로 간주"하면 이 검사 자체가 fail-open이 되고,
    그건 이 함수가 막으려는 바로 그 실패 모드다.

    **알려진 한계 — 이 검사는 세션 경계까지만 막는다 (interview-level 미봉쇄).**
    결합 키는 `session_id`인데 `SKILL.md`가 payload에 **기존 spec-distill 세션 id 재사용**을
    규정하므로, 한 세션에서 진행한 두 인터뷰는 payload 2개와 audit 2개가 전부 같은 id를 갖는다.
    그 사이의 차용은 이 검사가 구분하지 못한다 — 실행으로 확인됨: `interview-brief-floor-open.md`의
    `audit_file:` 한 줄을 `interview-brief-valid.audit.md`로 바꾸면 exit 1 → **exit 0**.
    즉 위 문단이 서술한 공격은 *교차 세션*에서만 닫혔고, 정작 흔한 *동일 세션* 경우는 열려 있다.
    이 한계를 처음 놓친 이유는 증명 fixture(`interview-brief-foreign-audit.md`)가 다른 세션 id를
    써서 **쉬운 절반만** 시험했기 때문이다. 초기 서술이 자랑한 "fixture churn 0"이 바로 그 신호였다 —
    churn이 0인 것은 payload 39개가 이미 세션 id 하나를 공유하기 때문이고, 그건 곧 이 키가 그
    39개를 서로 구분하지 못한다는 뜻이다.

    interview-level 결합에는 payload마다 고유한 audit이 필요하다 — `audit_file`을 payload 파일명에서
    유도하거나, audit이 이미 선언하지만 아무도 읽지 않는 `payload:` 역참조를 검사하는 것. 둘 다
    audit fixture를 payload별로 분리해야 해서 이 라운드의 스코프 밖이며, 사용자 판단 사항이다.
    """
    errs: list[str] = []
    afm = _frontmatter(audit_text)

    def _one(key: str, text: str, label: str):
        """`frontmatter_value`의 오류를 **어느 파일의** 어떤 키인지 밝히는 문구로 바꾼다.

        페어링 진단에서 가장 먼저 알아야 하는 것은 payload 쪽인지 audit 쪽인지다 — 두 파일이
        같은 키 이름을 쓰므로 키 이름만 담은 원본 문구로는 구분이 안 된다.
        """
        val, err = frontmatter_value(key, text)
        if err is None:
            return val
        detail = "없음" if err == f"{key} key absent" else err[len(key) + 1:]
        errs.append(f"{label} {detail}")
        return None

    atype = _one("type", afm, "audit frontmatter에 type")
    if atype is not None and atype != "interview-audit":
        errs.append(f"audit type {atype!r} != 'interview-audit'")
    # audit이 **어느 payload의 것이라고 스스로 선언하는지**를 읽는다. 이름 유도는 "어느 파일을
    # 읽을지"를 고정하지만 그 파일의 *내용*까지 묶지는 못한다 — 남의 audit을 유도 경로에 복사해
    # 넣으면 그대로 통과했다(실행 실증: floor가 열린 payload의 sidecar 자리에 완료된 audit을
    # 복사 → exit 0). 이 역참조는 두 템플릿과 모든 fixture가 이미 담고 있으면서 아무도 읽지
    # 않던 필드다 — 선언만 있고 읽는 코드가 없으면 그건 계약이 아니다.
    apay = _one("payload", afm, "audit frontmatter에 payload")
    if apay is not None and apay != payload_name:
        errs.append(
            f"audit payload {apay!r} != {payload_name!r} "
            "(다른 인터뷰의 audit 내용 — Coverage Ledger 차용)"
        )
    psid = _one("session_id", payload_fm, "payload frontmatter에 session_id")
    asid = _one("session_id", afm, "audit frontmatter에 session_id")
    if psid is not None and asid is not None and psid != asid:
        errs.append(
            f"audit session_id {asid!r} != payload {psid!r} "
            "(다른 인터뷰의 audit — Coverage Ledger 차용)"
        )
    return errs


VALID_SOURCES = ("verbatim", "chosen")
VALID_STATUSES = ("confirmed", "provisional", "open")
REQUIRED_ITEM_FIELDS = ("id", "source", "status", "statement", "evidence")
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

    `audit_file`은 이미 `frontmatter_value`가 주석을 떼는데 항목 필드는 떼지 않아,
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


# 같은 이유로 `[-*]` — `*`로 쓴 §6 앵커가 안 보이면 그 항목의 evidence가 전부 dangling으로
# 잡혀 원인과 무관한 red가 난다.
S_ANCHOR_RE = re.compile(r"^\s*[-*]\s+\*\*(S\d+)\*\*", re.MULTILINE)


def verbatim_anchors(text: str) -> set:
    """§6 사용자 원문이 제공하는 S<N> 앵커 집합."""
    return set(S_ANCHOR_RE.findall(_section_text(text, "6", "사용자 원문")))


def payload_verbatim_is_s1_only(payload_text: str) -> bool:
    """N1b — payload §6의 앵커 집합이 **정확히** {"S1"}인가 (v0.43.0).

    `⊆ {"S1"}`이 아니라 `== {"S1"}`이다. ⊆로 쓰면 빈 §6이 통과하고, 그때
    이를 잡아 줄 것으로 기대할 bijection C는 **항목이 0건인 payload에서 공허하다**
    (`evidence`는 필수 필드라 항목이 있으면 순회가 비지 않지만, 항목 0건이면
    루프가 아예 돌지 않는다). 등식이 그 구멍을 닫는다.

    등식 술어라 **스스로 양성이다** — §6을 통째로 지워도 이 검사가 직접 red를 낸다.
    이 자리를 bijection C에 귀속시키면 틀린 귀속이 되고, 잘못 귀속된 RED는
    통과보다 나쁘다.
    """
    return verbatim_anchors(payload_text) != {"S1"}


def bijection_c_errors(payload_text: str, audit_text: str) -> list[str]:
    """bijection C — 모든 evidence: S<N>이 §6에서 해석된다 (AC6).

    v0.43.0: 앵커 집합이 payload §6 **∪** audit §6이다. `S1`은 payload에,
    `S2` 이상은 audit에 살므로 한쪽만 보면 반대쪽 전량이 "없는 앵커"가 된다.

    **단방향이다.** 인용된 S<N>의 *존재*만 본다 — 모든 앵커가 인용될 것은
    요구하지 않는다. 그 역방향을 넣으면 audit §6 전량이 인용 의무로 끌려온다.
    "bijection이니 양방향이겠지"로 구현하면 안 된다.

    한계: 요약이 그 원문을 실제로 뒷받침하는지(의미적 정합)는 기계 검증하지 않는다 —
    V9 수동 spot-check가 그 갭을 맡는다.
    """
    anchors = verbatim_anchors(payload_text) | verbatim_anchors(audit_text)
    items, _ = parse_user_sourced_items(_frontmatter(payload_text))
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


SOURCE_KEY_RE = re.compile(r"«([^»]+)»")


def _body_excluding_section6(text: str) -> str:
    """payload 본문에서 §6 사용자 원문을 뺀 것 — N1a의 코퍼스.

    §6이 예외인 이유는 편의가 아니다. URL을 깎는 근거("링크가 권위로 읽혀 하류를
    끌고 간다")는 **모델이 web sweep으로 가져온 링크**를 겨눈다. 사용자가 자기
    요청에 직접 쓴 URL은 사용자가 하류에 전하려 한 것이고, 지우는 것은 압축이
    아니라 원문 훼손이다. 게다가 지우면 게이트가 **동시 만족 불가능**해진다 —
    `check_verbatim_coverage.py`의 `normalize()`가 맨 URL을 안 벗기므로 L2가
    `not_contained`로 exit 1을 낸다. 유일한 탈출로인 P21 치환은 보안 컨트롤을
    URL 세탁에 쓰는 것이고 그 statement의 L2를 advisory로 강등시킨다.
    """
    body = _body(text)
    m = re.search(r"^##\s+6\.\s+사용자 원문\b", body, re.MULTILINE)
    if not m:
        return body
    rest = body[m.end():]
    nxt = re.search(r"^##\s+\d+\.", rest, re.MULTILINE)
    return body[: m.start()] + (rest[nxt.start():] if nxt else "")


def payload_url_free(text: str) -> list[str]:
    """N1a — 모델이 저술한 payload 부분에 외부 URL(`https?://`)이 0개인가.

    **부재 술어다.** 대상 절을 통째로 지우면 공허하게 통과하므로, 이 검사의 이빨은
    이 함수 안에 없다 — #1 `find_missing_sections`(§4 절 삭제) · #12
    `landscape_present`(§4 항목 전부 삭제) · #15 `tried_discarded_ok`(§5 항목 전부
    삭제) 셋이 삭제 우회로를 막아야 이빨을 갖는다. "이 검사는 약하니 지우자" 류
    리팩터가 이 배치에서 특히 위험하다.

    **web kill switch로 완화하지 않는다.** 웹이 꺼졌다고 payload에 URL을 넣을 이유가
    생기지 않는다 — 완화할 대상이 애초에 없다(`check_seed.py`의 같은 주석).

    리포 내부 `file:line` 참조는 대상이 아니다 — 외부 권위가 아니라 고칠 대상을
    가리키는 손가락이고, 하류가 실제로 열어야 하는 것이다.
    """
    return [ln.strip() for ln in _body_excluding_section6(text).splitlines()
            if URL_RE.search(ln)]


def landscape_unkeyed(text: str) -> list[str]:
    """#13 — §4 항목마다 «출처키»가 있는가. **∀다**(v0.44.0에서 URL→키로 술어 교체).

    URL 요구는 audit으로 갔지만 **∀는 payload에 남는다.** 둘을 그대로 맞바꾸면
    인용 없는 §4 항목 여덟 개 + audit URL 한 개가 통과한다 — 강도 하락이다.
    audit으로 가는 것은 URL이라는 **술어뿐**이고, 그 술어는 ∃로 약해진다.

    **web kill switch로 완화하지 않는다.** 웹이 꺼져도 출처를 말로 댈 수 있다.
    web-off brief는 §4에 순회할 항목이 없어 공허하게 통과하는 것이 옳다 —
    조사하지 않았으면 인용할 것도 없다.
    """
    sec = _section_text(text, "4", "External Landscape")
    return [ln for ln in _entry_lines(sec) if not SOURCE_KEY_RE.search(ln)]


def landscape_keys_declared(payload_text: str, audit_text: str) -> list[str]:
    """N2 — payload §4의 «출처키» 집합 ⊆ audit §7이 선언한 키 집합 (v0.44.0).

    **개수가 아니라 집합이다.** 개수는 세 번 틀린다: web-off brief(§4에 항목 1건,
    §7에 0건)가 `1 ≤ 0`으로 red · 두 §4 항목이 같은 출처를 인용하면 `2 ≤ 1`로 red ·
    §7이 sweep을 산문 전문으로 적으면 「항목」의 계수 단위가 미정이라 집행 불가.
    집합이면 셋 다 통과한다. `bijection_a_errors`가 같은 판단을 이미 했다.

    **조건부다.** 「audit §7이 비어 있지 않다」로 두면 갓 만든 audit도 웹이 꺼진
    audit도 red가 된다. payload가 landscape를 실었다는 사실을 조건으로 건다 —
    키가 없으면 공집합 ⊆ 무엇이든으로 자동 만족되므로 kill switch 코드가 필요 없다.

    **이것이 보장하지 않는 것**: 어느 키가 어느 원자료인가. 키를 지어내도 통과한다
    (설계 §10). 그 해석까지 묶는 것은 §3.4 ①의 교차 bijection이고 기각됐다.
    """
    want = {m.group(1).strip()
            for ln in _entry_lines(_section_text(payload_text, "4", "External Landscape"))
            for m in SOURCE_KEY_RE.finditer(ln)}
    have = {m.group(1).strip()
            for m in SOURCE_KEY_RE.finditer(_section_text(audit_text, "7", "확산 원자료"))}
    return sorted(want - have)


def landscape_present(text: str) -> bool:
    """§4는 항목 ≥1을 갖거나, **web이 실제로 꺼져 있을 때만** sentinel로 대신한다.

    v0.44.0 이전까지는 §4 본문에 "생략" 한 단어만 있어도 True였고 URL 요구가 그것을
    덮어서 무해했다 — 이제 N1a(§4/§5 URL 전면 금지) 체제에서는 이것이 **N1a의 공허
    우회로를 여는 유일한 문**이 된다(§4에 "생략"만 쓰면 URL도 «출처키»도 없는 payload가
    통과한다). 그래서 sentinel 경로를 `_web_disabled()`로 좁혔다 — web이 실제로 꺼져
    있을 때만 sentinel이 유효하고, 켜져 있으면 sentinel 문구도 항목 없음과 동일하게
    취급된다(F3 — 헤더/문구 존재가 조사를 대신하지 않는다).

    **내구성 대가**: 이 함수가 처음으로 환경변수에 의존한다. web-off로 저술된 brief가
    다른 세션에서 그 변수 없이 게이트를 다시 타면 RED가 된다. audit `## 4. 게이트 실행
    기록`에 web-disabled 사유 칸을 둔 것은 그래서다 — 저술 시점의 환경을 아티팩트가
    날라, 나중 실행이 자기 환경으로 남의 brief를 판정하지 않게 한다.
    """
    sec = _section_text(text, "4", "External Landscape").strip()
    if not sec:
        return False
    if _web_disabled() and re.search(r"\bN/?A\b|비활성|생략|web[ -]?disabled", sec, re.IGNORECASE):
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


def attribution_block_missing(audit_text: str) -> bool:
    """audit §6 상단 출처 표기 블록 존재 검사 (AC5/C3 — v0.43.0에서 payload→audit 이사).

    템플릿이 상속시키지만 개별 audit에서 지워질 수 있으므로 게이트가 확인한다.
    """
    for ln in _section_text(audit_text, "6", "사용자 원문").splitlines():
        if ln.lstrip().startswith(">") and all(m in ln for m in ATTRIBUTION_MARKERS):
            return False
    return True


def skepticism_malformed(text: str) -> list[str]:
    """§5의 `verdict:` 항목 형식 검사. PN4: 정확한 문자열 일치가 아니라 containment.

    v0.44.0 N1a: URL 요구를 지웠다 — payload 외부 URL은 이제 N1a(`payload_url_free`)가
    §6 예외 하나만 두고 전면 금지하므로, 이 함수가 §5 항목에서 URL 유무를 스스로
    요구/거부할 이유가 없다(있으면 N1a가 별도로, 그리고 이 함수와 무관하게 red를 낸다).
    `verdict:`·`statement`·ST 참조 요구는 그대로 남는다 — web kill switch는 이 셋 중
    무엇도 완화하지 않는다(완화 대상이 URL 요구였는데 그게 없어졌다).
    """
    bad: list[str] = []
    for ln in section5_entries(text):
        if "verdict:" not in ln:
            continue
        has_verdict = bool(re.search(r"verdict:\s*(?:%s)\b" % "|".join(VALID_VERDICTS),
                                     ln, re.IGNORECASE))
        # URL을 먼저 벗겨낸 뒤 ST<N>을 찾는다 — URL 요구는 지웠지만 이 방어는 남긴다:
        # payload에 URL이 남아 있으면(N1a가 별도로 잡는다) 그 경로 조각에 우연히 낀
        # word-bounded ST<N>(예: `/ST9/`)이 실제 참조인 양 요구를 충족시키는 것을 막는다.
        ln_no_url = URL_RE.sub("", ln)
        has_st = bool(ST_REF_RE.search(ln_no_url))
        stripped = _strip_bullet(VERDICT_CLAUSE_RE.sub("", ST_REF_RE.sub("", ln_no_url))).strip()
        has_stmt = len(stripped) >= 10
        if not (has_verdict and has_stmt and has_st):
            miss = []
            if not has_stmt:
                miss.append("statement<10c")
            if not has_verdict:
                miss.append("no-verdict")
            if not has_st:
                miss.append("no-ST-ref")
            bad.append(f"{ln[:60]} :: {','.join(miss)}")
    return bad


# 불릿은 `_entry_lines`와 같은 관례여야 한다 — `^-`만 보면 `* 기각 — N/A`가 sentinel로
# 인식되지 않고 **실제 기각 1건**으로 오분류돼 R4가 헛통과한다(기각 0건인데 통과).
REJECT_NA_RE = re.compile(r"^[-*]\s*기각\s*—\s*N/?A\b", re.IGNORECASE)


def tried_discarded_ok(text: str) -> bool:
    """R4 통과 의례 이관 — 구 §7 Tried & Discarded가 §5로 병합됐다.

    병합은 표현의 통합이지 의례의 폐기가 아니다: `기각` 항목이 0건이면 명시 N/A sentinel
    없이는 통과할 수 없다. steelman과 무관하게 사용자가 폐기한 방향도 여기 남는다.
    """
    rej = [ln for ln in section5_entries(text) if _strip_bullet(ln).startswith("기각")]
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
        body = _strip_bullet(ln).strip()
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
    # 실제 오류를 그대로 싣는다 — 어떤 오류든 "key absent"로 뭉개면 중복 키가 부재로 보고돼
    # 원인과 증상이 어긋난다(중복 2건인데 "없다"고 말하면 사용자는 키를 하나 더 추가한다).
    _af_err = frontmatter_value("audit_file", fm)[1]
    if _af_err:
        errs.append(_af_err)
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
    if not sec6_absent and payload_verbatim_is_s1_only(text):
        failures.append(
            f"payload §6 앵커가 {{'S1'}}이 아니다: {sorted(verbatim_anchors(text))} "
            "(S1만 payload에, 나머지 전량은 audit §6에)")

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
            pair = audit_pairing_errors(fm, audit_text, path.name)
            if pair:
                failures.append(f"audit pairing: {pair}")
            if not sec6_absent:
                ce = bijection_c_errors(text, audit_text)
                if ce:
                    failures.append(f"bijection C (evidence→§6): {ce}")
            audit_sec6_absent = any(m.startswith("6.") for m in amiss)
            if not audit_sec6_absent and attribution_block_missing(audit_text):
                failures.append("audit §6 출처 표기 블록 부재 (🗣·☑·✎ 세 기호를 모두 담은 인용 줄 필요)")
            if not sec5_absent and not any(m.startswith("3.") for m in amiss):
                ae = bijection_a_errors(text, audit_text)
                if ae:
                    failures.append(f"bijection A (payload §5↔audit §3): {ae}")
            if not any(m.startswith("7.") for m in amiss):
                nk = landscape_keys_declared(text, audit_text)
                if nk:
                    failures.append(f"landscape keys not declared in audit §7: {nk}")

    sec4_absent = any(m.startswith("4.") for m in miss)
    if not sec4_absent and not landscape_present(text):
        failures.append("External Landscape empty (no entries and no web-disabled sentinel)")
    urls = payload_url_free(text)
    if urls:
        failures.append(f"payload에 외부 URL {len(urls)}건 (§6 사용자 원문 제외): {urls[:3]}")
    unk = landscape_unkeyed(text)
    if unk:
        failures.append(f"unkeyed landscape entries: {len(unk)}")
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
    advisories: list[str] = []
    # 킬 스위치가 verdict를 뒤집을 수 있으면 **반드시** 말한다. v0.44.0 N1a 이후
    # `_web_disabled()`가 완화하는 것은 `landscape_present`의 §4 sentinel 경로(#12) 하나
    # 뿐이지만, 그 하나조차 흔적 없이 완화되면 이전 세션에서 export한 env가 남아 있을 때
    # 이후 모든 brief가 이유 없이 통과한다. CLAUDE.md는 graceful degradation에 loud
    # logging을 요구한다. advisories 채널이 그 자리다.
    if _web_disabled():
        advisories.append(WEB_DISABLED_ADVISORY)
    for a in advisories:
        print(a, file=sys.stderr)
    print(json.dumps({"pass": ok, "failures": failures,
                      "advisories": advisories}, ensure_ascii=False))
    return 0 if ok else 1


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print("usage: check_brief.py <subcommand> <brief.md>", file=sys.stderr)
        return 64
    sub, path = argv[1], Path(argv[2])
    # v0.44.0 N1a: `skepticism`(§5 URL 요구)도 지워 kill switch로 완화되는 **단독
    # 서브커맨드가 이제 하나도 없다** — `landscape-keys`는 앞선 #13 개명에서, `skepticism`은
    # 이 커밋에서 빠졌다. 남은 유일한 완화 지점은 `gate()` 내부의 `landscape_present`
    # (#12 sentinel 경로)뿐이고, `gate`는 이미 advisories JSON으로 그것을 알린다 —
    # 별도 서브커맨드 stderr 알림이 더는 필요 없다(알릴 완화가 없다).
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
    if sub == "landscape-keys":
        print(json.dumps({"unkeyed": landscape_unkeyed(text)}, ensure_ascii=False))
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
        # 원장을 읽기 **전에** 이 쌍이 같은 인터뷰인지 묻는다 — `gate`는 거부하는 쌍을
        # `coverage`는 `{"failures": []}`로 답하고 있었다(codex 적발, 실행 실증). 같은 질문에
        # 두 진입점이 다른 답을 내면 둘 중 하나는 거짓이고, 여기선 느슨한 쪽이 거짓이다:
        # 남의 audit에서 읽은 원장은 이 payload에 대해 아무것도 말해주지 않는다.
        pair = audit_pairing_errors(_frontmatter(text), audit_text, path.name)
        if pair:
            print(json.dumps({"failures": [f"audit pairing: {p}" for p in pair]},
                             ensure_ascii=False))
            return 1
        print(json.dumps({"failures": coverage_ledger_failures(audit_text)},
                         ensure_ascii=False))
        return 0
    if sub == "frontmatter":
        print(json.dumps({"errors": frontmatter_errors(text)}, ensure_ascii=False))
        return 0
    if sub == "items":
        # bijection_c_errors는 v0.43.0부터 2인자다(payload ∪ audit 앵커) — gate()와
        # 같은 방식으로 audit을 해석해 넘긴다. **빈 리스트로 떨어뜨리지 않는다** — audit을
        # 못 열었다는 사실과 「위반 없음」은 다른 사실이고, `[]`로 내면 이 표면을 읽는
        # 쪽이 audit 미해석을 통과로 오독한다.
        audit_path, audit_err = resolve_audit(path, _frontmatter(text))
        if audit_err:
            bij_c = [f"audit 해석 실패 — bijection C 판정 불가: {audit_err}"]
        else:
            try:
                bij_c = bijection_c_errors(text, audit_path.read_text(encoding="utf-8"))
            except (OSError, UnicodeDecodeError) as exc:
                bij_c = [f"audit unreadable — bijection C 판정 불가: {exc}"]
        print(json.dumps({"errors": user_sourced_errors(text),
                          "bijection_c": bij_c,
                          "bijection_b": bijection_b_errors(text)}, ensure_ascii=False))
        return 0
    print(f"unknown subcommand: {sub}", file=sys.stderr)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv))
