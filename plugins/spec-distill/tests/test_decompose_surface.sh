#!/usr/bin/env bash
# R4 분해 판단 · 재분해 문면 락(AC1 · AC2 · AC3 · AC7 · AC8 · AC11).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_decompose_surface.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SD="$ROOT/plugins/spec-distill"
FIN="$SD/skills/pm-interview/references/finishing.md"
SKILL="$SD/skills/pm-interview/SKILL.md"
TPL="$SD/templates/interview-brief-template.md"

win() {  # win <파일> <시작 줄 리터럴> <끝 줄 접두> — 시작 줄 다음부터 끝 줄 앞까지
  awk -v s="$2" -v e="$3" '$0==s{f=1;next} f&&index($0,e)==1{exit} f' "$1"
}
has() {  # has <창> <리터럴> <라벨>
  case "$1" in *"$2"*) ok "$3" ;; *) no "$3 — 없음: $2" ;; esac
}
assert_file_has() {  # assert_file_has <파일> <고정 문자열> <라벨>
  if grep -qF -- "$2" "$1" 2>/dev/null; then ok "$3"; else no "$3 — 없음: $2"; fi
}

# ── AC1 · AC2 — 분해 판단 단계 ──────────────────────────────────────────────
DEC="$(win "$FIN" '### 분해 판단 — Step A 직전' '### Step A')"
if [ -n "$DEC" ]; then ok "분해 판단 절이 Step A 앞에 있다"; else no "분해 판단 절 창이 비었다 — 앵커 파손"; fi
for lit in '따로 승인할 수 있는 덩어리 수' '파일 영역 수' '사용자 원문 갈래 수' '근거 번호' \
           '컷오프는 두지 않는다' '하나로 충분해 보인다' '나누는 게 좋아 보인다' \
           '"spec 하나로"' '"나눈다 — 분해안 보기"' \
           '| 번호 | 이름 | 종류 | 의도 | 범위 | 의존 | 브랜치 | 경로 예약 | 배정 번호 | 받는 것 | 넘기는 것 |' \
           '「묶음」' '「브랜치 <설계문서 경로>」' '「결정」' '걷는 뼈대' \
           '미배정 번호 <n> · 고아 발화 <m>' '「승인」' '「고치기」' '「spec 하나로」' '계속 고칠까요' \
           '자동으로 끝내지 않는다' '## 분해안' '분해됨 — <로드맵 경로>'; do
  has "$DEC" "$lit" "분해 판단: $lit"
done
# 부재 · 존재 짝 — 숫자 컷오프 문면이 없다(존재 짝은 위 「컷오프는 두지 않는다」).
cut="$(printf '%s\n' "$DEC" | grep -nE '[0-9]+ ?(개|곳|갈래|영역|덩어리)( 이상| 넘| 초과|보다 많)' || true)"
assert_eq "$cut" "" "분해 판단: 숫자 컷오프 문면이 없다"
assert_file_absent "$FIN" '이상이면 나눈다' "finishing: 「이상이면 나눈다」 문면이 없다"

# ── AC3 · AC4 — 생성 · 재생성 ───────────────────────────────────────────────
STEPA="$(win "$FIN" '### Step A — brief 작성 (terminal 산출물, 2파일)' '### Step A.5')"
has "$STEPA" 'roadmap_write.py" create' "Step A: 생성기 create 를 부른다"
has "$STEPA" '--plan-table' "Step A: 분해안 표를 넘긴다"
has "$STEPA" '분해 판단 3' "Step A: 실패하면 분해안 표로 돌아간다"
REGEN="$(win "$FIN" '#### B-R — 로드맵 다시 생성 (분해된 일만)' '#### ')"
if [ -n "$REGEN" ]; then ok "Step B: 다시 생성 절이 있다"; else no "Step B: B-R 창이 비었다"; fi
for lit in 'brief 를 마지막으로 쓴 직후' '언제나 한 번' '항목이 바뀌었는지와 상관없다' '## 생성 기록' \
           '커밋 전에 도는 단계'; do
  has "$REGEN" "$lit" "B-R: $lit"
