#!/usr/bin/env bash
# guards: plugins/spec-distill/references/proceed-gate.md plugins/spec-distill/skills/pm-interview/references/finishing.md plugins/spec-distill/templates/interview-brief-template.md plugins/spec-distill/skills/pm-interview/SKILL.md plugins/spec-distill/references/epic-handoff.md plugins/spec-distill/references/trivia-escape.md plugins/spec-distill/agents/steelman-builder.md plugins/spec-distill/skills/pm-interview/references/steelman.md plugins/spec-distill/skills/request-framing/SKILL.md plugins/spec-distill/scripts/roadmap_render.py plugins/spec-distill/scripts/roadmap_model.py plugins/spec-distill/CHANGELOG.md plugins/spec-distill/README.md
#
# R10 계획 2 — 끝 게이트: 정본의 둘째 질문(선택) · 인터뷰 끝 ①② 이름 표 · 다른 다음 단계의 줄.
# 정적 락이다 — 모델이 이 문면을 실제로 따르는지는 재지 못한다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT/plugins/spec-distill"
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/references/proceed-gate.md"
  echo "plugins/spec-distill/skills/pm-interview/references/finishing.md"
  echo "plugins/spec-distill/templates/interview-brief-template.md"
  echo "plugins/spec-distill/skills/pm-interview/SKILL.md"
  echo "plugins/spec-distill/references/epic-handoff.md"
  echo "plugins/spec-distill/references/trivia-escape.md"
  echo "plugins/spec-distill/agents/steelman-builder.md"
  echo "plugins/spec-distill/skills/pm-interview/references/steelman.md"
  echo "plugins/spec-distill/skills/request-framing/SKILL.md"
  echo "plugins/spec-distill/scripts/roadmap_render.py"
  echo "plugins/spec-distill/scripts/roadmap_model.py"
  echo "plugins/spec-distill/CHANGELOG.md"
  echo "plugins/spec-distill/README.md"
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }
win() { awk -v a="$2" -v b="$3" '$0 ~ a {f=1; print; next} f && $0 ~ b {f=0} f' "$1" | tr '\n' ' ' | tr -s ' '; }
PG="$SD/references/proceed-gate.md"; FIN="$SD/skills/pm-interview/references/finishing.md"
# AC17(정본) — Step B 안에 있다(다음 세션 명령 절 앞)
STEPB="$(win "$PG" '^## Step B' '^## ')"
[ -n "$STEPB" ] && ok "AC17(양성 대조): 정본 Step B 를 떴다" || no "AC17: 정본 Step B 부재"
for lit in '**둘째 질문(선택) — 다음 단계 갈래.**' '머리글은 「다음 단계 갈래」' \
           '첫 질문의 네 선택지 · 순서 · `(권장)` 은 그대로다' '①/② 의 이름과 설명은 특정 단계를 가리키지 않는다' \
           '제안이 없으면 둘째 질문도 없다' '`## 다음 세션 명령` 규칙 3 대로'; do
  assert_contains "$STEPB" "$lit" "AC17(정본): «${lit}»"
done
B2="$(win "$FIN" '^#### B-2' '^#### ')"; B3="$(win "$FIN" '^#### B-3' '^#### ')"
[ -n "$B2" ] && [ -n "$B3" ] && ok "양성 대조: B-2 · B-3 를 떴다" || no "B-2 · B-3 부재"
# AC21 — 분해된 일의 이름 · 하나짜리 이름 그대로 · /compact 가 ①(권장)
assert_contains "$B2" '| 하나짜리 brief · 둘째 질문 없음 | 확정하고 /compact 후 brainstorming (권장) | 확정하고 /new 후 brainstorming |' "AC21: 하나짜리 brief 이름 그대로"
assert_contains "$B2" '| 분해된 일 | 확정하고 /compact 후 지휘자로 (권장) | 확정하고 /new 후 지휘자로 |' "AC21: 분해된 일은 지휘자로"
assert_contains "$B2" '이 세션에서 로드맵의 에픽들을 끝까지 이끈다' "AC21: 분해된 일의 설명이 지휘자를 말한다"
# AC23 — 둘째 질문이 있으면 단계 안 가리키는 이름 · 정본을 가리킴 · 제안 없으면 없음 · 분해된 일엔 없음
assert_contains "$B2" '| 하나짜리 brief · 둘째 질문 있음 | 확정하고 /compact 후 다음 단계로 (권장) | 확정하고 /new 후 다음 단계로 |' "AC23: 둘째 질문이 있으면 단계를 가리키지 않는 이름"
for lit in '선택지 넷의 개수 · 순서 · `(권장)` 은 어느 경우든 그대로' \
           '`${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md` 의 「둘째 질문(선택)」 대로' \
           '「brainstorming (권장)」 · 「<모델의 제안>」' '제안 이유는 게이트 앞 글' \
           '제안이 없으면 둘째 질문도 없다' '분해된 일에는 둘째 질문을 두지 않는다'; do
  assert_contains "$B2" "$lit" "AC23: B-2 «${lit}»"
