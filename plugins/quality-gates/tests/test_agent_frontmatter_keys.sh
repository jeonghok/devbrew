#!/usr/bin/env bash
# 레거시 AC15 (v2.11.0 뒤집기): repo-wide agent 도구 표면 가드.
#
# 왜 이 파일이 수정 대상이고 새 파일이 아닌가 (Law 3):
#   v2.10.x 까지 이 락은 **틀린 컨벤션을 강제**했다. kebab 을 FAIL 시키면서
#   "Expected: allowedTools / disallowedTools (camelCase)" 라고 가르쳤는데,
#   `allowedTools` 는 공식 subagent frontmatter 필드가 아니다
#   (code.claude.com/docs/en/sub-agents 의 지원 필드는 `tools` / `disallowedTools`).
#   결함을 반쯤 고치고 락을 걸면 락이 나머지 절반을 영구화한다 — 이 파일이 그 실례다.
#   버그를 놓친 검증 파일을 편집하는 것이 compounding 이벤트다.
#
# 규칙 (plugins/*/agents/*.md 전부):
#   L1  `allowedTools` / kebab 변종 존재            -> FAIL
#   L2  `tools:` 부재                                -> FAIL  (카브아웃 없음)
#       + `tools:` 키 중복(YAML 은 마지막 값으로 resolve, grep -m1 은 첫 값을 봄) -> FAIL
#         — 중복 판정은 인용/콜론 앞 공백 스펠링까지 포함한다(v2.14.1 S-1)
#       + `tools:` 키가 하나인데 column 0 의 정규형이 아니면 -> FAIL
#       + `tools:` 콜론 뒤에 YAML 구분자(space/tab/줄끝)가 없으면 -> FAIL
#         (v2.14.2 A-2 — `tools:[]` 는 파서에게 `tools` 키가 아니라 ScannerError 인데
#          카브아웃이 "도구 0개" 라고 단언하던 fail-open)
#       + frontmatter 의 column-0 줄이 `# 주석` 도, `^[A-Za-z_][A-Za-z0-9_.-]*:` 도,
#         직전 빈-값 키에 속한 블록 시퀀스 항목(`- …`) 도 아니면 -> FAIL
#         (형태 화이트리스트 — 스펠링 열거의 닫힘 보증. v2.14.1 S-1 / v2.14.2 A-3)
#       + `tools:` 값에 ASCII 제어문자(tab 포함) 또는 패딩 자리의 비-ASCII 바이트 -> FAIL
#         (v2.14.1 S-2 — POSIX `[[:space:]]` 트림이 CR/VT/FF/NBSP 를 조용히 먹던 fail-open)
#       + `tools:` 값이 plain(unquoted) 단일 라인 comma-scalar 가 아니면 -> FAIL
#         (인용 "..."/'...', block scalar >/|, flow-seq [...], anchor &a/*a, tag !!seq 전부 거절 — M2 구조적 봉쇄)
#       + plain scalar 의 인라인 주석(` # ...`)은 토큰화 前 제거(인용이 없으니 `#` 은 늘 comment) -> 금지 도구 은닉 차단
#       (인용부호 `"..."`/`'...'` 는 한 겹 벗기고 계속 검증 — quote 로 금지 도구를
#        가릴 수 없게. adversarial review 가 실제 /tmp 픽스처로 재현한 YAML-구문 우회.)
#   L3  `tools:` 의 금지 도구에 **그 도구 이름의**
#       `# TOOL-EXCEPTION:` 마커가 frontmatter 에 없음 -> FAIL
#
# 금지 8종: Write · Edit · MultiEdit · NotebookEdit · Agent · Bash · Monitor · MCP 서버 grant
#   - `Monitor` 가 목록에 있는 이유: 공식 스키마상 `command` 는 "the same shell environment
#     as Bash" 에서 돌고 `ws` 는 임의 wss:// egress 다 = 이름만 다른 Bash + 네트워크.
#   - MCP 는 **서버 단위 grant만** 금지한다(`mcp__*` / `mcp__<server>` / `mcp__<server>__*`).
#     per-tool 정확한 이름은 허용 — runtime-verifier 가 chrome 15개를 개별 열거하도록
#     처방됐기 때문이다(서버 grant 는 15→~29 로 표면을 넓혀 upload_file 유출 벡터를 준다).
#
# 사용: test_agent_frontmatter_keys.sh [scan_root]
#   scan_root 생략 시 repo 최상위. mutation 테스트가 픽스처 root 를 넘긴다.
set -u
ROOT="${1:-$(git rev-parse --show-toplevel)}"
cd "$ROOT" || { echo "FAIL: scan root 진입 불가: $ROOT" >&2; exit 1; }

