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

finish
