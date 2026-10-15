#!/usr/bin/env bash
# R2 Task 6 — §4 여러 줄 항목(RC39 · AC14) · §1 출처 표시(N21) · 해결한 결정도 §3 에(N22).
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
S="$ROOT/plugins/spec-distill/scripts"; FX="$ROOT/plugins/spec-distill/tests/fixtures"
TMP="$(mktemp -d -t sd-form-XXXXXX)" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
trap 'rm -rf "$TMP"' EXIT

# 기반은 계약 v2 이고 §4 첫 항목에 결정 연결이 있는 정상 쌍이다(`s4 배선` 이 그것을 요구한다).
base() {
  cp "$FX/interview-brief-v2-valid.md" "$TMP/p.md"; cp "$FX/interview-brief-v2-valid.audit.md" "$TMP/p.audit.md"
  python3 -I -X utf8 - "$TMP/p.md" "$TMP/p.audit.md" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
p.write_text(re.sub(r"(?m)^audit_file:.*$", "audit_file: p.audit.md", t, count=1), encoding="utf-8")
a = pathlib.Path(sys.argv[2]); u = a.read_text(encoding="utf-8")
a.write_text(re.sub(r"(?m)^payload:.*$", "payload: p.md", u, count=1), encoding="utf-8")
PY
}
gate() { python3 "$S/check_brief.py" gate "$TMP/p.md" > "$TMP/out" 2>&1; }
# 절 본문 갈아 끼우기: put <절 번호> <새 본문 파일>
put() { python3 -I -X utf8 - "$TMP/p.md" "$1" "$2" <<'PY'
import re, sys, pathlib
p, num, new = pathlib.Path(sys.argv[1]), sys.argv[2], pathlib.Path(sys.argv[3]).read_text(encoding="utf-8")
t = p.read_text(encoding="utf-8")
m = re.search(r"(?m)^## %s\..*$" % re.escape(num), t)
nxt = re.search(r"(?m)^## \d+\.", t[m.end():])
end = m.end() + nxt.start() if nxt else len(t)
p.write_text(t[:m.end()] + "\n\n" + new.strip("\n") + "\n\n" + t[end:], encoding="utf-8")
PY
}
# 절 끝에 줄 더하기: app <절 번호> <줄 파일> — 기반 픽스처의 결정 · 연결을 지우지 않는다(지우면 무관한 술어가 red 를 낸다)
app() { python3 -I -X utf8 - "$TMP/p.md" "$1" "$2" <<'PY'
import re, sys, pathlib
p, num, add = pathlib.Path(sys.argv[1]), sys.argv[2], pathlib.Path(sys.argv[3]).read_text(encoding="utf-8")
t = p.read_text(encoding="utf-8")
m = re.search(r"(?m)^## %s\..*$" % re.escape(num), t)
nxt = re.search(r"(?m)^## \d+\.", t[m.end():])
end = m.end() + nxt.start() if nxt else len(t)
p.write_text(t[:end].rstrip("\n") + "\n" + add.strip("\n") + "\n\n" + t[end:], encoding="utf-8")
PY
}
# §4 첫 항목 줄을 블록으로 갈아 끼우기(나머지 §4 항목은 그대로): rep4 <블록 파일>
rep4() { python3 -I -X utf8 - "$TMP/p.md" "$1" <<'PY'
import re, sys, pathlib
p, blk = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]).read_text(encoding="utf-8").strip("\n")
t = p.read_text(encoding="utf-8")
m = re.search(r"(?m)^## 4\..*$", t)
nxt = re.search(r"(?m)^## \d+\.", t[m.end():])
sec_end = m.end() + nxt.start() if nxt else len(t)
h = re.search(r"(?m)^[-*]\s.*$", t[m.end():sec_end])
assert h, "기반 픽스처 §4 에 항목이 없다"
s, e = m.end() + h.start(), m.end() + h.end()
p.write_text(t[:s] + blk + t[e:], encoding="utf-8")
PY
}
# §6 에 실재하는 첫 앵커(스윕 뒤 S1 이 반드시 있다)
SA=S1