FORBIDDEN_NAMED="Write Edit MultiEdit NotebookEdit Agent Bash Monitor"
violations=0

# ── 진단 채널 (fd 3) — v2.14.2 A-1 ────────────────────────────────────────────
# 🔴 진단은 **stdout 을 절대 쓰지 않는다**. 예전 구현은 agent 루프 안에서 fd 1 로 printf 했다.
# stdout 이 쓰기 불가일 때(`>&-`) 그 printf 는 실패하지만 bash 의 stdio 버퍼에 내용이 **남고**,
# 바로 뒤 L3 토큰 루프의 process substitution 이 fork 하는 자식이 그 버퍼를 상속해
# **토큰 파이프로 flush** 했다. 그 결과 토큰 루프가 도구 이름 대신 DECL 텍스트를 읽고
# 금지 도구를 놓쳤다 — 진단 스위치 하나가 verdict 를 뒤집는 fail-open 이다.
# 실측(`tools: Read, Write` 픽스처, 199d682):
#                     정상 stdout   stdout 닫힘(`>&-`)
#     EMIT 미설정         rc=1            rc=1
#     EMIT=1              rc=1            rc=0   ← 진짜 Write 위반이 PASS
#
# 대책: 진단은 전용 fd 3 으로만 나가고, fd 3 은 시작 시 **항상 쓰기 가능**하게 확정한다.
# 실패한 쓰기가 없으면 상속될 버퍼도 없다 — 루프의 fd 공간과 원천적으로 교차하지 않는다.
#   (1) 호출자가 fd 3 을 제공했으면 그대로 쓴다 (differential 하니스가 `3>&1` 로 준다).
#       호출자 fd 를 덮어쓰지 않으려고 무조건 `exec 3>&1` 하지 않는다.
#   (2) 아니면 stdout 의 복제.
#   (3) stdout 도 못 쓰면 /dev/null — 진단은 사라지되 verdict 는 절대 흔들리지 않는다.
# `exec` 의 리다이렉션은 영구적이므로 `2>/dev/null` 은 그룹으로 스코프한다
# (`exec 3>&1 2>/dev/null` 로 쓰면 이후 모든 FAIL 메시지가 조용히 사라진다).
EMIT_DECL=no
if [ "${DEVBREW_AGENT_TOOLS_LOCK_EMIT:-0}" = 1 ]; then
  if ! { : >&3; } 2>/dev/null; then
    { exec 3>&1; } 2>/dev/null
    { : >&3; } 2>/dev/null || exec 3>/dev/null
  fi
  EMIT_DECL=yes
fi

# 리터럴 tab — case 패턴에서 쓰려고 루프 밖에서 한 번만 만든다(agent 마다 fork 하지 않도록).
TAB="$(printf '\t')"

# `tools:` 키 **후보** 탐지 정규식 — 의도적으로 넓다. 좁은 탐지는 fail-open 이고
# 넓은 탐지는 fail-closed 이므로, 애매하면 넓게 잡아 FAIL 로 보낸다.
TOOLS_KEY_RE="^[\"']?tools[\"']?[[:space:]]*:"

# frontmatter 창 = 첫 두 '---' 줄 사이.
fm_of() { awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$1"; }

# 서버 단위 MCP grant 판정 (per-tool 정확 이름은 grant 가 아니다).
is_server_grant() {
  local t="$1" rest
  case "$t" in mcp__*) ;; *) return 1 ;; esac
  rest="${t#mcp__}"
  [ "$rest" = "*" ] && return 0                      # mcp__*
  case "$rest" in *__\*) return 0 ;; esac            # mcp__<server>__*
  case "$rest" in *__*) return 1 ;; *) return 0 ;; esac  # __ 없으면 mcp__<server>
}

