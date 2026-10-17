#!/usr/bin/env bash
# R7 §2-2 · §2-4 · §3-2 — 리뷰 진입 펜스의 표지 · 정리 배선 (AC7 · AC8 · AC10 양의 짝).
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
SR="$SD/skills/spec-review/SKILL.md"; RB="$SD/skills/reviewing-brief/SKILL.md"
FIN="$SD/skills/spec-interview/references/finishing.md"

repo="$T/repo"; mkdir -p "$repo/docs" && git -C "$repo" init -q
doc="$repo/docs/a-design.md"; printf '# A\n' > "$doc"
run_open() {   # run_open <sid> → 원장 열기 펜스 출력
  ( cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID="$1" DEVBREW_SPEC_DISTILL_SESSION_ID="$1" \
      bash -c "spec_path='$doc'
$(fence "$SR" ledger-open)" 2>&1 )
}

o1="$(run_open sess-aaaa1111)"
assert_eq "$(printf '%s\n' "$o1" | tail -n 1)" "ledger-open: HELD" "AC8: 빈 원장에서 원장 열기가 표지를 잡는다"
SDIR="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$repo/.claude/spec-distill" --doc "$doc")"
assert_eq "$(cat "$SDIR/reviewing-by")" "sess-aaaa1111" "AC8: 표지가 원장 폴더에 세션 id 한 줄로 선다"
o2="$(run_open sess-bbbb2222)"
assert_eq "$(printf '%s\n' "$o2" | tail -n 1)" "ledger-open: OTHER:sess-aaaa1111" "AC8: 다른 세션의 표지가 있으면 멈추고 그 세션을 댄다"
grep -qF '「그만둠 (권장)」' "$SR" && grep -qF '「이어 씀 — 표지를 내 것으로 바꾼다」' "$SR" \
  && ok "AC8: OTHER 판결이 그만둠/이어 씀 질문으로 간다(문면)" || no "AC8: 표지 질문 문면이 없다"
o3="$(cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" bash -c "unset CLAUDE_CODE_SESSION_ID DEVBREW_SPEC_DISTILL_SESSION_ID; spec_path='$doc'
$(fence "$SR" ledger-open)" 2>&1)"
assert_eq "$(printf '%s\n' "$o3" | tail -n 1)" "ledger-open: NO_SESSION" "§2-4: 세션 id 가 없으면 리뷰를 시작하지 않는다"

# AC7 — 이어 감 줄 두 분기
printf -- '---\ndocreview:\n  doc: %s\n  profile: design-doc\n  round: 2\n---\n# x\n' "$doc" > "$SDIR/docreview-state.md"
python3 "$SD/scripts/ledger_marker.py" release --dir "$SDIR" --session sess-aaaa1111 >/dev/null
o4="$(run_open sess-cccc3333)"
printf '%s\n' "$o4" | grep -qF "[spec-distill] 이전 리뷰 라운드 2 에서 이어 간다 — $SDIR" \
  && ok "AC7: 다른 세션이 이어 받으면 이어 감 줄이 난다" || no "AC7: 이어 감 줄이 없다: $o4"
o5="$(run_open sess-cccc3333)"
printf '%s\n' "$o5" | grep -qF "이전 리뷰 라운드" && no "AC7: 같은 세션의 다음 라운드에서 이어 감 줄이 났다" \
  || ok "AC7: 같은 세션의 다음 라운드에서는 이어 감 줄이 없다"