done
# R7 이음매 — 분해안 표 · 생성 기록은 docs 상태 파일(<줄기>.state.md)에 산다. 세션 폴더의 옛 이름을 넘기지 않는다.
has "$STEPA" '--plan-table "${BRIEF_REL%.md}.state.md"' "Step A 8: --plan-table 은 brief 줄기의 docs 상태 파일"
has "$STEPA" '--audit "${BRIEF_REL%.md}.audit.md"' "Step A 8: --audit 도 같은 줄기에서"
# AC11 — Step A 8 의 제목 · 승인 원문은 heredoc 으로 들어가 인자에서 한 낱말로 남는다.
for lit in "IFS= read -r title <<'DEVBREW_ROADMAP_TITLE_EOF'" '<주제 한 줄>' \
           "cat > \"\$AF1\" <<'DEVBREW_ROADMAP_APPROVAL_EOF'" '<승인 원문>' \
           '--title="$title"' '--approval="$(cat "$AF1")"' "trap 'rm -rf -- \"\$AD\"' EXIT" 'AF1="$AD/1"' \
           '그 자리의 여는 줄과 닫는 줄의 구분자를 글에 없는 다른 낱말로 함께 바꾼다' \
           '`AF2` · `AF3` … 으로 하나씩 더하고' '`DEVBREW_ROADMAP_APPROVAL_EOF`' \
           '펜스 줄과 더하는 `AF<k>` 줄은 맨 앞 칸에서 시작한다'; do
  has "$STEPA" "$lit" "Step A 8(AC11): $lit"
done
for lit in '--title "<주제 한 줄>"' '--approval "<승인 원문>"'; do
  case "$STEPA" in *"$lit"*) no "Step A 8(AC11): 옛 인자 꼴이 남아 있다: $lit" ;; *) ok "Step A 8(AC11): 옛 인자 꼴 없음: $lit" ;; esac
done
assert_file_absent "$FIN" 'session-id>/state\.local\.md' "finishing: 세션 폴더의 옛 상태 파일 경로가 없다"
# R7 이음매 — 로드맵 폴더는 끝내기 커밋 펜스(interview-commit)의 경로 지정에 «있을 때만» 든다. 손 커밋 안내 줄은 없다.
CF="$(awk 'index($0,"<!-- interview-commit:begin -->"){f=1;next} index($0,"<!-- interview-commit:end -->"){f=0} f' "$FIN")"
# 로드맵 폴더는 모델이 채우는 자리표가 아니라 brief §7 의 첫 `분해됨 — <로드맵 경로>` 줄에서 펜스가 도출한다.
case "$CF" in *'RDIR="<'*) no "커밋 펜스: 로드맵 폴더가 모델이 채우는 자리표다" ;; *) ok "커밋 펜스: 로드맵 폴더 자리표가 없다(도출)" ;; esac
has "$CF" "r7=\"\$(awk -v p='분해됨 — ' 'index(\$0,\"## 7.\")==1{f=1;next} f&&/^## /{exit}" "커밋 펜스: brief §7 의 분해됨 줄에서 도출"
has "$CF" '[ "$(dirname -- "$RDIR")" = "${top}/docs/superpowers/roadmaps" ]' "커밋 펜스: 로드맵 폴더의 부모는 docs/superpowers/roadmaps"
has "$CF" 'case "$r7" in */roadmap.md) ;; *) r_err=' "커밋 펜스: §7 경로는 roadmap.md 로 끝난다"
has "$CF" '[ -d "$RDIR" ] || r_err=' "커밋 펜스: 로드맵 폴더 자리는 폴더다"
has "$CF" 'if [ -e "$RDIR" ] || [ -L "$RDIR" ]; then' "커밋 펜스: 없는 로드맵 폴더는 빼고 진행한다"
has "$CF" 'git -C "$top" add -- "$BRIEF" "$AUDIT_F" "$STATE_F" ${RDIR:+"$RDIR"} || c_rc=$?' "커밋 펜스: add 경로 지정에 로드맵 폴더(있을 때만)"
has "$CF" '-- "$BRIEF" "$AUDIT_F" "$STATE_F" ${RDIR:+"$RDIR"} || c_rc=$?' "커밋 펜스: commit 경로 지정에 로드맵 폴더(있을 때만)"
has "$CF" 'path-inside --root "$top" "$BRIEF" "$AUDIT_F" "$STATE_F" ${RDIR:+"$RDIR"}; then' "커밋 펜스: 로드맵 폴더도 path-inside 로 잰다"
n_unq="$(printf '%s\n' "$CF" | grep -cE '"\$STATE_F" "\$RDIR"' || true)"
assert_eq "$n_unq" "0" "커밋 펜스: 로드맵 폴더를 조건 없이 넣는 경로 지정이 없다"
assert_file_absent "$FIN" '함께 커밋하라 —' "finishing: 손 커밋 안내 줄(「…함께 커밋하라 — <경로들>」)이 없다"
assert_file_absent "$FIN" 'git 이 무시하는 자리' "finishing: 상태 파일이 git 무시 자리일 수 있다는 줄이 없다"
has "$REGEN" 'brief §7 의 `분해됨 — <로드맵 경로>` 줄에서 로드맵 폴더를 도출해' "B-R: 커밋 펜스가 §7 에서 로드맵 폴더를 도출한다고 가리킨다"
has "$REGEN" '로드맵 다시 생성이 멈췄다. 고친 뒤 직접 커밋하라: <brief 경로> · <audit 경로> · <상태 파일 경로> · <로드맵 폴더>' "B-R: 멈춤에 「커밋하지 않았다」 줄(네 경로)"
has "$REGEN" 'rc 2 는 사용법 오류다' "B-R: rc 2 의 처리"
assert_file_absent "$FIN" '빼고 커밋한다' "finishing: 「빼고 커밋한다」 대신 「빼고 진행한다」"
B1="$(win "$FIN" '#### B-1 — superpowers 가용성 분기' '#### ')"
has "$B1" 'brief · audit · 상태 파일 · 로드맵 폴더(<Step A 8 의 --out 값>)는 커밋하지 않았다' "B-1: 분해된 일의 미커밋 안내에 로드맵 폴더"
# 리뷰 보강(I1) — B-A 가 더한 번호로 rc 1: 생성만 다시 돌고 A.5 · 게이트는 다시 없다
for lit in 'Step A 8 의 명령**만** 다시 돌린 뒤' 'Step A.5 리뷰를 다시 돌리지 않고 Step B 게이트도 다시 띄우지 않는다' \
           '`## 생성 기록` 에 적힌 파일' '`분해됨 — <로드맵 경로>` 줄을 뺀 뒤' '표로 고칠 수 없는 사유'; do
  has "$REGEN" "$lit" "B-R(I1): $lit"