done
para() { awk -v m="$2" 'index($0,m)==1{print}' "$1"; }
NEWP="$(para "$FIN" '**다른 다음 단계의 줄 — 둘째 질문에서 제안을 골랐을 때.**')"
SAMEP="$(para "$FIN" '**이름이 바뀌어도 절차는 같다.**')"
[ -n "$NEWP" ] && [ -n "$SAMEP" ] && ok "양성 대조: B-3 의 「다른 다음 단계의 줄」 · 「이름이 바뀌어도 절차는 같다」 문단을 떴다" || no "B-3 새 문단 부재"
assert_contains "$B3" '**다른 다음 단계의 줄 — 둘째 질문에서 제안을 골랐을 때.**' "AC23: B-3 안에 있다"
assert_contains "$B3" '**이름이 바뀌어도 절차는 같다.**' "AC23: B-3 안에 있다(절차 문단)"
for lit in '`@<brief-path>` 를 원소로' 'confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.' \
           '§3 열린 질문 · §4 조사 · §5 위험을 번호째 입력으로 읽는다' \
           'brief 의 확정 항목은 다시 묻지 않고 되비춤으로 확인한다.' \
           '사람에게 쓰는 글의 낱말 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에)을 지킨다.' \
           '`next_phase:` 를 고른 skill 의 완전명으로 바꾼다' '인용 줄로 두지 않는다'; do
  assert_contains "$NEWP" "$lit" "AC23: 「다른 다음 단계의 줄」 문단 «${lit}»"
done
assert_contains "$SAMEP" '「같은 턴에서 호출하지 말 것」은 그 줄이 부르는 skill(지휘자 · 고른 skill) 모두에 선다.' "AC23: 같은 턴 금지가 지휘자 · 고른 skill 모두에 선다"
EH="$SD/references/epic-handoff.md"; TPL="$SD/templates/interview-brief-template.md"; SKI="$SD/skills/pm-interview/SKILL.md"
nsl() { awk -v m="$2" '$0==m{f=1;next} f&&NF{print;exit}' "$1"; }
BL="$(nsl "$FIN" '**다음 세션 줄 — ①/② 공통**')"; EL="$(nsl "$EH" '**에픽 넘김 줄**')"
SHARED='설계문서에 ## 있는 것 검토 절(레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)과 ## 상류 · 하류 연계 절(이 일이 받는 곳 · 넘기는 곳 · 되돌아오는 길 · 같은 상태를 읽는 다른 표면)을 두고, 경로 · 테스트 명령 · 기본 브랜치 · 브랜치 이름 · 모델 같은 레포 전용 값은 박지 말고 도출하거나 레포 설정에서 읽게 설계한다.'
assert_contains "$EL" "$SHARED" "AC22(양성 대조): 에픽 넘김 줄에 원칙 문장"
assert_contains "$BL" "$SHARED" "AC22: brief 줄의 원칙 문장이 에픽 넘김 줄과 글자가 같다"
# AC18
grep -qxF 'next_phase: superpowers:brainstorming   # 기본 다음 단계 — 끝 게이트의 둘째 질문에서 다른 단계를 고르면 그 skill 의 완전명' "$TPL" \
  && ok "AC18: 템플릿 next_phase 가 기본 다음 단계라고 말한다" || no "AC18: 템플릿 next_phase 주석 부재"
