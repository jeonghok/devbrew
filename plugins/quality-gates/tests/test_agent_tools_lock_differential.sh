#!/usr/bin/env bash
# S-3 — Law 2 락(`test_agent_frontmatter_keys.sh`)의 **파서 합치(differential)** 증명.
#
# 왜 mutation 하니스와 별도 파일인가 (모듈화):
#   `test_agent_tools_lock_mutation.sh` 는 락 **술어의 모양**을 증명한다 — "이 케이스는
#   RED 여야 한다" 를 케이스별로 못 박는다. 그 하니스는 두 개의 실제 우회(중복 키
#   `tools : [Write]` / NBSP-패딩 `[]`)를 **45/45 GREEN 인 채로** 통과시켰다. 술어의 모양을
#   아무리 촘촘히 락해도 *"락이 믿은 값 = 파서가 실제로 resolve 하는 값"* 이라는 **의미론적
#   속성**은 증명되지 않기 때문이다. 이 파일이 그 속성을 담당한다.
#
# 두 레이어 (의존성이 다르다 — 분리해서 세는 이유):
#   L1 verdict   : 락 verdict == want_lock. 의존성 없음, **항상 실행**.
#                  (파서가 없어도 S-1/S-2 회귀는 계속 잡힌다.)
#   L2 파서 합치 : PyYAML 이 같은 바이트를 실제로 어떻게 resolve 하는지와 대조.
#                  **파서는 테스트-타임 의존성**이다 — 없으면 loud 하게 skip 하고,
#                  절대 조용히 pass 로 세지 않는다. 락 자체는 regex 기반 fail-closed 로
#                  남는다. 파서는 락을 **검증**하는 도구이지 락을 **실행**하는 도구가 아니다.
#
# L2 불변식 (락이 GREEN 을 준 파일에 한해):
#   (a) 파서가 그 frontmatter 를 실제로 파싱할 수 있어야 한다. 파싱 불가인데 GREEN 이면
#       락은 "런타임이 읽지도 못하는 선언"을 승인한 것이다.
#   (b) 락이 **zero-tool 근거(`[]` 카브아웃)** 로 통과시켰다면 파서는 `tools` 를 **실제 빈
#       시퀀스**로 resolve 해야 한다. 빈 시퀀스처럼 **보이는 문자열**(NBSP-패딩)이나
#       비어있지 않은 리스트(중복 키)면 위반이다.
#   (c) 락이 **plain scalar 근거**로 통과시켰다면 파서도 문자열로 resolve 해야 하고,
#       comma 토큰 집합이 락이 검증한 토큰 집합과 **정확히 같아야** 한다.
#
#   "락이 믿은 값" 은 추측하지 않는다 — 락이 `DEVBREW_QUALITY_GATES_AGENT_TOOLS_LOCK_EMIT=1` 에서 내보내는
#   `DECL` 라인에서 읽는다. 락의 로직을 이 파일에 다시 구현하면 같은 버그를 두 번 쓰게 되어
#   (순환) 아무것도 증명하지 못한다.
#
# 사용: test_agent_tools_lock_differential.sh
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LOCK="$ROOT/plugins/quality-gates/tests/test_agent_frontmatter_keys.sh"
SKIP=0
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# GC9: mktemp 가드 — 대입 실패 시 trap arm 전에 abort (빈 변수 → trap 의 rm -rf 가 repo 를 지운다).
TMP="$(mktemp -d)" || { echo "FAIL: mktemp 실패"; exit 1; }
[ -n "$TMP" ] && [ -d "$TMP" ] || { echo "FAIL: TMP 가 유효한 디렉토리가 아님"; exit 1; }
trap 'rm -rf "$TMP"' EXIT
FIX="$TMP/plugins/probe/agents"
mkdir -p "$FIX" || exit 1
AGENT="$FIX/probe.md"

# ── 파서 가용성 (테스트-타임 의존성) ───────────────────────────────────────────
PARSER=yes
python3 -c 'import yaml' 2>/dev/null || PARSER=no
if [ "$PARSER" = no ]; then
  echo "‼️  DEGRADED — python3+PyYAML 부재: L2(파서 합치) 검사를 실행할 수 없다."
  echo "‼️  L1(verdict) 만 실행한다. **skip 은 pass 가 아니다** — 아래 요약의 skipped 수를 볼 것."
  echo "‼️  복구: python3 -m pip install pyyaml"
  echo
