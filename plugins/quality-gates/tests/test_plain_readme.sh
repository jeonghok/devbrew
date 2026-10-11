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
for c in '`/qg`' '`/qg branch`' '`/qg --paths <glob>...`' '`/qg --plan <path>`' '`/qg critique <path>`'; do
  assert_contains "$use" "| ${c} |" "§8: 쓰는 법 표에 ${c} 행이 있다"
done
assert_eq "$(printf '%s\n' "$use" | grep -c '^| [^-|]')" "6" "§8: 표는 머리 하나와 행 다섯이다(없는 명령 행이 없다)"
assert_contains "$use" "열린 PR 이 있으면 코멘트 하나를 단다" "R17: 게시는 /qg 행이 말한다(별도 명령이 없다)"
assert_contains "$use" "판정 전에 앱을 띄워 걸어 볼지 묻는다." "R21: /qg 행이 e2e 질문을 말한다"
# 「친다」 칸은 위 다섯 가운데 하나여야 한다 — 없어진 명령의 이름을 여기 적지 않는다(그 이름은
# tests/test_publish_surface_removed.sh 의 개념 별칭 스윕이 이 파일에서도 잡는다).
cmds="$(printf '%s\n' "$use" | awk -F'|' '/^\| / && !/^\| 이럴 때 /{gsub(/^ +| +$/, "", $3); print $3}')"
bad="$(printf '%s\n' "$cmds" | grep -vxF -e '`/qg`' -e '`/qg branch`' -e '`/qg --paths <glob>...`' -e '`/qg --plan <path>`' -e '`/qg critique <path>`')"
assert_eq "${bad}" "" "R17: 표의 「친다」 칸은 진입 명령 다섯뿐이다(없어진 명령 행이 없다)"
assert_file_absent "$RM" '^## 사용$' "§8: 옛 「사용」 절이 없다(쓰는 법이 대신한다)"
flow="$(awk '/^## 파이프라인 흐름/{f=1;next} f&&/^```/{exit} f' "$RM" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$flow" "파이프라인은 한 턴 안에서 끝까지 돈다" "§8: 흐름 첫 문단이 쉬운 말이다"
assert_contains "$flow" "이 질문은 진행만 정하고 리뷰어 수를 막지 않는다." "§8: 흐름 첫 문단이 질문이 하는 일과 하지 않는 일을 말한다"
assert_not_contains "$flow" "serial dispatch로 실행합니다" "§8: 옛 흐름 문단이 없다"
assert_file_grep "$RM" '^## 인스턴스화한 원칙$' "CLAUDE.md: 원칙 절은 그대로 있다"
assert_file_absent "$RM" 'Stop·중단' "M3: 게시 문단에 옛 라벨(Stop)이 없다"
assert_file_grep "$RM" '멈추기 · 중단으로 끝난 실행은 sink 를 부르지 않는다' "M3(양의 짝): 게시 문단이 새 라벨(멈추기)로 말한다"
finish
