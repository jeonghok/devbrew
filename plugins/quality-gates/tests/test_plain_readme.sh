#!/usr/bin/env bash
# guards: plugins/quality-gates/README.md
#
# 쉬운 말 출력 설계 §8 (계획 R13 · R17) — README 첫 문단이 「무엇을 해 주는가」를 쉬운 말로 말하고, `## 쓰는 법` 이
# 「이럴 때 — 친다 — 나오는 것」 표로 진입 명령을 모두 싣는다. 흐름 첫 문단도 쉬운 말이다.
# CLAUDE.md 가 요구하는 원칙 절은 그대로 있다. 부재 단언마다 양성 짝이 있다.
set -u
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  sed -n '2s/^# guards: //p' "$0" | tr ' ' '\n'
  exit 0
fi
. "$REPO_ROOT/shared/tests/assert.sh"
RM="$PLUGIN_ROOT/README.md"
# 첫 문단 · 절 본문은 줄바꿈을 지워 잰다 — 다시 쓰일 때 문장이 줄을 넘을 수 있다.
lead="$(awk 'NR>1 && /^## /{exit} NR>1' "$RM" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$lead" "바뀐 코드를 내보내기 전에 확인한다." "§8: 첫 문단이 무엇을 해 주는지로 시작한다"
assert_contains "$lead" "판정 하나(\`clean\` · \`defect\` · \`not-certified (<사유>)\`)를 낸다." "§8: 첫 문단이 판정 셋을 말한다"
assert_contains "$lead" "열린 PR 이 있으면 판정 뒤 쉬운 설명과 판정 줄을 코멘트 하나로 단다" "R17: 첫 문단이 게시를 말한다"
assert_contains "$lead" "원하면 판정 전에 사람이 승인한 명령으로 앱을 띄워 직접 걸어 본다(e2e 걷기)." "R21: 첫 문단이 e2e 걷기(선택 · 사람 승인)를 말한다"
assert_not_contains "$lead" "Claude Code용 품질 검증 파이프라인" "§8: 옛 첫 문단이 없다"
use="$(awk '/^## 쓰는 법$/{f=1;next} f&&/^## /{exit} f' "$RM")"
assert_grep "$use" '^\| 이럴 때 \| 친다 \| 나오는 것 \|$' "§8: 쓰는 법이 「이럴 때 · 친다 · 나오는 것」 표다"
for c in '`/quality-gates:quality-pipeline`' '`/quality-gates:quality-pipeline branch`' '`/quality-gates:quality-pipeline --paths <glob>...`' '`/quality-gates:quality-pipeline range <시작>[..<끝>]`' '`/quality-gates:artifact-critique <path>`'; do
  assert_contains "$use" "| ${c} |" "§8: 쓰는 법 표에 ${c} 행이 있다"
done
assert_eq "$(printf '%s\n' "$use" | grep -c '^| [^-|]')" "6" "§8: 표는 머리 하나와 행 다섯이다(없는 명령 행이 없다 — --plan 은 13.0.0 에서 없어졌다)"
assert_contains "$use" "열린 PR 이 있으면 코멘트 하나를 단다" "R17: 게시는 파이프라인 행이 말한다(별도 명령이 없다)"
assert_contains "$use" "판정 전에 앱을 띄워 걸어 볼지 묻는다." "R21: 파이프라인 행이 e2e 질문을 말한다"
# 「친다」 칸은 위 다섯 가운데 하나여야 한다 — 없어진 명령의 이름을 여기 적지 않는다(그 이름은
# tests/test_publish_surface_removed.sh 의 개념 별칭 스윕이 이 파일에서도 잡는다).
cmds="$(printf '%s\n' "$use" | awk -F'|' '/^\| / && !/^\| 이럴 때 /{gsub(/^ +| +$/, "", $3); print $3}')"
bad="$(printf '%s\n' "$cmds" | grep -vxF -e '`/quality-gates:quality-pipeline`' -e '`/quality-gates:quality-pipeline branch`' -e '`/quality-gates:quality-pipeline --paths <glob>...`' -e '`/quality-gates:quality-pipeline range <시작>[..<끝>]`' -e '`/quality-gates:artifact-critique <path>`')"
assert_eq "${bad}" "" "R17: 표의 「친다」 칸은 진입 명령 다섯뿐이다(없어진 명령 행이 없다)"
assert_file_absent "$RM" '^## 사용$' "§8: 옛 「사용」 절이 없다(쓰는 법이 대신한다)"
flow="$(awk '/^## 파이프라인 흐름/{f=1;next} f&&/^```/{exit} f' "$RM" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$flow" "파이프라인은 한 턴 안에서 끝까지 돈다" "§8: 흐름 첫 문단이 쉬운 말이다"
assert_contains "$flow" "이 질문들은 진행만 정하고 리뷰어 수를 막지 않는다." "§8: 흐름 첫 문단이 질문이 하는 일과 하지 않는 일을 말한다"
assert_not_contains "$flow" "serial dispatch로 실행합니다" "§8: 옛 흐름 문단이 없다"
assert_file_grep "$RM" '^## Principles Instantiated$' "CLAUDE.md: 원칙 절은 레포 규칙 이름(Principles Instantiated)이다"
assert_file_absent "$RM" '^## 인스턴스화한 원칙$' "원칙 절의 옛 제목이 없다(plugin-audit 이 영어 제목만 읽는다)"
assert_file_absent "$RM" 'Stop·중단' "M3: 게시 문단에 옛 라벨(Stop)이 없다"
assert_file_absent "$RM" '멈추기 · 중단으로 끝난 실행은 sink 를 부르지 않는다' "M3: 게시 문단에 옛 문장(멈추기로 끝난 실행은 게시하지 않는다)이 없다"
assert_file_grep "$RM" '게시는 판정 그대로 한다 — 막는 지적으로 끝난 직접 호출도 판정을 게시한다' "M3(양의 짝): 게시 문단이 「게시는 판정 그대로 한다」 로 말한다"