done
assert_file_absent "$FIN" '항목이 바뀌면 확정 직후' "옛 「항목이 바뀌면」 재생성 조건이 없다"

# ── AC7 — 분해된 일의 다음 세션 줄 ──────────────────────────────────────────
MARK='**다음 세션 줄 — 분해된 일 ①/② 공통**'
DLINE="$(awk -v m="$MARK" '$0==m{f=1;next} f&&NF{print;exit}' "$FIN")"
case "$DLINE" in
  '`/spec-distill:epic-conductor <roadmap-path>`') ok "분해된 일: 다음 세션 줄이 지휘자 호출" ;;
  *) no "분해된 일: 다음 세션 줄이 다르다: $DLINE" ;;
esac
n_brief="$(grep -cE '^[[:space:]]*> `(@<[^<>]+> )+이 interview brief 로' "$FIN" || true)"
assert_eq "$n_brief" "1" "나누지 않은 일의 brief 줄은 그대로 하나"

# ── SKILL · 템플릿 ──────────────────────────────────────────────────────────
assert_file_has "$SKILL" "「분해 판단」 단계부터" "SKILL: 종료 뒤 분해 판단을 가리킨다"
assert_file_has "$TPL" "분해됨 — <로드맵 경로>" "brief 템플릿 §7: 분해 줄"