fi

cat > "$TMP/parse.py" <<'PYEOF'
"""frontmatter 를 실제 YAML 파서로 resolve 해 `tools` 키의 kind/토큰을 보고한다.

출력 1줄, 탭 구분: <status>\t<kind>\t<토큰을 | 로 join>
  status: ok | err
  kind  : list | str | null | absent | other | -
"""
import io
import sys

import yaml


def frontmatter(path):
    with io.open(path, encoding="utf-8") as fh:
        lines = fh.read().split("\n")
    if not lines or lines[0] != "---":
        return None
    out = []
    for line in lines[1:]:
        if line == "---":
            return "\n".join(out)
        out.append(line)
    return None


def main():
    fm = frontmatter(sys.argv[1])
    if fm is None:
        print("err\t-\t")
        return
    try:
        doc = yaml.safe_load(fm)
    except Exception:
        print("err\t-\t")
        return
    if not isinstance(doc, dict):
        print("err\t-\t")
        return
    sentinel = object()
    val = doc.get("tools", sentinel)
    if val is sentinel:
        print("ok\tabsent\t")
    elif val is None:
        print("ok\tnull\t")
    elif isinstance(val, list):
        print("ok\tlist\t" + "|".join(str(x) for x in val))
    elif isinstance(val, str):
        toks = [t.strip(" \t") for t in val.split(",")]
        print("ok\tstr\t" + "|".join(t for t in toks if t))
    else:
        print("ok\tother\t" + str(val))


main()
PYEOF

# 픽스처의 body 는 고정 — 변하는 것은 frontmatter 프래그먼트뿐이다.
write_agent() {  # write_agent <printf %b 프래그먼트>
  printf -- '---\nname: probe\ndescription: fixture\nmodel: inherit\n%b\n---\n\nbody\n' "$1" > "$AGENT"
}

# dcase <want_lock GREEN|RED> <want_parser status:kind> <설명> <프래그먼트>
dcase() {
  local want_lock="$1" want_parser="$2" msg="$3" frag="$4"
  write_agent "$frag"

  # ── L1: verdict (의존성 없음) ──
  # DECL 은 **fd 3** 으로 온다 (락의 "진단 채널" 참조, v2.14.2 A-1). `3>&1 1>/dev/null` 로
  # 진단만 캡처하고 락의 실제 stdout 은 버린다 — 진단이 stdout 을 공유하면 락 안에서
  # 실패한 printf 의 stdio 버퍼가 토큰 루프의 process substitution 으로 새어
  # verdict 를 뒤집는다. 채널을 호출자가 명시적으로 주는 것이 그 계약이다.
  local got_lock decl
  if decl="$(DEVBREW_QUALITY_GATES_AGENT_TOOLS_LOCK_EMIT=1 bash "$LOCK" "$TMP" 3>&1 1>/dev/null 2>/dev/null)"; then
    got_lock=GREEN
  else
    got_lock=RED
  fi
  if [ "$got_lock" = "$want_lock" ]; then
    ok "[L1] ${msg} → ${got_lock}"
  else
    no "[L1] ${msg} — want ${want_lock}, got ${got_lock}"
  fi

  if [ "$PARSER" = no ]; then SKIP=$((SKIP+1)); return; fi

  # ── L2: 파서 합치 ──
  local praw pstatus pkind ptoks
  praw="$(python3 "$TMP/parse.py" "$AGENT")"
  pstatus="$(printf '%s' "$praw" | cut -f1)"
  pkind="$(printf '%s' "$praw" | cut -f2)"
  ptoks="$(printf '%s' "$praw" | cut -f3)"

  if [ "${pstatus}:${pkind}" = "$want_parser" ]; then
    ok "[L2-ground] ${msg} — 파서 실제 resolve = ${want_parser}"
  else
    no "[L2-ground] ${msg} — 파서 resolve want ${want_parser}, got ${pstatus}:${pkind}"
  fi

  # 불변식은 락이 GREEN 을 준 경우에만 의미가 있다 (RED 면 락은 아무것도 주장하지 않았다).
  [ "$got_lock" = GREEN ] || return

  # 락이 스스로 보고한 "내가 검증했다고 믿는 값".
  local dline basis bel
  dline="$(printf '%s\n' "$decl" | grep '^DECL	' | head -1)"
  if [ -z "$dline" ]; then
    no "[L2-diff] ${msg} — 락이 GREEN 인데 DECL 을 내보내지 않았다(믿은 값 불명 = 검증 불가)"
    return
  fi
  basis="$(printf '%s' "$dline" | cut -f3)"
  bel="$(printf '%s' "$dline" | cut -f4)"

  if [ "$pstatus" != ok ]; then
    no "[L2-diff] ${msg} — 락 GREEN 인데 파서는 이 frontmatter 를 파싱하지 못한다(런타임이 읽지 못할 선언을 승인)"
    return
  fi

  case "$basis" in
    zero-seq)
      if [ "$pkind" = list ] && [ -z "$ptoks" ]; then
        ok "[L2-diff] ${msg} — zero-tool 근거 GREEN, 파서도 실제 빈 시퀀스"
      else
        no "[L2-diff] ${msg} — 락은 zero-tool(\`[]\`) 근거로 통과시켰는데 파서는 ${pkind}='${ptoks}' 로 resolve 한다"
      fi
      ;;
    scalar)
      # 락이 믿은 토큰 집합을 파서 쪽과 같은 표현(| join)으로 정규화.
      local beltoks
      beltoks="$(printf '%s' "$bel" | tr ',' '\n' | sed 's/^[ 	]*//; s/[ 	]*$//' | grep -v '^$' | paste -sd'|' -)"
      if [ "$pkind" = str ] && [ "$beltoks" = "$ptoks" ]; then
        ok "[L2-diff] ${msg} — scalar 근거 GREEN, 파서 토큰과 정확히 일치"
      else
        no "[L2-diff] ${msg} — 락이 검증한 토큰 '${beltoks}' vs 파서 ${pkind}='${ptoks}'"
      fi
      ;;
    *)
      no "[L2-diff] ${msg} — 알 수 없는 DECL basis '${basis}'"
      ;;
  esac
}

