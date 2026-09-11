#!/usr/bin/env bash
# guards: plugins/** shared/**
#
# `variant-of:` 마커의 계약. 중복 락(test_no_new_duplication.sh)의 면제 ③ 이 이 마커를 근거로 쓴다 —
# copy-of 마커는 test_copy_of_contract.sh 가 따로 집행하는데 variant-of 에는 그런 락이 없었다. 이 파일이
# 그 자리다. copy-of 계약 락에 축으로 넣지 않은 이유: 그 락은 «배포 지점이 정본을 가리키는 방법»의
# 계약이고(축 0 이 그 방법 수를 README 와 대조한다), variant-of 는 배포 방법이 아니라 정본 둘 사이의
# 관계다. 코퍼스 도출은 중복 락과 같다 — 면제를 주는 쪽과 그 근거를 감사하는 쪽이 같은 파일을 봐야 한다.
#
#   V1 마커 전수 — 코퍼스의 variant-of 마커 파일마다 ① agent 정의 자리(`shared/<x>/agents/*.md` ·
#      `plugins/<x>/agents/*.md`) ② 대상이 코퍼스에 있는 `shared/<x>/agents/*.md` 정본 ③ 대상은 마커가
#      없다(사슬 금지) ④ 관계 성립. 그리고 마커 파일 집합이 아래 리터럴 목록과 같다 — 면제는 diff 에 한
#      줄로 드러나야 한다(새 variant 는 이 목록을 같은 커밋에서 고친다).
#   V2 판정기 음성 — fixtures/variant_of/ 의 쌍. 양성(ok.md — 자유 키 description·tools 도 다르다)은 OK,
#      음성은 저마다의 사유로 FAIL. 감사 함수의 FAIL 갈래도 스크래치 코퍼스에서 하나씩 태운다.
#      판정기가 관대하게 퇴행하면 여기가 RED 다. 키 인식 축: YAML 이 최상위 키로 읽는 모양(큰따옴표 ·
#      작은따옴표 · 콜론 앞 공백)이 앞 키의 값으로 흡수되면 숨은 키가 관계를 통과한다. 값 블록 축:
#      비-자유 키의 여러 줄 값은 둘째 줄 이후만 달라도 FAIL 이고, 줄마다 같으면 OK(양의 짝). 줄 문법 축:
#      판정기는 실제 agent 파일이 쓰는 줄 모양(허용 목록)만 받는다 — 식별자 밖 키(따옴표 · 콜론 앞 공백 ·
#      명시 키 `?` · 컬럼-0 flow · 안 닫힌 따옴표) · 중복 키 · 자유 키 값을 여는 따옴표 · flow(뒤따르는
#      컬럼-0 줄을 YAML 이 값 안으로 삼켜 `tools` 가 사라진다 — Task 7 재리뷰 N1)가 저마다의 사유로 떨어진다.
#      교차 대조 축: 판정기가 읽은 최상위 키 집합이 PyYAML 의 것과 다르면 판정 불가(줄 문법 안의 `on:` 키).
#   V2b 줄바꿈 축 — frontmatter 에 LF 밖 줄바꿈(CR · NEL · U+2028 · U+2029)이나 탭으로 시작하는 줄이 있으면
#      판정 불가. PyYAML 은 그 문자 뒤를 새 최상위 키로 읽는데 판정기는 LF 로만 나누므로, 문자마다 한 셀과
#      리뷰의 실측 재현(실제 doc-critic-web 두 사본의 description 끝에 NEL + 권한 모드 키)을 둔다.
#   V2c 줄 문법 — 규칙 하나만 어기는 입력을 ok.md · ml_ok.md 에서 규칙마다 짓는다(규칙 하나를 풀면 그 셀의
#      사유가 바뀌어 RED). 경계 셀(`---a:` 키 뒤의 NEL — 위험 문자 검사도 비교와 같은 `\n---\n` 경계를
#      쓴다)과 N1 실측 재현(실제 doc-critic-web 두 사본의 description 을 안 닫힌 큰따옴표로 열어 tools 줄을
#      삼킨다)을 둔다.
#   V4 파일 전체 문자 금지 — agent 정의 파일(정본 · 배포 사본 · copy-of 사본 전부, 코퍼스에서 도출)은
#      어디에도 CR · NEL · U+2028 · U+2029 를 담지 않는다. 판정기가 보는 쌍 밖의 agent 파일, frontmatter 밖의
#      자리까지 바이트로 잰다 — 다른 락의 줄 기반 검사가 우연히 잡는 것에 기대지 않는다. 여기 두는 이유:
#      이 락이 이미 중복 락과 같은 코퍼스를 도출하고, agent 정의 자리의 정의(`variant_of.in_agent_scope`)가
#      이 판정기 한 곳에 있다. 검출기는 판정기와 한 정의(`variant_of.nonlf_breaks`)이고, 문자마다 검출 셀이
#      있다(검출 집합에서 문자 하나를 빼면 그 셀이 RED).
#   V3 범위 음성 셀 — agent 정의 밖(skill) 복제본에 마커를 달고 한 줄을 끼우면 관계는 서지만(전제로 잰다)
#      중복 락이 면제하지 않는다. 스크래치 git 루트에서 중복 락을 실제로 돌려 그 쌍의 위반 줄을 본다.
#      양의 짝: 같은 루트의 agent 정본 쌍(doc-critic ↔ doc-critic-web)은 면제된다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1
EXCLUDE_RE='/(fixtures|mocks|harness)/'
CORPUS="$(git ls-files --cached --others --exclude-standard -- 'plugins/*' 'shared/*' | grep -vE "$EXCLUDE_RE")"
FX_DIR="shared/tests/fixtures/variant_of"
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' "$CORPUS"
  git ls-files --cached --others --exclude-standard -- "$FX_DIR"
  exit 0