# AC8 — 넘겨받기 뒤 넘겨준 세션의 쓰기가 멈추고 원장이 그대로다
( cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-dddd4444 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-dddd4444 \
    bash -c "spec_path='$doc'
$(fence "$SR" ledger-takeover)" >/dev/null 2>&1 )
assert_eq "$(cat "$SDIR/reviewing-by")" "sess-dddd4444" "AC8: 「이어 씀」 뒤 표지가 바뀐다"
before="$(cksum < "$SDIR/docreview-state.md")"
guard="$(fence "$SR" ledger-guard)"
( cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-cccc3333 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-cccc3333 \
    bash -c "SD='$SD'; STATE_DIR='$SDIR'; harness_sid=sess-cccc3333
$guard
python3 \"\$SD/scripts/docreview_state.py\" begin-round --state-dir \"\$STATE_DIR\" --snapshot /dev/null" >/dev/null 2>&1 ); rc=$?
assert_eq "$rc" "3" "AC8: 남의 표지 — 쓰기 전 확인이 rc 3 으로 멈춘다"
assert_eq "$(cksum < "$SDIR/docreview-state.md")" "$before" "AC8: 남의 표지 — 원장 파일이 바뀌지 않았다"
# 양의 짝 — 표지 주인은 확인을 지나 다음 명령에 닿는다(확인이 늘 멈추는 것이 아니다)
pos="$(cd "$repo" && bash -c "SD='$SD'; STATE_DIR='$SDIR'; harness_sid=sess-dddd4444
$guard
echo guard-passed" 2>&1)"; rc=$?
{ [ "$rc" -eq 0 ] && [ "$pos" = "guard-passed" ]; } \
  && ok "AC8: 표지 주인 — 쓰기 전 확인을 지나 다음 명령이 돈다(양의 짝)" || no "AC8: 표지 주인인데 확인이 막았다(rc $rc): $pos"
# 끝맺음 펜스 — 남의 표지면 박제 · 계수 · 표시를 하지 않고 표지도 풀지 않는다
adv_out="$(cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-cccc3333 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-cccc3333 \
    bash -c "spec_path='$doc'
$(fence "$SR" advice-display)" 2>&1)"
assert_contains "$adv_out" "표지가 다른 세션 것이다" "AC8: 남의 표지 — 끝맺음 펜스가 참고 목록을 건너뛴다"
assert_eq "$(cksum < "$SDIR/docreview-state.md")" "$before" "AC8: 남의 표지 — 끝맺음 펜스 뒤에도 원장 파일이 그대로다"
assert_eq "$(cat "$SDIR/reviewing-by")" "sess-dddd4444" "AC8: 남의 표지 — 끝맺음 펜스의 해제가 남의 표지를 지우지 않는다"
rm -f "$SDIR/reviewing-by"
( cd "$repo" && bash -c "SD='$SD'; STATE_DIR='$SDIR'; harness_sid=sess-cccc3333
$guard
python3 \"\$SD/scripts/docreview_state.py\" begin-round --state-dir \"\$STATE_DIR\" --snapshot /dev/null" >/dev/null 2>&1 ); rc=$?
assert_eq "$rc" "3" "AC8: 표지 없음 — 쓰기 전 확인이 rc 3 으로 멈춘다"
assert_eq "$(cksum < "$SDIR/docreview-state.md")" "$before" "AC8: 표지 없음 — 원장 파일이 바뀌지 않았다"

# AC8 — 원장에 쓰는 명령마다 같은 펜스 안 앞에 확인이 있다(정적).
WRITERS='docreview_state\.py" (init|begin-round|record-findings|decide|fix|ask|defer|observe-diff|advice)|docreview_route\.py" (prepare-recritic|finalize)|docreview_anchor\.py" check-intent'
GUARDED="$SR $RB $FIN $SD/skills/request-framing/SKILL.md"
ac8_scan() {   # ac8_scan <파일> → rc 0 이면 확인 없는 원장 쓰기가 없다
  python3 -I - "$1" "$WRITERS" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
w = re.compile(sys.argv[2]); g = 'ledger_marker.py" check --dir "$STATE_DIR"'
bad = []
# 플래그 없는 `advice` 는 읽기 전용이다(목록 JSON 만 낸다). 허용 목록으로만 뺀다 — argparse 는 접두 약어
# (`--rend` · `--sin` · `--log-f`)를 받으므로 쓰는 플래그를 이름으로 막으면 샌다. `advice` 뒤가 정확히
# `--state-dir <인자 하나>` 와 선택적 `>`/`2>` 넘기기뿐이고(인자는 따옴표 안 `$이름` 이나 맨 글자 — 따옴표 밖
# `$` · `$(` · 백틱 불가), 줄이 `\` 로 이어지면 다음 줄이 `||` 로 시작하며, 이어진 명령의 쓰기 명령이 전부
# `advice` 일 때만 뺀다.
ARG = r'(?:"(?:[^"$`\\]|\$\{?[A-Za-z_][A-Za-z0-9_]*\}?)*"|\'[^\']*\'|[A-Za-z0-9_./-]+)'
# 넘기는 자리(명령 뒤 · 명령 앞 모두)는 같은 펜스에서 `이름="$(mktemp …)"` 로 만든 이름의 `"$이름"` 꼴만 받는다 —
# 그 밖(글자 경로 · 다른 변수 · STATE_DIR 이 든 자리 · 따옴표 없음)은 예외에서 빠진다.
def ro_for(names):
    tgt = r'"\$(?:' + "|".join(map(re.escape, names)) + r')"' if names else r'(?!)'
    return re.compile(r'\s+--state-dir\s+' + ARG + r'(?:\s+2?>\s*' + tgt + r')?(?:\s+\\)?\s*'), tgt
for body in re.findall(r"^```bash\n(.*?)^```$", text, re.S | re.M):
    lines = body.splitlines()
    names = re.findall(r'^\s*([A-Za-z_][A-Za-z0-9_]*)=(?:"\$\(|\$\()\s*mktemp\b', body, re.M)
    ro, tgt = ro_for(names)
    for i, line in enumerate(lines):
        if not w.search(line) or g in "\n".join(lines[:i]):
            continue
        j, cmd = i, line
        while cmd.rstrip().endswith("\\") and j + 1 < len(lines):
            j += 1; cmd = cmd + "\n" + lines[j]
        m = re.search(r'docreview_state\.py" advice(.*)$', line)
        cont_ok = not line.rstrip().endswith("\\") or (i + 1 < len(lines) and lines[i + 1].lstrip().startswith("||"))
        pre = line[:m.start()] if m else ""
        pre_ok = all(re.match(r'>\s*' + tgt, pre[k:]) is not None and (k == 0 or pre[k-1] in '2 \t') for k in [x.start() for x in re.finditer('>', pre)])
        if (m and pre_ok and ro.fullmatch(m.group(1)) and cont_ok
                and all(x.group(0).endswith('" advice') for x in w.finditer(cmd))):
            continue
        bad.append(line.strip()[:120])
print("\n".join(bad), file=sys.stderr)
sys.exit(1 if bad else 0)
PY
}
for f in $GUARDED; do
  ac8_scan "$f" && ok "AC8: $(basename "$(dirname "$f")")/$(basename "$f") — 원장 쓰기 명령 앞에 확인이 있다" || no "AC8: $f — 확인 없는 원장 쓰기"
done
# AC8 읽기 전용 예외의 양성 짝 — 쓰는 플래그가 붙은 advice(이어진 줄 포함)와 같은 줄의 다른 쓰기 명령은 여전히 잡힌다.
ac8f="$T/ac8-probe.md"
for probe in 'python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" --render' \
             'python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" \
  --sink "$spec_path"' \
             'python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" > x; python3 "$SD/scripts/docreview_state.py" decide --state-dir "$STATE_DIR"' \
             'python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" --rend' \
             'python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" --sin "$spec_path"' \
             'python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" --log-f "$AUDIT"' \
             'python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" $ADV_FLAGS' \
             'python3 "$SD/scripts/docreview_state.py" advice --state-dir $STATE_DIR' \
             'python3 "$SD/scripts/docreview_state.py" advice --state-dir "$(echo "$STATE_DIR")"' \
             'python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" > "$STATE_DIR/advice-all.json"' \
             'python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" > "${STATE_DIR}/advice-all.json"' \
             'python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" 2> $STATE_DIR/err' \
             'OUT=$STATE_DIR/x
python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" > "$OUT"' \
             'OUT="$STATE_DIR/x"
python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" > "$OUT"' \
             '> "$STATE_DIR/x" python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR"' \
             'OUT="$(mktemp)"
> "$STATE_DIR/x" python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" > "$OUT"' \
             'python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" > /tmp/x'; do
  printf '```bash\n%s\n```\n' "$probe" > "$ac8f"
  ac8_scan "$ac8f" 2>/dev/null && no "AC8 예외 양성 짝: 확인 없는 쓰기가 예외로 빠졌다: $probe" || ok "AC8 예외 양성 짝: 확인 없는 쓰기는 잡힌다 — $(printf '%s' "$probe" | head -n 1 | cut -c 40-100)"
done
# 예외 — 「참고 전부 보기」 펜스의 바로 그 꼴(넘기기 + `\` 로 이어진 `|| { … }`)
printf '```bash\n%s\n```\n' 'adv_all="$(mktemp "${TMPDIR:-/tmp}/x.XXXXXX")" \
  || { echo "임시 파일 실패"; exit 0; }
python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" > "$adv_all" \
  || { rm -f "$adv_all"; echo "실패"; exit 0; }' > "$ac8f"
ac8_scan "$ac8f" 2>/dev/null && ok "AC8 예외: 플래그 없는 advice(읽기 전용)는 확인 없이 둘 수 있다" || no "AC8 예외: 플래그 없는 advice 가 쓰기로 잡혔다"

# AC8 — 해제는 게이트 응답 기록 뒤(문면 순서) · 끝맺음 펜스가 release 로 끝난다
adv="$(fence "$SR" advice-display)"
printf '%s\n' "$adv" | grep -qF 'ledger_marker.py" acquire' && printf '%s\n' "$adv" | tail -n 3 | grep -qF 'ledger_marker.py" release' \
  && ok "AC8: spec-review 끝맺음 펜스가 acquire 로 시작해 release 로 끝난다" || no "AC8: spec-review 끝맺음 펜스 꼴"
python3 -I - "$SR" <<'PY' && ok "AC8: 해제가 finalize · 게이트 응답 반영 뒤에 온다(문면 순서)" || no "AC8: 해제 문면 순서"
import sys
t = open(sys.argv[1], encoding="utf-8").read()
a = t.find("응답을 `decide`·`fix`·`ask` 서브커맨드로 반영한다"); r = t.find("<!-- advice-display:begin -->")
sys.exit(0 if 0 <= a < r else 1)
PY
finb="$(fence "$FIN" advice-ba)"
printf '%s\n' "$finb" | tail -n 3 | grep -qF 'ledger_marker.py" release' && ok "AC8: finishing B-A 가 release 로 끝난다" || no "AC8: finishing B-A 해제 없음"
grep -qF 'ledger_marker.py" release' "$RB" && no "AC8: reviewing-brief 가 스스로 표지를 푼다(B-A 가 푼다)" || ok "AC8: reviewing-brief 는 표지를 풀지 않는다"

# AC10 양의 짝 — 리뷰 진입 셋이 ledger_sweep.py 를 부른다.
SWEEPERS="$SR $RB $SD/skills/request-framing/SKILL.md"
for f in $SWEEPERS; do
  fence "$f" ledger-open | grep -qF 'ledger_sweep.py" --root "$ROOT"' && ok "AC10: $(basename "$(dirname "$f")") 원장 열기가 정리를 부른다" || no "AC10: $f 정리 호출 없음"
done

# ── 보충 A1 — 정리는 mkdir · acquire 앞에서, 같은 세션의 다음 라운드에서는 건너뛴다 ───────────────
age() {   # age <경로> → 그 경로와 아래 전부의 mtime 을 48시간 전으로
  python3 -I - "$1" <<'PY'
import os, sys, time
when = time.time() - 48 * 3600
for dp, dns, fns in os.walk(sys.argv[1]):
    for n in dns + fns:
        os.utime(os.path.join(dp, n), (when, when), follow_symlinks=False)
os.utime(sys.argv[1], (when, when))
PY
}
open_at() {   # open_at <repo> <문서> <sid> <skill 파일> → 원장 열기 펜스 출력(spec_path · PAYLOAD 둘 다 문서)
  ( cd "$1" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID="$3" DEVBREW_SPEC_DISTILL_SESSION_ID="$3" \
      bash -c "spec_path='$2'; PAYLOAD='$2'
$(fence "$4" ledger-open)" 2>&1 )
}
ledger() {   # ledger <파일> <문서> <라운드>
  printf -- '---\ndocreview:\n  doc: %s\n  profile: design-doc\n  round: %s\n---\n# x\n' "$2" "$3" > "$1"
}

# (i) 올린 뒤 첫 리뷰 — 같은 문서의 옛 원장이 원장 열기에서 .docreview 로 옮겨진다
r2="$T/repo2"; mkdir -p "$r2/docs" && git -C "$r2" init -q
d2="$r2/docs/b-design.md"; printf '# B\n' > "$d2"
R2="$r2/.claude/spec-distill"; mkdir -p "$R2/oldsess0001/docreview/k1"
ledger "$R2/oldsess0001/docreview/k1/docreview-state.md" "$d2" 1
printf 'x\n' > "$R2/oldsess0001/interview-basename"   # 직속 파일 — 옛 세션의 모양(ctime 은 되돌릴 수 없어 빈 폴더 유예 창을 비켜 간다)
age "$R2/oldsess0001"
S2="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$R2" --doc "$d2")"
oi="$(open_at "$r2" "$d2" sess-eeee5555 "$SR")"
assert_eq "$(printf '%s\n' "$oi" | tail -n 1)" "ledger-open: HELD" "A1(i): 옛 원장이 있는 첫 리뷰도 표지를 잡는다"
[ -f "$S2/docreview-state.md" ] && grep -qF "doc: $d2" "$S2/docreview-state.md" \
  && ok "A1(i): 같은 문서의 옛 원장이 .docreview/<키> 로 옮겨졌다(정리가 mkdir · acquire 보다 먼저 돈다)" \
  || no "A1(i): 옛 원장이 옮겨지지 않았다: $oi"
[ -d "$R2/oldsess0001" ] && no "A1(i): 옛 세션 폴더가 남았다" || ok "A1(i): 옮긴 뒤 옛 세션 폴더가 걷혔다"
assert_contains "$oi" "이전 리뷰 라운드 1 에서 이어 간다 — $S2" "A1(i): 옮겨진 원장에서 이어 감 줄이 난다"
assert_not_contains "$oi" "읽지 못한 원장" "A1(i): 막 연 자리가 「읽지 못한 원장」 으로 보고되지 않는다"

# (ii) 같은 세션의 다음 라운드는 정리를 건너뛰고, 다른 세션의 진입은 정리를 부른다
mkdir -p "$R2/.docreview/zz-0000000000000000"
ledger "$R2/.docreview/zz-0000000000000000/docreview-state.md" "$T/nope-design.md" 1
age "$R2/.docreview/zz-0000000000000000"
oii="$(open_at "$r2" "$d2" sess-eeee5555 "$SR")"
assert_eq "$(printf '%s\n' "$oii" | tail -n 1)" "ledger-open: HELD" "A1(ii): 같은 세션의 다음 라운드 — HELD"
[ -d "$R2/.docreview/zz-0000000000000000" ] && ok "A1(ii): 같은 세션의 다음 라운드는 정리를 부르지 않는다(문서 없는 원장이 남는다)" \
  || no "A1(ii): 같은 세션의 다음 라운드에서 정리가 돌았다"
oiii="$(open_at "$r2" "$d2" sess-ffff6666 "$SR")"
assert_eq "$(printf '%s\n' "$oiii" | tail -n 1)" "ledger-open: OTHER:sess-eeee5555" "A1(ii): 다른 세션 — OTHER"
[ -d "$R2/.docreview/zz-0000000000000000" ] && no "A1(ii): 다른 세션의 진입이 정리를 부르지 않았다" \
  || ok "A1(ii): 다른 세션의 진입은 표지 판결 전에 정리를 부른다(문서 없는 원장이 걷혔다)"

# (iii) .docreview 가 밖을 가리키는 링크면 원장 자리를 만들지 않는다
r3="$T/repo3"; mkdir -p "$r3/docs" && git -C "$r3" init -q
d3="$r3/docs/c-design.md"; printf '# C\n' > "$d3"
outside="$T/outside"; mkdir -p "$outside" "$r3/.claude/spec-distill"
ln -s "$outside" "$r3/.claude/spec-distill/.docreview"
for f in "$SR" "$RB"; do
  o="$(open_at "$r3" "$d3" sess-gggg7777 "$f")"
  assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: NO_DIR" "A1(iii): $(basename "$(dirname "$f")") — 링크된 .docreview 면 NO_DIR"
  assert_eq "$(ls -A "$outside")" "" "A1(iii): $(basename "$(dirname "$f")") — 링크 너머 폴더가 비어 있다"
done
# 상태 루트(.claude/spec-distill) 자신이 밖을 가리키는 링크여도 같다
outside2="$T/outside2"; mkdir -p "$outside2"
mv "$r3/.claude/spec-distill" "$T/r3-root-saved"; ln -s "$outside2" "$r3/.claude/spec-distill"
o="$(open_at "$r3" "$d3" sess-gggg7777 "$SR")"
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: NO_DIR" "A1(iii): 상태 루트가 링크면 NO_DIR"
assert_eq "$(ls -A "$outside2")" "" "A1(iii): 상태 루트 링크 너머 폴더가 비어 있다"
rm -f "$r3/.claude/spec-distill"; mv "$T/r3-root-saved" "$r3/.claude/spec-distill"
# 양성 대조 — 링크를 걷으면 같은 진입이 표지를 잡는다(위 NO_DIR 이 상시 실패가 아니다)
rm -f "$r3/.claude/spec-distill/.docreview"
o="$(open_at "$r3" "$d3" sess-gggg7777 "$SR")"
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: HELD" "A1(iii) 양성 대조: 링크가 없으면 HELD"

# reviewing-brief 원장 열기도 실제로 돈다 — HELD · OTHER
d4="$repo/docs/b-brief.md"; printf '# brief\n' > "$d4"
ob1="$(open_at "$repo" "$d4" sess-aaaa1111 "$RB")"
assert_eq "$(printf '%s\n' "$ob1" | tail -n 1)" "ledger-open: HELD" "AC8: reviewing-brief 원장 열기가 표지를 잡는다"
ob2="$(open_at "$repo" "$d4" sess-bbbb2222 "$RB")"
assert_eq "$(printf '%s\n' "$ob2" | tail -n 1)" "ledger-open: OTHER:sess-aaaa1111" "AC8: reviewing-brief — 남의 표지면 OTHER"

# ── fix 1 ─────────────────────────────────────────────────────────────────────
# (1) HELD 가 아닌 판결은 펜스를 rc 3 으로 끝내 같은 호출의 뒤 명령(절차서 선결의 mkdir)이 돌지 않는다
rm -rf "$r3/.claude/spec-distill/.docreview"   # 위 양성 대조가 진짜 폴더를 만들었다 — ln 이 그 안에 링크를 놓지 않게
ln -s "$outside" "$r3/.claude/spec-distill/.docreview"
[ -L "$r3/.claude/spec-distill/.docreview" ] && ok "fix1(1) 전제: .docreview 가 링크다" || no "fix1(1) 전제: .docreview 가 링크가 아니다 — 아래 칸이 공허하다"
for f in "$SR" "$RB"; do
  o="$(cd "$r3" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-gggg7777 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-gggg7777 \
      bash -c "spec_path='$d3'; PAYLOAD='$d3'
$(fence "$f" ledger-open)
mkdir -p \"\$STATE_DIR\"; echo after-fence-ran" 2>&1)"; rc=$?
  nm="$(basename "$(dirname "$f")")"
  assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: NO_DIR" "fix1(1): $nm — 뒤에 선결 mkdir 를 이어 붙여도 마지막 줄이 NO_DIR"
  assert_eq "$rc" "3" "fix1(1): $nm — NO_DIR 판결이 호출을 rc 3 으로 끝낸다"
  assert_eq "$(ls -A "$outside")" "" "fix1(1): $nm — 이어 붙인 mkdir 가 링크 너머에 원장 자리를 만들지 않았다"
