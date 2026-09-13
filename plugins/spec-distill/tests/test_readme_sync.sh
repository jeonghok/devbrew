#!/usr/bin/env bash
# T20/AC14 — README/plugin.json/CHANGELOG synced with v0.23.0
# (interview brief handoff 재설계: payload/audit 분리 + user_statements + 4옵션 게이트).
# 이 스위트는 세 층을 검사한다: (1) T20/AC14 — 이 spec(2026-07-25-...-design.md §8 AC14/
# T20)이 정의하는 진짜 acceptance criteria. (2) CHANGELOG append-only 보존 체크 — AC 번호가
# 아니다. 어느 spec의 AC도 아닌 devbrew repo 컨벤션("플러그인 건드리는 PR마다 version bump
# + CHANGELOG entry")을 집행하는 순수 회귀 락이라 AC 라벨을 붙이지 않는다(붙이면 다른 spec의
# 같은 번호 AC와 충돌 — 아래 참고). (3) README-sync 키워드 스윕도 같은 이유로 AC 라벨 없음.
# plugin.json version은 0.26 이상 floor로 assert(patch digit는 의도적으로 unpin) — devbrew의
# "플러그인 건드리는 모든 PR은 patch-bump" 규칙 때문에 리터럴 patch pin은 다음 doc-only
# bump마다 stale-red. 정확한-minor pin(예: `0\.25\.[0-9]+`)도 같은 병이다 — "이 버전 이후
# shipped" 의도를 "정확히 이 minor"로 좁혀 다음 minor bump마다 stale-red가 된다(Task 14 실증).
# floor로 전환: v0.23.0 feature가 여전히 shipped임을 뜻하는 invariant는 이제 "0.26 이상"으로
# 표현되고, 미래 minor bump마다 pin이 위로만 ratchet된다(qg 쪽 test_qg_publish_docs.sh·
# test_artifact_metadata.sh와 동형 관용구).
# v1.0.0(문서 리뷰 엔진 첫 호출자 배선)에서 major가 0을 벗어났다 — "0.(26-99)"만 매치하는
# 옛 정규식은 그 순간부터 항상 RED다(major bump는 이 invariant를 절대 되돌리지 않는데도).
# qg 두 락과 같은 관용구로 "major ≥ 1(임의 minor·patch)"를 OR로 더해 위로만 ratchet되게
# 고쳤다 — 다음 major bump에도 다시 고칠 필요가 없다.
# CHANGELOG [0.20.0]/[0.22.0]/[0.23.0] 엔트리는 append-only 기록이라 리터럴 pin이 correct —
# 버전 bump마다 최신 엔트리 pin을 **추가**하고 과거 pin은 절대 빼지 않는다(누산). 뺀 순간
# 그 히스토리 엔트리가 삭제돼도 이 스위트가 조용히 통과해 append-only 보장이 깨진다.
# AC14는 README "## Principles Instantiated" 섹션(awk 윈도우, 다음 "^## "까지)에 국한된
# 네 사실(라운드별 잠금 제거/종료 시 사용자 일괄 확인/payload-audit 분리/user_sourced_items)
# 어서션 — 내용의 정확성은 검증하지 않는다(누락만 잡음, 정확성은 V6 수동 리뷰 몫).
# 라벨 위생: 이 파일은 과거 여러 design doc의 AC 번호를 그대로 이어받아 쓴 이력이 있다
# (예전 CHANGELOG-보존 체크는 v0.20.0 시절 AC13으로, kw 스윕은 v0.12.0 시절 AC12/AC16으로
# 붙었었다). 그 번호들은 *당시* spec 기준으로는 맞았지만 spec이 갈릴 때마다 같이 갱신되지
# 않아 지금 spec의 AC13(6-리터럴 락)·AC11(bijection A + R4 보존)·AC16(탐색 폭 회귀, advisory)
# 과 충돌했다 — "AC↔T/V 편도 참조"(design doc Rejected Alternatives 명명). T20과 AC14만
# 지금 spec의 T20/AC14 정의와 실제로 일치해 라벨을 유지, 나머지 셋은 라벨을 뗐다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
README="$REPO_ROOT/plugins/spec-distill/README.md"
PLUGIN_JSON="$REPO_ROOT/plugins/spec-distill/.claude-plugin/plugin.json"
CHANGELOG="$REPO_ROOT/plugins/spec-distill/CHANGELOG.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