fi

. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
VO="$ROOT/shared/tests/variant_of.py"
TAB="$(printf '\t')"
TMPD="$(mktemp -d -t variant-of-XXXXXX)" || exit 1
[ -n "$TMPD" ] && [ -d "$TMPD" ] || exit 1
trap 'rm -rf "$TMPD"' EXIT

# ── V1 마커 전수 ─────────────────────────────────────────────────────────────
EXPECTED_VARIANTS="plugins/spec-distill/agents/doc-critic-web.md
shared/docreview/agents/doc-critic-web.md"
printf '%s\n' "$CORPUS" > "$TMPD/corpus.txt"
n_corpus="$(grep -c . "$TMPD/corpus.txt" || true)"
[ "${n_corpus:-0}" -ge 50 ] \
  && ok "V1: 코퍼스 ${n_corpus}건 도출 (중복 락과 같은 도출 · 붕괴 바닥 50)" \
  || no "V1: 코퍼스가 ${n_corpus:-0}건 — 도출이 깨졌다. 아래 전수 판정이 공허하다"
python3 "$VO" audit "$TMPD/corpus.txt" > "$TMPD/audit.txt"; arc=$?
assert_eq "$arc" "0" "V1: 감사가 정상 종료했다"
while IFS="$TAB" read -r p t v; do
  [ -n "$p" ] || continue
  if [ "$v" = "OK" ]; then
    ok "V1: $p → $t (agent 정의 자리 · 정본 대상 · 사슬 없음 · 관계 성립)"
  else
    no "V1: $p → $t 가 variant-of 계약을 어긴다 — $v"
  fi
done < "$TMPD/audit.txt"
got="$(cut -f1 "$TMPD/audit.txt" | sort)"
want="$(printf '%s\n' "$EXPECTED_VARIANTS" | sort)"
if [ "$got" = "$want" ]; then
  ok "V1: variant-of 마커 파일 집합 == 리터럴 목록 ($(printf '%s' "$got" | tr '\n' ' '))"
else
  no "V1: variant-of 마커 파일 집합이 목록과 다르다 — 감사=[$(printf '%s' "$got" | tr '\n' ' ')] 목록=[$(printf '%s' "$want" | tr '\n' ' ')]. 새 면제는 이 목록을 같은 커밋에서 고친다"
fi