done
rm -f "$r3/.claude/spec-distill/.docreview"
o="$(cd "$r3" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-gggg7777 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-gggg7777 \
    bash -c "spec_path='$d3'
$(fence "$SR" ledger-open)
echo after-fence-ran" 2>&1)"; rc=$?
{ [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$o" | tail -n 1)" = "after-fence-ran" ]; } \
  && ok "fix1(1) 양성 대조: HELD 면 같은 호출의 뒤 명령이 돈다" || no "fix1(1) 양성 대조: HELD 인데 뒤 명령이 돌지 않았다(rc $rc): $o"

# (2) 쓰기 전 확인 — 표지 없음은 원장 열기로, 남의 표지는 「이어 씀」 으로 안내한다
d9="$repo/docs/g-design.md"; printf '# G\n' > "$d9"
S9="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$repo/.claude/spec-distill" --doc "$d9")"; mkdir -p "$S9"
for f in "$SR" "$RB"; do
  g="$(fence "$f" ledger-guard)"; nm="$(basename "$(dirname "$f")")"
  rm -f "$S9/reviewing-by"
  out="$(bash -c "SD='$SD'; PR='$SD'; STATE_DIR='$S9'; harness_sid=sess-cccc3333
$g
echo wrote" 2>&1)"; rc=$?
  { [ "$rc" -eq 3 ] && assert_contains "$out" "원장 열기 펜스(ledger-open)를 먼저 다시 돌려라" "fix1(2): $nm — 표지 없음이면 원장 열기를 다시 돌리라고 한다"; } \
    || no "fix1(2): $nm — 표지 없음에서 rc $rc"
  assert_not_contains "$out" "「이어 씀」" "fix1(2): $nm — 표지 없음에서 「이어 씀」 을 안내하지 않는다"
  printf 'sess-dddd4444\n' > "$S9/reviewing-by"
  out="$(bash -c "SD='$SD'; PR='$SD'; STATE_DIR='$S9'; harness_sid=sess-cccc3333
