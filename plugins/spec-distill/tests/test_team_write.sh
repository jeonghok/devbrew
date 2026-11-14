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

# ── original: 출처 판독의 두 갈래 (Task 6 리뷰에서 넘어온 것) ──────────────────────
# audit §6 구간을 빼는 것은 audit 에 발화 번호가 하나 이상 있고 그것이 모두 brief §6 에 있을 때뿐이다
printf -- '# xa 브리프\n\n## 6. 사용자 원문\n\n- **S1** 🗣 최초 요청:\n  > 가 요청\n- **S2** 🗣 발화 (round 1):\n  > 나 발화\n\n## 7. Next Action\n\n없음.\n' > "$W/docs/iv/xa-brief-interview.md"
printf -- '# xa 감사\n\n## 6. 사용자 원문\n\n- **S2** 🗣 발화 (round 1):\n  > 나 발화\n' > "$W/docs/iv/xa-brief-interview.audit.md"
cp "$W/docs/iv/xa-brief-interview.md" "$W/docs/iv/xb-brief-interview.md"
printf -- '# xb 감사\n\n## 6. 사용자 원문\n\n- **S2** 🗣 발화 (round 1):\n  > 나 발화\n- **S3** ☑ 선택 (round 2):\n  > 다 선택\n' > "$W/docs/iv/xb-brief-interview.audit.md"
cp "$W/docs/iv/xa-brief-interview.md" "$W/docs/iv/xc-brief-interview.md"
printf -- '# xc 감사\n\n## 6. 사용자 원문\n\n번호 없이 남은 사용자 말 한 줄.\n' > "$W/docs/iv/xc-brief-interview.audit.md"
g add -- docs/iv && g commit -qm x-fixtures
assert_eq "$(orig_b docs/iv/xa-brief-interview.md xa)" "0" "audit 발화가 모두 brief §6 에 있다: rc 0"
assert_eq "$(marker_heads "$W/${RD}xa/intent/original.md")" "<!-- 출처: docs/iv/xa-brief-interview.md · 사용자 원문 · framing audit 없음 -->" "audit 발화가 모두 brief §6 에 있다: audit 구간을 싣지 않는다"
assert_eq "$(orig_b docs/iv/xb-brief-interview.md xb)" "0" "audit 에 brief 에 없는 발화가 있다: rc 0"
assert_eq "$(markers "$W/${RD}xb/intent/original.md")" "2" "audit 에 brief 에 없는 발화가 있다: audit 구간을 싣는다"
assert_eq "$(orig_b docs/iv/xc-brief-interview.md xc)" "0" "audit §6 에 글은 있고 발화 번호가 없다: rc 0"
assert_eq "$(markers "$W/${RD}xc/intent/original.md")" "2" "audit §6 에 글은 있고 발화 번호가 없다: audit 구간을 싣는다(빈 번호 집합은 「모두 brief 에 있다」 가 아니다)"
assert_file_has "$W/${RD}xc/intent/original.md" "번호 없이 남은 사용자 말 한 줄." "audit §6 의 번호 없는 글이 사본에 있다"
# 출처 커밋 찾기는 사용자 git 설정(log.showSignature)에 흔들리지 않는다 — 가짜 git 이 서명 줄을 끼운다
REALGIT="$(command -v git)"
mkdir -p "$T/fg1" "$T/fg2"
printf '#!/bin/sh\nL= N=\nfor a in "$@"; do [ "$a" = log ] && L=1; [ "$a" = --no-show-signature ] && N=1; done\n[ -n "$L" ] && [ -z "$N" ] && echo "gpg: Signature made (가짜 서명 줄)"\nexec "%s" "$@"\n' "$REALGIT" > "$T/fg1/git"
printf '#!/bin/sh\nfor a in "$@"; do [ "$a" = log ] && { echo "커밋-번호-아님"; exit 0; }; done\nexec "%s" "$@"\n' "$REALGIT" > "$T/fg2/git"
chmod +x "$T/fg1/git" "$T/fg2/git"
orig_path() {  # orig_path <가짜 git 폴더> <팀 이름> — 그 git 을 PATH 앞에 두고 original 을 부른다
  (cd "$W" && PATH="$1:$PATH" python3 "$RW" original --brief docs/iv/u-brief-interview.md --out "${RD}$2") > "$T/out.txt" 2>&1; echo $?
}
assert_eq "$(orig_path "$T/fg1" xs)" "0" "log.showSignature 꼴 출력: --no-show-signature 로 커밋을 읽는다(rc 0)"
assert_eq "$(markers "$W/${RD}xs/intent/original.md")" "2" "log.showSignature 꼴 출력: 구간 둘을 옮겼다"
assert_eq "$(orig_path "$T/fg2" xt)" "1" "git log 출력이 커밋 번호가 아니다: rc 1"
assert_contains "$(cat "$T/out.txt")" "커밋을 정하지 못했다" "git log 출력이 커밋 번호가 아니다: 커밋을 정하지 못했다고 말한다"
assert_not_contains "$(cat "$T/out.txt")" "먼저 커밋" "git log 출력이 커밋 번호가 아니다: 「먼저 커밋」 으로 말하지 않는다"
[ ! -e "$W/${RD}xt" ] && ok "git log 출력이 커밋 번호가 아니다: 팀 폴더를 만들지 않았다" || no "커밋을 정하지 못했는데 팀 폴더가 생겼다"
g push -q origin main   # 픽스처(s4 · x)를 origin 에 — 아래 새 레포 사본이 같은 출처를 받는다

