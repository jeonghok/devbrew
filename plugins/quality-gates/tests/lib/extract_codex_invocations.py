#!/usr/bin/env python3
"""extract_codex_invocations.py — codex 호출부 **후보 수집기**.

이 파일은 원래 마크다운 agent 파일에서 invocation 줄을 뽑아 grep으로 플래그를
검사하는 파서였다. 겨냥하던 `agents/codex-reviewer.md`가 v1.32.0에 삭제되면서
죽었고, `:21-27`이 마크다운 fence만 읽어 `.sh`에서는 애초에 0건이었다.

**역할이 바뀐다: 판정이 아니라 후보 수집이다.**

계약을 정적으로 읽는 것은 포기했다(설계 §9 R10) — 셸이 `codex exec`를 쓸 수 있는
형태를 열거할 수 없고, 열거 자체가 "열거 금지"와 충돌하며, 앵커를 변수 이름에
묶으면 피검자가 그것을 통제한다. 판정은 `test_sandbox_enforced.sh`(샌드박스
플래그)와 `test_codex_invocation_contract.sh`(argv 계약 전반)가 **실행 관측**으로
한다.

그래서 이 수집기가 놓친 호출부는 *"잘못된 통과"*가 아니라 *"검사되지 않음"*이다.
그 구분이 결정적이다 — 이 파일은 커버리지를 주장하지 않는다.

소비자는 둘이다. `test_sandbox_enforced.sh` — 그 테스트가
`tests/lib/codex_observation.sh`의 `codex_candidates()`(bash, 독립 구현)와 이
파일이 같은 후보 집합을 내는지 매 실행마다 확인한다(standing assertion). 둘이
같은 앵커를 쓴다는 주장이 1회성 수동 diff로만 검증되던 것을 고정한 것이다 —
갈라지면 다음 실행에서 바로 RED. 그리고 `shared/tests/test_runner_disposition.sh:37`
— 러너의 처분 공시를 검사할 모집단을 여기서 가져간다(모집단을 신설하지 않는다).

Usage: extract_codex_invocations.py <root_dir>
Stdout: 후보 파일 경로, 한 줄에 하나, 정렬됨.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# 명령 위치 = 줄머리이거나 공백 뒤. 따옴표 바로 뒤(문자열 리터럴 내부)는 아니다.
# `tests/lib/codex_observation.sh`의 OBS_INVOKE와 **같은 앵커**다 — 두 곳이 다른
# 앵커를 쓰면 커버리지가 조용히 갈라진다.
INVOKE = re.compile(r"(^|\s)codex\s+exec\s")
COMMENT = re.compile(r"^\s*#")

SKIP_DIRS = {".git", "node_modules", "__pycache__", ".claude"}


def has_live_invocation(path: Path) -> bool:
    """**비-주석** 줄에 호출이 있는가.

    주석에만 있는 파일(검사 스크립트·문서)은 실행 대상이 아니다. 실측: 이 필터가
    `test_sandbox_enforced.sh`와 이 파일 자신을 정확히 걸러낸다.
    """
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return False
    return any(INVOKE.search(line) and not COMMENT.match(line)
               for line in text.splitlines())


def collect(root: Path) -> list[str]:
    # 확장자 필터는 두지 않는다. `codex_candidates()`(bash 쪽 수집기,
    # tests/lib/codex_observation.sh)는 확장자로 거르지 않고 `plugins/` 트리
    # 전체를 grep한다 — 애초에 파서를 되살리는 이유가 그 bash 수집기와 같은
    # 후보 집합을 내는 것이므로(위 docstring), 여기서 확장자로 좁히면 그
    # 목적과 정면으로 어긋난다. bash 쪽을 손대는 대신(이 태스크의 수정 대상
    # 밖) 이쪽을 bash에 맞춰 "필터 없음"으로 정렬했다 — 실측(SKIP_DIRS 아래
    # 주석 참고)으로 이 트리에서는 확장자 제한 유무가 후보 집합을 바꾸지
    # 않지만, 원리상 필터가 있으면 향후 비-`.sh/.py/.md/.mjs/.js` 파일에
    # 실제 invocation이 생겨도 이 수집기만 놓치는 조용한 갈라짐이 가능했다.
    #
    # SKIP_DIRS는 그대로 둔다 — bash 쪽도 이 디렉토리들을 명시적으로 거르진
    # 않지만(`.git`은 plugins/ 아래 있을 수 없고, `node_modules`·`__pycache__`는
    # 이 리포에 없음을 확인함), `.claude/`는 각 플러그인의 git-ignore된 세션
    # 상태 디렉토리(수백 개의 per-session state 파일)라 소스가 아니다 — 실측으로
    # 그 안에 codex invoke 패턴이 없음을 확인했다. 만약 미래에 그 가정이 깨지면(즉
    # `.claude/` 안에 실제 invocation이 생기면) 두 수집기의 standing assertion이
    # 곧바로 이 괴리를 RED로 잡는다 — 조용히 통과하지 않는다.
    out = []
    for p in root.rglob("*"):
        if not p.is_file() or p.is_symlink():
            # 알려진 공백 — **심볼릭 링크로 배포된 러너는 모집단에 안 든다.**
            # `shared/docreview/scripts/run_docreview_codex_reviewer.sh` 가 그것이다:
            # 정본은 `shared/` 라 스캔 root(`plugins`) 밖이고, 두 플러그인의 사본
            # (`plugins/{quality-gates,spec-distill}/scripts/`)은 링크라 여기서 걸러진다.
            # 그래서 `test_sandbox_enforced.sh`(codex 격리의 유일한 기둥 `-s read-only`
            # 를 실행 관측으로 집행)와 `test_runner_disposition.sh`(처분 공시)가 이 러너를
            # 한 번도 안 본다 — 잘못된 통과가 아니라 **검사되지 않음**이다.
            # 고칠 때: 그 러너에 첫 호출자가 생기는 PR 2. 링크가 완성되는 때가 아니라
            # 실제로 codex 를 태우기 시작하는 때가 위험 창이 열리는 때다. 이 skip 을
            # 건드리는 것은 보안 락의 모집단을 바꾸는 일이라 그때 한 번에 판단한다.
            continue
        # **스캔 root 기준 상대 경로**로만 판정한다. 절대 경로 성분을 보면 root의
        # *조상*에 있는 디렉토리 이름까지 걸린다 — devbrew의 워크트리 관례가
        # `<repo>/.claude/worktrees/<name>` 이라 모든 워크트리 실행에서 `.claude`가
        # 조상으로 걸려 트리 전체가 통째로 prune됐다(python 수집기 0건 vs bash 6건).
        # 그 결과 아래 standing assertion이 워크트리에서 상시 RED였고, 이 락은 이
        # 리포의 표준 격리 워크플로에서 한 번도 이빨을 쓰지 못했다(2026-08-23 실측).
        # root 안쪽의 `plugins/<x>/.claude`(실재 — 3곳)를 거르는 원래 의도는 그대로다.
        if SKIP_DIRS & set(p.relative_to(root).parts):
            continue
        if has_live_invocation(p):
            out.append(str(p))
    return sorted(out)


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <root_dir>", file=sys.stderr)
        return 2
    root = Path(sys.argv[1])
    if not root.is_dir():
        print(f"not a directory: {root}", file=sys.stderr)
        return 2
    for line in collect(root):
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
