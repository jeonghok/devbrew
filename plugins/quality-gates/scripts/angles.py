#!/usr/bin/env python3
"""각도 상태 — 세 각도의 총 함수 (설계 §6.3.1 · §6.3.2, AC10 · AC10a · AC11 · AC12).

**각도는 에이전트가 아니다.** 각도는 「채워졌는가」의 술어이고 수행자는 스코프가
정한다(§6.3.1). 그래서 이 모듈은 **수행자 명단을 갖지 않는다** — 명단을 넣으면
이 PR 이 지우는 `test_review_floor_lock.sh` 를 파이썬으로 다시 쓰는 것이다.

**판정 값은 내지 않는다.** 이 모듈이 내는 것은 「막는가」라는 불리언 하나이고,
그것을 `not-certified (angle-absent)` 로 번역하는 것은 `verdict.py` 다. 그래서
여기서 `verdict` 를 import 하지 않는다 — 어휘의 소유자는 하나여야 한다.
"""
import argparse
import re
import sys

# 각도 셋 — 닫힌 열거. 튜플 **순서가 출력 순서**다.
ANGLES = ("security", "adjudication", "different-premise")

# 부재가 판정을 **막는** 각도 (§6.3.1 표의 앞 두 행 · AC11). 셋째 행
# `different-premise` 는 여기 없다 — 헌장의 「모델 다양성 손실은 공시하고 막지
# 않는다」 그대로다(AC12). 이 집합에 셋째를 넣으면 codex 가 못 도는 실행이 전부
# 미판정이 된다.
BLOCKING_ANGLES = ("security", "adjudication")

# 자기 finding 자기 판정이 금지되는 각도 (AC10a). **보안 각도는 여기 없다** —
# 보안은 «무엇을 찾는가» 의 문제라 그 리뷰어가 finding 을 내는 것이 정상이고,
# 금지하면 C13 이 허용한 접어 넣기가 사실상 죽는다(설계가 명시적으로 뺀 자리).
SELF_ADJUDICATION_FORBIDDEN = ("adjudication",)

FILLED = "filled"
ABSENT = "absent"
FOLDED_PREFIX = "folded_into:"

# 엄격 서식 — YAML 을 쓰지 않는다(계획 R-I). 상태 값 안에 콜론이 있어서
# (`folded_into:security-reviewer`) YAML 은 따옴표·공백에 따라 해석이 갈리고 그
# 갈림이 조용하다. 총 함수의 입력을 관대한 파서에 맡기면 AC10 의 「하나라도 없으면
# 실패」가 그 관대함만큼 새어 나간다. 상태는 **공백 없는 한 토큰**이다.
_LINE = re.compile(r"^([a-z-]+): (\S+)$")
_PERFORMER = re.compile(r"^[A-Za-z0-9_-]+$")


def fail4(msg):
    # `angles:` 를 접두사로 쓰지 않는다 — 그것은 성공 출력의 블록 헤더다. 순진한
    # 줄-지향 파서가 이 오류 문장을 상태 줄로 읽는다. 형제 `verdict.py` 와 같은
    # 모양으로 스크립트 이름을 쓴다.
    print(f"angles.py: {msg}", file=sys.stderr)
    raise SystemExit(4)


def read_or_fail4(path):
    """각도 파일을 읽는다. 없거나 못 읽으면 exit 4.

    **형제와 다른 점** — `verdict.read_or_none()` 은 경로가 비면 `None`(그 축을 안
    쓴다)을 돌려준다. 여기 오는 경로는 호출자가 이미 「쓴다」고 정한 것이라 부재가
    곧 실패다. 그래서 이름도 반환 계약도 다르다.

    **형제와 같은 점** — 두 절(`OSError` · `UnicodeDecodeError`)을 **둘 다** 둔다.
    `UnicodeDecodeError` 는 `ValueError` 의 하위이지 `OSError` 가 아니라서, 앞
    절만 두면 비-UTF-8 입력이 raw traceback + exit 1 로 0/2/4 계약을 탈출한다.
    이 리포에서 네 번 재발한 모양이다.
    """
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except OSError as exc:
        fail4(f"각도 상태 파일을 읽지 못했다: {path} ({exc})")
    except UnicodeDecodeError as exc:
        fail4(f"각도 상태 파일이 UTF-8 이 아님: {path} ({exc})")