# ── AC8 — 재분해 참조 ──────────────────────────────────────────────────────
RED="$SD/references/redecompose.md"
if [ -f "$RED" ]; then ok "redecompose.md 실재"; else no "redecompose.md 없음"; fi
RTXT="$(cat "$RED" 2>/dev/null)"
for lit in '빠짐 · 축소 · 여러 spec' '게이트 ③' '「인터뷰 다시 열기」' '지휘 세션' \
           'roadmap_write.py" extract' '`## 분해안`' \
           '| 에픽 | 바뀌는 것 | 옮겨 가는 번호 | 새 의존 | 진행 중인 브랜치 · 설계문서 |' \
           '"이대로 다시 나눈다"' '"고치기"' '"그만둔다"' \
           'R<max+1>' '사라지는 번호는 재사용하지 않는다' '머지되거나 끝난 에픽은 건드리지 않는다' '## 미룸' \
           'roadmap_write.py" update' '재분해 이력' 'feature/roadmap-<요지>' '원래 바이트'; do
  has "$RTXT" "$lit" "redecompose: $lit"
done

# 리뷰 보강(I2 · I3 · I4) — 재분해 끝내기 · 전용 브랜치 · 상태 파일 표 갱신
for lit in '새로 fetch 한 `origin/main` 에서 `feature/roadmap-<요지>` 브랜치를 전용 worktree' \
           '에픽의 feature 브랜치(진행 중인 설계문서가 있는 브랜치)는 고치지 않는다' \
           '## 7. 끝내기' '`check_bundle_coverage.py <묶음> <설계문서>` 를 먼저 돌려' 'spec-review 를 다시 돌린다' \
           'spec-review 게이트 ③ 의 후속 질문' '`## 분해안` 표를 `roadmap_write.py extract` 출력으로 바꿔 둔다' \
           '머지되거나 끝난 에픽'; do
  has "$RTXT" "$lit" "redecompose(리뷰): $lit"
done
# R7 이음매 — 재분해 표는 세션 상태 폴더(ledger_sweep 이 TTL 뒤 지우는 옛 자리)가 아니라 펜스의 임시 파일에 산다.
assert_file_absent "$RED" 'session-id>/redecompose-table|state_path\.py" state-root' "redecompose: 세션 상태 폴더에 표를 쓰지 않는다"
for lit in 'TABLE="$(mktemp "${TMPDIR:-/tmp}/redecompose-table.XXXXXX")"' '--plan-table "$TABLE"' 'rm -f -- "$TABLE"'; do
  has "$RTXT" "$lit" "redecompose: 표는 임시 파일 — $lit"
done

# ── R3 넘김 — 분해된 일의 설계는 에픽 넘김 줄 · --bundle 로 ──────────────────
RTPL="$SD/templates/roadmap-template.md"
CONDUCT="$(win "$RTPL" '## 지휘 절차' '## ')"
for lit in '/spec-distill:epic-conductor {{ROADMAP}}' '손으로 따르는 절차' '실행 방식은 writing-plans 가 권하는 방식이고, 계획 검토는 계획에 설계에 없던 결정이 있을 때만 기다린다.'; do
  has "$CONDUCT" "$lit" "로드맵 템플릿 지휘 절차: $lit"
done
for lit in '`--bundle <묶음의 레포 상대경로>` 를 붙여 spec-review 를 다시 돌린다' \
           '`${CLAUDE_PLUGIN_ROOT}/references/epic-handoff.md` 의 에픽 넘김 줄로 연다' \
           '`## 미룸` 표(칸: 항목 · 이유 · 받는 곳'; do
  has "$RTXT" "$lit" "redecompose(R3 넘김): $lit"
done
EH_LINE="$(grep -m1 '^> `@<bundle-abs>' "$SD/references/epic-handoff.md")"
has "$EH_LINE" 'roadmap 에 <roadmap-rel> 을 적는다' "에픽 넘김 줄: 설계문서 frontmatter roadmap(게이트 ③ 의 열쇠)"

# ── R5 계획 2 AC32 — 재분해 신호는 열린 목록 · 이력 설명은 새 꼴 ──────────────────
SIG="$(win "$RED" '## 1. 신호' '## ')"
for lit in '목록은 닫혀 있지 않다' '에픽 설계 세션' '계획 · 구현 세션' '경계를 스스로 고치지 않고 보고한다' \
           '「이 에픽 다시 설계」 로 가고 이 절차로 오지 않는다'; do
  has "$SIG" "$lit" "AC32: 재분해 신호 — $lit"
done
for lit in '- 에픽 설계 세션 —' '- 계획 · 구현 세션 —'; do
  has "$SIG" "$lit" "AC32: 재분해 신호 불릿 꼴 — $lit"
