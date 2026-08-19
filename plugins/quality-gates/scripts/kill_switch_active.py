# copy-of: shared/killswitch/kill_switch_active.py
"""devbrew kill switch 판정 정본.

이 파일이 생기기 전에는 같은 책임이 **열두 곳**에 따로 살았고 본문이 전부 달랐다
(이름도 둘로 갈라져 있었다 — `kill_switch_active` 5곳 · `_disabled` 7곳). 이름이
다르다는 이유만으로 census 스크립트도 두 무리를 잇지 못했다. 드리프트는 가설이
아니라 실측이었다: `plugins/quality-gates/hooks/post-tool-use.py` 는
`DEVBREW_SKIP_HOOKS` 를 콤마 분리 **전체 토큰**으로 대조하는데
`plugins/spec-distill/scripts/spec-distill-gc.py` 는 그 변수를 **아예 읽지 않았다**.
사용자가 껐다고 믿는 스위치가 어떤 지점에서는 무반응이었다.

kill switch 는 보안 컨트롤이다(`CLAUDE.md:48`). 같은 이름의 판정 함수가 여러 뜻을
갖는 것은 *"한 플러그인에서 배운 형태가 다른 곳에서 조용히 안 먹는"* 결함이고,
그 결함의 방향은 언제나 fail-open 이다.

**배포 방식** — 이 모듈은 실행 지점이 없는 import-only 정본이다. 각 플러그인의
`scripts/` 에 `# copy-of:` 마커를 머리에 단 물리 사본으로 실린다(설치본에는
`shared/` 가 없으므로 형제 사본이어야 import 가 풀린다). 사본이 정본과 갈라지지
않는지는 `shared/tests/test_copy_of_contract.sh` 축 1b·1c 가 잰다.

**토큰 정규화는 여기서 하지 않는다** — 대소문자·공백·플러그인 토큰 표기 통일은
별건이다. 여기서는 이관 전 열두 본문이 받아들이던 형태를 전부 받는다(토큰 양끝
공백 제거 + 전체 토큰 일치). 좁히는 방향의 변경은 회귀다.
"""
from __future__ import annotations

import os


def kill_switch_active(plugin: str, hook: str, event: str = "") -> bool:
    """이 훅이 꺼져 있는가.

    두 스위치를 본다 (CLAUDE.md §런타임):
      · DEVBREW_DISABLE_<PLUGIN>=1        — 그 플러그인 전체
      · DEVBREW_SKIP_HOOKS=<plugin>:<tok> — 콤마 구분 목록. tok 은 훅명 **또는** 이벤트명.

    별칭 둘을 다 받는 이유: spec-distill 훅은 이벤트명·훅명 둘 다 받고 project-init 은
    훅명만 받았다. 한 플러그인에서 배운 형태가 다른 곳에서 조용히 안 먹는 것은 결함이며,
    kill switch 는 보안 컨트롤이라(CLAUDE.md:48) 그 결함의 방향이 fail-open 이다.

    **어떤 훅도 자신의 kill switch 존중을 거부할 수 없다.**
    """
    # 전역 스위치의 변수명은 **도출한다** — 플러그인 이름을 열거한 표를 두지 않는다.
    # 표를 두면 새 플러그인이 그 표에 없는 채로 착지해 전역 스위치가 조용히 무반응이
    # 된다(열거는 공간·시간 양쪽으로 fail-open). `-` → `_`, 대문자화가 CLAUDE.md 의
    # `DEVBREW_DISABLE_<PLUGIN>` 관례 그 자체다.
    if os.environ.get("DEVBREW_DISABLE_" + plugin.upper().replace("-", "_")) == "1":
        return True

    # 부분 문자열이 아니라 **전체 토큰**으로 대조한다. `in` 부분 일치를 쓰면
    # `quality-gates:post-tool-use` 가 `quality-gates:post-tool-use-session-tracker`
    # 안에 접두로 들어가, 사용자가 긴 쪽을 지목했을 때 짧은 쪽 훅까지 조용히 꺼진다
    # (quality-gates v1.6.2 가 실제로 겪은 결함).
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    tokens = {t.strip() for t in skip.split(",") if t.strip()}

    # 별칭 둘 다 받는다. `event` 가 빈 문자열인 것은 **훅이 아닌 소비자**(GC 스크립트
    # 등)의 정상 상태다 — 그때는 `"<plugin>:"` 같은 꼬리 없는 토큰이 생기지 않도록
    # 이벤트 별칭 자체를 만들지 않는다. 빈 이벤트를 토큰으로 만들면
    # `DEVBREW_SKIP_HOOKS=<plugin>:` 하나가 그 플러그인의 모든 무이벤트 소비자를
    # 한꺼번에 끄는, 아무도 문서화하지 않은 와일드카드가 된다.
    aliases = [hook]
    if event:
        aliases.append(event)
    return any("{0}:{1}".format(plugin, alias) in tokens for alias in aliases)
