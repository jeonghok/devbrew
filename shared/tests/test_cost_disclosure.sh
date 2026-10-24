#!/usr/bin/env bash
# guards: plugins/*/skills/*/SKILL.md CLAUDE.md docs/philosophy/*.md
# 지출 승인 대신 규모 공시(CLAUDE.md cost_class 줄 · 철학 P22).
#  (가) 모든 SKILL.md 와 규칙 문서에 지출 승인 문구가 없다 — 대상은 도출한다.
#  (나) 게이트가 있던 세 skill 의 공시 절에 「지출 승인을 묻지 않는다」 가 있다.
#  RC14 — 세 skill 의 루프 상한 · kill switch 는 남는다.
# Run (리포 루트에서): bash shared/tests/test_cost_disclosure.sh
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

BANNED=('지출 동의' '지출 전 명시' '지출-전 명시' '지출 승인 게이트' '승인 전에는 agent 를 보내지 않는다' '이름 붙인 예외')

derive_git() { git -C "$1" ls-files -- 'plugins/*/skills/*/SKILL.md' | sort; }
derive_find() { ( cd "$1" && find plugins -path '*/skills/*/SKILL.md' | sort ); }
derive_rules() { ( cd "$1" && ls CLAUDE.md docs/philosophy/*.md 2>/dev/null ); }

# scan <root> <목록 파일> — 걸린 파일마다 <파일>\t<문구>. 읽지 못한 파일도 낸다(조용한 통과 금지).
scan() {
  local root="$1" list="$2" f p
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ ! -r "$root/$f" ]; then printf '%s\t%s\n' "$f" '(읽을 수 없음)'; continue; fi
    for p in "${BANNED[@]}"; do
      if grep -qF -- "$p" "$root/$f"; then printf '%s\t%s\n' "$f" "$p"; fi
    done
  done < "$list"
}

if [ "${1:-}" = "--emit-scanned" ]; then
  derive_find "$ROOT"
  derive_rules "$ROOT"
  exit 0
fi

. "$ROOT/shared/tests/assert.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/cost-disclosure.XXXXXX")" || { no "mktemp 실패"; finish; exit 1; }
[ -n "$TMP" ] && [ -d "$TMP" ] || { no "임시 디렉토리가 없다"; finish; exit 1; }
trap 'rm -rf "$TMP"' EXIT

# ── 도출 + 양성 대조 ──────────────────────────────────────────────────────
derive_git "$ROOT" > "$TMP/git.lst"
derive_find "$ROOT" > "$TMP/find.lst"
derive_rules "$ROOT" > "$TMP/rules.lst"
n_git="$(grep -c . "$TMP/git.lst")"
n_find="$(grep -c . "$TMP/find.lst")"
if [ "$n_git" -gt 0 ] && cmp -s "$TMP/git.lst" "$TMP/find.lst"; then
  ok "도출: git ls-files 와 find 가 같은 SKILL.md ${n_git}개를 낸다"
else
  no "도출: git ls-files(${n_git}) 와 find(${n_find}) 가 다르거나 0 이다 — 추적되지 않은 SKILL.md 가 있거나 도출이 비었다"
  diff "$TMP/git.lst" "$TMP/find.lst" | sed 's/^/      /'
fi
assert_eq "$(grep -cxF 'CLAUDE.md' "$TMP/rules.lst")" "1" "도출: 규칙 문서에 CLAUDE.md 가 든다"
n_phil="$(grep -c '^docs/philosophy/' "$TMP/rules.lst")"
[ "$n_phil" -gt 0 ] && ok "도출: 규칙 문서에 docs/philosophy/*.md ${n_phil}개가 든다" || no "도출: docs/philosophy/*.md 를 하나도 찾지 못했다"

# ── (가) 실제 레포 — 지출 승인 문구 0 ───────────────────────────────────────
cat "$TMP/find.lst" "$TMP/rules.lst" > "$TMP/all.lst"
hits="$(scan "$ROOT" "$TMP/all.lst")"
assert_eq "$hits" "" "(가) SKILL.md · CLAUDE.md · 철학 문서에 지출 승인 문구가 없다"

# 양성 — 상한을 여는 질문은 걸리지 않는다(훑은 목록에 들었고 문구가 있고 scan 이 내지 않는다).
for pair in 'plugins/spec-distill/skills/pm-interview/SKILL.md|닿으면 연장을 묻는다' \
            'plugins/spec-distill/skills/reviewing-brief/SKILL.md|「추가 라운드 1회 열기」'; do
  f="${pair%%|*}"; lit="${pair#*|}"
  assert_eq "$(grep -cxF -- "$f" "$TMP/find.lst")" "1" "(가) 양성: ${f} 가 훑은 목록에 든다"
  assert_contains "$(cat "$ROOT/$f")" "$lit" "(가) 양성: ${f} 에 「${lit}」 가 있다"
  assert_not_contains "$hits" "$f" "(가) 양성: 상한을 여는 질문(${lit})은 걸리지 않는다"
done

# ── (가) 내장 양성 대조 — 사본에서 문구를 심으면 scan 과 도출이 잡는다 ──────────
C="$TMP/copy"
while IFS= read -r f; do
  [ -n "$f" ] || continue
  mkdir -p "$C/$(dirname "$f")" && cp "$ROOT/$f" "$C/$f"
done < "$TMP/find.lst"
derive_find "$C" > "$TMP/c0.lst"
assert_eq "$(scan "$C" "$TMP/c0.lst")" "" "대조: 손대지 않은 사본은 깨끗하다"
QP='plugins/quality-gates/skills/quality-pipeline/SKILL.md'
if [ -f "$C/$QP" ]; then
  printf '%s\n' '지출 동의 게이트' >> "$C/$QP"
  assert_eq "$(scan "$C" "$TMP/c0.lst")" "$(printf '%s\t%s' "$QP" '지출 동의')" "대조 (1): quality-pipeline 사본에 「지출 동의 게이트」 를 붙이면 그 파일 한 줄이 걸린다"
  cp "$ROOT/$QP" "$C/$QP"
else
  no "대조 (1): 사본에 ${QP} 가 없다 — 도출이 그 skill 을 놓쳤다"
fi
ZZ='plugins/zz/skills/zz/SKILL.md'
mkdir -p "$C/$(dirname "$ZZ")" && printf '%s\n' '이름 붙인 예외' > "$C/$ZZ"
derive_find "$C" > "$TMP/c1.lst"
assert_eq "$(grep -c . "$TMP/c1.lst")" "$((n_find + 1))" "대조 (2): 새 skill 을 더하면 find 도출이 하나 는다"
assert_eq "$(scan "$C" "$TMP/c1.lst")" "$(printf '%s\t%s' "$ZZ" '이름 붙인 예외')" "대조 (2): 새 skill 의 지출 승인 문구가 걸린다"

# ── (나) 세 skill 의 공시 절 ────────────────────────────────────────────────
# win <파일> <시작 줄 머리> <끝 줄 머리> — 시작 줄부터 끝 줄 앞까지(머리는 줄 맨 앞 글자 그대로). 끝을 못 찾으면 rc 3.
win() {
  awk -v s="$2" -v e="$3" 'f && index($0, e)==1 {done=1; exit} index($0, s)==1 {f=1} f {print} END {exit (done ? 0 : 3)}' "$1"
}
EC="$ROOT/plugins/spec-distill/skills/epic-conductor/SKILL.md"
PA="$ROOT/plugins/plugin-audit/skills/plugin-audit/SKILL.md"
AC="$ROOT/plugins/quality-gates/skills/artifact-critique/SKILL.md"
W_EC="$(win "$EC" '### 4. 규모 공시' '##')"; rc_ec=$?
W_PA="$(win "$PA" '3. **범위 고르기 · 규모 공시' '4. **실행 디렉토리**')"; rc_pa=$?
W_AC="$(win "$AC" '### E3 — 범위 고르기 · 규모 공시' '##')"; rc_ac=$?
assert_eq "$rc_ec" "0" "(나) epic-conductor: 「### 4. 규모 공시」 절의 시작과 끝을 찾았다"
assert_eq "$rc_pa" "0" "(나) plugin-audit: step 3 「범위 고르기 · 규모 공시」 부터 step 4 앞까지 찾았다"
assert_eq "$rc_ac" "0" "(나) artifact-critique: 「### E3 — 범위 고르기 · 규모 공시」 절의 시작과 끝을 찾았다"
assert_contains "$W_EC" '지출 승인을 묻지 않는다' "(나) epic-conductor 규모 공시 절: 지출 승인을 묻지 않는다"
assert_contains "$W_PA" '지출 승인을 묻지 않는다' "(나) plugin-audit step 3: 지출 승인을 묻지 않는다"
assert_contains "$W_AC" '지출 승인을 묻지 않는다' "(나) artifact-critique E3: 지출 승인을 묻지 않는다"

# 규칙 문서도 같은 문장을 갖는다(음성 scan 의 양의 짝).
COST="$(grep -F '**모든 skill에 `cost_class` 선언**' "$ROOT/CLAUDE.md")"
P22="$(awk '/^### P22/{f=1;next} /^(## |### )/{f=0} f' "$ROOT/docs/philosophy/devbrew-harness-philosophy.md")"
assert_contains "$COST" '어느 클래스의 skill 도 지출 승인을 묻지 않는다' "규칙: CLAUDE.md cost_class 줄에 지출 승인을 묻지 않는다"
assert_contains "$P22" '어느 클래스의 스킬도 지출 승인을 묻지 않는다' "규칙: 철학 P22 에 지출 승인을 묻지 않는다"

# ── RC14 — 루프 상한 · kill switch 는 남는다 ──────────────────────────────────
assert_contains "$(cat "$EC")" 'DEVBREW_SPEC_DISTILL_DISABLE=1' "RC14 epic-conductor: kill switch"
assert_contains "$W_EC" '엔진의 재리뷰 상한까지' "RC14 epic-conductor: 규모 줄이 리뷰 라운드 상한을 밝힌다"
assert_contains "$(cat "$PA")" 'DEVBREW_PLUGIN_AUDIT_DISABLE=1' "RC14 plugin-audit: kill switch"
assert_contains "$W_PA" '상한 없음' "RC14 plugin-audit: step 3 이 상한 없는 부분을 밝힌다"
for lit in 'effective_max_rounds' 'artifact_stagnation.py' 'DEVBREW_QUALITY_GATES_DISABLE_CRITIQUE=1'; do
  assert_contains "$(cat "$AC")" "$lit" "RC14 artifact-critique: $lit"
done

finish
