#!/usr/bin/env bash
# A1 — 리포의 **어떤** 플러그인도 쓰기 도구에 발화하는 PostToolUse 훅을 갖지 않는다.
#
# 정의역도 판정도 **열거가 아니라 도출**이다.
#   정의역 — 대상 파일은 하드코딩이 아니라 glob 으로 뽑는다. 네 번째 플러그인이 같은
#            결함을 들고 와도 RED 다.
#   판정   — "금지 목록에 있는가" 가 아니라 **"쓰기 도구를 전부 배제한다고 증명할 수
#            있는가"** 를 묻는다. 증명할 수 없으면 막는다. 이유는 아래 python 블록에.
#
# **경계** — 이 락이 읽는 것은 각 `hooks.json` 의 `PostToolUse` 항목뿐이라,
# `PreToolUse`·`Stop` 등 다른 훅 이벤트에 쓰기 도구 matcher 가 들어와도 GREEN 이다.
#
# 이 락은 음의 락(“위반 0건”)이라 코퍼스가 비면 공허하게 통과한다. 그래서 양의 짝을
# 다섯 붙인다: 정의역이 비지 않았다(`assert paths`), **두 glob 이 각각 살아 있다**
# (`assert EXEMPT <= paths` 가 shared 쪽을, `assert scanned >= 3` 이 plugins 쪽을),
# 면제가 실제로 무언가를 면제하고 있다(양성 대조 3), 그리고 이 fix 가 남겨야 할 것들이
# 살아 있다(양성 대조 1·2).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
FAIL=0
ok() { echo "  ✓ $1"; }
no() { echo "  ✗ $1"; FAIL=1; }

# 면제 경로의 **단일 정의** — 아래 python 블록과 양성 대조 3 이 같은 값을 쓴다.
# 둘로 나눠 적으면 한쪽만 고쳐도 조용히 통과하는 drift 가 생긴다.
EXEMPT_FIXTURE="shared/tests/fixtures/hookprobe/hooks/hooks.json"

if python3 - "$EXEMPT_FIXTURE" <<'PY'
import glob, json, re, sys

# ── 판정 ─────────────────────────────────────────────────────────────────────
# `matcher` 가 어떤 매칭 의미론을 갖는지(정규식·glob·리터럴 alternation) 이 락은
# **단정하지 않는다** — 단정할 근거가 없고, 이 브랜치는 이미 도구 동작을 산문으로
# 단정한 값을 치렀다. 그래서 의미론을 몰라도 성립하는 술어로 뒤집는다:
#
#     통과 = 「이 matcher 가 쓰기 도구를 전부 배제한다」를 **증명할 수 있다**
#
# 증명 가능한 유일한 모양은 `|` 로 나눈 모든 조각이 **맨 식별자**(메타문자 없음)이고
# 그 식별자가 전부 아래 SAFE_TOOLS 안에 있는 경우다. 그 밖의 철자는 무엇에 발화하는지
# 이 락이 알 수 없으므로 **fail-closed** — 막는다.
#
# 두 축 모두 fail-closed 다 (CLAUDE.md 「denylist 단독 금지」):
#   공간 — denylist 판정에서는 '*' '.*' '^(Write|Edit)$' 'Edit.*' 'Write.*' '[WE].*'
#          여섯 철자가 전부 GREEN 이었다(실측). 지금은 전부 막힌다. 와일드카드 matcher
#          는 가정이 아니라 이 리포에 실재한다 — hookprobe 픽스처의 '*.md'.
#   시간 — 내일 추가될 쓰기 도구는 오늘 열거할 수 없다. denylist 는 그것을 조용히
#          통과시키지만 allowlist 는 막고 사람에게 묻는다.
#
# SAFE_TOOLS 를 늘리는 것은 **의도된 편집**이어야 하고 리뷰에서 보여야 한다.
SAFE_TOOLS = {"Bash"}

# 진단 라벨 전용 — **판정에 쓰지 않는다.** 위 allowlist 가 판정을 전부 진다.
# 여기 이름이 빠져도 그 토큰은 SAFE_TOOLS 밖이라 어차피 막힌다(이 집합은 메시지를
# 한 단어 친절하게 만들 뿐이라 stale 해져도 게이트가 약해지지 않는다).
WRITE_TOOL_LABELS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}

BARE_IDENT = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")


def rejection_reason(m):
    """통과시킬 수 없는 이유. 통과면 None."""
    if m is None:
        return "matcher 키 부재 — 전 도구에 발화한다"
    if not isinstance(m, str) or not m.strip():
        return f"matcher 가 빈 값({m!r}) — 전 도구에 발화한다"
    for tok in (t.strip() for t in m.split("|")):
        if not BARE_IDENT.match(tok):
            return (f"조각 {tok!r} 이 맨 식별자가 아니다 — 무엇에 발화하는지 "
                    f"증명할 수 없다(와일드카드/정규식 가능)")
        if tok not in SAFE_TOOLS:
            label = " — 쓰기 도구다" if tok in WRITE_TOOL_LABELS else ""
            return f"조각 {tok!r} 이 SAFE_TOOLS 밖이다{label}"
    return None


