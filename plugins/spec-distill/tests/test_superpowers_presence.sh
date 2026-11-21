#!/usr/bin/env bash
# superpowers 가 없을 때 · quality-gates 가 없을 때의 문면(AC22 · AC23).
#  · 지휘자 진입(`### 1.5 의존 확인`) — superpowers 가 없으면 멈추는 문장
#  · 인터뷰 끝(finishing.md B-1) — superpowers 없음 갈래(brief 까지 만들고 알린 뒤 멈춤)가 그대로 · 있으면 B-2 로 간다
#  · 손 절차 머리 — superpowers 없으면 멈춤 · 걸음 7 — quality-gates 없음 문장
#  · spec-distill plugin.json 에 `dependencies` 키가 없다(음) — 양의 짝: dependencies.md 의 superpowers 행
#  · skill · reference · README · 의존 목록이 check_deps.py 의 하위 명령으로 entry · measure 만 부른다(음) — 양의 짝: entry 호출
# 정적 락이다 — 모델이 skill 목록으로 superpowers 를 실제로 가려내는지는 재지 못한다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_superpowers_presence.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd -P)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
SD="$ROOT/plugins/spec-distill"
EC="$SD/skills/epic-conductor/SKILL.md"
FIN="$SD/skills/pm-interview/references/finishing.md"
CD="$SD/references/conducting.md"
README="$SD/README.md"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/sppresence.XXXXXX")" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
TMP="$(cd "$TMP" && pwd -P)" || exit 1
case "$TMP" in /*/sppresence.*) ;; *) echo "임시 폴더 경로가 이상하다: $TMP" >&2; exit 1 ;; esac
trap 'rm -rf "$TMP"' EXIT

STOP='superpowers 가 필요하다 — Claude Code 의 /plugin 에서 superpowers 를 설치한 뒤 다시 부른다'
QG_ABSENT='품질 게이트 없이 간다 — quality-gates 가 설치돼 있지 않다'
EC_STOP_LINE="[spec-distill] epic-conductor 멈춤 — $STOP"
MAN_STOP_LINE="[spec-distill] 지휘 절차 멈춤 — $STOP"
# stop_literal <글> — 멈춤 문장을 담은 백틱 안 줄 하나(백틱 뺌)
stop_literal() {
  printf '%s\n' "$1" | grep -oE '`[^`]*superpowers 가 필요하다[^`]*`' | head -1 | tr -d '`'
}

# section <파일> <제목 줄 ERE> <끝 줄 ERE> — 제목 줄부터 끝 줄 앞까지(제목 포함, 끝 제외)
section() {
  awk -v s="$2" -v e="$3" 'f && $0 ~ e {exit} $0 ~ s {f=1} f' "$1"
}

for f in "$EC" "$FIN" "$CD" "$README"; do
  [ -f "$f" ] && ok "읽는다: ${f#$ROOT/}" || no "없다: ${f#$ROOT/}"
done

# ── 1. 지휘자 진입 — superpowers 가 없으면 멈춘다 ─────────────────
E15="$(section "$EC" '^### 1\.5 의존 확인$' '^##+ ')"
[ -n "$E15" ] && ok "epic-conductor: 「### 1.5 의존 확인」 절을 읽었다" || no "epic-conductor: 「### 1.5 의존 확인」 절이 없다"
stopline="$(printf '%s\n' "$E15" | grep -F -- "$STOP" | head -1)"
assert_contains "$stopline" "$STOP" "epic-conductor 1.5: superpowers 가 없으면 보일 문장"
assert_contains "$stopline" "멈춘다" "epic-conductor 1.5: 그 문장의 줄이 멈춘다고 적는다"
assert_contains "$stopline" "skill 목록" "epic-conductor 1.5: 있는지는 skill 목록으로 가린다"
ecstop="$(stop_literal "$stopline")"
assert_eq "$ecstop" "$EC_STOP_LINE" "epic-conductor 1.5: 멈춤 줄 전체가 그 skill 의 모델 줄 꼴이다"
case "$ecstop" in "[devbrew-deps]"*) no "epic-conductor 1.5: 모델이 쓰는 멈춤 줄이 스크립트 머리 [devbrew-deps] 를 단다" ;;
  *) ok "epic-conductor 1.5: 모델이 쓰는 멈춤 줄은 [devbrew-deps] 로 시작하지 않는다" ;; esac
assert_not_contains "$(cat "$EC")" "[devbrew-deps] 멈춤 — superpowers" "epic-conductor: superpowers 멈춤을 스크립트 머리로 쓰는 줄이 없다"
okrow="$(printf '%s\n' "$E15" | grep -E '^\| rc 0 ' | head -1)"
assert_contains "$okrow" "superpowers" "epic-conductor 1.5: 의존 확인 rc 0 다음이 superpowers 확인이다(바로 2 로 가지 않는다)"

# ── 2. 인터뷰 끝 — superpowers 없음 갈래(B-1)는 그대로 · 있으면 B-2 로 간다 ──────
B1="$(section "$FIN" '^#### B-1 — superpowers 가용성 분기$' '^#### B-2 ')"
[ -n "$B1" ] && ok "finishing.md: B-1 절을 읽었다" || no "finishing.md: B-1 절이 없다"
absent="$(printf '%s\n' "$B1" | grep -F -- '- **superpowers 부재 시**' | head -1)"
assert_contains "$absent" "**선택지 셋의 따로 된 끝 질문**을 띄운다" "F4 AC10: superpowers 가 없으면 끝 질문을 띄운다"
assert_contains "$absent" "공통 계약(\`proceed-gate.md\` Step B)의 질문이 아니다" "F4 AC10: 그 질문은 공통 계약의 질문이 아니다"
assert_contains "$absent" "crash·spec-mode fallback **금지**" "finishing.md B-1: crash · spec-mode fallback 금지는 그대로다"
assert_eq "$(printf '%s\n' "$B1" | grep -c '^        {label: ')" "3" "F4 AC10: 끝 질문의 선택지는 셋이다"
for lit in '{label: "확정하고 끝낸다 (권장)", description: "얻음: 확정을 저장하고 커밋해 brief 를 다음 작업의 입력으로 남긴다 · 내줌: 확정 후보에 안 고친 잘못이 있으면 확정으로 굳은 채 커밋된다"},' \
           '{label: "확정 목록 수정", description: "얻음: 끝내기 전에 확정 후보와 공시를 고친다 · 내줌: 아직 아무것도 확정되지 않고 고친 뒤 이 질문을 다시 거친다"},' \
           '{label: "brief만 종료", description: "얻음: 아무것도 확정하지 않고 brief 를 여기서 끝낸다 · 내줌: 모든 항목이 잠정으로 남는다"}' \
           '「확정하고 끝낸다」 는 PR 을 열지 않는다. 「확정 목록 수정」 은 두 번 고친 뒤에는 계속할지 묻는다(B-0 의 재제시 상한).' \
           'B-2 의 게이트 앞 글 목록(리뷰 게이트 결과 · 읽어 보기 · 남은 항목 · 경고 · 건너뛴 것)을 같은 순서 · 같은 규칙으로 보인다.' \
           '질문의 상태 줄도 B-2 와 같은 꼴이다 — 경고 줄과 「전문」 줄은 B-2 의 본문 규칙대로 싣는다.' \
           '<경고 줄 — 채널마다의 짧은 줄을 「 · 」로 이은 것 | 경고 없음 | 이상 없음>. 전문: <경로>. superpowers 가 없어 다음 단계로 넘기지 않는다.' \
           '커밋 펜스(`interview-commit`) → 여기서 멈춘다. 분해된 일이어도 「PR 과 머지」 로 가지 않는다.' \
           '`[spec-distill] superpowers 가 없어 다음 단계를 열지 못했다 — 설치한 뒤 새 세션에서 아래 줄로 잇는다.`' \
           '분해된 일이고 커밋 펜스가 「brief · audit · 상태 파일 · 로드맵 폴더를 커밋했다」 줄을 냈으면 그 앞에 지휘 세션을 이 커밋이 기본 브랜치에 머지된 뒤 열라고 한 줄로 알린다.' \
           '고친 뒤에는 B-2 가 아니라 이 끝 질문을 다시 띄운다' \
           '`[spec-distill] superpowers 가 없어 이어 갈 다음 단계가 없다.` 한 줄을 보이고 같은 질문을 다시 띄운다.' \
           '건너뛴 것을 하라는 말이면 B-S 로 간다.'; do
  assert_contains "$B1" "$lit" "F4 AC10: B-1 «${lit}»"
done
assert_not_contains "$(cat "$FIN")" 'superpowers 가 없어 여기서 멈춘다' "F4 AC10: 옛 멈춤 안내가 없다(양성 짝: 위 단언)"
avail_line="$(printf '%s\n' "$B1" | grep -F -- '- **superpowers 가용 시**' | head -1)"
assert_eq "$avail_line" "- **superpowers 가용 시**: B-2 proceed 게이트 제시." "finishing.md B-1: superpowers 가 있으면 B-2 게이트로 간다"

# ── 3. 손 절차 머리 · 걸음 7 ─────────────────────────────────────────────────
MAN_HEAD="$(section "$CD" '^## 손으로 따르는 절차$' '^1\. \*\*')"
[ -n "$MAN_HEAD" ] && ok "conducting.md: 손 절차 머리를 읽었다" || no "conducting.md: 손 절차 머리가 없다"
mline="$(printf '%s\n' "$MAN_HEAD" | grep -F -- "$STOP" | head -1)"
assert_contains "$mline" "$STOP" "conducting.md 손 절차 머리: superpowers 가 없으면 보일 문장"
assert_contains "$mline" "멈춘다" "conducting.md 손 절차 머리: 그 문장의 줄이 멈춘다고 적는다"
assert_eq "$(stop_literal "$mline")" "$MAN_STOP_LINE" "conducting.md 손 절차 머리: 멈춤 줄 전체가 모델 줄 꼴이다(스크립트 머리 아님)"
S7="$(section "$CD" '^### 7\. 끝$' '^##+ ')"
[ -n "$S7" ] && ok "conducting.md: 걸음 7 을 읽었다" || no "conducting.md: 걸음 7 이 없다"
qline="$(printf '%s\n' "$S7" | grep -F -- "$QG_ABSENT" | head -1)"
assert_contains "$qline" "$QG_ABSENT" "conducting.md 걸음 7: quality-gates 가 없을 때 알릴 문장"
assert_contains "$qline" "진행한다" "conducting.md 걸음 7: 알리고 진행한다"
assert_not_contains "$qline" "멈춘다" "conducting.md 걸음 7: quality-gates 가 없다고 멈추지 않는다"

# ── 4. README Prerequisites ─────────────────────────────────────────────────
PRE="$(section "$README" '^## Prerequisites$' '^## ')"
spl="$(printf '%s\n' "$PRE" | grep -F -- '- **superpowers**' | head -1)"
assert_contains "$spl" "지휘자" "README Prerequisites: superpowers 줄이 지휘자 흐름을 말한다"
assert_contains "$spl" "진입에서 멈춘다" "README Prerequisites: superpowers 가 없으면 지휘자 흐름은 진입에서 멈춘다"
qgl="$(printf '%s\n' "$PRE" | grep -F -- '- **quality-gates**' | head -1)"
assert_contains "$qgl" "$QG_ABSENT" "README Prerequisites: quality-gates 가 없을 때의 문장"

# ── 5. plugin.json 에 dependencies 키가 없다(음) · dependencies.md 에 superpowers 행(양) ──
pj="$(python3 -I -c 'import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
print(d.get("name", ""))
print("has-dependencies" if "dependencies" in d else "no-dependencies")' "$SD/.claude-plugin/plugin.json" 2>&1)"
assert_eq "$(printf '%s\n' "$pj" | sed -n 1p)" "spec-distill" "plugin.json 을 읽었다(이름 spec-distill)"
assert_eq "$(printf '%s\n' "$pj" | sed -n 2p)" "no-dependencies" "plugin.json 에 dependencies 키가 없다 — 없으면 플러그인 전체가 꺼진다"
sprow="$(python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import check_deps
for r in check_deps.read_table(sys.argv[2]):
    if r["name"] == "superpowers":
        print("%s|%s|%s" % (r["strength"], "ok" if check_deps.version_triple(r["min_version"]) else "no-version", r["when_missing"]))' \
  "$ROOT/shared/deps" "$SD/dependencies.md" 2>&1)"
assert_eq "$(printf '%s' "$sprow" | cut -d'|' -f1-2)" "알림|ok" "dependencies.md: superpowers 행이 판과 강도 알림으로 있다(양의 짝)"
assert_contains "$sprow" "진입에서 멈춘다" "dependencies.md: superpowers 행의 없을 때 칸이 지휘자 흐름의 멈춤을 말한다"

# ── 6. check_deps.py 하위 명령은 entry · measure 만 부른다(음) · entry 호출(양) ──
CORPUS="$TMP/corpus.txt"
{ find "$SD/skills" "$SD/references" "$SD/agents" -name '*.md' -type f; printf '%s\n' "$README" "$SD/dependencies.md"; } | sort > "$CORPUS"
assert_contains "$(cat "$CORPUS")" "$EC" "코퍼스가 epic-conductor SKILL.md 를 담는다"
assert_contains "$(cat "$CORPUS")" "$SD/agents/" "코퍼스가 agent 문서를 담는다"
calls="$(while IFS= read -r f; do grep -ohE 'check_deps\.py"? [a-z-]+' "$f"; done < "$CORPUS" | sed -E 's/^check_deps\.py"? //' | sort -u | tr '\n' ' ')"
assert_eq "$calls" "entry measure " "skill · reference · agent · README · 의존 목록이 부르는 check_deps.py 하위 명령은 entry · measure 둘이다"
assert_contains "$(grep -F 'check_deps.py" entry' "$EC")" '--need python,git,gh' "epic-conductor 1.5: entry 호출이 있다(양의 짝)"


finish