done
RED_ALL="$(cat "$RED")"
case "$RED_ALL" in *'이력에 한 줄'*) no "재분해 이력: 파일 어디에도 옛 「이력에 한 줄」 이 남았다" ;; *) ok "재분해 이력: 옛 「이력에 한 줄」 이 파일 어디에도 없다" ;; esac
has "$RED_ALL" '재분해 이력에 항목 하나를 남긴다' "재분해 이력: 선택지 설명도 새 꼴(양성 짝)"
case "$SIG" in *'신호는 셋이다'*) no "AC32: 닫힌 「셋」 목록 문장이 남았다" ;; *) ok "AC32: 닫힌 「셋」 목록 문장이 없다(양성 짝: 열린 목록)" ;; esac
APPLY="$(win "$RED" '## 5. 적용' '## ')"
for lit in '`### <날짜> · <사유>`' '`- 바뀜:`' '`- 원문:`' '원문 칸에는 사용자 말만 둔다' \
           '--change="$change_line"' '<사유 한 줄>' '--approval="$(cat "$AF1")"' '<사용자 말 그대로>' '사용자 말이 여럿이면 `--approval` 을 말마다 하나씩'; do
  has "$APPLY" "$lit" "재분해 이력 새 꼴: $lit"
done
case "$APPLY" in *'재분해 이력에 한 줄('*) no "재분해 이력: 옛 한 줄 꼴 설명이 남았다" ;; *) ok "재분해 이력: 옛 한 줄 꼴 설명이 없다(양성 짝: 새 꼴)" ;; esac
FIN7="$(win "$RED" '## 7. 끝내기' '## ')"
has "$FIN7" '(「지적대로 고치기」 · 「이 에픽 다시 설계」 · 「인터뷰 다시 열기」 · 「직접 편집」 네 갈래)' "AC33: 재분해 7 이 게이트 ③ 의 네 갈래로 돌아간다"
case "$FIN7" in *'세 갈래)'*) no "AC33: 재분해 7 에 옛 「세 갈래」가 남았다" ;; *) ok "AC33: 재분해 7 에 옛 「세 갈래」가 없다(양성 짝: 네 갈래)" ;; esac
assert_file_has "$SD/references/epic-handoff.md" '게이트 ③ 에서 「이 에픽 다시 설계」 와 재분해 갈래를 연다' "AC33: 넘김 줄 자리표 설명이 게이트 ③ 의 두 갈래를 말한다"
UP="$(win "$RED" '## 6. 올리기' '## ')"
has "$UP" '`${CLAUDE_PLUGIN_ROOT}/references/conducting.md` 의 손 절차 6' "재분해 6: 손 절차를 가리킨다"
case "$UP" in *'(지휘 절차 6)'*) no "재분해 6: 로드맵의 지휘 절차를 가리키는 옛 꼬리가 남았다" ;; *) ok "재분해 6: 옛 꼬리가 없다" ;; esac

# ── AC11 — 재결정 규약 한 줄 ────────────────────────────────────────────────
PG="$SD/references/proceed-gate.md"
P23="$(win "$PG" '## 재결정 규약 (P23)' '## ')"
has "$P23" '분해 단위의 변경은 `${CLAUDE_PLUGIN_ROOT}/references/redecompose.md` 로' "proceed-gate: 재결정 규약 절에 분해 단위 한 줄"
has "$P23" '보고 후 재결정 허용' "proceed-gate: 확정 항목 단위 규약은 그대로"

# ── AC11 e2e — Step A 8 펜스를 잘라 셸 메타문자가 든 제목 · 승인 원문으로 돈다 ──────
FENCE="$(win "$FIN" '### Step A — brief 작성 (terminal 산출물, 2파일)' '### Step A.5' \
  | awk 'index($0,"```bash"){b=""; f=1; next} index($0,"```")&&f{f=0; if(index(b,"roadmap_write.py\" create")){print b; exit}; next} f{b=b $0 "\n"}')"
