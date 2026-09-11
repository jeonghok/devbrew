#!/usr/bin/env bash
# guards: plugins/spec-distill/**
#
# seed `@경로` 핸드오프 — framing 게이트(`/new`·`/compact` → `/interview @<seed 경로>`) ·
# 공유 계약의 권장/차선 핸드오프 · `/interview` Step 1.5 · 옛 호출 모양 부재 · 이름 가드 공백 거부.
#
# 정본 `references/proceed-gate.md` 에 대한 단언은 **정본 자체**를 대상으로 한다 — 채택자
# presence 코퍼스에 정본을 넣는 것이 아니다(그 코퍼스 규칙은 test_proceed_gate_adopters.sh 에 있다).
# 부재 단언에는 코퍼스를 실제로 읽었다는 양성 짝이 붙는다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT/plugins/spec-distill"
SK="$SD/skills/framing-requests/SKILL.md"
CANON="$SD/references/proceed-gate.md"
CMD="$SD/commands/interview.md"
RF="$SD/commands/request-framing.md"
README="$SD/README.md"
. "$ROOT/shared/tests/assert.sh"

# 부재 코퍼스: CHANGELOG 와 tests/ 를 뺀 이 플러그인의 문서 전부(추적 + 미추적).
CORPUS=()
while IFS= read -r f; do
  [ -n "$f" ] && CORPUS+=("$ROOT/$f")
done < <(cd "$ROOT" && git ls-files --cached --others --exclude-standard -- 'plugins/spec-distill/*.md' \
  | grep -vE '^plugins/spec-distill/(CHANGELOG\.md$|tests/)')

if [ "${1:-}" = "--emit-scanned" ]; then
  for f in "${CORPUS[@]+"${CORPUS[@]}"}"; do printf '%s\n' "${f#"$ROOT"/}"; done
  exit 0
fi

# 헤딩 블록: 시작 ERE 줄부터 다음 멈춤 ERE 줄 전까지.
block() { awk -v s="$1" -v e="$2" '$0 ~ s {f=1; print; next} f && $0 ~ e {f=0} f' "$3"; }
flat()  { tr '\n' ' ' | tr -s ' '; }

# ── /interview Step 1.5 와 「풀린 입력」 ───────────────────────────────────
l15="$(grep -n '^## Step 1[.]5' "$CMD" | head -1 | cut -d: -f1)"
l2="$(grep -n '^## Step 2: ' "$CMD" | head -1 | cut -d: -f1)"
if [ -n "$l15" ] && [ -n "$l2" ] && [ "$l15" -lt "$l2" ]; then
  ok "AC5: Step 1.5 가 Step 2 보다 앞에 있다 (${l15} < ${l2})"
else
  no "AC5: Step 1.5 가 Step 2 보다 앞에 있지 않다 (Step 1.5=${l15:-없음} Step 2=${l2:-없음})"
fi
s15="$(block '^## Step 1[.]5' '^## ' "$CMD" | flat)"
[ -n "$s15" ] && ok "AC5(양성): Step 1.5 블록을 읽었다" || no "AC5(양성): Step 1.5 블록이 없다 — 아래 단언이 공허하다"
assert_contains "$s15" '`@` 로 시작하는 **공백 없는 한 토큰**일 때만' "AC5: 발동 조건 — 한 토큰 @"
assert_contains "$s15" '**절대경로로** Read 도구에 넘긴다' "AC5: 동작 — Read"
assert_contains "$s15" '줄번호·탭 접두를 뗀 **파일 원문 전체(frontmatter 포함)**' "AC5: 풀린 입력 = frontmatter 포함 파일 전문"
assert_contains "$s15" '「풀린 입력」의 출처는 이 Read 결과다' "§3: 첨부가 따로 와도 출처는 Read 결과"
assert_contains "$s15" '를 읽지 못했다(<관측한 사유>) — seed 를 만든 워크트리 디렉토리에서 세션을 열었는지 확인하라. 인터뷰를 시작하지 않는다.' "AC5: 부재 문구"
assert_contains "$s15" '아래 문구를 내고 멈춘다. **인터뷰를 시작하지 않는다.**' "AC5: 정지 지시"
assert_contains "$s15" '발동하지 않았으면 「풀린 입력」은' "§3: 미발동이면 받은 입력 그대로"
s2="$(block '^## Step 2: ' '^## ' "$CMD" | flat)"
s25="$(block '^## Step 2[.]5' '^## ' "$CMD" | flat)"
s3="$(block '^## Step 3' '^## ' "$CMD")"
sa="$(block '^## Arguments' '^## ' "$CMD" | flat)"
assert_contains "$s2" '「풀린 입력」을 대조' "§3: Step 2 trivia 대조 대상 = 풀린 입력"
assert_contains "$s25" '「풀린 입력」의 frontmatter 에 `type: interview-seed`' "§3: Step 2.5 seed 판별 대상 = 풀린 입력"
assert_contains "$s3" 'Skill conducting-interview <풀린 입력>' "§3: Step 3 인자 = 풀린 입력"
[ -n "$s3" ] && ok "§3(양성): Step 3 블록을 읽었다" || no "§3(양성): Step 3 블록이 없다 — 아래 단언이 공허하다"
assert_not_contains "$s3" 'Skill conducting-interview $ARGUMENTS' "§3: Step 3 가 치환된 원 인자를 넘기지 않는다"
assert_contains "$sa" '「풀린 입력」 — Step 1.5 의 결과' "§3: Arguments 절이 풀린 입력을 가리킨다"