echo "== 기준선: 락과 파서가 합치해야 하는 정상 형태 =="
dcase GREEN ok:str  "tools: Read, Grep, Glob"          'tools: Read, Grep, Glob'
dcase GREEN ok:list "tools: [] (zero-tool 선언)"        'tools: []'
dcase GREEN ok:list "tools: []<후행 공백>"               'tools: []   '
dcase GREEN ok:list "tools:<선행 공백>[]"                'tools:   []'
dcase GREEN ok:str  "tools: ... # 인라인 주석"           'tools: Read, Grep, Glob # 정상 주석'

# 🔴 S-1 — 중복 키. 파서는 **마지막** 값으로 resolve 하는데 락은 첫 값을 본다.
# `^tools:` 정규식은 콜론 앞 공백/인용 스펠링을 못 봐서 중복 가드가 발화하지 않았다.
echo "== S-1: 파서가 같은 키로 읽는 대체 스펠링 (전부 tools 로 resolve) =="
dcase RED ok:list "tools: [] + 'tools : [Write]' (콜론 앞 공백)"     'tools: []\ntools : [Write]'
dcase RED ok:list "tools: [] + '\"tools\": [Write]' (이중 인용 키)"   'tools: []\n"tools": [Write]'
dcase RED ok:list "tools: [] + \"'tools': [Write]\" (단일 인용 키)"   "tools: []\n'tools': [Write]"
dcase RED ok:list "tools: [] + 'tools   : [Write]' (다중 공백)"      'tools: []\ntools   : [Write]'
dcase RED ok:str  "'\"tools\": Read, Grep' 단독 — 정규 스펠링이 아니면 통과 금지" '"tools": Read, Grep'
# 이 케이스가 step-2("키가 하나인데 정규형이 아니면 FAIL")의 **가장 위험한 형태**다: 금지 도구도
# 인용부호도 없어서 값-단계 거절이 하나도 발화하지 않는다. 락이 정규형을 요구하지 않으면
# `tools : Read, Grep` 을 통째로 값으로 오해해 토큰 'tools : Read' 를 검증하고 넘어간다 —
# 파서는 'Read','Grep' 을 부여한다. 락과 파서가 **다른 토큰 집합**을 보는 상태로 GREEN.
dcase RED ok:str  "'tools : Read, Grep' 단독 (콜론 앞 공백, 금지 도구 없음)" 'tools : Read, Grep'

