#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/context-build/SKILL.md plugins/spec-distill/skills/context-build/references/state-file.md plugins/spec-distill/skills/context-build/references/seed-input.md plugins/spec-distill/skills/context-build/references/steelman.md plugins/spec-distill/agents/coverage-mapper.md plugins/spec-distill/agents/blind-spot-prober.md plugins/spec-distill/skills/intent-sync/SKILL.md
#
# 인터뷰 진입이 원자료를 찾아 읽고, seed 를 사용자의 말이 아니라 모델이 줄인 글로 부른다(원자료 정본 사슬 AC7 · AC12 · AC22).
#   - 인터뷰 본문: audit 경로는 raw_source.py 판결 줄에서 받는다 · 한 답의 라벨과 적은 말은 S 둘 · coverage-mapper 첫 입력에
#     원자료 경로 · 자기 줄 수는 SKILL_LINE_CAP 미만.
#   - 네 파일(본문 · 두 agent · steelman)에서 seed 를 S1 · 사용자 원문으로 부르는 옛 낱말이 사라지고 새 낱말이 선다.
#   - state-file.md 「원자료 — 판결 뒤」 절: 다섯 자리 표 · 펜스 · 출력 줄 · 막지 않음. 펜스는 임시 레포에서 실제로 돈다.
#   - seed-input.md 의 S1 항목 · intent-sync 의 문장.
#   변이 — 한 자리씩 깬 사본 묶음을 같은 판정에 먹여 그 이름이 실패로 나오는지 본다.
set -u
REL_FILES="skills/context-build/SKILL.md skills/context-build/references/state-file.md skills/context-build/references/seed-input.md skills/context-build/references/steelman.md agents/coverage-mapper.md agents/blind-spot-prober.md skills/intent-sync/SKILL.md"
if [ "${1:-}" = "--emit-scanned" ]; then
  for r in $REL_FILES; do printf 'plugins/spec-distill/%s\n' "$r"; done
  exit 0
fi
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SDP="$REPO_ROOT/plugins/spec-distill"
CAPF="$SDP/tests/test_conducting_interview_stage.sh"
. "$REPO_ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
W="$(mktemp -d)"; [ -n "$W" ] && [ -d "$W" ] || { echo "mktemp 실패"; exit 1; }
trap 'rm -rf "$W"' EXIT

# 펜스를 돌릴 임시 레포 둘 — 기록이 있는 인터뷰와 기록 파일을 잃은 인터뷰.
fx_get() { grep -E "^$2=" "$1" | head -n 1 | cut -d= -f2-; }
python3 -I "$SDP/tests/raw_source_fixture.py" make "$W/rec" --mode recorded > "$W/rec.keys" || { no "픽스처(recorded)를 짓지 못했다"; finish; }
python3 -I "$SDP/tests/raw_source_fixture.py" make "$W/lost" --mode lost > "$W/lost.keys" || { no "픽스처(lost)를 짓지 못했다"; finish; }
REC_SEED="$(fx_get "$W/rec.keys" seed)"; REC_STATE="$(fx_get "$W/rec.keys" state)"; LOST_STATE="$(fx_get "$W/lost.keys" state)"
[ -f "$REC_SEED" ] && [ -f "$REC_STATE" ] && [ -f "$LOST_STATE" ] && ok "픽스처 경로가 실재한다" || no "픽스처 경로가 비었다"
# 머리말을 UTF-8 로 읽을 수 없는 상태 파일 — locate 가 판결 줄 없이 종료 코드 2 로 끝난다.
BAD_STATE="$W/rec/docs/iv/깨진-interview.state.md"
printf -- '---\ntype: interview-state\nseed: \377\376\n---\n' > "$BAD_STATE"
python3 -I "$SDP/scripts/raw_source.py" locate --interview "$BAD_STATE" --absolute > "$W/bad.probe" 2>/dev/null
[ "$?" = 2 ] && ! grep -q '^raw-source: ' "$W/bad.probe" && ok "전제: 깨진 상태 파일에서 locate 가 판결 줄 없이 2 로 끝난다" \
  || no "전제: 깨진 상태 파일이 종료 코드 2 를 내지 않는다 — fence_no_verdict 가 공허하다"