# ── §1 출처 표시 (N21)
base; gate; assert_eq "$?" "0" "base: 스윕된 정상 쌍이 통과한다 (양성 대조)"
printf -- "- Goal: 로그인 실패를 줄인다 ⟨%s⟩\n- Non-goal: 세션 스토어 개편 ⟨모델 추론⟩\n" "$SA" > "$TMP/s1"
base; put 1 "$TMP/s1"; gate; assert_eq "$?" "0" "n21_marked: §1 줄마다 출처 표시가 있으면 통과한다"
printf -- "- Goal: 로그인 실패를 줄인다 ⟨%s⟩\n- Non-goal: 세션 스토어 개편\n" "$SA" > "$TMP/s1"
base; put 1 "$TMP/s1"; gate; rc=$?
{ [ "$rc" -ne 0 ] && grep -q '§1' "$TMP/out"; } && ok "n21_unmarked: 출처 표시 없는 §1 줄은 red" || no "n21_unmarked: rc=$rc"
printf -- "- Goal: 로그인 실패를 줄인다 ⟨S99⟩\n" > "$TMP/s1"
base; put 1 "$TMP/s1"; gate; rc=$?
[ "$rc" -ne 0 ] && ok "n21_dangling: §1 의 ⟨S99⟩ 가 §6 에 없으면 red" || no "n21_dangling: 통과했다"

# ── 해결한 결정 (N22) — 기반 결정은 그대로 두고 OQ9 를 더한다
printf -- "- OQ9 [해결 ⟨%s⟩] — 렌더링 전략\n" "$SA" > "$TMP/s0"
printf -- "- OQ9 [해결 ⟨%s⟩]: 렌더링 전략 — 해결: 서버 렌더링으로 간다\n" "$SA" > "$TMP/s3"
base; app 0 "$TMP/s0"; app 3 "$TMP/s3"; gate; assert_eq "$?" "0" "resolved_kept: 해결 결정이 해결 내용과 함께 §3 에 남으면 통과한다 (양성 짝)"
base; app 0 "$TMP/s0"; gate; rc=$?
{ [ "$rc" -ne 0 ] && grep -q 'OQ9' "$TMP/out"; } && ok "resolved_dropped: §0 의 해결 결정이 §3 에 없으면 red" || no "resolved_dropped: rc=$rc"
printf -- "- OQ9 [해결 ⟨S99⟩] — 렌더링 전략\n" > "$TMP/s0d"
printf -- "- OQ9 [해결 ⟨S99⟩]: 렌더링 전략 — 해결: 서버 렌더링\n" > "$TMP/s3d"
base; app 0 "$TMP/s0d"; app 3 "$TMP/s3d"; gate; rc=$?
{ [ "$rc" -ne 0 ] && grep -q 'S99' "$TMP/out"; } && ok "resolved_dangling: 해결 토큰의 S99 가 §6 에 없으면 red" || no "resolved_dangling: rc=$rc"
printf -- "- OQ9: 렌더링 전략\n" > "$TMP/s3n"
base; app 0 "$TMP/s0"; app 3 "$TMP/s3n"; gate; rc=$?
[ "$rc" -ne 0 ] && ok "resolved_unmarked: §3 의 해결 결정 줄에 해결 표시가 없으면 red" || no "resolved_unmarked: 통과했다"

# ── §4 여러 줄 (RC39 · AC14). 기반 픽스처의 §4 첫 항목만 여러 줄로 바꾼다(다른 항목은 그대로).
first4() { python3 -I -X utf8 -c 'import re,sys; t=open(sys.argv[1],encoding="utf-8").read(); m=re.search(r"(?m)^## 4\..*$",t); r=t[m.end():]; print(next(l for l in r.splitlines() if re.match(r"^[-*]\s",l)))' "$TMP/p.md"; }
base; H="$(first4)"
printf -- "%s\n  이유를 둘째 줄에서 이어 쓴다.\n  - 하위 불릿도 본문이다.\n" "$H" > "$TMP/s4"
rep4 "$TMP/s4"; gate; assert_eq "$?" "0" "s4_multiline: 첫 줄이 항목이고 들여쓴 줄은 본문 — 여러 줄 항목이 통과한다"
base; H="$(first4)"; HL="$(printf '%s' "$H" | python3 -I -X utf8 -c 'import re,sys; s=sys.stdin.read(); print(re.sub(r"\s*\[(?:RC\d+\s*)?→[^\]]*\]\s*$","",s))')"
LK="$(printf '%s' "$H" | grep -oE '\[(RC[0-9]+ *)?→[^]]*\]$')"
[ -n "$LK" ] || no "s4 배선: 기반 §4 첫 항목에 결정 연결이 없다 — 연결 달린 항목으로 시작하도록 배선을 고쳐라(아래 단언이 공허하다)"
printf -- "%s\n  둘째 줄. %s\n" "$HL" "$LK" > "$TMP/s4"
rep4 "$TMP/s4"; gate; rc=$?
[ "$rc" -ne 0 ] && ok "s4_link_on_body: 결정 연결이 첫 줄 끝이 아니면 red" || no "s4_link_on_body: 통과했다"
# 첫 줄 연결은 그대로 두고 본문 줄에 연결을 하나 더 — 첫 줄만 읽는 ① 은 조용하므로 본문 줄 규칙만이 red 를 낸다.
base; H="$(first4)"
printf -- "%s\n  둘째 줄. [→ 없음]\n" "$H" > "$TMP/s4"
rep4 "$TMP/s4"; gate; rc=$?
{ [ "$rc" -ne 0 ] && grep -q '§4 항목의 결정 연결' "$TMP/out"; } && ok "s4_second_link_on_body: 첫 줄 연결이 있어도 본문 줄의 연결은 red" || no "s4_second_link_on_body: rc=$rc"
base; H="$(first4)"
printf -- "%s\n  본문에 RC77 을 숨긴다.\n" "$H" > "$TMP/s4"
rep4 "$TMP/s4"; gate; rc=$?
[ "$rc" -ne 0 ] && ok "s4_rc_on_body: 첫 줄에 없는 RC<n> 을 본문에 두면 red" || no "s4_rc_on_body: 통과했다"

