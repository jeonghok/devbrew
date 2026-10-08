#!/usr/bin/env bash
# guards: plugins/** shared/** CLAUDE.md README.md docs/philosophy/** docs/plugin-authoring.md
#
# 호출 표면 정합 락의 집행과 이빨.
#  1부 합성 리포 — 양성 대조 GREEN · 축 A~I 변이마다 RED + 그 축의 태그 · 음성 대조 GREEN
#  2부 이 리포 — 무변이 GREEN
#  3부 이 리포의 `git clone --no-local` 사본에 실제 변이 (Task 11)
#  4부 `claude plugin validate --strict` manifest 단계 (Task 11)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOCK="$ROOT/shared/entry/check_invocation_surface.py"
if [ "${1:-}" = "--emit-scanned" ]; then
  python3 "$LOCK" --root "$ROOT" --emit-scanned
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
TMP="$(mktemp -d "${TMPDIR:-/tmp}/invsurf.XXXXXX")" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
trap 'rm -rf "$TMP"' EXIT

mk_repo() {   # mk_repo <dir> — 축 A~I 를 모두 만족하는 최소 리포
  python3 - "$1" "$LOCK" <<'PY'
import os, subprocess, sys
d, lock = sys.argv[1], sys.argv[2]
def w(rel, text):
    p = os.path.join(d, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as fh:
        fh.write(text)
def head(plugin, skill):
    return subprocess.run([sys.executable, lock, "--print-head", plugin, skill],
                          capture_output=True, text=True, check=True).stdout
ENTRY = [("spec-distill", "request-framing", False), ("spec-distill", "spec-interview", False),
         ("spec-distill", "spec-review", False), ("plugin-audit", "plugin-audit", True),
         ("project-init", "project-init", True)]
for p, s, user_only in ENTRY:
    fm = "---\nname: %s\ndescription: x\ncost_class: low\n%s" % (s, "disable-model-invocation: true\n" if user_only else "")
    rows = ("\n| `[devbrew-entry] ok …` | 간다 |\n| `[devbrew-entry] disabled …` | 멈춘다 |\n"
            "| `[devbrew-entry] error …` | 멈춘다 |\n| `[shell command execution disabled by policy]` | 멈춘다 |\n")
    w("plugins/%s/skills/%s/SKILL.md" % (p, s), fm + head(p, s) + rows + "\n## 본문\n\n/%s:%s 로 부른다.\n" % (p, s))
    w("plugins/%s/scripts/entry_preflight.py" % p, "# stub\n")
w("plugins/spec-distill/skills/reviewing-brief/SKILL.md",
  "---\nname: reviewing-brief\ndescription: x\ncost_class: medium\nuser-invocable: false\n---\n\nbody\n")
w("plugins/quality-gates/commands/qg.md", "---\ndescription: qg\n---\n")
w("plugins/spec-distill/README.md", "# spec-distill\n\n`/spec-interview` 를 친다.\n")
w("README.md", "# r\n")
subprocess.run(["git", "init", "-q", d], check=True)
PY
}
run_lock() { python3 "$LOCK" --root "$1" 2>&1; }
expect_green() {   # expect_green <dir> <msg>
  local out rc
  out="$(run_lock "$1")"; rc=$?
  if [ "$rc" = "0" ]; then ok "$2"; else no "$2 (rc=$rc)"; printf '%s\n' "$out" | head -15; fi
}
expect_red() {     # expect_red <dir> <axis> <msg> <reason-substring>
  local out rc
  out="$(run_lock "$1")"; rc=$?
  if [ "$rc" = "1" ] && printf '%s\n' "$out" | grep "^RED $2 " | grep -qF -- "$4"; then ok "$3"
  else no "$3 (rc=$rc, 축 $2 태그 또는 사유 '$4' 없음)"; printf '%s\n' "$out" | head -10; fi
}
variant() {        # variant <name> — 좋은 리포의 사본
  rm -rf "$TMP/v-$1"; cp -R "$TMP/good" "$TMP/v-$1"
}
edit() {           # edit <file> <old> <new> — 첫 일치 하나를 바꾼다. 못 심으면 계측기 고장으로 센다
  python3 - "$1" "$2" "$3" <<'PY'
import sys
p, old, new = sys.argv[1:4]
t = open(p, encoding="utf-8").read()
if old not in t:
    sys.exit(1)
open(p, "w", encoding="utf-8").write(t.replace(old, new, 1))
PY
  [ "$?" = "0" ] || no "변이 심기 실패: $1 에 '$2' 가 없다"
}
put() { mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" >> "$1"; }

# ── 1부: 합성 리포 ──────────────────────────────────────────────
mk_repo "$TMP/good"
SR="plugins/spec-distill/skills/spec-review/SKILL.md"
PA="plugins/plugin-audit/skills/plugin-audit/SKILL.md"
out="$(run_lock "$TMP/good")"; rc=$?
if [ "$rc" != "0" ]; then
  no "양성 대조: 좋은 리포가 GREEN 이 아니다 (rc=$rc) — 아래 변이 RED 는 증거가 아니다"
  printf '%s\n' "$out" | head -20
  finish; exit 1
fi
ok "양성 대조: 좋은 리포 GREEN"

variant a1; edit "$TMP/v-a1/$SR" "name: spec-review" "name: spec-reviewer"; expect_red "$TMP/v-a1" A "A 반전: name ≠ 디렉토리" "이 디렉토리"
variant a2; mkdir -p "$TMP/v-a2/plugins/spec-distill/skills/reviewing-docs"
cp "$TMP/v-a2/$SR" "$TMP/v-a2/plugins/spec-distill/skills/reviewing-docs/SKILL.md"
edit "$TMP/v-a2/plugins/spec-distill/skills/reviewing-docs/SKILL.md" "name: spec-review" "name: reviewing-docs"
expect_red "$TMP/v-a2" A "A 추가: 동명사 진입 skill" "동명사"
variant b1; edit "$TMP/v-b1/plugins/spec-distill/skills/reviewing-brief/SKILL.md" "name: reviewing-brief" "name: brief-review"
expect_red "$TMP/v-b1" B "B 반전: 내부 skill 이 동명사가 아니다" "user-invocable: false"
BANG_SR="$(python3 "$LOCK" --print-head spec-distill spec-review | sed -n '5p')"
variant c1; edit "$TMP/v-c1/$SR" "$BANG_SR" ""; expect_red "$TMP/v-c1" C "C 삭제: 사전 검사 줄 없음" "정확히 하나"
variant c2; edit "$TMP/v-c2/$SR" "## 진입 단계" "$BANG_SR

## 진입 단계"; expect_red "$TMP/v-c2" C "C 추가: 사전 검사 줄 둘" "정확히 하나"
variant c3; edit "$TMP/v-c3/$SR" "spec-distill spec-review\`" "spec-distill spec-interview\`"; expect_red "$TMP/v-c3" C "C 표기: 인자 바꿔치기" "기대 모양"
variant c4; edit "$TMP/v-c4/$SR" "allowed-tools:
" "allowed-tools:
  - Read
"; expect_red "$TMP/v-c4" C "C 추가: allowed-tools 에 다른 도구" "allowed-tools"
variant c5; edit "$TMP/v-c5/$SR" "[shell command execution disabled by policy]" "정책"; expect_red "$TMP/v-c5" C "C 삭제: 정책 판독 행" "감시줄 판독 행"
variant c6; edit "$TMP/v-c6/$SR" "## 진입 단계" "## 진입"; expect_red "$TMP/v-c6" C "C 삭제: 진입 단계 절" "절이 없다"
variant c7; edit "$TMP/v-c7/$SR" "## 본문" "## 본문

위 \`!\` 줄이 남긴 자리"; expect_red "$TMP/v-c7" C "C 추가: 산문의 느낌표-백틱" "정확히 하나"
variant d1; put "$TMP/v-d1/plugins/spec-distill/skills/spec-review/references/x.md" '!`echo $ARGUMENTS`'
expect_red "$TMP/v-d1" D "D 추가: 사전 검사 줄에 \$ARGUMENTS" "사용자 인자"
variant d2; put "$TMP/v-d2/plugins/spec-distill/references/y.md" '```!
echo ${ARGUMENTS}
```'
expect_red "$TMP/v-d2" D "D 표기: \`\`\`! 블록의 \${ARGUMENTS}" "사용자 인자"
variant d3; put "$TMP/v-d3/plugins/spec-distill/skills/spec-review/references/z.md" 'x !`echo $1`'
expect_red "$TMP/v-d3" D "D 표기: 공백 뒤 사전 검사 줄의 \$1" "사용자 인자"
variant e1; edit "$TMP/v-e1/$SR" "cost_class: low" "cost_class: low
bogus_key: 1"; expect_red "$TMP/v-e1" E "E 추가: 미지 키" "공식 키"
variant f1; edit "$TMP/v-f1/$SR" "cost_class: low" "cost_class: low
disable-model-invocation: true"; expect_red "$TMP/v-f1" F "F 추가: spec-review 를 사용자 전용으로" "둘에만"
variant f2; edit "$TMP/v-f2/$PA" "disable-model-invocation: true
" ""; expect_red "$TMP/v-f2" F "F 반전: plugin-audit 에서 제거" "disable-model-invocation: true 가 없다"
variant g1; put "$TMP/v-g1/plugins/spec-distill/scripts/hint.py" "print('run /spec-review now')"; expect_red "$TMP/v-g1" G "G 추가: bare 진입 이름" "bare /"
variant g2; put "$TMP/v-g2/plugins/spec-distill/skills/spec-review/references/h.md" '`/spec-distill:nonexistent` 로'; expect_red "$TMP/v-g2" G "G 표기: 풀리지 않는 완전명" "풀리지 않는다"
variant g3; put "$TMP/v-g3/plugins/project-init/templates/t.md" '`/project-init` step'; expect_red "$TMP/v-g3" G "G 추가: 템플릿의 bare 이름" "bare /"
variant h1; put "$TMP/v-h1/plugins/spec-distill/commands/x.md" "---"; expect_red "$TMP/v-h1" H "H 추가: qg 밖 commands/" "commands/ 층"
variant i1; put "$TMP/v-i1/plugins/spec-distill/README.md" "conducting-interview 를 부른다"; expect_red "$TMP/v-i1" I "I 추가: 옛 skill 이름" "옛 이름"
variant i2; put "$TMP/v-i2/plugins/spec-distill/README.md" '`/interview@x`'; expect_red "$TMP/v-i2" I "I 표기: 옛 호출 토큰" "옛 호출 토큰"
variant i3; rm -rf "$TMP/v-i3/plugins/spec-distill/skills/spec-review"; expect_red "$TMP/v-i3" I "I 삭제: 새 skill 디렉토리(양성 짝)" "양성 짝"

variant h2; put "$TMP/v-h2/plugins/spec-distill/commands/sub/x.md" "---"; expect_red "$TMP/v-h2" H "H 깊이: 중첩 commands/ 경로" "commands/ 층"
variant g4; put "$TMP/v-g4/plugins/spec-distill/skills/spec-review/references/t.md" '`/spec-distil:spec-review` 로'; expect_red "$TMP/v-g4" G "G 오타: 없는 플러그인 완전명" "풀리지 않는다"
variant a3; mkdir -p "$TMP/v-a3/plugins/spec-distill/skills/review"
cp "$TMP/v-a3/$SR" "$TMP/v-a3/plugins/spec-distill/skills/review/SKILL.md"
edit "$TMP/v-a3/plugins/spec-distill/skills/review/SKILL.md" "name: spec-review" "name: review"
expect_red "$TMP/v-a3" A "A 추가: 한 단어 진입 skill 이름" "두 단어"
variant c8; edit "$TMP/v-c8/$SR" "$BANG_SR" ""
edit "$TMP/v-c8/$SR" "## 진입 단계" "## 진입 단계

$BANG_SR"
expect_red "$TMP/v-c8" C "C 순서: 사전 검사 줄이 진입 단계 아래" "위에 있지 않다"
variant c9; rm -f "$TMP/v-c9/plugins/plugin-audit/scripts/entry_preflight.py"; expect_red "$TMP/v-c9" C "C 삭제: 사전 검사 스크립트" "스크립트"
variant c10; edit "$TMP/v-c10/$SR" "$BANG_SR" "foo $BANG_SR"; expect_red "$TMP/v-c10" C "C 표기: 사전 검사 줄 앞 접두" "기대 모양"
variant c11; edit "$TMP/v-c11/$SR" "## 진입 단계" "산문 한 줄

## 진입 단계"; expect_red "$TMP/v-c11" C "C 추가: 사전 검사 줄과 절 사이 산문" "사이에"
variant g5; put "$TMP/v-g5/plugins/spec-distill/scripts/q.py" "# /quality-gates:qg"
expect_green "$TMP/v-g5" "G 음성 대조: /quality-gates:qg 는 commands/qg.md 로 풀린다"

# qg 보고 모드와 그 수명
variant q1; put "$TMP/v-q1/plugins/quality-gates/README.md" "framing-requests"
expect_green "$TMP/v-q1" "qg 보고 모드: qg 안 옛 이름은 RED 가 아니다"
rep="$(python3 "$LOCK" --root "$TMP/v-q1" --report)"
assert_contains "$rep" "plugins/quality-gates/README.md" "qg 보고 모드: --report 표에 행으로 실린다"
rm -rf "$TMP/v-q1/plugins/quality-gates/commands"
expect_red "$TMP/v-q1" I "qg 수명: commands/ 가 사라지면 같은 위반이 RED" "옛 이름"

# 음성 대조 — 경로 조각 · fixture · CHANGELOG · 락 자신 · README 의 짧은 이름은 GREEN
variant n1
put "$TMP/v-n1/plugins/spec-distill/scripts/n.py" "# docs/superpowers/interview/x.md · plugins/plugin-audit/README.md · skills/spec-review/SKILL.md"
put "$TMP/v-n1/plugins/spec-distill/tests/fixtures/f.md" "source: spec-distill conducting-interview v0.23.0"
put "$TMP/v-n1/plugins/spec-distill/CHANGELOG.md" '`/interview` 제거'
put "$TMP/v-n1/shared/entry/check_invocation_surface.py" "reviewing-spec"
expect_green "$TMP/v-n1" "음성 대조: 경로 조각 · fixture · CHANGELOG · 락 자신 · README 짧은 이름"

# ── 2부: 이 리포 ────────────────────────────────────────────────
out="$(run_lock "$ROOT")"; rc=$?
assert_eq "$rc" "0" "이 리포: 표면 정합 GREEN"
[ "$rc" = "0" ] || printf '%s\n' "$out" | head -40

finish