# --- R4 Task 8 — 한 번 보고 끝나는 흐름. 부재 단언마다 양의 짝이 있다(본문 문장 · 칸 이름으로 — 머리만으로 만족되지 않게).
flat_rm() { tr '\n' ' ' < "$RM" | tr -s ' '; }

case_readme_one_pass() {
  local diag p18 flat n tok line
  diag="$(awk '/^## 파이프라인 흐름/{f=1;next} f&&/^```/{if(on){exit}; on=1; next} on' "$RM")"
  assert_eq "$(printf '%s\n' "$diag" | grep -c '^ ├ ① 리뷰 ')" "1" "흐름 그림: ├ ① 리뷰 한 줄이 있다(양의 짝)"
  assert_eq "$(printf '%s\n' "$diag" | grep -c '② differential test')" "1" "흐름 그림: ① 리뷰 다음 줄들에 ② 차등 테스트가 한 번 있다(양의 짝)"
  assert_eq "$(printf '%s\n' "$diag" | awk '/^ ├ ① 리뷰 /{a=NR} /^ ├ e2e /{b=NR} END{print (a>0 && b>a) ? "yes" : "no"}')" "yes" "흐름 그림: ① 리뷰가 e2e 앞이다"
  for tok in 'qg iter loop' 'CAP' '다음 iteration' '분류표' 'excluded.md'; do
    assert_eq "$(printf '%s\n' "$diag" | grep -cF -- "$tok")" "0" "흐름 그림에 '${tok}' 이 없다"
  done
  for tok in 'qg iter loop' '수정 루프' 'extra-iterations' 'Max-iter' 'Fix-loop' '고치고 다시 돌기' '지금 판정으로 끝내기' '멈추기' '분류표' 'excluded.md' '반복 상한' '기본 상한 5'; do
    assert_eq "$(grep -cF -- "$tok" "$RM")" "0" "README 에 '${tok}' 이 없다"
  done
  # 「한 번 더 돌기」 는 문서 비평 라운드(상한이 있는 유일한 루프)에만 남는다 — 그 줄은 「라운드」 를 말한다.
  assert_eq "$(grep -F '한 번 더 돌기' "$RM" | grep -vc '라운드')" "0" "「한 번 더 돌기」 는 문서 비평 라운드 줄에만 있다"
  assert_eq "$(grep -cF '한 번 더 돌기' "$RM")" "1" "「한 번 더 돌기」 가 문서 비평 줄에 한 번 있다(양의 짝)"
  p18="$(grep -F -- '- **P18 — ' "$RM")"
  assert_contains "$p18" "문서 비평" "P18 줄이 문서 비평 라운드를 말한다(양의 짝)"
  for tok in '수정 루프' '5 번' 'Retry' '반복을 하나씩' 'extra-iterations'; do
    assert_not_contains "$p18" "$tok" "P18 줄에 '${tok}' 이 없다"
  done
  flat="$(flat_rm)"
  n="$(printf '%s' "$flat" | grep -oF '막는 지적이 남아도 묻지 않고 고칠 목록을 result.md 에 남긴다' | wc -l | tr -d ' ')"
  assert_eq "$n" "1" "흐름 문단이 「막는 지적이 남아도 묻지 않고 고칠 목록을 result.md 에 남긴다」 를 한 번 말한다"
  line="$(grep -F '판정 줄은 `qg: <판정>' "$RM")"
  assert_contains "$line" '`qg: <판정> · 막는 지적 B · 선택 O · 차등 새 실패 F[ · e2e E] · <sha>`' "판정 줄 꼴이 새 칸 이름(막는 지적 · 선택 · 차등 새 실패 · e2e)이다"
  assert_not_contains "$line" "제외 패치" "판정 줄 설명에 제외 패치 칸이 없다"
  assert_contains "$line" '`pass` · `fail` · `미확인` · `무효`' "e2e 게이트 결과가 pass · fail · 미확인 · 무효 넷이다"
}