# ── create --layout team: 한 거래로 팀 폴더 (AC3 · AC4 · AC5 · AC8 · AC18) ─────────
HEAD_T='| 번호 | 이름 | 종류 | 의도 | 범위 | 의존 | 브랜치 | 경로 예약 | 배정 번호 | 받는 것 | 넘기는 것 | 지시 원문 범위 |'
SEP_T='|---|---|---|---|---|---|---|---|---|---|---|---|'
TP1='| P1 | 이름 정하기 | 결정 | 과제 폴더 이름을 정한다 | 한다 이름 / 안 한다 구현 | 없음 | 없음 | 없음 | S2 · OQ1 | 없음 | 없음 | 없음 |'
TE1='| E1 | 팀 폴더 | 묶음 | 팀 폴더를 세운다 | 한다 폴더 / 안 한다 배포 | P1 | feature/t-e1 | docs/team/ | C1 · D2 · «ext-a» · S1 | 없음 | E2 에 폴더 | 2–4 |'
TE2='| E2 | 역할 문서 | 묶음 | 역할 문서를 깐다 | 한다 문서 / 안 한다 권한 | E1 | feature/t-e2 | 없음 | ST1 · K1 · RC1 · S3 · S4 | E1 의 폴더 | 없음 | 9–12 |'
ttable() {  # ttable <파일> <행들…> — team 표 파일
  local f="$1"; shift
  { printf '# 팀 분해 상태\n\n## 분해안\n\n%s\n%s\n' "$HEAD_T" "$SEP_T"; printf '%s\n' "$@"; } > "$f"
}
otable() {  # otable <파일> <team 행들…> — 같은 행에서 마지막 칸(지시 원문 범위)을 뗀 옛 표 파일
  local f="$1"; shift
  { printf '# 옛 분해 상태\n\n## 분해안\n\n%s\n%s\n' "${HEAD_T% 지시 원문 범위 |}" "${SEP_T%---|}"; for r; do printf '%s|\n' "${r%|*|}"; done; } > "$f"
}
record_of() { sed -n '/^## 생성 기록/,$p' "$1" | grep '^- ' > "$1.record"; }   # record_of <표 파일> — 생성 기록 줄만 <표>.record 로
cat > "$T/snap.py" <<'PY'
import hashlib, os, sys
top = sys.argv[1]
for d, dirs, files in os.walk(top):
    if d == top and ".git" in dirs:
        dirs.remove(".git")
    dirs.sort()
    rel = os.path.relpath(d, top)
    print("d", rel)
    for n in sorted(files + dirs):
        p = os.path.join(d, n)
        if os.path.islink(p):
            print("l", os.path.join(rel, n), os.readlink(p))
        elif n in files:
            print("f", os.path.join(rel, n), hashlib.sha256(open(p, "rb").read()).hexdigest())
