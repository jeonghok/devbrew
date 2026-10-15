#!/usr/bin/env bash
# R7 §1 — 인터뷰 상태 파일: 진입 판결 · 끝내기 커밋 · 옛 자리 이월 · reviewing-brief 의 degrade 원장 (AC2 · AC3 · AC4 · AC5 · AC12).
set -u
ROOT_REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT_REPO/plugins/spec-distill"
. "$ROOT_REPO/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
unset DEVBREW_SPEC_DISTILL_DISABLE DEVBREW_SKIP_HOOKS DEVBREW_SPEC_DISTILL_TTL_HOURS
T="$(mktemp -d)"; [ -n "$T" ] && [ -d "$T" ] || { echo "mktemp 실패"; exit 1; }
T="$(cd "$T" && pwd -P)"; trap 'rm -rf "$T"' EXIT

fence() {   # fence <파일> <마커 이름> → 그 마커 사이 첫 bash 펜스 본문
  awk -v b="<!-- $2:begin -->" -v e="<!-- $2:end -->" '
    index($0,b){f=1;next} index($0,e){f=0} f&&/^```bash$/{c=1;next} f&&c&&/^```$/{c=0;next} f&&c' "$1"
}
SK="$SD/skills/spec-interview/SKILL.md"; SF="$SD/skills/spec-interview/references/state-file.md"
FIN="$SD/skills/spec-interview/references/finishing.md"; RB="$SD/skills/reviewing-brief/SKILL.md"