# ── §4 유니코드 공백 들여쓰기 (fix round 1) — NBSP(U+00A0) · 전각 공백(U+3000) 으로 들여쓴 줄도 들여쓴 줄이다.
# 항목 뒤면 본문(첫 줄에 없는 RC 는 red), 항목 앞이면 그 자체로 항목(fail-closed — «출처키» 없으면 red).
# 공백 글자는 보이지 않으므로 코드 포인트로 만든다.
ws_block() {  # ws_block <코드 포인트 16진> <after|top> <줄> → 첫 §4 항목과 엮은 블록을 $TMP/s4 에
  python3 -I -X utf8 -c 'import sys
cp, where, head, line = int(sys.argv[1], 16), sys.argv[2], sys.argv[3], sys.argv[4]
ind = chr(cp) * 2
blk = head + "\n" + ind + line if where == "after" else ind + line + "\n" + head
open(sys.argv[5], "w", encoding="utf-8").write(blk + "\n")' "$1" "$2" "$H" "$3" "$TMP/s4"
}
for cp in 00A0 3000; do
  base; H="$(first4)"; ws_block "$cp" after "- 레포는 캐시가 없다 RC9"
  rep4 "$TMP/s4"; gate; rc=$?
  { [ "$rc" -ne 0 ] && grep -q 'RC9' "$TMP/out"; } \
    && ok "s4_ws_after_${cp}: U+${cp} 로 들여쓴 불릿은 앞 항목의 본문이다 — 첫 줄에 없는 RC9 는 red" \
    || no "s4_ws_after_${cp}: U+${cp} 들여쓴 줄이 순회에서 빠졌다 (rc=$rc)"
  base; H="$(first4)"; ws_block "$cp" top "- 레포 주장 RC9 — 경로#앵커"
  rep4 "$TMP/s4"; gate; rc=$?
  { [ "$rc" -ne 0 ] && grep -q 'unkeyed landscape entries' "$TMP/out"; } \
    && ok "s4_ws_top_${cp}: 항목 앞의 U+${cp} 들여쓴 불릿은 그 자체로 항목이다 — «출처키» 없으면 red" \
    || no "s4_ws_top_${cp}: 항목 앞의 U+${cp} 들여쓴 불릿이 순회에서 빠졌다 (rc=$rc)"
done
# 양의 짝 — NBSP 로 들여쓴 산문 본문 줄은 정직하다.
base; H="$(first4)"; ws_block 00A0 after "이유를 둘째 줄에서 이어 쓴다."
rep4 "$TMP/s4"; gate; assert_eq "$?" "0" "s4_ws_prose: NBSP 로 들여쓴 산문 본문 줄은 통과한다 (양성 짝)"

# ── 해결 표시는 한 모양뿐 (fix round 1 — 허용 목록). `[해결` 을 담은 줄은 `[해결 ⟨S<n>⟩]` 를 정확히 한 번.
# §0 · §3 둘 다에 같은 줄을 둬 집합 등식은 만족시킨다 — 모양 규칙만 red 를 낸다.
for tok in '[해결 ⟨S99⟩ · ⟨S1⟩]' '[해결]' '[해결 S1]' '[해결⟨S99⟩]' '[해결 ⟨S1⟩] [해결 ⟨S1⟩]'; do
  printf -- "- OQ9 %s — 렌더링 전략\n" "$tok" > "$TMP/s0"
  printf -- "- OQ9 %s: 렌더링 전략 — 해결: 서버 렌더링\n" "$tok" > "$TMP/s3"
  base; app 0 "$TMP/s0"; app 3 "$TMP/s3"; gate; rc=$?
  { [ "$rc" -ne 0 ] && grep -q '해결 표시 모양이 아니다' "$TMP/out"; } \
    && ok "resolved_shape «${tok}»: 정본 모양이 아닌 해결 표시는 red" \
    || no "resolved_shape «${tok}»: 통과했거나 다른 이유로 red (rc=$rc)"
