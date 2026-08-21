"""codex_prompt_common.py — codex 프롬프트 빌더들이 공유하는 stdout 가드 + P21 로더.

정본화 이전 이력: 같은 stdout 인코딩 가드와 같은 P21(신뢰불가 입력 프리앰블) 로더가 네
곳에 따로 있었다 — quality-gates 의 `build_codex_prompt.py`·`build_artifact_codex_prompt.py`,
spec-distill 의 `build_spec_codex_prompt.py`·`build_brief_codex_prompt.py`. 주석까지
바이트 단위로 같았다. P21 은 **보안 컨트롤**이라 네 벌로 두면 한 곳만 고쳤을 때 나머지
셋이 조용히 옛 문구를 계속 내보낸다 — 그 실패는 프롬프트 안에서만 보이므로 관측되지
않는다.

**배포는 심볼릭 링크가 아니라 물리 사본(`# copy-of:`)이다.** 아래 `P21_PREAMBLE_PATH`
는 이 모듈 파일의 **형제**를 가리키는데, 링크로 배포하면 `.resolve()` 가 링크를 따라가
그 형제가 `shared/codex/` 로 해석된다. 그리고 `shared/` 는 설치본에 실리지 않는다(실측)
— 리포에서는 통과하고 **설치본에서만** P21 이 빠진 프롬프트가 나가는, 관측되지 않는
실패가 된다. 사본을 만드는 법은 형제 정본(`codex_jsonl.py`)과 같다:
`{ echo "# copy-of: shared/codex/codex_prompt_common.py"; cat <이 파일>; }`.

**import 전용이다 — 실행 지점(`if __name__`)을 두지 않는다.**
`shared/tests/test_copy_of_contract.sh` 축 1c(import 형제 사본의 ∀ 도미넌스)의 분류기가
실행 지점이 있는 파일을 집합에서 떨어뜨린다. 떨어지면 이 모듈의 형제 ∀ 계약이 조용히
소멸하고, 배포 지점 하나에서 사본이 사라져도 아무것도 RED 가 되지 않는다.

**import 부수효과로 stdout 을 건드리지 않는다.** 인코딩 고정은 `configure_stdout()` 로
노출하고 호출자가 명시적으로 부른다 — import 만으로 프로세스 전역 상태가 바뀌면 그
사실이 호출부에서 안 보인다.
"""

from __future__ import annotations

import pathlib
import re
import sys

# P21 프리앰블은 **형제 파일** `scripts/prompt-preamble.md` 에서 읽는다 — 그 경로는
# `shared/codex/prompt-preamble.md`
# 를 가리키는 상대 심볼릭 링크이고, 설치 시점에 실제 내용으로 역참조되어 배포 트리 안으로
# 들어온다(설계 §2.2·§16.1). 런타임에 `shared/` 로 나가지 않는다 — `${CLAUDE_PLUGIN_ROOT}`
# 에서 그곳은 도달 불가다(§2.1).
# 〔앵커 주의〕 위 `scripts/prompt-preamble.md` 리터럴은 이 사본이 사는 플러그인을
# `shared/tests/test_copy_of_contract.sh` 축 1a 의 **참조원 도출**에 넣는 문자열이기도
# 하다. 표기를 바꾸면 그 플러그인이 심볼릭 링크 ∀ 집합에서 조용히 빠진다(실측: 이
# 통합이 빌더에서 같은 리터럴을 걷어냈을 때 spec-distill 이 도출 3건→2건으로 이탈했다).
P21_PREAMBLE_PATH = pathlib.Path(__file__).resolve().parent / "prompt-preamble.md"
P21_MARKER_RE = re.compile(r"^[ \t]*<!--.*-->[ \t]*$")


def configure_stdout() -> None:
    """stdout 을 UTF-8 로 고정한다. 빌더가 모듈 최상단에서 명시적으로 부른다.

    stdout 인코딩은 프로세스 locale/PYTHONIOENCODING을 따른다(파일 읽기 쪽의 명시적
    encoding="utf-8"과 달리) — 고정하지 않으면 템플릿의 em dash·한국어가 ascii 계열
    인코딩에서 UnicodeEncodeError로 프로세스를 죽인다. reconfigure는 TextIOWrapper에만
    있고 sys.stdout을 채울 수 있는 모든 객체에 있지는 않으므로 형제 관용구(둘 다
    plugins/spec-distill/ 하위 — review-dispatch.py 모듈 최상단의 stdin/stdout/stderr
    reconfigure 루프, check_verbatim_coverage.py의 main()이 쓰는 stdout/stderr guard)와
    같이 guard한다. 단 그 둘이 잡는 예외 클래스가 서로 다르다(전자 AttributeError·OSError,
    후자 AttributeError·ValueError) — 닫힌 TextIOWrapper는 ValueError를 낸다(실측)로
    여기서는 합집합을 잡는다.
    """
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
    except (AttributeError, OSError, ValueError):
        pass


def load_p21_preamble() -> str:
    """정본을 읽어 HTML 주석 줄을 뺀 본문을 낸다. 실패는 삼키지 않는다 — 보안 컨트롤이라
    조용히 빠진 프롬프트는 빠졌다는 사실조차 남기지 않는다(호출자가 rc=2 로 죽는다)."""
    lines = P21_PREAMBLE_PATH.read_text(encoding="utf-8").splitlines()
    return "\n".join(x for x in lines if not P21_MARKER_RE.match(x)).strip("\n")
