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
            "| `[devbrew-entry] error …` | 멈춘다 |\n| `[shell command execution disabled by policy]` | 멈춘다 |\n"
            "| 감시줄 없음 · 그 밖 | 멈춘다 |\n")
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
variant c12; edit "$TMP/v-c12/$SR" "| 감시줄 없음 · 그 밖 | 멈춘다 |
" ""; expect_red "$TMP/v-c12" C "C 삭제: 감시줄 없음 판독 행(fail-closed)" "감시줄 판독 행"
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
variant i4; put "$TMP/v-i4/plugins/spec-distill/tests/x.sh" "# conducting""-interview 를 부른다"; expect_red "$TMP/v-i4" I "I 경계: fixtures 밖 tests 파일의 옛 이름은 RED (fixture 면제의 양성 짝)" "옛 이름"

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

# ── 3부: 이 리포의 사본에 실제 변이 ─────────────────────────────
CL="$TMP/clone"
CLONE_OK=0
if git clone -q --no-local "$ROOT" "$CL" 2>"$TMP/clone.err"; then
  CLONE_OK=1
else
  no "clone 실패 — 3부 실제 변이와 4부 실측을 건너뛴다: $(tail -1 "$TMP/clone.err")"
fi
if [ "$CLONE_OK" = "1" ]; then
if [ "$(git -C "$CL" rev-parse --is-shallow-repository)" != "false" ]; then no "사본이 얕다 — 변이 결과를 믿을 수 없다"; fi
expect_green "$CL" "실제 사본 양성 대조: HEAD GREEN"
real() {   # real <name> — 실제 사본의 변이용 복제
  rm -rf "$TMP/r-$1"; cp -R "$CL" "$TMP/r-$1"
}
RSR="plugins/spec-distill/skills/spec-review/SKILL.md"
RBANG="$(python3 "$LOCK" --print-head spec-distill spec-review | sed -n '5p')"
real c; edit "$TMP/r-c/$RSR" "$RBANG" "";                                    expect_red "$TMP/r-c" C "실제 C 삭제: spec-review 사전 검사 줄" "정확히 하나"
real d; edit "$TMP/r-d/$RSR" "spec-distill spec-review\`" "spec-distill spec-review \$ARGUMENTS\`"; expect_red "$TMP/r-d" D "실제 D 추가: 사전 검사 줄에 \$ARGUMENTS" "사용자 인자"
real f; edit "$TMP/r-f/plugins/project-init/skills/project-init/SKILL.md" "disable-model-invocation: true
" "";                                                                         expect_red "$TMP/r-f" F "실제 F 반전: project-init 사용자 전용 해제" "disable-model-invocation: true 가 없다"
real g; put "$TMP/r-g/plugins/spec-distill/skills/request-framing/SKILL.md" "다음은 /spec-interview 다"; expect_red "$TMP/r-g" G "실제 G 추가: bare 진입 이름" "bare /spec-interview"
real h; put "$TMP/r-h/plugins/project-init/commands/project-init.md" "---";  expect_red "$TMP/r-h" H "실제 H 추가: 명령 층 부활" "commands/ 층"
real i; put "$TMP/r-i/CLAUDE.md" "reviewing-spec";                           expect_red "$TMP/r-i" I "실제 I 추가: 옛 이름 재삽입" "옛 이름 'reviewing-spec'"
real n; put "$TMP/r-n/plugins/spec-distill/scripts/n.py" "# docs/superpowers/interview/x.md · plugins/plugin-audit/README.md"
expect_green "$TMP/r-n" "실제 음성 대조: 경로 조각은 GREEN"
fi