if [ -n "$FENCE" ]; then ok "Step A 8 펜스를 잘랐다"; else no "Step A 8 펜스를 자르지 못했다"; fi
# heredoc 여는 줄마다 같은 구분자만 든 닫는 줄이 펜스에 있다 — 앞에 칸이 붙은 닫는 줄은 heredoc 을 닫지 못한다.
hd="$(printf '%s\n' "$FENCE" | awk -v q="'" '
  match($0, "<<" q "[A-Za-z_][A-Za-z0-9_]*" q) { d = substr($0, RSTART + 3, RLENGTH - 4); open[d] = 1; n++; next }
  ($0 in open) { closed[$0] = 1 }
  END { bad = ""; for (d in open) if (!(d in closed)) bad = bad " " d; printf "%d%s", n, bad }')"
assert_eq "$hd" "2" "Step A 8: heredoc 둘의 닫는 구분 줄이 줄 맨 앞에 있다"
e2e_run() {  # e2e_run <제목> <승인 원문> <결과 폴더 이름> — stdout: rc, 결과 폴더는 $E/repo/docs/<이름>. 펜스는 쓰인 그대로 돈다.
  local title="$1" appr="$2" outn="$3" body rc=0
  body="$FENCE"
  body="${body//<주제 한 줄>/$title}"
  body="${body//<승인 원문>/$appr}"
  body="${body//docs\/superpowers\/interview\/<file>/docs/iv/brief.md}"
  body="${body//docs\/superpowers\/roadmaps\/<YYYY-MM-DD>-<주제 또는 주제-HHMM>\//docs/$outn/}"
  body="${body//<YYYY-MM-DD>/2026-10-21}"
  printf '%s\n' "$body" > "$E/fence.sh"
  (cd "$E/repo" && CLAUDE_PLUGIN_ROOT="$SD" PYTHONDONTWRITEBYTECODE=1 /bin/bash "$E/fence.sh") > "$E/out.txt" 2>&1 || rc=$?
  echo "$rc"
}
E="$(mktemp -d)" || exit 1
[ -n "$E" ] && [ -d "$E" ] || exit 1
trap 'rm -rf "$E"' EXIT
mkdir -p "$E/repo/docs/iv"
cat > "$E/repo/docs/iv/brief.md" <<'MD'
---
type: interview-brief
user_sourced_items:
  - id: C1
    statement: "첫 확정"
---

# 픽스처 brief

## 0. 한눈에

**결정 목록**

- OQ1 [열림] — 열린 하나

## 1. Goal · Non-goal

- Goal: 목표.

## 2. 제약

- 🗣 confirmed **C1** — 첫 확정 ⟨S1⟩

## 3. Open Questions

- OQ1: 열린 하나

## 4. External Landscape

- 바깥 하나 «ext-a» — [취함] [→ OQ1]

## 5. 기각 · Blind Spots

- 위험 — 숨은 가정: 가정 — 근거 약함

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > 처음 말

## 7. Next Action

다음.
MD
printf '# audit\n\n## 6. 사용자 원문\n\n- **S2** 🗣 발화 (round 1):\n  > 둘째 말\n' > "$E/repo/docs/iv/brief.audit.md"
printf '# state\n\n## 분해안\n\n%s\n%s\n%s\n' \
  '| 번호 | 이름 | 종류 | 의도 | 범위 | 의존 | 브랜치 | 경로 예약 | 배정 번호 | 받는 것 | 넘기는 것 |' \
  '|---|---|---|---|---|---|---|---|---|---|---|' \
  '| E1 | 첫 에픽 | 묶음 | 첫 의도 | 한다 가 / 안 한다 나 | 없음 | feature/e1 | a/x.py | C1 · OQ1 · K1 · «ext-a» · S1 · S2 | 없음 | 없음 |' \
  > "$E/repo/docs/iv/brief.state.md"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