$g
echo wrote" 2>&1)"; rc=$?
  { [ "$rc" -eq 3 ] && assert_contains "$out" "「이어 씀」" "fix1(2): $nm — 남의 표지면 「이어 씀」 을 안내한다"; } \
    || no "fix1(2): $nm — 남의 표지에서 rc $rc"
  assert_not_contains "$out" "wrote" "fix1(2): $nm — 남의 표지에서 뒤 명령이 돌지 않았다"
done

# (3) 해제가 실제로 돈다 — 끝맺음 펜스 둘과 해제 펜스
d6="$repo/docs/e-design.md"; printf '# E\n' > "$d6"
o="$(open_at "$repo" "$d6" sess-hhhh8888 "$SR")"
S6="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$repo/.claude/spec-distill" --doc "$d6")"
ledger "$S6/docreview-state.md" "$d6" 1
assert_eq "$(cat "$S6/reviewing-by" 2>/dev/null)" "sess-hhhh8888" "fix1(3): finalize 뒤(끝맺음 펜스 전)에는 표지가 남아 있다"
( cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-hhhh8888 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-hhhh8888 \
    bash -c "spec_path='$d6'
$(fence "$SR" advice-display)" >/dev/null 2>&1 )
[ -e "$S6/reviewing-by" ] && no "fix1(3): spec-review 끝맺음 펜스 뒤에도 표지가 남았다" || ok "fix1(3): spec-review 끝맺음 펜스 뒤 표지가 사라졌다"
assert_eq "$(cat "$S6/last-session" 2>/dev/null)" "sess-hhhh8888" "fix1(3): spec-review 끝맺음 펜스가 last-session 에 자기 세션을 남겼다"

d7="$repo/docs/f-brief.md"; printf '# F\n' > "$d7"
o="$(open_at "$repo" "$d7" sess-iiii9999 "$RB")"
S7="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$repo/.claude/spec-distill" --doc "$d7")"
ledger "$S7/docreview-state.md" "$d7" 1
assert_eq "$(cat "$S7/reviewing-by" 2>/dev/null)" "sess-iiii9999" "fix1(3): B-A 전에는 reviewing-brief 가 잡은 표지가 남아 있다"
ba="$(fence "$FIN" advice-ba | python3 -I -c 'import sys; t = sys.stdin.buffer.read().decode("utf-8"); k = "<Step A.5 의 PAYLOAD 절대경로>"; sys.stdout.buffer.write(t.replace(k, sys.argv[1]).encode("utf-8")); sys.exit(0 if k in t else 1)' "$d7")" \
  && ok "fix1(3): B-A 펜스의 PAYLOAD 자리표를 픽스처 경로로 바꿨다" || no "fix1(3): B-A 펜스에 PAYLOAD 자리표가 없다 — 아래 칸이 공허하다"
( cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-iiii9999 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-iiii9999 \
    bash -c "$ba" >/dev/null 2>&1 )
[ -e "$S7/reviewing-by" ] && no "fix1(3): finishing B-A 뒤에도 표지가 남았다" || ok "fix1(3): finishing B-A 뒤 표지가 사라졌다"
assert_eq "$(cat "$S7/last-session" 2>/dev/null)" "sess-iiii9999" "fix1(3): finishing B-A 가 last-session 에 자기 세션을 남겼다"

# 보안 — B-A 는 payload 짝 audit 가 링크면 audit 에 쓰지 않는다(엔진 advice --log-file 이 링크를 따라간다)
d9="$repo/docs/g-brief.md"; printf '# G\n' > "$d9"
o="$(open_at "$repo" "$d9" sess-iiii9999 "$RB")"
S9="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$repo/.claude/spec-distill" --doc "$d9")"
ledger "$S9/docreview-state.md" "$d9" 1
printf 'victim\n' > "$T/ba-victim"; ln -s "$T/ba-victim" "$repo/docs/g-brief.audit.md"
before9="$(cksum < "$S9/docreview-state.md")"
ba9="$(fence "$FIN" advice-ba | python3 -I -c 'import sys; t = sys.stdin.buffer.read().decode("utf-8"); k = "<Step A.5 의 PAYLOAD 절대경로>"; sys.stdout.buffer.write(t.replace(k, sys.argv[1]).encode("utf-8"))' "$d9")"
o="$(cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-iiii9999 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-iiii9999 bash -c "$ba9" 2>&1)"
assert_contains "$o" "참고(advisory) 목록 건너뜀 — brief · audit · 상태 파일 중 링크를 거치거나" "보안: B-A — 짝 audit 가 링크면 참고 목록을 건너뛰고 사유를 보인다"
assert_eq "$(cat "$T/ba-victim")" "victim" "보안: B-A — 링크 너머 파일은 그대로다"
assert_eq "$(cksum < "$S9/docreview-state.md")" "$before9" "보안: B-A — 링크 칸에서 원장도 그대로다"
rm -f "$repo/docs/g-brief.audit.md"
# 보안 — payload 의 폴더가 저장소 밖(git 아님) 폴더로 가는 링크면 B-A 가 audit 에 쓰지 않는다
mkdir -p "$T/ba-out"; printf '# GL\n' > "$T/ba-out/gl-brief.md"; printf 'audit-victim\n' > "$T/ba-out/gl-brief.audit.md"
ln -s "$T/ba-out" "$repo/docs/balink"
dl="$repo/docs/balink/gl-brief.md"
bal="$(fence "$FIN" advice-ba | python3 -I -c 'import sys; t = sys.stdin.buffer.read().decode("utf-8"); k = "<Step A.5 의 PAYLOAD 절대경로>"; sys.stdout.buffer.write(t.replace(k, sys.argv[1]).encode("utf-8"))' "$dl")"
o="$(cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-iiii9999 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-iiii9999 bash -c "$bal" 2>&1)"
assert_contains "$o" "참고(advisory) 목록 건너뜀 — brief · audit · 상태 파일 중 링크를 거치거나" "보안: B-A — payload 폴더가 git 아닌 밖으로 가는 링크면 건너뛴다"
assert_contains "$o" "링크를 거친다" "보안: B-A — payload-root 의 사유를 보인다"
assert_eq "$(cat "$T/ba-out/gl-brief.audit.md")" "audit-victim" "보안: B-A — 폴더 링크 너머 audit 는 그대로다"
rm -f "$repo/docs/balink"