shopt -s nullglob
for f in plugins/*/agents/*.md; do
  FM="$(fm_of "$f")"

  # --- L1 ---
  if grep -qE '^(allowedTools|allowed-tools|disallowed-tools):' <<<"$FM"; then
    echo "FAIL [L1] $f: 존재하지 않는/잘못된 계층의 키. agent 의 실재 키는 'tools' / 'disallowedTools'." >&2
    echo "  ('allowed-tools' 는 command/skill 계층의 키다 — agent 와 무관.)" >&2
    violations=$((violations+1))
    continue
  fi

  # --- L2 ---
  # 🔴 락과 파서는 *어느 줄이 `tools` 키인가* 에 대해 서로 다를 수 없어야 한다.
  # 예전 `^tools:` 정규식은 파서가 같은 키로 읽는 스펠링 중 **정규형 하나만** 봤다:
  #     tools: []          <- 락이 본 줄 (카브아웃으로 통과)
  #     tools : [Write]    <- 파서가 마지막 값으로 resolve 하는 줄 (락은 존재조차 모름)
  # 실측(PyYAML 6.0.3): `tools :` · `tools   :` · `"tools":` · `'tools':` · `"tools" :` ·
  # `!!str tools:` · `&a tools:` · `? tools\n: …` · `"tools":` · `"\x74ools":` ·
  # `{tools: …, "tools": …}` 가 **전부** 같은 `tools` 키로 resolve 된다. 스펠링을 하나씩
  # 막는 건 새는 게임이다(이 파일이 ⑥~⑰ 로 세 라운드에 걸쳐 배운 그 게임) — 그래서 두 겹:
  #
  #   (1) **넓은 후보 탐지**: 인용/콜론 앞 공백 스펠링을 한 번에 센다. 2개 이상이면
  #       중복으로 FAIL, 1개인데 정규형이 아니면 FAIL. (락이 추론할 수 없는 형태를
  #       조용히 통과시키지 않는다.)
  #   (2) **형태 화이트리스트 = 닫힘 보증**: (1) 은 여전히 열거다. 이스케이프·태그·앵커·
  #       explicit key 는 아무리 열거해도 잡히지 않는다. 그래서 **여집합**으로 닫는다 —
  #       frontmatter 의 column-0 줄은 `# 주석` 이거나 `^[A-Za-z_][A-Za-z0-9_.-]*:` 여야 한다.
  #       이 형태 안에서는 **키 문자열 = 바이트 그대로**다(plain scalar 에는 이스케이프도
  #       태그도 앵커도 인용도 없다). block mapping 의 키는 반드시 column 0 에 오고 값의
  #       continuation 은 반드시 들여쓰기되므로, column-0 줄만 검사하면 키 공간이 전부
  #       덮인다. 따라서 (1) 이 놓친 **모든** 이색 스펠링은 여기서 걸린다.
  #
  # 중복이 왜 그 자체로 FAIL 인가: YAML 파서는 중복 키를 마지막 값으로 resolve 하는데
  # `grep -m1` 은 첫 값을 본다 — 앞에 무해한 decoy, 뒤에 금지 도구를 두면 이 락이
  # decoy 만 검증하고 런타임은 진짜(금지) 목록을 부여받는다. 보안 필드의 모호성은
  # 그 자체로 실격이다 — 조용히 첫 값을 취하지 않고 FAIL.
  tools_key_count="$(grep -cE "$TOOLS_KEY_RE" <<<"$FM")"
  if [ "$tools_key_count" -gt 1 ]; then
    echo "FAIL [L2] $f: 'tools:' 키가 ${tools_key_count} 번 중복 선언됨 — 보안 필드의 중복 키는" >&2
    echo "  모호하다(YAML 은 마지막 값으로 resolve, 이 락은 grep -m1 으로 첫 값을 봄). 하나로 합칠 것." >&2
    echo "  (인용 키 \"tools\"/'tools' 와 콜론 앞 공백 'tools :' 도 파서는 같은 키로 읽으므로 함께 센다.)" >&2
    violations=$((violations+1))
    continue
  fi

  tools_line="$(grep -m1 -E "$TOOLS_KEY_RE" <<<"$FM" || true)"
  if [ -z "$tools_line" ]; then
    echo "FAIL [L2] $f: 'tools:' allowlist 부재. denylist 단독은 공간(열거 누락)뿐 아니라" >&2
    echo "  시간에 대해서도 fail-open 이다 — 내일 추가될 도구는 오늘 열거할 수 없다." >&2
    violations=$((violations+1))
    continue
  fi

  # 후보가 정확히 하나여도 그것이 **정규형** `tools:` (column 0, 인용 없음, 콜론 앞 공백
  # 없음) 이 아니면 FAIL. 이 락은 정규형만 검증할 수 있고, 검증할 수 없는 형태를 조용히
  # 통과시키는 것이 바로 fail-open 이다.
  case "$tools_line" in
    tools:*) ;;
    *)
      echo "FAIL [L2] $f: 'tools:' 키가 정규 스펠링이 아니다: '${tools_line}'" >&2
      echo "  파서는 인용 키/콜론 앞 공백을 같은 'tools' 키로 읽지만 이 락은 정규형만 검증한다." >&2
      echo "  column 0 에 인용 없이 정확히 'tools: …' 으로 쓸 것." >&2
      violations=$((violations+1))
      continue
      ;;
  esac

  # ── v2.14.2 A-2: 콜론 뒤 **YAML 구분자**를 값 해석 前에 요구한다 ───────────────
  # 🔴 `tools:[]` 는 YAML 에서 `tools` 키가 **아니다**. 구분(space/tab/줄끝)이 없으면 콜론은
  # mapping indicator 가 아니라 plain scalar 의 한 글자다 — 실측(PyYAML 6.0.3):
  #     tools:[]        -> ScannerError (문서 전체가 root scalar, tools 항목 없음)
  #     tools:Read, Grep-> ScannerError
  #     tools: []       -> {'tools': []}
  # v2.14.0 카브아웃은 `tools:*` glob 으로만 정규형을 판정해서 `tools:[]` 를 통과시켰고,
  # 그 위에서 `[]` 정확 일치가 걸려 **basis=zero-seq** 즉 *"이 agent 는 도구가 0개"* 라고
  # 적극적으로 단언했다. 어떤 파서도 읽지 못하는 문서에 대한 단언이다 = fail-open.
  # (5b0caff FAIL → c982607 PASS → 199d682 PASS. 이 브랜치가 만든 결함.)
  # tab 을 구분자로 인정하되 값에 tab 이 있으면 아래 (a) 제어문자 검사가 거절한다 —
  # 두 검사는 서로 다른 것을 본다(구분 유무 vs 파싱 가능성). 어느 쪽이든 fail-closed.
  tools_after_colon="${tools_line#tools:}"
  sep_ok=no
  [ -z "$tools_after_colon" ] && sep_ok=yes          # 줄 끝 = 유효한 구분 (bare null; 값 단계에서 거절)
  case "$tools_after_colon" in
    ' '*)   sep_ok=yes ;;                            # space
    "$TAB"*) sep_ok=yes ;;                           # tab
  esac
  if [ "$sep_ok" = no ]; then
    echo "FAIL [L2] $f: 'tools:' 콜론 뒤에 YAML 구분자(space/tab/줄끝)가 없다: '${tools_line}'" >&2
    echo "  구분이 없으면 콜론은 mapping indicator 가 아니다 — 파서에게 이 줄은 'tools' 키가" >&2
    echo "  아니라 하나의 plain scalar 이고 문서는 ScannerError 다. 락이 통과시키면 파서가" >&2
    echo "  읽지도 못하는 문서에 대해 도구 표면을 단언하게 된다. 'tools: …' 로 쓸 것." >&2
    violations=$((violations+1))
    continue
  fi

  # 형태 화이트리스트 (닫힘 보증). 들여쓴 줄(값의 continuation)·빈 줄·`#` 주석은 통과,
  # column-0 줄은 정규 plain simple key 이거나 **직전 빈-값 키에 속한 블록 시퀀스 항목**이어야
  # 한다. 첫 위반 줄 하나만 보고한다.
  #
  # ── v2.14.2 A-3: 허용 형태를 두 가지 **정당한** YAML 로 넓힌다 ───────────────
  #   (i)  column-0 블록 시퀀스 항목 — `skills:` 다음 줄의 `- code-review`.
  #        YAML 은 시퀀스가 부모 키와 같은 열에 오는 것을 허용하고, 실측상 이때
  #        `tools` 는 정상 resolve 된다(`tools: 'Read, Grep'`). 순수 over-reject 였다.
  #   (ii) `.` 을 포함하거나 `_` 로 시작하는 최상위 키 — `x.y: 1`, `_foo: 1`.
  #        둘 다 plain simple key 이고 파서는 정상 resolve 한다. 키 문자열이 바이트
  #        그대로라는 이 화이트리스트의 근거는 `.`/`_` 에도 그대로 성립한다
  #        (이 문자들로는 `tools` 라는 키 이름을 만들 수 없다).
  #
  # 🔴 나머지 세 형태는 **의도적으로 계속 거절한다**. "유효한 YAML 을 거절한다" 는 버그
  # 리포트를 받고 이 목록을 푸는 다음 사람을 위해 각각의 근거를 여기 적는다:
  #   (A) merge key `<<: *anchor` — 이 락이 **해석할 수 없는** 형태이고, 파서는 여기서
  #       column-0 `tools:` 줄 **없이** 도구 목록을 부여한다. 실측(PyYAML 6.0.3):
  #           defaults: &d
  #             tools: [Write]
  #           <<: *d
  #       → `tools: ['Write']`. 이 문서에는 `tools` 를 키로 쓴 column-0 줄이 하나도 없어서
  #       TOOLS_KEY_RE·중복 카운트·값 검사가 **전부 발화하지 않는다**(오늘 이 형태를 잡는 것은
  #       "tools: 부재" 검사 하나뿐이고, 그건 값-단계 방어가 아니다).
  #       ⚠️ 정직하게: 여기에 column-0 `tools: []` 를 덧붙여 부재 검사를 만족시키면 YAML 의
  #       merge 의미론상 **명시 키가 merge 를 이긴다**(실측: `tools=[]`). 그래서 merge 거절은
  #       오늘 유일한 방벽이 아니라 **두 번째 독립 방벽**이다. 그래도 유지하는 이유: 이 락은
  #       앵커를 따라갈 수 없고, 거절을 풀면 안전성이 *"부재 검사 + 파서의 merge 우선순위"*
  #       라는 **락이 실행하지 않는 파서의 두 성질**에 얹히게 된다. 해석 불가 형태는 거절 —
  #       이 화이트리스트가 존재하는 규칙 그대로다.
  #   (B) document-end 마커 `...` — 파서도 못 읽는다(ParserError). 락이 통과시키면
  #       "런타임이 읽지 못할 선언" 을 승인하는 것이다(A-2 와 같은 클래스).
  #   (C) 인용 키 `"description": fixture` — 파서는 정상 resolve 하지만, 인용 키를 열면
  #       `"tools":` / `'tools':` / `"\x74ools":` 스펠링이 같이 열린다. 이 화이트리스트가
  #       존재하는 이유가 바로 그 스펠링 열거를 닫는 것이다(v2.14.1 S-1). 실 agent 17개
  #       중 인용 키를 쓰는 파일은 0개라 거절 비용도 0이다.
  bad_shape="$(awk '
    /^[[:space:]]*$/ { next }
    /^[[:space:]]/   { next }
    /^#/             { next }
    # 정규 plain simple key. 값이 비어 있으면(또는 주석뿐이면) 다음 column-0 `- ` 줄은
    # 이 키에 속한 블록 시퀀스다 -> 그때만 허용한다. `tools: []` 같이 값이 있는 키 뒤의
    # column-0 `- Write` 는 파서에게 ParserError 이므로 계속 거절해야 한다(실측).
    /^[A-Za-z_][A-Za-z0-9_.-]*:/ {
      rest = substr($0, index($0, ":") + 1)
      seq_ok = (rest ~ /^[[:space:]]*$/ || rest ~ /^[[:space:]]+#/) ? 1 : 0
      next
    }
    /^-[[:space:]]/ { if (seq_ok == 1) next; print; exit }
    /^-$/           { if (seq_ok == 1) next; print; exit }
    { print; exit }
  ' <<<"$FM")"
  if [ -n "$bad_shape" ]; then
    echo "FAIL [L2] $f: frontmatter 최상위 줄이 인식 가능한 형태가 아니다: '${bad_shape}'" >&2
    echo "  column 0 의 줄은 '# 주석', 정규 plain key(^[A-Za-z_][A-Za-z0-9_.-]*:), 또는 직전" >&2
    echo "  빈-값 키에 속한 블록 시퀀스 항목('- …') 이어야 한다." >&2
    echo "  인용 키·태그(!!str)·앵커(&a)·explicit key(?)·flow mapping({…})·merge key(<<:)·" >&2
    echo "  document-end(...)은 거절한다 — merge key 는 'tools' 키 줄이 하나도 없는 문서에" >&2
    echo "  도구 목록을 부여할 수 있고(락이 앵커를 따라갈 수 없다), 나머지는 파서가 못 읽거나" >&2
    echo "  스펠링 열거를 다시 연다. 각 거절의 근거는 이 검사 바로 위 주석 (A)/(B)/(C)." >&2
    violations=$((violations+1))
    continue
  fi

  # `tools:` 값 정규화 — fail-closed: **단일 라인 plain(unquoted) comma-scalar 만** 검증 가능하고,
  # 그 외 YAML 형태는 전부 거절한다. 하나의 syntax 씩 막는 건 새는 게임이다 — codex 가 3회에 걸쳐
  # inline-comment → 인용 안 `#` → multiline-quoted 로 매번 새 우회를 재현했다(M2). 그래서 인용
  # ("..."/'...')·block scalar(`>`/`|`)·flow-seq(`[...]`)·anchor/alias(`&a`/`*a`)·tag(`!!seq`) 를
  # 통째로 거절한다: 이들은 값이 다음 줄로 이어지거나(multiline quoted/block scalar), 토큰이
  # 쪼개지거나(flow-seq), 참조/태그/이스케이프로 숨겨(anchor/tag/quoted) 금지 이름 정확매칭을
  # 피할 수 있다. 실 agent 17개는 전부 plain unquoted 라 이 거절로 잃는 것이 없다.
  #
  # 🔴 트림 **전에** 락과 파서가 같은 바이트를 다르게 읽게 만드는 문자를 걷어낸다.
  # POSIX `[[:space:]]` 는 이 코드가 주장해 온 "수평 공백"보다 훨씬 넓다 — CR·VT·FF 는
  # 물론 UTF-8 로케일에서는 NBSP(U+00A0)·U+2003 같은 비-ASCII 공백까지 먹는다. 그 결과:
  #   `tools: <CR>[]`   → 트림이 CR 을 먹어 카브아웃 통과. 파서는 ScannerError 로 **파싱조차
  #                       못 한다**(v2.14.0 에서 RED→GREEN 으로 뒤집힌 실제 회귀).
  #   `tools: <NBSP>[]` → 트림이 NBSP 를 먹어 `tools_val` 이 정확히 `5b 5d` 가 되고 카브아웃
  #                       통과. 파서는 그 값을 **빈 시퀀스가 아니라 문자열** '\xa0[]' 로 읽는다.
  # 비-ASCII 공백을 코드포인트로 열거하는 방어는 닫히지 않는다(U+1680·U+2000..200A·U+202F·
  # U+205F·U+3000·U+FEFF…). 그래서 **여집합**으로 간다.
  tools_raw="${tools_line#tools:}"
  # (a) ASCII 제어문자 — tab 포함. 실측(PyYAML 6.0.3): `tools:` 값 안의 CR/VT/FF/TAB 은
  #     위치를 불문하고 ScannerError/ReaderError 다(YAML 은 tab 을 노드 구분자로 금지).
  #     즉 파서가 **읽지도 못하는** 선언이므로 락도 읽지 않는다 — 정확히 합치하는 거절이다.
  if LC_ALL=C printf '%s' "$tools_raw" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    echo "FAIL [L2] $f: 'tools:' 값에 ASCII 제어문자(CR/VT/FF/TAB 등)가 있다." >&2
    echo "  YAML 파서는 이런 값을 파싱하지 못한다(ScannerError) — 락이 통과시키면 런타임이" >&2
    echo "  읽지도 못할 선언을 승인하는 것이다. 값은 space 로만 패딩할 것." >&2
    violations=$((violations+1))
    continue
  fi
  # (b) 패딩 자리(첫 graphic 문자 앞 / 마지막 graphic 문자 뒤)의 비-ASCII 바이트.
  #     `[!-~]` 는 LC_ALL=C 에서 바이트 0x21..0x7e — 로케일 독립이다.
  #     검사 대상은 **인라인 주석을 벗긴 사본**이다: 주석 본문은 파서가 값에서 버리므로
  #     한국어 주석(`tools: Read, Grep # 정상 주석`)까지 거절하면 over-reject 다. 사본만
  #     쓰고 본 흐름의 `tools_val` 은 건드리지 않는다 — 주석 제거를 앞당기면 `tools: [] # x`
  #     가 카브아웃으로 새어 **수용이 넓어진다**(그건 이 수정이 금지하는 방향이다).
  tools_probe="$(LC_ALL=C printf '%s' "$tools_raw" | LC_ALL=C sed 's/[[:blank:]]#.*$//')"
  pad_lead="$(LC_ALL=C printf '%s' "$tools_probe" | LC_ALL=C sed 's/[!-~].*$//')"
  pad_trail="$(LC_ALL=C printf '%s' "$tools_probe" | LC_ALL=C sed 's/^.*[!-~]//')"
  if [ -n "$(LC_ALL=C printf '%s%s' "$pad_lead" "$pad_trail" | LC_ALL=C tr -d ' ')" ]; then
    echo "FAIL [L2] $f: 'tools:' 값의 앞/뒤 패딩에 ASCII space 가 아닌 바이트가 있다" >&2
    echo "  (NBSP U+00A0 등 비-ASCII 공백). 트림은 먹지만 파서는 값의 일부로 읽어" >&2
    echo "  락과 파서가 서로 다른 값을 보게 된다 — fail-closed 로 거절한다." >&2
    violations=$((violations+1))
    continue
  fi
  # 이제 남은 패딩은 ASCII space 뿐이다. 트림은 **수평 공백 `[ \t]` 만** — LC_ALL=C 의
  # `[[:blank:]]` 는 정확히 space + tab 이다(로케일 독립). tab 은 (a) 에서 이미 걸러졌으므로
  # 여기 남는 건 space 뿐이지만, 트림 집합을 문서가 주장하는 것과 일치시켜 둔다.
  tools_val="$(LC_ALL=C printf '%s' "$tools_raw" | LC_ALL=C sed 's/^[[:blank:]]*//; s/[[:blank:]]*$//')"
  # ── v2.14.0 카브아웃: **리터럴 빈 시퀀스** `tools: []` 하나만 ──────────────
  # 위 flow-seq 전면 거절의 근거는 *"토큰이 다음 줄로 이어지거나 쪼개져/숨어 금지 이름
  # 정확매칭을 피할 수 있다"* 이다. 리터럴 빈 시퀀스에는 **숨길 토큰이 0개**라 그 근거가
  # 적용되지 않는다 — zero-tool agent(도구를 하나도 갖지 않는 격리 리뷰어)를 선언하는
  # 유일하게 안전한 형태다. bare `tools:`(YAML null)는 계속 거절한다: null 은 런타임이
  # "키 미설정 = 전 도구 허용"으로 읽을 수 있는 silent fail-open 이고 빈 시퀀스와 **다른
  # 값**이다.
  #
  # 술어는 2바이트 문자열 `[]` 에 대한 **정확 일치**다. 여기 도달하는 값의 패딩은 ASCII
  # space 뿐이다 — 위 (a)/(b) 가 제어문자(tab 포함)와 비-ASCII 공백을 이미 거절했고, 트림은
  # LC_ALL=C `[[:blank:]]`(= space + tab) 만 벗긴다. 그래서 `tools:   []   ` 은 도달하지만
  # `tools: <NBSP>[]` · `tools: <CR>[]` 은 도달하지 못한다(v2.14.0 은 도달시켰다 = S-2 회귀).
  # 대괄호 안에 무엇이든 허용하는 술어는 경계를
  # 가진 술어이고 경계는 틀릴 수 있다 — `[ ]` 를 열면 `[  ]`·`[\t]`·`[ , ]` 로 이어지는
  # 열거 게임이 시작된다(이 락이 ⑥~⑰ 로 세 라운드에 걸쳐 배운 그 게임). 그래서 `[ ]` 도
  # 거절한다. glob 이 아니라 `[ = ]` 문자열 비교를 쓰는 이유: `case` 패턴에서 `[]` 는
  # bracket expression 으로 해석될 여지가 있어 조용히 뜻이 달라진다.
  #
  # ⚠️ 여기서 `continue` 하지 말 것. 아래 multiline continuation 가드를 건너뛰면
  # `tools: []` 다음 줄에 들여쓴 `Write` 를 붙이는 우회가 열린다(mutation 케이스로 락함).
  # 카브아웃은 **이 case 의 거절만** 면제하고 나머지 검증은 그대로 통과시킨다.
  # (`[]` 는 아래 토큰 루프에서 금지 8종에도 MCP 서버 grant 에도 매칭되지 않는 무해 토큰.)
  is_zero_tool_seq=no
  [ "$tools_val" = "[]" ] && is_zero_tool_seq=yes
  if [ "$is_zero_tool_seq" = no ]; then
  case "$tools_val" in
    ''|\"*|\'*|'>'*|'|'*|'['*|'&'*|'*'*|'!'*)
      echo "FAIL [L2] $f: 'tools:' 값이 비어있거나 plain(unquoted) 단일 라인 scalar 가 아니다" >&2
      echo "  (인용 \"...\"/'...', block scalar >/|, flow-seq [...], anchor/alias &a/*a, tag !!seq)." >&2
      echo "  'tools: A, B, C' 형태로 바꿀 것 — 그 외 형태는 값이 다음 줄로 이어지거나 토큰이 쪼개져/" >&2
      echo "  참조·태그·이스케이프로 숨어 금지 이름 정확매칭을 피할 수 있어 fail-closed 로 거절한다." >&2
      echo "  도구를 하나도 주지 않으려면 **정확히** 'tools: []' 로 쓸 것 (bare 'tools:' 는 YAML null" >&2
      echo "  이라 런타임이 '키 미설정 = 전 도구 허용'으로 읽을 수 있어 거절된다)." >&2
      violations=$((violations+1))
      continue
      ;;
  esac
  fi
  # multiline plain scalar 탐지: `tools:` 다음 줄이 들여쓰기된 비어있지 않은 줄이면 값이 여러 줄로
  # 접혀 이어진다(plain 값이 tools: 줄에서 시작). grep -m1 은 첫 줄만 보므로 뒤 토큰을 놓친다 → 거절.
  # (block sequence `tools:\n  - X` 는 empty-value 로, block scalar `>`/`|` 와 인용 multiline 은 시작
  #  문자로 이미 거절됨. plain-multiline 이 그 외 유일한 잔여 경로 — 이걸 닫으면 "단일 라인 plain
  #  scalar 만 허용" 불변식이 완성된다.) `# TOOL-EXCEPTION:` 마커는 tools: 줄 *앞* 이라 무관.
  # awk 주의: main rule 의 `exit` 는 END 를 트리거하므로(END 가 exit code 를 덮어씀) 여기선
  # 플래그(ml)만 세우고 END 에서 한 번만 exit. tools: 다음의 빈 줄은 건너뛰고(YAML plain scalar 는
  # 빈 줄을 낀 채로도 이어질 수 있다 — `Read,\n\n  Write`) 첫 비어있지 않은 줄을 검사한다: 들여쓰기된
  # content 면 multiline(거절), top-level key/`---` 면 단일 라인(통과).
  if awk 'seen==1{if($0~/^[[:space:]]*$/)next; if($0~/^[[:space:]]+[^[:space:]]/)ml=1; seen=2} /^tools:/&&seen==0{seen=1} END{exit(ml?0:1)}' <<<"$FM"; then
    echo "FAIL [L2] $f: 'tools:' 값이 다음 줄로 이어지는 multiline scalar 다 — 단일 라인" >&2
    echo "  'tools: A, B, C' 로 바꿀 것 (multiline 은 첫 줄만 봐서는 뒤 토큰을 놓친다)." >&2
    violations=$((violations+1))
    continue
  fi
  # 이제 단일 라인 plain unquoted scalar 만 남았다 — 인라인 주석(` #...`)만 처리(인용이 없으니 `#` 은 늘 comment).
  # 주석 introducer 판정도 LC_ALL=C `[[:blank:]]` 로 고정한다: YAML 이 `#` 을 주석 시작으로
  # 보는 조건은 **space/tab 선행**뿐이라 NBSP 선행 `#` 은 파서에게 값의 일부다. 로케일에 따라
  # `[[:space:]]` 가 NBSP 를 먹으면 락만 주석으로 벗겨내 파서와 다른 토큰을 보게 된다.
  tools_val="$(LC_ALL=C printf '%s' "$tools_val" | LC_ALL=C sed 's/[[:blank:]]#.*$//; s/[[:blank:]]*$//')"

  # 진단 전용 emission — verdict 에 영향이 **전혀** 없고 기본 off 다. differential 하니스
  # (test_agent_tools_lock_differential.sh) 가 *"락이 검증했다고 믿는 값"* 을 추측 대신
  # 여기서 읽는다. 그 값을 테스트에 재구현하면 같은 버그를 두 번 쓰게 되어(순환) 파서와의
  # 합치를 아무것도 증명하지 못한다 — NBSP 우회가 정확히 그렇게 새어나갔다.
  # ⚠️ 출력은 반드시 fd 3 (위 "진단 채널" 참조). fd 1 로 되돌리면 A-1 fail-open 이 부활한다.
  if [ "$EMIT_DECL" = yes ]; then
    if [ "$is_zero_tool_seq" = yes ]; then
      printf 'DECL\t%s\tzero-seq\t\n' "$f" >&3
    else
      printf 'DECL\t%s\tscalar\t%s\n' "$f" "$tools_val" >&3
    fi
  fi

  # --- L3 ---
  # ⚠️ 이 루프의 세 줄은 실측으로 세 번 고쳤다 (아래 "이 루프를 고치지 말 것" 참조).
  while IFS= read -r raw; do
    tok="$(printf '%s' "$raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -n "$tok" ] || continue
    forbidden=no
    case " $FORBIDDEN_NAMED " in *" $tok "*) forbidden=yes ;; esac
    is_server_grant "$tok" && forbidden=yes
    [ "$forbidden" = yes ] || continue
    # 마커는 frontmatter 창 안에, 그 도구 이름으로, 근거와 함께 (도구별 1:1).
    esc="$(printf '%s' "$tok" | sed 's/[][\.*^$(){}?+|/]/\\&/g')"
    if grep -qE "^#[[:space:]]*TOOL-EXCEPTION:[[:space:]]*${esc}[[:space:]]+.+$" <<<"$FM"; then
      continue
    fi
    echo "FAIL [L3] $f: tools: 에 금지 도구 '$tok' 가 있는데 마커가 없다." >&2
    echo "  필요하면 frontmatter 에 정확히: # TOOL-EXCEPTION: $tok — <한 줄 근거>" >&2
    violations=$((violations+1))
  done < <(printf '%s\n' "$tools_val" | tr ',' '\n')
done

if [ "$violations" -gt 0 ]; then
  echo "FAIL: agent 도구 표면 위반 $violations 건" >&2
  exit 1
fi
echo "PASS: 모든 agent 가 tools: allowlist 를 선언하고 금지 도구는 마커를 동반한다"
exit 0
