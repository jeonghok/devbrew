#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""build_brief_bundle.py — 충실도 축의 두 리뷰어가 공유하는 번들 (payload + audit §6).

형제 `build_seed_inline_blob.py`의 **구조**를 이식한다(명시 경로 → 라벨 붙은 조립 →
stdout). 조립 로직이 두 소비자에 각각 따로 있으면 한쪽만 고쳐질 때 두 리뷰어가 다른
재료를 보는 drift가 생긴다.

**이식하는 것은 구조이지 그 파일의 실패 정책이 아니다.** 형제는 원문 절을 못 찾으면
stderr로 경고하고 그대로 조립한다(fail-open). 여기서는 **rc 2 · 무디스패치**다 —
원문 없이 충실도를 물으면 "왜곡 없음"이 나온다.

**audit 경로를 유추하지 않는다**(형제가 명시적으로 거부한 것). 재료를 어디서 가져올지의
유추는 실패했을 때 조용하고, 잘못된 재료로 리뷰를 태우는 것이 없는 것보다 나쁘다.
게이트의 `resolve_audit()`이 stem을 유도하는 것과 층이 다르다 — 그것은 찾는 것이 아니라
payload가 어느 audit을 자기 것이라 부를지 고르지 못하게 거절하는 것이다.

라벨 토큰은 **마크다운 헤딩이 아니다.** 헤딩이면 payload 자신의 절 헤딩들과 같은
네임스페이스에 들어가 "몇 번째 ##인가"가 다시 문제가 된다. 그리고 실린 audit §6의
**절 헤딩은 벗긴다** — 안 벗기면 payload의 같은 헤딩과 바이트 동일해져, 라벨을 붙여도
"§6을 보라"는 지시가 먼저 나오는 쪽(S1 하나)에 걸린다.

exit: 0 정상 / 2 payload·audit 부재·읽기 실패·audit §6 없음(무디스패치) /
3 번들 payload 부분에 audit 파일명 잔존(위생 미달 — 호출자가 degrade 기록 후 계속)
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

# §6 경계는 이 파일이 계산하지 않는다 — `scripts/section6.py` 한 곳이다. 이 파일이 자기
# 정규식을 갖던 동안 게이트와 종결 규칙이 달라, audit §6 안의 **펜스로 감싼** `## 7.` 하나로
# 이 블록이 비거나(원문 전량 소실) 위조본으로 바뀌는데 게이트는 rc 0 이었다(v0.47.0 실측).
_SCRIPTS_DIR = str(pathlib.Path(__file__).resolve().parent)
if _SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, _SCRIPTS_DIR)
import section6  # noqa: E402
import check_brief  # noqa: E402  — audit 신원 결속(아래 `blessed_audit`)

REDACT_KEYS = ("audit_file", "name", "created_at")
AUDIT_NAME_RE = re.compile(r"\S*\.audit\.md\b")

# 번들 안에서 비신뢰 verbatim이 "여기서부터 시작한다"고 알리는 두 리터럴 표지 — 이 번들을
# 프롬프트에 그대로 inline하는 소비자(agents/brief-critic.md의 dispatch 지시문)는 반드시
# **둘 다** 이름으로 가리켜야 한다. 하나만 가리키면 다른 쪽 원문에는 injection 경계가
# 없어진다(task-10 fix round 2 실측 — 라벨 토큰만 가리키고 payload 쪽 §6은 빠뜨린 결함).
#
# 왜 이 둘인가: `<<<PAYLOAD>>>` 다음에 실리는 payload 본문은 자신의 `## 6. 사용자 원문`
# 절(S1)을 **바이트 그대로** 담고 있다 — redact_frontmatter()는 frontmatter 세 키만
# 건드리고 body는 손대지 않는다(위 모듈 docstring의 "실린 audit §6의 절 헤딩은 벗긴다 —
# 안 벗기면 payload의 같은 헤딩과 바이트 동일해진다"는 대칭으로, payload 쪽 헤딩은 애초에
# 벗길 대상이 아니라 그대로 남는다). audit_verbatim()이 만드는 두 번째 블록(S2 이상)은
# `<<<AUDIT-VERBATIM>>>` 라벨이 표지한다. 이 튜플이 정본이다 — 번들 포맷이 바뀌어 세
# 번째 위치가 생기면 여기만 늘리면 되고, 소비자 쪽 문면이 그 표지를 놓치면
# test_brief_agents.sh의 cross-check 락이 잡는다.
UNTRUSTED_VERBATIM_MARKERS = ("## 6. 사용자 원문", "<<<AUDIT-VERBATIM>>>")


def redact_frontmatter(text: str) -> str:
    for k in REDACT_KEYS:
        text = re.sub(rf"(?m)^({k}\s*:\s*)[^\n]*$", r"\1<redacted>", text, count=1)
    return text