# ── 4부: manifest — claude plugin validate --strict ─────────────
# 면제는 하나다: hooks 명령의 따옴표 없는 ${CLAUDE_PLUGIN_ROOT} 경고(선재, 2026-10-09 실측).
# 그 면제는 qg 핸드오프 보고서 3부의 행이다.
# manifest_bad [stderr-file] — stdin 의 validate JSON 을 판정한다. 출력 없음 = 통과, 한 줄이라도 있으면 RED 사유.
# 실측 모양(CLI 2.1.294): 최상위 키는 {success, strict, target, manifest, contents} 정확히 다섯,
# success 는 errors · warnings 가 모두 없을 때만 true.
manifest_bad() {
  python3 -c '
import json, sys
raw = sys.stdin.read()
errf = sys.argv[1] if len(sys.argv) > 1 else ""
def stderr_tail():
    if not errf:
        return ""
    try:
        lines = [l for l in open(errf, encoding="utf-8", errors="replace").read().splitlines() if l.strip()]
    except OSError:
        return ""
    return (" — stderr: " + lines[-1]) if lines else ""
if not raw.strip():
    print("unusable: validate 출력이 비었다" + stderr_tail())
    sys.exit(0)
try:
    d = json.loads(raw)
except ValueError as exc:
    print("unusable: validate 출력이 JSON 이 아니다 (%s)%s" % (exc, stderr_tail()))
    sys.exit(0)
if not isinstance(d, dict):
    print("shape: 최상위가 객체가 아니다" + stderr_tail())
    sys.exit(0)
out = []
KNOWN = {"success", "strict", "target", "manifest", "contents"}
extra = sorted(set(d) - KNOWN)
if extra:
    out.append("shape: 모르는 최상위 키 %s — 스키마 표류" % extra)
m, c = d.get("manifest"), d.get("contents")
if not isinstance(m, dict):
    out.append("shape: manifest 가 객체가 아니다")
if not isinstance(c, list):
    out.append("shape: contents 가 배열이 아니다")
if not isinstance(d.get("success"), bool):
    out.append("shape: success 가 bool 이 아니다")
if d.get("strict") is not True:
    out.append("shape: strict 가 true 가 아니다")
items = ([m] if isinstance(m, dict) else []) + (list(c) if isinstance(c, list) else [])
EXEMPT = "Shell command uses ${CLAUDE_PLUGIN_ROOT} without quotes"
exempt = 0
for i, it in enumerate(items):
    if not isinstance(it, dict):
        out.append("shape: 항목 %d 가 객체가 아니다" % i)
        continue
    es, ws = it.get("errors"), it.get("warnings")
    if not isinstance(es, list) or not isinstance(ws, list):
        out.append("shape: 항목 %d (%s) 에 배열 errors · warnings 가 없다" % (i, it.get("file", "?")))
        continue
    for e in es:
        e = e if isinstance(e, dict) else {"message": repr(e)}
        out.append("error %s %s %s" % (it.get("file", "?"), e.get("path"), e.get("message")))
    for w in ws:
        w = w if isinstance(w, dict) else {"message": repr(w)}
        if str(w.get("path", "")).startswith("hooks.") and str(w.get("message", "")).startswith(EXEMPT):
            exempt += 1
            continue
        out.append("warning %s %s %s" % (it.get("file", "?"), w.get("path"), w.get("message")))
if d.get("success") is False and exempt == 0:
    out.append("success: false 인데 그것을 설명하는 면제 경고가 없다")
if out and any(o.startswith("shape:") for o in out):
    out[0] += stderr_tail()
print("\n".join(out))
' "$@" 2>&1
}