# 🔴 S-1 봉쇄의 **닫힘 증명**: 아래 4종은 "인용/공백" 열거로는 절대 못 잡는다.
# 열거가 아니라 column-0 줄 형태 화이트리스트가 잡아야 한다.
echo "== S-1 닫힘: 열거로는 못 잡는 스펠링 (형태 화이트리스트가 backstop) =="
dcase RED ok:list "tools: [] + '!!str tools: [Write]' (tag)"          'tools: []\n!!str tools: [Write]'
dcase RED ok:list "tools: [] + '&a tools: [Write]' (anchor)"          'tools: []\n&a tools: [Write]'
dcase RED ok:list "tools: [] + '\"\\\\u0074ools\": [Write]' (escape)"  'tools: []\n"\\\\u0074ools": [Write]'
dcase RED ok:list "tools: [] + '? tools / : [Write]' (explicit key)"  'tools: []\n? tools\n: [Write]'

# 🔴 S-2 — 값 패딩. POSIX [[:space:]] 는 CR/VT/FF 와 (UTF-8 로케일에서) NBSP 까지 먹어서
# 락이 `[]` 라고 믿는 값을 파서는 문자열로 읽거나(NBSP) 아예 파싱하지 못한다(CR/VT/FF/TAB).
echo "== S-2: 값 패딩 — 제어문자 / 비-ASCII 공백 =="
dcase RED ok:str  "tools: <NBSP>[] — 파서는 빈 시퀀스가 아니라 문자열로 읽는다" 'tools: \0302\0240[]'
dcase RED err:-   "tools: <CR>[] — 파서는 파싱조차 못 한다"                    'tools: \r[]'
dcase RED err:-   "tools: <VT>[] — 파서는 파싱조차 못 한다"                    'tools: \v[]'
dcase RED err:-   "tools: <FF>[] — 파서는 파싱조차 못 한다"                    'tools: \f[]'
dcase RED err:-   "tools: <TAB>[] — YAML 은 tab 을 노드 구분자로 금지한다"      'tools: \t[]'
# 패딩 자리가 아니라 **토큰 한가운데**의 제어문자 — (b) 패딩 검사는 여기 닿지 못하므로
# 이 케이스가 (a) 제어문자 검사의 유일한 이빨이다. 토큰 트림도 못 벗기는 위치라
# 락은 'Gre<VT>p' 를 무해한 이름으로 보고 통과시키지만, 파서는 파일 전체를 못 읽는다.
dcase RED err:-   "tools: Read, Gre<VT>p — 토큰 중간 제어문자(패딩 검사 사각지대)" 'tools: Read, Gre\vp'

# 🔴 같은 클래스의 파생: 주석 introducer 판정. YAML 이 `#` 을 주석으로 보는 조건은 **space/tab
# 선행**뿐이다 — NBSP 선행 `#` 은 파서에게 값의 일부다. 락의 주석 제거가 로케일 의존
# `[[:space:]]` 였다면 NBSP 를 먹고 `# …` 를 벗겨 파서와 다른 토큰을 보게 된다.
echo "== S-2 파생: 주석 introducer 는 space/tab 선행일 때만 =="
dcase GREEN ok:str "tools: Read, Grep<NBSP># x — 주석이 아니라 값의 일부(양쪽 합치)" 'tools: Read, Grep\0302\0240# x'
dcase RED   ok:str "tools: Read<NBSP># x, Write — 주석으로 오인해 벗기면 Write 를 놓친다" 'tools: Read\0302\0240# x, Write'

# 🔴 A-2 (v2.14.2) — 콜론 뒤 구분자 없음. `tools:[]` 는 파서에게 `tools` 키가 **아니다**:
# 구분이 없으면 콜론은 mapping indicator 가 아니라 plain scalar 의 한 글자라 문서 전체가
# 하나의 root scalar 가 되고 ScannerError 다. 그런데 c982607 의 카브아웃은 이 줄을 통과시키고
# `[]` 정확 일치로 **basis=zero-seq** 를, 즉 *"이 agent 는 도구가 0개"* 를 적극적으로 단언했다
# (5b0caff FAIL → c982607 PASS → 199d682 PASS). 어떤 파서도 읽지 못하는 문서에 대한 단언이다.
echo "== A-2: 콜론 뒤 YAML 구분자가 없으면 그 줄은 'tools' 키가 아니다 =="
dcase RED err:- "tools:[] — 구분자 없음, 파서는 ScannerError (zero-seq 로 단언하던 fail-open)" 'tools:[]'
dcase RED err:- "tools:Read, Grep — 구분자 없음, 파서는 ScannerError"                          'tools:Read, Grep'
dcase RED err:- "tools:<TAB>[] — 콜론 직후 tab, 파서는 ScannerError"                           'tools:\t[]'

