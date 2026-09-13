#!/usr/bin/env python3
"""TTL-based GC for quality-gates per-session state folders.

Triggers (must be explicit, never SessionStart):
  - setup-qg.sh start (auto, fire-and-forget)
  - /qg --gc, /cancel-qg --gc, /cancel-qg --all (user)

Race guard: 3-layer (state root 디렉토리 fd 락 + double-stat ns + rename-then-rmtree).
락 파일은 없다 — 루트 아래 고정 이름 파일은 저장소가 링크로 커밋할 수 있어서 열지 않는다.
루트가 심볼릭 링크를 거쳐 제자리 밖으로 풀리면 락을 잡기 전에 거부하고, 루트 안의 링크
자식은 세션 폴더로 보지 않는다. 두 검사는 `gc_common` 정본의 `root_escapes` · `locked_root` 다.

Kill switches:
  DEVBREW_QUALITY_GATES_DISABLE=1        → no-op.
  DEVBREW_SKIP_HOOKS=quality-gates:qg-gc → no-op (이 스크립트 하나만).

훅이 아니지만 `DEVBREW_SKIP_HOOKS` 토큰으로 지목할 이름을 갖는다 — 이관 전에는
전역 스위치 하나뿐이라 "이 GC만 끈다"가 불가능했다. kill switch 는 opt-out
컨트롤이므로 **더 잘 꺼지는** 방향이고, 회귀는 반대 방향(덜 꺼짐)뿐이다.

TTL override: DEVBREW_QUALITY_GATES_TTL_HOURS (positive int, default 24).
Verbose: DEVBREW_QUALITY_GATES_GC_VERBOSE=1 → print summary line on stdout.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from gc_common import gc_one, locked_root, root_escapes, ttl_ns  # noqa: E402
from kill_switch_active import kill_switch_active  # noqa: E402

ROOT = Path(".claude/quality-gates")
SESSION_PATTERN = re.compile(r"^[A-Za-z0-9_-]{8,}$")
# 이름의 charset만으로는 세션 폴더와 형제 디렉토리를 구분할 수 없다 —
# `worktrees`(9자)·`baseline-cache`(14자)가 위 패턴을 만족한다. 내용으로 식별한다.
#
# denylist({"worktrees", "baseline-cache"} 제외)를 쓰지 않는 이유: 공간에는 맞지만
# **시간에 fail-open**이다. 내일 추가될 형제 디렉토리를 오늘 열거할 수 없다.
# 마커 기반은 반대로 시간에 fail-closed다 — 새 형제 디렉토리는 자동으로 안전하다.
# 오판 방향도 옳다: 안 지우는 누수(빈 디렉토리 0바이트)가 살아있는 것을 지우는
# 것보다 안전하다.
# `pipeline.md`·`publish-eligible.md`는 SKILL.md가 실제로 쓰는 이름이다.
# `runtime-evidence.md`는 Runtime gate의 evidence-log 이름 —
# agents/runtime-verifier.md:98 및 scripts/detect-runtime.sh:286 이
# `.claude/quality-gates/<sid>/runtime-evidence.md`에 직접 쓴다(실재 확인됨).
# 목록에서 빠진 마커의 오판 방향은 "안 지움"(누수)이라 안전하다 — 반대 방향이 아니다.
SESSION_MARKERS = ("pipeline.md", "publish-eligible.md", "runtime-evidence.md")

# 4.x 가 남긴 폴더는 유일한 파일이 `files.md` 인 경우가 있다 — 세션 tracker 가 편집
# 파일을 적었지만 `/qg` 를 한 번도 안 돌린 세션이다. 5.0.0 이 그 생산자를 지워도
# **이미 디스크에 있는 폴더는 남는다**: 위 마커가 하나도 안 맞아 sweep 에서 매번
# `continue` 되고, 기존 사용자 전원에게 영구 누수가 된다. 회수 마커를 따로 둔다.
#
# 이것도 열거지만 CLAUDE.md 가 금하는 열거와 실패 모드가 다르다. 금지되는 열거는
# **미래**에 대해 fail-open 이다 — 내일 추가될 이름을 오늘 적을 수 없다. 이 목록의
# 정의역은 **이미 닫힌 과거**다: 4.x 가 만들 수 있었던 산출물 집합은 확정돼 더
# 늘지 않는다.
#
# 이 이름은 소비자가 아니라 **회수 마커**다 — 파일을 열지도, 내용을 읽지도 않고
# 폴더를 세션 폴더로 식별하는 데만 쓴다(그래서 tracker 부활의 발판이 아니다).
# 4.x 잔여가 전부 TTL 을 지나간 뒤 지운다.
LEGACY_SESSION_MARKERS = ("files.md",)

# TTL 계산 · 나이 판정 · 안전 삭제 · 루트 안전 검사(탈출 판정 · 루트 디렉토리 락)는
# `shared/gc/gc_common.py` 정본(형제 사본 `scripts/gc_common.py`)이 갖는다. 여기 남는 것은
# quality-gates 고유 본문이다 — state root 표기(`ROOT`)와 세션 폴더 **식별**
# (`SESSION_MARKERS`, 위 주석의 이유). spec-distill 의 GC 에는 마커 식별이 아예 없다(패턴만
# 본다). 두 계약이 다르므로 이 둘은 통합 대상이 아니다 — **왜** 다른지는 여기서 판정하지 않는다.


def _is_session_folder(folder: Path) -> bool:
    try:
        return any((folder / name).is_file()
                   for name in SESSION_MARKERS + LEGACY_SESSION_MARKERS)
    except OSError:
        return False


def _verbose() -> bool:
    return os.environ.get("DEVBREW_QUALITY_GATES_GC_VERBOSE") == "1"


def gc(self_session_id: str | None = None) -> int:
    if kill_switch_active("quality-gates", "qg-gc") or not ROOT.exists():
        return 0
    if root_escapes(ROOT, "quality-gates"):
        print(
            f"[quality-gates] GC 거부 — state root '{ROOT}' 가 심볼릭 링크를 거쳐 "
            f"'{os.path.realpath(ROOT)}' 로 풀린다. 저장소 밖을 지울 수 있어 건너뛴다.",
            file=sys.stderr,
        )
        return 0
    ttl = ttl_ns("DEVBREW_QUALITY_GATES_TTL_HOURS")
    removed = 0
    with locked_root(ROOT, "quality-gates") as held:
        if not held:
            return 0
        for child in ROOT.iterdir():
            if child.is_symlink() or not child.is_dir():
                continue
            if not SESSION_PATTERN.match(child.name):
                continue
            # 이름 + 내용 **둘 다** 만족해야 sweep — 두 조건의 교집합이
            # 단독보다 좁다. 패턴을 지우지 않고 함께 유지하는 이유가 이것이다.
            if not _is_session_folder(child):
                continue
            if self_session_id and child.name == self_session_id:
                continue
            try:
                if gc_one(child, ttl, ROOT):
                    removed += 1
            except OSError as exc:
                print(
                    f"[quality-gates] GC failed on {child.name}: {exc}",
                    file=sys.stderr,
                )
    if _verbose() and removed > 0:
        print(f"[quality-gates] GC: removed {removed} stale session folder(s)")
    return removed


def main() -> int:
    self_id = os.environ.get("CLAUDE_CODE_SESSION_ID") or None
    args = sys.argv[1:]
    if "--session-id" in args:
        i = args.index("--session-id")
        if i + 1 < len(args):
            self_id = args[i + 1]
    gc(self_id)
    return 0


if __name__ == "__main__":
    sys.exit(main())
