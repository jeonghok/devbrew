#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/references/docreview-profiles/brief.md plugins/spec-distill/agents/doc-critic.md plugins/spec-distill/agents/doc-recritic.md
#
# `reviewing-brief` 껍데기의 **계약** 락 — 문서 리뷰 엔진의 brief 자리.
#
# 실행으로 재야 하는 성질(codex 게이트 fence 의 잔존물 중화 · 문서별 자리 · 번들 실패 정리)은
# `test_reviewing_brief_residue.sh` 가 차가운 셸에서 잰다. 이 파일은 그 fence **밖**의 계약을 잰다:
# 호출자 계약 · 진입 게이트의 순서와 차단 · 지출 게이트의 부재와 대체 · 옛 파이프라인의 부재 ·
# 게이트 문면 · 냉독의 무스키마 · 웹 공시가 사실과 맞는가 · degrade 채널 공시.
#
# 판정 방식 — 절(`## `) 윈도우는 코드 펜스를 인식한다(펜스 안 컬럼-0 주석이 헤딩처럼 보여 창을
# 자르지 않게). 명령의 존재는 펜스 안 **실행 라인**(주석 제외)으로 잰다 — 산문 한 줄로 만족되지
# 않게. 부재 단언마다 같은 자리의 양의 짝을 함께 둔다 — 절이 통째로 사라지면 부재는 공허하게 참이다.
set -u -o pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT/plugins/spec-distill"
SKILL="$SD/skills/reviewing-brief/SKILL.md"
PROF="$SD/references/docreview-profiles/brief.md"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/skills/reviewing-brief/SKILL.md"
  echo "plugins/spec-distill/references/docreview-profiles/brief.md"
  echo "plugins/spec-distill/agents/doc-critic.md"
  echo "plugins/spec-distill/agents/doc-recritic.md"
  exit 0
fi

. "$ROOT/shared/tests/assert.sh"

[ -f "$SKILL" ] || { no "대상 부재 — ${SKILL#"$ROOT/"}"; finish; exit; }

