#!/usr/bin/env bash
# 재리뷰 상한의 **cross-file 일치** 회귀 락.
#
# 정본은 `shared/docreview/references/reviewing-document.md` 의 `` `rereview_cap: N` ``
# 한 줄이다. 그 문서가 스스로 *"이 값의 정본은 이 한 줄이다"* 라고 적고 있으므로, 이
# 락이 하는 일은 그 자기 주장을 **실행 차원에서 참으로 만드는 것**이다 — 다른 어떤
# 파일도 이 숫자의 출처가 아니다.
#
# ── 이 락이 대조하는 자리와, 왜 그 자리인가 ─────────────────────────────────
#  1. `shared/docreview/scripts/docreview_state.py` 의 `REREVIEW_CAP` — **엔진 상수**.
#     조사 실측(2026-09-08): 오늘 이 상수와 산문 정본은 완전히 분리돼 있고 어떤 락도
#     둘을 대조하지 않았다. 산문만 고치면 실행은 옛 값으로 계속 돌고, 상수만 고치면
#     사용자가 읽는 문서가 거짓말을 한다. 둘 중 어느 쪽도 소리를 내지 않는다.
#  2. `plugins/spec-distill/skills/reviewing-spec/SKILL.md` — design doc 자리의 껍데기.
#  3. `plugins/spec-distill/README.md` — 흐름도 한 줄 + AP16 불릿 **둘 다**(개수 하한 2).
#
# ── 음의 짝 (양의 단언만으로는 통째 삭제를 못 잡는다) ───────────────────────
# 위 셋은 전부 **존재** 단언이라, 상한 문장을 통째로 지우면 「없으니 어긋날 것도 없다」
# 로 조용히 통과한다. 그래서 상한 어휘가 등장하는 **모든** 자리를 도출해 그 숫자가
# 전부 CAP 과 같은지를 함께 잰다(∃ 가 아니라 ∀). 옛 값 `5` 를 이름으로 금지하지
# 않는다 — 그러면 다음 값이 `7` 일 때 이 락이 다시 침묵한다.
#
# ── 이후 PR 이 코퍼스를 넓히는 자리 ─────────────────────────────────────────
# 문서 리뷰 엔진은 자리 넷을 흡수한다. design doc 자리(이 파일이 오늘 재는 것) 다음은
# `reviewing-brief` · `critiquing-artifacts` · `framing-requests` 이고, 그 자리들이
# 엔진으로 전환될 때 **아래 `TARGETS` 배열에 그 SKILL.md 를 한 줄씩 더한다**. 배열
# 하나만 늘리면 양의 단언과 음의 짝이 동시에 그 파일을 덮는다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$REPO_ROOT/shared/tests/assert.sh"

REF="$REPO_ROOT/shared/docreview/references/reviewing-document.md"
ENGINE="$REPO_ROOT/shared/docreview/scripts/docreview_state.py"
SKILL="$REPO_ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md"
README="$REPO_ROOT/plugins/spec-distill/README.md"

# 이후 PR 이 늘리는 자리 — 「그 자리의 산문이 상한을 CAP 으로 적었는가」를 재는 대상.
# (`critiquing-artifacts` · `framing-requests` 의 SKILL.md 가 엔진으로 전환될 때 여기 한 줄씩.
#  `reviewing-brief` 는 PR 3 에서 들어왔다 — 옛 브리프 critic 의 별개 상한이 그 전환으로
#  사라져, 파일 통째로 양의 단언과 ∀ 둘 다의 대상이 된다.)
TARGETS=(
  "$SKILL"
  "$README"
  "$REPO_ROOT/plugins/spec-distill/skills/reviewing-brief/SKILL.md"
)