# ── V2 판정기 음성 ───────────────────────────────────────────────────────────
FX="$ROOT/$FX_DIR"
res="$(python3 "$VO" check "$FX/ok.md" "$FX/base.md")"
assert_eq "$res" "OK${TAB}4" "V2(양성 대조): ok.md 는 관계가 선다 — name·description·tools(자유 키)가 달라도 끼운 4줄 하나"
n_neg=0
neg() {   # neg <변형 fixture> <기준 fixture> <기대 사유 접두>
  local out
  n_neg=$((n_neg+1))
  out="$(python3 "$VO" check "$FX/$1" "$FX/$2")"
  case "$out" in
    "FAIL${TAB}$3"*) ok "V2: $1 → FAIL ($3)" ;;
    *) no "V2: $1 이 기대 사유로 떨어지지 않는다 — '$out' (기대: FAIL $3…)" ;;
  esac
}
neg two_insertions.md base.md body_changed_beyond_one_insertion
neg deleted.md base.md body_changed_beyond_one_insertion
neg line_changed.md base.md body_changed_beyond_one_insertion
neg fm_value.md base.md frontmatter_value_differs:cost_class
neg fm_key_added.md base.md frontmatter_keys_differ:model
neg blank_insertion.md base.md no_insertion
neg identical.md base.md no_insertion
neg ok.md absent-target.md unreadable:
# 식별자 밖 키 — YAML 은 따옴표 · 콜론 앞 공백 키를 최상위 키로 읽는다(Task 3b 재리뷰 P4: `"maxTurns": 1` 이
# tools 블록에 흡수돼 관계가 OK 였다). 줄 문법이 그 모양을 받지 않는다.
neg fm_dq_key.md base.md frontmatter_unparsable:key_shape
neg fm_sq_key.md base.md frontmatter_unparsable:key_shape
neg fm_spacecolon_key.md base.md frontmatter_unparsable:key_shape
# 값 블록 — 여러 줄 값의 둘째 줄 이후만 다른 쌍(키 줄만 비교하는 퇴행이 GREEN 이던 축).
neg ml_value.md base_ml.md frontmatter_value_differs:input_slots
# 키로 못 읽는 컬럼-0 줄은 앞 블록에 흡수하지 않고 판정 불가다(흡수하면 명시 키 `? hooks` 가 tools 자유 블록에
# 숨어 통과한다 — PyYAML 은 최상위 hooks 로 읽는다). 중복 키도 같다(PyYAML 은 나중 값으로 조용히 덮는다).
neg fm_qmark_explicit.md base.md frontmatter_unparsable:key_shape
neg fm_flow_key.md base.md frontmatter_unparsable:key_shape
neg fm_unclosed_quote_key.md base.md frontmatter_unparsable:key_shape
neg fm_qmark_inline.md base.md frontmatter_unparsable:key_shape
neg fm_dup_key.md base.md frontmatter_unparsable:duplicate_key
# 자유 키 값을 여는 따옴표 · flow — 뒤따르는 컬럼-0 줄을 YAML 은 값 안으로 삼키는데 옛 판정기는 그 줄을 키로
# 읽었다(Task 7 재리뷰 N1 — `tools` 가 사라지면 agent 는 도구 전체를 상속한다). PyYAML 전제 셀은 아래 V2c.
neg fm_hide_tools_dq.md base.md frontmatter_unparsable:value_double_quote
neg fm_hide_tools_sq.md base.md frontmatter_unparsable:value_single_quote
neg fm_hide_tools_flow.md base.md frontmatter_unparsable:value_flow_mapping
neg fm_hide_color_dq.md base.md frontmatter_unparsable:value_double_quote
# 교차 대조만 잡는 셀 — `on:` 은 줄 문법 안의 키인데 PyYAML 은 문자열이 아니라 True 로 읽는다.
neg fm_yaml_boolkey.md base.md frontmatter_yaml_mismatch:non_string_key
[ "$n_neg" -ge 22 ] && ok "V2: 판정기 음성 ${n_neg}건을 태웠다" || no "V2: 음성이 ${n_neg}건뿐 — 셀이 사라졌다"
res_ml="$(python3 "$VO" check "$FX/ml_ok.md" "$FX/base_ml.md")"
assert_eq "$res_ml" "OK${TAB}4" "V2(양성 대조 — 여러 줄 값): 비-자유 키 input_slots 블록이 줄마다 같으면 관계가 선다"

