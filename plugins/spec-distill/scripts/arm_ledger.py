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

Kill switch (CLI defense-in-depth): DEVBREW_DISABLE_SPEC_DISTILL=1 → no-op.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
HOOKS_DIR = SCRIPT_DIR.parent / "hooks"
sys.path.insert(0, str(HOOKS_DIR))
from state_path import state_root, SESSION_PATTERN  # noqa: E402 # pyright: ignore[reportMissingImports]

PREFIX = "docs/superpowers/specs/"

#: G6 — verdict 없이 끝난 dispatch의 세션당·문서당 재시도 상한 (§5.2 상태기계).
DISPATCH_ATTEMPT_CAP = 3

#: PostToolUse 훅 전체 timeout이 10초라 git 호출은 그 절반으로 묶는다 (§8).
GIT_TIMEOUT_SEC = 5

PENDING_RE = re.compile(r"^pending_review:\n(?:  [^\n]*\n)*", re.MULTILINE)
ARMED_RE = re.compile(r"^armed_paths:\n((?:  - [^\n]+\n)*)", re.MULTILINE)
ATTEMPTS_RE = re.compile(r"^dispatch_attempts:\n((?:  [^\n]+\n)*)", re.MULTILINE)


def canonical_key(raw_path: str) -> str | None:
    """경로에서 PREFIX 이후 substring. 스코프 밖이면 None.

    워크트리·절대·상대 경로가 같은 문서를 같은 키로 매핑한다. 정규화는 이 함수에만 존재.
    """
    if not raw_path:
        return None
    idx = raw_path.find(PREFIX)
    if idx < 0:
        return None
    return raw_path[idx:]


def state_file_for(sid: str) -> Path:
    """sid → state.local.md 경로 단일 해석(저장소 위치 변경 시 이 한 곳만 갱신)."""
    return state_root() / sid / "state.local.md"


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


def attempts(body: str) -> dict[str, int]:
    m = ATTEMPTS_RE.search(body)
    if not m:
        return {}
    out: dict[str, int] = {}
    for line in m.group(1).splitlines():
        ls = line.strip()
        key, sep, val = ls.rpartition(": ")
        if not sep:
            continue
        try:
            out[key.strip()] = int(val.strip())
        except ValueError:
            continue
    return out


def _read_body(state_file: Path) -> str:
    """원장 read. 실패는 빈 body로 degrade — 판정은 arm 쪽으로 fail-open (§8)."""
    if not state_file.exists():
        return ""
    try:
        return state_file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(
            f"[spec-distill] arm_ledger: 원장 read 실패 — 미기록으로 간주(arm): {exc}",
            file=sys.stderr,
        )
        return ""


def _compose(body: str, keys: list[str], att: dict[str, int]) -> str:
    """원장 두 블록을 재조립. 나머지 본문(frontmatter·pending·타임스탬프)은 보존."""
    rest = ATTEMPTS_RE.sub("", ARMED_RE.sub("", body)).rstrip()
    parts = [rest] if rest else []
    if keys:
        parts.append(
            "armed_paths:\n" + "".join(f"  - {k}\n" for k in keys).rstrip())
    if att:
        parts.append(
            "dispatch_attempts:\n"
            + "".join(f"  {k}: {n}\n" for k, n in sorted(att.items())).rstrip())
    return "\n\n".join(parts) + "\n"


def is_armed(state_file: Path, raw_path: str) -> bool:
    key = canonical_key(raw_path)
    if key is None:
        return False
    return key in armed_keys(_read_body(state_file))


def is_born(raw_path: str) -> bool:
    """git이 아는 문서면 True. 판정 실패는 전부 False(=arm 쪽)로 fail-open (§8).

    `git add`만 된 문서도 태어난 것으로 본다 — 저자가 리포에 넣기로 이미 결정했다는 뜻.
    """
    if not raw_path:
        return False
    try:
        cp = subprocess.run(
            ["git", "ls-files", "--error-unmatch", "--", raw_path],
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
        return "out-of-scope"
    body = _read_body(state_file)
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
    return _compose(body, keys, attempts(body))


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
    return _compose(body, keys, att)


def mark_reviewed(state_file: Path, raw_path: str) -> bool:
    """verdict 시점 기록: armed_paths 추가 + dispatch_attempts 항목 삭제 (§5.2).

    완료된 리뷰는 시도 이력을 남길 이유가 없고, 남기면 다음 계산과 skip_reason에 섞인다.
    """
    key = canonical_key(raw_path)
    if key is None:
        return False
    body = _read_body(state_file)
    if not body:
        body = f"---\nsession_id: {state_file.parent.name}\n---\n\n"
    keys = armed_keys(body)
    if key not in keys:
        keys.append(key)
    att = attempts(body)
    att.pop(key, None)
    try:
        state_file.parent.mkdir(parents=True, exist_ok=True)
        state_file.write_text(_compose(body, keys, att), encoding="utf-8")
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


def _usage() -> int:
    print(
        "usage: arm_ledger.py {strip-pending|mark-reviewed} <sid> <raw_path>\n"
        "       arm_ledger.py check-born <raw_path>",
        file=sys.stderr,
    )
    return 2


def main(argv: list[str]) -> int:
    if os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1":
        print(
            "[spec-distill] arm_ledger: DEVBREW_DISABLE_SPEC_DISTILL=1 — no-op",
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