# ── ∀ 전용 코퍼스 — 「이 자리가 숫자를 **되찾으면** 소리를 낸다」 ────────────
# design doc 자리의 전환이 상한 인용을 재조준하며 손댄 파일들이다. 지금 이 둘은 상한
# 숫자를 하나도 적지 않는 것이 옳은 상태이므로 위 `TARGETS`(양의 하한 ≥1)에는 넣지
# 않는다 — 넣으면 「없으니 RED」가 되어 옳은 상태를 벌한다. 넣어야 하는 것은 **음의
# 짝뿐**이다: 어느 저자가 여기에 숫자를 다시 적으면 그것이 정본 밖의 두 번째 출처가
# 되는데, 넓히기 전의 이 락은 그 자리를 **아예 보지 않았다**.
#
# `docs/philosophy/devbrew-harness-philosophy.md` 는 다른 경로로 여기 들어왔다. 그 문서의
# P18 코드 지도가 상한을 **옛 값으로** 계속 적고 있었고 — 이 락이 그 값을 바꾼 릴리스에서
# — 아무것도 발화하지 않았다. 원인은 하나다: 그 파일이 이 코퍼스 밖이었다. 인용만 고치고
# 코퍼스를 안 넓히면 다음 값 변경 때 같은 자리가 같은 방식으로 다시 빠져나간다.
# **넣기 전에 M4 의 위험(같은 어휘를 쓰는 «다른» 상한)을 점검했다**: 이 파일에서 아래
# `CAP_RE` 가 매치하는 자리는 그 P18 줄 하나뿐이고, 나머지 상한 언급(P18 본문의
# 「max-iteration cap」, 「qg Review fix-loop」)에는 **숫자가 없다.** 그래서 줄-스코프(이
# 상한을 인용하는 줄만 잘라 ∀ 를 거는 방식)가 필요 없고 파일 통째로 넣는다.
# **다만 미래 위험 하나를 이름 붙여 둔다** — 그 P18 줄은 이 상한 바로 옆에 「qg Review
# fix-loop」를 나란히 적는다. 누가 그 qg 상한을 **숫자로** 적으면 이 락이 무관한 값에 대해
# RED 를 낸다. 그때의 처방은 이 항목을 빼는 것이 아니라 줄-스코프로 좁히는 것이다.
NEG_ONLY=(
  "$REPO_ROOT/plugins/spec-distill/references/proceed-gate.md"
  "$REPO_ROOT/plugins/spec-distill/skills/conducting-interview/references/finishing.md"
  "$REPO_ROOT/docs/philosophy/devbrew-harness-philosophy.md"
)


# ── 정본 ─────────────────────────────────────────────────────────────────────
CAP="$(grep -oE '`rereview_cap: [0-9]+`' "$REF" | grep -oE '[0-9]+' | head -1)"
if [ -z "${CAP:-}" ]; then
  echo "✗ FATAL: 정본 패턴을 $REF 에서 찾지 못했다 — 기대: \`rereview_cap: N\`"
  exit 1
fi
echo "정본 재리뷰 상한 = $CAP (출처: shared/docreview/references/reviewing-document.md)"
echo

# ── 1. 엔진 상수 ─────────────────────────────────────────────────────────────
if grep -qE "^REREVIEW_CAP = ${CAP}\$" "$ENGINE"; then
  ok "엔진 상수: docreview_state.py 의 REREVIEW_CAP = $CAP"
else
  ACT="$(grep -oE '^REREVIEW_CAP = [0-9]+' "$ENGINE" | grep -oE '[0-9]+' | head -1)"
  no "엔진 상수 drift: docreview_state.py REREVIEW_CAP = ${ACT:-없음} (정본 $CAP) — 산문과 실행이 갈렸다"
fi

