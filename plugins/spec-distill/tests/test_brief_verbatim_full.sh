#!/usr/bin/env bash
# R2 Task 5 — payload §6 은 S1~Sn 원문 전량이고 추가만 허용(설계 §3-2 · AC11).
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
S="$ROOT/plugins/spec-distill/scripts"; FX="$ROOT/plugins/spec-distill/tests/fixtures"
TMP="$(mktemp -d -t sd-v6-XXXXXX)" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
trap 'rm -rf "$TMP"' EXIT

# 기반: 스윕을 마친 정상 쌍(payload §6 이 S1~Sn 전량이다)
base() {
  cp "$FX/interview-brief-valid.md" "$TMP/p.md"; cp "$FX/interview-brief-valid.audit.md" "$TMP/p.audit.md"
  python3 -I -X utf8 - "$TMP/p.md" "$TMP/p.audit.md" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
p.write_text(re.sub(r"(?m)^audit_file:.*$", "audit_file: p.audit.md", t, count=1), encoding="utf-8")
a = pathlib.Path(sys.argv[2]); u = a.read_text(encoding="utf-8")
a.write_text(re.sub(r"(?m)^payload:.*$", "payload: p.md", u, count=1), encoding="utf-8")
PY
}
gate() { python3 "$S/check_brief.py" gate "$TMP/p.md" > "$TMP/out" 2>&1; }
# payload §6 에서 앵커 하나의 항목(머리 줄 + 이어지는 들여쓴 줄)을 지운다
drop_anchor() { python3 -I -X utf8 - "$TMP/p.md" "$1" <<'PY'
import re, sys, pathlib
p, sid = pathlib.Path(sys.argv[1]), sys.argv[2]
lines, out, skip = p.read_text(encoding="utf-8").split("\n"), [], False
for ln in lines:
    if re.match(r"^\s*[-*]\s+\*\*S\d+\*\*", ln):
        skip = bool(re.match(r"^\s*[-*]\s+\*\*%s\*\*" % re.escape(sid), ln))
    elif skip and not (ln.startswith(" ") or ln.strip() == ""):
        skip = False
    if not skip:
        out.append(ln)
p.write_text("\n".join(out), encoding="utf-8")
PY
}

base; gate; assert_eq "$?" "0" "full_ok: payload §6 이 S1~Sn 전량이면 통과한다 (양성 대조)"
base; drop_anchor S2; gate; rc=$?
{ [ "$rc" -ne 0 ] && grep -q 'N1b' "$TMP/out"; } \
  && ok "n1b_missing_audit: audit §6 의 S2 가 payload §6 에 없으면 red (N1b)" || no "n1b_missing_audit: rc=$rc"
base; drop_anchor S1; gate; rc=$?
[ "$rc" -ne 0 ] && ok "n1b_no_s1: S1 이 없으면 red" || no "n1b_no_s1: S1 없이 통과했다"

# check_verbatim_coverage — 같은 앵커가 양쪽에 같은 글자면 통과, 다르면 구조 위반(rc 1)
CV="$S/check_verbatim_coverage.py"
cp "$FX/brief-verbatim-ok.md" "$TMP/v.md"; cp "$FX/brief-verbatim-ok.audit.md" "$TMP/v.audit.md"
STATE="$FX/state-verbatim-ok.md"
[ -f "$STATE" ] || { no "state fixture 부재: $STATE"; finish; }
python3 "$CV" "$TMP/v.md" "$STATE" "$TMP/v.audit.md" > "$TMP/cv" 2>&1; assert_eq "$?" "0" "dup_same: payload · audit 의 같은 앵커가 같은 글자면 통과한다"
python3 -I -X utf8 - "$TMP/v.md" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
# payload 쪽 S2 본문의 첫 인용 줄 끝에 글자를 덧붙인다 — 지적에 맞춰 payload 사본을 고친 모양
t2 = re.sub(r'(\*\*S2\*\*[^\n]*\n\s*>\s*"?[^\n]*?)("?\s*\n)', r"\1 (고침)\2", t, count=1)
assert t2 != t, "S2 항목을 찾지 못했다 — 픽스처를 확인하라"
p.write_text(t2, encoding="utf-8")
PY
python3 "$CV" "$TMP/v.md" "$STATE" "$TMP/v.audit.md" > "$TMP/cv" 2>&1; rc=$?
{ [ "$rc" -eq 1 ] && grep -q '글자가' "$TMP/cv"; } \
  && ok "dup_differs: 같은 앵커의 글자가 다르면 구조 위반(rc 1)" || no "dup_differs: rc=$rc $(head -c 300 "$TMP/cv")"
cp "$FX/brief-verbatim-ok.md" "$TMP/v.md"
python3 -I -X utf8 - "$TMP/v.md" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
lines, out, skip = t.split("\n"), [], False
for ln in lines:
    if re.match(r"^\s*[-*]\s+\*\*S\d+\*\*", ln):
        skip = bool(re.match(r"^\s*[-*]\s+\*\*S2\*\*", ln))
    elif skip and not (ln.startswith(" ") or ln.strip() == ""):
        skip = False
    if not skip:
        out.append(ln)
p.write_text("\n".join(out), encoding="utf-8")
PY
python3 "$CV" "$TMP/v.md" "$STATE" "$TMP/v.audit.md" > "$TMP/cv" 2>&1; rc=$?
{ [ "$rc" -eq 1 ] && grep -q 'S2' "$TMP/cv"; } \
  && ok "payload_missing: state · audit 에 있는 S2 가 payload §6 에 없으면 위반(rc 1)" || no "payload_missing: rc=$rc"

# 추가만 허용 — 결정 발화를 payload §6 · audit §6 · state 에 같은 write 로 더하면 다음 원문 검사가 통과한다
cp "$FX/brief-verbatim-ok.md" "$TMP/v.md"; cp "$FX/brief-verbatim-ok.audit.md" "$TMP/v.audit.md"; cp "$STATE" "$TMP/st.md"
python3 -I -X utf8 - "$TMP/v.md" "$TMP/v.audit.md" "$TMP/st.md" <<'PY'
import re, sys, pathlib
pay, aud, st = (pathlib.Path(x) for x in sys.argv[1:4])
ids = [int(x) for x in re.findall(r"\*\*S(\d+)\*\*", pay.read_text(encoding="utf-8"))]
n = max(ids) + 1
item = '\n- **S%d** 🗣 brief 리뷰 결정:\n  > "방향은 그대로 두고 범위만 줄인다"\n' % n
for f in (pay, aud):
    t = f.read_text(encoding="utf-8")
    m = re.search(r"(?m)^## 6\..*$", t)
    nxt = re.search(r"(?m)^## \d+\.", t[m.end():])
    cut = m.end() + nxt.start() if nxt else len(t)
    f.write_text(t[:cut].rstrip("\n") + "\n" + item + "\n" + t[cut:], encoding="utf-8")
s = st.read_text(encoding="utf-8")
entry = '  - id: S%d\n    source: verbatim\n    round: 99\n    text: "방향은 그대로 두고 범위만 줄인다"\n' % n
s = re.sub(r"(?m)^(user_statements:\s*\n)", lambda m: m.group(1) + entry, s, count=1)
st.write_text(s, encoding="utf-8")
PY
python3 "$CV" "$TMP/v.md" "$TMP/st.md" "$TMP/v.audit.md" > "$TMP/cv" 2>&1
assert_eq "$?" "0" "append_only: 결정 발화를 세 자리에 같은 write 로 더한 뒤 원문 검사가 통과한다"

finish