# 🔴 A-3 (v2.14.2) — 형태 화이트리스트의 경계를 다섯 줄 전부 **의도적으로** 못 박는다.
# codex 감사는 네 형태를 "정당한 YAML 인데 거절된다" 고 보고했지만 파서로 재보니 둘만 진짜
# over-reject 였다. 나머지는 거절이 load-bearing 이다 — 특히 merge key.
echo "== A-3 완화: 파서가 정상 resolve 하는 두 형태는 GREEN 이어야 한다 =="
dcase GREEN ok:str "column-0 블록 시퀀스 항목 (skills: / - code-review)" 'skills:\n- code-review\n- other\ntools: Read, Grep'
dcase GREEN ok:str "column-0 블록 시퀀스 + 빈-값 키의 인라인 주석"        'skills: # 목록\n- code-review\ntools: Read, Grep'
dcase GREEN ok:str "'.' 을 포함한 최상위 키 (x.y: 1)"                    'x.y: 1\ntools: Read, Grep'
dcase GREEN ok:str "'_' 로 시작하는 최상위 키 (_foo: 1)"                 '_foo: 1\ntools: Read, Grep'

echo "== A-3 유지: 계속 거절해야 하는 세 형태 =="
# ⚠️ merge key 는 앵커가 **실제로 tools 를 실어야** 의미가 있다. 두 변형을 다 못 박는다:
#   (1) column-0 `tools:` 줄이 하나도 없는 형태 — 파서는 ['Write'] 를 부여하는데 락의
#       TOOLS_KEY_RE·중복 카운트·값 검사는 전부 발화하지 않는다(오늘 잡는 건 "부재" 검사뿐).
#   (2) `tools: []` 를 덧붙여 부재 검사를 만족시킨 형태 — 이때 파서는 명시 키를 우선해
#       `[]` 로 resolve 한다(실측). 락을 RED 로 지키는 것은 **형태 화이트리스트뿐**이라
#       이 줄이 (A) 거절의 이빨이다. 여기를 풀면 안전성이 파서의 merge 우선순위에 얹힌다.
dcase RED ok:list "merge key '<<: *d' — 앵커가 tools: [Write] 를 실어 주입(키 줄 0개)"   'defaults: &d\n  tools: [Write]\n<<: *d'
dcase RED ok:list "merge key + 'tools: []' — 부재 검사를 만족시켜도 형태로 거절"          'defaults: &d\n  tools: [Write]\ntools: []\n<<: *d'
dcase RED err:-   "document-end 마커 '...' — 파서도 못 읽는다(ParserError)"              '...\ntools: Read, Grep'
dcase RED ok:str  "인용 키 '\"description\": fixture' — 열면 \"tools\": 스펠링이 같이 열린다" '"description": fixture\ntools: Read, Grep'

echo "== A-3 완화가 새로 열지 않았는지: 블록 시퀀스는 직전 빈-값 키에 속할 때만 =="
dcase RED err:- "tools: [] 뒤 column-0 '- Write' — 파서는 ParserError"      'tools: []\n- Write'
dcase RED err:- "skills:/- a 뒤 tools: [] 뒤 '- Write' — seq_ok 가 리셋되는가" 'skills:\n- a\ntools: []\n- Write'
dcase RED err:- "선행 빈-값 키 없는 column-0 '- Write'"                      'tools: Read\n- Write'

# 사용자가 RED 로 유지하라고 못 박은 4종 — 카브아웃이 이걸 열면 안 된다.
echo "== 카브아웃 경계: 사용자 지정 stay-red 4종 =="
dcase RED ok:list "tools: [Write]"      'tools: [Write]'
dcase RED ok:list "tools: [ Read ]"     'tools: [ Read ]'
dcase RED ok:list "tools: [Read, Write]" 'tools: [Read, Write]'
dcase RED ok:null "bare tools: (YAML null)" 'tools:'

echo
if [ "$PARSER" = no ]; then
  echo "differential: L2 파서 합치 ${SKIP}건 SKIPPED (파서 부재 — 미실행, pass 아님)"
fi
finish