# ── V2b 줄바꿈 축 — 문자마다 한 셀(Task 7 재리뷰 I1) ─────────────────────────────
# 셀은 ok.md 의 tools 줄에서 만든다: `tools: Read, WebSearch<문자>hooks: x`(탭은 다음 줄 `<탭>hooks: x`).
# 보이지 않는 문자를 fixture 파일에 박지 않고 여기서 이스케이프로 짓는다. 전제: PyYAML 은 줄바꿈 넷에서
# 최상위 hooks 를 읽는다 — 이 셀들이 가리키는 구멍이 실재한다는 증거다.
LB="$TMPD/lb"
python3 - "$FX/ok.md" "$LB" <<'PY'
import os, sys
src, d = sys.argv[1:3]
os.makedirs(d, exist_ok=True)
t = open(src, "rb").read().decode("utf-8")
anchor = "tools: Read, WebSearch\n"
assert t.count(anchor) == 1, "anchor"
for name, ch in (("cr", "\r"), ("nel", "\x85"), ("ls", chr(0x2028)), ("ps", chr(0x2029))):
    body = t.replace(anchor, "tools: Read, WebSearch" + ch + "hooks: x\n")
    open(os.path.join(d, name + ".md"), "wb").write(body.encode("utf-8"))
open(os.path.join(d, "tab.md"), "wb").write(t.replace(anchor, anchor + "\thooks: x\n").encode("utf-8"))
PY
yaml_top() {   # yaml_top <파일> <키> — PyYAML 이 frontmatter 최상위에서 읽은 그 키의 값(없으면 None)
  python3 -c 'import sys,yaml; t=open(sys.argv[1],"rb").read().decode("utf-8"); e=t.find("\n---\n",4); print(yaml.safe_load(t[4:e]).get(sys.argv[2]))' "$1" "$2" 2>&1 | tail -1
}
lb_neg() {   # lb_neg <이름> <기대 사유 전체>
  local out
  out="$(python3 "$VO" check "$LB/$1.md" "$FX/base.md")"
  if [ "$out" = "FAIL${TAB}$2" ]; then ok "V2b: $1 → FAIL ($2)"; else no "V2b: $1 이 기대 사유로 떨어지지 않는다 — '$out' (기대: FAIL $2)"; fi
}
for c in cr nel ls ps; do
  assert_eq "$(yaml_top "$LB/$c.md" hooks)" "x" "V2b 전제: $c — PyYAML 은 그 문자 뒤를 최상위 키 hooks 로 읽는다"
done
lb_neg cr frontmatter_nonlf_break:U+000D
lb_neg nel frontmatter_nonlf_break:U+0085
lb_neg ls frontmatter_nonlf_break:U+2028
lb_neg ps frontmatter_nonlf_break:U+2029
lb_neg tab frontmatter_tab_line
# 리뷰 실측 재현 — 실제 doc-critic-web 두 사본(정본 · 배포 사본)의 description 블록 마지막 연속줄 끝에
# NEL + 권한 모드 키. 사본은 스크래치에만 쓴다. 옛 판정기는 `OK 4` 였고 락 다섯이 GREEN 이었다.
RP="$TMPD/repro"
python3 - "$ROOT" "$RP" <<'PY'
import os, sys
root, d = sys.argv[1:3]
os.makedirs(d, exist_ok=True)
INJ = "\x85permissionMode: bypassPermissions"
for rel in ("shared/docreview/agents/doc-critic-web.md", "plugins/spec-distill/agents/doc-critic-web.md"):
    lines = open(os.path.join(root, rel), "rb").read().decode("utf-8").split("\n")
    end = lines.index("---", 1)
    i = next(j for j in range(1, end) if lines[j].startswith("description:"))
    last = i
    for j in range(i + 1, end):
        if lines[j][:1] not in (" ", "\t") and lines[j].strip():
            break
        if lines[j].strip():
            last = j
    assert last > i, rel
    lines[last] += INJ
    open(os.path.join(d, rel.replace("/", "__")), "wb").write("\n".join(lines).encode("utf-8"))