def audit_verbatim(audit_text: str):
    """audit §6의 **항목만** 반환한다 (절 헤딩 제외). 절이 없거나 **모호하면** None.

    모호(경계가 읽는 규칙마다 다름)를 None 으로 내리는 것이 요점이다 — 예전에는 이 함수가
    자기 규칙으로 어딘가를 잘라 **무언가를 실었고**, 그 무언가가 게이트가 본 것과 달랐다.
    「모르겠다」를 「비었다」로 바꾸지 않는다: 호출자가 rc 2·무디스패치로 받는다.
    """
    return None if (b := section6.body(audit_text)) is None else b.strip()


def blessed_audit(payload_path: pathlib.Path, payload_text: str):
    """게이트가 축복한 audit 경로. 규칙을 복제하지 않고 게이트에서 **가져온다**.

    이 함수가 없으면 「게이트가 검사한 파일」과 「이 빌더가 싣는 파일」을 묶는 것이 아무것도
    없다 — 실측(v0.47.0): 게이트가 `I.audit.md` 를 통과시킨 payload 로 빌더에 전혀 다른
    `OTHER.audit.md` 를 넘기면 위조 원문이 그대로 ground truth 로 실린다(rc 0).

    **경로를 유추하지 않는다는 원칙은 유지한다.** 호출자는 여전히 audit 을 명시해야 하고,
    이 함수는 그 명시가 게이트의 해석과 **다를 때 거절**한다 — `resolve_audit()` 자신이
    「찾는 것이 아니라 고르지 못하게 거절하는 것」이라 적은 그 층이다.
    """
    return check_brief.resolve_audit(payload_path, check_brief._frontmatter(payload_text))


def assemble(payload_text: str, verbatim: str) -> str:
    # 라벨 다음 줄에 **빈 줄**을 둔다(task-10 fix). payload는 frontmatter `---`로
    # 시작하므로, 라벨 바로 다음 줄이 그 `---`이면 CommonMark가 라벨 텍스트를 setext
    # h2(`<h2>`)로 승격시킨다 — `## 6. 사용자 원문`과 같은 헤딩 네임스페이스에 들어가
    # 이 파일이 막으려는 바로 그 헤딩-충돌이 라벨 도입 자체로 재발한다. 빈 줄은 앞
    # 텍스트를 단락 나머지와 분리해 setext 후보에서 제외시킨다(CommonMark: setext
    # underline은 바로 앞 줄이 같은 단락에 속할 때만 성립).
    _, audit_label = UNTRUSTED_VERBATIM_MARKERS  # 소비자 계약과 실제 출력을 한 값으로 묶는다
    return (f"<<<PAYLOAD>>>\n\n{redact_frontmatter(payload_text).strip()}\n\n"
            f"{audit_label}\n\n{verbatim}\n")


def main() -> int:
    p = argparse.ArgumentParser(prog="build_brief_bundle.py")
    p.add_argument("payload_file")
    p.add_argument("audit_file")
    args = p.parse_args()
    paths = {"payload_file": pathlib.Path(args.payload_file),
             "audit_file": pathlib.Path(args.audit_file)}
    for label, path in paths.items():
        if not path.is_file():
            print(f"{label} not found: {path}", file=sys.stderr)
            return 2
    try:
        payload_text = paths["payload_file"].read_text(encoding="utf-8")
        audit_text = paths["audit_file"].read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(f"읽기 실패: {exc}", file=sys.stderr)
        return 2
    # 신원 결속을 **조립 전에** 건다 — 뒤에 걸면 잘못된 재료로 이미 조립한 뒤가 된다.
    blessed, blessed_err = blessed_audit(paths["payload_file"], payload_text)
    if blessed_err is not None:
        print(f"payload가 자기 audit을 해석하지 못한다: {blessed_err} — "
              "게이트가 축복한 파일을 특정할 수 없으면 조립하지 않는다.", file=sys.stderr)
        return 2
    if blessed.resolve() != paths["audit_file"].resolve():
        print(f"audit 신원 불일치: 넘겨받은 {paths['audit_file']} vs "
              f"payload가 선언하고 게이트가 검사한 {blessed} — 게이트가 보지 않은 원문을 "
              "ground truth로 실을 수 없다.", file=sys.stderr)
        return 2
    verbatim = audit_verbatim(audit_text)
    if verbatim is None:
        why = section6.ambiguities(audit_text) or ["`## 6. 사용자 원문` 절이 없다"]
        print(f"{paths['audit_file']} — {why[0]}. "
              "원문 없이(또는 어느 원문인지 모른 채) 충실도를 물으면 「왜곡 없음」이 "
              "나온다. 조립하지 않는다.", file=sys.stderr)
        return 2
    redacted_payload = redact_frontmatter(payload_text)
    sys.stdout.write(assemble(payload_text, verbatim))
    # 위생 스캔은 **payload 부분에만** 건다. 번들이 audit 내용을 의도적으로 싣게 됐으므로
    # 전체를 스캔하면 정상 동작이 매번 exit 3을 낸다.
    if AUDIT_NAME_RE.search(redacted_payload):
        print("[spec-distill] 번들 payload 부분에 audit 파일명이 남아 있다 — "
              "원문 보존이 우선이라 지우지 않는다(호출자가 degrade 기록).", file=sys.stderr)
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