# ── framing 게이트: 옵션 표 · 호출 모양 · 두 가드 ──────────────────────────
call="$(block '^### 호출 모양' '^##' "$SK")"
rows="$(printf '%s\n' "$call" | grep -E '^\| [①②③④] \|')"
nrows="$(printf '%s\n' "$rows" | grep -c .)"
assert_eq "$nrows" "4" "AC1(양성): 호출 모양 절 옵션 표에서 행 4개를 읽었다"
r1="$(printf '%s\n' "$rows" | grep -E '^\| ① \|')"
r2="$(printf '%s\n' "$rows" | grep -E '^\| ② \|')"
for n in '`/new` 후' '`/interview @<seed 경로>`' '권장' '턴 종료'; do assert_contains "$r1" "$n" "AC1: ① 행에 $n"; done
for n in '`/compact` 후' '`/interview @<seed 경로>`' '턴 종료'; do assert_contains "$r2" "$n" "AC1: ② 행에 $n"; done
assert_not_contains "$r2" '권장' "AC1: 권장은 ① 하나"
assert_not_contains "$rows" '바로' "AC1: 옵션 표에 「바로」 진행 행이 없다"
cf="$(printf '%s\n' "$call" | flat)"
assert_contains "$cf" '`<seed 경로>` 는 `$SEED` 의 실제 값' "AC2: 자리표를 실제 값으로 치환하라는 지시"
assert_contains "$cf" '`/new` 뒤 같은 줄에' "AC2: /new 뒤 같은 줄에 붙이지 말라는 안내"
assert_contains "$cf" '세션 이름' "AC2: 같은 줄 텍스트가 세션 이름이 된다는 사실"
assert_contains "$cf" '명령 노출(①/②) 바로 앞' "§4: 핸드오프 직전 커밋 시점 = 명령 노출 바로 앞"
assert_not_contains "$cf" '<seed 전문>' "§1: 호출 모양 절에 옛 붙여넣기 자리표가 없다"

gb="$(block '^### 두 가드' '^##' "$SK")"
stop="$(printf '%s\n' "$gb" | awk '/^- \*\*cross-compact 조기 진행 금지\*\*/{f=1; print; next} f && /^- /{f=0} f' | flat)"
pol="$(printf '%s\n' "$gb" | awk '/^- \*\*polite stop 금지/{f=1; print; next} f && /^- /{f=0} f' | flat)"
[ -n "$stop" ] && ok "AC3(양성): 정지 가드 불릿을 읽었다" || no "AC3(양성): 정지 가드 불릿이 없다 — 아래 단언이 공허하다"
for n in '①/② 어느 쪽이든' '턴 종료(STOP)' '같은 턴에서 인터뷰를 시작하지 않습니다' '**다음 턴**' '사용자 트리거로만'; do
  assert_contains "$stop" "$n" "AC3: 정지 가드 한 불릿 안에 $n"