done

# ── §0 과 §3 은 같은 결정 전량 (fix round 1) — 집합 등식 양방향.
printf -- "- OQ9 [열림] — 캐시 무효화 시점\n" > "$TMP/s0"
base; app 0 "$TMP/s0"; gate; rc=$?
{ [ "$rc" -ne 0 ] && grep -q '§0 의 OQ9 가 §3 에 없다' "$TMP/out"; } \
  && ok "decisions_s0_only: §0 의 열린 결정이 §3 에 없으면 red" || no "decisions_s0_only: rc=$rc"
printf -- "- OQ9: 캐시 무효화 시점\n" > "$TMP/s3"
base; app 3 "$TMP/s3"; gate; rc=$?
{ [ "$rc" -ne 0 ] && grep -q '§3 의 OQ9 가 §0 결정 목록에 없다' "$TMP/out"; } \
  && ok "decisions_s3_only: §3 의 결정이 §0 에 없으면 red" || no "decisions_s3_only: rc=$rc"
printf -- "- OQ9 [열림] — 캐시 무효화 시점\n" > "$TMP/s0"
printf -- "- OQ9: 캐시 무효화 시점\n" > "$TMP/s3"
base; app 0 "$TMP/s0"; app 3 "$TMP/s3"; gate; assert_eq "$?" "0" "decisions_both: 두 절에 같이 있으면 통과한다 (양성 짝)"

# ── 해결 결정의 §0 · §3 일치와 해결 내용 (fix round 1).
printf -- '- **S2** 🗣 R1 답:\n  > "서버에서 그리자"\n' > "$TMP/s6"
printf -- "- OQ9 [해결 ⟨S1⟩] — 렌더링 전략\n" > "$TMP/s0"
printf -- "- OQ9 [해결 ⟨S2⟩]: 렌더링 전략 — 해결: 서버 렌더링\n" > "$TMP/s3"
base; app 6 "$TMP/s6"; app 0 "$TMP/s0"; app 3 "$TMP/s3"; gate; rc=$?
{ [ "$rc" -ne 0 ] && grep -q '§0(S1) 과 §3(S2)' "$TMP/out"; } \
  && ok "resolved_sid_mismatch: §0 과 §3 의 해결 토큰이 다른 발화를 가리키면 red" || no "resolved_sid_mismatch: rc=$rc"
printf -- "- OQ9 [해결 ⟨S2⟩] — 렌더링 전략\n" > "$TMP/s0"
base; app 6 "$TMP/s6"; app 0 "$TMP/s0"; app 3 "$TMP/s3"; gate
assert_eq "$?" "0" "resolved_sid_same: 같은 S2 를 가리키면 통과한다 (양성 짝 — S2 추가 자체는 무해)"
printf -- "- OQ9 [해결 ⟨S1⟩] — 렌더링 전략\n" > "$TMP/s0"
printf -- "- OQ9 [해결 ⟨S1⟩]: 렌더링 전략\n" > "$TMP/s3"
base; app 0 "$TMP/s0"; app 3 "$TMP/s3"; gate; rc=$?
{ [ "$rc" -ne 0 ] && grep -q '해결 내용' "$TMP/out"; } \
  && ok "resolved_no_body: §3 해결 줄에 「— 해결: <한 줄>」 이 없으면 red" || no "resolved_no_body: rc=$rc"
printf -- "- OQ9 [열림] — 렌더링 전략\n" > "$TMP/s0"
printf -- "- OQ9 [해결 ⟨S1⟩]: 렌더링 전략 — 해결: 서버 렌더링\n" > "$TMP/s3"
base; app 0 "$TMP/s0"; app 3 "$TMP/s3"; gate; rc=$?
{ [ "$rc" -ne 0 ] && grep -q '해결이 아니다' "$TMP/out"; } \
  && ok "resolved_status_mismatch: §0 은 열림인데 §3 이 해결이면 red" || no "resolved_status_mismatch: rc=$rc"

finish