grep -qE '"version": "([1-9][0-9]*)\.[0-9]+\.[0-9]+"|"version": "0\.(2[6-9]|[3-9][0-9])\.[0-9]+"' "$PLUGIN_JSON" \
  && ok "T20: plugin.json version >= 0.26.x (major >= 1 포함)" \
  || no "T20: plugin.json이 0.26 floor 미만"
grep -qE '^## \[0\.23\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && ok "T20: CHANGELOG [0.23.0] 엔트리 + ISO 날짜" \
  || no "T20: CHANGELOG [0.23.0] 누락/비-ISO"
grep -qE '^## \[0\.24\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && ok "T20: CHANGELOG [0.24.0] 엔트리 + ISO 날짜" \
  || no "T20: CHANGELOG [0.24.0] 누락/비-ISO"
grep -qE '^## \[0\.2[02]\.0\].*XX' "$CHANGELOG" \
  && no "T20: CHANGELOG 날짜에 XX placeholder" || ok "T20: XX placeholder 없음"
grep -qE '^## \[0\.20\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && ok "CHANGELOG append-only: [0.20.0] 엔트리 보존" \
  || no "CHANGELOG append-only: [0.20.0] 엔트리가 사라졌다"
grep -qE '^## \[0\.22\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && ok "CHANGELOG append-only: [0.22.0] 엔트리 보존" \
  || no "CHANGELOG append-only: [0.22.0] 엔트리가 사라졌다"
grep -qE '^## \[0\.25\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && ok "CHANGELOG append-only: [0.25.0] 엔트리 보존" \
  || no "CHANGELOG append-only: [0.25.0] 엔트리가 없다"

for kw in 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' 'spec-distill:review-entry' 'review_entry.py' 'interview-brief' 'steelman-builder' 'DEVBREW_SPEC_DISTILL_DISABLE_CODEX' 'model diversity' 'coverage-mapper' 'blind-spot-prober' 'user_sourced_items' 'audit_file' 'user_statements' 'bijection'; do
  grep -q "$kw" "$README" \
    && ok "README-sync: mentions $kw" || no "README-sync: missing $kw"
done

# AC14: README "Principles Instantiated"가 네 사실을 각각 명시하는지 (섹션 스코프 — 헤더-satisfiable 회피)
pi_block="$(awk '/^## Principles Instantiated/{f=1;print;next} /^## /{f=0} f' "$README")"
{ [[ -n "$pi_block" ]] && grep -qE '라운드별 잠금|라운드마다 결정' <<<"$pi_block"; } \
  && ok "AC14/1: 라운드별 잠금 제거 명시" || no "AC14/1: 라운드별 잠금 제거가 없다"
grep -qE '일괄 확인|사용자 확인' <<<"$pi_block" \
  && ok "AC14/2: 종료 시 사용자 일괄 확인 명시" || no "AC14/2: 사용자 일괄 확인이 없다"
grep -qE 'payload.*audit|2파일|두 파일' <<<"$pi_block" \
  && ok "AC14/3: payload/audit 분리 명시" || no "AC14/3: payload/audit 분리가 없다"
grep -q 'user_sourced_items' <<<"$pi_block" \
  && ok "AC14/4: user_sourced_items 계약 명시" || no "AC14/4: user_sourced_items 계약이 없다"

# v0.23.0: README 서두가 산출물을 **2파일 쌍**으로 설명해야 한다. 이 문장은 오랫동안 "7-section
# 단일 파일"이라 적혀 있었고(옛 포맷), 어떤 assertion도 그걸 잡지 않았다 — AC14 블록만 잠겨 있어
# 서두는 무검증이었다. 사용자가 README "What it does"를 따라 쓰면 게이트가 거부하는 포맷이 나온다.
{ grep -qF '2파일 쌍' "$README" && grep -qF '.audit.md' "$README" \
    && grep -qF '8섹션' "$README"; } \
  && ok "v0.23.0: README 서두가 payload+audit 2파일 쌍을 설명" \
  || no "README 서두가 산출물을 2파일 쌍으로 설명하지 않는다"