# 판정기의 이빨 — CLI 없이 합성 JSON 으로
MOK='{"file":"m/plugin.json","type":"plugin","errors":[],"warnings":[],"notes":[],"gatingHooks":[]}'
MHK_EX='{"file":"h/hooks.json","type":"hooks","errors":[],"warnings":[{"path":"hooks.SessionEnd","message":"Shell command uses ${CLAUDE_PLUGIN_ROOT} without quotes: /bin/sh x"}],"notes":[]}'
mb() { printf '%s' "$1" | manifest_bad; }
o_sf="$(mb '{"success":false}')"
assert_contains "$o_sf" "shape: manifest 가 객체가 아니다" "manifest_bad: {success:false} 만 — manifest 모양 사유"
assert_contains "$o_sf" "shape: contents 가 배열이 아니다" "manifest_bad: {success:false} 만 — contents 모양 사유"
assert_contains "$o_sf" "shape: strict 가 true 가 아니다" "manifest_bad: {success:false} 만 — strict 사유"
assert_not_contains "$o_sf" "Traceback" "manifest_bad: {success:false} 만 — 판정기가 죽지 않는다"
o_f="$(mb '{"success":false,"strict":true,"target":"t","manifest":'"$MOK"',"contents":[{"file":"h/hooks.json","type":"hooks","errors":[],"warnings":[],"notes":[]}]}')"
assert_eq "$o_f" "success: false 인데 그것을 설명하는 면제 경고가 없다" "manifest_bad: 모양은 온전하고 목록이 빈 success:false 는 미설명 실패로 RED"
assert_not_contains "$o_f" "Traceback" "manifest_bad: 미설명 실패 사례 — 판정기가 죽지 않는다"
assert_eq "$(mb '{"success":true,"strict":false,"target":"t","manifest":'"$MOK"',"contents":[]}')" "shape: strict 가 true 가 아니다" "manifest_bad: strict:false 는 RED"
assert_grep "$(mb '{"success":true,"strict":true,"target":"t","manifest":'"$MOK"',"contents":["x"]}')" '^shape: 항목 1 가 객체가 아니다$' "manifest_bad: 객체가 아닌 contents 항목은 RED"
assert_grep "$(mb '{"success":false,"strict":true,"target":"t","manifest":{"file":"m","type":"plugin","errors":[{"path":"version","message":"bad"}],"warnings":[],"notes":[],"gatingHooks":[]},"contents":[]}')" '^error ' "manifest_bad: error 항목은 RED"
assert_grep "$(mb '{"success":false,"strict":true,"target":"t","manifest":'"$MOK"',"contents":[{"file":"h/hooks.json","type":"hooks","errors":[],"warnings":[{"path":"hooks","message":"hooks.PostToolUse.0.hooks.0: Invalid command hook"}]}]}')" '^warning ' "manifest_bad: 면제 밖 hooks 경고는 RED"
# 면제는 두 조건의 «둘 다» 다 — 경로 조건만 · 메시지 조건만 맞는 경고는 각각 RED 여야 한다.
assert_grep "$(mb '{"success":false,"strict":true,"target":"t","manifest":'"$MOK"',"contents":[{"file":"h/hooks.json","type":"hooks","errors":[],"warnings":[{"path":"hooks.SessionEnd","message":"Hook timeout is not a number"}]}]}')" '^warning h/hooks.json hooks.SessionEnd ' "manifest_bad: hooks. 경로라도 면제 문구가 아닌 경고는 RED"
assert_grep "$(mb '{"success":false,"strict":true,"target":"t","manifest":'"$MOK"',"contents":[{"file":"s/SKILL.md","type":"skill","errors":[],"warnings":[{"path":"skills.x","message":"Shell command uses ${CLAUDE_PLUGIN_ROOT} without quotes: /bin/sh x"}]}]}')" '^warning s/SKILL.md skills.x ' "manifest_bad: 면제 문구라도 hooks. 밖 경로의 경고는 RED"
assert_grep "$(printf '' | manifest_bad)" '^unusable:' "manifest_bad: 빈 출력은 RED"
assert_grep "$(mb '{"success":true,"strict":true,"target":"t","manifest":'"$MOK"',"contents":[],"extra":1}')" '모르는 최상위 키' "manifest_bad: 모르는 최상위 키는 RED"
assert_eq "$(mb '{"success":false,"strict":true,"target":"t","manifest":'"$MOK"',"contents":['"$MHK_EX"']}')" "" "manifest_bad: 면제 경고만 있는 success:false 는 통과"
assert_eq "$(mb '{"success":true,"strict":true,"target":"t","manifest":'"$MOK"',"contents":[]}')" "" "manifest_bad: 깨끗한 success:true 는 통과"
printf 'boom: validator crashed\n' > "$TMP/fake.err"
assert_contains "$(printf 'not json' | manifest_bad "$TMP/fake.err")" "stderr: boom: validator crashed" "manifest_bad: 쓸 수 없는 JSON 이면 stderr 마지막 줄을 싣는다"

MANIFEST_SKIP=""
if ! command -v claude >/dev/null 2>&1; then
  MANIFEST_SKIP="⚠ SKIPPED manifest 실측 — claude CLI 가 PATH 에 없다. 이 단계는 재지 않았다."
elif [ "$CLONE_OK" != "1" ]; then
  MANIFEST_SKIP="⚠ SKIPPED manifest 실측 — 커밋 상태의 사본이 없다(clone 실패)."
fi
if [ -z "$MANIFEST_SKIP" ]; then
  for p in spec-distill plugin-audit project-init; do
    v="$(claude plugin validate --strict --json "$CL/plugins/$p" 2>"$TMP/validate-$p.err")"
    bad="$(printf '%s' "$v" | manifest_bad "$TMP/validate-$p.err")"
    assert_eq "$bad" "" "manifest: $p (커밋 상태) 가 validate --strict 를 통과한다(hooks 따옴표 경고 면제)"
  done
else
  note "  ${MANIFEST_SKIP}"
fi

finish; rc=$?
[ -z "$MANIFEST_SKIP" ] || printf '%s\n' "${MANIFEST_SKIP}"
exit "$rc"
