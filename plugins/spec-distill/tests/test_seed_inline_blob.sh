#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/build_seed_inline_blob.py
#
# build_seed_inline_blob.py 를 실행 기반으로 검증한다(fix round 1, Important 4).
# 이 스크립트는 seed-critic.md 가 문서화한 `<draft>${BLOB}</draft>` 의 **안쪽
# 내용**을 조립한다 — 초안(frontmatter 제외) + audit `## 1. 원문` + 레포 CLAUDE.md
# 세 재료를 하나로 묶는다. 소비자는 framing-requests/SKILL.md 의 「재료 조립」
# 블록이고, 그 블록이 만든 번들을 격리 critic 과 codex 러너가 나눠 쓴다 — 조립이
# 한 곳인 것이 두 리뷰어가 같은 재료를 본다는 근거다. 이 파일은 그 조립기의 계약을
# 소비자와 무관하게 실행으로 못 박는다. 형제 build_brief_inline_blob.py 의 관용구(정상 경로 · 재료별
# 부재 exit 2 · 조용한 결측 금지 · mutation)를 이 스크립트의 실제 계약(redaction이
# 아니라 3-재료 조립)에 맞춰 적용한다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$ROOT/plugins/spec-distill/scripts/build_seed_inline_blob.py"

. "$ROOT/shared/tests/assert.sh"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/scripts/build_seed_inline_blob.py"
  exit 0
fi

test -f "$SCRIPT" || { no "부재: $SCRIPT"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }

TMP="$(mktemp -d -t sd-seed-blob-XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/seed.md" <<'EOF'
---
type: interview-seed
next_phase: spec-distill:interview
audit_file: seed.audit.md
---

SEED_BODY_MARKER 로그인이 가끔 실패한다.
EOF
cat > "$TMP/seed.audit.md" <<'EOF'
---
type: interview-seed-audit
payload: seed.md
---

# Topic — Interview Seed Audit

## 1. 원문

RAW_TEXT_MARKER 사용자가 실제로 한 말.

## 2. 질문 전체

- 쏟아낸 것: 없음
EOF
cat > "$TMP/CLAUDE.md" <<'EOF'
# CLAUDE.md
CLAUDE_MD_MARKER 테스트용 규칙.
EOF

# --- 정상 3-파일 입력 ---------------------------------------------------------
out="$(python3 "$SCRIPT" "$TMP/seed.md" "$TMP/seed.audit.md" "$TMP/CLAUDE.md" 2>"$TMP/err.txt")"; rc=$?
[[ "$rc" == "0" ]] && ok "정상 3-파일 입력 → exit 0" || no "정상 입력이 exit $rc"

grep -qF "SEED_BODY_MARKER" <<<"$out" && ok "seed 본문 실림" || no "seed 본문 소실"
grep -qF "RAW_TEXT_MARKER" <<<"$out" && ok "audit §1 원문 실림" || no "원문 소실"
grep -qF "CLAUDE_MD_MARKER" <<<"$out" && ok "CLAUDE.md 본문 실림" || no "CLAUDE.md 소실"

# seed 쪽 frontmatter는 벗겨낸다(check_seed.py의 body_of()와 같은 계약) — 하니스용
# 메타(next_phase 등)가 codex 프롬프트로 새면 안 된다.
grep -qF "next_phase: spec-distill:interview" <<<"$out" \
  && no "seed frontmatter가 새어 있다 — 하니스용 메타가 codex에 갔다" \
  || ok "seed frontmatter 부재(본문만 실림)"

# 세 섹션이 초안 → 원문 → CLAUDE.md 순서로 조립된다.
i1="$(grep -n "SEED_BODY_MARKER" <<<"$out" | head -1 | cut -d: -f1)"
i2="$(grep -n "RAW_TEXT_MARKER" <<<"$out" | head -1 | cut -d: -f1)"
i3="$(grep -n "CLAUDE_MD_MARKER" <<<"$out" | head -1 | cut -d: -f1)"
if [[ -n "${i1:-}" && -n "${i2:-}" && -n "${i3:-}" && "$i1" -lt "$i2" && "$i2" -lt "$i3" ]]; then
  ok "세 섹션이 초안 → 원문 → CLAUDE.md 순서로 조립된다"