# 예외로 죽는 raw_source.py(권한 오류 같은 것) — 판결 줄도 [raw_source] 줄도 없이 종료 코드 1.
CRASH_ROOT="$W/crash-root"; mkdir -p "$CRASH_ROOT/scripts"
printf 'raise PermissionError(13, "가짜")\n' > "$CRASH_ROOT/scripts/raw_source.py"
SHELLS="/bin/bash"
[ -x /bin/zsh ] && SHELLS="$SHELLS /bin/zsh"

# run_fence <state-file.md> <셸> <SEED_ABS> <STATE> <꼬리표> — $W/<꼬리표>.{out,err,rc}
run_fence() {
  local body="$W/$5.sh" sh="$2" flag=""
  printf "SEED_ABS='%s'\nSTATE='%s'\n" "$3" "$4" > "$body"
  awk '$0=="### 원자료 — 판결 뒤"{inside=1; next}
       inside && /^#/ {exit}
       inside && $0=="```bash" {grab=1; next}
       grab && $0=="```" {exit}
       grab {print}' "$1" >> "$body"
  case "$sh" in */zsh) flag="-f" ;; esac
  env -i PATH="$PATH" CLAUDE_PLUGIN_ROOT="${FENCE_ROOT:-$SDP}" PYTHONDONTWRITEBYTECODE=1 "$sh" $flag "$body" > "$W/$5.out" 2> "$W/$5.err"
  echo "$?" > "$W/$5.rc"
}
verdicts() { grep -c '^raw-source: ' "$W/$1.out"; }

# fence_fails <state-file.md> → 실패한 펜스 실행 이름을 한 줄씩
fence_fails() {
  local sf="$1" sh tag nm
  for sh in $SHELLS; do
    nm="${sh##*/}"
    tag="both-$nm"; run_fence "$sf" "$sh" "$REC_SEED" "$REC_STATE" "$tag"
    { [ "$(cat "$W/$tag.rc")" = 0 ] && [ "$(verdicts "$tag")" = 2 ] \
      && [ "$(grep '^raw-source: FOUND ' "$W/$tag.out" | wc -l | tr -d ' ')" = 2 ] \
      && grep '^raw-source: ' "$W/$tag.out" | sed -n 2p | grep -q '^raw-source: FOUND /'; } || echo "fence_both:$nm"
    tag="lost-$nm"; run_fence "$sf" "$sh" "" "$LOST_STATE" "$tag"
    { [ "$(cat "$W/$tag.rc")" = 0 ] && [ "$(verdicts "$tag")" = 1 ] && grep -q '^raw-source: LOST ' "$W/$tag.out" \
      && grep -qF '판결 종료 코드 3' "$W/$tag.err"; } || echo "fence_lost:$nm"
    tag="nostate-$nm"; run_fence "$sf" "$sh" "" "$W/rec/docs/iv/없는-interview.state.md" "$tag"
    { [ "$(cat "$W/$tag.rc")" = 1 ] && [ "$(verdicts "$tag")" = 0 ] && grep -qF '상태 파일이 없다(' "$W/$tag.err"; } || echo "fence_no_state:$nm"
    tag="seed-$nm"; run_fence "$sf" "$sh" "$REC_SEED" "" "$tag"
    { [ "$(cat "$W/$tag.rc")" = 0 ] && [ "$(verdicts "$tag")" = 1 ] && grep -q '^raw-source: FOUND ' "$W/$tag.out"; } || echo "fence_seed_only:$nm"
    tag="noverdict-$nm"; run_fence "$sf" "$sh" "" "$BAD_STATE" "$tag"
    { [ "$(cat "$W/$tag.rc")" = 0 ] && [ "$(verdicts "$tag")" = 0 ] \
      && grep -qF '[spec-distill] 판결 종료 코드 2 — 판결 줄이 없다. 아래 「판결 줄이 없다」 갈래대로 간다' "$W/$tag.err"; } || echo "fence_no_verdict:$nm"
    tag="crash-$nm"; FENCE_ROOT="$CRASH_ROOT" run_fence "$sf" "$sh" "$REC_SEED" "$REC_STATE" "$tag"
    { [ "$(cat "$W/$tag.rc")" = 0 ] && [ "$(verdicts "$tag")" = 0 ] && ! grep -qF '멈추지 않는다' "$W/$tag.err" \
      && grep -qF '[spec-distill] 판결 종료 코드 1 — 판결 줄이 없다. 「seed 원문 대조」 줄은 audit=없음(' "$W/$tag.err" \
      && grep -qF '[spec-distill] 판결 종료 코드 1 — 판결 줄이 없다. 아래 「판결 줄이 없다」 갈래대로 간다' "$W/$tag.err"; } || echo "fence_crash:$nm"
  done
}

