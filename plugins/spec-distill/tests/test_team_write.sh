#!/usr/bin/env bash
# team 형식 생성기 끝에서 끝 — 원자료 사본(`roadmap_write.py original`) · team 나무 검사(`team_layout.py check`) (R1 AC3–AC5).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_team_write.sh
set -u
export PYTHONDONTWRITEBYTECODE=1 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SD="$ROOT/plugins/spec-distill"
S="$SD/scripts"
RW="$S/roadmap_write.py"
RS="$S/roadmap_status.py"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
W="$T/repo"
g() { git -C "$W" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false -c init.defaultBranch=main "$@"; }
tree_of() { (cd "$1" && find . -type f | LC_ALL=C sort); }
assert_file_has() {  # assert_file_has <파일> <고정 문자열> <라벨>
  if grep -qF -- "$2" "$1" 2>/dev/null; then ok "$3"; else no "$3 — 없음: $2"; fi
}
markers() { grep -c '^<!-- 출처: ' "$1"; }   # markers <original.md> — 구간 출처 줄 수
marker_heads() {  # marker_heads <original.md> — 출처 줄에서 커밋과 줄 범위를 떼고 경로 · 절 이름만 남긴다
  grep '^<!-- 출처: ' "$1" | sed 's/@[0-9a-f]*//; s/ · [0-9]*–[0-9]*행 · [0-9]*줄//'
}

# sections_match 의 몸 — original.md 를 이 테스트가 따로 읽어(구현의 파서를 쓰지 않는다) 구간마다 출처의 그 줄들과 견준다
cat > "$T/sections_match.py" <<'PY'
import re, subprocess, sys
path, repo = sys.argv[1], sys.argv[2]
MARK = re.compile(r"<!-- 출처: (.+)@([0-9a-f]{40}) · (원문|질문 전체|사용자 원문) · ([0-9]+)–([0-9]+)행 · ([0-9]+)줄(?: · .+)? -->")
data = open(path, "rb").read()
lines = [l + b"\n" for l in data.split(b"\n")]
lines[-1] = lines[-1][:-1]
if not lines[-1]:
    lines.pop()