PY
snap() { python3 "$T/snap.py" "$1"; }   # snap <폴더> — .git 밖의 폴더 · 파일(내용 해시) · 링크 전부
ttc() {  # ttc <레포> <표 파일> <--out> [인자…] — 그 레포에서 create --layout team, rc 를 echo 한다(뒤 인자가 --layout 을 덮을 수 있다)
  local w="$1" tb="$2" out="$3"; shift 3
  (cd "$w" && python3 "$RW" create --layout team --brief docs/iv/t-brief-interview.md --audit docs/iv/t-brief-interview.audit.md \
     --plan-table "$tb" --out "$out" --title "팀 픽스처" --date 2026-11-14 --approval "이대로 승인 (권장)" "$@") > "$T/out.txt" 2>&1; echo $?
}
ocreate() {  # ocreate <표 파일> <--out> — 옛 형식 create(--layout 없음), rc 를 echo 한다
  (cd "$W" && python3 "$RW" create --brief docs/iv/t-brief-interview.md --audit docs/iv/t-brief-interview.audit.md \
     --plan-table "$1" --out "$2" --title "팀 픽스처" --date 2026-11-14 --approval "이대로 승인 (권장)") > "$T/out.txt" 2>&1; echo $?
}
fresh() {  # fresh <이름> — origin 째로 새 레포 사본 $T/<이름>(origin $T/<이름>.git)과 생성 기록 없는 제 표 $T/<이름>.md
  git clone -q --bare "$T/origin.git" "$T/$1.git" && git clone -q "$T/$1.git" "$T/$1" && ttable "$T/$1.md" "$TP1" "$TE1" "$TE2"
}
gx() { local w="$1"; shift; git -C "$w" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"; }
tcreate() { (cd "$W" && python3 "$RW" create --layout team --brief docs/iv/t-brief-interview.md --audit docs/iv/t-brief-interview.audit.md \
   --plan-table "$1" --out "$2" --title "팀 픽스처" --date 2026-11-14 --approval "이대로 승인 (권장)") > "$T/out.txt" 2>&1; echo $?; }

ttable "$T/state.md" "$TP1" "$TE1" "$TE2"
assert_eq "$(tcreate "$T/state.md" "${RD}t1")" "0" "AC3: create --layout team rc 0"
cp "$T/out.txt" "$T/out.create.txt"
assert_eq "$(tree_of "$W/${RD}t1")" "$(printf './RULES.md\n./intent/original.md\n./jobs/E1/INTENT.md\n./jobs/E1/results/.gitkeep\n./jobs/E1/sources.md\n./jobs/E2/INTENT.md\n./jobs/E2/results/.gitkeep\n./jobs/E2/sources.md\n./roadmap.md')" "AC3: §11 의 파일(결정 블록은 과제 폴더가 없다)"
assert_eq "$(sed -n 1,5p "$W/${RD}t1/roadmap.md")" "$(printf -- '---\ntype: roadmap\nlayout: team\nsource_brief: docs/iv/t-brief-interview.md\n---')" "AC3: 머리말 layout: team"
assert_file_has "$W/${RD}t1/roadmap.md" "- 묶음: jobs/E1/sources.md" "블록의 묶음 값이 번호 파일을 가리킨다"
assert_file_has "$W/${RD}t1/roadmap.md" "에픽마다 과제 폴더의 INTENT.md 를 넘긴다." "로드맵 머리 글이 team 문장이다"
assert_eq "$(grep -c '에픽마다 원본 brief' "$W/${RD}t1/roadmap.md")" "0" "로드맵 머리 글에 옛 문장이 남지 않았다"
for r in leader designer writer worker; do cmp -s "$W/${RD}${r}/CLAUDE.md" "$SD/templates/team/role-${r}.md" && ok "AC18: 역할 문서 ${r} 를 틀 그대로 깔았다" || no "AC18: 역할 문서 ${r}"; done
cmp -s "$W/${RD}HANDBOOK.md" "$SD/templates/team/HANDBOOK.md" && ok "AC18: HANDBOOK.md 를 깔았다" || no "AC18: HANDBOOK.md"
cmp -s "$W/${RD}t1/RULES.md" "$SD/templates/team/RULES.md" && ok "RULES.md 를 빈 틀 그대로 깔았다" || no "RULES.md 가 틀과 다르다"
[ ! -e "$W/REVIEW.md" ] && ok "생성기는 REVIEW.md 를 깔지 않는다" || no "REVIEW.md 를 깔았다"
cmp -s "$O" "$T/o5" && ok "있던 original.md 는 바이트 그대로다" || no "create 가 있던 original.md 를 바꿨다"
assert_eq "$(check)" "0" "AC3: 만든 나무가 구조 검사를 통과한다"
assert_file_has "$W/${RD}t1/jobs/E1/INTENT.md" "- 범위: intent/original.md 2–4행" "AC4: 지시 원문은 줄 범위를 적는다"
assert_eq "$(grep -c '둘째 말' "$W/${RD}t1/jobs/E1/INTENT.md" "$W/${RD}t1/jobs/E1/sources.md" | awk -F: '{s+=$2} END{print s}')" "0" "AC4: 원자료의 글을 다시 싣지 않는다"
assert_eq "$(grep -c '팀 폴더를 하나 두고' "$W/${RD}t1/jobs/E1/INTENT.md")" "0" "AC4: 범위 안의 원자료 글도 INTENT.md 에 싣지 않는다"
assert_contains "$(cat "$T/out.create.txt")" "E1 지시 원문 2–4행" "create 가 과제마다 그 범위의 글을 화면에 낸다"
assert_contains "$(cat "$T/out.create.txt")" "> 팀 폴더를 하나 두고 역할마다 문서를 둔다." "화면에 그 범위의 줄(original.md 4행)이 있다"
assert_contains "$(cat "$T/out.create.txt")" "E2 지시 원문 9–12행" "E2 의 범위도 화면에 낸다"
assert_file_has "$W/${RD}t1/jobs/E2/sources.md" "ids: [RC1, K1, ST1, S3, S4]" "sources.md 머리 ids 는 그 행의 번호다"
assert_eq "$(grep -c '사용자 원문' "$W/${RD}t1/jobs/E2/sources.md")" "0" "sources.md 는 사용자 원문 절을 싣지 않는다"
record_of "$T/state.md"
assert_eq "$(grep -c . "$T/state.md.record")" "5" "생성 기록: 로드맵 · INTENT.md 둘 · sources.md 둘"   # RULES · original · 역할 문서는 기록하지 않는다
assert_eq "$(grep -c 'RULES\|original\|CLAUDE\|HANDBOOK\|gitkeep' "$T/state.md.record")" "0" "생성 기록에 없을 때만 까는 파일은 없다"

# 한 거래 (AC3) — 실패하면 아무것도 남지 않는다
before="$(snap "$W")"
same_tree() { [ "$(snap "$W")" = "$before" ] && ok "$1: 나무 그대로(폴더 · 파일 내용 · 링크)" || no "$1: 나무가 바뀌었다"; }
ttable "$T/bad-un.md" "$TP1" "${TE1/C1 · /}" "$TE2"
assert_eq "$(tcreate "$T/bad-un.md" "${RD}t9")" "1" "배정 번호에서 C1 을 뺀 표(unassigned): rc 1"
assert_contains "$(cat "$T/out.txt")" "unassigned: C1" "unassigned: 검증 실패 사유에 C1"
same_tree "unassigned"
[ ! -e "$W/${RD}t9" ] && ok "unassigned: 새 팀 폴더를 남기지 않았다" || no "unassigned: 팀 폴더가 남았다"
ttable "$T/bad-far.md" "$TP1" "${TE1/2–4 |/9999–10000 |}" "$TE2"
assert_eq "$(tcreate "$T/bad-far.md" "${RD}t9")" "1" "AC4: 범위가 파일 밖(9999–10000): rc 1"
assert_contains "$(cat "$T/out.txt")" "9999–10000" "AC4: 범위가 파일 밖: 그 범위를 짚는다"
assert_contains "$(cat "$T/out.txt")" "검사 실패" "범위가 파일 밖: 거래 안의 team 나무 검사가 멈췄다"
same_tree "범위가 파일 밖"
for bad in "4–2" "0–3" "없음"; do
  ttable "$T/bad-r.md" "$TP1" "${TE1/2–4 |/${bad} |}" "$TE2"
  assert_eq "$(tcreate "$T/bad-r.md" "${RD}t9")" "1" "Review Focus 5: 묶음 행의 범위 「${bad}」: rc 1"
  assert_contains "$(cat "$T/out.txt")" "E1: 지시 원문 범위" "Review Focus 5: 범위 「${bad}」: 표의 그 행 · 그 칸을 짚는다"
  assert_not_contains "$(cat "$T/out.txt")" "검사 실패" "Review Focus 5: 범위 「${bad}」: 쓰기 전에 표를 읽을 때 멈춘다"
  same_tree "범위 「${bad}」"
done
ttable "$T/bad-br.md" "$TP1" "${TE1/| 묶음 |/| 브랜치 docs/b-design.md |}" "$TE2"
assert_eq "$(tcreate "$T/bad-br.md" "${RD}t9")" "1" "Review Focus 5: 브랜치 종류 행: rc 1"
assert_contains "$(cat "$T/out.txt")" "브랜치 블록" "브랜치 종류 행: team 형식에서 쓰지 않는다고 말한다"
assert_not_contains "$(cat "$T/out.txt")" "검증 실패" "브랜치 종류 행: 쓰기 전에 표를 읽을 때 멈춘다"
same_tree "브랜치 종류 행"
assert_eq "$(tcreate "$T/state.md" "${RD}worker")" "1" "AC8: --out 이 역할 이름: rc 1"
assert_contains "$(cat "$T/out.txt")" "역할 이름" "AC8: --out 이 역할 이름: 그 사유"
otable "$T/old.md" "$TP1" "$TE1" "$TE2"
assert_eq "$(ocreate "$T/old.md" "${RD}designer")" "1" "AC8: 옛 형식(--layout 없이)도 역할 이름을 거절한다"
assert_contains "$(cat "$T/out.txt")" "역할 이름" "AC8: 옛 형식: 그 사유"
same_tree "역할 이름"
assert_eq "$(tcreate "$T/state.md" docs/elsewhere/t9)" "1" "로드맵 폴더 밖(--out docs/elsewhere/t9): rc 1"
assert_contains "$(cat "$T/out.txt")" "로드맵 폴더" "로드맵 폴더 밖: 그 사유"
same_tree "로드맵 폴더 밖"
assert_eq "$(ttc "$W" "$T/state.md" "${RD}t9" --layout nope)" "2" "--layout nope: rc 2"
same_tree "--layout nope"
# 역할 문서가 아직 없는 새 레포 사본 — 거래가 실패하면 역할 폴더 · HANDBOOK.md · 새 빈 폴더까지 남지 않는다
fresh w1
b1="$(snap "$T/w1")"
assert_eq "$(ttc "$T/w1" "$T/bad-un.md" "${RD}t1")" "1" "새 사본 · 검증 실패: rc 1"
[ "$(snap "$T/w1")" = "$b1" ] && ok "새 사본 · 검증 실패: 역할 폴더 · HANDBOOK.md · original.md · 빈 폴더 없이 그대로" || no "새 사본 · 검증 실패: 나무가 바뀌었다"
assert_eq "$(ttc "$T/w1" "$T/bad-far.md" "${RD}t1")" "1" "새 사본 · team 나무 검사 실패: rc 1"
assert_contains "$(cat "$T/out.txt")" "검사 실패" "새 사본 · team 나무 검사 실패: 그 사유"
[ "$(snap "$T/w1")" = "$b1" ] && ok "새 사본 · team 나무 검사 실패: 그대로" || no "새 사본 · team 나무 검사 실패: 나무가 바뀌었다"
assert_eq "$(ttc "$T/w1" "$T/w1.md" "${RD}t1")" "0" "새 사본 · 같은 레포에서 좋은 표: rc 0(양의 짝)"
[ -f "$T/w1/${RD}leader/CLAUDE.md" ] && [ -f "$T/w1/${RD}t1/intent/original.md" ] && ok "새 사본 · 좋은 표: 역할 문서와 original.md 를 만들었다" || no "새 사본 · 좋은 표: 만들지 않았다"

# 있는 것은 건드리지 않는다 (AC18 · Review Focus 4)
fresh w2
mkdir -p "$T/w2/${RD}leader"
printf '# 사람이 고친 리더 문서\n' > "$T/w2/${RD}leader/CLAUDE.md"
printf '# 사람이 쓴 HANDBOOK\n- 규칙 하나\n' > "$T/w2/${RD}HANDBOOK.md"
cp "$T/w2/${RD}leader/CLAUDE.md" "$T/w2-leader"; cp "$T/w2/${RD}HANDBOOK.md" "$T/w2-hb"
assert_eq "$(ttc "$T/w2" "$T/w2.md" "${RD}t1")" "0" "반쯤 있는 자리: rc 0"
cmp -s "$T/w2/${RD}leader/CLAUDE.md" "$T/w2-leader" && ok "AC18: 있던 leader/CLAUDE.md 는 바이트 그대로" || no "AC18: 있던 leader/CLAUDE.md 를 바꿨다"
cmp -s "$T/w2/${RD}HANDBOOK.md" "$T/w2-hb" && ok "AC18: 있던 HANDBOOK.md 는 바이트 그대로" || no "AC18: 있던 HANDBOOK.md 를 바꿨다"
for r in designer writer worker; do cmp -s "$T/w2/${RD}${r}/CLAUDE.md" "$SD/templates/team/role-${r}.md" && ok "반쯤 있는 자리: 없던 ${r} 는 깔았다" || no "반쯤 있는 자리: ${r} 를 깔지 않았다"; done
fresh w3
mkdir -p "$T/w3-elsewhere" "$T/w3/${RD}"
ln -s "$T/w3-elsewhere" "$T/w3/${RD}designer"
b3="$(snap "$T/w3")"
assert_eq "$(ttc "$T/w3" "$T/w3.md" "${RD}t1")" "1" "역할 폴더가 심볼릭 링크: rc 1"
assert_contains "$(cat "$T/out.txt")" "링크" "역할 폴더가 심볼릭 링크: 링크라서 멈췄다고 말한다"
assert_eq "$(ls -A "$T/w3-elsewhere")" "" "역할 폴더가 심볼릭 링크: 링크 대상 폴더에 파일이 생기지 않는다"
[ "$(snap "$T/w3")" = "$b3" ] && ok "역할 폴더가 심볼릭 링크: 레포 나무도 그대로" || no "역할 폴더가 심볼릭 링크: 레포에 무엇이 남았다"
fresh w4
printf -- '---\nroadmaps_dir: .claude/roadmaps/\n---\n' > "$T/w4/.devbrew.md"
gx "$T/w4" add -- .devbrew.md && gx "$T/w4" commit -qm cfg && gx "$T/w4" push -q origin main
assert_eq "$(cd "$T/w4" && python3 "$S/repo_defaults.py" get roadmaps_dir 2>/dev/null)" ".claude/roadmaps/" "픽스처: origin 의 .devbrew.md 가 roadmaps_dir 을 .claude 아래로 둔다"
assert_eq "$(ttc "$T/w4" "$T/w4.md" .claude/roadmaps/t1)" "1" "roadmaps_dir 이 .claude 아래: rc 1"
assert_contains "$(cat "$T/out.txt")" ".claude" "roadmaps_dir 이 .claude 아래: 그 자리를 짚는다"
[ ! -e "$T/w4/.claude" ] && ok "roadmaps_dir 이 .claude 아래: .claude 아래에 아무것도 없다" || no "roadmaps_dir 이 .claude 아래인데 .claude 가 생겼다"
printf -- '- [손] 손으로 더한 규칙 · 출처: 사람 · 확인: 본다\n' >> "$W/${RD}t1/RULES.md"
cp "$W/${RD}t1/RULES.md" "$T/rules.hand"
assert_eq "$(tcreate "$T/state.md" "${RD}t1")" "0" "RULES.md 에 손으로 규칙을 더한 뒤 다시: rc 0"
cmp -s "$W/${RD}t1/RULES.md" "$T/rules.hand" && ok "AC18: 다시 돌려도 RULES.md 는 그대로다" || no "AC18: 다시 돌리니 RULES.md 가 바뀌었다"

# 다시 돌리기 (P13)
before="$(snap "$W")"
assert_eq "$(tcreate "$T/state.md" "${RD}t1")" "0" "P13: 같은 표로 다시: rc 0"
same_tree "P13: 같은 표로 다시"
I1="$W/${RD}t1/jobs/E1/INTENT.md"
cp "$I1" "$T/i1.orig"
printf -- '- 결정 · 2026-11-15 · 「가」\n' >> "$I1"
cp "$I1" "$T/i1.decided"
assert_eq "$(tcreate "$T/state.md" "${RD}t1")" "1" "P13: INTENT.md 에 결정 기록 줄이 있으면 다시 쓰지 않는다: rc 1"
assert_contains "$(cat "$T/out.txt")" "update" "P13: 결정 기록 줄: update 로 가라고 말한다"
cmp -s "$I1" "$T/i1.decided" && ok "P13: 결정 기록 줄: INTENT.md 그대로" || no "P13: 결정 기록 줄이 있는 INTENT.md 를 바꿨다"
cp "$T/i1.orig" "$I1"
before="$(snap "$W")"
ttable "$T/no-e2.md" "$TP1" "${TE1/S1 |/S1 · ST1 · K1 · RC1 · S3 · S4 |}"
sed -n '/^## 생성 기록/,$p' "$T/state.md" >> "$T/no-e2.md"
assert_eq "$(tcreate "$T/no-e2.md" "${RD}t1")" "1" "P13: 표에서 E2 를 빼고 다시: rc 1"
assert_contains "$(cat "$T/out.txt")" "jobs/E2" "P13: E2 를 뺐다: 남은 과제 파일을 짚는다"
same_tree "P13: E2 를 뺐다"

# 옛 형식은 그대로 (AC3 · AC8)
assert_eq "$(ocreate "$T/old.md" "${RD}old1")" "0" "AC3: 옛 형식 create(--layout 없이) rc 0"
assert_eq "$(tree_of "$W/${RD}old1")" "$(printf './E1.md\n./E2.md\n./roadmap.md')" "AC3: 옛 나무는 old1/{E1.md,E2.md,roadmap.md}"
[ ! -e "$W/${RD}old1/jobs" ] && [ ! -e "$W/${RD}old1/intent" ] && ok "AC3: 옛 나무에 과제 폴더 · 원자료 폴더가 없다" || no "AC3: 옛 나무에 team 폴더가 생겼다"
assert_eq "$(grep -c '^layout:' "$W/${RD}old1/roadmap.md")" "0" "AC3: 옛 로드맵 머리말에 layout 이 없다"
g add -- "${RD}old1" && g commit -qm old1 && g push -q origin main
st_json() {  # st_json — 기본 브랜치의 old1 상태 JSON 에서 blocks · format_errors · unknown_reasons · exit
  (cd "$W" && python3 "$RS" --roadmap "${RD}old1/roadmap.md" --json) | python3 -c 'import json, sys
r = json.load(sys.stdin)
print(json.dumps([r.get(k) for k in ("blocks", "format_errors", "unknown_reasons", "exit")], ensure_ascii=False, sort_keys=True))'
}
s_before="$(st_json)"
assert_grep "$s_before" '"id": "E2"' "픽스처: old1 상태 JSON 에 블록이 있다(빈 값끼리 견주지 않는다)"
g add -- "${RD}leader" "${RD}designer" "${RD}writer" "${RD}worker" "${RD}HANDBOOK.md" && g commit -qm roles && g push -q origin main
assert_eq "$(st_json)" "$s_before" "AC8: 역할 문서 넷 · HANDBOOK.md 를 push 한 뒤에도 old1 상태(blocks · format_errors · unknown_reasons · exit)가 같다"
awk '{print} /^줄 형식은/{print ""; print "- P1 · 결정 · 2026-11-14 · 「이름은 짧게」"}' "$W/${RD}old1/roadmap.md" > "$T/old1.rm" && cp "$T/old1.rm" "$W/${RD}old1/roadmap.md"
g add -- "${RD}old1" && g commit -qm old1-decided && g push -q origin main
[ "$(st_json)" != "$s_before" ] && ok "양성 대조: old1 자신의 변경(결정 기록 줄)은 같은 비교에서 잡힌다" || no "양성 대조: old1 을 바꿨는데 상태 JSON 이 같다 — 비교가 공허하다"

# 검사의 이빨 (AC4 · AC5) — 만든 나무를 커밋 · push 한 뒤
g add -- "${RD}t1" && g commit -qm t1 && g push -q origin main
assert_eq "$(check)" "0" "push 한 나무: 검사 rc 0(양의 짝)"
cp "$O" "$T/o.pushed"
awk 'NR==4{sub(/팀 폴더/, "팀 퐅더")}1' "$T/o.pushed" > "$O"
assert_eq "$(check)" "1" "AC5: original.md 본문의 글자 하나를 바꿨다: rc 1"
assert_contains "$(cat "$T/chk.txt")" "docs/iv/t-seed-interview.audit.md · 원문" "AC5: 어긋난 구간의 출처 경로와 절 이름을 낸다"
tail -n +2 "$T/o.pushed" > "$O"
assert_eq "$(check)" "1" "AC4: 첫 줄(표지)을 지웠다: rc 1"
assert_contains "$(cat "$T/chk.txt")" "앞 줄을 바꾸거나 지웠다" "AC4: 첫 줄을 지웠다: 덧붙이기만 받는다고 말한다"
{ cat "$T/o.pushed"; printf '구간이 아닌 줄\n'; } > "$O"
assert_eq "$(check)" "1" "끝에 구간이 아닌 줄을 붙였다: rc 1"
cp "$T/o.pushed" "$O"
assert_eq "$(check --base no-such-ref)" "3" "--base no-such-ref: rc 3"
cp "$I1" "$T/i1.pushed"
sed 's/2–4행/9–3행/' "$T/i1.pushed" > "$I1"
assert_eq "$(check)" "1" "AC4: 범위 줄이 9–3(뒤집힘): rc 1"
assert_contains "$(cat "$T/chk.txt")" "9–3" "AC4: 뒤집힌 범위를 짚는다"
grep -v '^- 범위: intent/' "$T/i1.pushed" > "$I1"
assert_eq "$(check)" "1" "AC4: 범위 줄을 지웠다: rc 1"
cp "$T/i1.pushed" "$I1"
printf '# 계획\n' > "$W/${RD}t1/jobs/E1/plan-2.md"
assert_eq "$(check)" "1" "P4: 브랜치 하나인 과제에 plan-2.md: rc 1"
assert_contains "$(cat "$T/chk.txt")" "plan-2.md" "P4: plan-2.md 를 짚는다"
# original 다시 — 로드맵이 있는 나무에서 쓴 뒤의 검사가 실패하면 되돌린다
printf -- '- **S5** 🗣 발화 (round 4):\n  > 다섯째 말\n' >> "$W/docs/iv/t-brief-interview.audit.md"
g add -- docs/iv && g commit -qm s5
assert_eq "$(orig)" "1" "original 다시 · 쓴 뒤의 검사 실패(plan-2.md): rc 1"
assert_contains "$(cat "$T/out.txt")" "검사 실패" "original 다시 · 검사 실패: 그 사유"
cmp -s "$O" "$T/o.pushed" && ok "original 다시 · 검사 실패: original.md 를 되돌렸다" || no "original 다시 · 검사 실패인데 original.md 가 바뀌었다"
rm -- "${W:?}/${RD:?}t1/jobs/E1/plan-2.md"
assert_eq "$(orig)" "0" "audit 에 발화를 더해 커밋한 뒤 original 다시: rc 0"
assert_eq "$(markers "$O")" "6" "덧붙인 구간 하나"
assert_eq "$(check)" "0" "AC4: 덧붙이기는 받는다(check rc 0)"
assert_eq "$(sed -n 2,4p "$O")" "$(printf '## 1. 원문\n\n> 팀 폴더를 하나 두고 역할마다 문서를 둔다.')" "AC4: E1 의 범위 2–4 가 가리키는 줄이 그대로다(framing 원문 절 머리 세 줄)"
head -c "$(wc -c < "$T/o.pushed")" "$O" | cmp -s - "$T/o.pushed" && ok "AC5: 덧붙인 뒤에도 push 한 사본의 바이트가 앞머리 그대로다" || no "AC5: 덧붙이다 앞 바이트가 바뀌었다"
cp "$I1" "$T/i1.keep"
sed 's/^팀 폴더를 세운다$/팀 폴더를 세웠다/' "$T/i1.keep" > "$I1"
assert_eq "$(grep -c '^팀 폴더를 세웠다$' "$I1")" "1" "픽스처: 목표 칸의 한 글자를 바꿨다"
rc="$( (cd "$W" && python3 "$S/team_layout.py" check --roadmap "${RD}t1/roadmap.md") 2> "$T/err.txt" > /dev/null; echo $?)"
assert_eq "$rc" "0" "AC28: 목표 칸이 블록과 다르다: rc 0(알림일 뿐)"
assert_contains "$(cat "$T/err.txt")" "목표" "AC28: 표준 오류에 「목표」 알림"
cp "$T/i1.keep" "$I1"

# 기본 브랜치 트리의 로드맵 찾기 (AC8)
cat > "$T/count.py" <<'PY'
import subprocess, sys
sys.path.insert(0, sys.argv[1])
import roadmap_model as M
repo, rd = sys.argv[2], sys.argv[3]
out = subprocess.run(["git", "-C", repo, "ls-tree", "-r", "-z", "origin/HEAD"], stdout=subprocess.PIPE, check=True).stdout
entries = M.tree_entries(out, rd)
def cat(sha):
    p = subprocess.run(["git", "-C", repo, "cat-file", "blob", sha], stdout=subprocess.PIPE)
    return p.returncode, p.stdout
found, unchecked = M.find_roadmaps(list(entries), M.blob_reader(entries, cat, set()), rd)
print(" ".join(found) + " | 검사 불가 %d" % len(unchecked))
PY
assert_eq "$(python3 "$T/count.py" "$S" "$W" "$RD")" "${RD}old1/roadmap.md ${RD}t1/roadmap.md | 검사 불가 0" "AC8: 기본 브랜치의 로드맵은 old1 · t1 둘이고 검사 불가가 없다(역할 폴더 · HANDBOOK.md 가 같은 자리에 있어도)"

finish