# ── 정의역 ───────────────────────────────────────────────────────────────────
# 커밋된 프로브 픽스처는 matcher 없는 PostToolUse 항목을 **의도적으로** 갖고 있다
# (2026-08-22 헤드리스 실측용). 면제이며, 그 이유가 여기 적혀 있어야 면제다.
EXEMPT = {sys.argv[1]}
paths = sorted(set(glob.glob("plugins/*/hooks/hooks.json")
                   + glob.glob("shared/**/hooks/hooks.json", recursive=True)))
assert paths, "hooks.json 을 하나도 찾지 못했다 — glob 이 깨졌다 (계측기 고장)"

bad, scanned = [], 0
for p in paths:
    if p in EXEMPT:
        continue
    scanned += 1
    for e in json.load(open(p, encoding="utf-8"))["hooks"].get("PostToolUse", []):
        why = rejection_reason(e.get("matcher"))
        if why:
            bad.append((p, e.get("matcher"), why))

# 발견한 위반을 **먼저** 인쇄한다. 아래 정의역 단언을 앞에 두면 위반과 정의역 사고가
# 함께 일어났을 때 AssertionError 만 보이고 BAD 줄은 인쇄되기도 전에 죽는다.
for p, m, why in bad:
    print(f"BAD {p} matcher={m!r} — {why}", file=sys.stderr)

# 정의역 하한 **두 개** — 각 glob 이 하나씩 진다. 하나로는 반쪽이 죽어도 안 보인다:
#   실측 — `shared/**` glob 만 지웠을 때 paths=3 · scanned=3 · bad=0 으로 GREEN 이었다.
#          `assert paths` 는 plugins 쪽이 혼자 채워 통과시켰고 `scanned>=3` 도 그랬다.
#          두 glob 을 동시에 깨는 변이로는 어느 쪽이 짐을 지는지 구분할 수 없다.
assert EXEMPT <= set(paths), (
    f"면제 대상이 정의역에 없다 — shared glob 이 그 파일에 닿지 않는다: "
    f"{sorted(EXEMPT - set(paths))}")
assert scanned >= 3, f"검사한 파일이 {scanned}개뿐이다 — plugins 정의역이 좁아졌다"
sys.exit(1 if bad else 0)
PY
then ok "A1: 리포 전수 — PostToolUse matcher 가 전부 '쓰기 도구 배제 증명 가능'"
else no "A1: 위반 발견 (위 BAD 줄 참조) 또는 정의역이 무너졌다"
fi

# 양성 대조 1 — Bash matcher 는 살아 있다 (GREEN 이 정답, A2).
# `|| N_BASH=0` 이 없으면 안 된다: grep 은 매치 없음(1)과 자체 실패(≥2)를 둘 다 비-zero
# 로 내고, `set -e` + `pipefail` 아래에서 이 대입이 스크립트를 그 자리에서 죽인다.
# 그러면 아래 두 대조는 **실행되지 않은 채** 종료되는데 rc 는 여전히 1 이라 사람 눈에는
# "락이 잡았다"로 보인다 — 실측으로 확인된 모양이다(Bash matcher 를 전부 rename 한
# 변이에서 출력이 ✓ 한 줄에서 끊겼다). 개수 0 은 아래 임계값이 판정한다.
N_BASH=$(grep -l '"matcher": "Bash"' plugins/*/hooks/hooks.json 2>/dev/null | wc -l | tr -d ' ') || N_BASH=0
[[ "$N_BASH" -ge 2 ]] && ok "양성 대조: Bash matcher 훅 ${N_BASH}개 생존" \
                      || no "양성 대조 실패: Bash matcher 훅이 ${N_BASH}개뿐"

# 양성 대조 2 — 기록물에 남은 이름은 위반이 아니다 (GREEN 이 정답).
grep -q 'spec-write-validator' plugins/spec-distill/CHANGELOG.md \
  && ok "양성 대조: CHANGELOG 의 은퇴 기록 생존" \
  || no "양성 대조 실패: CHANGELOG 에서 은퇴 기록이 사라졌다 (Law 3 substrate 파괴)"

# 양성 대조 3 — 면제가 실제로 무언가를 면제하고 있다.
# `EXEMPT` 는 픽스처가 matcher 없는 PostToolUse 항목을 갖고 있기 **때문에** 존재한다.
# 픽스처가 모양을 바꾸면 면제는 아무것도 보호하지 않게 되고, 이 락의 정의역은 조용히
# 줄어든다 — 그 사실을 말해줄 곳이 여기 말고 없다.
if python3 - "$EXEMPT_FIXTURE" <<'PY'
import json, sys
entries = json.load(open(sys.argv[1], encoding="utf-8"))["hooks"].get("PostToolUse", [])
if not any(not e.get("matcher") for e in entries):
    print(f"면제 픽스처 {sys.argv[1]} 에 matcher 없는 PostToolUse 항목이 없다", file=sys.stderr)
    sys.exit(1)
PY
then ok "양성 대조: 면제 픽스처가 여전히 matcher-less PostToolUse 를 갖는다"
else no "양성 대조 실패: 면제가 보호하는 대상이 사라졌다 — EXEMPT 를 지우거나 픽스처를 되돌려라"
fi

exit $FAIL
