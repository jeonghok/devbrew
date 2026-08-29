#!/usr/bin/env bash
# copy-of: shared/codex/runner_common.sh
# codex 러너의 fail-closed 산출물 정본. **부분 사본**이므로 파일 전체 동일화는
# 불가능하다(각 러너가 다른 프롬프트 빌더를 부른다) — 잔여는
# shared/tests/test_no_new_duplication.sh 의 20줄 검사가 지킨다.
#
# ── 이 파일을 source 하는 러너 (실측 도출: `grep -l runner_common.sh plugins/*/scripts/`) ──
# 중첩 YAML(`findings: []` + `meta:`)을 소비 계약으로 갖는 **셋**이다:
#   · plugins/quality-gates/scripts/run_codex_reviewer.sh
#   · plugins/spec-distill/scripts/run_spec_codex_reviewer.sh
#   · plugins/spec-distill/scripts/run_brief_codex_reviewer.sh
#
# ── source 하지 않는 러너 둘 — 스키마가 drift 가 아니라 **다른 소비자 계약**이다 ──
# 설계 §6.2 는 네 스키마(JSON · 평면 YAML · `agent:` 포함 중첩 · `agent:` 없는 중첩)를
# 하나로 통일하라고 적었다. 그 중 둘은 통일하면 소비자가 깨진다 — 2026-08-19 실측:
#
#   · plugins/plugin-audit/scripts/run_audit_codex_reviewer.sh → **JSON**.
#     소비자 `plugins/plugin-audit/scripts/assemble-audit-data.py:8` 이
#     `json.loads(...)` 로 읽고 `:95-103` 에서 `d_verdicts`·`oq_answers`·
#     `new_open_questions` 를 꺼낸다. 중첩 YAML 을 쓰면 `JSONDecodeError` 로 죽고,
#     이 정본의 스키마에는 그 세 키가 아예 없다. 조용한 degrade 가 아니라 hard crash 다.
#
#   · plugins/quality-gates/scripts/run_artifact_codex_reviewer.sh → **평면 YAML**
#     (`codex_failed: true` / `reason:`). 소비자
#     `plugins/quality-gates/scripts/synthesize_artifact_findings.py:85-93`
#     (`_is_findings_doc`)은 `findings:` 리스트가 **없는** 문서를 load 실패로 세어
#     `sources_failed` 를 올린다 — 그것이 이 파이프라인의 fail-closed 백스톱이다.
#     `findings: []` 를 쓰면 같은 문서가 "진짜로 발견 0건인 정상 소스"로 조용히
#     읽힌다(indeterminate 를 clean 으로 승격 — 이 리포가 반복해 막아 온 형태).
#     게다가 그 파이프라인의 주 degrade 산출자인
#     `plugins/quality-gates/scripts/extract_codex_artifact_yaml.py:76` 이 같은
#     평면 형태를 내므로, 러너만 중첩으로 바꾸면 한 파이프라인 안에서 스키마가
#     오히려 **둘로 갈라진다**.
#
# 그래서 이 정본이 통일하는 범위는 **중첩 YAML 계열 셋**이고, 나머지 둘은 위 근거로
# 남긴다. §6.2 의 "4종 → 1종"은 소비자 계약을 세지 않은 서술이다.
#
# ── 출력 스키마 (설계 §6.2) ──────────────────────────────────────────────
# 통합 전 셋의 출력이 갈라져 있었다(`agent:` 포함 중첩 vs 없는 중첩). 행동 등가 락이
# 판정만 재느라 스키마가 락 밖으로 샜다. 여기서 **중첩 YAML + findings: [] + meta:**
# 하나로 못박는다. 최상위 `agent:` 키는 넣지 않는다 — 성공 경로의 산출자
# `shared/codex/codex_findings_to_yaml.py:89-103`(`yaml_emit`)이 `agent:` 를
# **finding 마다**(`  - agent: codex-reviewer`) 달 뿐 최상위에는 내지 않으므로,
# degrade 경로에만 있던 최상위 `agent:` 는 성공 경로에도 없는 키였다. 읽는 소비자도
# 없다(`synthesize_findings.py:37-42` 는 `findings`/`verdicts` 만 꺼낸다).

# _degrade_if_empty <output_path> <reason> [exit_code]
# 산출물이 비었거나 없을 때 fail-closed 산출물을 쓴다. **쓰지 못하면 exit 3** —
# 호출자는 그때 직전 라운드 잔존 YAML 을 제거해야 한다(그러지 않으면 옛 판정이
# 이번 라운드 판정으로 읽힌다).
_degrade_if_empty() {
  local out="${1:-}" reason="${2:-unknown}" rc="${3:-0}"
  # `-n` 검사 — run_codex_reviewer.sh:92 에만 빠져 있었다. 빈 경로에 쓰기를 시도하면
  # 리다이렉션이 실패하고 산출물이 없는 채로 성공이 보고된다.
  if [ -z "$out" ]; then
    echo "_degrade_if_empty: OUTPUT_PATH 가 비었다" >&2
    return 3
  fi
  if [ -s "$out" ]; then return 0; fi
  {
    printf 'findings: []\n'
    printf 'meta:\n'
    printf '  codex_failed: true\n'
    printf '  reason: %s\n' "$reason"
    printf '  exit_code: %s\n' "$rc"
  } > "$out" 2>/dev/null || {
    echo "_degrade_if_empty: '$out' 에 쓸 수 없다" >&2
    return 3
  }
  # loud degradation (CLAUDE.md "Loud logging을 동반한 graceful degradation").
  # 이관 전에는 이 줄이 러너마다 자기 플러그인 태그로 있었다. 정본으로 올리면서
  # 태그 대신 **경로**를 싣는다 — 어느 러너가 degrade 했는지는 경로가 말해 주고,
  # 호출자의 전역이나 4번째 인자를 읽지 않아도 된다.
  echo "[devbrew:codex] 러너가 완료 전에 중단됨 — degrade 기록(stale 재사용 방지): $out (reason=$reason)" >&2
  return 0
}

