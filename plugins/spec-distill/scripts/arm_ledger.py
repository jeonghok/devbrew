#!/usr/bin/env python3
"""spec-distill arm ledger — arm 판정의 단일 지점 (v0.25.0).

design doc auto-review(Layer 2)를 문서 생애 한 번만 발동시킨다.

    should_arm(state_file, path) =
          not is_armed(state_file, path)   # 세션 원장 — 세션 안쪽 시간축
      and not is_born(path)                # git 추적 여부 — 세션 바깥 시간축

`armed_paths`의 의미는 하나다: "더 이상 dispatch 안 함". 기록자는 둘이지만
(verdict = 완료, G6 상한 = 포기) 결론이 같다.

이 파일이 v0.14.0–v0.18.0에 쌓였던 억제·락 방어층(문서별 억제 집합, 문서-키
진행중 락)을 대체한다. 억제는 리뷰가 끝난 뒤 *제3자*가 사후 기록해야 해서 기록자가
셋 필요했고 빠뜨림을 막는 층이 그 위에 쌓였다. arm 원장은 리뷰 자신이 자기 완료를
기록하므로 그 층이 필요 없다.

CLI:
  arm_ledger.py strip-pending <sid> <raw_path>   # reviewing-spec Step 1 진입
  arm_ledger.py mark-reviewed <sid> <raw_path>   # reviewing-spec Step 3 (verdict)
  arm_ledger.py check-born    <raw_path>         # reviewing-spec approve(①/②)
                                                 #   0=git-tracked, 1=미커밋+advisory, 2=usage

Kill switch (CLI defense-in-depth): DEVBREW_SPEC_DISTILL_DISABLE=1 → no-op.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from state_path import SESSION_PATTERN  # noqa: E402 # pyright: ignore[reportMissingImports]
# `state_file_for` 는 훅과 공유하는 정의다 — 같은 플러그인 안이므로 import 하나로
# 중복이 소멸한다(설계 §6.1③). 여기서 재-export 되므로 `arm_ledger.state_file_for`
# 로 부르는 소비자(spec-write-validator.py)는 그대로 동작한다.
from hook_common import parse_iso, state_file_for  # noqa: E402,F401 # pyright: ignore[reportMissingImports]

PREFIX = "docs/superpowers/specs/"

#: G6 — verdict 없이 끝난 dispatch의 세션당·문서당 재시도 상한 (§5.2 상태기계).
DISPATCH_ATTEMPT_CAP = 3

#: PostToolUse 훅 전체 timeout이 10초라 git 호출은 그 절반으로 묶는다 (§8).
GIT_TIMEOUT_SEC = 5

PENDING_RE = re.compile(r"^pending_review:\n(?:  [^\n]*\n)*", re.MULTILINE)
ARMED_RE = re.compile(r"^armed_paths:\n((?:  - [^\n]+\n)*)", re.MULTILINE)
ATTEMPTS_RE = re.compile(r"^dispatch_attempts:\n((?:  [^\n]+\n)*)", re.MULTILINE)
INFLIGHT_RE = re.compile(r"^inflight_paths:\n((?:  [^\n]+\n)*)", re.MULTILINE)
VALIDATION_RE = re.compile(r"^validation_attempts:\n((?:  [^\n]+\n)*)", re.MULTILINE)

#: 구조 검증 실패의 세션당·문서당 재시도 상한. `DISPATCH_ATTEMPT_CAP` 과 **별도**여야
#: 한다 — 합치면 구조 실패 2회 뒤에 리뷰 dispatch 가 1회밖에 남지 않는다 (설계 §4.4).
VALIDATION_ATTEMPT_CAP = 3

#: in-flight 표시의 만료. 리뷰 소요보다 넉넉히 길되 무한은 아니다 — 리뷰가 중간에
#: 죽으면 이 표시가 남아 게이트를 조용히 닫는데, 그 방향은 Law 1 이 금지하는
#: under-review 다. 만료 뒤 재-dispatch 는 `DISPATCH_ATTEMPT_CAP` 이 상한을 준다.
INFLIGHT_TTL_SEC = 900


def canonical_key(raw_path: str) -> str | None:
    """경로에서 PREFIX 이후 substring. 스코프 밖이면 None.

    워크트리·절대·상대 경로가 같은 문서를 같은 키로 매핑한다. 정규화는 이 함수에만 존재.
    """
    if not raw_path:
        return None
    idx = raw_path.find(PREFIX)
    if idx < 0:
        return None
    key = raw_path[idx:]
    # 제어문자가 든 경로는 키가 될 수 없다. 상태 파일은 0-indent 블록으로 파싱되는
    # 마크다운이라, 개행이 든 경로가 보간되면 `armed_paths:` 블록을 위조해 **다른**
    # 문서의 리뷰를 영구 억제할 수 있다. 스코프 밖(None)으로 떨어뜨리는 것이 안전한
    # 방향 — arm 억제가 아니라 arm 유지 쪽이다.
    # **위조 판정은 reader 와 같은 함수로 한다.** `armed_keys`·`attempts` 는
    # `splitlines()` 로 줄을 나누는데, 그건 `\n` 뿐 아니라 universal-newline 전체
    # (VT U+000B · FF U+000C · FS/GS/RS U+001C-1E · NEL U+0085 · LS U+2028 · PS U+2029)
    # 에서 쪼갠다. 반면 `ARMED_RE` 의 `[^\n]+` 는 그것들을 전부 통과시킨다 — 그래서
    # U+2028 이 든 키는 **물리적으로 한 줄**로 기록되고 **두 개의 키**로 읽혀 다른
    # 문서의 리뷰를 영구 억제한다. `\n\r` 만 세는 것으로는 부족하다.
    #
    # 아래 `isprintable()` 도 같은 문자들을 (Cc/Zl/Zp 라서) 막으므로 이 줄은 **행동상
    # 잉여**다 — 지워도 동작이 바뀌지 않는다. 남겨 두는 이유는 방어가 아니라 **선언**:
    # `isprintable()` 이 무엇을 지키고 있는지가 이름만 봐서는 보이지 않아, 리뷰에서
    # 실제로 "과하니 `\n\r\x00` 로 좁히자"는 제안이 나왔다. 그 좁히기는 T16 이 막는
    # 위조를 되연다.
    #
    # 착각 금지: 이 줄이 그 좁히기를 **막지는 못한다**. `isprintable()` 만 지우고 이 줄을
    # 남기면 `\x1b` 같은 문자가 키로 통과한다(측정 확인). 그 조합을 잡는 것은 이 줄이
    # 아니라 유닛 테스트 쪽 책임이다.
    if len(key.splitlines()) != 1:
        return None
    if any(c in key for c in "\n\r\t\x00") or not key.isprintable():
        return None
    return key


def pending_path(body: str) -> str | None:
    m = PENDING_RE.search(body)
    if not m:
        return None
    for line in m.group(0).splitlines():
        ls = line.strip()
        if ls.startswith("path:"):
            return ls[len("path:"):].strip()
    return None


def strip_pending(body: str) -> str:
    """pending_review 블록 제거. 0-indent 원장 블록은 보존."""
    return PENDING_RE.sub("", body)


def armed_keys(body: str) -> list[str]:
    m = ARMED_RE.search(body)
    if not m:
        return []
    keys: list[str] = []
    for line in m.group(1).splitlines():
        ls = line.strip()
        if ls.startswith("- "):
            keys.append(ls[2:].strip())
    return keys


def _parse_kv_lines(block: str) -> dict[str, str]:
    """`  key: value` 줄들을 dict 로 — 세 원장 블록(attempts·inflight·
    validation_attempts)이 공유하는 유일한 저수준 파서 (설계 §6.1). 값 변환(정수화 등)은
    호출부 책임 — 이 함수는 문자열째로만 돌려준다.
    """
    out: dict[str, str] = {}
    for line in block.splitlines():
        ls = line.strip()
        key, sep, val = ls.rpartition(": ")
        if not sep:
            continue
        out[key.strip()] = val.strip()
    return out


def _parse_int_block(regex: re.Pattern[str], body: str) -> dict[str, int]:
    m = regex.search(body)
    if not m:
        return {}
    out: dict[str, int] = {}
    for key, val in _parse_kv_lines(m.group(1)).items():
        try:
            out[key] = int(val)
        except ValueError:
            continue
    return out


def attempts(body: str) -> dict[str, int]:
    return _parse_int_block(ATTEMPTS_RE, body)


def inflight(body: str) -> dict[str, str]:
    """key → in-flight 로 마킹된 ISO 타임스탬프 문자열 (A12)."""
    m = INFLIGHT_RE.search(body)
    if not m:
        return {}
    return _parse_kv_lines(m.group(1))


def validation_attempts(body: str) -> dict[str, int]:
    """구조 검증 실패 카운터 — `attempts`(dispatch_attempts) 와 별도 블록 (A14)."""
    return _parse_int_block(VALIDATION_RE, body)


def _read_body(state_file: Path) -> str | None:
    """원장 read. 부재는 `""`, **판독 실패는 `None`** — 둘은 같은 뜻이 아니다.

    이 구분이 이 모듈의 유일한 비대칭 방어다. 빈 body 로의 degrade 는 *읽기* 술어
    (`is_armed`·`skip_reason`)에는 옳다 — 미기록으로 읽혀 arm 쪽, 안전한 방향이다.
    그러나 같은 값을 read-modify-write 인 `mark_reviewed` 가 "새 세션" 으로 읽으면
    파일 전체를 덮어써 다른 문서의 `armed_paths` 와 살아있는 `pending_review` 를
    함께 지운다 — 이 릴리스가 없애려는 재발동 그 자체다. 그래서 읽기 쪽은 호출부에서
    명시적으로 `or ""` 로 degrade 하고(방향이 코드에 보이게), 쓰기 쪽은 `None` 에서
    멈춘다. 판독 불가 파일은 보존한다 (CLAUDE.md: 실패 시 디버깅을 위해 보존).
    """
    if not state_file.exists():
        return ""
    try:
        return state_file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(
            f"[spec-distill] arm_ledger: 원장 read 실패: {exc}",
            file=sys.stderr,
        )
        return None


def _compose(
    body: str,
    keys: list[str],
    att: dict[str, int],
    infl: dict[str, str] | None = None,
    val: dict[str, int] | None = None,
) -> str:
    """원장 네 블록을 재조립. 나머지 본문(frontmatter·pending·타임스탬프)은 보존.

    `infl`·`val` 은 기본값 `None`(→ `{}`) 을 갖지만, **모든 호출부가 명시적으로
    채워서 넘긴다** — 그렇지 않으면 body 에 이미 있던 inflight_paths·
    validation_attempts 블록이 이 함수를 거치는 순간 조용히 사라진다(round-trip 이
    아니라 삭제가 된다). 기본값은 오직 순수 함수로서의 안전한 시그니처를 위한
    것이지, "생략해도 된다"는 뜻이 아니다.
    """
    infl = infl or {}
    val = val or {}
    rest = VALIDATION_RE.sub(
        "", INFLIGHT_RE.sub("", ATTEMPTS_RE.sub("", ARMED_RE.sub("", body)))
    ).rstrip()
    parts = [rest] if rest else []
    if keys:
        parts.append(
            "armed_paths:\n" + "".join(f"  - {k}\n" for k in keys).rstrip())
    if att:
        parts.append(
            "dispatch_attempts:\n"
            + "".join(f"  {k}: {n}\n" for k, n in sorted(att.items())).rstrip())
    if infl:
        parts.append(
            "inflight_paths:\n"
            + "".join(f"  {k}: {v}\n" for k, v in sorted(infl.items())).rstrip())
    if val:
        parts.append(
            "validation_attempts:\n"
            + "".join(f"  {k}: {n}\n" for k, n in sorted(val.items())).rstrip())
    return "\n\n".join(parts) + "\n"


def is_armed(state_file: Path, raw_path: str) -> bool:
    key = canonical_key(raw_path)
    if key is None:
        return False
    # 읽기 술어 — 판독 실패는 "미기록"으로 degrade 해 arm 쪽(안전한 방향)으로 떨어진다.
    return key in armed_keys(_read_body(state_file) or "")


def is_born(raw_path: str) -> bool:
    """git이 아는 문서면 True. 판정 실패는 전부 False(=arm 쪽)로 fail-open (§8).

    `git add`만 된 문서도 태어난 것으로 본다 — 저자가 리포에 넣기로 이미 결정했다는 뜻.
    """
    if not raw_path:
        return False
    # 고쳐야 했던 버그는 **상대경로**에만 있었다: repo-root 상대 경로를 하위 디렉토리에서
    # 넘기면 git 이 cwd 상대로 해석해, 커밋된 문서가 not-born 으로 떨어진다(v0.14.0 과
    # 같은 모양). 그래서 상대경로만 `:(top,...)` 로 리포 루트에 고정한다.
    #
    # **절대경로는 접지 않는다.** canonical_key 는 PREFIX 이후만 남기므로, 접어 버리면
    # 다른 체크아웃(특히 `<main_repo>/.claude/worktrees/<name>/` 아래)의 문서가 이 리포의
    # 동명 파일로 판정돼 born=True 가 되고, `should_arm` 이 False 가 되어 그 문서의 Law 1
    # 게이트가 조용히 꺼진다 — 측정으로 재현했다(cwd=main repo, 워크트리 문서 → rc 0).
    # 절대경로의 소속 리포는 git 이 스스로 정확히 판정한다(리포 밖이면 128 → loud → arm).
    # 그 판정을 빼앗은 것이 결함의 원인이었으므로, 답은 containment 검사를 **더하는** 게
    # 아니라 접기를 **하지 않는** 것이다. 문자열 접두사 비교는 여기서 특히 틀린다 —
    # 워크트리가 main repo 경로 **안쪽**에 있어 "같은 리포"로 오판한다.
    #
    # 양쪽 다 `literal` 매직을 붙인다. `--` 는 옵션 파싱만 멈출 뿐 wildmatch 를 끄지
    # 않아서, 파일명 속 `*` 하나가 무관한 tracked 파일에 매칭돼 존재한 적 없는 문서를
    # born 으로 만든다(측정: `:/…/*-design.md` → rc 0, `:(top,literal)…` → rc 1).
    key = canonical_key(raw_path)
    if os.path.isabs(raw_path):
        pathspec = f":(literal){raw_path}"
    elif key is not None:
        pathspec = f":(top,literal){key}"
    else:
        pathspec = f":(literal){raw_path}"
    try:
        cp = subprocess.run(
            ["git", "ls-files", "--error-unmatch", "--", pathspec],
            capture_output=True, text=True, check=False, timeout=GIT_TIMEOUT_SEC,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        print(
            f"[spec-distill] arm_ledger: git ls-files 실행 실패 — "
            f"미커밋으로 간주(arm): {exc}",
            file=sys.stderr,
        )
        return False
    if cp.returncode == 0:
        return True
    if cp.returncode != 1:
        # 1 = 리포 안의 untracked(정상). 그 외(128=리포 밖 등)는 판정 불능이므로 loud.
        print(
            f"[spec-distill] arm_ledger: git ls-files exit={cp.returncode} "
            f"('{raw_path}') — 미커밋으로 간주(arm): {cp.stderr.strip()}",
            file=sys.stderr,
        )
    return False


def should_arm(state_file: Path, raw_path: str) -> bool:
    """훅이 부르는 유일한 arm 판정 진입점 (§5.1 · G4)."""
    return not is_armed(state_file, raw_path) and not is_born(raw_path)


def skip_reason(state_file: Path, raw_path: str) -> str:
    """should_arm이 False인 사유. 'reviewed'|'capped'|'born'|'out-of-scope'.

    git을 다시 부르지 않는다 — should_arm이 False인데 원장에 없다면 born이 유일하게
    남은 사유이기 때문이다. should_arm이 True일 때 부르면 의미가 없다.
    """
    key = canonical_key(raw_path)
    if key is None:
        # `canonical_key` 의 None 은 **두 가지 다른 사실**을 뜻한다: 진짜 스코프 밖,
        # 그리고 스코프 안인데 키가 될 수 없음(제어문자·NBSP 등). 둘을 뭉개면 파일명의
        # 보이지 않는 문자 하나 때문에 자동 리뷰를 잃은 문서가 "스코프 밖 경로"로
        # 보고돼, 사용자는 원인도 조치도 알 수 없다. `unkeyable()` 의 docstring 이
        # 이 둘은 뭉개지지 않는다고 주장하는데, 뭉개지던 자리가 바로 여기였다.
        return "out-of-scope" if PREFIX not in raw_path else "unkeyable-path"
    # 읽기 전용 — 판독 실패는 빈 body 로 degrade (arm 쪽).
    body = _read_body(state_file) or ""
    if key in armed_keys(body):
        # mark-reviewed는 완료 시 attempts 항목을 지운다 → 남아 있으면 G6 상한 도달.
        return "capped" if key in attempts(body) else "reviewed"
    return "born"


def mark_armed(body: str, raw_path: str) -> str:
    """키를 armed_paths에 멱등 추가해 **문자열로 반환** (파일 write 안 함 — §6 원자성).

    Stop 훅은 G6 상한에 닿는 그 순간에만 pending strip·attempts·armed·타임스탬프를
    하나의 write로 커밋해야 한다. 여기서 파일을 따로 쓰면 write가 둘로 갈라진다.
    """
    key = canonical_key(raw_path)
    if key is None:
        return body
    keys = armed_keys(body)
    if key not in keys:
        keys.append(key)
    return _compose(body, keys, attempts(body), inflight(body), validation_attempts(body))


def next_attempt(body: str, raw_path: str) -> int:
    """이번 dispatch가 몇 번째 시도인지 (순수 함수). 스코프 밖이면 0 = 추적 안 함."""
    key = canonical_key(raw_path)
    if key is None:
        return 0
    return attempts(body).get(key, 0) + 1


def record_attempt(body: str, raw_path: str, n: int) -> str:
    """§5.2 상태기계의 유일한 구현.

    | dispatch 1·2회차 | attempts 증가 | armed 불변 |
    | dispatch 3회차   | attempts=3    | armed 키 추가 |

    3회차가 마지막 자동 dispatch이고 그 emit이 상한을 알리는 vehicle이다.
    이후 편집은 validator의 should_arm이 false라 pending 자체가 생기지 않는다.
    """
    key = canonical_key(raw_path)
    if key is None or n <= 0:
        return body
    att = attempts(body)
    att[key] = n
    keys = armed_keys(body)
    if n >= DISPATCH_ATTEMPT_CAP and key not in keys:
        keys.append(key)
    return _compose(body, keys, att, inflight(body), validation_attempts(body))


def mark_inflight(body: str, raw_path: str, now_iso: str) -> str:
    """리뷰 dispatch 직전에 호출 — "지금 이 문서를 리뷰 중" 을 원장에 남긴다 (A12).

    `is_inflight` 가 이 표시를 읽어 발견 결과에서 해당 문서를 제외한다. 리뷰가
    정상 종료하면 `mark_reviewed` 가 지운다; 비정상 종료(crash)로 남으면 TTL
    (`INFLIGHT_TTL_SEC`) 이 만료시켜 dispatch 쪽으로 되돌린다.
    """
    key = canonical_key(raw_path)
    if key is None:
        return body
    infl = inflight(body)
    infl[key] = now_iso
    return _compose(body, armed_keys(body), attempts(body), infl, validation_attempts(body))


def clear_inflight(body: str, raw_path: str) -> str:
    """in-flight 표시를 그 키만 지운다 (다른 블록은 보존, 순수 함수)."""
    key = canonical_key(raw_path)
    if key is None:
        return body
    infl = inflight(body)
    if key not in infl:
        return body
    del infl[key]
    return _compose(body, armed_keys(body), attempts(body), infl, validation_attempts(body))


def is_inflight(body: str, raw_path: str, now, ttl_sec: int = INFLIGHT_TTL_SEC) -> bool:
    """리뷰가 지금 이 문서에 대해 진행 중인가 — 발견 단계가 제외 판정에 쓴다 (A12).

    **판독 불가 타임스탬프는 만료로 읽는다**(→ False, dispatch 쪽으로 연다). 손상된
    원장이 게이트를 영구히 닫으면(under-review) Law 1 이 금지하는 방향이기 때문이다.
    재-dispatch 의 상한은 `DISPATCH_ATTEMPT_CAP` 이 별도로 준다.

    `ttl_sec` 기본값은 `INFLIGHT_TTL_SEC` — 호출부가 명시하지 않으면 그 상수가
    실제로 쓰인다(리터럴을 이 함수 안에 다시 박지 않는다).
    """
    key = canonical_key(raw_path)
    if key is None:
        return False
    ts = inflight(body).get(key)
    if ts is None:
        return False
    parsed = parse_iso(ts)
    if parsed is None:
        return False
    return (now - parsed).total_seconds() < ttl_sec


def next_validation(body: str, raw_path: str) -> int:
    """이번 구조 검증이 몇 번째 시도인지 (순수 함수). `next_attempt` 와 같은 모양이나
    `validation_attempts` 블록을 읽는다 — `DISPATCH_ATTEMPT_CAP` 과 별도 카운터(A14)."""
    key = canonical_key(raw_path)
    if key is None:
        return 0
    return validation_attempts(body).get(key, 0) + 1


def record_validation(body: str, raw_path: str, n: int) -> str:
    """구조 검증 실패 카운터를 기록 (순수 함수). `record_attempt` 와 블록이 다르다 —
    합치면 구조 실패 2회 뒤에 리뷰 dispatch 가 1회밖에 남지 않는다(설계 §4.4)."""
    key = canonical_key(raw_path)
    if key is None or n <= 0:
        return body
    val = validation_attempts(body)
    val[key] = n
    return _compose(body, armed_keys(body), attempts(body), inflight(body), val)


def mark_reviewed(state_file: Path, raw_path: str) -> bool:
    """verdict 시점 기록: armed_paths 추가 + dispatch_attempts 항목 삭제 + in-flight
    표시 제거 (§5.2, A12).

    완료된 리뷰는 시도 이력을 남길 이유가 없고, 남기면 다음 계산과 skip_reason에 섞인다.
    in-flight 표시도 같은 이유로 지운다 — verdict 가 났는데 표시가 남으면 다음
    발견에서 이 문서가 "리뷰 진행 중"으로 잘못 제외된다.
    """
    key = canonical_key(raw_path)
    if key is None:
        return False
    body = _read_body(state_file)
    if body is None:
        # 판독 불가 — 덮어쓰면 다른 문서의 원장·pending 이 함께 사라진다. 보존하고 멈춘다.
        print(
            "[spec-distill] arm_ledger: 원장 판독 불가 — 파일 보존, 리뷰 완료 미기록"
            "(같은 문서가 다시 dispatch될 수 있다).",
            file=sys.stderr,
        )
        return False
    if not body:
        body = f"---\nsession_id: {state_file.parent.name}\n---\n\n"
    keys = armed_keys(body)
    if key not in keys:
        keys.append(key)
    att = attempts(body)
    att.pop(key, None)
    body = clear_inflight(body, raw_path)
    try:
        state_file.parent.mkdir(parents=True, exist_ok=True)
        state_file.write_text(
            _compose(body, keys, att, inflight(body), validation_attempts(body)),
            encoding="utf-8",
        )
    except OSError as exc:
        print(
            f"[spec-distill] arm_ledger: 원장 write 실패 — 리뷰 완료 미기록"
            f"(같은 문서가 다시 dispatch될 수 있다): {exc}",
            file=sys.stderr,
        )
        return False
    return True


def strip_pending_file(state_file: Path, raw_path: str) -> bool:
    """같은 키의 pending만 제거 (다른 문서 pending 보존). 원장은 건드리지 않는다 (§5.4).

    dispatch의 연료는 pending이다. 리뷰 진입 시 연료를 없애면 v0.18.0 락이 상태로
    표현하던 불변식("이 문서 리뷰 진행 중")을 한 줄로 얻는다. 진입은 리뷰의 시작일
    뿐 완료가 아니므로 여기서 armed_paths를 쓰면 안 된다.
    """
    key = canonical_key(raw_path)
    if key is None or not state_file.exists():
        return False
    body = _read_body(state_file)
    if body is None:
        # mark_reviewed 와 같은 이유 — 이것도 read-modify-write 다. 보존하고 멈춘다.
        print(
            "[spec-distill] arm_ledger: 원장 판독 불가 — 파일 보존, pending strip 안 함"
            "(리뷰 중 재dispatch 가능).",
            file=sys.stderr,
        )
        return False
    pend = pending_path(body)
    if pend is None or canonical_key(pend) != key:
        return False
    try:
        state_file.write_text(strip_pending(body).rstrip() + "\n", encoding="utf-8")
    except OSError as exc:
        print(
            f"[spec-distill] arm_ledger: pending strip write 실패 "
            f"(리뷰 중 재dispatch 가능): {exc}",
            file=sys.stderr,
        )
        return False
    return True


def clear_inflight_file(state_file: Path, raw_path: str) -> bool:
    """CLI `clear-inflight` 진입점 (파일 I/O). 정상 경로는 `mark_reviewed` 가 이미
    겸한다 — 이 CLI 는 리뷰가 crash 로 죽어 in-flight 표시만 수동으로 걷어내야 하는
    복구 경로다. TTL 만료를 기다리지 않고 즉시 게이트를 열고 싶을 때 쓴다.
    """
    key = canonical_key(raw_path)
    if key is None or not state_file.exists():
        return False
    body = _read_body(state_file)
    if body is None:
        # 다른 read-modify-write 함수들과 같은 이유 — 보존하고 멈춘다.
        print(
            "[spec-distill] arm_ledger: 원장 판독 불가 — 파일 보존, in-flight clear 안 함.",
            file=sys.stderr,
        )
        return False
    if key not in inflight(body):
        return False
    try:
        state_file.write_text(clear_inflight(body, raw_path), encoding="utf-8")
    except OSError as exc:
        print(
            f"[spec-distill] arm_ledger: in-flight clear write 실패: {exc}",
            file=sys.stderr,
        )
        return False
    return True


def _usage() -> int:
    print(
        "usage: arm_ledger.py {strip-pending|mark-reviewed|clear-inflight} <sid> <raw_path>\n"
        "       arm_ledger.py check-born <raw_path>",
        file=sys.stderr,
    )
    return 2


def main(argv: list[str]) -> int:
    if os.environ.get("DEVBREW_SPEC_DISTILL_DISABLE") == "1":
        print(
            "[spec-distill] arm_ledger: DEVBREW_SPEC_DISTILL_DISABLE=1 — no-op",
            file=sys.stderr,
        )
        return 0
    if len(argv) < 2:
        return _usage()
    cmd = argv[1]

    if cmd == "check-born":
        if len(argv) < 3:
            return _usage()
        raw_path = argv[2]
        if canonical_key(raw_path) is None:
            print(
                f"[spec-distill] arm_ledger: '{raw_path}' out of scope "
                f"(no {PREFIX}) — no-op",
                file=sys.stderr,
            )
            return 2
        if is_born(raw_path):
            return 0
        print(
            f"[spec-distill] '{raw_path}'가 아직 git에 없다 — 지금 커밋하지 않으면 "
            "다음 세션에서 이 문서의 리뷰가 한 번 더 발동한다.",
            file=sys.stderr,
        )
        return 1

    if len(argv) < 4:
        return _usage()
    sid, raw_path = argv[2], argv[3]
    if not SESSION_PATTERN.match(sid):
        trunc = sid[:32] + ("..." if len(sid) > 32 else "")
        print(
            f"[spec-distill] arm_ledger: session_id rejected: '{trunc}'",
            file=sys.stderr,
        )
        return 2
    sf = state_file_for(sid)

    if cmd == "strip-pending":
        strip_pending_file(sf, raw_path)
        return 0
    if cmd == "clear-inflight":
        clear_inflight_file(sf, raw_path)
        return 0
    if cmd == "mark-reviewed":
        if not mark_reviewed(sf, raw_path):
            print(
                f"[spec-distill] arm_ledger: '{raw_path}' 리뷰 완료 미기록 "
                "— 같은 문서가 다시 dispatch될 수 있다.",
                file=sys.stderr,
            )
            return 1
        return 0
    print(f"[spec-distill] arm_ledger: unknown subcommand '{cmd}'", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