else
  no "세 섹션 순서가 어긋났다(i1=${i1:-?} i2=${i2:-?} i3=${i3:-?})"
fi

# --- 재료 부재 셋 각각: exit 2 + 어느 인자인지 stderr에 명시 -------------------
python3 "$SCRIPT" "$TMP/does-not-exist.md" "$TMP/seed.audit.md" "$TMP/CLAUDE.md" >/dev/null 2>"$TMP/err_seed.txt"
rc_seed=$?
[[ "$rc_seed" == "2" ]] && ok "seed_file 부재 → exit 2" || no "seed_file 부재가 exit $rc_seed"
grep -q "seed_file" "$TMP/err_seed.txt" && ok "seed_file 부재 stderr에 원인 명시" || no "seed_file 부재 stderr 불명확"

python3 "$SCRIPT" "$TMP/seed.md" "$TMP/does-not-exist.md" "$TMP/CLAUDE.md" >/dev/null 2>"$TMP/err_audit.txt"
rc_audit=$?
[[ "$rc_audit" == "2" ]] && ok "audit_file 부재 → exit 2" || no "audit_file 부재가 exit $rc_audit"
grep -q "audit_file" "$TMP/err_audit.txt" && ok "audit_file 부재 stderr에 원인 명시" || no "audit_file 부재 stderr 불명확"

python3 "$SCRIPT" "$TMP/seed.md" "$TMP/seed.audit.md" "$TMP/does-not-exist.md" >/dev/null 2>"$TMP/err_claude.txt"
rc_claude=$?
[[ "$rc_claude" == "2" ]] && ok "claude_md_file 부재 → exit 2" || no "claude_md_file 부재가 exit $rc_claude"
grep -q "claude_md_file" "$TMP/err_claude.txt" && ok "claude_md_file 부재 stderr에 원인 명시" || no "claude_md_file 부재 stderr 불명확"

# --- audit에 §1 원문 절이 없는 경우: 조용히 넘어가지 않는다(stderr 경고), 그래도
# exit 0(다른 두 재료는 여전히 유효하므로 완전 실패로 죽이지 않는다) ------------
cat > "$TMP/audit_no_raw.md" <<'EOF'
---
type: interview-seed-audit
---

# Topic

## 2. 질문 전체

없음
EOF
out2="$(python3 "$SCRIPT" "$TMP/seed.md" "$TMP/audit_no_raw.md" "$TMP/CLAUDE.md" 2>"$TMP/err2.txt")"; rc2=$?
[[ "$rc2" == "0" ]] && ok "§1 원문 없는 audit도 exit 0(다른 두 재료는 유효)" || no "§1 원문 없는 audit이 exit $rc2"
grep -q "원문" "$TMP/err2.txt" && ok "§1 원문 부재가 stderr에 loud하게 남는다(조용한 결측 아님)" \
                                || no "§1 원문 부재를 조용히 삼켰다"
grep -qF "SEED_BODY_MARKER" <<<"$out2" && ok "§1 원문 없어도 나머지 두 재료는 조립된다" \
                                        || no "§1 원문 부재가 나머지 조립까지 깨뜨렸다"

# --- mutation: frontmatter strip을 무력화하면 위 negative가 다시 통과해야 한다 ---
mutres="$(python3 - "$SCRIPT" "$TMP/mut.py" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
t = open(src, encoding="utf-8").read()
NEEDLE = 'return FRONTMATTER_RE.sub("", text, count=1)'
REPL = 'return text  # mutated: no-op'
t2 = t.replace(NEEDLE, REPL, 1)
open(dst, "w", encoding="utf-8").write(t2)
print("MUTATED" if t2 != t else "UNCHANGED")
PY
)"
if [[ "$mutres" == "MUTATED" ]]; then
  outmut="$(python3 "$TMP/mut.py" "$TMP/seed.md" "$TMP/seed.audit.md" "$TMP/CLAUDE.md" 2>/dev/null)"
  grep -qF "next_phase: spec-distill:interview" <<<"$outmut" \
    && ok "mutation: frontmatter strip 제거 → frontmatter 재노출(락에 이빨 있음)" \
    || no "mutation: strip을 없애도 frontmatter가 안 샌다 — 이 락은 다른 이유로 통과한다"
else
  no "mutation: strip 호출을 못 찾았다(${mutres}) — 락이 vacuous하다"
fi

finish
