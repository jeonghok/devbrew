#!/usr/bin/env python3
"""spec-distill PostToolUse hook — Layer 1 structural validator.

- Reads PostToolUse JSON payload from stdin.
- Filters: tool must be Write/Edit/MultiEdit on a `.md` under docs/superpowers/specs/
  (sub-folder hierarchy 포함).
  Mode: `-spec.md` → spec; `-design.md` → design; other `.md` → spec if its
  frontmatter block has a `locked_decisions` key, else design.
  Out-of-scope paths exit 0 silently.
- spec mode: 11 sections + frontmatter + locked_decisions + ambiguity scan.
- design mode: ambiguity + placeholder scan only.
- On pass: writes `pending_review:` block to .claude/spec-distill/<session>/state.local.md.
- On fail: exit 2 + stderr; stdout `{"decision": "block", "reason": "..."}` for safety.

Kill switches:
- DEVBREW_SPEC_DISTILL_DISABLE=1
- DEVBREW_SKIP_HOOKS=spec-distill:PostToolUse  (or :validator)
- DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1  (Layer 1 only; skip state write)
- DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1  (skip design.md)
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


# 표준 스트림을 UTF-8 로 고정한다 (v0.25.0). `read_text(encoding="utf-8")` 와 달리
# stdin 디코딩은 **프로세스 locale** 을 따르므로, LC_ALL=C 환경에서 훅 payload 의
# 한국어(UserPromptSubmit 의 user prompt, PostToolUse 의 문서 내용)가
# UnicodeDecodeError 로 훅을 죽인다 — 이 플러그인이 [0.24.4] 에서 이미 겪은 실패다.
# except 절을 늘려 열거하는 대신 클래스 자체를 없앤다 (check_verbatim_coverage.py 와 동일 패턴).
for _s in (sys.stdin, sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
    except (AttributeError, OSError):
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
SCRIPTS_DIR = SCRIPT_DIR.parent / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))
from state_path import state_root as _state_root  # noqa: E402
from kill_switch_active import kill_switch_active  # noqa: E402
PARSE_LIB = SCRIPT_DIR.parent / "scripts" / "parse_spec_structure.py"
BLACKLIST = SCRIPT_DIR.parent / "scripts" / "ambiguity-blacklist.txt"

PATH_PREFIX = "docs/superpowers/specs/"

# arm_ledger 와 같은 패턴이지만 의도적으로 로컬이다. 이 플러그인은 이미
# review-dispatch.py·pending-review-reminder.py·arm_ledger.py
# 세 곳에서 이 정규식을 각자 정의한다 — 새 중복이 아니라 기존 관례.
PENDING_RE = re.compile(r"^pending_review:\n(?:  [^\n]*\n)*", re.MULTILINE)


def _frontmatter_has_locked_decisions(file_path: str) -> bool:
    """첫 ---...--- frontmatter 블록 안에 locked_decisions 키가 있으면 True.

    body의 locked_decisions 언급은 무시. 닫는 ---가 없는 unclosed frontmatter는
    유효 블록이 아니므로 False. 읽기/디코드 실패는 False + loud stderr (caller가
    design으로 매핑)."""
    try:
        text = Path(file_path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(
            f"[spec-distill] resolve_mode content-peek failed for {file_path}: {exc}",
            file=sys.stderr,
        )
        return False
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return False  # frontmatter 블록 없음
    block: list[str] = []
    closed = False
    for line in lines[1:]:
        if line.strip() == "---":
            closed = True
            break
        block.append(line)
    if not closed:
        return False  # unclosed frontmatter → spec marker로 인정 안 함
    return any(re.match(r"\s*locked_decisions\s*:", b) for b in block)


def resolve_mode(file_path: str) -> Optional[str]:
    """Return 'spec', 'design', or None (not in scope)."""
    if PATH_PREFIX not in file_path:
        return None
    if not file_path.endswith(".md"):
        return None
    if file_path.endswith("-spec.md"):
        return "spec"
    design_disabled = (
        os.environ.get("DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE") == "1"
    )
    if file_path.endswith("-design.md"):
        return None if design_disabled else "design"
    # suffix 없는 임의 .md — content-aware
    if _frontmatter_has_locked_decisions(file_path):
        return "spec"
    return None if design_disabled else "design"


def call_parser(sub: str, *args: str) -> dict:
    try:
        cp = subprocess.run(
            ["python3", str(PARSE_LIB), sub, *args],
            capture_output=True, text=True, check=False,
            timeout=10,
        )
    except (FileNotFoundError, OSError, subprocess.TimeoutExpired) as exc:
        return {"_error": f"parser failure: {exc}"}
    if cp.returncode != 0:
        return {"_error": cp.stderr.strip() or f"parser rc={cp.returncode}"}
    try:
        return json.loads(cp.stdout)
    except json.JSONDecodeError as e:
        return {"_error": f"parser bad json: {e}"}


LEGACY_ADVISORY_MARKER = ".legacy-advisory-emitted-v060"


def _legacy_advisory_check(state_root_path: Path) -> None:
    """AC14 — emit one-shot advisory if `.claude/spec-distill/default/` exists."""
    legacy = state_root_path / "default"
    marker = state_root_path / LEGACY_ADVISORY_MARKER
    if not legacy.exists() or marker.exists():
        return
    try:
        state_root_path.mkdir(parents=True, exist_ok=True)
        marker.write_text("")
        print(
            "[spec-distill] v0.6.0 detected: .claude/spec-distill/default/ "
            "legacy folder, manual cleanup recommended (no auto-delete to "
            "preserve in-flight work — see CHANGELOG [0.6.0]).",
            file=sys.stderr,
        )
    except OSError as exc:
        print(
            f"[spec-distill] legacy advisory marker write failed: {exc}",
            file=sys.stderr,
        )


def unkeyable(path: str) -> bool:
    """이 경로가 원장 키가 될 수 없는가. 판정은 `canonical_key` **하나에만** 존재한다.

    writer 와 reader 가 서로 다른 문자 집합을 거부하면 그 차집합이 통째로 G6 상한
    밖으로 샌다 — pending 은 쓰이는데 원장엔 기록될 수 없어 `dispatch_attempts` 가
    영원히 오르지 않고, 그 문서는 편집할 때마다 재발동한다(무한 루프).

    여기 도달한 경로는 항상 스코프 안이다: `resolve_mode` 가 `PATH_PREFIX` 를 요구하고
    그 값은 `arm_ledger.PREFIX` 와 같다(test_arm_ledger.py `TestPrefixContract`). 따라서
    `canonical_key` 의 `None` 은 오직 "제어문자라 키를 만들 수 없음"만 뜻하며,
    "스코프 밖"과 뭉개지지 않는다 — 그 등식이 깨지면 스코프 밖 문서의 pending 기록이
    조용히 죽으므로 락이 필수다.

    모듈을 못 읽으면 같은 규칙을 로컬에서 재현한다.

    **`except Exception` 이어야 한다 — `ImportError` 만으로는 부족하다.** 위 arm 게이트는
    같은 모듈을 `except Exception` 으로 감싸 degrade 하는데, 여기서 좁게 잡으면 게이트가
    우아하게 넘긴 실패(`SyntaxError` — 머지 충돌 마커·부분 write, `state_path` import 가
    던지는 `OSError`, 모듈 레벨 `TypeError`)가 세 줄 뒤 writer 에서 치명적으로 다시
    터진다. 그러면 rc≠0 에 stdout 이 비어 pending 도 advisory 도 없다 — HEAD 에서는
    정상 arm 되던 입력이다. 기존 회귀 락은 `sys.modules` 에 `None` 을 주입하는데 그건
    정확히 `ImportError` 라, fail-open 이 깨진 채로 "fail-open 동작함" 을 통과시킨다.

    **fallback 은 `canonical_key` 와 같은 범위를 봐야 한다.** `canonical_key` 는
    PREFIX 이후(`path[idx:]`)만 검사한다. 경로 전체를 검사하면 디렉토리 이름의 NBSP·탭
    (POSIX 에서 합법이고 키에는 들어가지도 않는다)에서 모듈 유무에 따라 정반대 판정이
    나고, 그 방향이 하필 fail-**closed**(리뷰 포기)다 — 이 릴리스의 다른 모든 degrade 와
    반대다.
    """
    idx = path.find(PATH_PREFIX)
    key = path[idx:] if idx >= 0 else path
    try:
        import arm_ledger  # pyright: ignore[reportMissingImports]
    except Exception:  # noqa: BLE001 — arm 게이트와 같은 폭이어야 한다(위 docstring)
        return (len(key.splitlines()) != 1
                or any(c in key for c in "\n\r\t\x00")
                or not key.isprintable())
    return arm_ledger.canonical_key(path) is None


def write_state(
    session_id: str, path: str, mode: str, worktree_path: str
) -> Optional[str]:
    """기록 성공이면 None, 실패면 **사유 sentinel**(ARM_SKIP_REASONS 키).

    호출부는 이 값을 반드시 소비해야 한다 — 실패인데 성공 advisory 를 내보내면 모델은
    오지 않을 리뷰를 기다린다(Law 1 게이트가 조용히 꺼진 것과 같다).

    bool 이 아니라 사유를 싣는 이유: 실패 경로가 셋이고 사용자가 취할 행동이 서로
    다르다(파일명 변경 / 상태 파일 복구). 하나로 뭉개면 "결과를 정직하게 보고한다"는
    이 수정의 목적을 사유 층에서 다시 어긴다.
    """
    # 신뢰할 수 없는 `tool_input.file_path` 가 마크다운 상태 파일에 그대로 보간되는
    # 지점이다. 개행이 든 경로는 0-indent 로 `armed_paths:` 블록을 위조해 **다른**
    # 문서의 리뷰를 영구 억제할 수 있다. **writer 에서 막는 것이 요점** — reader 마다
    # 걸러내면 새 reader 가 생길 때마다 두더지잡기가 된다(이 리포가 겪은 실패 모드).
    if unkeyable(path):
        print(
            "[spec-distill] file_path 에 제어문자가 있어 pending 기록을 건너뛴다 "
            "(원장 위조 방지). 이 경로는 자동 리뷰가 붙지 않는다 — 파일명을 바꿔라.",
            file=sys.stderr,
        )
        return "unkeyable-path"
    state_dir = _state_root() / session_id
    state_dir.mkdir(parents=True, exist_ok=True)
    _legacy_advisory_check(_state_root())
    state_file = state_dir / "state.local.md"
    block = (
        "pending_review:\n"
        f"  path: {path}\n"
        f"  mode: {mode}\n"
        f"  worktree_path: {worktree_path}\n"
        f"  triggered_at: {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}\n"
    )
    # `path` 말고 `mode`·`worktree_path` 도 같은 위조 능력을 가진다(후자는 os.getcwd()
    # 이고 POSIX 디렉토리명엔 개행이 허용된다). 값마다 술어를 늘리는 대신 **완성된
    # 블록**을 reader 와 같은 함수로 센다 — `armed_paths` 를 읽는 쪽은 `splitlines()`
    # 를 쓰고, 그건 `\n` 뿐 아니라 U+2028·U+0085·\x0b 등 universal-newline 전체에서
    # 쪼갠다. `\n` 만 세면 그 차집합이 그대로 위조 통로가 된다.
    if len(block.splitlines()) != 5:
        print(
            "[spec-distill] pending 블록에 예상 밖 줄 경계가 있어 기록을 건너뛴다 "
            "(원장 위조 방지). 자동 리뷰가 붙지 않는다.",
            file=sys.stderr,
        )
        return "unsafe-state-value"
    # 줄 경계만으로는 부족하다. `os.getcwd()` 는 디코딩 불가 바이트를 surrogateescape
    # (U+DC80–U+DCFF 대역)로 담아 돌려줄 수 있고, 그런 문자열은 줄 경계가 정상
    # (splitlines == 5)이면서 `write_text(encoding="utf-8")` 에서 **UnicodeEncodeError**
    # 를 던진다. 그건 `ValueError` 하위이지 `OSError` 가 **아니므로** 호출부의
    # `except (PermissionError, OSError)` 를 그대로 통과해 훅을 죽인다 — 이 플러그인이
    # 읽기 쪽에서 이미 겪은 `UnicodeDecodeError` ⊄ `OSError` 의 쓰기 쪽 쌍이다.
    # 게다가 세 번째 write 경로는 기존 파일에 쓰므로, 인코딩 실패가 write 도중 나면
    # 살아있는 상태 파일이 잘려 나갈 수 있다.
    try:
        block.encode("utf-8")
    except UnicodeEncodeError as exc:
        print(
            f"[spec-distill] pending 블록을 UTF-8 로 인코딩할 수 없어 기록을 "
            f"건너뛴다 (자동 리뷰 미발동): {exc}",
            file=sys.stderr,
        )
        return "unsafe-state-value"
    if not state_file.exists():
        state_file.write_text(
            f"---\nsession_id: {session_id}\n---\n\n{block}", encoding="utf-8"
        )
        return None
    # File exists — detect stale session_id (AC8 defensive truncate)
    try:
        body = state_file.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError) as exc:
        print(
            f"[spec-distill] state.local.md unreadable — preserving for debug: {exc}",
            file=sys.stderr,
        )
        return "state-unreadable"
    fm_match = re.search(r"^session_id:\s*([^\n]+)$", body, flags=re.MULTILINE)
    if fm_match and fm_match.group(1).strip() != session_id:
        old = fm_match.group(1).strip()
        print(
            f"[spec-distill] stale state detected (old sid={old[:32]}, "
            f"current={session_id[:32]}) — truncating",
            file=sys.stderr,
        )
        state_file.write_text(
            f"---\nsession_id: {session_id}\n---\n\n{block}", encoding="utf-8"
        )
        return None
    # Matching session_id (or no frontmatter — backward compat per AC8 case iii)
    # — strip pending_review block and append fresh
    # "pending_review 블록은 정확히 하나" 는 모듈 가용성과 무관하게 성립해야 한다.
    # 두 블록이 생기면 Stop 이 첫 블록(다른 문서)을 소비하고 rewrite_state 의 전역
    # re.sub 가 방금 arm 된 문서의 트리거까지 지운다 — 오류 없는 under-review.
    body = PENDING_RE.sub("", body)
    state_file.write_text(body.rstrip() + "\n\n" + block, encoding="utf-8")
    return None

def emit_block(reasons: list[str]) -> None:
    print(
        json.dumps({"decision": "block", "reason": "\n".join(reasons)}),
        flush=True,
    )
    for r in reasons:
        print(f"[spec-distill] {r}", file=sys.stderr)


ARM_SKIP_REASONS = {
    "reviewed": "이 세션에서 리뷰가 이미 완료됨 (arm-once)",
    "capped": (
        "리뷰가 3회 시도됐으나 verdict 없이 끝나 자동 dispatch를 중단함 (G6 상한) "
        "— 리뷰가 필요하면 reviewing-spec을 직접 호출하라"
    ),
    "born": "git이 아는 문서 — 커밋 이후에는 자동 리뷰가 붙지 않는다",
    "out-of-scope": "스코프 밖 경로",
    # arm 은 통과했는데 **기록**에 실패한 경우들. arm-skip 과 원인이 다르지만 사용자가
    # 알아야 할 사실은 같다 — "이 편집에는 리뷰가 붙지 않는다". 이 두 사유가 없으면
    # 호출부가 성공 advisory 로 흘러 모델에게 오지 않을 리뷰를 약속한다.
    "unkeyable-path": (
        "파일명에 제어문자가 있어 리뷰 키를 만들 수 없다 — 자동 리뷰가 붙지 않는다. "
        "파일명을 바꾸고 다시 저장하라"
    ),
    "unsafe-state-value": (
        "상태 값에 줄 경계 문자가 있어 기록을 거부했다 — 자동 리뷰가 붙지 않는다. "
        "작업 디렉토리 이름을 확인하라"
    ),
    "state-unreadable": (
        "state.local.md 판독 불가로 기록하지 못했다(파일은 보존) "
        "— 복구하거나 reviewing-spec을 직접 호출하라"
    ),
    "state-write-failed": (
        "상태 기록에 실패해 자동 리뷰가 발동하지 않았다 "
        "— 리뷰가 필요하면 reviewing-spec을 직접 호출하라"
    ),
    "session-unresolved": (
        "세션 id를 해석하지 못해 자동 리뷰가 발동하지 않았다 "
        "— DEVBREW_SPEC_DISTILL_SESSION_ID를 지정하거나 reviewing-spec을 직접 호출하라"
    ),
    "autoreview-disabled": (
        "DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1 이라 자동 리뷰를 건너뛴다 "
        "(구조 검증은 그대로 수행됨)"
    ),
}


def emit_arm_skip_advisory(mode: str, key: str, reason: str) -> None:
    """v0.25.0 — arm-once 게이트가 arm을 건너뛸 때의 advisory.

    기존 'Reviewer will be dispatched' 출력을 *교체*한다(이중 방출 금지). 사유를
    구분해 표시하는 것이 요건이다 — 'reviewed'와 'capped'는 둘 다 armed_paths에
    있지만 사용자가 취해야 할 행동이 다르다(전자는 정상, 후자는 수동 호출 필요).
    """
    why = ARM_SKIP_REASONS.get(reason, reason)
    text = f"[spec-distill] {key} arm skipped — {why}."
    print(
        json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": text,
            },
            "systemMessage": f"[spec-distill] {mode} arm skipped ({reason}) for {key}",
        }),
        flush=True,
    )
    print(text, file=sys.stderr)


def main() -> int:
    if kill_switch_active("spec-distill", "validator", "PostToolUse"):
        return 0
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError, OSError) as exc:
        # arm 지점이라 가장 넓게 잡는다 — 여기서 죽으면 Law 1 게이트 자체가 안 걸린다.
        #
        # 하지만 **넓게 잡는 것과 조용히 죽는 것은 다르다.** HEAD 에서는
        # `json.JSONDecodeError` 만 잡았으므로 stdin I/O 오류(`OSError` 및 그 하위
        # `BlockingIOError`·`InterruptedError`·`io.UnsupportedOperation`)는 traceback
        # 으로 터져 최소한 사용자 눈에 보였다. 절을 넓히면서 그것들이 rc 0 + 무출력이
        # 됐다 — arm 이 안 걸린 채 문서가 통과하는데 아무 흔적이 없다. 형제 두 훅은
        # 같은 릴리스에서 loud advisory 를 받았고 이 파일만 빠졌다.
        # CLAUDE.md: graceful degradation은 **loud logging 을 동반**해야 한다.
        print(f"[spec-distill] payload 판독 실패 — arm 건너뜀: {exc}", file=sys.stderr)
        print(
            json.dumps({
                "hookSpecificOutput": {
                    "hookEventName": "PostToolUse",
                    # 아는 것만 말한다. payload 를 못 읽었으므로 이번 도구 호출이
                    # 애초에 스코프 안(spec/design 편집)이었는지조차 알 수 없다 —
                    # "리뷰가 안 붙는다"고 단정하면 그 자체가 근거 없는 주장이다.
                    "additionalContext": (
                        "[spec-distill] arm-once:validator-payload-unreadable — "
                        "훅 payload 를 읽지 못해 구조 검증과 자동 리뷰 arm 이 실행되지 "
                        "않았다. 방금 편집이 spec/design 문서였다면 이번에는 리뷰가 "
                        "발동하지 않는다."
                    ),
                },
            }),
            flush=True,
        )
        return 0  # graceful degradation; not our payload
    tool_name = payload.get("tool_name", "")
    if tool_name not in ("Write", "Edit", "MultiEdit"):
        return 0
    file_path = payload.get("tool_input", {}).get("file_path", "")
    mode = resolve_mode(file_path)
    if mode is None:
        return 0  # out of scope

    # Layer 1 mechanical checks
    reasons: list[str] = []
    if mode == "spec":
        fm = call_parser("frontmatter", file_path)
        if not fm or "name" not in fm:
            reasons.append("spec mode: missing or invalid frontmatter")
        ld = call_parser("locked-decisions", file_path)
        if ld.get("errors"):
            reasons.append("locked_decisions errors: " + "; ".join(ld["errors"]))
        secs = call_parser("sections", file_path)
        missing = secs.get("missing", [])
        if missing:
            reasons.append(f"missing sections: {missing}")

    amb = call_parser("ambiguity", file_path, str(BLACKLIST))
    for hit in amb.get("hits", []):
        reasons.append(
            f"ambiguity hit: line {hit['line']} \"{hit['phrase']}\""
        )

    if mode == "design":
        ph = call_parser("placeholders", file_path)
        for hit in ph.get("hits", []):
            reasons.append(
                f"placeholder hit: {hit['token']} at line {hit['line']}"
            )

    if reasons:
        emit_block(reasons)
        return 2

    # Pass → write state (unless Layer 2 disabled)
    #
    # 아래 두 분기(옵트아웃·sid 미해석)도 pending 을 남기지 않는다. 그러면 Stop 훅이
    # 볼 것이 없어 리뷰는 영영 발동하지 않는데, 그대로 흘려보내면 맨 아래 성공
    # advisory 가 "Reviewer will be dispatched" 를 주장한다 — write 실패 분기에서
    # 고친 것과 **같은 거짓말**이고, 이번 라운드에 그 세 줄 위만 고치고 여기를 놔뒀다.
    # stderr 는 대안이 아니다: 같은 릴리스의 review-dispatch.py 가 exit 0 의 stderr 는
    # 전달되지 않는다고 명시한다.
    if os.environ.get("DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW") == "1":
        emit_arm_skip_advisory(mode, file_path, "autoreview-disabled")
        return 0
    from state_path import resolve_session_id
    session_id = resolve_session_id(payload)
    if session_id is None:
        emit_arm_skip_advisory(mode, file_path, "session-unresolved")
        return 0
    if session_id is not None:
            # v0.25.0 arm-once 게이트 (Layer 2). Layer 1 구조 검증은 위에서 이미
            # 실행됐다(G2) — arm이 skip돼도 구조 실패는 exit 2로 차단된다.
            # 판정 실패(모듈 부재·원장 read 실패·git 불능)는 전부 arm 쪽으로
            # fail-open한다 (Law 1: 과리뷰 > under-review). 원장이 1회로 제한하므로
            # storm이 되지 않는다.
            try:
                import arm_ledger  # pyright: ignore[reportMissingImports]
                sfile = arm_ledger.state_file_for(session_id)
                if not arm_ledger.should_arm(sfile, file_path):
                    key = arm_ledger.canonical_key(file_path) or file_path
                    emit_arm_skip_advisory(
                        mode, key, arm_ledger.skip_reason(sfile, file_path))
                    return 0  # arm skip — 기존 advisory 미방출
            except Exception as exc:  # noqa: BLE001 — graceful degradation
                print(
                    f"[spec-distill] arm gate failed "
                    f"(non-fatal, arming normally): {exc}",
                    file=sys.stderr,
                )
            # 기록 결과를 **반드시 소비한다**. arm 판정이 통과해도 기록이 실패하면
            # Stop 훅이 볼 pending 이 없어 리뷰는 영영 발동하지 않는다 — 그런데도 아래
            # 성공 advisory 로 흘러가면 모델은 오지 않을 리뷰를 기다린다. 이 리포가
            # 결함으로 취급하는 "코드보다 많이 주장하는" 모양이고, 방향은 under-review
            # (Law 1 위반) 다. 제어문자 거부(신규)와 write 실패(기존)를 같은 자리에서
            # 막는 이유 — 인스턴스가 아니라 클래스를 닫는다.
            try:
                skip = write_state(session_id, file_path, mode, os.getcwd())
            # `UnicodeError` 를 함께 잡는다 — 인코딩 실패는 `ValueError` 하위라
            # `OSError` 로는 걸리지 않는다. write_state 가 선제 검사하지만, 방어층은
            # 기존 파일에 append 하는 세 번째 write 경로에도 필요하다.
            except (PermissionError, OSError, UnicodeError) as exc:
                print(f"[spec-distill] state write failed (non-fatal): {exc}", file=sys.stderr)
                skip = "state-write-failed"
            if skip is not None:
                # 표시용 키는 repr 로 이스케이프한다 — 제어문자가 든 경로를 그대로
                # 실으면 advisory 자체가 다시 위조 통로가 된다.
                safe_key = (
                    file_path if not unkeyable(file_path) else repr(file_path)[:160]
                )
                emit_arm_skip_advisory(mode, safe_key, skip)
                return 0  # 기록 실패 — 성공 advisory 미방출

    # Advisory output (v0.5.0 dual-target: additionalContext for Claude + systemMessage trace).
    print(
        json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": (
                    f"[spec-distill] {mode} structural OK. "
                    "Reviewer will be dispatched at turn end "
                    "(Stop hook will mandate reviewing-spec skill invocation)."
                ),
            },
            "systemMessage": f"[spec-distill] {mode} OK · reviewer dispatch pending",
        }),
        flush=True,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