def _validated_state(name, state):
    if state in (FILLED, ABSENT):
        return state
    if state.startswith(FOLDED_PREFIX):
        performer = state[len(FOLDED_PREFIX):]
        if not performer:
            fail4(f"'{name}' 의 {FOLDED_PREFIX} 에 수행자가 없다")
        if not _PERFORMER.match(performer):
            fail4(f"'{name}' 의 수행자 이름이 아니다: {performer!r}")
        return state
    fail4(f"'{name}' 의 상태 '{state}' 가 문법 밖이다 "
          f"({FILLED} · {FOLDED_PREFIX}<수행자> · {ABSENT})")


def parse(text):
    """`<각도>: <상태>` 줄들을 각도→상태 dict 로. **총 함수를 여기서 강제한다**(AC10).

    빠진 각도 · 열거 밖 각도 · 같은 각도의 중복 · 문법 밖 상태는 전부 exit 4 다.
    중복을 「마지막이 이긴다」로 두지 않는 이유: 그러면 앞 줄을 조용히 덮는 경로가
    열리고, 무엇이 참인지 산출물만 보고는 복원할 수 없다.
    """
    states = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        m = _LINE.match(line)
        if not m:
            fail4(f"각도 상태 줄의 서식이 아니다: {raw!r} "
                  "(기대: '<각도>: <상태>', 상태는 공백 없는 한 토큰)")
        name, state = m.group(1), m.group(2)
        if name not in ANGLES:
            fail4(f"열거 밖 각도 '{name}' — 각도 셋은 닫혀 있다")
        if name in states:
            fail4(f"각도 '{name}' 의 상태가 두 번 나온다")
        states[name] = _validated_state(name, state)
    missing = [a for a in ANGLES if a not in states]
    if missing:
        fail4("상태가 없는 각도: " + ", ".join(missing)
              + " — 각도 상태는 총 함수다 (AC10)")
    return states


def performer_of(state):
    """`folded_into:<수행자>` 면 수행자 이름, 아니면 `None`."""
    if state.startswith(FOLDED_PREFIX):
        return state[len(FOLDED_PREFIX):]
    return None


def check_self_adjudication(states, finding_authors):
    """AC10a — 자기 finding 을 자기가 판정하면 exit 4. **판정 각도에 한정**한다.

    `finding_authors` 는 그 실행이 실제로 «낸» finding 에서 도출한 수행자 집합이다
    (계획 R-H). 각도 파일 자신에서 뽑으면 그것은 자기-일관성 검사이지 Law 2
    검사가 아니다 — 저자가 이름을 달리 적는 것만으로 조용해진다.
    """
    for name in SELF_ADJUDICATION_FORBIDDEN:
        performer = performer_of(states[name])
        if performer is not None and performer in finding_authors:
            fail4(f"'{name}' 각도가 이 실행에서 finding 을 낸 "
                  f"'{performer}' 에게 접혔다 — 자기 finding 자기 판정은 "
                  "Law 2 위반이다 (AC10a)")


def blocks(states):
    """AC11 — 보안 또는 판정 각도가 `absent` 면 참.

    `different-premise` 는 세지 않는다(AC12). 그 부재는 `render()` 가 공시한다.
    """
    return any(states[a] == ABSENT for a in BLOCKING_ANGLES)


def render(states):
    """`angles:` 블록. **항상 `len(ANGLES)` 줄**이다 — 부재도 침묵이 아니라 한 줄이다.

    침묵과 `absent` 는 다른 사실이다. 부재한 각도를 빼고 렌더하면 읽는 쪽이 그것을
    「그 각도가 필요 없었다」와 구별할 수 없다.
    """
    out = ["angles:"]
    for a in ANGLES:
        out.append(f"  {a}: {states[a]}")
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--angles", default=None)
    ap.add_argument("--author", action="append", default=[])
    args = ap.parse_args()
    # exit 2 와 exit 4 를 가른다 — 빈 인자는 «잘못된 호출»이지 «실패한 판정»이
    # 아니다. 형제 `verdict.py` 의 `--differential ""` 처리와 같은 규칙이다.
    if not args.angles:
        print("angles.py: --angles 에 각도 상태 파일 경로를 줘라 "
              "(빈 문자열은 받지 않는다)", file=sys.stderr)
        return 2
    states = parse(read_or_fail4(args.angles))
    check_self_adjudication(states, set(args.author))
    sys.stdout.write(render(states))
    print(f"angle_absent: {'true' if blocks(states) else 'false'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
