#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/spec-interview/SKILL.md plugins/spec-distill/references/fresh-evidence.md
#
# 인터뷰 skill 의 `## 조사 열기` 절 — 조사 agent 를 여럿 동시에 띄우고(AC1), 본체가 주문을 써
# open-researcher 에 보내며(AC2 · AC8), 웹이 꺼지면 띄우지 않고(AC3), 무엇을 만들자는 결정에서
# 있는 것을 먼저 찾고(AC12), 라운드의 질문 호출은 하나에 독립 결정을 묶을 수 있다(AC13).
# 두 펜스(웹 · 요약)는 문구가 아니라 차가운 셸에서 실행해 잰다. 실제 agent 는 부르지 않는다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT/plugins/spec-distill"
SKILL="$SD/skills/spec-interview/SKILL.md"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/skills/spec-interview/SKILL.md"
  echo "plugins/spec-distill/references/fresh-evidence.md"
  exit 0
fi

. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

SCRATCH="$(mktemp -d -t sd-open-XXXXXX)" || { echo "scratch 생성 실패" >&2; exit 1; }
[ -n "$SCRATCH" ] && [ -d "$SCRATCH" ] || { echo "scratch 가 유효한 디렉토리가 아니다" >&2; exit 1; }
trap 'rm -rf "$SCRATCH"' EXIT

