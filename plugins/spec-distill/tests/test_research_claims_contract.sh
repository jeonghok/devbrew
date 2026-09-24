#!/usr/bin/env bash
# guards: plugins/spec-distill/references/research-claims.md plugins/spec-distill/skills/conducting-interview/SKILL.md plugins/spec-distill/skills/conducting-interview/references/steelman.md plugins/spec-distill/agents/steelman-builder.md
#
# 조사 주장 계약이 **경로가 아니라 내용으로** 세 dispatch 에 배달되는가, 그리고 정본과 사본이
# 갈라지지 않는가. 설치본에서 계약 파일은 플러그인 캐시(사용자 cwd 밖)에 있어 subagent 의 Read 가
# 권한 거부되고, 그러면 agent 는 계약 없이 판정하면서 orchestrator 는 그것을 모른다.
# 구조는 형제 `test_dispatch_profile_inline.sh` 를 상속한다(같은 문제를 이미 네 축으로 잰다).
#
#   A  SKILL.md `## 조사 주장 계약` 절 산문(펜스 밖)에 body-unique 문구
#   B  양의 짝 — 슬롯 `<claims_contract>${CLAIMS_CONTRACT}</claims_contract>` 가 SKILL.md 2 · steelman.md 1
#   C  `claims-contract` 마커 사이 펜스가 그 절 안에 있고 `cat "$CLAIMS"` 를 부르며 실패 분기가
#      「dispatch 하지 않는다」를 말하고 rc 1 로 끝난다
#   X  그 펜스를 차가운 셸에서 실행 — 실제 루트면 stdout 이 계약 내용(rc 0), 계약 없는 루트면 rc 1 + 빈 stdout
#   D  정합 — 정본의 필드 이름 집합 == steelman-builder 사본의 것 (집합 등호)
#   E  `fail-closed` 값의 회귀 감지 — 처분 락은 어휘만 보고 값을 단언하지 않는다. 필드 등호
#      (부분 문자열이 아니다) + 그 줄의 `fail-(open|closed)` 토큰이 정확히 하나임을 함께 잰다
#      (필드 등호만으로는 `disclosure=` 뒤에 반대 값을 이어붙여도 안 잡힌다)
# 실제 agent 는 부르지 않는다.
#
# 알려진 한계(축 A): `assert_contains` 는 순수 문자열 포함 검사라, PHRASE 리터럴을 그대로 두고
# 바로 뒤에 그 원칙을 부정하는 절을 이어붙이는 변이(표기 유지·의미만 반전 — 예:
# "...싣는다는 문구는 이제 무시하고 실제로는 경로 문자열만 싣는다")는 잡지 못하고 green 으로
# 남는다(실측). 펜스 자체(C·X)가 그 절의 실제 동작을 재므로 실행 경로는 여전히 커버되지만,
# 산문이 자기모순으로 갈라지는 것은 이 락이 아니라 사람 리뷰(문서 리뷰)의 몫이다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT/plugins/spec-distill"
SKILL="$SD/skills/conducting-interview/SKILL.md"
STEEL="$SD/skills/conducting-interview/references/steelman.md"
CANON="$SD/references/research-claims.md"
COPY="$SD/agents/steelman-builder.md"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/references/research-claims.md"
  echo "plugins/spec-distill/skills/conducting-interview/SKILL.md"
  echo "plugins/spec-distill/skills/conducting-interview/references/steelman.md"
  echo "plugins/spec-distill/agents/steelman-builder.md"
  exit 0
fi

. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

SCRATCH="$(mktemp -d -t sd-claims-XXXXXX)" || { echo "scratch 생성 실패" >&2; exit 1; }
[ -n "$SCRATCH" ] && [ -d "$SCRATCH" ] || { echo "scratch 가 유효한 디렉토리가 아니다" >&2; exit 1; }
trap 'rm -rf "$SCRATCH"' EXIT

PHRASE='경로가 아니라 **계약 파일의 내용**을 싣는다'
SLOT='<claims_contract>${CLAIMS_CONTRACT}</claims_contract>'
SLOT2='<open_decisions>${OPEN_DECISIONS}</open_decisions>'