git init -q -b main "$E/repo"
git -C "$E/repo" -c user.name=t -c user.email=t@example.invalid add -A
git -C "$E/repo" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false commit -qm fixture
HOSTILE_TITLE='-제목 $HOME `id` "q" '"'a'"
HOSTILE_APPR='-승인 $(touch '"$E"'/pwned) "좋아" '"'ok'"
assert_eq "$(e2e_run "$HOSTILE_TITLE" "$HOSTILE_APPR" rm1)" "0" "stepa8_e2e_verbatim: 펜스 rc 0"
RMALL="$(cat "$E"/repo/docs/rm1/*.md 2>/dev/null)"
case "$RMALL" in *"$HOSTILE_TITLE"*) ok "stepa8_e2e_verbatim: 제목이 글자 그대로 실렸다" ;; *) no "stepa8_e2e_verbatim: 제목이 그대로 실리지 않았다" ;; esac
case "$RMALL" in *"「${HOSTILE_APPR}」"*) ok "stepa8_e2e_verbatim: 승인 원문이 글자 그대로 실렸다" ;; *) no "stepa8_e2e_verbatim: 승인 원문이 그대로 실리지 않았다" ;; esac
if [ -e "$E/pwned" ]; then no "stepa8_e2e_verbatim: 승인 원문 속 명령이 실행됐다(pwned)"; else ok "stepa8_e2e_verbatim: pwned 파일 없음"; fi
# 생성기는 승인 말 하나를 한 줄로만 받는다 — 두 줄 말은 변형 · 실행 없이 생성기가 그대로 거절한다(rc 1, 아무것도 만들지 않는다).
ML_APPR="$(printf '첫 줄 $(touch %s/pwned2)\n둘째 줄 `id`' "$E")"
assert_eq "$(e2e_run '여러 줄 시험' "$ML_APPR" rm2)" "1" "stepa8_multiline_approval_verbatim: 두 줄 말은 생성기가 거절한다(rc 1)"
case "$(cat "$E/out.txt")" in *'원문은 한 줄이고'*'첫 줄 $(touch '*) ok "stepa8_multiline_approval_verbatim: 거절 사유가 두 줄 말을 글자 그대로 보인다" ;; *) no "stepa8_multiline_approval_verbatim: 거절 사유에 두 줄 말이 그대로 없다" ;; esac
if [ -e "$E/pwned2" ]; then no "stepa8_multiline_approval_verbatim: 명령이 실행됐다(pwned2)"; else ok "stepa8_multiline_approval_verbatim: pwned2 파일 없음"; fi
if [ -e "$E/repo/docs/rm2" ]; then no "stepa8_multiline_approval_verbatim: 거절됐는데 폴더가 남았다"; else ok "stepa8_multiline_approval_verbatim: 거절되면 폴더를 만들지 않는다"; fi
# 줄마다 AF<k> 로 나누면(여러 말 규칙) 두 줄이 각자 한 말로 그대로 실린다.
FENCE_ONE="$FENCE"
AF_BLOCK='AF2="$AD/2"
cat > "$AF2" <<'"'"'DEVBREW_ROADMAP_APPROVAL_EOF'"'"'
<둘째 말>
DEVBREW_ROADMAP_APPROVAL_EOF
'
FENCE="${FENCE/
c_rc=0/
${AF_BLOCK}c_rc=0}"
case "$FENCE" in *'AF2="$AD/2"'*) ok "stepa8_multiline_approval_verbatim: AF2 블록이 펜스에 들어갔다" ;; *) no "stepa8_multiline_approval_verbatim: AF2 블록을 넣지 못했다 — 아래 판정은 무의미하다" ;; esac
FENCE="${FENCE/--approval=\"\$(cat \"\$AF1\")\"/--approval=\"\$(cat \"\$AF1\")\" --approval=\"\$(cat \"\$AF2\")\"}"
SECOND='둘째 줄 $(touch '"$E"'/pwned3) `id`'
FENCE="${FENCE//<둘째 말>/$SECOND}"
assert_eq "$(e2e_run '두 말 시험' '첫 줄 "q"' rm3)" "0" "stepa8_multiline_approval_verbatim: 줄마다 AF<k> 로 나누면 rc 0"
RMALL3="$(cat "$E"/repo/docs/rm3/*.md 2>/dev/null)"
case "$RMALL3" in *'「첫 줄 "q"」'*"「${SECOND}」"*) ok "stepa8_multiline_approval_verbatim: 두 말이 각자 글자 그대로 실렸다" ;; *) no "stepa8_multiline_approval_verbatim: 두 말이 그대로 실리지 않았다" ;; esac
if [ -e "$E/pwned3" ]; then no "stepa8_multiline_approval_verbatim: 명령이 실행됐다(pwned3)"; else ok "stepa8_multiline_approval_verbatim: pwned3 파일 없음"; fi
FENCE="$FENCE_ONE"

finish