# entry_fails <플러그인 꼴 폴더> → 실패한 단언 이름을 한 줄씩(통과면 빈 출력)
entry_fails() {
  local root="$1" cap own
  cap="$(grep -E '^SKILL_LINE_CAP=[0-9]+$' "$CAPF" | head -n 1 | cut -d= -f2)"
  own="$(awk '/^<!-- plain-language:begin -->$/{s=1} s==0{n++} s==2{s=0; if ($0 != "") n++; next} /^<!-- plain-language:end -->$/{s=2} END{print n+0}' "$root/skills/context-build/SKILL.md")"
  { [ -n "$cap" ] && [ "$own" -lt "$cap" ]; } || echo skill_lines
  python3 -I -B - "$root" <<'ENTRY_WORDS_PY' || echo words_checker_crashed
import os
import re
import sys

root = sys.argv[1]


def raw(rel):
    try:
        return open(os.path.join(root, rel), encoding="utf-8").read()
    except OSError:
        return ""


def flat(rel):
    return re.sub(r"\n[ \t]*", " ", raw(rel))


bad = []


def want(name, cond):
    if not cond:
        bad.append(name)


skill = flat("skills/context-build/SKILL.md")
want("skill_module", "`scripts/raw_source.py` 가 낸 판결 줄에서 받는다" in skill
     and "읽은 파일의 절대경로에서 audit 경로를 도출한다" not in skill)
want("skill_no_verdict", "판결이 찾음이 아니면 `audit=없음(<판결 줄의 사유>)` 로 낸다" in skill)
want("skill_two_s", "한 답에 고른 것과 적은 말이 섞였으면 S 둘로 적는다" in skill)
want("skill_first_input", "원자료의 경로(진입 단계의 원자료 판결이 찾음일 때" in skill
     and "그 파일의 `## 1. 원문` 절과 `## 2. 질문 전체` 절을 Read 로 읽는다" in skill)

old_words = ("seed 전문(S1)", "S1 이 될 값", "seed S1", "사용자 원문(S1 과 문제를 서술한 발화)",
             "사용자 원문 — S1 과 문제를 서술한 발화")
for rel in ("skills/context-build/SKILL.md", "agents/coverage-mapper.md", "agents/blind-spot-prober.md",
            "skills/context-build/references/steelman.md"):
    t = flat(rel)
    want("no_seed_as_s1:" + rel,
         bool(t) and not any(w in t for w in old_words) and ("모델이 줄인 글" in t or "원자료" in t))

st_raw = raw("skills/context-build/references/state-file.md")
head = "\n### 원자료 — 판결 뒤\n"
i = st_raw.find(head)
j = st_raw.find("\n#", i + len(head)) if i >= 0 else -1
sec_raw = st_raw[i:j] if 0 <= i < j else ""
sec = re.sub(r"\n[ \t]*", " ", sec_raw)
rows = [ln for ln in sec_raw.split("\n") if ln.startswith("| ")]
row_heads = ("| `NEW-SEED` 또는 `ASK` 의 「새로 시작」 — 상태 파일을 만든 직후 |", "| `RESUME`(`LEGACY` 를 옮긴 뒤 포함) |",
             "| `NEW` 인데 seed 를 경로로 받았다", "| `NEW` 인데 seed 를 붙여 넣었다 |",
             "| `NEW` 이고 seed 가 아니다 |")
placed = (0 <= st_raw.find("\n### 이어 갈 때\n") < i < st_raw.find("\n### 옛 자리의 진행 기록\n"))
want("state_section", placed
     and all(any(r.startswith(h) for r in rows) for h in row_heads)
     and 'locate --interview "$STATE" --absolute' in sec
     and 'locate --seed "$SEED_ABS"' in sec
     and "원자료: 읽음 — " in sec and "원자료: 찾지 못함 — " in sec
     and "원자료: 없음 — framing 없는 컨텍스트 쌓기" in sec
     and "원자료를 찾지 못했다(<사유>) — seed 만 읽는다" in sec
     and "막지 않고" in sec)
want("state_resume", "이어 가는 세션은 앞 세션이 읽은 글을 갖고 있지 않다" in sec)
resume_row = [r for r in rows if r.startswith("| `RESUME`(`LEGACY` 를 옮긴 뒤 포함) |")]
want("state_resume_seed", len(resume_row) == 1
     and "진입 인자가 seed 경로였으면(`ASK` 의 「이어 감」 등) `SEED_ABS` 도 채운다" in resume_row[0]
     and "「seed 원문 대조」 줄" in resume_row[0]
     and "`STATE` 만 채워" not in resume_row[0])
want("state_no_verdict",
     "`[spec-distill] 원자료: 찾지 못함 — 판결 줄이 없다(종료 코드 <n>: <[raw_source] 줄 — 없으면 오류 출력의 마지막 줄>)`" in sec
     and "끝맺음은 같은 판결 없이는 멈추므로(`finishing.md` Step A 3) 그 사유를 첫 라운드에 함께 밝힌다" in sec)
stf = re.sub(r"\n[ \t]*", " ", st_raw)
want("state_sentences",
     "원자료를 찾아 실은 컨텍스트 쌓기의 `S1` 에는 이 블록이 아니라 원자료가 실린다" in stf
     and "이어 갈 때 「풀린 입력」 이 여기서 나온다(끝맺음의 비밀값 확인이" in stf
     and "이어 갈 때 `S1` 이 여기서 나온다" not in stf)

si = flat("skills/context-build/references/seed-input.md")
want("seed_input_s1", "**§6 `S1` 은 seed 가 아니라 원자료다**" in si
     and "「풀린 입력」 원문 그대로다" not in si
     and "원자료: 찾지 못함 — 붙여 넣은 seed" in si)
want("seed_input_paths", "그 dispatch 에는 원자료의 경로도 함께 준다" in si
     and "audit 경로는 `raw_source.py` 의 판결 줄에서 받은 것이다" in si)

rf = flat("skills/intent-sync/SKILL.md")
want("framing_sentence",
     "**컨텍스트 쌓기가 seed 로 시작한 줄 몰라 원자료(framing 기록의 원문 절과 질문 전체 절)가 brief §6 의 첫 칸에 실리지 않습니다.**" in rf
     and "방금 확정한 요청" not in rf)

for name in bad:
    print(name)
ENTRY_WORDS_PY
  fence_fails "$root/skills/context-build/references/state-file.md"
}