done
[ -n "$pol" ] && ok "§1(양성): polite stop 불릿을 읽었다" || no "§1(양성): polite stop 불릿이 없다 — 아래 단언이 공허하다"
assert_contains "$pol" '두 줄 명령을 노출하지 않고 설명만 하고 끝내는 것' "§1: 핸드오프 옵션의 polite stop 정의"
assert_not_contains "$gb" '다음 단계로 가지 않는 것은' "§1: 옛 polite stop 문면이 남지 않았다"

# ── 이름 가드: 공백 거부 — 문구가 아니라 case 패턴을 실제로 돌려 잰다 ──────
case_pat() { awk -v c="$1" 'index($0, c) {getline; print; exit}' "$SK" | sed -E 's/^[[:space:]]*//; s/\).*$//'; }
rejects()  { bash -c 'case "$2" in '"$1"') echo R ;; *) echo A ;; esac' _ "$1" "$2"; }
tp="$(case_pat 'case "$TOPIC" in')"
ip="$(case_pat 'case "$IV_NAME" in')"
{ [ -n "$tp" ] && [ -n "$ip" ]; } \
  && ok "이름 가드(양성): case 패턴 둘을 읽었다" \
  || no "이름 가드(양성): case 패턴을 못 읽었다 (TOPIC='${tp}' IV_NAME='${ip}') — 아래 단언이 공허하다"
assert_eq "$(rejects "$tp" 'umbrella-kiosk')" A "이름 가드(양성 짝): 공백 없는 kebab TOPIC 은 통과"
assert_eq "$(rejects "$tp" 'umbrella kiosk')" R "이름 가드: 공백 든 TOPIC 거부"
assert_eq "$(rejects "$tp" "$(printf 'umbrella\tkiosk')")" R "이름 가드: 탭 든 TOPIC 거부"
assert_eq "$(rejects "$tp" '<kebab-topic>')" R "이름 가드: 자리표 TOPIC 거부 (기존 동작 유지)"
assert_eq "$(rejects "$ip" '2026-09-10-umbrella-kiosk-interview')" A "이름 가드(양성 짝): 공백 없는 IV_NAME 은 통과"
assert_eq "$(rejects "$ip" '2026-09-10-umbrella kiosk-interview')" R "이름 가드: 공백 든 IV_NAME 거부"

# ── 공유 계약: 정본 자체에 대한 단언 ───────────────────────────────────────
stepb="$(block '^## Step B' '^## ' "$CANON")"
c1="$(printf '%s\n' "$stepb" | grep -E '^\| ① \|')"
c2="$(printf '%s\n' "$stepb" | grep -E '^\| ② \|')"
{ [ -n "$c1" ] && [ -n "$c2" ]; } && ok "AC4(양성): 정본 Step B 표 ①·② 행을 읽었다" || no "AC4(양성): 정본 Step B 표 ①·② 행이 없다 — 아래 단언이 공허하다"
assert_not_contains "$c1" '/compact' "AC4: Step B ① 행이 /compact 를 못박지 않는다"
assert_contains "$c1" '권장 핸드오프 — skill 이 정한 명령을 노출하고 **턴 종료**' "AC4: ① = 권장 핸드오프, 명령은 skill 이 정한다"
assert_contains "$c2" '차선 핸드오프 — skill 이 정한다' "§2: ② = 차선 핸드오프"
assert_contains "$c2" '바로 진행' "§2: ② 에 바로 진행 선택지가 있다"
fill="$(awk '/^\*\*각 skill 이 채우는 것\*\*/{f=1} f && /^$/{exit} f' "$CANON" | flat)"
assert_contains "$fill" '①/② 의 핸드오프 종류(`/compact` · `/new` · 바로 진행)와 노출할 명령' "§2: 각 skill 이 채우는 것에 핸드오프 종류"
stepa="$(block '^## Step A' '^## ' "$CANON" | flat)"
assert_contains "$stepa" '핸드오프 명령도 노출하지 않는다' "AC4: Step A — 핸드오프 명령도 노출하지 않는다"
assert_not_contains "$stepa" '`/compact` 도 노출하지 않는다' "AC4: Step A 옛 문면이 없다"
g1="$(block '^### 가드 1' '^##' "$CANON" | flat)"
assert_contains "$g1" '완료 동작은 핸드오프 종류가 정한다' "§2: 가드 1 — 완료 동작은 핸드오프 종류가 정한다"
g2="$(block '^### 가드 2' '^##' "$CANON" | flat)"
assert_contains "$g2" 'cross-compact 조기 진행 금지 (AC19)' "§2: 가드 2 제목 유지 (기존 인용이 가리키는 이름)"
assert_contains "$g2" '**명령을 노출하면 그 턴은 거기서 종료(STOP)한다.**' "AC4: 가드 2 — 명령 노출 → 턴 종료"
assert_contains "$g2" '바로 진행 옵션은 이 정지 요건의 **명시적 예외**다' "AC4: 가드 2 — 바로 진행 → 예외"
ver="$(block '^## 검증' '^## ' "$CANON" | flat)"
assert_contains "$ver" '명령을 노출하는 각 옵션의 서술 *블록 안에서*' "§2: 검증 절 리뷰 레이어 = 명령 노출 옵션마다"
assert_contains "$ver" '「호출 모양」 절 옵션 표 ①·② 행' "§2: 앵커 절 — framing 앵커에 ② 행"