assert_contains "$(flat "$TPL")" '§7 대로 기본 다음 단계(brainstorming 해답공간)로' "AC18: 템플릿 정의 문장"
assert_contains "$(win "$TPL" '^## 7[.]' '^## ')" '(기본 다음 단계 — superpowers 있으면:' "AC18: §7 이 기본 다음 단계를 말한다"
assert_contains "$(flat "$FIN")" '`next_phase: superpowers:brainstorming`(기본 다음 단계 — 끝 게이트의 둘째 질문에서 다른 단계를 고르면 B-3 이 그 skill 의 완전명으로 바꾼다)' "AC18: Step A 의 next_phase"
assert_contains "$(flat "$SKI")" 'interview brief**(기본 다음 단계가 brainstorming 인 meta-prompt)' "AC18: SKILL 정의 문장"
grep -qF 'brainstorming용 meta-prompt' "$SKI" && no "AC18: 옛 「brainstorming용」 정의 잔존" || ok "AC18: 옛 정의 없음(양성 짝: 위 단언)"
# AC19 · AC20
TE="$SD/references/trivia-escape.md"; SB="$SD/agents/steelman-builder.md"; SM="$SD/skills/pm-interview/references/steelman.md"
TEF="$(flat "$TE")"
grep -qxF '# Trivia Escape — 한 문장 기준' "$TE" && ok "AC19: 머리가 한 문장 기준" || no "AC19: 머리가 다르다"
for lit in '한 문장으로 설명 가능한 사소한 변경이면' '아래 다섯은 그 기준에 드는 흔한 예시다' \
           '목록에 없어도 한 문장으로 설명되는 변경이면 trivia 로 보고' '목록에 들어도 의미가 바뀌는 변경이면 trivia 가 아니다' \
           '**짧은 요청 + 명백히 안전한 syntactic action 동사**' '(보기: 10 토큰 안팎)' '판정 근거: <판정 근거>'; do
  assert_contains "$TEF" "$lit" "AC19: «${lit}»"
done
for old in '<10 토큰' '다섯 중 하나에 해당하면' '맞은 패턴'; do
  grep -qF "$old" "$TE" && no "AC19: 옛 문구 «${old}» 잔존" || ok "AC19: 옛 문구 «${old}» 없음(양성 짝: 위 단언)"
done
for f in "$SD/skills/pm-interview/SKILL.md" "$SD/skills/request-framing/SKILL.md"; do
  assert_contains "$(flat "$f")" '그 파일의 기준과 예시로 판정한다' "AC19: ${f##*/skills/} 진입이 기준으로 판정"
  grep -qF '다섯 패턴' "$f" && no "AC19: ${f##*/skills/} 에 「다섯 패턴」 잔존" || ok "AC19: ${f##*/skills/} 「다섯 패턴」 없음"
done
SBF="$(flat "$SB")"
for lit in '보기: landscape 모순 · 알려진 anti-pattern · 기존 사용자 제약과의 충돌. 이 셋에 한정하지 않는다.' \
           '<goal 기준으로 대안이 이기는 케이스 — 길이는 근거가 정한다(보기: 2-4줄)>' \
           '<같은 기준으로 원안이 이기는 케이스 — 길이는 근거가 정한다(보기: 2-4줄)>'; do
  assert_contains "$SBF" "$lit" "AC20: steelman-builder «${lit}»"
done
for old in '충돌 중 하나.' ', 2-4줄>'; do
  grep -qF "$old" "$SB" && no "AC20: steelman-builder 옛 «${old}» 잔존" || ok "AC20: 옛 «${old}» 없음(양성 짝: 위 단언)"