EF="$(entry_fails "$SDP")"
[ -z "$EF" ] && ok "entry_fails: 실제 파일 전 항목 통과(펜스 실행 여섯 × 셸 $(echo $SHELLS | wc -w | tr -d ' '))" \
  || no "entry_fails 실패 항목: $(printf '%s' "$EF" | tr '\n' ' ')"

# ── 변이 — 묶음 사본을 만들고 한 자리를 깨 같은 판정에 먹인다 ─────────────────────
n_bundle=0
bundle() { # → 새 사본 폴더 경로
  local b r
  n_bundle=$((n_bundle + 1)); b="$W/bundle$n_bundle"
  for r in $REL_FILES; do mkdir -p "$b/$(dirname "$r")" && cp "$SDP/$r" "$b/$r"; done
  printf '%s\n' "$b"
}
break_at() { # <사본 파일> <찾을 글> <바꿀 글 | --drop-line> — 처음 하나만. 찾지 못하면 rc 1.
  python3 -I -B -c '
import sys
path, needle, repl = sys.argv[1:4]
with open(path, encoding="utf-8") as f:
    text = f.read()
at = text.find(needle)
if at < 0:
    sys.exit(1)
if repl == "--drop-line":
    lo = text.rfind("\n", 0, at) + 1
    hi = text.find("\n", at)
    text = text[:lo] + (text[hi + 1:] if hi >= 0 else "")
else:
    text = text[:at] + repl + text[at + len(needle):]
with open(path, "w", encoding="utf-8") as f:
    f.write(text)
' "$1" "$2" "$3"
}
bites() { # <기대 이름> <사본 폴더> <변이 설명>
  local got
  got="$(entry_fails "$2")"
  if grep -qxF "$1" <<< "$got"; then ok "변이($3) → $1"
  else no "변이($3) 가 $1 로 실패하지 않았다 — 나온 것: $(printf '%s' "$got" | tr '\n' ' ')"; fi
}