section() {   # section <파일> <제목 정규식> → 그 `## ` 절 본문(다음 `## ` 직전까지, 펜스 인식)
  SEC="$2" awk '
    !on && $0 ~ ("^## " ENVIRON["SEC"]) {on=1; next}
    on && /^```/ {fence=!fence}
    on && !fence && /^## / {exit}
    on
  ' "$1"
}
prose_of() { awk '/^```/ {f=!f; next} !f' <<<"$1"; }
cut_marked() {
  awk '/<!-- claims-contract:begin -->/ {g=1; next}
       /<!-- claims-contract:end -->/ {g=0}
       g && /^```bash$/ {b=1; next}
       g && b && /^```$/ {b=0; next}
       g && b' "$1"
}
fail_branch() {
  awk '!inb && /^if \[ "\$claims_rc" -ne 0 \]/ {inb=1} inb {print} inb && /^fi$/ {exit}' "$1"
}
# YAML 키 이름 집합 — 펜스 안 `키:` 줄에서. 리스트 접두 `- ` 를 허용한다.
keys_of() {   # keys_of <파일> <블록 시작 정규식> <블록 끝 정규식>
  awk -v s="$2" -v e="$3" '$0 ~ s {f=1; next} f && $0 ~ e {f=0} f' "$1" \
    | sed -nE 's/^[[:space:]]*-?[[:space:]]*([a-z_]+):.*/\1/p' | sort -u
}

SEC="$(section "$SKILL" '조사 주장 계약')"
lines_sec="$(printf '%s\n' "$SEC" | grep -c . || true)"
if [ "${lines_sec:-0}" -ge 8 ]; then
  ok "절을 잘랐다 (${lines_sec}줄 — 아래 절 단언이 공허하지 않다)"
else
  no "\`## 조사 주장 계약\` 절을 못 잘랐다 (${lines_sec:-0}줄) — 아래 단언이 공허하다"
fi

# A — 산문에만 산다.
assert_contains "$(prose_of "$SEC")" "$PHRASE" \
  "A: 절 산문이 \`\${CLAIMS_CONTRACT}\` 에 경로가 아니라 계약 파일의 내용을 싣는다고 말한다 (body-unique)"

# A2 — `${OPEN_DECISIONS}` 렌더 형식(최종 리뷰 M-4). 세 dispatch 가 같은 슬롯을 싣는데 무엇을 어떤 모양으로
#      싣는지 정한 자리가 없으면 해결된 결정까지 실리거나(장치가 닫힌 결정에 `decides` 를 단다) id 없는
#      문장이 실린다. 열린 것만 · id 형식을 한 리터럴로 문다(`resolved` 로 바꾸면 사라진다). 평탄화해 재줄바꿈에 관용.
assert_contains "$(prose_of "$SEC" | tr '\n' ' ' | tr -s ' ')" '`${OPEN_DECISIONS}` 에는 `open_decisions[]` 중 `status: open` 인 것만 한 줄에 하나씩 `OQ<n>: <한 줄>` 로 싣는다' \
  "A2: 절 산문이 \`\${OPEN_DECISIONS}\` 의 렌더 형식(열린 것만 · OQ<n>: <한 줄>)을 정의한다"

# B — 양의 짝: 슬롯 개수. SKILL.md 2(coverage-mapper · blind-spot-prober) + steelman.md 1.
n_sk="$(grep -oF "$SLOT" "$SKILL" | wc -l | tr -d ' ')"
n_st="$(grep -oF "$SLOT" "$STEEL" | wc -l | tr -d ' ')"
assert_eq "$n_sk" "2" "B: SKILL.md 의 \`claims_contract\` 슬롯이 2개 (coverage-mapper · blind-spot-prober)"
assert_eq "$n_st" "1" "B: steelman.md 의 \`claims_contract\` 슬롯이 1개"
m_sk="$(grep -oF "$SLOT2" "$SKILL" | wc -l | tr -d ' ')"
m_st="$(grep -oF "$SLOT2" "$STEEL" | wc -l | tr -d ' ')"
assert_eq "$m_sk" "2" "B: SKILL.md 의 \`open_decisions\` 슬롯이 2개 (계약만 있고 결정 목록이 없으면 decides 를 채울 수 없다)"
assert_eq "$m_st" "1" "B: steelman.md 의 \`open_decisions\` 슬롯이 1개"

# F — 결정 연결 형식 넷과 레포 주장의 RC 상시 탑재(최종 리뷰 I-4). 정본이 말하지 않으면 계약을
#     받은 장치가 닿는 결정 없는 레포 주장을 `[→ 없음]` 으로 내려 RC 를 잃는다. 줄바꿈에 관용하도록
#     평탄화하고, 리터럴에 극성(「항상 … 싣는다」)과 짝(「웹 주장만 쓴다」)을 함께 문다.
CANON_FLAT="$(tr '\n' ' ' < "$CANON" | tr -s ' ')"
# AC5 — 인덱스만 읽고 판정하는 것의 금지와 그 출처. 삭제·반전이 다른 축에 안 보여 여기서 문다(qg iter 1).
assert_contains "$CANON_FLAT" '## 판정 전에 구현을 읽는다 > 인덱스·레지스트리·목차·description 필드만 읽고 판정하지 말 것. **구현을 읽어라.**' \
  "AC5: 인덱스만 읽기 금지 + 구현을 읽으라는 지시"
assert_contains "$CANON_FLAT" 'docs/archive/interview/2026-07-12-project-init-audit-interview.md' \
  "AC5: 출처 인용 경로"
assert_contains "$CANON_FLAT" 'subagent 가 낸 `id` 는 **임시값**이다 — orchestrator 가 V1 에서 인터뷰 전역 순번으로 다시 붙이고, 그 번호만 payload · audit 에 실린다.' \
  "규칙 4: RC id 의 발급 주체는 orchestrator(V1) — subagent 의 id 는 임시값"
assert_contains "$CANON_FLAT" '레포 `[RC<n> → OQ<n>]` · `[RC<n> → 없음]`, 웹 `[→ OQ<n>]` · `[→ 없음]`' \
  "F: 정본이 결정 연결 형식 넷(레포 둘 · 웹 둘)을 댄다"
assert_contains "$CANON_FLAT" '**레포 주장은 연결 안에 항상 `RC<n>` 을 싣는다** — 닿는 결정이 없어도 `[RC<n> → 없음]` 이고, `[→ …]` 는 웹 주장만 쓴다' \
  "F: 정본이 레포 주장의 RC 상시 탑재와 웹 전용 형식을 못 박는다"

# C — 내용을 얻는 펜스.
FENCE="$SCRATCH/fence.sh"; cut_marked "$SKILL" > "$FENCE"
n_fence="$(grep -c . "$FENCE" || true)"
if [ "${n_fence:-0}" -ge 5 ] && bash -n "$FENCE" 2>/dev/null; then
  ok "C: claims-contract 펜스 ${n_fence}줄 · bash -n 통과"
else
  no "C: 펜스가 ${n_fence:-0}줄이거나 문법이 깨졌다 — 마커가 없거나 추출이 깨졌다"
fi
grep -qF '<!-- claims-contract:begin -->' <<<"$SEC" \
  && ok "C: 그 펜스가 \`## 조사 주장 계약\` 절 안에 있다" \
  || no "C: 펜스가 그 절 밖이거나 없다"
grep -v '^[[:space:]]*#' "$FENCE" | grep -qF 'cat "$CLAIMS"' \
  && ok "C: 펜스가 실행 줄에서 \`cat \"\$CLAIMS\"\` 로 내용을 얻는다 (Read 가 아니다)" \
  || no "C: 펜스에 \`cat \"\$CLAIMS\"\` 실행 줄이 없다"
FB="$(fail_branch "$FENCE")"
{ grep -qF 'dispatch 하지 않는다' <<<"$FB" && grep -qE '^[[:space:]]*exit 1$' <<<"$FB"; } \
  && ok "C: 실패 분기가 dispatch 하지 않는다고 말하고 rc 1 로 끝난다" \
  || no "C: 실패 분기(\`if [ \"\$claims_rc\" -ne 0 ]\`)가 없거나 dispatch 금지 · rc 1 이 빠졌다"

# D — 정합: 정본과 사본의 필드 이름 집합이 **집합 등호**.
#     ⊇ 하나만 요구하면 사본이 `decides`·`id` 를 빠뜨려도 green 이고, 그 방향이 바로 이 축의
#     근거로 인용한 「한쪽만 고치는」 결함이다.
#     정규식을 한 문자열에 콜론으로 패킹하지 않는다 — 정규식 자체가 `:` 를 담아 구분자와
#     충돌하고, 그 충돌은 조용하지 않지만 **엉뚱하게** 터진다: 실측에서 `s_re` 가 `^evidence`
#     로 잘리고 `e_re` 가 `$:^repo_claims:$` 가 되어 awk 가 「정규식 구문 오류」로 죽었다.
#     블록마다 명시 호출한다.
cmp_block() {   # cmp_block <라벨> <시작 정규식> <끝 정규식>
  local blk="$1" s_re="$2" e_re="$3" k_canon k_copy
  k_canon="$(keys_of "$CANON" "$s_re" "$e_re")"
  k_copy="$(keys_of "$COPY" "$s_re" "$e_re")"
  if [ -z "$k_canon" ] || [ -z "$k_copy" ]; then
    no "D($blk) 양성대조: 키 집합 도출이 비었다 (정본='$k_canon' 사본='$k_copy') — 아래 등호가 공허하다"
  else
    ok "D($blk) 양성대조: 정본 $(printf '%s\n' "$k_canon" | grep -c .)키 · 사본 $(printf '%s\n' "$k_copy" | grep -c .)키 도출"
  fi
  assert_eq "$k_copy" "$k_canon" "D($blk): 정본과 사본의 필드 이름 집합이 같다 (집합 등호 — ⊇ 로는 사본의 누락을 못 잡는다)"
}
# 시작·끝 정규식에 `$` 앵커를 쓰지 않는다 — 정본의 `evidence:` 줄에는 정렬 공백과 주석이 붙어
# 있어 `^evidence:$` 가 매치하지 않는다(실측: 그 앵커로는 정본 쪽 도출이 통째로 비었다).
# `^evidence:` · `^repo_claims:` 는 두 파일에서 각각 정확히 한 줄만 매치하고(실측), 여는 펜스는
# ```yaml 이라 `^```$` 는 닫는 펜스만 잡는다.
cmp_block evidence    '^evidence:'    '^repo_claims:'
cmp_block repo_claims '^repo_claims:' '^```$'
# 신설 필드 둘이 실제로 그 집합에 있는지 — 등호만 요구하면 둘 다 빠져도 green 이다.
for f in decides id; do
  grep -qE "^[[:space:]]*-?[[:space:]]*${f}:" "$CANON" \
    && ok "D: 정본에 신설 필드 \`$f\`" || no "D: 정본에 신설 필드 \`$f\` 부재 (등호가 둘 다 빠진 채로 성립할 수 있다)"
done

# E — `fail-closed` 값의 회귀 감지. 처분 락(`test_dispatch_disposition.sh` 축 A④)은
#     `consumer=(\S+)\s+·\s+fail-(open|closed)(?:\s+·\s+disclosure=(.+?))?` 로 필드를
#     구분자 ` · ` 로 나눠 어휘만 검증하고 그 파일이 스스로 「값이 저자 손에 있는 한 축 B 급
#     이빨은 이 축에서 나오지 않는다」고 공시한다. 이 축은 그 값을 여기서 못 박는다 — **부분
#     문자열이 아니라 필드 등호**로: 같은 구분자로 나눠 `fail-` 로 시작하는 필드를 골라 그
#     값이 정확히 `fail-closed` 인지 비교한다. 그것만으로는 부족하다 — `disclosure=` 필드
#     뒤에 반대 절(`... (교정: 실제 구현은 fail-open 이다)`)을 이어붙여도 `fail-` 필드 자체는
#     `fail-closed` 그대로라 필드 등호를 통과한다(리뷰 실측). 그래서 그 줄 전체에서
#     `fail-(open|closed)` 토큰이 **정확히 하나**인지를 별도로 잰다 — 이어붙은 반대 값은
#     토큰을 둘로 늘린다. 대상은 «계약 슬롯을 싣는 dispatch» 로 도출한다 — 자리 목록을
#     리터럴로 열거하지 않는다.
SEP='**처분** — '
disp_total=0; disp_field_eq=0; disp_single_token=0
for f in "$SKILL" "$STEEL"; do
  while IFS= read -r ln; do
    disp_total=$((disp_total + 1))
    after="${ln#*"$SEP"}"
    faildir_field="$(printf '%s\n' "$after" | awk -F' · ' '{for (i=1;i<=NF;i++) if ($i ~ /^fail-/) print $i}')"
    [ "$faildir_field" = "fail-closed" ] && disp_field_eq=$((disp_field_eq + 1))
    n_tok="$(grep -oE 'fail-(open|closed)' <<<"$ln" | wc -l | tr -d ' ')"
    [ "$n_tok" = "1" ] && disp_single_token=$((disp_single_token + 1))
  done < <(grep -nE '^\s*(//|#)?\s*\*\*처분\*\*\s+—' "$f" | cut -d: -f2- )
done
if [ "$disp_total" -ge 3 ]; then
  ok "E 양성대조: 두 파일에서 처분 앵커 ${disp_total}건 도출 (아래 등식이 공허하지 않다)"
else
  no "E 양성대조: 처분 앵커 도출이 ${disp_total}건 — 3 미만이면 아래 등식이 공허하다"
fi
assert_eq "$disp_field_eq" "$disp_total" \
  "E: 이 자리의 처분 앵커 전부가 fail-closed (필드 등호 — \`consumer=... · fail-<값> · disclosure=...\` 로 나눈 <값> 자체를 비교, 부분 문자열이 아니다)"
assert_eq "$disp_single_token" "$disp_total" \
  "E: 각 처분 줄에 \`fail-(open|closed)\` 토큰이 정확히 하나 (둘 이상이면 뒤에 반대 값을 이어붙인 것 — 필드 등호만으로는 못 잡는다)"

# X — 실행. 문구가 있다는 것과 그 문구가 **돌아간다**는 것은 다른 사실이다.
BASE="/usr/bin:/bin"
PR_NOCLAIM="$SCRATCH/pr-noclaim"; mkdir -p "$PR_NOCLAIM/references"
run_fence() {   # run_fence <셀> <펜스> <플러그인 루트>
  local cell="$1" fence="$2" pr="$3"
  ( cd "$SCRATCH" && env -i PATH="$BASE" HOME="$SCRATCH" PYTHONDONTWRITEBYTECODE=1 \
      CLAUDE_PLUGIN_ROOT="$pr" bash "$fence" ) \
      >"$SCRATCH/$cell.out" 2>"$SCRATCH/$cell.err"
  echo $? > "$SCRATCH/$cell.rc"
}
if [ "${n_fence:-0}" -ge 5 ]; then
  FENCE_E="$SCRATCH/fence-errexit.sh"; { echo 'set -euo pipefail'; cat "$FENCE"; } > "$FENCE_E"
  for mode in plain errexit; do
    f="$FENCE"; [ "$mode" = errexit ] && f="$FENCE_E"
    run_fence "ok-$mode" "$f" "$SD"
    assert_eq "$(cat "$SCRATCH/ok-$mode.rc")" "0" "X($mode): 실제 루트면 rc 0"
    assert_eq "$(cat "$SCRATCH/ok-$mode.out")" "$(cat "$CANON")" "X($mode): stdout 이 계약 파일 내용 그대로다"
    run_fence "no-$mode" "$f" "$PR_NOCLAIM"
    assert_eq "$(cat "$SCRATCH/no-$mode.rc")" "1" "X($mode): 계약이 없는 루트면 rc 1"
    assert_eq "$(grep -c . "$SCRATCH/no-$mode.out" || true)" "0" "X($mode): 그때 stdout 은 비었다 (빈 슬롯으로 dispatch 할 거리가 없다)"
    assert_contains "$(cat "$SCRATCH/no-$mode.err")" "dispatch 하지 않는다" "X($mode): 그때 loud advisory 가 dispatch 금지를 말한다"
    # 강등 경로 둘을 이름으로 댄다 — 어느 자리가 무엇으로 강등되는지가 사유에 실려야 한다.
    assert_contains "$(cat "$SCRATCH/no-$mode.err")" "coverage-mapper 0 (unavailable: 계약 배달 실패)" "X($mode): 사유가 audit §2 문면을 댄다"
    assert_contains "$(cat "$SCRATCH/no-$mode.err")" "inline premortem" "X($mode): 사유가 prober 강등 경로를 댄다"
  done
else
  no "X: 펜스를 못 잘라 실행 축을 재지 못했다"
fi

finish