# ── 도구 ────────────────────────────────────────────────────────────────────
# section <이름 정규식> → 그 `## ` 절 본문(다음 `## ` 직전까지, 펜스 인식)
section() {
  SEC="$1" awk '
    !on && $0 ~ ("^## " ENVIRON["SEC"]) {on=1; next}
    on && /^```/ {fence=!fence}
    on && !fence && /^## / {exit}
    on
  ' "$SKILL"
}
# run_lines <텍스트> → ```bash 펜스 안 실행 라인(주석 줄 제외, `\` 연속줄을 한 줄로)
run_lines() {
  awk '/^```bash$/{f=1; next} /^```$/{f=0; next} f' <<<"$1" \
    | awk '{ if ($0 !~ /^[[:space:]]*#/ && sub(/\\$/, "")) { part = part $0 " "; next }
             sub(/^[[:space:]]+/, "", $0); print part $0; part = "" }
           END { if (part != "") print part }' \
    | grep -v '^[[:space:]]*#' || true
}
has()    { grep -qF -- "$2" <<<"$1"; }
lines_ge() { [ "$(printf '%s\n' "$1" | grep -c .)" -ge "$2" ]; }
ALL="$(cat "$SKILL")"
ALL_RUN="$(run_lines "$ALL")"
FM="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$SKILL")"

n_mark="$(grep -c '^```' "$SKILL" || true)"
if [ "$n_mark" -gt 0 ] && [ $((n_mark % 2)) -eq 0 ]; then
  ok "전제: 코드 펜스 마커 ${n_mark}개 — 짝수, 절 윈도우가 유효하다"
else
  no "전제: 코드 펜스 마커 ${n_mark}개 — 닫히지 않은 펜스가 있어 절 윈도우가 EOF 까지 흐른다"
fi

# ── 1. 지출 — 승인 게이트는 없고 엔진 상한이 대신한다 ─────────────────────────
grep -qxE 'cost_class: medium' <<<"$FM" \
  && ok "지출: cost_class: medium" || no "지출: cost_class 가 medium 이 아니다"
grep -qF 'cost_class: high' "$SKILL" \
  && no "지출: cost_class: high 가 파일 어딘가에 남았다 — high 는 지출 승인 게이트를 요구한다(CLAUDE.md)" \
  || ok "지출: cost_class: high 잔존 없음"
grep -qE '^[[:space:]]*AskUserQuestion\(\{' "$SKILL" \
  && no "지출: AskUserQuestion 호출 리터럴이 있다 — 떼기로 한 지출 승인 게이트가 되살아났다" \
  || ok "지출: 자기 AskUserQuestion 호출 리터럴 없음 (진입 지출 게이트 없음)"
W_PROC="$(section '절차')"
{ has "$W_PROC" '재리뷰 상한 2' && has "$W_PROC" '라운드 4' && has "$W_PROC" '지출 통제'; } \
  && ok "지출(양의 짝): \`## 절차\` 가 지출 통제를 엔진의 재리뷰 상한 2 와 라운드 4 의 명시 승인으로 댄다" \
  || no "지출(양의 짝): 게이트를 뗀 자리에 무엇이 지출을 묶는지 \`## 절차\` 가 말하지 않는다"

# ── 2. 호출자 계약 — 인자 둘, 훅 없음 ──────────────────────────────────────────
W_IN="$(section '입력')"
lines_ge "$W_IN" 10 && ok "입력: 절 윈도우 확보" || no "입력: 절이 비었거나 잘렸다 — 아래 단언이 공허하다"
{ has "$W_IN" '`$PAYLOAD`' && has "$W_IN" '`$AUDIT`' && has "$W_IN" 'conducting-interview'; } \
  && ok "입력: 호출자(conducting-interview)가 넘기는 두 슬롯 \$PAYLOAD · \$AUDIT 를 이름으로 댄다" \
  || no "입력: 호출자 계약의 두 슬롯이 \`## 입력\` 에 없다"
for gone in CODEX_DIR_YAML CODEX_FID_YAML; do
  grep -qF "$gone" "$SKILL" \
    && no "입력: 옛 인자 $gone 이 남았다 — codex 산출물 경로는 이 skill 이 도출한다" \
    || ok "입력: 옛 인자 $gone 없음"
done
grep -qE 'CODEX_YAML="\$STATE_DIR/docreview-codex\.yaml"' <<<"$ALL_RUN" \
  && ok "입력(양의 짝): codex 산출물 경로를 문서별 상태 디렉토리에서 도출하는 실행 라인이 있다" \
  || no "입력(양의 짝): codex 산출물 경로의 도출 라인이 없다 — 옛 인자 부재가 공허하다"
IN_RUN="$(run_lines "$W_IN")"
grep -qE '^STATE_DIR=.*state-dir-for .*--doc "\$\{PAYLOAD:-\}"' <<<"$IN_RUN" \
  && ok "입력: 엔진 상태 디렉토리가 payload 로 도출된다 (state-dir-for --doc \$PAYLOAD)" \
  || no "입력: STATE_DIR 도출이 payload 를 문서로 쓰지 않는다"

# ── 3. kill switch 공시 (codex 게이트 fence 밖) ─────────────────────────────
OUTSIDE="$(awk '/codex-gate:begin/{g=1} !g; /codex-gate:end/{g=0}' "$SKILL")"
for sw in 'DEVBREW_SPEC_DISTILL_DISABLE=1' 'DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW=1' \
          'DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1' 'DEVBREW_SPEC_DISTILL_DISABLE_WEB=1' \
          'DEVBREW_SPEC_DISTILL_DISABLE_RECRITIC=1'; do
  has "$OUTSIDE" "$sw" && ok "kill switch: $sw 가 fence 밖 표면에 공시된다" \
                       || no "kill switch: $sw 공시가 fence 밖에 없다 (P21 — 끌 수 있다는 사실이 안 보인다)"
done
W_KS="$(section 'kill switch')"
has "$W_KS" '캐시하지 않' && ok "kill switch: dispatch 직전 확인·캐시 금지 계약" || no "kill switch: 확인 시점 계약(캐시 금지)이 없다"
{ has "$W_KS" 'SKIPPED' && has "$W_KS" 'Step B' && has "$W_KS" '조용히 건너뛰지 않는다'; } \
  && ok "kill switch: BRIEF_REVIEW skip 은 record + loud advisory 후 Step B (조용한 생략 아님)" \
  || no "kill switch: BRIEF_REVIEW skip 경로의 공시가 무너졌다"

# ── 4. 진입 게이트 — 번들보다, 엔진보다 먼저 · 실패는 차단 ──────────────────────
first_line() { grep -nE -- "$1" <<<"$ALL_RUN" | head -1 | cut -d: -f1; }
i_gate="$(first_line 'check_brief\.py" gate "\$PAYLOAD"')"
i_cov="$(first_line 'check_verbatim_coverage\.py" "\$PAYLOAD" "\$STATE" "\$AUDIT"')"
i_bnd="$(first_line 'build_brief_bundle\.py" "\$PAYLOAD" "\$AUDIT" > "\$BUNDLE"')"
i_run="$(first_line 'run_docreview_codex_reviewer\.sh" "\$PROFILE" "\$BUNDLE"')"
if [ -n "$i_gate" ] && [ -n "$i_cov" ] && [ -n "$i_bnd" ] && [ -n "$i_run" ] \
   && [ "$i_gate" -lt "$i_cov" ] && [ "$i_cov" -lt "$i_bnd" ] && [ "$i_bnd" -lt "$i_run" ]; then
  ok "순서: 구조 게이트 → 원문 완전성 → 번들 조립 → codex 러너 (실행 라인 순서)"
else
  no "순서 위반 또는 부재 (gate=${i_gate:-없음} coverage=${i_cov:-없음} bundle=${i_bnd:-없음} runner=${i_run:-없음}) — 엔진은 게이트를 통과한 문서만 받아야 한다"
fi
l_gate_h="$(grep -n '^## 진입 게이트' "$SKILL" | head -1 | cut -d: -f1)"
l_proc_h="$(grep -n '^## 절차' "$SKILL" | head -1 | cut -d: -f1)"
{ [ -n "$l_gate_h" ] && [ -n "$l_proc_h" ] && [ "$l_gate_h" -lt "$l_proc_h" ]; } \
  && ok "순서: \`## 진입 게이트\` 절이 \`## 절차\`(엔진) 절보다 앞이다" \
  || no "순서: 진입 게이트 절이 엔진 절보다 앞에 있지 않다 (${l_gate_h:-없음} / ${l_proc_h:-없음})"
W_GATE="$(section '진입 게이트')"
GATE_RUN="$(run_lines "$W_GATE")"
branch_exits() {   # branch_exits <여는 if 정규식> → 그 분기 본문(fi 까지)에 exit 1 이 있는가
  P="$1" awk '!inb && $0 ~ ENVIRON["P"] {inb=1; next} inb && /^fi$/ {exit} inb' <<<"$GATE_RUN" | grep -qE '^[[:space:]]*exit 1'
}
branch_exits '^if \[ "\$gate_rc" -ne 0 \]' \
  && ok "진입 게이트: 구조 게이트 실패 분기가 실제로 멈춘다 (exit 1)" \
  || no "진입 게이트: 구조 게이트 실패 분기가 없거나 멈추지 않는다 — 검증되지 않은 문서가 엔진에 들어간다"
branch_exits '^if \[ "\$vc_rc" -eq 1 \]' \
  && ok "진입 게이트: 원문 완전성 위반 분기가 실제로 멈춘다 (exit 1)" \
  || no "진입 게이트: 원문 완전성 위반 분기가 없거나 멈추지 않는다"
for row in '비어 있지 않으면' '구조 위반' '그 외 non-zero' 'indeterminate ≠ clean'; do
  has "$W_GATE" "$row" && ok "진입 게이트 rc 표: '$row'" || no "진입 게이트 rc 표에서 '$row' 행이 사라졌다"
done
grep -qE '^vc_rc=0; python3 .*\|\| vc_rc=\$\?$' <<<"$GATE_RUN" \
  && ok "진입 게이트: rc 를 errexit 에 안전한 모양으로 잡는다 (파이프 없음)" \
  || no "진입 게이트: rc 포착이 errexit 에 안전하지 않거나 파이프 뒤에 있다"

# ── 5. 프로필 — brief 하나만 ──────────────────────────────────────────────────
has "$(section '프로필')" 'docreview-profiles/brief.md' \
  && ok "프로필: brief.md 를 이름으로 고른다" || no "프로필: brief.md 선택이 사라졌다"
n_prof=0; other=""
for pf in "$SD"/references/docreview-profiles/*.md; do
  [ -f "$pf" ] || continue; n_prof=$((n_prof+1)); b="$(basename "$pf")"
  [ "$b" = "brief.md" ] && continue
  grep -qF "docreview-profiles/$b" "$SKILL" && other="$other $b"
done
if [ "$n_prof" -lt 2 ]; then no "프로필: 디렉터리에서 ${n_prof}개만 도출 — 「다른 것을 안 부른다」가 공허하다"
elif [ -z "$other" ]; then ok "프로필: 실재 프로필 ${n_prof}개 중 이 skill 이 경로로 대는 것은 brief 하나다"
else no "프로필: brief 아닌 프로필을 경로로 댄다:$other"; fi

# ── 6. 절차 슬롯 — 엔진 --doc 은 payload, reviewer 입력은 번들, 결정 기록은 audit ────
{ has "$W_PROC" 'references/reviewing-document.md' && has "$W_PROC" '`--doc` = `$PAYLOAD`' \
  && has "$W_PROC" '`$BUNDLE`' && has "$W_PROC" '`--log-file` = `$AUDIT`'; } \
  && ok "절차: 절차서를 읽고 슬롯(--doc=payload · 리뷰어 입력=번들 · 결정 기록=audit)을 댄다" \
  || no "절차: 절차서 참조 또는 이 자리의 슬롯 배정이 빠졌다"
awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$PROF" | grep -qE '^decision_log:.*kind: audit_section' \
  && ok "절차(사실): 프로필의 decision_log 가 실제로 audit_section 이다 — '--log-file = \$AUDIT' 가 참이다" \
  || no "절차(사실): 프로필 decision_log 가 audit_section 이 아니다 — SKILL 의 결정 기록 목적지가 거짓이 됐다"

# ── 7. 옛 파이프라인 부재 + 엔진 배선 (양의 짝) ─────────────────────────────────
for gone in 'brief-critic' 'brief-direction-reviewer' 'merge_brief_review' 'run_brief_codex_reviewer' \
            'build_brief_codex_prompt' 'can-redispatch' 'bump-critic-round' 'set-stage' \
            'fidelity_verdict' 'brief_critic_rounds'; do
  grep -qF -- "$gone" "$SKILL" && no "옛 파이프라인: '$gone' 이 남았다 — 치환이지 추가가 아니다(없는 산출물을 기다린다)" \
                              || ok "옛 파이프라인: '$gone' 없음"
done
for d in doc-critic doc-recritic brief-readback; do
  n="$(grep -cE "^[[:space:]]*subagent_type: \"spec-distill:${d}\"" "$SKILL" || true)"
  [ "$n" = "1" ] && ok "배선: $d dispatch 가 정확히 하나" || no "배선: $d dispatch 가 ${n}개 (기대 1)"
done
grep -qE '^bash "\$SD/scripts/run_docreview_codex_reviewer\.sh"' <<<"$ALL_RUN" \
  && ok "배선: codex 는 엔진의 단일 러너로 간다 (실행 라인)" || no "배선: 엔진 codex 러너 호출 라인이 없다"

# ── 8. 게이트 — 절차서 문면 + 2단계는 Step B 의 몫 ─────────────────────────────
W_G="$(section '게이트')"
lines_ge "$W_G" 15 && ok "게이트: 절 윈도우 확보" || no "게이트: 절이 비었거나 잘렸다 — 아래 단언이 공허하다"
G_BODY="$(grep -vE '^#' <<<"$W_G")"
for p in '최대 4개씩' '상한 도달이면 열린 것이 0 이어도 항상 두 단계다' '별개 항목' '열기 / 열지 않음' '--extra-approval'; do
  has "$G_BODY" "$p" && ok "게이트 문면: '$p'" || no "게이트 문면: '$p' 가 사라졌다 (절차서와 갈렸다)"
done
{ has "$G_BODY" '2단계' && has "$G_BODY" '이 skill 이 띄우지 않는다' && has "$G_BODY" 'Step B'; } \
  && ok "게이트: 승인 게이트 2단계(진행 옵션)는 이 skill 이 아니라 conducting-interview Step B 가 띄운다" \
  || no "게이트: 2단계 진행 결정의 소유자가 적혀 있지 않다 — 진행 옵션이 두 번 뜨거나 한 번도 안 뜬다"
grep -qF 'references/proceed-gate.md' "$SKILL" \
  && no "게이트: proceed-gate 계약의 채택자 포인터가 있다 — 이 skill 은 진행 게이트를 띄우지 않는다" \
  || ok "게이트: proceed-gate 채택자 포인터 없음 (2단계는 Step B 가 채택자다)"
{ has "$G_BODY" 'polite stop' && has "$G_BODY" '미검증'; } \
  && ok "게이트: polite stop 금지와 critic 사망 시 「미검증」 라벨" \
  || no "게이트: polite stop 금지 또는 「미검증」 라벨이 빠졌다"

# ── 9. 냉독 — 무스키마 · payload 만 · advisory ─────────────────────────────────
W_RB="$(section '냉독')"
lines_ge "$W_RB" 20 && ok "냉독: 절 윈도우 확보" || no "냉독: 절이 비었거나 잘렸다"
RB_CALL="$(awk '/^```javascript$/{f=1; next} /^```$/{f=0} f' <<<"$W_RB")"
{ has "$RB_CALL" 'subagent_type: "spec-distill:brief-readback"' && has "$RB_CALL" '${BLOB}'; } \
  && ok "냉독(양의 짝): dispatch 블록이 실재하고 \${BLOB} 을 싣는다" \
  || no "냉독(양의 짝): readback dispatch 블록이 없다 — 아래 부재 단언이 공허하다"
for tok in 'category' 'severity' 'sentinel' 'JSON' 'audit' 'G1' 'gap 클래스' '미결을 확정으로'; do
  has "$RB_CALL" "$tok" && no "냉독: dispatch 블록에 '$tok' — 기준·스키마를 알면 측정이 오염된다" \
                        || ok "냉독: dispatch 블록에 '$tok' 없음"
done
RB_RUN="$(run_lines "$W_RB")"
{ grep -qE 'build_brief_inline_blob\.py" "\$PAYLOAD"' <<<"$RB_RUN" && ! grep -qF 'build_brief_bundle' <<<"$RB_RUN"; } \
  && ok "냉독: payload 만 싣는다 (번들이 아니다 — 하류가 읽는 것을 잰다)" \
  || no "냉독: payload-only blob 이 아니다"
has "$W_RB" '그 외 non-zero 는 `2`와 동일하게 취급' && ok "냉독: blob rc 표의 catch-all" || no "냉독: blob rc catch-all 이 사라졌다"
for g in G1 G2 G3 G4 G5 G6; do
  grep -qE "^\| ${g} \|" <<<"$W_RB" && ok "냉독: gap 클래스 $g 행" || no "냉독: gap 클래스 $g 행이 사라졌다"
done
{ has "$W_RB" 'G1–G6 **전부 0건**' && has "$W_RB" '세 조각' && has "$W_RB" 'advisory'; } \
  && ok "냉독: 성공 조건(G1–G6 전부 0건) · 세 조각 보고 · advisory" \
  || no "냉독: 성공 조건 또는 보고 형식이 무너졌다"

# ── 10. 수정 권한 ─────────────────────────────────────────────────────────────
W_ED="$(section '수정 권한')"
{ has "$W_ED" 'user_sourced_items' && has "$W_ED" '**불변**' && has "$W_ED" '**append-only**'; } \
  && ok "수정 권한: §2 는 frontmatter 와 같은 write · payload §6 불변 · audit §6 append-only" \
  || no "수정 권한: 저자 규칙 셋 중 하나가 빠졌다 (laundering 이 열린다)"
{ has "$W_ED" '임의로 기각하지 못한다' && has "$W_ED" '미반영 findings' && has "$W_ED" 'Step B'; } \
  && ok "수정 권한: finding 임의 기각 금지 + 미반영은 이유와 함께 Step B" \
  || no "수정 권한: 임의 기각 금지 또는 미반영 이월이 빠졌다"

# ── 11. 웹 공시 — 문면이 사실과 맞는가 ─────────────────────────────────────────
{ has "$ALL" 'Claude 쪽 근거가 없다' && has "$ALL" '`tools: Read, Grep, Glob`' && has "$ALL" 'codex 의 웹 검색'; } \
  && ok "웹: Claude 쪽 웹 근거 부재와 스위치가 끄는 대상(codex 웹)을 공시한다" \
  || no "웹: 웹 축소 공시가 빠졌다 — 옛 방향성 리뷰어의 웹 근거가 사라진 사실이 안 보인다"
for a in doc-critic doc-recritic; do
  awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$SD/agents/$a.md" | grep -qxE 'tools: Read, Grep, Glob' \
    && ok "웹(사실): $a 의 tools 가 정확히 Read, Grep, Glob 이다 — 공시가 참이다" \
    || no "웹(사실): $a 의 tools 가 바뀌었다 — 「Claude 쪽 웹 근거 없음」 공시가 거짓이 됐다"
done
awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$PROF" | grep -qxE 'web: true' \
  && ok "웹(사실): 프로필 brief.md 가 web: true — codex 러너가 이 자리에서 웹을 켠다" \
  || no "웹(사실): 프로필이 web: true 가 아니다 — 「스위치가 codex 웹을 끈다」 공시가 거짓이 됐다"

# ── 12. degrade 채널 ──────────────────────────────────────────────────────────
W_DG="$(section 'degrade 채널')"
for ch in 'advisory[]' 'blocks' 'gate --render' 'brief_review_degradations' '$DEGRADE_FALLBACK_FILE' '웹:'; do
  has "$W_DG" "$ch" && ok "degrade 채널: '$ch' 를 이름으로 댄다" || no "degrade 채널: '$ch' 가 절에서 사라졌다"
done
{ has "$W_DG" 'degrade 없음' && has "$W_DG" '실제로 읽었다는 주장' && has "$W_DG" '알 수 없는'; } \
  && ok "degrade 채널: 「없음」은 읽었다는 주장이고, 판독 실패는 「알 수 없음」이다" \
  || no "degrade 채널: 침묵과 「없음」·「판독 불가」의 구분이 사라졌다"
for fld in component affected_axis verification_status reason; do
  has "$W_KS" "\`$fld\`" && ok "degrade record: 필드 '$fld'" || no "degrade record: 필드 '$fld' 가 사라졌다"
done
grep -qE '^python3 "\$PR/scripts/brief_review_state\.py" degrade-append "\$STATE" .*\|\| echo .*>> "\$DEGRADE_FALLBACK_FILE"$' <<<"$ALL_RUN" \
  && ok "degrade record: append 가 실패하면 두 번째 채널 파일에 이어 붙는다 (실행 라인)" \
  || no "degrade record: degrade-append 의 실패가 두 번째 채널로 가지 않는다 — 원장이 죽으면 「degrade 없음」이 된다"
grep -qE '^init_rc=0; python3 "\$PR/scripts/brief_review_state\.py" init "\$STATE" \|\| init_rc=\$\?$' <<<"$ALL_RUN" \
  && ok "degrade 원장: init 의 종료 코드를 그 자리에서 잡는다" \
  || no "degrade 원장: init 의 종료 코드를 잡지 않는다 — 기록 경로가 죽어도 조용하다"

# ── 13. Step B 로 돌아가는 산출물 ───────────────────────────────────────────────
W_SB="$(section 'Step B 로 돌아간다')"
{ has "$W_SB" '엔진 게이트 결과' && has "$W_SB" '냉독 요약' && has "$W_SB" 'degrade'; } \
  && ok "Step B: 산출물 셋(엔진 게이트 결과 · 냉독 요약 · degrade)을 싣는다" \
  || no "Step B: 호출자에게 넘길 산출물 목록이 무너졌다"
finish