done
assert_contains "$(flat "$SM")" '**trigger** — 기본은 셋이다: landscape 모순 / 알려진 anti-pattern / 기존 사용자 제약과의 충돌. 다른 이유로 방향이 의심되면 모델이 판단해 띄우고 그 이유를 trigger 로 적는다.' "AC20: 인터뷰 쪽 trigger 도 예시"
# 정본 둘째 질문 문단 — 지휘자 아래 승인 질문에는 둘째 질문이 없다(문단 한정: 「기타 칸」 문단의 비슷한 문장과 가른다)
PG2="$(awk 'index($0,"**둘째 질문(선택) — 다음 단계 갈래.**")==1{f=1} f&&!NF{exit} f{print}' "$PG" | tr '\n' ' ')"
[ -n "$PG2" ] && ok "AC17(양성 대조): 정본 둘째 질문 문단을 떴다" || no "AC17: 정본 둘째 질문 문단 부재"
assert_contains "$PG2" '지휘자 아래 승인 질문에는 둘째 질문이 없다(에픽의 흐름은 로드맵 `흐름:` 칸이 정한다).' "AC17: 둘째 질문 문단이 지휘자 아래엔 없다고 말한다"
# AC25 — 위험 번호를 brief §5 줄에 박는다
DJ="$(win "$FIN" '^### 분해 판단' '^### ')"; SA="$(win "$FIN" '^### Step A ' '^### ')"
BA="$(win "$FIN" '^#### B-A' '^#### ')"; BR="$(win "$FIN" '^#### B-R' '^#### ')"
[ -n "$DJ" ] && [ -n "$SA" ] && [ -n "$BA" ] && [ -n "$BR" ] && ok "AC25(양성 대조): 분해 판단 · Step A · B-A · B-R 을 떴다" || no "AC25: 분해 판단 · Step A · B-A · B-R 부재"
parab() { awk -v m="$2" 'index($0,m)==1{f=1} f&&!NF{exit} f{print}' "$1" | tr '\n' ' ' | tr -s ' '; }
RISKP="$(parab "$FIN" '   **위험 번호.**')"
assert_contains "$SA" ' **위험 번호.** payload §5 의 위험 줄마다' "AC25: 「위험 번호」 문단이 Step A 안에 있다"
for lit in '`- 위험 K<n> — <숨은 가정 | 실패 양식 | 리뷰 참고> …`' '숨은 가정 · 실패 양식 · 리뷰 참고 순으로 K1 부터 매긴다' \
           '다른 줄의 번호를 고치지 않는다.' \
           '지운 위험의 번호는 다시 쓰지 않는다 — 새로 더하는 위험 줄은 지금까지 나온 가장 큰 K(이 brief 의 §5, 로드맵이 있으면 그 `## 위험 번호표` 와 분해 표의 배정 번호까지)의 다음 수를 받는다.'; do
  assert_contains "$RISKP" "$lit" "AC25: Step A 「위험 번호」 «${lit}»"
done
assert_not_contains "$RISKP" '이 brief 의 가장 큰 K 다음 수' "AC25: Step A 「위험 번호」 에 옛 「이 brief 의 가장 큰 K」 없음(양성 짝: 위 단언)"
assert_contains "$DJ" '위험 K 는 Step A 가 brief §5 위험 줄에 박을 번호다' "AC25: 분해 표 배정 번호 불릿"
RMT="$SD/templates/roadmap-template.md"
for f in "$FIN" "$RMT"; do
  grep -qF '번호 없는 위험 줄' "$f" && no "AC25: 옛 「번호 없는 위험 줄」 잔존(${f##*/})" || ok "AC25: 옛 「번호 없는 위험 줄」 없음(${f##*/}, 양성 짝: 위 · 아래 단언)"
done
RMTR="$(win "$RMT" '^## 위험 번호표' '^## ')"
for lit in '번호는 brief §5 위험 줄마다 박힌 번호(`- 위험 K<n> — …`)다.' '지운 위험의 번호는 다시 쓰지 않는다.' \
           '번호가 박히지 않은 옛 brief 만 숨은 가정 · 실패 양식 · 리뷰 참고 순으로 줄 순서대로 번호를 달고, 그렇게 매겼다고 알린다.'; do
  assert_contains "$RMTR" "$lit" "AC25: 로드맵 템플릿 「위험 번호표」 «${lit}»"
