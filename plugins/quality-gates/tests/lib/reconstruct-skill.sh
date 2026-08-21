#!/usr/bin/env bash
# reconstruct-skill.sh — quality-pipeline SKILL.md 를 references/runtime-gate.md
# 포인터 자리에 그 파일 본문을 되접어, 분할 전과 논리적으로 동일한 단일 문서로
# 재구성한다. `source`해서 `reconstruct_skill_md` 함수를 쓴다.
#
# 왜 필요한가 (Task 31, 무게 감축): `## Runtime gate` 절차 전문이
# skills/quality-pipeline/references/runtime-gate.md 로 옮겨지고 SKILL.md 에는
# 포인터 산문만 남았다. 이 리포의 여러 테스트(2026-08-21 기준 **7개**가 이 헬퍼를
# source 한다 — 예: tests/harness/test_skill_orchestration_behavior.sh ·
# tests/test_runtime_verdict_precedence.sh. **이 둘은 예시이지 목록이 아니다** —
# 실제 소비자는 `grep -rl reconstruct_skill_md plugins/` 로 도출할 것. 열거한 목록은
# 낡고, 낡은 목록은 "여기 없으니 무관하다"로 읽힌다)는 SKILL.md 를 줄 번호·섹션 윈도우로
# 분석해 Runtime 게이트 절차(Step R-init..R9)의 순서·근접성·본문을 검증한다 —
# 원래 단일 파일이라는 전제 위에서 설계됐다. 파일을 둘로 쪼개면서 그 검사 로직
# 수십 곳을 전부 다시 쓰는 대신, 검사가 읽을 **논리적으로 재구성된 문서**를
# 여기서 한 번 만든다: 포인터 블록 자리에 참조 파일을 그대로 삽입하면 분할
# 전 문서와 (섹션 경계의 빈 줄 1개를 빼면) 줄 단위로 동일해진다 — 아래 모든
# proximity 임계값(100~220줄)에 비하면 무시할 수 있는 오차다.
#
# 사용:
#   . ".../tests/lib/reconstruct-skill.sh"
#   if ! SKILL_MD="$(reconstruct_skill_md "$SKILL_MD_REAL")"; then
#     echo "FAIL: SKILL.md ↔ references/runtime-gate.md 재구성 실패"; exit 1
#   fi
#   trap 'rm -f "$SKILL_MD"' EXIT
#
# **실패는 침묵하지 않는다.** 포인터(`## Runtime gate` 헤딩)를 못 찾거나 참조
# 파일이 없거나 비어 있으면 stderr 에 사유를 낸 뒤 실패(rc≠0, stdout 없음)로
# 답한다 — 호출부가 이것을 원본 SKILL.md 로 조용히 폴백해 쓰면 안 된다. 폴백하면
# Runtime 관련 검사 전부가 포인터 산문 몇 줄만 보고 돌게 되어, 앵커 부재로 전량
# FAIL 하거나(창이 비어 음의 락이 vacuous 통과) 판정이 사실과 무관해진다.
reconstruct_skill_md() {   # $1 = SKILL.md 절대경로
  local skill="$1"
  local skill_dir out
  skill_dir="$(dirname "$skill")"
  out="$(mktemp -t reconstructed-skill-XXXXXX)" || return 1
  if awk -v skill_dir="$skill_dir" '
    BEGIN { in_ptr = 0; spliced = 0 }
    /^## Runtime gate$/ && !spliced {
      spliced = 1
      ref = skill_dir "/references/runtime-gate.md"
      n = 0
      while ((getline line < ref) > 0) { print line; n++ }
      close(ref)
      if (n == 0) {
        print "reconstruct-skill.sh: references/runtime-gate.md 부재 또는 빈 파일 (" ref ")" > "/dev/stderr"
        exit 3
      }
      print ""   # rstrip 이 지운 섹션 경계 빈 줄 1개 복원 (경계 근처 근접성 오차 최소화용, 판정에 load-bearing 아님)
      in_ptr = 1
      next
    }
    in_ptr && /^## / { in_ptr = 0 }
    in_ptr { next }
    { print }
    END {
      if (!spliced) {
        print "reconstruct-skill.sh: SKILL.md 에 \"## Runtime gate\" 포인터 헤딩이 없다 — 재구성 대상을 못 찾음" > "/dev/stderr"
        exit 3
      }
    }
  ' "$skill" > "$out"; then
    # ── 스플라이스 후 잔존 포인터 검사 (Task 33 fix round 4, F4) ──────────────
    #
    # 위 awk 는 **하드코딩된 한 섹션**(`## Runtime gate`)만 되접고, 그 헤딩이 없을 때만
    # 시끄럽게 죽는다. quality-pipeline/SKILL.md 가 **또** 쪼개지면(아직 906줄이다)
    # 재구성은 여전히 성공하고, 일곱 소비자에게 **새 섹션이 조용히 빠진 문서**를 넘긴다 —
    # 모든 소비자의 `if ! reconstruct_skill_md` 가드는 "성공"을 보고한다. 이 브랜치의
    # 헤드라인 실패 클래스가, 그것을 막으려고 만든 수리 뒤에 숨는 것이다.
    #
    # 판정 술어는 "references 토큰이 남았는가"가 **아니다** — 그러면 오늘 당장 거짓 RED 다.
    # 재구성 출력에는 `[state-file-format](references/state-file-format.md#history)` 같은
    # **인라인 상호참조 링크**가 정당하게 남는다(실측: 재구성본 552행). 그것은 되접을
    # 대상이 아니라 보조 문서 링크다.
    #
    # 되접혀야 하는 것은 이 리포가 **조건부 로드 포인터**에 쓰는 관용구다: 자기 줄에 홀로
    # 선 `Read <…references/x.md>` 지시(quality-pipeline · conducting-interview ·
    # reviewing-spec 전부 이 형태를 쓴다 — 실측 4곳). 그 줄이 출력에 남았다는 것은 곧
    # **아직 포인터인 채로 남은 섹션이 있다**는 뜻이다.
    local leftover
    leftover="$(grep -nE '^[[:space:]]*Read[[:space:]]+[^[:space:]]*references/[A-Za-z0-9_./-]+\.md' "$out" || true)"
    if [ -n "$leftover" ]; then
      printf 'reconstruct-skill.sh: 재구성 후에도 되접히지 않은 조건부-로드 포인터가 남아 있다 — SKILL.md 가 또 분할됐고 이 헬퍼는 한 섹션만 안다:\n%s\n' "$leftover" >&2
      rm -f "$out"
      return 1
    fi
    printf '%s\n' "$out"
    return 0
  fi
  rm -f "$out"
  return 1
}