i, seen = 0, 0
while i < len(lines):
    m = MARK.fullmatch(lines[i].decode("utf-8", "replace").rstrip("\n"))
    if not m:
        sys.exit(print("%d행이 출처 줄이 아니다: %r" % (i + 1, lines[i][:80])))
    src, commit, label, first, last, n = m.group(1), m.group(2), m.group(3), int(m.group(4)), int(m.group(5)), int(m.group(6))
    body = lines[i + 1:i + 1 + n]
    p = subprocess.run(["git", "-C", repo, "show", "%s:%s" % (commit, src)], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    want = [l + b"\n" for l in p.stdout.split(b"\n")]
    want[-1] = want[-1][:-1]
    want = want[first - 1:last]
    if p.returncode or last - first + 1 != n or len(body) != n or body != want:
        sys.exit(print("%d행 구간(%s · %s %d–%d행)이 출처와 바이트가 다르다" % (i + 1, src, label, first, last)))
    i, seen = i + 1 + n, seen + 1
print("ok" if seen else "구간이 없다")
PY
sections_match() { python3 "$T/sections_match.py" "${1:-$O}" "$W"; }   # sections_match [<original.md>] — ok 또는 첫 어긋남

# ── 픽스처: framing seed · audit, 인터뷰 brief · audit · 상태 파일 (이 파일만의 글) ─────────────
mkdir -p "$W/docs/iv"
cat > "$W/docs/iv/t-seed-interview.md" <<'MD'
---
type: interview-seed
next_phase: spec-distill:pm-interview
audit_file: t-seed-interview.audit.md
---

팀 폴더 하나에 역할 문서를 두고 과제마다 의도 파일을 먼저 쓰게 하고 싶다.
MD
cat > "$W/docs/iv/t-seed-interview.audit.md" <<'MD'
---
type: interview-seed-audit
seed: t-seed-interview.md
---

# 틀잡기 감사

## 1. 원문

> 팀 폴더를 하나 두고 역할마다 문서를 둔다.
## 목표 / ## 지시 원문
> 위 줄도 사용자가 붙여 넣은 글이다.

## 2. 질문 전체

- 질문 — 역할 이름을 무엇으로? 고른 답: devbrew 말로

## 3. 긴 초안

초안 단락 하나.
MD
cat > "$W/docs/iv/t-brief-interview.md" <<'MD'
---
type: interview-brief
user_sourced_items:
  - id: C1
    statement: "팀 폴더 하나"
  - id: D2
    statement: "역할 문서 넷"
---

# 팀 픽스처 brief

## 0. 한눈에

**결정 목록**

- OQ1 [열림] — 과제 폴더 이름 짓기

## 1. Goal · Non-goal

- Goal: 팀 폴더를 세운다.
- Non-goal: 배포 자동화.

## 2. 제약

- 🗣 confirmed **C1** — 팀 폴더 하나 ⟨S1⟩
- ☑ confirmed **D2** — 역할 문서 넷 ⟨S2⟩

## 3. Open Questions

- OQ1: 과제 폴더 이름 짓기

## 4. External Landscape

- 바깥 사례 하나 «ext-a» — [취함] [→ OQ1]

## 5. 기각 · Blind Spots

- 기각 — 폴더를 역할마다 따로 — verdict: kept — ST1 — 부착 1/1
- 위험 K1 — 숨은 가정: 팀 이름이 역할 이름과 겹친다 — 근거 약함
- 위험 — 사실 | 레포 사실 하나 — RC1 (s/t.py) [RC1 → OQ1]

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > 팀 폴더를 만들어 달라

## 7. Next Action

다음 걸음.
MD
cat > "$W/docs/iv/t-brief-interview.audit.md" <<'MD'
# 인터뷰 감사

## 6. 사용자 원문

- **S2** 🗣 발화 (round 1):
  > 둘째 말
- **S3** ☑ 선택 (round 2):
  > 셋째 말
MD
printf -- '---\ntype: interview-state\nseed: docs/iv/t-seed-interview.md\nphase: 1\n---\n' > "$W/docs/iv/t-brief-interview.state.md"
# 상태 파일의 seed 가 「없음」 인 짝(u) · 다른 framing audit · CRLF 로 커밋한 brief(v) · 끝 줄바꿈 없는 audit(w)
cp "$W/docs/iv/t-brief-interview.md" "$W/docs/iv/u-brief-interview.md"
cp "$W/docs/iv/t-brief-interview.audit.md" "$W/docs/iv/u-brief-interview.audit.md"
printf -- '---\ntype: interview-state\nseed: 없음\n---\n' > "$W/docs/iv/u-brief-interview.state.md"
cp "$W/docs/iv/t-seed-interview.audit.md" "$W/docs/iv/other-seed-interview.audit.md"
sed 's/^type: interview-seed-audit$/type: interview-brief/' "$W/docs/iv/t-seed-interview.audit.md" > "$W/docs/iv/typed-seed-interview.audit.md"   # 세 절은 있고 type 만 다르다
awk '{printf "%s\r\n", $0}' "$W/docs/iv/t-brief-interview.md" > "$W/docs/iv/v-brief-interview.md"
cp "$W/docs/iv/t-brief-interview.audit.md" "$W/docs/iv/v-brief-interview.audit.md"
cp "$W/docs/iv/u-brief-interview.state.md" "$W/docs/iv/v-brief-interview.state.md"
cp "$W/docs/iv/t-brief-interview.md" "$W/docs/iv/w-brief-interview.md"
printf -- '# 감사\n\n## 6. 사용자 원문\n\n- **S2** 🗣 발화 (round 1):\n  > 끝 줄바꿈이 없는 말' > "$W/docs/iv/w-brief-interview.audit.md"
cp "$W/docs/iv/u-brief-interview.state.md" "$W/docs/iv/w-brief-interview.state.md"

git init -q --bare -b main "$T/origin.git"
git init -q -b main "$W"
g remote add origin "$T/origin.git"
g add -- docs && g commit -qm fixtures && g push -q origin main && g fetch -q origin
g remote set-head origin main
RD="$(cd "$W" && python3 "$S/repo_defaults.py" get roadmaps_dir 2>/dev/null)"
[ -n "$RD" ] && ok "로드맵 폴더를 해결자에서 얻었다(${RD})" || no "로드맵 폴더를 해결자에서 얻지 못했다"

orig() { (cd "$W" && python3 "$RW" original --brief docs/iv/t-brief-interview.md --out "${RD}t1" "$@") > "$T/out.txt" 2>&1; echo $?; }
check() { (cd "$W" && python3 "$S/team_layout.py" check --roadmap "${RD}t1/roadmap.md" "$@") > "$T/chk.txt" 2>&1; echo $?; }
orig_b() {  # orig_b <brief 레포 상대> <팀 이름> [인자…] — 다른 brief · 다른 팀 폴더로 original 을 부르고 rc 를 echo 한다
  local b="$1" t="$2"; shift 2
  (cd "$W" && python3 "$RW" original --brief "$b" --out "${RD}${t}" "$@") > "$T/out.txt" 2>&1; echo $?
}
O="$W/${RD}t1/intent/original.md"

# ── original: 원자료 사본 (AC5) ──────────────────────────────────────────────
assert_eq "$(orig)" "0" "original: rc 0"
assert_eq "$(grep -c '^<!-- 출처: ' "$O")" "4" "original: 구간 넷(원문 · 질문 전체 · brief §6 · audit §6)"
assert_grep "$(head -n 1 "$O")" '^<!-- 출처: docs/iv/t-seed-interview\.audit\.md@[0-9a-f]{40} · 원문 · [0-9]+–[0-9]+행 · [0-9]+줄 -->$' "AC5: 첫 줄이 구간의 출처 줄이다(파일 머리가 따로 없다)"
assert_file_has "$O" "## 목표 / ## 지시 원문" "Review Focus 1: 원문 절 안의 제목 꼴 줄까지 옮겼다"
assert_eq "$(sections_match)" "ok" "AC5: 옮긴 구간이 출처와 바이트가 같다"
cp "$O" "$T/o1"; assert_eq "$(orig)" "0" "original 다시: rc 0"; cmp -s "$O" "$T/o1" && ok "다시 불러도 바이트가 같다" || no "다시 부르니 바뀌었다"
assert_eq "$(marker_heads "$O")" \
  "$(printf '%s\n' '<!-- 출처: docs/iv/t-seed-interview.audit.md · 원문 -->' '<!-- 출처: docs/iv/t-seed-interview.audit.md · 질문 전체 -->' \
     '<!-- 출처: docs/iv/t-brief-interview.md · 사용자 원문 -->' '<!-- 출처: docs/iv/t-brief-interview.audit.md · 사용자 원문 -->')" \
  "구간 순서: framing 원문 · framing 질문 전체 · brief · audit"
assert_eq "$(grep -c '^## 3\. 긴 초안' "$O")" "0" "질문 전체 구간은 긴 초안 절 앞에서 끝난다"
assert_file_has "$O" "## 2. 질문 전체" "질문 전체 구간은 그 절 머리부터다"
assert_eq "$(tree_of "$W/${RD}t1")" "./intent/original.md" "original 은 original.md 하나만 만든다"
assert_eq "$(g status --porcelain -- docs/iv)" "" "original 은 출처 파일을 건드리지 않는다"

# ── 커밋되지 않은 출처 (Review Focus 2) ─────────────────────────────────────────
printf -- '- **S4** 🗣 발화 (round 3):\n  > 넷째 말\n' >> "$W/docs/iv/t-brief-interview.audit.md"   # §6 끝에 닿게 픽스처를 짠다
assert_eq "$(orig)" "1" "커밋 안 된 출처: 옮기지 않는다"
assert_contains "$(cat "$T/out.txt")" "먼저 커밋" "커밋 안 된 출처: 할 일을 말한다"
cmp -s "$O" "$T/o1" && ok "커밋 안 된 출처: 파일 그대로" || no "커밋 안 된 출처인데 파일이 바뀌었다"
g add -- docs/iv && g commit -qm s4
assert_eq "$(orig)" "0" "커밋 뒤: rc 0"
head -c "$(wc -c < "$T/o1")" "$O" | cmp -s - "$T/o1" && ok "AC5: 새 구간을 붙여도 앞 바이트가 그대로다" || no "앞 줄이 바뀌었다"
assert_eq "$(grep -c '^<!-- 출처: ' "$O")" "5" "늘어난 꼬리만 새 구간 하나"
assert_eq "$(tail -n 3 "$O" | head -n 1 | sed 's/@[0-9a-f]*//')" "<!-- 출처: docs/iv/t-brief-interview.audit.md · 사용자 원문 · 9–10행 · 2줄 -->" "꼬리 구간은 audit 의 새 두 줄(9–10행)이다"
assert_eq "$(sections_match)" "ok" "AC5: 늘어난 꼬리 구간도 출처와 바이트가 같다"
cp "$O" "$T/o5"
mkdir -p "$W/docs/nc"
cp "$W/docs/iv/u-brief-interview.md" "$W/docs/nc/x-brief-interview.md"
cp "$W/docs/iv/u-brief-interview.audit.md" "$W/docs/nc/x-brief-interview.audit.md"
assert_eq "$(orig_b docs/nc/x-brief-interview.md t8)" "1" "추적되지 않는 출처: 옮기지 않는다"
assert_contains "$(cat "$T/out.txt")" "먼저 커밋" "추적되지 않는 출처: 할 일을 말한다"
[ ! -e "$W/${RD}t8" ] && ok "추적되지 않는 출처: 팀 폴더를 만들지 않았다" || no "추적되지 않는 출처인데 팀 폴더가 생겼다"

# ── framing audit 를 찾는 세 길 ────────────────────────────────────────────
# 상태 파일의 seed 가 「없음」 이고 --framing-audit 도 없으면 brief 쪽 구간만, 출처 줄 끝에 그 사실
assert_eq "$(orig_b docs/iv/u-brief-interview.md t2)" "0" "framing 없음: rc 0"
O2="$W/${RD}t2/intent/original.md"
assert_eq "$(markers "$O2")" "2" "framing 없음: brief · audit 구간 둘"
assert_eq "$(grep -c '^<!-- 출처: .* · 사용자 원문 · .* · framing audit 없음 -->$' "$O2")" "2" "framing 없음: brief 쪽 구간의 출처 줄 끝이 「framing audit 없음 -->」"
assert_eq "$(sections_match "$O2")" "ok" "framing 없음: 구간이 출처와 바이트가 같다"
# --framing-audit 로 주면 그 파일의 두 절이 실린다
assert_eq "$(orig_b docs/iv/u-brief-interview.md t3 --framing-audit docs/iv/other-seed-interview.audit.md)" "0" "--framing-audit: rc 0"
O3="$W/${RD}t3/intent/original.md"
assert_eq "$(marker_heads "$O3" | sed -n 1,2p)" \
  "$(printf '%s\n' '<!-- 출처: docs/iv/other-seed-interview.audit.md · 원문 -->' '<!-- 출처: docs/iv/other-seed-interview.audit.md · 질문 전체 -->')" "--framing-audit: 그 파일의 원문 · 질문 전체 절이 먼저 실린다"
assert_eq "$(markers "$O3")" "4" "--framing-audit: 구간 넷"
assert_eq "$(grep -c 'framing audit 없음' "$O3")" "0" "--framing-audit: 「framing audit 없음」 표지가 없다"
assert_eq "$(sections_match "$O3")" "ok" "--framing-audit: 구간이 출처와 바이트가 같다"
# 상태 파일이 가리키는 audit 과 --framing-audit 이 다르면 사용법 오류, 같으면 받는다
assert_eq "$(orig_b docs/iv/t-brief-interview.md t4 --framing-audit docs/iv/other-seed-interview.audit.md)" "2" "framing 둘이 다르다: rc 2"
assert_contains "$(cat "$T/out.txt")" "t-seed-interview.audit.md" "framing 둘이 다르다: 상태 파일이 가리키는 파일을 보인다"
[ ! -e "$W/${RD}t4" ] && ok "framing 둘이 다르다: 팀 폴더를 만들지 않았다" || no "framing 둘이 다른데 팀 폴더가 생겼다"
assert_eq "$(orig --framing-audit docs/iv/t-seed-interview.audit.md)" "0" "framing 둘이 같다: rc 0(양의 짝)"
# --framing-audit 이 type: interview-seed-audit 이 아니면 쓰지 않는다(세 절이 다 있어도)
assert_grep "$(cat "$W/docs/iv/typed-seed-interview.audit.md")" '^type: interview-brief$' "픽스처: type 만 다른 framing 꼴 파일"
assert_eq "$(orig_b docs/iv/u-brief-interview.md t5 --framing-audit docs/iv/typed-seed-interview.audit.md)" "1" "framing 의 type 이 다르다: rc 1"
assert_contains "$(cat "$T/out.txt")" "interview-seed-audit" "framing 의 type 이 다르다: 기대한 type 을 말한다"
[ ! -e "$W/${RD}t5" ] && ok "framing 의 type 이 다르다: 팀 폴더를 만들지 않았다" || no "framing 의 type 이 다른데 팀 폴더가 생겼다"

# ── 줄바꿈 꼴 (Review Focus 3) ─────────────────────────────────────────────
# CRLF 로 커밋한 brief — 구간 바이트에 \r\n 이 그대로 있다
assert_eq "$(orig_b docs/iv/v-brief-interview.md t6)" "0" "CRLF 출처: rc 0"
O6="$W/${RD}t6/intent/original.md"
assert_eq "$(sections_match "$O6")" "ok" "CRLF 출처: 구간이 출처와 바이트가 같다"
assert_eq "$(grep -c $'\r$' "$O6")" "$(awk '/^## 6\./{f=1} /^## 7\./{f=0} f' "$W/docs/iv/v-brief-interview.md" | grep -c $'\r$')" "CRLF 출처: brief §6 의 줄마다 \\r\\n 이 그대로다"
[ "$(grep -c $'\r$' "$O6")" -gt 0 ] && ok "CRLF 출처: \\r 이 남은 줄이 있다(양성 대조)" || no "CRLF 출처: \\r 이 사라졌다"
assert_eq "$(grep '^<!-- 출처: ' "$O6" | grep -c $'\r$')" "0" "CRLF 출처: 출처 줄 자체는 LF 다"
# 끝 줄바꿈 없는 출처 — 옮기지 않고 그 사실을 말한다
assert_eq "$(orig_b docs/iv/w-brief-interview.md t7)" "1" "끝 줄바꿈 없는 출처: rc 1"
assert_contains "$(cat "$T/out.txt")" "끝에 줄바꿈" "끝 줄바꿈 없는 출처: 그 사실을 말한다"
[ ! -e "$W/${RD}t7" ] && ok "끝 줄바꿈 없는 출처: 팀 폴더를 만들지 않았다" || no "끝 줄바꿈 없는 출처인데 팀 폴더가 생겼다"

cmp -s "$O" "$T/o5" && [ "$(markers "$O")" = "5" ] && ok "t1 은 다음 과제(create --layout team)가 쓸 상태다(구간 다섯)" || no "t1 의 original.md 가 바뀌었다"

finish