# write_failclosed <output_path> <reason>
# fail-closed 산출물을 **무조건** 쓴다(_degrade_if_empty 는 산출물이 비었을 때만 쓴다 —
# 그 차이 때문에 두 함수는 합쳐지지 않는다).
#
# 이관 전 두 러너는 이것을 `write_failclosed <reason>` 한 인자로 부르고 경로는 **전역
# `$OUTPUT_PATH`** 에서 읽었다. 정본은 경로를 인자로 받는다 — 바로 위 `_degrade_if_empty`
# 와 같은 자리에 같은 뜻의 인자를 두기 위해서다(공유 파일이 호출자의 전역을 읽으면
# 그 전역 이름이 조용한 계약이 된다).
#
# **인자가 하나 늘어나므로 호출부를 하나라도 빠뜨리면 안 된다.** 빠뜨린 호출
# `write_failclosed "runner_incomplete"` 는 out="runner_incomplete" · reason="" 가 되어
# **엉뚱한 파일 이름으로 쓰기를 시도**한다. 아래 빈-인자 가드가 그것을 조용히 통과시키지
# 않고 RED 로 만든다 — `field` 인자 순서와 같은 부류의 실패원이라 가드를 뺄 수 없다.
write_failclosed() {
  local out="${1:-}" reason="${2:-}"
  if [ -z "$out" ] || [ -z "$reason" ]; then
    echo "write_failclosed: <output_path> <reason> 두 인자가 필요하다 (out='$out' reason='$reason')" >&2
    return 1
  fi
  {
    echo 'findings: []'
    echo 'meta:'
    echo '  codex_failed: true'
    echo "  reason: $reason"
  } > "$out" || {
    echo "[spec-distill] fail-closed YAML 기록 실패: $out ($reason)" >&2
    return 1
  }
}

# codex_extract_or_fallback <stdout_file> <stderr_file> <exit_code> <output_path> <emit_keys> <plugin_root>
# codex_findings_to_yaml.py 를 표준 인자(override-exit-code·override-reason 유도
# 포함)로 부른다. 실패하면(추출기 자체가 비-0 으로 죽으면) **아무것도 쓰지 않고
# 실패로 반환한다** — output_path 를 그다음 어떻게 채울지(즉시 exit 0 인
# emit_fallback 호출인지, 인라인 echo 넷인지)는 호출자마다 다르므로 호출자 몫으로
# 남긴다. 이 함수가 그 exit 까지 가지면 형제 러너 셋의 서로 다른 실패 처리 모양을
# 강제로 통일하게 된다.
#
# 세 번째 러너(run_seed_codex_reviewer.sh, Task 14)가 형제 둘과 이 tail 을
# 바이트-동일하게 써서 `shared/tests/test_no_new_duplication.sh` 의 20줄 창에
# 걸린 것을 해소하며 정본화됐다.
#
# **`codex exec ...` 호출 자체는 여기 넣지 않는다.** 넣으면 이 정본의 배포
# 사본(`plugins/*/scripts/runner_common.sh`)이 `codex_candidates()`
# (`plugins/quality-gates/tests/lib/codex_observation.sh`) 스캔에 "새 러너"로
# 잡히는데, 그 스캐너는 실행 가능한 진입점을 기대한다(`obs_invoke` 의 case 표) —
# 라이브러리 파일은 그 표에 없어 관측 락 여럿(test_sandbox_enforced.sh ·
# test_codex_invocation_contract.sh · test_web_kill_switch.sh)이 "실행할 방법이
# 없다"로 조용히 깨진다. 그래서 codex 호출 플래그(`-s read-only` · `-C` · `--json`
# · web 인자)는 각 러너 파일에 리터럴로 남기고, 여기서는 그 뒤(override_reason
# 유도 + 추출)만 정본화한다.
codex_extract_or_fallback() {
  local stdout_file="$1" stderr_file="$2" exit_code="$3" output_path="$4" \
        emit_keys="$5" plugin_root="$6"
  local override_reason=""
  if [ "$exit_code" -ne 0 ]; then
    override_reason=exit_nonzero
  fi
  python3 "$plugin_root/scripts/codex_findings_to_yaml.py" \
      --stderr-file "$stderr_file" \
      --meta-override-exit-code "$exit_code" \
      --meta-override-reason "$override_reason" \
      --emit-keys "$emit_keys" \
      < "$stdout_file" > "$output_path"
}