done
assert_contains "$BA" '`- 위험 K<n> — 리뷰 참고 | [<category>] <anchor> — <summary> (리뷰 <id>)`(`<n>` 은 Step A 「위험 번호」 의 다음 수 — 지운 위험의 번호는 다시 쓰지 않는다)' "AC25: B-A 의 §5 줄 꼴이 Step A 의 번호 규칙을 가리킨다"
assert_not_contains "$BA" '이 brief 의 가장 큰 K 다음 수' "AC25: B-A 에 옛 「이 brief 의 가장 큰 K」 없음(양성 짝: 위 단언)"
# 분해 판단 5 — 로드맵 폴더 이름은 brief 파일 이름에서 도출한다(<주제>-<HHMM> 줄기도)
DJ5="$(parab "$FIN" '5. **기록.**')"
assert_contains "$DJ" '5. **기록.**' "분해 판단 5 가 분해 판단 절 안에 있다"
assert_contains "$DJ5" '로드맵 폴더는 `<roadmaps_dir><YYYY-MM-DD>-<주제 또는 주제-HHMM>/` 다(`roadmaps_dir` 은 레포 설정의 로드맵 폴더) — 폴더 이름은 brief 파일 이름(`<줄기>.md`)에서 끝의 `-interview.md` 를 뗀 것, 곧 brief 파일 이름의 날짜 · 주제 부분 그대로다.' "분해 판단 5: 로드맵 폴더 이름을 brief 파일 이름에서 도출"
assert_not_contains "$DJ5" '(brief 와 같은 날짜 · 주제)' "분해 판단 5: 옛 「brief 와 같은 날짜 · 주제」 없음(양성 짝: 위 단언)"
for lit in '사유가 `unassigned` · `orphans` · `unknown_ids` 이거나 `brief 에서 줄을 찾지 못한 번호` 면' \
           '`unknown_ids` 는 표가 brief 에 없는 번호(지운 위험의 K 등)를 배정한 것이다 — 표에서 그 번호를 뺀다.' \
           '`brief 에서 줄을 찾지 못한 번호` 면 그 번호를 brief 에서 찾아 가른다 — brief 에 없으면 `unknown_ids` 와 같이 표에서 뺀다.' \
           'brief 에 있으면 생성기가 그 줄을 읽지 못한 것이다(생성기의 빈틈) — 표를 고치지 않고 그 번호와 사유를 그대로 보이고 아래 「표로 고칠 수 없는 사유」 처럼 멈춘다.' \
           '면 표가 아니라 brief 를 고친다 — 번호 없는 줄에는 메시지가 말한 번호부터 박고(로드맵 `## 위험 번호표` 에 더 큰 K 가 있으면 그다음 수부터), 겹친 번호는 한 줄을 Step A 「위험 번호」 의 다음 수로 바꾼다.' \
           '그다음 Step A 8 의 명령을 한 번만 다시 돌리고 위 갈래대로 가른다 — 또 같은 사유면 아래 「표로 고칠 수 없는 사유」 처럼 멈춘다.'; do
  assert_contains "$BR" "$lit" "AC25: B-R «${lit}»"
done
assert_not_contains "$BR" '`unknown_ids` · `brief 에서 줄을 찾지 못한 번호` 는 표가' "AC25: B-R 이 두 사유를 한데 묶어 표에서 빼지 않는다(양성 짝: 위 단언)"
# B-R 이 brief 를 고치게 하는 위험 번호 사유는 생성기의 글과 같은 글이다
for msg in 'brief §5 위험 줄 가운데 K 번호가 없는 줄이 있다' 'brief §5 위험 줄의 K 번호가 겹친다'; do
  assert_contains "$BR" "\`${msg}\`" "AC25: B-R 이 위험 번호 사유 «${msg}» 를 이름으로 가른다"
  grep -F 'raise FormatError(' "$SD/scripts/roadmap_model.py" | grep -qF "$msg" \
    && ok "AC25: roadmap_model 의 FormatError 글에 «${msg}» 가 있다" || no "AC25: roadmap_model 의 FormatError 글이 B-R 과 다르다(«${msg}»)"
done
# B-R 이 부르는 묶음 그리기 사유는 생성기의 글과 같은 글이다(문서 · 코드가 따로 바뀌지 않게)
NOFIND='brief 에서 줄을 찾지 못한 번호'
assert_contains "$BR" "\`${NOFIND}\` 면" "AC25: B-R 이 묶음 그리기 사유를 이름으로 가른다"
grep -F 'raise TableError(' "$SD/scripts/roadmap_render.py" | grep -qF "$NOFIND" \
  && ok "AC25: roadmap_render 의 TableError 글에 «${NOFIND}» 가 있다" || no "AC25: roadmap_render 의 TableError 글이 B-R 과 다르다"
