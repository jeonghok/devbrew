#!/usr/bin/env bash
# 모든 skill 진입에 의존 확인 펜스가 있고, 진입마다 `--need` 목록이 정해진 대로다.
#  · gh 는 gh 를 쓰는 진입(epic-conductor · quality-pipeline)에만 있다 — 양 · 음 짝.
#  · 펜스 자리 — 번호 걸음이 있는 진입은 `### 1.5 의존 확인`, 표만 있는 진입은 감시줄 표 바로 뒤,
#    reviewing-brief 는 `## 진입 게이트` 의 첫 펜스. 감시줄 표의 ok 줄이 그 확인으로 간다.
#  · 펜스를 잘라 돌린다 — 가짜 check_deps.py 가 받은 인자를 적고 그 rc 를 펜스가 그대로 낸다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

TMP="$(mktemp -d "${TMPDIR:-/tmp}/entryneeds.XXXXXX")" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
TMP="$(cd "$TMP" && pwd -P)" || exit 1
case "$TMP" in /*/entryneeds.*) ;; *) echo "임시 폴더 경로가 이상하다: $TMP" >&2; exit 1 ;; esac
trap 'rm -rf "$TMP"' EXIT

expected_need() {   # expected_need <플러그인/skill> → --need 값 (빈 값 = 표에 없는 skill)
  case "$1" in
    spec-distill/epic-conductor)    echo "python,git,gh" ;;
    spec-distill/request-framing)   echo "python,git" ;;
    spec-distill/reviewing-brief)   echo "python,git" ;;
    spec-distill/roadmap-status)    echo "python,git" ;;
    spec-distill/pm-interview)      echo "python,git" ;;
    spec-distill/spec-review)       echo "python,git" ;;
    quality-gates/quality-pipeline) echo "python,git,gh" ;;
    quality-gates/artifact-critique) echo "python,git" ;;
    project-init/project-init)      echo "python" ;;
    plugin-audit/plugin-audit)      echo "python" ;;
    *)                              echo "" ;;
  esac
}
shape() {   # shape <플러그인/skill> → numbered | table | gate
  case "$1" in
    spec-distill/epic-conductor|spec-distill/pm-interview|spec-distill/request-framing|spec-distill/roadmap-status) echo numbered ;;
    spec-distill/reviewing-brief) echo gate ;;
    *) echo table ;;
  esac
}

SKILLS="$(cd "$ROOT" && git ls-files -- 'plugins/*/skills/*/SKILL.md')"
n_skill="$(printf '%s\n' "$SKILLS" | grep -c .)"
assert_eq "$n_skill" "10" "대상: 추적된 SKILL.md 가 열 개다(도출)"

# fence_info <SKILL.md> → 의존 확인 펜스마다 한 줄: `<여는 줄> <루트 변수> <루트 변수 대입 줄 수> <--plugin-root 값> <--need 값>`
fence_info() {
  python3 -I - "$1" <<'PY'
import re, sys
lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
# 인자 순서는 둘 중 하나다 — `--need python` 이 줄 끝이면 인라인 python 락이 인터프리터 호출로 읽는다.
CALL = re.compile(r'^python3 "\$(\w+)/scripts/check_deps\.py" entry '
                  r'(?:--plugin-root "\$(?P<r1>\w+)" --need (?P<n1>\S+)|--need (?P<n2>\S+) --plugin-root "\$(?P<r2>\w+)")$')
i = 0
while i < len(lines):
    if lines[i] != "```bash":
        i += 1
        continue
    j = i + 1
    while j < len(lines) and lines[j] != "```":
        j += 1
    body = lines[i + 1:j]
    for line in body:
        m = CALL.match(line)
        if m:
            var = m.group(1)
            guards = sum(1 for b in body if b.startswith('%s="${CLAUDE_PLUGIN_ROOT}"; [ -n "$%s" ] ||' % (var, var)))
            print(i + 1, var, guards, m.group("r1") or m.group("r2"), m.group("n1") or m.group("n2"))
    i = j + 1
PY
}

seen=""
for f in $SKILLS; do
  key="$(printf '%s' "$f" | sed -n 's#^plugins/\([^/]*\)/skills/\([^/]*\)/SKILL\.md$#\1/\2#p')"
  seen="$seen $key"
  want="$(expected_need "$key")"
  if [ -z "$want" ]; then no "$key: --need 표에 없는 skill 이다 — 표에 더하고 진입에 의존 확인을 둔다"; continue; fi
  info="$(fence_info "$ROOT/$f")"
  n="$(printf '%s\n' "$info" | grep -c .)"
  assert_eq "$n" "1" "$key: 의존 확인 펜스가 정확히 하나다"
  [ "$n" = 1 ] || continue
  set -- $info
  fline="$1"; var="$2"; guards="$3"; rootarg="$4"; need="$5"
  assert_eq "$need" "$want" "$key: --need 목록"
  assert_eq "$rootarg" "$var" "$key: --plugin-root 가 그 펜스의 루트 변수다"
  assert_eq "$guards" "1" "$key: 같은 펜스에 루트 가드 줄이 있다"
  case "$need" in
    *gh*) case "$key" in spec-distill/epic-conductor|quality-gates/quality-pipeline) ok "$key: gh 를 쓰는 진입이 gh 를 확인한다" ;;
                         *) no "$key: gh 를 쓰지 않는 진입이 gh 를 확인한다" ;; esac ;;
    *)    case "$key" in spec-distill/epic-conductor|quality-gates/quality-pipeline) no "$key: gh 를 쓰는 진입이 gh 를 확인하지 않는다" ;;
                         *) ok "$key: gh 를 쓰지 않는 진입은 gh 를 보지 않는다" ;; esac ;;
  esac

  # 자리 — 진입 단계 모양마다
  sk="$ROOT/$f"
  case "$(shape "$key")" in
    numbered)
      l1="$(grep -n '^### 1\. 감시줄 판독$' "$sk" | head -1 | cut -d: -f1)"
      l15="$(grep -n '^### 1\.5 의존 확인$' "$sk" | head -1 | cut -d: -f1)"
      l2="$(grep -n '^### 2\. ' "$sk" | head -1 | cut -d: -f1)"
      if [ -n "$l1" ] && [ -n "$l15" ] && [ -n "$l2" ] && [ "$l1" -lt "$l15" ] && [ "$l15" -lt "$fline" ] && [ "$fline" -lt "$l2" ]; then
        ok "$key: 펜스가 「### 1.5 의존 확인」 안(1 과 2 사이)에 있다"
      else no "$key: 펜스 자리가 1.5 가 아니다 (1=${l1:-없음} 1.5=${l15:-없음} 펜스=$fline 2=${l2:-없음})"; fi
      okrow="$(grep -F '| `[devbrew-entry] ok …` |' "$sk" | head -1)"
      assert_contains "$okrow" "1.5 로 간다" "$key: 감시줄 표의 ok 줄이 1.5 로 간다"
      ;;
    table)
      lok="$(grep -nF '| 감시줄 없음 · 그 밖 |' "$sk" | head -1 | cut -d: -f1)"
      lnext="$(awk -v s="${lok:-0}" 'NR>s && /^#{1,2} / {print NR; exit}' "$sk")"
      if [ -n "$lok" ] && [ -n "$lnext" ] && [ "$lok" -lt "$fline" ] && [ "$fline" -lt "$lnext" ]; then
        ok "$key: 펜스가 감시줄 표 바로 뒤(다음 제목 앞)에 있다"
      else no "$key: 펜스가 감시줄 표 바로 뒤가 아니다 (표 끝=${lok:-없음} 펜스=$fline 다음 제목=${lnext:-없음})"; fi
      okrow="$(grep -F '| `[devbrew-entry] ok …` |' "$sk" | head -1)"
      assert_contains "$okrow" "의존 확인" "$key: 감시줄 표의 ok 줄이 의존 확인으로 간다"
      ;;
    gate)
      lg="$(grep -n '^## 진입 게이트' "$sk" | head -1 | cut -d: -f1)"
      lfirst="$(awk -v s="${lg:-0}" 'NR>s && /^```bash$/ {print NR; exit}' "$sk")"
      assert_eq "$lfirst" "$fline" "$key: 펜스가 「## 진입 게이트」 의 첫 펜스다"
      ;;
  esac
  # 펜스 뒤 글이 rc 3 이면 멈춘다고 적는다
  after="$(awk -v s="$fline" 'NR>s && f && /^```bash$/ {exit} NR>s && /^```$/ && !f {f=1; next} f' "$sk")"
  # 결과 표의 rc 3 행 하나가 그 자리에서 멈춘다고 적는다(뒤 걸음의 「멈춘다」로 채워지지 않게 행 단위로 잰다)
  if printf '%s\n' "$after" | grep -qE '^\| rc 3 [^|]*\|[^|]*멈춘다'; then ok "$key: 결과 표의 rc 3 행이 멈춘다고 적는다"
  else no "$key: 결과 표에 「rc 3 … | … 멈춘다」 행이 없다"; fi

  # 펜스를 잘라 돌린다 — 가짜 check_deps.py 가 인자를 적고 STUB_RC 로 끝난다
  plug="${key%%/*}"
  fake="$TMP/$plug"; mkdir -p "$fake/scripts"
  printf 'import os, sys\nopen(os.environ["ARGS_OUT"], "w", encoding="utf-8").write(" ".join(sys.argv[1:]))\nprint("[devbrew-deps] stub")\nsys.exit(int(os.environ.get("STUB_RC", "0")))\n' > "$fake/scripts/check_deps.py"
  awk -v s="$fline" 'NR>s && /^```$/ {exit} NR>s' "$sk" > "$TMP/fence.sh"
  for rc in 0 3; do
    rm -f "$TMP/args"
    ( cd "$TMP" && env -i PATH=/usr/bin:/bin HOME="$TMP" CLAUDE_PLUGIN_ROOT="$fake" ARGS_OUT="$TMP/args" STUB_RC="$rc" \
        PYTHONDONTWRITEBYTECODE=1 /bin/bash "$TMP/fence.sh" ) >/dev/null 2>&1; got=$?
    assert_eq "$got" "$rc" "$key: 펜스가 의존 확인의 rc $rc 를 그대로 낸다"
    case "$(cat "$TMP/args" 2>/dev/null)" in
      "entry --plugin-root $fake --need $want"|"entry --need $want --plugin-root $fake") ok "$key: 펜스가 플러그인 루트와 --need 를 넘긴다 (rc $rc)" ;;
      *) no "$key: 펜스가 넘긴 인자가 다르다 (rc $rc): $(cat "$TMP/args" 2>/dev/null)" ;;
    esac
  done
  ( cd "$TMP" && env -i PATH=/usr/bin:/bin HOME="$TMP" ARGS_OUT="$TMP/args-noroot" /bin/bash "$TMP/fence.sh" ) >/dev/null 2>&1; got=$?
  assert_eq "$got" "1" "$key: 루트가 비면 펜스가 rc 1 로 멈춘다"
  [ -e "$TMP/args-noroot" ] && no "$key: 루트가 빈데 의존 확인을 불렀다" || ok "$key: 루트가 비면 의존 확인을 부르지 않는다"
done

# 표의 모든 skill 이 실제로 있었다(표가 사라진 skill 을 가리키지 않는다)
for key in spec-distill/epic-conductor spec-distill/request-framing spec-distill/reviewing-brief spec-distill/roadmap-status \
           spec-distill/pm-interview spec-distill/spec-review quality-gates/quality-pipeline quality-gates/artifact-critique \
           project-init/project-init plugin-audit/plugin-audit; do
  case " $seen " in *" $key "*) ok "표의 $key 가 추적된 skill 이다" ;; *) no "표의 $key 가 추적된 skill 이 아니다" ;; esac
done

finish