# M3 — 표지를 확인하지 못한 것(rc 2)은 남의 표지(rc 3)와 다른 말로 알린다. 표지 자리에 심은 링크가 rc 2 를 낸다.
printf 'marker-victim\n' > "$T/mk-victim"
d11="$repo/docs/k-design.md"; printf '# K\n' > "$d11"
o="$(open_at "$repo" "$d11" sess-mmmm3333 "$SR")"
S11="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$repo/.claude/spec-distill" --doc "$d11")"
ledger "$S11/docreview-state.md" "$d11" 1
rm -f "$S11/reviewing-by"; ln -s "$T/mk-victim" "$S11/reviewing-by"
o="$(cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-mmmm3333 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-mmmm3333 \
    bash -c "spec_path='$d11'
$(fence "$SR" advice-display)" 2>&1)"
assert_contains "$o" "표지를 확인하지 못했다(rc 2) — 원장 쓰기를 하지 않는다" "M3: spec-review 끝맺음 — rc 2 는 「표지를 확인하지 못했다」"
assert_not_contains "$o" "표지가 다른 세션 것이다" "M3: spec-review 끝맺음 — rc 2 를 남의 표지로 말하지 않는다"
d12="$repo/docs/l-brief.md"; printf '# L\n' > "$d12"
o="$(open_at "$repo" "$d12" sess-mmmm3333 "$RB")"
S12="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$repo/.claude/spec-distill" --doc "$d12")"
ledger "$S12/docreview-state.md" "$d12" 1
rm -f "$S12/reviewing-by"; ln -s "$T/mk-victim" "$S12/reviewing-by"
ba12="$(fence "$FIN" advice-ba | python3 -I -c 'import sys; t = sys.stdin.buffer.read().decode("utf-8"); k = "<Step A.5 의 PAYLOAD 절대경로>"; sys.stdout.buffer.write(t.replace(k, sys.argv[1]).encode("utf-8"))' "$d12")"
o="$(cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-mmmm3333 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-mmmm3333 bash -c "$ba12" 2>&1)"
assert_contains "$o" "표지를 확인하지 못했다(rc 2) — 원장 쓰기를 하지 않는다" "M3: finishing B-A — rc 2 는 「표지를 확인하지 못했다」"
assert_not_contains "$o" "표지가 다른 세션 것이다" "M3: finishing B-A — rc 2 를 남의 표지로 말하지 않는다"
[ -e "$S12/advice-list.json" ] && no "M3: finishing B-A — rc 2 인데 원장 자리에 참고 목록을 썼다" || ok "M3: finishing B-A — rc 2 면 원장 자리에 쓰지 않는다"
assert_eq "$(cat "$T/mk-victim")" "marker-victim" "M3: 심은 표지 링크 너머는 그대로다"

d8="$repo/docs/h-design.md"; printf '# H\n' > "$d8"
o="$(open_at "$repo" "$d8" sess-jjjj0000 "$SR")"
S8="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$repo/.claude/spec-distill" --doc "$d8")"
run_release() {   # run_release <sid>
  ( cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID="$1" DEVBREW_SPEC_DISTILL_SESSION_ID="$1" \
      bash -c "spec_path='$d8'
$(fence "$SR" ledger-release)" >/dev/null 2>&1 )
}
run_release sess-kkkk1111
assert_eq "$(cat "$S8/reviewing-by" 2>/dev/null)" "sess-jjjj0000" "fix1(3): 해제 펜스 — 남의 표지는 지우지 않는다"
run_release sess-jjjj0000
[ -e "$S8/reviewing-by" ] && no "fix1(3): 해제 펜스 — 주인이 불러도 표지가 남았다" || ok "fix1(3): 해제 펜스 — 주인이 부르면 표지가 사라진다"
assert_eq "$(cat "$S8/last-session" 2>/dev/null)" "sess-jjjj0000" "fix1(3): 해제 펜스 — last-session 에 주인 세션을 남겼다"

# (4) 표지 내용은 판결 줄에 그대로 실리지 않는다 — 두 줄 표지가 HELD 를 위조하지 못한다
d10="$repo/docs/i-design.md"; printf '# I\n' > "$d10"
S10="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$repo/.claude/spec-distill" --doc "$d10")"; mkdir -p "$S10"
printf 'sess-zzzz9999\nledger-open: HELD\n' > "$S10/reviewing-by"
for f in "$SR" "$RB"; do
  o="$(open_at "$repo" "$d10" sess-llll2222 "$f")"
  assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: OTHER:(알 수 없는 표지)" "fix1(4): $(basename "$(dirname "$f")") — 두 줄 표지는 OTHER:(알 수 없는 표지)"
done

# ── Task 8 — request-framing: 이름 파일 없이 audit 의 session_id 로 이름을 되찾고, 원장 배선은 위와 같다 ──────
RF="$SD/skills/request-framing/SKILL.md"
grep -qF 'interview-basename' "$RF" && no "AC11: request-framing 에 interview-basename 이 남았다" || ok "AC11: interview-basename 이 없다"
grep -qF 'interview_state.py" seed-audit-for-session --session "$sid"' "$RF" \
  && ok "AC11 양의 짝: audit session_id 로 이름을 되찾는다" || no "AC11: 이름 되찾기 호출이 없다"
grep -qE '^STATE="\$ROOT/\$sid/state\.local\.md"' "$RF" && no "§1-6: request-framing 의 세션 STATE 줄이 남았다" || ok "§1-6: 세션 STATE 줄이 없다"
# 상태 블록 실행 — 같은 세션 seed audit 둘이면 이름을 만들지 않는다
blk="$(awk '/^## 상태/{f=1} f&&/^```bash$/{c=1;next} c&&/^```$/{exit} c' "$RF")"
rfr="$T/rf"; mkdir -p "$rfr/docs/superpowers/interview" && git -C "$rfr" init -q
for n in a b; do printf -- '---\ntype: interview-seed-audit\nsession_id: sess-rf000001\n---\n' > "$rfr/docs/superpowers/interview/2026-10-15-$n-interview.audit.md"; done
out="$(cd "$rfr" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-rf000001 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-rf000001 bash -c "$blk
echo \"SEED=[\$SEED]\"" 2>&1)"
printf '%s\n' "$out" | grep -qF 'SEED=[]' && ok "AC11: 같은 세션 seed audit 이 둘이면 이름을 만들지 않는다" || no "AC11: 둘 이상에서 이름을 골랐다: $out"
assert_contains "$out" "seed audit 이 둘 이상이다(위 경로들) — 이름을 고르지 않고 멈춘다" "AC11: 둘 이상이면 상태 블록이 멈춘 이유를 댄다"
# TOPIC 을 실값으로 바꿔 둔 블록도 둘 이상에서 TOPIC 으로 새 이름을 만들지 않는다
out="$(cd "$rfr" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-rf000001 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-rf000001 bash -c "$(printf '%s\n' "$blk" | sed 's/^TOPIC="<kebab-topic>"$/TOPIC="rfz"/')
echo \"SEED=[\$SEED]\"" 2>&1)"
printf '%s\n' "$out" | grep -qF 'SEED=[]' && ok "AC11: 둘 이상이면 TOPIC 이 있어도 새 이름을 만들지 않는다" || no "AC11: 둘 이상에서 TOPIC 으로 새 이름을 만들었다: $out"
rm -f "$rfr/docs/superpowers/interview/2026-10-15-b-interview.audit.md"
out="$(cd "$rfr" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-rf000001 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-rf000001 bash -c "$blk
echo \"SEED=[\$SEED]\"" 2>&1)"
printf '%s\n' "$out" | grep -qF 'SEED=[docs/superpowers/interview/2026-10-15-a-interview.md]' \
  && ok "AC11: 하나면 그 이름을 되찾는다" || no "AC11: 이름을 되찾지 못했다: $out"