assert_contains "$BA" '로 적습니다. brief 의 위험 줄에 번호가 없으면(옛 brief) 이 줄도 번호 없이 `- 위험 — 리뷰 참고 | …` 로 쓴다.' "AC25: B-A 옛 brief 는 번호 없이"
TPL5="$(win "$TPL" '^## 5[.]' '^## ')"
for lit in '- 위험 K1 — <숨은 가정 | 실패 양식>: <내용> — <근거>' '- 위험 K2 — 숨은 가정 | <내용> — RC3 (plugins/x/y.py#sym) [RC3 → OQ1]'; do
  assert_contains "$TPL5" "$lit" "AC25: 템플릿 §5 «${lit}»"
done
# 인터뷰 중 §5 위험 줄은 번호 없이 적고 번호는 Step A 가 박는다(섞인 줄은 생성기가 FormatError 로 막는다)
assert_contains "$(flat "$SKI")" '라운드 중에는 번호 없이 적고, brief 를 쓸 때 Step A 가 줄마다 `위험` 바로 뒤에 번호를 박는다(`- 위험 K<n> — …`, `references/finishing.md` 「위험 번호」).' "AC25: 인터뷰 중 위험 줄의 번호는 Step A 가 박는다"
# AC24 — 분해 표의 선택 칸 여섯 · 조사 에픽
DT="$(win "$FIN" '^3[.] [*][*]분해안 표' '^4[.] [*][*]')"
[ -n "$DT" ] && ok "AC24(양성 대조): 분해 판단 3 창을 떴다" || no "AC24: 분해 판단 3 창 부재"
for lit in '칸은 기본 열하나다:' \
           '선택 칸 여섯(크기 · 병렬 · 순서 이유 · 근거 · 흐름 · 산출물)을 더한 열일곱 칸' \
           '쓰지 않는 칸은 「없음」이다' \
           '`${CLAUDE_PLUGIN_ROOT}/references/roadmap-ontology.md` 의 에픽 · 산출물 행' \
           '조사 에픽은 종류 「묶음」에 `흐름` 「조사 — <단계 한 줄>」, `산출물` 에 결과 파일의 레포 상대경로를 쓴다' \
           '「결정」은 산출물 없이 로드맵 결정 기록으로 끝나는 일이다'; do
  assert_contains "$DT" "$lit" "AC24: 분해 판단 3 «${lit}»"
done
assert_not_contains "$DT" '칸은 열하나다:' "AC24: 옛 «칸은 열하나다:» 없음(양성 짝: 위 단언)"
[ -f "$SD/references/roadmap-ontology.md" ] && ok "AC24: 인용한 roadmap-ontology.md 가 있다" || no "AC24: roadmap-ontology.md 부재"
# CHANGELOG · README — 사람에게 보이는 글은 내부 단계 이름 대신 쉬운 말로
CL="$SD/CHANGELOG.md"; RD="$SD/README.md"
assert_contains "$(flat "$CL")" '- 같이 쓰는 진행 게이트의 정본(`references/proceed-gate.md`)의 둘째 질문 문단에, 지휘자 아래 승인 질문에는 둘째 질문이 없다는 문장을 더했다.' "CHANGELOG: 둘째 질문은 같이 쓰는 진행 게이트의 정본에"
assert_contains "$(flat "$CL")" '- 로드맵을 다시 만드는 단계가 「brief 에서 줄을 찾지 못한 번호」 로 멈추면, 그 번호가 brief 에 없을 때만 분해 표에서 뺀다.' "CHANGELOG: 다시 만드는 단계를 쉬운 말로"
for old in '인터뷰 끝 게이트의 정본에 선택 질문' 'B-R 이 묶음 에픽의'; do
  grep -qF "$old" "$CL" && no "CHANGELOG: 옛 «${old}» 잔존" || ok "CHANGELOG: 옛 «${old}» 없음(양성 짝: 위 단언)"
done
assert_contains "$(flat "$RD")" '인터뷰 끝 게이트는 하나짜리 brief 에서 둘째 질문으로 다른 다음 단계를 고를 수 있고' "README: 「하나짜리 brief 에서」"
grep -qF '하나짜리 brief 에서도' "$RD" && no "README: 옛 「에서도」 잔존" || ok "README: 옛 「에서도」 없음(양성 짝: 위 단언)"
finish