# ── 옛 호출 모양 부재(코퍼스 전수) + 새 모양 실재 ──────────────────────────
ncorp="${#CORPUS[@]}"
for need in "$SK" "$CMD" "$RF" "$README" "$CANON"; do
  case " ${CORPUS[*]+"${CORPUS[*]}"} " in
    *" $need "*) ok "AC6(양성): 코퍼스에 ${need#"$ROOT"/} 가 들어 있다" ;;
    *) no "AC6(양성): 코퍼스에 ${need#"$ROOT"/} 가 없다 — 부재 단언이 그 파일을 안 본다" ;;
  esac
done
old_hits="$(grep -nF -e '<seed 전문>' -e '<seed 파일 전문>' -- "${CORPUS[@]+"${CORPUS[@]}"}" 2>&1)"; grc=$?
if [ "$ncorp" -eq 0 ]; then
  no "AC6: 코퍼스 0개 — 부재를 잴 수 없다"
elif [ "$grc" -ge 2 ]; then
  no "AC6: grep 실패(rc=$grc) — 부재를 확인하지 못했다: $old_hits"
elif [ -n "$old_hits" ]; then
  no "AC6: 옛 호출 모양이 남았다:"; printf '%s\n' "$old_hits"
else
  ok "AC6: 옛 호출 모양(<seed 전문> · <seed 파일 전문>) 0건 — 문서 ${ncorp}개"
fi
for f in "$SK" "$RF" "$CMD" "$README"; do
  assert_file_grep "$f" '/interview @<seed 경로>' "AC6: 새 모양이 ${f#"$ROOT"/} 에 있다"
done

# ── 풀어 쓴 옛 서술의 동기화 (§4 목록) ──────────────────────────────────
TPL="$SD/templates/interview-seed-audit-template.md"
SEEDIN="$SD/skills/conducting-interview/references/seed-input.md"
FIN="$SD/skills/conducting-interview/references/finishing.md"
assert_file_grep   "$TPL"    '/interview @<seed 경로>` 가 가리키는 것은 payload' "§4: audit 템플릿 인용 블록이 새 모양"
assert_file_absent "$TPL"    '첫 턴에 붙여넣는' "§4: audit 템플릿에 옛 핸드오프 서술이 없다"
assert_file_grep   "$SEEDIN" '`/interview @<seed 경로>` 를 치게 하고' "§4: seed-input 도착 경로가 새 모양"
assert_file_absent "$SEEDIN" '붙여넣게 하고' "§4: seed-input 에 옛 도착 경로가 없다"
assert_file_grep   "$FIN"    '`@경로` 를 풀어 넘겼든 사용자가 전문을 붙여넣었든' "§4: finishing S1 문장이 두 도착 경로를 다 적는다"
assert_file_absent "$RF"     '붙여넣' "§4: request-framing 에 붙여넣기 핸드오프 서술이 없다"
assert_file_absent "$README" '다음 세션 첫 턴에 붙여넣는 메시지' "§4: README 흐름도에 옛 서술이 없다"

finish
