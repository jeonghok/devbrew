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
#   L2  `tools:` 부재                                -> FAIL  (카브아웃 없음 — 8/8 해당)
#       + `tools:` 키 중복(YAML 은 마지막 값으로 resolve, grep -m1 은 첫 값을 봄) -> FAIL
#       + `tools:` 값이 비어있거나 block scalar(`>`/`|`, 진짜 목록이 다음 줄에 있음) -> FAIL
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
  # 중복 `tools:` 키 → FAIL. YAML 파서는 중복 키를 마지막 값으로 resolve 하는데
  # `grep -m1` 은 첫 값을 본다 — 앞에 무해한 decoy, 뒤에 금지 도구를 두면 이 락이
  # decoy 만 검증하고 런타임은 진짜(금지) 목록을 부여받는다. 보안 필드의 중복 키는
  # 그 자체로 모호/의심스럽다 — 조용히 첫 값을 취하지 않고 FAIL.
  tools_key_count="$(grep -cE '^tools:' <<<"$FM")"
  if [ "$tools_key_count" -gt 1 ]; then
    echo "FAIL [L2] $f: 'tools:' 키가 $tools_key_count 번 중복 선언됨 — 보안 필드의 중복 키는" >&2
    echo "  모호하다(YAML 은 마지막 값으로 resolve, 이 락은 grep -m1 으로 첫 값을 봄). 하나로 합칠 것." >&2
    violations=$((violations+1))
    continue
  fi

  tools_line="$(grep -m1 -E '^tools:' <<<"$FM" || true)"
  if [ -z "$tools_line" ]; then
    echo "FAIL [L2] $f: 'tools:' allowlist 부재. denylist 단독은 공간(열거 누락)뿐 아니라" >&2
    echo "  시간에 대해서도 fail-open 이다 — 내일 추가될 도구는 오늘 열거할 수 없다." >&2
    violations=$((violations+1))
    continue
  fi

  # `tools:` 값을 정규화: 트림 → block-scalar/empty 거절 → 인용 한 겹 벗기기.
  # 이 락은 단일 라인 plain scalar 만 검증할 수 있다 — block scalar(`>`/`|`, 접힘/유지
  # 변종 포함)는 진짜 목록이 다음 줄들(창 밖일 수도 있음)에 있어 여기서 보면 놓친다,
  # 그래서 FAIL 로 거절한다. 인용부호는 한 겹만 벗겨 값을 quoting 이전과 동일하게
  # 만든다 — 안 그러면 `"Read, Grep, Write"` 의 `Write"` 가 quote 에 가려 L3 를 피한다.
  tools_val="$(printf '%s' "${tools_line#tools:}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  case "$tools_val" in
    ''|'>'*|'|'*|'['*)
      echo "FAIL [L2] $f: 'tools:' 값이 비어있거나 YAML block scalar(>, |, 접힘/유지 변종 포함) 또는" >&2
      echo "  flow-sequence(\`[...]\`) 다. 이 락은 단일 라인 plain scalar 만 검증 가능 —" >&2
      echo "  'tools: A, B, C' 형태로 바꿀 것 (flow-sequence 는 토큰이 '[A'/'B]' 로 쪼개져 금지 이름" >&2
      echo "  정확매칭을 피해갈 수 있어 같은 fail-closed 정신으로 거절한다)." >&2
      violations=$((violations+1))
      continue
      ;;
  esac
  case "$tools_val" in
    \"*\") tools_val="${tools_val#\"}"; tools_val="${tools_val%\"}" ;;
    \'*\') tools_val="${tools_val#\'}"; tools_val="${tools_val%\'}" ;;
  esac

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