# ── 삭제된 술어의 부재 + 그 양성 짝 (whole-branch 리뷰 I2) ────────────────────
# 위 스윕들은 전부 「이 키워드가 **있는가**」만 묻는다. 그래서 문서 리뷰 엔진 전환이
# 옛 stagnation 술어의 생산자와 소비자를 design doc 자리에서 통째로 걷어낸 뒤에도, 그
# 술어를 현재형으로 서술하는 README 줄이 그대로 살아남아 이 스위트를 통과했다 —
# 이 파일에 부재를 묻는 단언이 하나도 없었기 때문이다. 제거된 구성물이 표면에 남으면
# 그것은 오탈자가 아니라 **거짓 인용**이고, 다음 세션이 그 줄을 근거로 삼는다.
#
# **부재 단언에는 짝이 필요하다.** 「옛 이름이 없다」만 걸면 그 줄을 통째로 지워도
# 통과한다(부재는 대상을 삭제하면 언제나 참이다) — 모양만 있고 이빨은 없는 락이 된다.
# 그래서 같은 자리에서 「**지금** 술어를 이름으로 대는가」를 함께 잰다. 둘이 한 쌍이고,
# 한쪽만으로는 어느 방향도 못 잡는다:
#   · 옛 이름을 되살리면 → 부재 단언이 RED
#   · 지금 술어의 서술을 지우면 → 양성 짝이 RED
# 부재는 README **전체**에서 잰다(어느 절로 옮겨도 거짓 인용은 거짓 인용이다). 양성
# 짝은 그 술어가 사는 절로 좁힌다 — file-wide 면 다른 절의 우연한 언급이 만족시킨다.
absorb_block="$(awk '/^### Principles 흡수/{f=1;print;next} f && /^#/{f=0} f' "$README")"
if [[ -z "$absorb_block" ]]; then
  no "P18: 'Principles 흡수' 절을 못 찾았다 — 구조 앵커 파손(조용한 통과 금지)"
else
  ok "P18: 'Principles 흡수' 절 추출 ($(printf '%s\n' "$absorb_block" | wc -l | tr -d ' ')줄)"
  ABSORB_TMP="$(mktemp -t readme-absorb-XXXXXX)"
  printf '%s\n' "$absorb_block" > "$ABSORB_TMP"
  # 부재 — 엔진이 대체한 옛 술어의 두 카운터. 이 브랜치 이후 design doc 자리에는
  # 생산자도 소비자도 없다(구현은 brief 자리가 아직 쓰는 merge_review.py 하나뿐이고,
  # 이 플러그인 README 가 서술하는 자리에는 도달하지 않는다).
  if grep -qE 'raised_count|dismissed_by_user' "$README"; then
    no "P18/부재: 옛 stagnation 술어의 카운터 이름이 README 에 남아 있다 — 생산자도 소비자도 없는 술어를 현재형으로 서술한다(거짓 인용)"
  else
    ok "P18/부재: 옛 stagnation 술어의 카운터 이름이 README 에 없다"
  fi
  # 양성 짝 — 지금 술어를 실제 식별자로 댄다. 이게 없으면 위 부재 단언은 P18 줄을
  # 통째로 지우는 것만으로 만족된다.
  if grep -qF 'open_lineages' "$ABSORB_TMP" && grep -qF 'gate_summary' "$ABSORB_TMP"; then
    ok "P18/양성 짝: 지금 stagnation 술어(열린 계보 open_lineages · gate_summary)를 이름으로 댄다"
  else
    no "P18/양성 짝: 'Principles 흡수' 절이 지금 stagnation 술어를 이름으로 대지 않는다 — 부재 단언이 대상 삭제만으로 만족된다"
  fi
  rm -f "$ABSORB_TMP"
fi
finish