B="$(bundle)"
break_at "$B/skills/context-build/SKILL.md" '한 답에 고른 것과 적은 말이 섞였으면 S 둘로 적는다' '' \
  && bites skill_two_s "$B" "S 둘 문장 삭제" || no "변이 준비 실패: skill_two_s"
B="$(bundle)"
break_at "$B/agents/coverage-mapper.md" 'seed 전문(모델이 줄인 글)과' 'seed 전문(S1)과' \
  && bites no_seed_as_s1:agents/coverage-mapper.md "$B" "coverage-mapper 옛 낱말" || no "변이 준비 실패: coverage-mapper"
B="$(bundle)"
break_at "$B/skills/context-build/references/state-file.md" '| `RESUME`(`LEGACY` 를 옮긴 뒤 포함) |' --drop-line \
  && bites state_section "$B" "RESUME 행 삭제" || no "변이 준비 실패: state_section"
B="$(bundle)"
break_at "$B/skills/context-build/references/state-file.md" '진입 인자가 seed 경로였으면(`ASK` 의 「이어 감」 등) `SEED_ABS` 도 채운다' '' \
  && bites state_resume_seed "$B" "RESUME 행의 SEED_ABS 구절 삭제" || no "변이 준비 실패: state_resume_seed"
B="$(bundle)"
break_at "$B/skills/context-build/references/state-file.md" '[ -f "$STATE" ]' --drop-line \
  && bites fence_no_state:bash "$B" "펜스의 상태 파일 확인 줄 삭제" || no "변이 준비 실패: fence_no_state"
B="$(bundle)"
break_at "$B/skills/context-build/references/seed-input.md" '**§6 `S1` 은 seed 가 아니라 원자료다**' '**§6 `S1` 은 「풀린 입력」 원문 그대로다**' \
  && bites seed_input_s1 "$B" "seed-input 옛 S1 문장" || no "변이 준비 실패: seed_input_s1"
B="$(bundle)"
break_at "$B/skills/context-build/references/state-file.md" '--interview "$STATE" --absolute' '--interview "$STATE"' \
  && bites fence_both:bash "$B" "펜스의 --absolute 삭제" || no "변이 준비 실패: fence_both"
B="$(bundle)"
break_at "$B/skills/context-build/references/state-file.md" '아래 「판결 줄이 없다」 갈래대로 간다' '아래 「판결 줄이 없다」 갈래대로 멈춘다' \
  && bites fence_no_verdict:bash "$B" "종료 코드 2 줄을 멈춘다로" || no "변이 준비 실패: fence_no_verdict"
B="$(bundle)"
break_at "$B/skills/context-build/references/state-file.md" '`NEW-SEED` 또는 `ASK` 의 「새로 시작」 — ' '`NEW-SEED` — ' \
  && bites state_section "$B" "ASK 새로 시작 갈래 삭제" || no "변이 준비 실패: state_section(ASK)"
B="$(bundle)"
break_at "$B/skills/context-build/references/state-file.md" '(종료 코드 <n>: <[raw_source] 줄 — 없으면 오류 출력의 마지막 줄>)' '(종료 코드 <n>)' \
  && bites state_no_verdict "$B" "판결 없음 줄의 사유 삭제" || no "변이 준비 실패: state_no_verdict"
B="$(bundle)"
break_at "$B/skills/context-build/references/state-file.md" '"[spec-distill] 판결 종료 코드 ${rc} — 판결 줄이 없다. 아래 「판결 줄이 없다」 갈래대로 간다"' '"[spec-distill] 판결 종료 코드 ${rc} — 위 판결 줄대로 간다(멈추지 않는다)"' \
  && bites fence_crash:bash "$B" "0 · 3 밖의 종료 코드를 옛 「멈추지 않는다」 로" || no "변이 준비 실패: fence_crash"

finish