# 같은 세션의 인터뷰 audit(type 이 다르다)은 이름 되찾기에 걸리지 않는다 — TOPIC 이 자리표면 이름이 없다
printf -- '---\ntype: interview-audit\nsession_id: sess-rf000002\n---\n' > "$rfr/docs/superpowers/interview/2026-10-15-c-interview.audit.md"
out="$(cd "$rfr" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-rf000002 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-rf000002 bash -c "$blk
echo \"SEED=[\$SEED]\"" 2>&1)"
printf '%s\n' "$out" | grep -qF 'SEED=[]' && ok "AC11: 같은 세션의 인터뷰 audit 으로 이름을 되찾지 않는다" || no "AC11: 인터뷰 audit 이 이름 되찾기에 걸렸다: $out"
[ -e "$rfr/.claude/spec-distill" ] && no "§2-5: 상태 블록이 .claude/spec-distill 아래에 무언가를 만들었다: $(ls -A "$rfr/.claude/spec-distill")" \
  || ok "§2-5: 상태 블록은 세션 폴더를 만들지 않는다"

# 펜스 실행 도구 — 상태 블록(TOPIC 을 픽스처 주제로)을 앞에 이어 붙인다. 두 세션 다 같은 날 · 같은 주제로 같은 seed 를 가리킨다.
blkT="$(printf '%s\n' "$blk" | sed 's/^TOPIC="<kebab-topic>"$/TOPIC="rfx"/')"
printf '%s\n' "$blkT" | grep -qx 'TOPIC="rfx"' && ok "전제: 상태 블록의 TOPIC 자리표를 픽스처 주제로 바꿨다" || no "전제: TOPIC 줄 모양이 바뀌었다 — 아래 칸이 공허하다"
RFO="$(fence "$RF" ledger-open)"
[ -n "$RFO" ] && ok "전제: request-framing 원장 열기 펜스가 있다" || no "전제: request-framing 원장 열기 펜스가 없다 — 아래 칸이 공허하다"
rf_run() {   # rf_run <repo> <sid> <이어 붙일 스크립트> → 출력(rc 는 호출의 rc)
  ( cd "$1" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID="$2" DEVBREW_SPEC_DISTILL_SESSION_ID="$2" bash -c "$blkT
$3" 2>&1 )
}
rf_repo() {   # rf_repo <dir> → seed 하나를 둔 git 저장소를 만들고 그 seed 의 절대경로를 낸다
  mkdir -p "$1/docs/superpowers/interview" && git -C "$1" init -q
  printf -- '---\ntype: interview-seed\n---\n\n본문.\n' > "$1/docs/superpowers/interview/$(date +%F)-rfx-interview.md"
  printf '%s\n' "$1/docs/superpowers/interview/$(date +%F)-rfx-interview.md"
}
bash_with() {   # bash_with <파일> <고정 문자열> → 그 문자열을 담은 첫 bash 펜스
  awk -v pat="$2" '/^```bash$/ {b=1; buf=""; next} b && /^```$/ {b=0; if (!done && index(buf, pat)) {printf "%s", buf; done=1}; next} b {buf = buf $0 "\n"}' "$1"
}

rf1="$T/rf1"; sd1="$(rf_repo "$rf1")"
RS1="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$rf1/.claude/spec-distill" --doc "$sd1")"
o="$(rf_run "$rf1" sess-rfaa0001 "$RFO")"
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: HELD" "T8: request-framing 원장 열기가 빈 원장에서 표지를 잡는다"
assert_eq "$(cat "$RS1/reviewing-by" 2>/dev/null)" "sess-rfaa0001" "T8: 표지가 seed 의 원장 폴더에 선다"
o="$(rf_run "$rf1" sess-rfbb0002 "$RFO")"
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: OTHER:sess-rfaa0001" "T8: 다른 세션 — OTHER 로 멈춘다"
grep -qF '「그만둠 (권장)」' "$RF" && grep -qF '「이어 씀 — 표지를 내 것으로 바꾼다」' "$RF" \
  && ok "T8: OTHER 판결이 그만둠/이어 씀 질문으로 간다(문면)" || no "T8: request-framing 표지 질문 문면이 없다"
grep -qF '`OTHER:(알 수 없는 표지)`' "$RF" && ok "T8: 판결 표에 OTHER:(알 수 없는 표지) 가 있다" || no "T8: 판결 표에 알 수 없는 표지 칸이 없다"
o="$(cd "$rf1" && CLAUDE_PLUGIN_ROOT="$SD" bash -c "unset CLAUDE_CODE_SESSION_ID DEVBREW_SPEC_DISTILL_SESSION_ID
$blkT
$RFO" 2>&1)"
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: NO_SESSION" "T8: 세션 id 가 없으면 NO_SESSION"
# 쓰기 전 확인 — 펜스와 실제 원장 쓰기 펜스(처분 · 답 기록)
ledger "$RS1/docreview-state.md" "$sd1" 1
printf -- '---\ntype: interview-seed-audit\nsession_id: sess-rfaa0001\n---\n\n## 6. 리뷰 결정\n' > "$rf1/docs/superpowers/interview/$(date +%F)-rfx-interview.audit.md"
RG="$(fence "$RF" ledger-guard)"
printf '%s\n' "$RG" | grep -qF 'ledger_marker.py" check --dir "$STATE_DIR" --session "$sid"' \
  && ok "T8: request-framing 쓰기 전 확인이 \$sid 로 잰다" || no "T8: request-framing 쓰기 전 확인 펜스 꼴: $RG"
rs1b="$(cksum < "$RS1/docreview-state.md")"
out="$(bash -c "SD='$SD'; STATE_DIR='$RS1'; sid=sess-rfbb0002
$RG
echo wrote" 2>&1)"; rc=$?
assert_eq "$rc" "3" "T8: 남의 표지 — 쓰기 전 확인이 rc 3"
assert_contains "$out" "「이어 씀」" "T8: 남의 표지 — 「이어 씀」 을 안내한다"
assert_not_contains "$out" "wrote" "T8: 남의 표지 — 뒤 명령이 돌지 않았다"
out="$(bash -c "SD='$SD'; STATE_DIR='$RS1'; sid=sess-rfaa0001
$RG
echo wrote" 2>&1)"; rc=$?
{ [ "$rc" -eq 0 ] && [ "$out" = "wrote" ]; } && ok "T8: 표지 주인 — 확인을 지난다(양의 짝)" || no "T8: 표지 주인인데 확인이 막았다(rc $rc): $out"
DISP="$(bash_with "$RF" 'one-line "$STATE_DIR/said-<id>.txt"' | sed -e 's/<id>/RFID1/g' -e 's/<drop | adopt | reject | hold>/adopt/')"
ANS="$(bash_with "$RF" 'kind 답' | sed -e 's/<n>/1/g' -e 's/<id>/RFID1/g')"
for pair in "처분|$DISP" "답 기록|$ANS"; do
  nm="${pair%%|*}"; body="${pair#*|}"
  printf '채택\n' > "$RS1/said-RFID1.txt"; printf '요약\n' > "$RS1/note-RFID1.txt"
  ab="$(cksum < "$rf1/docs/superpowers/interview/$(date +%F)-rfx-interview.audit.md")"
  out="$(cd "$rf1" && bash -c "SD='$SD'; STATE_DIR='$RS1'; AUDIT_ABS='$rf1/docs/superpowers/interview/$(date +%F)-rfx-interview.audit.md'; sid=sess-rfbb0002
$body" 2>&1)"; rc=$?
  assert_eq "$rc" "3" "T8: ${nm} 펜스 — 남의 표지면 rc 3 으로 멈춘다"
  assert_eq "$(cksum < "$RS1/docreview-state.md")" "$rs1b" "T8: ${nm} 펜스 — 남의 표지면 원장이 그대로다"
  assert_eq "$(cksum < "$rf1/docs/superpowers/interview/$(date +%F)-rfx-interview.audit.md")" "$ab" "T8: ${nm} 펜스 — 남의 표지면 audit 도 그대로다"
  [ -e "$RS1/said-RFID1.txt" ] && ok "T8: ${nm} 펜스 — 남의 표지면 문구 파일을 지우지 않는다" || no "T8: ${nm} 펜스 — 멈췄는데 문구 파일이 사라졌다"
  out="$(cd "$rf1" && bash -c "SD='$SD'; STATE_DIR='$RS1'; AUDIT_ABS='$rf1/docs/superpowers/interview/$(date +%F)-rfx-interview.audit.md'; sid=sess-rfaa0001