section() {   # section <파일> <제목 정규식> → 그 `## ` 절 본문(다음 `## ` 직전까지, 펜스 인식)
  SEC="$2" awk '
    !on && $0 ~ ("^## " ENVIRON["SEC"]) {on=1; next}
    on && /^```/ {fence=!fence}
    on && !fence && /^## / {exit}
    on
  ' "$1"
}
prose_of() { awk '/^```/ {f=!f; next} !f' <<<"$1"; }
cut_marked_by() {   # cut_marked_by <표지> <파일> → `<!-- <표지>:begin -->` · `:end` 사이 ```bash 펜스 본문
  MK="$1" awk '
    $0 == "<!-- " ENVIRON["MK"] ":begin -->" {g=1; next}
    $0 == "<!-- " ENVIRON["MK"] ":end -->" {g=0}
    g && /^```bash$/ {b=1; next}
    g && b && /^```$/ {b=0; next}
    g && b' "$2"
}

SEC="$(section "$SKILL" '조사 열기')"; FLAT="$(prose_of "$SEC" | tr '\n' ' ' | tr -s ' ')"
[ "$(grep -c . <<<"$SEC")" -ge 15 ] && ok "절을 잘랐다" || no "조사 열기 절 부재 — 아래가 공허하다"
# AC1
assert_contains "$FLAT" '서로 기대지 않는 조사 질문이 둘 이상이면 한 메시지에서 조사 agent 를 여럿 띄울 수 있다' "AC1: 동시에 여럿"
assert_contains "$FLAT" '무엇을 왜 함께 띄웠는지 한 줄 적는다' "AC1: 함께 띄운 이유 한 줄"
assert_contains "$FLAT" '조건 자리(`steelman-builder`)는 그대로다' "AC1: 기존 자리 유지"
# AC2 — dispatch · 슬롯 넷 · 처분 · 기대 결론 금지
for s in '<order>${RESEARCH_ORDER}</order>' '<fresh_evidence>${FRESH_EVIDENCE}</fresh_evidence>' \
         '<claims_contract>${CLAIMS_CONTRACT}</claims_contract>' '<open_decisions>${OPEN_DECISIONS}</open_decisions>'; do
  assert_contains "$SEC" "$s" "AC2: 슬롯 ${s}"
done
assert_contains "$SEC" 'subagent_type: "spec-distill:open-researcher"' "AC2: dispatch"
assert_contains "$SEC" '// **처분** — consumer=orchestrator · fail-closed · disclosure=loud advisory + 본체 직접 조사로 강등' "AC2: 처분 줄"
assert_contains "$FLAT" '기대 결론은 싣지 않는다' "AC2: 주문에 기대 결론 없음"
# AC8 — 주문을 쓸 때 reference 를 읽는다(포인터 줄)
assert_contains "$SEC" 'Read ${CLAUDE_PLUGIN_ROOT}/references/fresh-evidence.md' "AC8: fresh-evidence 포인터"
# AC12
assert_contains "$FLAT" '레포 안의 있는 것(같은 일을 하는 스크립트 · skill · 모듈)을 먼저 찾고' "AC12: 레포 안 먼저"
assert_contains "$FLAT" '바깥 것은 사용자 검토 뒤에만 쓴다' "AC12: 바깥은 사용자 검토 뒤"
assert_contains "$FLAT" '만들 것이 없는 일(조사 · 결정만)이면 건너뛰고 이유를 적는다' "AC12: 건너뛰기와 이유"
# AC13
RB="$(awk '/^```/{c=!c} /^## 라운드 규약/{f=1;print;next} !c && /^## /{f=0} f' "$SKILL" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$RB" 'AskUserQuestion 1회다. 기본은 질문 1개이고, 서로 기대지 않는 결정이 둘 이상이면 같은 호출에 질문을 여럿 묶을 수 있다' "AC13: 호출 하나 · 독립 결정 묶기"
assert_contains "$RB" '답마다 `S<m>` 을 하나씩 기록한다' "AC13: 답마다 S"
assert_contains "$RB" '나머지는 다음 라운드의 «다음 결정»으로 넘어간다 — 서로 기대지 않는 결정은 위 규칙대로 같은 호출에 묶을 수 있다; 되묻기는 직전 답에 기대므로 묶지 않는다' "AC13: 겹침 순서는 기대는 결정에만 — 독립 결정은 묶고 되묻기는 묶지 않는다"
# V1 이 웹 주장으로 넓어진다(fresh-evidence 원칙 2)
assert_contains "$RB" '결정에 닿는 웹 주장(`evidence[]`)은 `${CLAUDE_PLUGIN_ROOT}/references/fresh-evidence.md` 원칙 2 대로 본체가 1차 자료로 한 번 더 확인하거나 «지금 이해»에 「확인 못 함」으로 둔다' "V1: 웹 주장 재확인 또는 「확인 못 함」"
# AC3 — 웹 펜스를 차가운 셸에서 실행
WF="$SCRATCH/web.sh"; cut_marked_by open-research-web "$SKILL" > "$WF"
bash -n "$WF" && [ -s "$WF" ] && ok "AC3(양성대조): 웹 펜스를 떴다" || no "AC3: 웹 펜스 부재 또는 구문 오류"
for v in 1 0 yes '' 2 01 10; do
  out="$(env -i PATH=/usr/bin:/bin DEVBREW_SPEC_DISTILL_DISABLE_WEB="$v" bash "$WF" 2>"$SCRATCH/w.err")"
  want=go; [ "$v" = 1 ] && want=skip
  assert_eq "$(tail -1 <<<"$out")" "open_researcher=${want}" "AC3: 스위치 '${v}' → ${want}"
done
env -i PATH=/usr/bin:/bin DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 bash "$WF" >/dev/null 2>"$SCRATCH/w.err"
assert_contains "$(cat "$SCRATCH/w.err")" 'repo-researcher' "AC3: 레포 질문은 repo-researcher 로"
assert_contains "$(cat "$SCRATCH/w.err")" '확인하지 못함' "AC3: 웹 질문은 「확인하지 못함」"
zsh_bin="$(command -v zsh || true)"; [ -z "$zsh_bin" ] || { out="$(env -i PATH=/usr/bin:/bin DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 "$zsh_bin" "$WF" 2>/dev/null)"; assert_eq "$(tail -1 <<<"$out")" "open_researcher=skip" "AC3: zsh 에서도"; }
# AC8 — 요약 펜스 실행: 실제 루트면 stdout = 표지 사이 그대로, 파일 없는 루트면 rc 1 · 빈 stdout
FF="$SCRATCH/fe.sh"; cut_marked_by fresh-evidence "$SKILL" > "$FF"
want="$(awk '/<!-- order-summary:end -->/{f=0} f; /<!-- order-summary:begin -->/{f=1}' "$SD/references/fresh-evidence.md")"
[ -n "$want" ] && ok "AC8(양성대조): 요약 블록이 비지 않았다" || no "AC8: fresh-evidence.md 의 요약 블록이 비었다 — 아래 등호가 공허하다"
got="$(env -i PATH=/usr/bin:/bin CLAUDE_PLUGIN_ROOT="$SD" bash "$FF" 2>/dev/null)"; rc=$?
assert_eq "$rc" "0" "AC8: 요약 펜스 rc 0"; assert_eq "$got" "$want" "AC8: stdout 이 요약 블록 그대로"
mkdir -p "$SCRATCH/empty/references"
got="$(env -i PATH=/usr/bin:/bin CLAUDE_PLUGIN_ROOT="$SCRATCH/empty" bash "$FF" 2>"$SCRATCH/f.err")"; rc=$?
assert_eq "$rc" "1" "AC8: 파일 없는 루트면 rc 1"; assert_eq "$got" "" "AC8: 그때 stdout 비었다"
assert_contains "$(cat "$SCRATCH/f.err")" '본체가 직접 조사한다' "AC8: 강등 경로를 말한다"
# AC14 — R2 의 「외부 선례 무관」 닫힘(사용자가 고른 답 · 불릿 없는 한 줄 · ☑ 일 때만)
R2="$(awk '/^```/{c=!c} /^### R2 — 웹 Landscape/{f=1;next} !c && /^##/{f=0} f' "$SKILL" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$R2" '라운드 질문에서 「외부 선례 무관 — <이유>」를 선택지로 보인다' "AC14: R2 — 라운드 질문의 선택지"
assert_contains "$R2" '불릿 없는 한 줄' "AC14: R2 — 불릿 없는 한 줄"
assert_contains "$R2" '사용자 선택(☑)으로 있을 때만 받는다' "AC14: R2 — ☑ 일 때만"

finish
