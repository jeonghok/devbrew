#!/usr/bin/env bash
# reconstruct-skill.sh — quality-pipeline SKILL.md 를 references/runtime-gate.md
# 포인터 자리에 그 파일 본문을 되접어, 분할 전과 논리적으로 동일한 단일 문서로
# 재구성한다. `source`해서 `reconstruct_skill_md` 함수를 쓴다.
#
# 왜 필요한가 (Task 31, 무게 감축): `## Runtime gate` 절차 전문이
# skills/quality-pipeline/references/runtime-gate.md 로 옮겨지고 SKILL.md 에는
# 포인터 산문만 남았다. 이 리포의 여러 테스트
# (tests/harness/test_skill_orchestration_behavior.sh ·
# tests/test_runtime_verdict_precedence.sh)는 SKILL.md 를 줄 번호·섹션 윈도우로
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
    printf '%s\n' "$out"
    return 0
  fi
  rm -f "$out"
  return 1
}