$body" 2>&1)"
  case "$out" in *"q_rc="*|*"ans_rc="*) ok "T8: ${nm} 펜스 — 표지 주인이면 확인을 지나 엔진 호출에 닿는다(양의 짝)" ;;
    *) no "T8: ${nm} 펜스 — 표지 주인인데 끝 줄에 닿지 않았다: $out" ;; esac
done
# 넘겨받기
o="$(rf_run "$rf1" sess-rfbb0002 "$(fence "$RF" ledger-takeover)")"
assert_eq "$(cat "$RS1/reviewing-by" 2>/dev/null)" "sess-rfbb0002" "T8: 「이어 씀」 뒤 넘겨받기 펜스가 표지를 바꾼다"
# 끝맺음 펜스(계수 기록) — 남의 표지면 건너뛰고 풀지 않는다 · 주인이면 쓰고 푼다
RC_F="$(fence "$RF" framing-count)"
printf '%s\n' "$RC_F" | grep -qF 'ledger_marker.py" acquire' && printf '%s\n' "$RC_F" | tail -n 3 | grep -qF 'ledger_marker.py" release' \
  && ok "T8: 계수 기록 펜스가 acquire 로 시작해 release 로 끝난다" || no "T8: 계수 기록 펜스 꼴"
rs1b="$(cksum < "$RS1/docreview-state.md")"
out="$(rf_run "$rf1" sess-rfaa0001 "$RC_F")"
assert_contains "$out" "표지가 다른 세션 것이다" "T8: 남의 표지 — 계수 기록 펜스가 건너뛴다"
assert_eq "$(cksum < "$RS1/docreview-state.md")" "$rs1b" "T8: 남의 표지 — 계수 기록 펜스 뒤 원장이 그대로다"
assert_eq "$(cat "$RS1/reviewing-by" 2>/dev/null)" "sess-rfbb0002" "T8: 남의 표지 — 계수 기록 펜스가 남의 표지를 풀지 않는다"
out="$(rf_run "$rf1" sess-rfbb0002 "$RC_F")"
[ -e "$RS1/reviewing-by" ] && no "T8: 주인의 계수 기록 펜스 뒤에도 표지가 남았다: $out" || ok "T8: 주인의 계수 기록 펜스 뒤 표지가 사라졌다"
assert_eq "$(cat "$RS1/last-session" 2>/dev/null)" "sess-rfbb0002" "T8: 계수 기록 펜스가 last-session 에 주인 세션을 남겼다"
# 위조 표지 — 두 줄 표지가 HELD 를 위조하지 못한다
printf 'sess-zzzz9999\nledger-open: HELD\n' > "$RS1/reviewing-by"
o="$(rf_run "$rf1" sess-rfcc0003 "$RFO")"
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: OTHER:(알 수 없는 표지)" "T8: 두 줄 표지는 OTHER:(알 수 없는 표지)"
rm -f "$RS1/reviewing-by"

# 링크된 .docreview — NO_DIR, 같은 호출의 mkdir 가 돌지 않고 링크 너머가 비어 있다
rf3="$T/rf3"; rf_repo "$rf3" >/dev/null
out3="$T/rf-outside"; mkdir -p "$out3" "$rf3/.claude/spec-distill"; ln -s "$out3" "$rf3/.claude/spec-distill/.docreview"
o="$(rf_run "$rf3" sess-rfdd0004 "$RFO
mkdir -p \"\$STATE_DIR\"; echo after-fence-ran")"; rc=$?
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: NO_DIR" "T8: 링크된 .docreview — 마지막 줄이 NO_DIR"
assert_eq "$rc" "3" "T8: 링크된 .docreview — 호출이 rc 3 으로 끝난다"
assert_eq "$(ls -A "$out3")" "" "T8: 링크된 .docreview — 링크 너머 폴더가 비어 있다"
rm -f "$rf3/.claude/spec-distill/.docreview"
o="$(rf_run "$rf3" sess-rfdd0004 "$RFO
echo after-fence-ran")"; rc=$?
{ [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$o" | tail -n 1)" = "after-fence-ran" ]; } \
  && ok "T8 양성 대조: 링크가 없으면 HELD 이고 뒤 명령이 돈다" || no "T8 양성 대조: 링크가 없는데 막혔다(rc $rc): $o"

# A1 — 옛 원장 이월(정리가 mkdir · acquire 앞) · 같은 세션의 다음 라운드는 정리를 건너뛴다
rf2="$T/rf2"; sd2="$(rf_repo "$rf2")"
RR2="$rf2/.claude/spec-distill"; mkdir -p "$RR2/oldsessrf01/docreview/k1"
ledger "$RR2/oldsessrf01/docreview/k1/docreview-state.md" "$sd2" 1
printf 'x\n' > "$RR2/oldsessrf01/interview-basename"   # 옛 세션 폴더의 모양(직속 파일)
age "$RR2/oldsessrf01"
RS2="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$RR2" --doc "$sd2")"
o="$(rf_run "$rf2" sess-rfee0005 "$RFO")"
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: HELD" "T8 A1(i): 옛 원장이 있는 첫 리뷰도 HELD"
[ -f "$RS2/docreview-state.md" ] && grep -qF "doc: $sd2" "$RS2/docreview-state.md" \
  && ok "T8 A1(i): 같은 seed 의 옛 원장이 .docreview/<키> 로 옮겨졌다" || no "T8 A1(i): 옛 원장이 옮겨지지 않았다: $o"
mkdir -p "$RR2/.docreview/zz-0000000000000000"
ledger "$RR2/.docreview/zz-0000000000000000/docreview-state.md" "$T/nope-design.md" 1
age "$RR2/.docreview/zz-0000000000000000"
o="$(rf_run "$rf2" sess-rfee0005 "$RFO")"
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: HELD" "T8 A1(ii): 같은 세션의 다음 라운드 — HELD"
[ -d "$RR2/.docreview/zz-0000000000000000" ] && ok "T8 A1(ii): 같은 세션의 다음 라운드는 정리를 부르지 않는다" || no "T8 A1(ii): 같은 세션의 다음 라운드에서 정리가 돌았다"
o="$(rf_run "$rf2" sess-rfff0006 "$RFO")"
assert_eq "$(printf '%s\n' "$o" | tail -n 1)" "ledger-open: OTHER:sess-rfee0005" "T8 A1(ii): 다른 세션 — OTHER"
[ -d "$RR2/.docreview/zz-0000000000000000" ] && no "T8 A1(ii): 다른 세션의 진입이 정리를 부르지 않았다" || ok "T8 A1(ii): 다른 세션의 진입은 판결 전에 정리를 부른다"

# ── T8 fix1 — 도출 지점의 관문: 링크된 .docreview 면 STATE_DIR 이 비고 어느 펜스도 링크 너머에 쓰지 않는다 ──────
cgate() { awk '/codex-gate:begin[[:space:]]+runner=run_docreview_codex_reviewer\.sh/ {g=1; next} /codex-gate:end/ {g=0} g && /^```bash$/ {b=1; next} g && b && /^```$/ {b=0; next} g && b' "$1"; }
crashy() { printf '%s\n' "$1" | grep -E 'unbound variable|syntax error|Traceback|command not found' || true; }
C1="$(bash_with "$RF" 'marks "$SEED_ABS" "$AUDIT_ABS" || marks_rc')"; C2="$(bash_with "$RF" 'hunks-final.json')"; C3="$(bash_with "$RF" 'gate-final.json')"
SRIN="$(bash_with "$SR" '# 엔진 상태 — 이 문서만의 디렉토리')"; SRCX="$(cgate "$SR")"
RBBU="$(bash_with "$RB" 'build_brief_bundle.py" "$PAYLOAD" "$AUDIT" > "$BUNDLE"')"; RBCX="$(cgate "$RB")"
for v in C1 C2 C3 SRIN SRCX RBBU RBCX; do
  eval "x=\"\$$v\""; [ -n "$x" ] && ok "전제(T8 관문): 펜스 $v 를 뽑았다" || no "전제(T8 관문): 펜스 $v 가 비었다 — 아래 칸이 공허하다"