# AC2 — production 표면의 state.local.md 는 §1-7 이월 문면과 정리 코드에만
hits="$(cd "$ROOT_REPO" && git grep --untracked -lF 'state.local.md' -- plugins/spec-distill/skills plugins/spec-distill/references plugins/spec-distill/scripts plugins/spec-distill/templates | sort)"
want="$(printf '%s\n' plugins/spec-distill/scripts/interview_state.py plugins/spec-distill/scripts/ledger_sweep.py plugins/spec-distill/skills/spec-interview/references/state-file.md | sort)"
assert_eq "$hits" "$want" "AC2: state.local.md 는 이월 문면(state-file.md) · interview_state.py · ledger_sweep.py 에만"
grep -cF 'state.local.md' "$SF" | grep -qx 1 && ok "AC2: state-file.md 의 옛 이름은 §1-7 이월 문단 하나에만" || no "AC2: state-file.md 의 옛 이름 횟수"
# 같은 개념의 다른 이름(세션 폴더 · Bash 전용 쓰기 · 세션 종료 정리)도 인터뷰 표면에서 사라졌다
for tok in 'PN1' 'per-session' 'Bash 로만' 'SessionEnd' 'Bash write contract'; do
  grep -qF -- "$tok" "$SK" "$SD"/skills/spec-interview/references/*.md \
    && no "AC2(별칭): 인터뷰 표면에 「${tok}」 이 남았다" || ok "AC2(별칭): 인터뷰 표면에 「${tok}」 없음"
done

# AC3 — 진입 펜스 판결 · 상태 파일 첫 키
iv="$T/iv"; mkdir -p "$iv/docs/superpowers/interview" && git -C "$iv" init -q
D="$iv/docs/superpowers/interview"
printf -- '---\ntype: interview-state\nseed: 없음\n---\n## R1\n' > "$D/2026-10-15-t-interview.state.md"
ent() { ( cd "$iv" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-iv000001 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-iv000001 \
          bash -c "ARG_PATH='$1'
$(fence "$SK" interview-state-entry)" 2>/dev/null | tail -n 1 ); }
[ -n "$(fence "$SK" interview-state-entry)" ] && ok "AC3: SKILL 에 진입 펜스(interview-state-entry)가 있다" || no "AC3: 진입 펜스가 없다"
assert_eq "$(ent "$D/2026-10-15-t-interview.state.md")" "interview-state: RESUME $D/2026-10-15-t-interview.state.md" "AC3: @<…>.state.md 는 이어 가는 분기"
grep -qF '`interview-state: RESUME <경로>`' "$SK" && ok "AC3: SKILL 판결 표에 RESUME 행" || no "AC3: SKILL 판결 표에 RESUME 행이 없다"
for v in 'interview-state: ASK' 'interview-state: LEGACY <경로>' 'interview-state: NEW-SEED <주제> seed=<경로>' 'interview-state: NEW`' 'interview-state: REJECT …'; do
  grep -qF -- "$v" "$SK" && ok "AC3: SKILL 판결 표에 「${v}」" || no "AC3: SKILL 판결 표에 「${v}」 이 없다"
done
printf -- '---\ntype: interview-seed\n---\n' > "$D/2026-10-15-s-interview.md"
printf -- '---\ntype: interview-seed-audit\n---\n' > "$D/2026-10-15-s-interview.audit.md"
v="$(ent "$D/2026-10-15-s-interview.md")"
assert_eq "$v" "interview-state: NEW-SEED s-brief seed=docs/superpowers/interview/2026-10-15-s-interview.md" "AC3: seed 로 시작하면 주제에 -brief 꼬리"
p="$(cd "$iv" && python3 "$SD/scripts/state_path.py" interview-state --topic s-brief --date 2026-10-15)"
case "$p" in "$D/2026-10-15-s-brief-interview.state.md") ok "AC3: 같은 날 seed 와 겹치지 않는 경로";; *) no "AC3: 경로 $p";; esac
grep -qF 'type: interview-state' "$SF" && grep -qF 'seed: <' "$SF" && ok "AC3: state-file.md 가 첫 두 키를 정한다" || no "AC3: 첫 두 키 문면"
grep -qF 'state_path.py" interview-state --topic' "$SF" && grep -qF '그 출력 경로에만' "$SF" \
  && ok "AC3: 상태 파일은 스크립트가 낸 경로에만 만든다(문면)" || no "AC3: 상태 파일 자리를 스크립트 출력으로 묶지 않았다"

# AC4 — 이어 감/새로 시작 질문 문면 · 새로 시작은 지우지 않는다
grep -qF '「이어 감 (권장)」' "$SF" && grep -qF '「새로 시작」' "$SF" && grep -qF '기존 파일은 지우지 않는다' "$SF" \
  && ok "AC4: 질문 문면과 보존 문장" || no "AC4: 질문 문면"

# AC5 — 커밋은 B-3 확정 뒤 한 번(문면 순서) · Step A/A.5 · ③ 에 커밋 없음
python3 -I - "$FIN" <<'PY' && ok "AC5: 커밋 펜스 자리(문면 순서)" || no "AC5: 커밋 펜스 자리"
import sys
t = open(sys.argv[1], encoding="utf-8").read()
a, a5, b3 = t.find("### Step A —"), t.find("### Step A.5"), t.find("#### B-3")
c = t.find("<!-- interview-commit:begin -->")
gate = t.find("`check_brief.py gate` 재실행(통과 확인)", b3)
three = t.find("- **③ 확정 목록 수정**", b3); four = t.find("- **④ brief만 종료**", b3)
nocommit = lambda s: "git commit" not in s and "interview-commit" not in s and "커밋 펜스" not in s
ok = (0 <= a < a5 < b3 < gate < c) and nocommit(t[a:b3]) and nocommit(t[three:four])
ok = ok and "interview-commit" in t[four:t.find("#### B-4")]
sys.exit(0 if ok else 1)
PY

cf="$(fence "$FIN" interview-commit)"
[ -n "$cf" ] && ok "AC5: 커밋 펜스(interview-commit)가 있다" || no "AC5: 커밋 펜스가 없다"
mk() {   # mk <이름> → origin 을 가진 클론, docs 에 세 파일
  local o="$T/$1-origin.git" c="$T/$1"
  git init -q --bare -b main "$o"; git clone -q "$o" "$c" 2>/dev/null
  git -C "$c" config user.email t@t.t; git -C "$c" config user.name t
  git -C "$c" commit -q --allow-empty -m init; git -C "$c" push -q origin main 2>/dev/null
  git -C "$c" remote set-head origin main >/dev/null 2>&1
  mkdir -p "$c/docs/superpowers/interview"
  for s in .md .audit.md .state.md; do printf 'x\n' > "$c/docs/superpowers/interview/2026-10-15-t-interview$s"; done
  printf '%s' "$c"
}
PH='<Step A.5 의 PAYLOAD 절대경로>'
grep -qF "BRIEF=\"$PH\"" <<<"$cf" && ok "AC5: 커밋 펜스가 BRIEF 를 자기 안에서 대입한다(자리표)" || no "AC5: 커밋 펜스에 BRIEF 자리표 줄이 없다"
runc() {   # runc <클론> → 자리표를 그 클론의 brief 절대경로로 바꿔 돈 출력
  local brief="$1/docs/superpowers/interview/2026-10-15-t-interview.md"
  ( cd "$1" && CLAUDE_PLUGIN_ROOT="$SD" bash -c "${cf//"$PH"/$brief}" 2>&1 )
}
c1="$(mk on-main)"
o="$(runc "$c1")"
assert_eq "$(git -C "$c1" rev-list --count HEAD)" "1" "AC5: 기본 브랜치에서는 커밋하지 않는다"
printf '%s\n' "$o" | grep -qF '브랜치에서 커밋하라' && printf '%s\n' "$o" | grep -qF '2026-10-15-t-interview.state.md' \
  && ok "AC5: 기본 브랜치 — 세 경로와 안내를 보인다" || no "AC5: 기본 브랜치 출력: $o"
c2="$(mk on-feature)"; git -C "$c2" switch -q -c feature/x
printf 'y\n' > "$c2/other.txt"; git -C "$c2" add other.txt
o="$(runc "$c2")"
assert_eq "$(git -C "$c2" show --name-only --pretty=format: HEAD | sed '/^$/d' | sort | tr '\n' ' ')" \
  "docs/superpowers/interview/2026-10-15-t-interview.audit.md docs/superpowers/interview/2026-10-15-t-interview.md docs/superpowers/interview/2026-10-15-t-interview.state.md " \
  "AC5: 기능 브랜치 — 세 경로만 한 커밋으로"
assert_eq "$(git -C "$c2" log -1 --pretty=%s)" "docs(interview): 2026-10-15-t-interview brief · audit · 상태 기록" "R-h: 끝내기 커밋 메시지 꼴"
printf '%s\n' "$o" | grep -qF 'brief · audit · 상태 파일을 커밋했다' && ok "AC5: 커밋한 사실을 보인다" || no "AC5: 커밋 출력: $o"
git -C "$c2" diff --cached --name-only | grep -qx other.txt && ok "Review Focus: staged_other_stays_staged" || no "staged 다른 파일이 사라졌다"
c3="$(mk no-head)"; git -C "$c3" switch -q -c feature/y; git -C "$c3" remote set-head origin -d >/dev/null 2>&1
o="$(runc "$c3")"
assert_eq "$(git -C "$c3" rev-list --count HEAD)" "1" "AC5: origin/HEAD 가 없으면 커밋하지 않는다"
printf '%s\n' "$o" | grep -qF '기본 브랜치를 판정하지 못했다' && ok "AC5: 그 사유를 보인다" || no "AC5: 사유 없음: $o"
o="$(cd "$c3" && CLAUDE_PLUGIN_ROOT="$SD" bash -c "$cf" 2>&1)"
printf '%s\n' "$o" | grep -qF '커밋 입력 부재' && ok "AC5: BRIEF 가 비면 커밋하지 않고 사유를 보인다" || no "AC5: BRIEF 부재 출력: $o"

# 보안 보충 — 링크인 상태 파일은 커밋하지 않고 링크 너머를 건드리지 않는다
c4="$(mk link-state)"; git -C "$c4" switch -q -c feature/z
printf 'outside\n' > "$T/outside.txt"
rm -f "$c4/docs/superpowers/interview/2026-10-15-t-interview.state.md"
ln -s "$T/outside.txt" "$c4/docs/superpowers/interview/2026-10-15-t-interview.state.md"
o="$(runc "$c4")"
assert_eq "$(git -C "$c4" rev-list --count HEAD)" "1" "보안: 상태 파일이 링크면 커밋하지 않는다"
assert_eq "$(git -C "$c4" diff --cached --name-only)" "" "보안: 링크면 아무것도 stage 하지 않는다"
assert_eq "$(cat "$T/outside.txt")" "outside" "보안: 링크 너머 파일은 그대로다"
printf '%s\n' "$o" | grep -qF '링크' && printf '%s\n' "$o" | grep -qF '2026-10-15-t-interview.audit.md' \
  && ok "보안: 거부 사유와 세 경로를 보인다" || no "보안: 링크 거부 출력: $o"
grep -qF 'path-inside --root "$top" "$BRIEF" "$AUDIT_F" "$STATE_F"' <<<"$cf" && ok "보안: 커밋 펜스가 세 경로를 path-inside 로 잰다" || no "보안: path-inside 관문이 없다"
# 양성 대조 — cwd 를 링크로 들어왔어도(논리 경로 BRIEF) 커밋한다. 이 칸의 경로는 pwd -P 로 풀지 않는다.
c5="$(mk via-link)"; git -C "$c5" switch -q -c feature/l
ln -s "$c5" "$T/lk-c5"
o="$(runc "$T/lk-c5")"
assert_eq "$(git -C "$c5" rev-list --count HEAD)" "2" "보안 양성 대조: 링크 cwd 로 들어와도 세 파일을 커밋한다 ($o)"
# 인터뷰 폴더가 다른 git 저장소로 가는 링크 — 어느 쪽에도 커밋하지 않는다
c6="$(mk host)"; git -C "$c6" switch -q -c feature/h
c7="$(mk sibling)"; git -C "$c7" switch -q -c feature/s
rm -rf "$c6/docs/superpowers/interview"; ln -s "$c7/docs/superpowers/interview" "$c6/docs/superpowers/interview"
o="$(runc "$c6")"
assert_eq "$(git -C "$c6" rev-list --count HEAD) $(git -C "$c7" rev-list --count HEAD)" "1 1" "보안: 인터뷰 폴더가 다른 저장소로 가는 링크면 어느 쪽에도 커밋하지 않는다"
assert_eq "$(git -C "$c6" diff --cached --name-only)$(git -C "$c7" diff --cached --name-only)" "" "보안: 그때 어느 쪽에도 stage 하지 않는다"
printf '%s\n' "$o" | grep -qF '커밋하지 않았다' && ok "보안: 그 사유를 보인다" || no "보안: 다른 저장소 링크 출력: $o"
# detached HEAD — 브랜치 위가 아니면 커밋하지 않는다
c8="$(mk detached)"; git -C "$c8" switch -q --detach
o="$(runc "$c8")"
assert_eq "$(git -C "$c8" rev-list --count HEAD)" "1" "AC5: detached HEAD 면 커밋하지 않는다"
printf '%s\n' "$o" | grep -qF 'detached HEAD' && ok "AC5: detached HEAD 사유를 보인다" || no "AC5: detached 출력: $o"
grep -qF 'brief · audit · 상태 파일은 커밋하지 않았다' "$FIN" && ok "B-1: superpowers 부재 안내가 세 파일을 커밋하지 않았다고 말한다" || no "B-1: 미커밋 안내가 없다"
# 이어 갈 때의 「풀린 입력」 — 상태 파일 전문이 아니라 그 안의 블록
python3 -I - "$SK" <<'PY' && ok "fix1: SKILL 3 · 3.5 가 interview-state 도 건너뛴다" || no "fix1: SKILL 3 · 3.5 가 interview-state 를 모른다"
import sys
t = open(sys.argv[1], encoding="utf-8").read()
s3 = t[t.index("### 3. trivia"):t.index("### 3.5")]
s35 = t[t.index("### 3.5"):t.index("### 3.6")]
sys.exit(0 if "type: interview-state" in s3 and "type: interview-state" in s35 else 1)
PY
grep -qF '본문 맨 앞에는 `## 풀린 입력` 블록을 두고' "$SF" && grep -qF 'NEW 면 받은 요청' "$SF" \
  && ok "fix1: 만들 때 「풀린 입력」을 블록에 남긴다(문면)" || no "fix1: 풀린 입력 블록 문면 없음"
grep -qF '상태 파일 전문이 아니다' "$SF" && grep -qF '`S1` 없음' "$SF" && grep -qF '사용자에게 한 번 알린다' "$SF" \
  && ok "fix1: 이어 갈 때 「풀린 입력」은 블록 · 없으면 알린다(문면)" || no "fix1: 이어 갈 때 풀린 입력 문면 없음"

# AC12 — 옛 state.local.md 이월(펜스 + 스크립트)
mkdir -p "$iv/.claude/spec-distill/sess-iv000001"
printf -- '---\nsession_id: x\n---\n## R1\n' > "$iv/.claude/spec-distill/sess-iv000001/state.local.md"
assert_eq "$(ent "")" "interview-state: LEGACY $iv/.claude/spec-distill/sess-iv000001/state.local.md" "AC12: 옛 진행 기록이 있으면 LEGACY"
o="$(cd "$iv" && CLAUDE_CODE_SESSION_ID=sess-iv000001 python3 "$SD/scripts/interview_state.py" migrate-legacy --session sess-iv000001 --topic old --date 2026-10-15)"
printf '%s\n' "$o" | grep -qF "옛 위치의 진행 기록을 docs 로 옮겼다 — $D/2026-10-15-old-interview.state.md" \
  && ok "AC12: 옮기고 그 사실을 보인다" || no "AC12: $o"
grep -qF 'interview_state.py" migrate-legacy' "$SF" && ok "AC12: state-file.md 가 LEGACY 에서 이월을 부른다" || no "AC12: 이월 호출 문면 없음"

# §1-6 · §2-5 — reviewing-brief 의 degrade 원장은 그 인터뷰의 상태 파일, 두 번째 채널은 원장 자리 안. 세션 폴더를 만들지 않는다.
grep -qF '$ROOT/$harness_sid' "$RB" && no "§2-5: reviewing-brief 에 세션 폴더 경로(\$ROOT/\$harness_sid)가 남았다" || ok "§2-5: reviewing-brief 에 세션 폴더 경로 없음"
python3 -I - "$RB" "$T/rbh" >/dev/null <<'PY'
import os, re, sys
t = open(sys.argv[1], encoding="utf-8").read()
os.makedirs(sys.argv[2], exist_ok=True)
n = 0
for b in re.findall(r"```bash\n(.*?)\n```", t, re.S):
    lines = b.split("\n")
    if not any(l.startswith("DEGRADE_FALLBACK_FILE=") for l in lines):
        continue
    end = next(i for i, l in enumerate(lines) if l.startswith('touch "${DEGRADE_FALLBACK_FILE'))
    with open(os.path.join(sys.argv[2], "h{0}.sh".format(n)), "w", encoding="utf-8") as f:
        f.write("\n".join(lines[:end + 1]) + "\n")
    n += 1
print(n)
PY
n_heads="$(ls "$T/rbh" 2>/dev/null | wc -l | tr -d ' ')"
n_state="$(grep -c '^STATE="${PAYLOAD:+${PAYLOAD%-interview.md}-interview.state.md}"' "$RB")"
[ "$n_heads" -ge 1 ] && [ "$n_heads" = "$n_state" ] && ok "§1-6: 머리 ${n_heads}개가 모두 STATE 를 상태 파일로 도출한다" || no "§1-6: 머리 ${n_heads}개 · 상태 파일 STATE ${n_state}줄"
grep -qF 'brief_review_state.py" degrade-append "$STATE"' "$RB" && ok "§1-6 양의 짝: degrade 기록이 \$STATE 로 간다" || no "§1-6: degrade-append 호출이 없다"
rbr="$T/rb"; mkdir -p "$rbr/docs/superpowers/interview" && git -C "$rbr" init -q
RBD="$rbr/docs/superpowers/interview"
printf -- '---\ntype: interview-brief\n---\n' > "$RBD/2026-10-15-t-interview.md"
printf -- '---\ntype: interview-state\nseed: 없음\n---\n' > "$RBD/2026-10-15-t-interview.state.md"
runh() {   # runh <repo> <머리 파일> → __STATE · __DIR · __FB 줄
  ( cd "$1" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-rb000001 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-rb000001 TMPDIR="$T/tmpd" \
      bash -c "PAYLOAD='docs/superpowers/interview/2026-10-15-t-interview.md'; AUDIT='docs/superpowers/interview/2026-10-15-t-interview.audit.md'
$(cat "$2")
echo \"__STATE=\$STATE\"; echo \"__DIR=\$STATE_DIR\"; echo \"__FB=\$DEGRADE_FALLBACK_FILE\"" 2>/dev/null )
}
mkdir -p "$T/tmpd"
RBKEY="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$rbr/.claude/spec-distill" --doc "$RBD/2026-10-15-t-interview.md")"
# 원장 열기 전 — 머리는 원장 자리를 만들지 않고 두 번째 채널을 임시 폴더로 보낸다
for h in "$T"/rbh/h*.sh; do
  [ -f "$h" ] || continue
  o="$(runh "$rbr" "$h")"
  st="$(printf '%s\n' "$o" | sed -n 's/^__STATE=//p')"; dir="$(printf '%s\n' "$o" | sed -n 's/^__DIR=//p')"; fb="$(printf '%s\n' "$o" | sed -n 's/^__FB=//p')"
  assert_eq "$st" "$RBD/2026-10-15-t-interview.state.md" "§1-6: $(basename "$h") — STATE 는 그 인터뷰의 상태 파일"
  assert_eq "$dir" "$RBKEY" "§1-6: $(basename "$h") — 원장 자리는 .docreview 아래 그 문서의 자리"
  assert_eq "$fb" "$T/tmpd/brief-degrade-fallback.sess-rb000001.txt" "§1-6: $(basename "$h") — 원장 열기 전이면 두 번째 채널은 임시 폴더"
  [ -e "$RBKEY" ] && no "A1: $(basename "$h") — 원장 열기 전에 원장 자리를 만들었다" || ok "A1: $(basename "$h") — 원장 열기 전에 원장 자리를 만들지 않는다"
  [ -e "$rbr/.claude/spec-distill/sess-rb000001" ] && no "§2-5: $(basename "$h") — 세션 폴더를 만들었다" || ok "§2-5: $(basename "$h") — 세션 폴더를 만들지 않는다"
done
# 원장 열기 전의 record(BRIEF_REVIEW skip 꼴) — 원장 자리를 만들지 않는다
python3 -I - "$RB" "$T/rec.sh" >/dev/null <<'PY'
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
b = next(x for x in re.findall(r"```bash\n(.*?)\n```", t, re.S) if 'degrade-append "$STATE" --component <a>' in x)
b = b.replace("<a>", "pipeline").replace("<b>", "all").replace("<c>", "skipped").replace("<r>", "rec-probe-1")
open(sys.argv[2], "w", encoding="utf-8").write(b + "\n")
PY
runh "$rbr" "$T/rec.sh" >/dev/null
[ -e "$RBKEY" ] && no "A1: 원장 열기 전 record 가 원장 자리를 만들었다" || ok "A1: 원장 열기 전 record 는 원장 자리를 만들지 않는다"
grep -qF 'rec-probe-1' "$RBD/2026-10-15-t-interview.state.md" "$T/tmpd/brief-degrade-fallback.sess-rb000001.txt" 2>/dev/null \
  && ok "A1: 그 record 는 상태 파일이나 임시 두 번째 채널에 닿는다" || no "A1: 원장 열기 전 record 가 사라졌다"
# 원장 열기 뒤 — 두 번째 채널은 원장 자리 안
o="$(cd "$rbr" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-rb000001 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-rb000001 \
      bash -c "PAYLOAD='docs/superpowers/interview/2026-10-15-t-interview.md'
$(fence "$RB" ledger-open)" 2>&1 | tail -n 1)"
assert_eq "$o" "ledger-open: HELD" "A1: 원장 열기가 표지를 잡는다(전제)"
for h in "$T"/rbh/h*.sh; do
  [ -f "$h" ] || continue
  fb="$(runh "$rbr" "$h" | sed -n 's/^__FB=//p')"
  assert_eq "$fb" "$RBKEY/brief-degrade-fallback.txt" "§1-6: $(basename "$h") — 원장 열기 뒤 두 번째 채널은 원장 자리 안"
done
# 링크인 .docreview(링크 너머에 그 문서의 자리까지 있다) — 두 번째 채널은 임시 폴더로, 링크 너머는 비어 있다
lrb="$T/lrb"; mkdir -p "$lrb/docs/superpowers/interview" "$lrb/.claude/spec-distill" "$T/outdir" && git -C "$lrb" init -q
cp "$RBD"/2026-10-15-t-interview.md "$RBD"/2026-10-15-t-interview.state.md "$lrb/docs/superpowers/interview/"
ln -s "$T/outdir" "$lrb/.claude/spec-distill/.docreview"
LKEY="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$lrb/.claude/spec-distill" --doc "$lrb/docs/superpowers/interview/2026-10-15-t-interview.md")"
mkdir -p "$LKEY"
o="$(runh "$lrb" "$T/rbh/h0.sh")"
fb="$(printf '%s\n' "$o" | sed -n 's/^__FB=//p')"
assert_eq "$fb" "$T/tmpd/brief-degrade-fallback.sess-rb000001.txt" "보안: 원장 자리가 링크면 두 번째 채널은 임시 폴더"
assert_eq "$(ls -A "$LKEY")" "" "보안: 링크 너머 그 문서의 자리에 아무것도 만들지 않는다"
[ -e "$lrb/.claude/spec-distill/sess-rb000001" ] && no "§2-5: 링크 칸 — 세션 폴더를 만들었다" || ok "§2-5: 링크 칸 — 세션 폴더를 만들지 않는다"

finish