PY
n_rp=0
for f in "$RP"/*.md; do
  [ -f "$f" ] || continue
  n_rp=$((n_rp+1))
  assert_eq "$(yaml_top "$f" permissionMode)" "bypassPermissions" "V2b 재현 전제: $(basename "$f") — PyYAML 은 최상위 permissionMode 를 읽는다"
  res="$(python3 "$VO" check "$f" "$ROOT/shared/docreview/agents/doc-critic.md")"
  assert_eq "$res" "FAIL${TAB}frontmatter_nonlf_break:U+0085" "V2b 재현: $(basename "$f") ↔ doc-critic 정본 → 판정 불가"
done
assert_eq "$n_rp" "2" "V2b 재현: 실제 doc-critic-web 사본 둘을 모두 태웠다"

# ── V2c 줄 문법 — 규칙마다 한 셀 · 경계 셀 · N1 실측 재현 ─────────────────────────
# 전제 — V2 의 N1 fixture 넷을 PyYAML 은 숨긴 키 없이 읽는다(셀이 가리키는 구멍이 실재한다).
assert_eq "$(yaml_top "$FX/fm_hide_tools_dq.md" tools)" "None" "V2c 전제: fm_hide_tools_dq — PyYAML 최상위에 tools 가 없다"
assert_eq "$(yaml_top "$FX/fm_hide_tools_sq.md" tools)" "None" "V2c 전제: fm_hide_tools_sq — PyYAML 최상위에 tools 가 없다"
assert_eq "$(yaml_top "$FX/fm_hide_tools_flow.md" tools)" "None" "V2c 전제: fm_hide_tools_flow — PyYAML 최상위에 tools 가 없다"
assert_eq "$(yaml_top "$FX/fm_hide_color_dq.md" color)" "None" "V2c 전제: fm_hide_color_dq — PyYAML 최상위에 color 가 없다"
# 규칙마다 한 셀 — 그 규칙 하나만 어기는 입력. 기대 사유를 끝까지 잰다(규칙을 풀면 다른 규칙 · 교차 대조가
# 잡더라도 사유가 바뀌어 RED).
GR="$TMPD/gr"
python3 - "$FX/ok.md" "$FX/ml_ok.md" "$GR" > "$TMPD/gr.txt" <<'PY'
import os, sys
ok, ml, d = sys.argv[1:4]
os.makedirs(d, exist_ok=True)
t = open(ok, "rb").read().decode("utf-8")
m = open(ml, "rb").read().decode("utf-8")
def sub(src, old, new):
    assert src.count(old) == 1, old
    return src.replace(old, new)
COLOR = "color: blue\n"
DESC = "  variant_of.py 판정기 fixture — 변형(양성).\n"
cells = [
    ("key_shape", "base.md", sub(t, COLOR, '"color": blue\n')),
    ("duplicate_key", "base.md", sub(t, COLOR, COLOR + COLOR)),
    ("content_before_key", "base.md", sub(t, "---\nname:", "---\n  stray\nname:")),
    ("whitespace_line", "base.md", sub(t, COLOR, COLOR + "   \n")),
    ("block_indent", "base.md", sub(t, DESC, DESC[1:])),
    ("child_shape", "base_ml.md", sub(m, "    kind: repo_context\n", "    kind: repo_context\n  tag: extra\n")),
    ("child_value", "base_ml.md", sub(m, "    kind: artifact\n", '    kind: "artifact"\n')),
    ("value_continuation", "base.md", sub(t, COLOR, COLOR + "  more\n")),
    ("value_double_quote", "base.md", sub(t, COLOR, 'color: "blue"\n')),
    ("value_single_quote", "base.md", sub(t, COLOR, "color: 'blue'\n")),
    ("value_flow_mapping", "base.md", sub(t, COLOR, "color: {a: blue}\n")),
    ("value_flow_sequence", "base.md", sub(t, COLOR, "color: [blue]\n")),
    ("value_plain_shape", "base.md", sub(t, COLOR, "color: blue: sky\n")),
]
for rule, base, body in cells:
    open(os.path.join(d, rule + ".md"), "wb").write(body.encode("utf-8"))
    print("%s\t%s" % (rule, base))
PY
n_gr=0
while IFS="$TAB" read -r rule base; do
  [ -n "$rule" ] || continue
  n_gr=$((n_gr+1))
  res="$(python3 "$VO" check "$GR/$rule.md" "$FX/$base")"
  assert_eq "$res" "FAIL${TAB}frontmatter_unparsable:$rule" "V2c 규칙: $rule 하나만 어긴 입력 → 그 규칙의 사유"
done < "$TMPD/gr.txt"
assert_eq "$n_gr" "13" "V2c: 줄 문법 규칙 13개를 하나씩 태웠다"
# 경계 — 위험 문자 검사가 비교와 같은 `\n---\n` 경계를 쓴다. `---a:` 키 줄에서 멈추면 그 뒤의 NEL 을 못 보고
# 사유가 줄 문법(key_shape)으로 바뀐다(Task 7 재리뷰 n2).
python3 - "$FX/ok.md" "$TMPD/dash.md" <<'PY'
import sys
src, dst = sys.argv[1:3]
t = open(src, "rb").read().decode("utf-8")
for old, new in (("tools: Read, WebSearch\n", "tools: Read, WebSearch\n---a: 1\n"),
                 ("cost_class: low\n", "cost_class: low" + chr(0x85) + "hooks: x\n")):
    assert t.count(old) == 1, old
    t = t.replace(old, new)
open(dst, "wb").write(t.encode("utf-8"))
PY
assert_eq "$(yaml_top "$TMPD/dash.md" hooks)" "x" "V2c 경계 전제: PyYAML 은 `---a` 뒤의 NEL 다음을 최상위 키 hooks 로 읽는다"
assert_eq "$(python3 "$VO" check "$TMPD/dash.md" "$FX/base.md")" "FAIL${TAB}frontmatter_nonlf_break:U+0085" \
  "V2c 경계: \`---a:\` 키 줄 뒤의 NEL 도 위험 문자 검사가 본다"
# N1 실측 재현 — 실제 doc-critic-web 두 사본의 description 블록을 안 닫힌 큰따옴표 한 줄로 바꾸고 tools 줄 뒤에
# 들여쓴 닫는 따옴표를 둔다. YAML 은 tools 줄을 description 안으로 삼킨다. 옛 판정기는 `OK 4` 였다.
N1="$TMPD/n1"
python3 - "$ROOT" "$N1" <<'PY'
import os, sys
root, d = sys.argv[1:3]
os.makedirs(d, exist_ok=True)
for rel in ("shared/docreview/agents/doc-critic-web.md", "plugins/spec-distill/agents/doc-critic-web.md"):
    lines = open(os.path.join(root, rel), "rb").read().decode("utf-8").split("\n")
    end = lines.index("---", 1)
    i = next(j for j in range(1, end) if lines[j].startswith("description:"))
    j = i + 1
    while j < end and (lines[j] == "" or lines[j].startswith(" ")):
        j += 1
    lines[i:j] = ['description: "hidden web variant']
    k = next(x for x in range(1, len(lines)) if lines[x].startswith("tools:"))
    lines.insert(k + 1, '  "')
    open(os.path.join(d, rel.replace("/", "__")), "wb").write("\n".join(lines).encode("utf-8"))
PY
n_n1=0
for f in "$N1"/*.md; do
  [ -f "$f" ] || continue
  n_n1=$((n_n1+1))
  assert_eq "$(yaml_top "$f" tools)" "None" "V2c N1 재현 전제: $(basename "$f") — PyYAML 최상위에 tools 가 없다"
  assert_eq "$(python3 "$VO" check "$f" "$ROOT/shared/docreview/agents/doc-critic.md")" \
    "FAIL${TAB}frontmatter_unparsable:value_double_quote" "V2c N1 재현: $(basename "$f") ↔ doc-critic 정본 → 판정 불가"
done
assert_eq "$n_n1" "2" "V2c N1 재현: 실제 doc-critic-web 사본 둘을 모두 태웠다"

# 감사 함수의 FAIL 갈래 — 스크래치 코퍼스(경로 모양이 판정 근거라 상대경로 트리를 만든다).
A="$TMPD/audit-root"
mkdir -p "$A/shared/x/agents" "$A/plugins/y/skills/s"
with_marker() {   # with_marker <src> <대상> <dst> — 1행 뒤에 마커를 끼운 사본
  { head -1 "$1"; echo "# variant-of: $2"; tail -n +2 "$1"; } > "$3"
}
cp "$FX/base.md" "$A/shared/x/agents/base.md"
with_marker "$FX/ok.md" shared/x/agents/base.md "$A/shared/x/agents/var.md"
with_marker "$FX/ok.md" shared/x/agents/base.md "$A/plugins/y/skills/s/SKILL.md"
with_marker "$FX/ok.md" plugins/y/skills/s/base.md "$A/shared/x/agents/badtarget.md"
with_marker "$FX/ok.md" shared/x/agents/nope.md "$A/shared/x/agents/missing.md"
with_marker "$FX/ok.md" shared/x/agents/var.md "$A/shared/x/agents/chain.md"
with_marker "$FX/line_changed.md" shared/x/agents/base.md "$A/shared/x/agents/broken.md"
( cd "$A" && find shared plugins -type f | sort > "$TMPD/a-corpus.txt" \
    && python3 "$VO" audit "$TMPD/a-corpus.txt" > "$TMPD/a-audit.txt" )
verdict_of() { awk -F "$TAB" -v p="$1" '$1==p {print $3}' "$TMPD/a-audit.txt"; }
assert_eq "$(verdict_of shared/x/agents/var.md)" "OK" "V2(감사 양성): 정본 agent 자리의 변형은 OK"
assert_eq "$(verdict_of plugins/y/skills/s/SKILL.md)" "FAIL:out_of_scope" "V2(감사): agent 정의 밖(skill)의 마커 → out_of_scope"
assert_eq "$(verdict_of shared/x/agents/badtarget.md)" "FAIL:target_not_canonical_agent" "V2(감사): 대상이 shared/ agent 정본이 아님 → target_not_canonical_agent"
assert_eq "$(verdict_of shared/x/agents/missing.md)" "FAIL:target_missing" "V2(감사): 대상 부재 → target_missing"
assert_eq "$(verdict_of shared/x/agents/chain.md)" "FAIL:target_is_variant" "V2(감사): 대상이 또 변형 → target_is_variant (사슬 금지)"
case "$(verdict_of shared/x/agents/broken.md)" in
  FAIL:relation:body_changed_beyond_one_insertion*) ok "V2(감사): 관계가 깨진 변형 → relation 사유" ;;
  *) no "V2(감사): 관계가 깨진 변형이 relation 사유로 떨어지지 않는다 — '$(verdict_of shared/x/agents/broken.md)'" ;;
esac

# ── V3 범위 음성 셀 — 중복 락을 스크래치 git 루트에서 실제로 돈다 ──────────────────
S="$TMPD/dup-root"
mkdir -p "$S/shared/tests" "$S/shared/docreview/agents" "$S/plugins/x/skills/a" "$S/plugins/x/skills/b"
cp "$ROOT/shared/tests/test_no_new_duplication.sh" "$ROOT/shared/tests/assert.sh" "$ROOT/shared/tests/variant_of.py" "$S/shared/tests/"
cp "$ROOT/shared/docreview/agents/doc-critic.md" "$ROOT/shared/docreview/agents/doc-critic-web.md" "$S/shared/docreview/agents/"
SRC="$ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md"
cp "$SRC" "$S/plugins/x/skills/a/SKILL.md"
# 복제본 — 마커 + name 변경 + 본문 첫 `## ` 앞 두 줄 끼움(리뷰의 probe 와 같은 모양)
python3 - "$SRC" "$S/plugins/x/skills/b/SKILL.md" <<'PY'
import sys
src, dst = sys.argv[1:3]
lines = open(src, encoding="utf-8").read().split("\n")
assert lines[0] == "---"
out = [lines[0], "# variant-of: plugins/x/skills/a/SKILL.md"]
out += ["name: reviewing-spec-copy" if ln.startswith("name:") else ln for ln in lines[1:]]
body_start = out.index("---", 1) + 1
for i in range(body_start, len(out)):
    if out[i].startswith("## "):
        out[i:i] = ["끼운 한 줄.", ""]
        break
open(dst, "w", encoding="utf-8").write("\n".join(out))
PY
pre="$(python3 "$VO" check "$S/plugins/x/skills/b/SKILL.md" "$S/plugins/x/skills/a/SKILL.md")"
assert_grep "$pre" '^OK' "V3 전제: skill 복제본은 관계가 선다 (${pre}) — 면제되지 않는 이유는 범위 하나다"
pre_a="$(python3 "$VO" check "$S/shared/docreview/agents/doc-critic-web.md" "$S/shared/docreview/agents/doc-critic.md")"
assert_grep "$pre_a" '^OK' "V3 전제: agent 정본 쌍도 관계가 선다 (${pre_a})"
( cd "$S" && git init -q . && bash shared/tests/test_no_new_duplication.sh ) > "$TMPD/v3.out" 2>&1
if grep -qF '20줄 검사: plugins/x/skills/a/SKILL.md ↔ plugins/x/skills/b/SKILL.md' "$TMPD/v3.out"; then
  ok "V3: agent 정의 밖의 variant-of 쌍은 면제되지 않는다 (중복 락이 그 쌍을 위반으로 낸다)"
else
  no "V3: skill 복제본 쌍이 중복 락에서 면제됐다 — 면제 ③ 에 범위가 없다"
  sed -n '1,12p' "$TMPD/v3.out"
fi
if grep -F '20줄 검사:' "$TMPD/v3.out" | grep -F 'doc-critic-web.md' | grep -qF 'doc-critic.md'; then
  no "V3(양의 짝): agent 정본 쌍(doc-critic ↔ doc-critic-web)이 면제되지 않았다 — 범위가 너무 좁다"
else
  ok "V3(양의 짝): agent 정본 쌍은 같은 루트에서 면제된다 (위 skill 쌍 위반 줄이 스캔이 돌았음을 증명한다)"
fi

# ── V4 파일 전체 문자 금지 — agent 정의 파일 전부, 바이트로 ────────────────────────
# 대상은 V1 과 같은 코퍼스에서 `in_agent_scope` 로 도출한다(이름을 적지 않는다). 파일은 바이트로 읽는다 —
# 텍스트 모드의 universal newline 은 CR 을 LF 로 바꿔 보이지 않게 한다.
python3 - "$ROOT" "$TMPD/corpus.txt" > "$TMPD/v4.txt" <<'PY'
import sys
root, corpus = sys.argv[1:3]
sys.path.insert(0, root + "/shared/tests")
import variant_of
n = 0
for p in open(corpus, encoding="utf-8").read().splitlines():
    if not variant_of.in_agent_scope(p):
        continue
    n += 1
    try:
        t = open(root + "/" + p, "rb").read().decode("utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print("%s\tunreadable:%s" % (p, type(exc).__name__))
        continue
    print("%s\t%s" % (p, ",".join(variant_of.nonlf_breaks(t)) or "clean"))
print("COUNT\t%d" % n)
PY
n_agents="$(awk -F "$TAB" '$1=="COUNT"{print $2}' "$TMPD/v4.txt")"
[ "${n_agents:-0}" -ge 20 ] \
  && ok "V4: agent 정의 파일 ${n_agents}개를 바이트로 읽었다 (코퍼스에서 도출 · 하한 20)" \
  || no "V4: agent 정의 파일을 ${n_agents:-0}개만 읽었다 — 도출이 깨졌다. 아래 부재 판정이 공허하다"
dirty="$(awk -F "$TAB" '$1!="COUNT" && $2!="clean"' "$TMPD/v4.txt")"
if [ -z "$dirty" ]; then
  ok "V4: agent 정의 파일 어디에도 CR · NEL · U+2028 · U+2029 가 없다"
else
  no "V4: agent 정의 파일에 LF 밖 줄바꿈 문자가 있다 — $(printf '%s' "$dirty" | tr '\n' ' ')"
fi
# 검출 셀 — 문자마다 본문(frontmatter 밖)에만 그 문자를 둔 스크래치 파일을 같은 검출기에 태운다. 기대 목록은
# 이 락의 진술이다(검출기의 집합에서 문자 하나를 빼면 그 셀이 RED).
python3 - "$ROOT" "$TMPD/v4cells" > "$TMPD/v4cells.txt" <<'PY'
import os, sys
root, d = sys.argv[1:3]
sys.path.insert(0, root + "/shared/tests")
import variant_of
os.makedirs(d, exist_ok=True)
for want, cp in (("U+000D", 0x0D), ("U+0085", 0x85), ("U+2028", 0x2028), ("U+2029", 0x2029)):
    p = os.path.join(d, want + ".md")
    open(p, "wb").write(("---\nname: x\n---\n\n본문" + chr(cp) + "숨김\n").encode("utf-8"))
    got = variant_of.nonlf_breaks(open(p, "rb").read().decode("utf-8"))
    print("%s\t%s" % (want, ",".join(got) or "none"))
PY
n_v4c=0
while IFS="$TAB" read -r want got; do
  [ -n "$want" ] || continue
  n_v4c=$((n_v4c+1))
  assert_eq "$got" "$want" "V4 검출 셀: 본문의 $want 하나를 검출기(variant_of.nonlf_breaks)가 잡는다"
done < "$TMPD/v4cells.txt"
assert_eq "$n_v4c" "4" "V4 검출 셀: 문자 넷을 모두 태웠다"
finish