case_readme_limits_one_pass() {
  local lim
  lim="$(awk '/^## 한계$/{f=1;next} f&&/^## /{exit} f' "$RM")"
  assert_contains "$lim" "qg 는 최종 판정 수치를 레포 코드가 돌기 전 또는 만든 직후에 읽어 지킨다." "한계 절 본문이 있다(양의 짝)"
  assert_contains "$lim" "- 중간 단계 — Step 4.5 의 표면화" "한계 절이 「중간 단계」 로 말한다(양의 짝)"
  for tok in '반복 중간 단계' '반복 2 이후' 'Fix-loop' '제외 패치'; do
    assert_not_contains "$lim" "$tok" "한계 절에 '${tok}' 이 없다"
  done
}

case_readme_rows_10_26_32() {
  local ans first rules flat row tree hdr_n
  # 행 10 ① — 답 파일 머리 아래 첫 문단은 답 파일만 말하고, 조언자 규칙은 새 머리 아래에 있다.
  ans="$(awk '/^### intent-critic 답 파일$/{f=1;next} f&&/^### /{exit} f' "$RM")"
  first="$(printf '%s\n' "$ans" | awk 'NF{p=1} p&&!NF{exit} p')"
  assert_contains "$first" "답 파일" "답 파일 머리의 첫 문단이 답 파일을 말한다(양의 짝)"
  for tok in '조언자' '부르는 조건' '넓게 보는' '다른 팀'; do
    assert_not_contains "$ans" "$tok" "답 파일 절에 조언자 규칙 낱말 '${tok}' 이 없다"
  done
  assert_contains "$ans" "- 답 커밋은 push 하지 않는다" "답 파일 절에 답 커밋 불릿이 있다(양의 짝)"
  assert_eq "$(grep -c '^### intent-critic 을 부르는 규칙$' "$RM")" "1" "새 머리 「intent-critic 을 부르는 규칙」 이 한 번 있다"
  rules="$(awk '/^### intent-critic 을 부르는 규칙$/{f=1;next} f&&/^### /{exit} f' "$RM")"
  assert_contains "$rules" "리뷰어를 부르는 조건은 리뷰의 넓이로 갈린다." "조언자 규칙이 새 머리 아래에 있다(양의 짝)"
  assert_contains "$rules" "부르는 횟수는 넓이와 상관없이 최대 둘" "부르는 횟수 문단도 새 머리 아래에 있다"
  flat="$(flat_rm)"
  # 행 10 ② — 문서만 고른 `--paths` 범위도 넓게 본다.
  assert_eq "$(printf '%s' "$flat" | grep -oF '`--paths` 로 문서만 고른 범위도 넓게 본다' | wc -l | tr -d ' ')" "1" "「--paths 로 문서만 고른 범위도 넓게 본다」 가 한 번 있다"
  # 행 10 ③ — 그 표시만 무시된다 · --origin 의 「만」 · 구조 트리 · review-diff.sh 머리 주석.
  assert_contains "$flat" "표시 줄의 값이 목록 · 매핑인 문서는 그 표시만 무시된다" "표시 줄의 값이 목록 · 매핑인 문서는 그 표시만 무시된다(양의 짝)"
  assert_not_contains "$flat" "표시 줄의 값이 목록 · 매핑인 문서는 의도 문서로 세지 않는다" "옛 문장(의도 문서로 세지 않는다)이 없다"
  tree="$(grep -F 'intent_origin.py' "$RM" | head -1)"
  assert_contains "$tree" "그 표시만 무시된다" "구조 트리의 intent_origin.py 줄이 그 표시만 무시된다고 말한다"
  assert_contains "$flat" "넘긴 원문과 그 로드맵은 \`HEAD\` 에서 읽는다" "--origin 설명이 원문과 그 로드맵을 HEAD 에서 읽는다고 말한다(양의 짝)"
  assert_not_contains "$flat" "넘긴 원문만 \`HEAD\` 에서 읽는다" "--origin 설명에 옛 「만」 이 없다"
  hdr_n="$(grep -F "printf 'mode: %s" "$PLUGIN_ROOT/scripts/review-diff.sh" | grep -o '%s' | wc -l | tr -d ' ')"
  assert_eq "$hdr_n" "11" "review-diff.sh 의 출력이 11 칸이다"
  assert_contains "$(sed -n '1,40p' "$PLUGIN_ROOT/scripts/review-diff.sh")" "stdout 11줄" "review-diff.sh 머리 주석이 stdout 11줄이라 말한다(실제 출력과 같은 수)"
  # 행 26 — 범위로 부른 리뷰에서 문서만 바뀐 범위는 바뀐 의도 문서의 머리 줄을 따라간다.
  assert_eq "$(printf '%s' "$flat" | grep -oF '범위로 부른 리뷰에서 문서만 바뀐 범위면 바뀐 의도 문서의 머리 줄을 따라간다' | wc -l | tr -d ' ')" "1" "범위 호출이 바뀐 의도 문서의 머리 줄을 따라간다는 문장이 한 번 있다"
}

for c in case_readme_one_pass case_readme_limits_one_pass case_readme_rows_10_26_32; do
  "$c"
done
finish
