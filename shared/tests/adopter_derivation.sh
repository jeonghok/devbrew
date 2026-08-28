# adopter_derivation.sh — «정본 포인터 채택자 도출» 공용 함수.
# 실행 파일이 아니라 라이브러리다(`assert.sh`·`presence_corpus.sh` 와 같은 관례).
# 이 파일 자체는 `ok`/`no` 를 쓰지 않으므로 `assert.sh` 보다 먼저 source 해도 무방하다 —
# 다만 호출부는 이미 `assert.sh` 를 함께 source 하고 있다.
#
#   . "$REPO_ROOT/shared/tests/adopter_derivation.sh"
#   derive_reference_adopters "$SD" "$CANON_REF" "$REPO_ROOT" "$emit_only"
#   adopters="$ADOPTERS"
#   scanned="$SCANNED"
#
# ── 무엇을 하는가 ────────────────────────────────────────────────────────────
# 정본(플러그인 레벨 레퍼런스 문서)을 가리키는 포인터가 있는 skill 을 그 skill 의
# 표면(`skills/<s>/SKILL.md` + `skills/<s>/references/*.md`)에서 도출한다. 채택자는
# **열거하지 않고 포인터에서 도출**한다 — 세 번째 skill 이 정본을 채택하면 자동으로
# 같은 대상이 된다.
#
# `emit_only=1` 이면 스캔한 표면 경로를 `repo_root` 기준 상대경로로 찍고 그 자리에서
# **exit 0** 한다 — `test_guards_coverage_bidirectional.sh` 가 읽는 `--emit-scanned`
# 계약이 정확히 이 시점에 필요하다(derive 만 하고 emit 을 caller 에 미루면 caller 마다
# 다시 같은 4줄을 복제해야 한다).
#
# ── 왜 공용인가 (Task 10, request-framing phase0) ───────────────────────────
# `test_proceed_gate_adopters.sh`(정본 proceed-gate.md)와 `test_compression_adopters.sh`
# (정본 compression.md)가 이 도출 로직을 각자 인라인으로 가졌더니 28줄 블록이 두 파일에
# 바이트 동일로 복제됐다 — `shared/tests/test_no_new_duplication.sh` 가 커밋 직전에
# 그 자리에서 RED 를 냈다(2026-08-29 실측). `presence_corpus.sh` 가 이미 겪은 것과 같은
# 모양의 결함이다(그 파일의 "왜 공용인가" 절 참고, Task 33 fix round 4) — 채택자 락이
# 셋째로 늘어나면 세 벌째 복제가 생기는 구조였다. 여기 한 벌만 둔다.
#
# ── 계약 ──────────────────────────────────────────────────────────────────
# 결과는 **전역 변수** `ADOPTERS`·`SCANNED` 로 돌려준다(개행 구분, 각 항목 뒤에 개행
# 하나 포함). bash 함수는 배열/문자열을 값으로 반환하지 못하므로, 이 파일을 소비하는
# 호출부들의 기존 관례(전역 누산 문자열)를 그대로 따른다 — 새 반환값 규약을 만들지 않는다.
# `emit_only=1` 경로는 함수 안에서 **exit 하고 돌아오지 않는다** — 호출부가 그 뒤에
# 별도로 emit 분기를 두지 않아도 되게 하려는 의도된 설계다.
derive_reference_adopters() {  # derive_reference_adopters <SD> <CANON_REF> <REPO_ROOT> <emit_only>
  local sd="$1" canon_ref="$2" repo_root="$3" emit_only="$4"
  local skill_dir surface f hit
  ADOPTERS=""
  SCANNED=""
  for skill_dir in "$sd"/skills/*/; do
    [ -d "$skill_dir" ] || continue
    surface=""
    for f in "$skill_dir"SKILL.md "$skill_dir"references/*.md; do
      [ -f "$f" ] || continue
      surface="$surface$f
"
    done
    [ -n "$surface" ] || continue
    hit=0
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      grep -qE -- "$canon_ref" "$f" && { hit=1; break; }
    done < <(printf '%s' "$surface")
    if [ "$hit" -eq 1 ]; then
      ADOPTERS="$ADOPTERS${skill_dir%/}
"
      SCANNED="$SCANNED$surface"
    fi
  done

  if [ "$emit_only" -eq 1 ]; then
    printf '%s' "$SCANNED" | sed "s|^$repo_root/||"
    exit 0
  fi
}