# ── 2·3. 산문 자리 (양의 단언) ───────────────────────────────────────────────
# README 는 두 자리(흐름도 · AP16)를 갖는다 — 하한을 1 로 두면 한쪽을 지워도 통과한다.
for f in "${TARGETS[@]}"; do
  rel="${f#"$REPO_ROOT"/}"
  case "$rel" in
    */README.md) want=2 ;;
    *)           want=1 ;;
  esac
  got="$(grep -cE "재리뷰 상한 ${CAP}([^0-9]|\$)" "$f" || true)"
  if [ "${got:-0}" -ge "$want" ]; then
    ok "$rel: '재리뷰 상한 $CAP' ${got}건 (하한 ${want})"
  else
    no "$rel: '재리뷰 상한 $CAP' 가 ${got:-0}건 — ${want}건 이상이어야 한다 (정본 $CAP 과 어긋났거나 문장이 사라졌다)"
  fi
done

# ── 4. 음의 짝 — 상한 어휘가 나오는 **모든** 자리의 숫자가 CAP 과 같은가 ────
# 어휘: 정본 표기(`rereview_cap: N`) · 엔진 상수(`REREVIEW_CAP = N`) · 한국어 산문
# (`재리뷰 상한 N`) · **영어 산문**(`re-review max N` / `auto re-review, max N` /
# `re-review cap N`).
#
# 〔fix round 1 / M-1〕 영어 형태가 빠져 있었다. 이 PR 이 README 에서 지운 옛 문구가 바로
# `auto re-review, max 5` · `re-review max 5` 였으므로 오늘 잔존은 0 이고 락은 통과한다 —
# 그러나 **다음 저자가 영어로 쓰면 이 축이 침묵한다.** 잔존 0 인 지금이 어휘를 넓힐 때다
# (오늘 통과가 내일의 커버리지 증거가 아니다).
#
# 서로 다른 상한(브리프 리뷰의 `재dispatch 상한 2`, G6 의 `재시도 상한 3`)은 이 어휘에
# 걸리지 않는다 — 같은 숫자를 쓰더라도 다른 값이므로 코퍼스에 넣지 않는다.
CAP_RE='rereview_cap: [0-9]+|REREVIEW_CAP = [0-9]+|재리뷰 상한 [0-9]+|re-?review[^0-9]{0,12}(max|cap)[^0-9]{0,4}[0-9]+'
bad=0
seen=0
scan_text() {   # scan_text <표시경로> <검사할 텍스트>
  local rel="$1" hit n
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    seen=$((seen + 1))
    n="$(printf '%s' "$hit" | grep -oE '[0-9]+' | tail -1)"
    if [ "$n" != "$CAP" ]; then
      bad=$((bad + 1))
      no "음의 짝: $rel 의 '$hit' 가 정본 $CAP 과 다르다"
    fi
  done < <(printf '%s\n' "$2" | grep -oE "$CAP_RE" || true)
}
for f in "$REF" "$ENGINE" "${TARGETS[@]}" "${NEG_ONLY[@]}"; do
  rel="${f#"$REPO_ROOT"/}"
  # 코퍼스 실재 — 없는 파일에 대한 `grep`(rc 2)은 `|| true` 가 삼켜 그 자리가 **조용히**
  # 코퍼스에서 빠진다. 이름이 바뀌었거나 삭제된 자리는 「어긋난 것이 없다」가 아니라
  # 「보지 못했다」이고, 넓힌 코퍼스일수록 그 침묵이 커진다.
  if [ ! -r "$f" ]; then
    no "코퍼스 실재: $rel 를 읽을 수 없다 — 이 자리는 이번 판정에서 통째로 빠졌다(조용한 축소 금지)"
    continue
  fi
  scan_text "$rel" "$(cat "$f")"
done
if [ "$seen" -lt 6 ]; then
  no "음의 짝: 상한 어휘를 ${seen}건밖에 도출하지 못했다 — 코퍼스에서 최소 6건(정본 1 + 엔진 1 + SKILL 둘 각 1 + README 2)이 나와야 한다. 이 상태에서 'bad=0' 은 증거가 아니다"
elif [ "$bad" -eq 0 ]; then
  ok "음의 짝: 상한 어휘 ${seen}건 전부가 정본 $CAP 과 같다 (옛 값 잔존 0)"
fi
finish