done
G_LINE='|| python3 "$SD/scripts/state_path.py" path-inside --root "${ROOT%/.claude/spec-distill}" "$STATE_DIR" ||'
python3 -I - "$SR" "$RB" "$RF" "$FIN" <<'PY' && ok "T8 관문: STATE_DIR 을 도출하는 줄마다 바로 다음 줄이 path-inside 관문이다(네 파일)" || no "T8 관문: 관문 없는 STATE_DIR 도출이 있다"
import re, sys
der = re.compile(r'^\s*STATE_DIR="(?:\$\{STATE_DIR:-)?\$\(python3 "\$(SD|PR)/scripts/docreview_state\.py" state-dir-for ')
bad = []; n = 0
for p in sys.argv[1:]:
    ls = open(p, encoding="utf-8").read().split("\n")
    for i, l in enumerate(ls):
        m = der.match(l)
        if not m:
            continue
        n += 1
        g = '[ -z "${STATE_DIR:-}" ] || python3 "$%s/scripts/state_path.py" path-inside --root "${ROOT%%/.claude/spec-distill}" "$STATE_DIR" || ' % m.group(1)
        if g not in ls[i + 1] or 'STATE_DIR=""' not in ls[i + 1]:
            bad.append("%s:%d" % (p, i + 1))
print("\n".join(bad), file=sys.stderr)
sys.exit(1 if bad or n < 19 else 0)
PY
lk_env() { env -i PATH=/usr/bin:/bin HOME="$T" PYTHONDONTWRITEBYTECODE=1 CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID="$1" DEVBREW_SPEC_DISTILL_SESSION_ID="$1" DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1 bash -c "$2" 2>&1; }
lk_setup() {   # lk_setup <repo> <밖 폴더> [link] → seed · audit · brief 를 둔 저장소, link 면 .docreview 를 밖으로
  sd="$(rf_repo "$1")"
  printf -- '---\ntype: interview-seed-audit\nsession_id: sess-lk000001\n---\n\n## 1. 원문\n\n원문.\n\n## 6. 리뷰 결정\n' > "${sd%.md}.audit.md"
  printf -- '---\ntype: interview-brief\n---\n# brief\n' > "$1/docs/b-interview.md"; printf -- '---\ntype: interview-audit\n---\n# a\n' > "$1/docs/b-interview.audit.md"
  printf '# D\n' > "$1/docs/d-design.md"
  mkdir -p "$2" "$1/.claude/spec-distill"
  [ "${3:-}" != link ] || ln -s "$2" "$1/.claude/spec-distill/.docreview"
}
lkr="$T/lk"; lko="$T/lk-outside"; lk_setup "$lkr" "$lko" link
[ -L "$lkr/.claude/spec-distill/.docreview" ] && ok "전제(T8 관문): .docreview 가 밖을 가리키는 링크다" || no "전제(T8 관문): 링크가 아니다"
# (a) request-framing — 상태 블록 + 확정 직전 검사 1 · 2 · 3, 각각 한 호출
for i in 1 2 3; do
  eval "body=\"\$C$i\""
  o="$(cd "$lkr" && lk_env sess-lk000001 "$blkT
$body")"
  eval "LKA$i=\"\$o\""
  assert_eq "$(crashy "$o")" "" "T8 관문(a): request-framing 검사 $i 가 링크 아래에서 죽지 않는다"
  assert_contains "$o" "원장 자리가 레포 밖으로 풀리거나 링크를 지난다" "T8 관문(a): 검사 $i — 리뷰 산출물을 건너뛴다는 한 줄을 낸다"
done
assert_contains "$LKA1" "marks_rc=" "T8 관문(a): 검사 1 이 판정 줄을 낸다"
assert_not_contains "$LKA1" "검사 불가»로 막힌다" "T8 관문(a): 검사 1 이 검사 2 · 3 을 «검사 불가» 로 막는다고 하지 않는다"
assert_contains "$LKA2" "저자 편집 대조 불가" "T8 관문(a): 검사 2 는 대조 불가를 알리고 막지 않는다"
assert_not_contains "$LKA2" "게이트를 띄우지 않는다" "T8 관문(a): 검사 2 가 게이트를 막지 않는다"
assert_contains "$LKA3" "final_drops_rc=0" "T8 관문(a): 검사 3 은 audit 으로 대조해 통과 판정을 낸다"
assert_eq "$(ls -A "$lko")" "" "T8 관문(a): 링크 너머 폴더가 비어 있다"
# (b) spec-review — ## 입력 + codex 펜스
o="$(cd "$lkr" && lk_env sess-lk000001 "spec_path='$lkr/docs/d-design.md'
$SRIN
$SRCX")"
assert_eq "$(crashy "$o")" "" "T8 관문(b): spec-review 입력 + codex 펜스가 링크 아래에서 죽지 않는다"
assert_eq "$(ls -A "$lko")" "" "T8 관문(b): spec-review codex 펜스 뒤 링크 너머 폴더가 비어 있다"
# (c) reviewing-brief — 번들 펜스 · codex 펜스
o="$(cd "$lkr" && lk_env sess-lk000001 "PAYLOAD='$lkr/docs/b-interview.md'; AUDIT='$lkr/docs/b-interview.audit.md'
$RBBU")"
assert_eq "$(crashy "$o")" "" "T8 관문(c): reviewing-brief 번들 펜스가 링크 아래에서 죽지 않는다"
assert_contains "$o" "엔진 상태 디렉토리 없음" "T8 관문(c): 번들 펜스는 엔진 자리 없음으로 라운드를 시작하지 않는다"
o="$(cd "$lkr" && lk_env sess-lk000001 "PAYLOAD='$lkr/docs/b-interview.md'
$RBCX")"
assert_eq "$(crashy "$o")" "" "T8 관문(c): reviewing-brief codex 펜스가 링크 아래에서 죽지 않는다"
assert_eq "$(ls -A "$lko")" "" "T8 관문(c): reviewing-brief 펜스 뒤 링크 너머 폴더가 비어 있다"
# 양성 대조 — 링크가 없으면 같은 펜스가 원장 자리에 산출물을 만든다
lpr="$T/lkp"; lk_setup "$lpr" "$T/lkp-outside"
o="$(cd "$lpr" && lk_env sess-lk000001 "$blkT
$C3")"
LP_RF="$(cd "$lpr" && lk_env sess-lk000001 "$blkT
echo \"SD_IS=\$STATE_DIR\"" | sed -n 's/^SD_IS=//p')"
{ [ -n "$LP_RF" ] && [ -f "$LP_RF/gate-final.json" ]; } && ok "T8 관문 양성 대조(a): 링크가 없으면 검사 3 이 원장 자리에 gate-final.json 을 쓴다" || no "T8 관문 양성 대조(a): 원장 자리 산출물이 없다('$LP_RF'): $o"
assert_not_contains "$o" "원장 자리가 레포 밖으로" "T8 관문 양성 대조(a): 링크가 없으면 건너뜀 줄이 없다"
o="$(cd "$lpr" && lk_env sess-lk000001 "spec_path='$lpr/docs/d-design.md'
$SRIN
$SRCX")"
LP_SR="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$lpr/.claude/spec-distill" --doc "$lpr/docs/d-design.md")"
[ -d "$LP_SR" ] && ok "T8 관문 양성 대조(b): 링크가 없으면 spec-review codex 펜스가 원장 자리를 만든다" || no "T8 관문 양성 대조(b): 원장 자리가 없다: $o"
o="$(cd "$lpr" && lk_env sess-lk000001 "PAYLOAD='$lpr/docs/b-interview.md'; AUDIT='$lpr/docs/b-interview.audit.md'
$RBBU")"
LP_RB="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$lpr/.claude/spec-distill" --doc "$lpr/docs/b-interview.md")"
[ -d "$LP_RB" ] && ok "T8 관문 양성 대조(c): 링크가 없으면 reviewing-brief 번들 펜스가 원장 자리를 만든다" || no "T8 관문 양성 대조(c): 원장 자리가 없다: $o"
assert_not_contains "$o" "엔진 상태 디렉토리 없음" "T8 관문 양성 대조(c): 링크가 없으면 엔진 자리 없음이 나지 않는다"
finish
