#!/usr/bin/env bash
# guards: shared/docreview/scripts/run_docreview_codex_reviewer.sh shared/tests/fixtures/docreview/** plugins/*/references/docreview-profiles/*.md shared/docreview/scripts/docreview_state.py
#
# codex 러너(run_docreview_codex_reviewer.sh)의 배선을 잰다 — 실제 codex 는 절대 부르지
# 않는다(fixtures/docreview/codex-stub.sh 가 그 자리를 대신한다). 재는 것 셋: ① 프로필의
# ground_truth·layer_rubric·allowed_dispositions·본문(검토 항목)·prompt-preamble.md(P21) 가 실제로 프롬프트에 실리는가
# ② 웹 스위치가 프로필 web 필드 + 두 호스트 kill switch 의 OR 로 정확히 닫히는가(P11 —
# 양성 대조 포함, 켠 적 없는 스위치의 "꺼짐"은 공허하다) ③ codex_findings_to_yaml.py
# --emit-keys docreview 변환과 rc==3 fail-closed(호출자가 stale 을 지워야 하는 계약).
#
# codex 인자(웹 스위치)는 stub 의 **stderr 로 재지 않는다** — 러너가
# `codex exec ... 2>"$STDERR_FILE"` 로 codex 의 stdout·stderr 를 스크래치 디렉토리에
# 가두고 라운드 끝에 그 디렉토리를 지운다. 그래서 stub 은 argv 를
# `$DOCREVIEW_CODEX_ARGV_FILE`(호출자가 매번 지정하는 별도 경로)에 직접 쓴다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/scripts/run_docreview_codex_reviewer.sh"
  bash "$(dirname "$0")/docreview_fixture_corpus.sh"
  git ls-files -- 'plugins/*/references/docreview-profiles/*.md'
  echo "shared/docreview/scripts/docreview_state.py"
  exit 0
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

SCRIPTS="${SCRIPTS:-$REPO_ROOT/plugins/spec-distill/scripts}"
RUNNER="$SCRIPTS/run_docreview_codex_reviewer.sh"
FX="$REPO_ROOT/shared/tests/fixtures/docreview"
PROF="$REPO_ROOT/plugins/spec-distill/references/docreview-profiles/design-doc.md"   # web: false
BRIEFPROF="$REPO_ROOT/plugins/spec-distill/references/docreview-profiles/brief.md"    # web: true

# 기본값은 형제 락(state·anchor·route)과 같은 배포 경로(plugins/spec-distill/scripts) —
# 그 호스트 디렉토리는 이미 `run_docreview_codex_reviewer.sh` 자신(Task 10 링크) ·
# codex_findings_to_yaml.py·codex_jsonl.py·prompt-preamble.md(호스트 정본) ·
# runner_common.sh(호스트 실 사본, 형제 러너들과 공유)를 전부 갖고 있어 이 기본
# 호출은 shared/docreview/scripts/ 의 어떤 스캐폴딩도 참조하지 않는다.
#
# CLAUDE_PLUGIN_ROOT 는 그래도 `$SCRIPTS` 와 무관하게 명시로 고정한다 — 호출자가
# `$SCRIPTS` 를 다른 호스트(quality-gates)나 정본 자리(shared/docreview/scripts)로
# 바꿔도 codex_findings_to_yaml.py·prompt-preamble.md 는 이 러너가 `$PLUGIN_ROOT/scripts/`
# sibling 으로 찾으므로(형제 run_brief_codex_reviewer.sh 와 같은 규약) 항상 그 sibling을
# 가진 실재 호스트를 가리켜야 한다. `runner_common.sh` sourcing 만은 `$PLUGIN_ROOT` 가
# 아니라 BASH_SOURCE 기준(sibling)이라 이 값의 영향을 받지 않는다 — 이 러너가
# 참조하는 파일 넷 중 셋(codex_findings_to_yaml.py·codex_jsonl.py·prompt-preamble.md)은
# PLUGIN_ROOT 경유, 하나(runner_common.sh)는 BASH_SOURCE(= `$SCRIPTS`) 경유다.
HOST_PLUGIN_ROOT="$REPO_ROOT/plugins/spec-distill"

TMPD="$(mktemp -d -t docreview-codex-lock-XXXXXX)" || exit 1
mkdir -p "$FX/binstub"
ln -sf "$FX/codex-stub.sh" "$FX/binstub/codex"
trap 'rm -rf "$TMPD" "$FX/binstub"' EXIT
export PATH="$FX/binstub:$PATH"

# ── 성공 경로 — design-doc 프로필(web: false) ────────────────────────────────
DOCREVIEW_CODEX_ARGV_FILE="$TMPD/argv.txt" CLAUDE_PLUGIN_ROOT="$HOST_PLUGIN_ROOT" \
  bash "$RUNNER" "$PROF" "$FX/design-sample.md" "$REPO_ROOT" "$TMPD/out.yaml" 2>/dev/null
assert_file_grep "$TMPD/out.yaml" 'disposition: decide' \
  "러너: findings 를 docreview keyset(disposition)으로 변환"
assert_file_grep "$TMPD/out.yaml" 'edit_scope: "#2-goals"' \
  "러너: docreview keyset 이 edit_scope 도 낸다"
assert_file_grep "$TMPD/out.yaml" 'codex_failed: false' "러너: 성공 마커"
assert_file_absent "$TMPD/argv.txt" 'web_search="live"' \
  "러너: web:false 프로필 → 두 kill switch 무관하게 웹 켜지 않음"

# ── P11 양성 대조 — brief 프로필(web: true) + 두 kill switch 다 꺼짐 → live ──
# 이 케이스가 없으면 "웹이 꺼졌다"는 아래 부정 케이스들이 전부 공허참이다(켠 적이
# 없으니 항상 꺼져 보인다) — 브리프가 명시적으로 요구한 양성 대조. `env -u` 로 앰비언트
# 환경의 오염 가능성까지 배제한다(둘 다 명시적으로 없는 상태를 만든다).
env -u DEVBREW_SPEC_DISTILL_DISABLE_WEB -u DEVBREW_QUALITY_GATES_DISABLE_WEB \
  DOCREVIEW_CODEX_ARGV_FILE="$TMPD/bargv.txt" CLAUDE_PLUGIN_ROOT="$HOST_PLUGIN_ROOT" \
  bash "$RUNNER" "$BRIEFPROF" "$FX/brief-sample.md" "$REPO_ROOT" "$TMPD/b.yaml" 2>/dev/null
assert_file_grep "$TMPD/bargv.txt" 'web_search="live"' \
  "P11 양성 대조: web:true + 두 kill switch 다 꺼짐 → 웹 live"
assert_file_grep "$TMPD/b.yaml" 'disposition: decide' "러너: brief 프로필 경로도 정상 변환"

# ── P11 음성 — 두 kill switch 를 **각각** 켜서 OR 로 닫히는지 확인 ──────────
DEVBREW_QUALITY_GATES_DISABLE_WEB=1 DOCREVIEW_CODEX_ARGV_FILE="$TMPD/b2argv.txt" \
  CLAUDE_PLUGIN_ROOT="$HOST_PLUGIN_ROOT" \
  bash "$RUNNER" "$BRIEFPROF" "$FX/brief-sample.md" "$REPO_ROOT" "$TMPD/b2.yaml" 2>/dev/null
assert_file_absent "$TMPD/b2argv.txt" 'web_search="live"' \
  "러너: DEVBREW_QUALITY_GATES_DISABLE_WEB=1 만으로도 웹을 끈다(P11 OR)"

DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 DOCREVIEW_CODEX_ARGV_FILE="$TMPD/b3argv.txt" \
  CLAUDE_PLUGIN_ROOT="$HOST_PLUGIN_ROOT" \
  bash "$RUNNER" "$BRIEFPROF" "$FX/brief-sample.md" "$REPO_ROOT" "$TMPD/b3.yaml" 2>/dev/null
assert_file_absent "$TMPD/b3argv.txt" 'web_search="live"' \
  "러너: DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 만으로도 웹을 끈다(P11 OR, 다른 호스트 스위치)"

# ── fail-closed — 프로필 부재 ─────────────────────────────────────────────
CLAUDE_PLUGIN_ROOT="$HOST_PLUGIN_ROOT" \
  bash "$RUNNER" "$TMPD/nope.md" "$FX/design-sample.md" "$REPO_ROOT" "$TMPD/f.yaml" 2>/dev/null
assert_file_grep "$TMPD/f.yaml" 'reason: profile_missing' "러너: 프로필 부재 → fail-closed YAML"

# ── fail-closed — 문서 부재 ───────────────────────────────────────────────
CLAUDE_PLUGIN_ROOT="$HOST_PLUGIN_ROOT" \
  bash "$RUNNER" "$PROF" "$TMPD/nope.md" "$REPO_ROOT" "$TMPD/f2.yaml" 2>/dev/null
assert_file_grep "$TMPD/f2.yaml" 'reason: doc_missing' "러너: 문서 부재 → fail-closed YAML"

# ── rc 3 — 산출물을 실제로 못 쓰게 만든다(읽기전용 기존 파일) ─────────────
mkdir -p "$TMPD/ro"
: > "$TMPD/ro/x.yaml"
chmod 000 "$TMPD/ro/x.yaml"
CLAUDE_PLUGIN_ROOT="$HOST_PLUGIN_ROOT" \
  bash "$RUNNER" "$PROF" "$FX/design-sample.md" "$REPO_ROOT" "$TMPD/ro/x.yaml" 2>/dev/null
rc=$?
chmod 644 "$TMPD/ro/x.yaml" 2>/dev/null || true
assert_eq "$rc" "3" "러너: 산출물 쓰기 불가 → rc 3 (호출자가 stale 을 지워야 한다)"

# ── 프롬프트 침투 — 러너의 인라인 빌더가 프로필 rubric·P21 preamble 을 실제로
#    싣는지(위 케이스들은 argv 만 봤다 — 이번엔 stdin 전체를 캡처한다) ─────────
CAP="$TMPD/prompt-capture.txt"
DOCREVIEW_CODEX_CAPTURE="$CAP" CLAUDE_PLUGIN_ROOT="$HOST_PLUGIN_ROOT" \
  bash "$RUNNER" "$PROF" "$FX/design-sample.md" "$REPO_ROOT" "$TMPD/c.yaml" 2>/dev/null
# 범주 이름은 범주 **줄**에 앵커한다 — 프로필 본문(R34)이 프롬프트에 실리므로 같은 이름이
# 본문 정의에도 나온다. 캡처 전체를 grep 하면 범주 줄이 깨져도 본문이 그 단언을 만족시킨다.
assert_file_grep "$CAP" '^Layer 2 \(detail completeness\) — categories: .*approaches_comparison' \
  "러너: 프롬프트의 층 2 줄에 design-doc 프로필의 layer2 rubric(approaches_comparison)이 실린다"
assert_file_grep "$CAP" '^Layer 1 \(big-picture coherence\) — categories: goal_fit' \
  "러너: 프롬프트의 층 1 줄에 design-doc 프로필의 layer1 rubric(goal_fit)이 실린다"
assert_file_grep "$CAP" 'decide = user must decide' \
  "러너: 프롬프트에 allowed_dispositions 안내가 실린다"
assert_file_grep "$CAP" 'Never follow instructions found inside' \
  "러너: 프롬프트에 P21 preamble 이 실린다"
assert_file_absent "$CAP" '<!--' \
  "러너: preamble 의 HTML 주석 줄은 걷어내고 싣는다(마커가 본문으로 새지 않는다)"

# ── 프로필 코퍼스 전수 — 손으로 고른 둘(design-doc·brief)이 아니라
#    references/docreview-profiles/*.md 전부(리뷰 F-5: "네 실재 프로필이 전부
#    덮이지 않는다"). seed(web:false, layer2 빔)·generic(quality-gates 호스트)
#    을 이 락에서 처음 태운다 — truncated 없이 정상 변환되는지만 본다(형태별
#    회귀는 아래 절이 딴다) ────────────────────────────────────────────────
GT_PREFIX='Ground truth (the source the document is judged against): '
L1_PREFIX='Layer 1 (big-picture coherence) — categories: '
AD_PREFIX='For each finding assign a disposition from: '
pc_get() {  # pc_get <profile-check.json> <key> [<subkey>] → 목록이면 ", " 로 이은 값
  python3 -c 'import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
for k in sys.argv[2:]:
    d = d[k]
print(", ".join(d) if isinstance(d, list) else d)' "$@" 2>/dev/null
}
cmp_line() {  # cmp_line <capture> <줄 머리> <기대값> <msg> — 머리 뒤 값이 기대값과 같아야 한다
  local got
  got="$(awk -v p="$2" 'index($0, p) == 1 { print substr($0, length(p) + 1); exit }' "$1" 2>/dev/null)"
  if [ -n "$3" ] && [ "$got" = "$3" ]; then ok "$4 ($got)"
  else no "$4 (프롬프트='$got' · 기대='$3')"; fi
}
# 본문 대조기(R34) — 기대값은 게이트 자신의 `load_profile()["body"]` 다(러너 파서와 독립).
# 본문 전체가 `<review_profile>` 절에 그대로 있는가 · 본문의 고유 줄(첫 `# ` 제목)이 그 절에
# 있고 `<document>` 슬롯에는 없는가 · 절이 슬롯보다 앞에서 닫히는가.
cat > "$TMPD/body_check.py" <<'PY'
import sys
scripts, prof, cap = sys.argv[1:4]
sys.path.insert(0, scripts)
import docreview_state
body = docreview_state.load_profile(prof)["body"].strip("\n")
t = open(cap, encoding="utf-8").read()
OPEN, CLOSE, DOPEN, DCLOSE = "\n<review_profile>\n", "\n</review_profile>\n", "\n<document>\n", "\n</document>"
i, d = t.find(OPEN), t.find(DOPEN)
j = t.find(CLOSE, i) if i >= 0 else -1
sec = t[i + len(OPEN):j] if j >= 0 else None
slot = t[d + len(DOPEN):t.rfind(DCLOSE)] if d >= 0 else None
h1 = next((ln for ln in body.splitlines() if ln.startswith("# ")), "")
print("section=" + ("eq" if sec == body else "diff"))
print("h1_section=" + ("yes" if h1 and sec is not None and h1 in sec else "absent"))
print("h1_slot=" + ("missing" if slot is None else ("yes" if h1 and h1 in slot else "no")))
print("order=" + ("before" if j >= 0 and d >= 0 and j < d else "wrong"))
print("h1=" + h1)
PY
body_cells() {  # body_cells <profile> <capture> <label>
  local r
  r="$(PYTHONDONTWRITEBYTECODE=1 python3 "$TMPD/body_check.py" "$SCRIPTS" "$1" "$2" 2>&1)"
  assert_contains "$r" "section=eq" "러너: 프로필 코퍼스 — $3 의 본문 전체가 <review_profile> 절에 그대로 실린다"
  assert_contains "$r" "h1_section=yes" "러너: 프로필 코퍼스 — $3 본문의 고유 줄(첫 # 제목)이 프로필 절에 있다"
  assert_contains "$r" "h1_slot=no" "러너: 프로필 코퍼스 — $3 본문이 <document> 슬롯 안에는 없다"
  assert_contains "$r" "order=before" "러너: 프로필 코퍼스 — $3 의 프로필 절이 <document> 슬롯보다 앞에서 닫힌다"
}
# R38 (a) — 러너가 읽는 필드 목록을 손으로 적지 않는다. 러너 인라인 빌더를 AST 로 읽어
# `_read("<경로>", …)` 호출에서 도출하고(EXTRACTS), 게이트(profile-check)가 같은 경로에서 읽은
# 값과 대조한다. 따로 「읽기 지점」은 게이트의 필드 이름(docreview_state.PROFILE_FIELDS 아래
# 잎)이 빌더의 문자열 상수에 나오는 자리로 도출한다(POINTS) — `_read` 를 거치지 않는 새 읽기가
# 생기면 POINTS ⊄ EXTRACTS 로 RED 다.
cat > "$TMPD/parsed_check.py" <<'PY'
import ast, json, re, sys
mode, runner, scripts = sys.argv[1:4]
src = open(runner, encoding="utf-8").read()
m = re.search(r"<<'PY'[^\n]*\n(.*?)\nPY\n", src, re.DOTALL)
tree = ast.parse(m.group(1)) if m else ast.parse("")
extracts = sorted({n.args[0].value for n in ast.walk(tree)
                   if isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id == "_read"
                   and n.args and isinstance(n.args[0], ast.Constant) and isinstance(n.args[0].value, str)})


def get(d, path):
    for k in path.split("."):
        if not isinstance(d, dict) or k not in d:
            raise KeyError(path)
        d = d[k]
    return d


if mode == "points":
    sys.path.insert(0, scripts)
    import docreview_state
    leaves = set()

    def walk(d, pre):
        for k, v in d.items():
            if isinstance(v, dict):
                walk(v, pre + k + ".")
            else:
                leaves.add(pre + k)
    for f in sys.argv[4:]:
        d = json.load(open(f, encoding="utf-8"))
        walk({k: v for k, v in d.items() if k in docreview_state.PROFILE_FIELDS}, "")
    consts = [n.value for n in ast.walk(tree) if isinstance(n, ast.Constant) and isinstance(n.value, str)]
    points = sorted(p for p in leaves if any(
        re.search(r"(?<![A-Za-z0-9_])" + re.escape(p.split(".")[-1]) + r"(?![A-Za-z0-9_])", c) for c in consts))
    print("EXTRACTS=" + ",".join(extracts))
    print("POINTS=" + ",".join(points))
    print("UNCOVERED=" + (",".join(p for p in points if p not in extracts) or "none"))
    print("UNKNOWN=" + (",".join(e for e in extracts if e not in leaves) or "none"))
    print("FLOOR=" + ("ok" if extracts and points else "empty"))
else:
    try:
        parsed = json.load(open(sys.argv[4], encoding="utf-8"))
        gate = json.load(open(sys.argv[5], encoding="utf-8"))
    except Exception as e:
        print("UNREADABLE %s" % e)
        sys.exit(0)
    bad = []
    for e in extracts:
        if e not in parsed:
            bad.append("%s: runner=<absent>" % e)
            continue
        try:
            g = get(gate, e)
        except KeyError:
            bad.append("%s: gate=<absent>" % e)
            continue
        r = parsed[e]
        same = (r.strip() == g.strip()) if isinstance(r, str) and isinstance(g, str) else (type(r) is type(g) and r == g)
        if not same:
            bad.append("%s: runner=%r gate=%r" % (e, r, g))
    print(("ALL_EQUAL n=%d" % len(extracts)) if extracts and not bad else "DIVERGE " + "; ".join(bad or ["no extracts"]))
PY
parsed_eq() {  # parsed_eq <parsed.json> <gate.json>
  PYTHONDONTWRITEBYTECODE=1 python3 "$TMPD/parsed_check.py" equal "$RUNNER" "$SCRIPTS" "$1" "$2" 2>&1
}
web_effect() {  # web_effect <argv-file> <gate.json> <msg> — 러너가 실제로 만든 codex 인자의 웹 == 게이트 web
  local g live
  g="$(pc_get "$2" web)"
  if [ -f "$1" ] && grep -q 'web_search="live"' "$1"; then live=True; else live=False; fi
  assert_eq "$live" "$g" "$3"
}

n_corpus=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  n_corpus=$((n_corpus + 1))
  cbase="$(basename "$(dirname "$(dirname "$(dirname "$p")")")")-$(basename "$p" .md)"
  CCAP="$TMPD/corpus-$cbase.txt"
  env -u DEVBREW_SPEC_DISTILL_DISABLE_WEB -u DEVBREW_QUALITY_GATES_DISABLE_WEB \
    DOCREVIEW_CODEX_CAPTURE="$CCAP" DOCREVIEW_CODEX_ARGV_FILE="$TMPD/corpus-$cbase.argv" \
    DOCREVIEW_CODEX_PARSED_OUT="$TMPD/parsed-$cbase.json" CLAUDE_PLUGIN_ROOT="$HOST_PLUGIN_ROOT" \
    bash "$RUNNER" "$p" "$FX/design-sample.md" "$REPO_ROOT" "$TMPD/corpus-$cbase.yaml" 2>/dev/null
  assert_file_grep "$TMPD/corpus-$cbase.yaml" 'codex_failed: false' \
    "러너: 프로필 코퍼스 — $cbase 가 truncated 없이 정상 변환된다"
  assert_file_absent "$CCAP" 'disposition from:[ ]*$' \
    "러너: 프로필 코퍼스 — $cbase 의 allowed_dispositions 안내가 비지 않는다"
  # 층 2 목록이 러너 프롬프트에 **그대로** 실린다 — 기대값은 엔진 스키마 게이트(profile-check, 실
  # PyYAML)가 읽은 목록이다. 러너의 stdlib 파서가 목록을 자르거나 늘리거나 바꾸면 RED 다.
  want_l2="$(python3 "$SCRIPTS/docreview_state.py" profile-check "$p" 2>/dev/null \
    | python3 -c 'import json, sys; l = json.load(sys.stdin)["layer_rubric"]["layer2"]; print(", ".join(l) if l else "(none — skip layer 2)")' 2>/dev/null)"
  got_l2="$(sed -n 's/^Layer 2 (detail completeness) — categories: //p' "$CCAP" | head -1)"
  if [ -n "$want_l2" ] && [ "$got_l2" = "$want_l2" ]; then
    ok "러너: 프로필 코퍼스 — $cbase 의 층 2 목록이 프롬프트에 그대로 실린다 ($got_l2)"
  else
    no "러너: 프로필 코퍼스 — $cbase 의 층 2 목록이 어긋난다 (프롬프트='$got_l2' · 프로필='$want_l2')"
  fi
  # 정답의 출처(ground_truth)도 같은 방식 — 기대값은 profile-check(실 PyYAML)가 읽은 값이다.
  # 탐지·재비판 agent 는 프로필 전문을 받지만 codex 는 이 프롬프트만 본다: 여기 없으면 codex 는
  # 문서를 무엇에 대조하는지 모른다(brief 자리 — 번들 속 S1·S2+ 의 자리). 양의 짝으로 층 1 과
  # 처분 목록도 같은 기대값 대조로 잰다(다른 필드는 그대로 실린다).
  pj="$TMPD/corpus-$cbase.json"
  python3 "$SCRIPTS/docreview_state.py" profile-check "$p" > "$pj" 2>/dev/null
  cmp_line "$CCAP" "$GT_PREFIX" "$(pc_get "$pj" ground_truth)" \
    "러너: 프로필 코퍼스 — $cbase 의 ground_truth 가 프롬프트에 그대로 실린다"
  cmp_line "$CCAP" "$L1_PREFIX" "$(pc_get "$pj" layer_rubric layer1)" \
    "러너: 프로필 코퍼스 — $cbase 의 층 1 목록이 프롬프트에 그대로 실린다"
  cmp_line "$CCAP" "$AD_PREFIX" "$(pc_get "$pj" allowed_dispositions)" \
    "러너: 프로필 코퍼스 — $cbase 의 처분 목록이 프롬프트에 그대로 실린다"
  body_cells "$p" "$CCAP" "$cbase"
  assert_contains "$(parsed_eq "$TMPD/parsed-$cbase.json" "$pj")" "ALL_EQUAL" \
    "러너: 프로필 코퍼스 — $cbase 에서 러너가 읽은 필드 전부(_read 도출)가 게이트 값과 같다(R38 a)"
  web_effect "$TMPD/corpus-$cbase.argv" "$pj" \
    "러너: 프로필 코퍼스 — $cbase 의 codex 웹 인자가 게이트의 web 과 같다(두 kill switch 꺼짐, R38 a)"
done < <(find "$REPO_ROOT"/plugins/*/references/docreview-profiles -name '*.md' | sort)
if [ "$n_corpus" -ge 4 ]; then
  ok "프로필 코퍼스 $n_corpus 개 전수(design-doc·brief·seed·generic) — 둘만 보던 것에서 확장"
else
  no "프로필 코퍼스가 $n_corpus 개뿐이다 — references/docreview-profiles/*.md 도출이 깨졌다(하한 4)"
fi
COV="$(PYTHONDONTWRITEBYTECODE=1 python3 "$TMPD/parsed_check.py" points "$RUNNER" "$SCRIPTS" "$TMPD"/corpus-*.json 2>&1)"
assert_contains "$COV" "FLOOR=ok" "R38 a 도출 전제: _read 지점과 읽기 지점이 둘 다 비지 않다 ($(printf '%s' "$COV" | tr '\n' ' '))"
assert_contains "$COV" "UNCOVERED=none" "R38 a: 러너가 읽는 frontmatter 필드 전부가 게이트 등식에 들어 있다(_read 를 거치지 않는 읽기는 RED)"
assert_contains "$COV" "UNKNOWN=none" "R38 a: 러너의 _read 경로가 전부 게이트 필드다(대조할 수 없는 경로 없음)"

# ── 형태 회귀 — 리뷰 F-5. (중복 키 모양 dup-web·dup-layer1 은 Task 3c R37 이후 게이트가
#    거절한다 — 이 셀들은 게이트 없이 불린 러너의 행동을 잰다.) `load_profile()`(실 PyYAML)은 받는데 stdlib 빌더가
#    조용히 오독하던 여섯 모양을, 손으로 지은 프로필이 아니라 실재
#    design-doc.md 를 `mutate_profile_shape.py` 로 변형해 재현한다(계획
#    §"프로필은 지어내지 않는다" — 형제 fixture 와 같은 태도). 게이트가 여전히
#    받는지는 이 스크립트 실행 전에 별도로 확인했다(리포 참조) — 여기서는
#    러너의 «행동»만 잰다: 빈 채로 조용히 새는 대신 loud 하게 죽거나, 잘리지
#    않고 끝까지 읽거나, PyYAML 과 같은 last-wins 를 낸다.
MUTATE="$FX/mutate_profile_shape.py"
DESIGN_DOC="$REPO_ROOT/plugins/spec-distill/references/docreview-profiles/design-doc.md"

mutate_case() {  # $1=shape $2=assert 함수 이름(내부용)
  local shape="$1" mp="$TMPD/shape-$1.md" mcap="$TMPD/shape-$1-cap.txt" \
        margv="$TMPD/shape-$1-argv.txt" mout="$TMPD/shape-$1.yaml"
  PYTHONDONTWRITEBYTECODE=1 python3 "$MUTATE" "$shape" "$DESIGN_DOC" "$mp"
  env -u DEVBREW_SPEC_DISTILL_DISABLE_WEB -u DEVBREW_QUALITY_GATES_DISABLE_WEB \
    DOCREVIEW_CODEX_CAPTURE="$mcap" DOCREVIEW_CODEX_ARGV_FILE="$margv" \
    CLAUDE_PLUGIN_ROOT="$HOST_PLUGIN_ROOT" \
    bash "$RUNNER" "$mp" "$FX/design-sample.md" "$REPO_ROOT" "$mout" 2>/dev/null
}

# 항목 1 — 줄바꿈된 flow list(layer1) → loud 실패(조용한 빈 프롬프트가 아니라)
mutate_case wrapped-layer1
assert_file_grep "$TMPD/shape-wrapped-layer1.yaml" 'reason: profile_parse_ambiguous' \
  "러너: 줄바꿈된 flow list(layer1) → loud 실패(조용히 빈 채로 새지 않는다, 리뷰 F-5 항목 1 — Task 3c R38 b 이후 사유 이름은 profile_parse_ambiguous)"

# 항목 1 변형 — layer2 는 게이트가 비어도 허용하므로 "비면 실패"만으로는 안
# 잡힌다(리뷰 재재현) — 헤더는 있는데 못 읽는 모양 자체를 잡아야 한다.
mutate_case wrapped-layer2
assert_file_grep "$TMPD/shape-wrapped-layer2.yaml" 'reason: profile_parse_ambiguous' \
  "러너: 줄바꿈된 flow list(layer2, 정당하게 빌 수 있는 키) → 그래도 loud 실패"

# 항목 2 — block 목록 중간의 빈 줄 → 끝까지 읽는다(마지막 항목 feasibility 로 확인)
mutate_case block-blank
assert_file_grep "$TMPD/shape-block-blank-cap.txt" '^Layer 1 \(big-picture coherence\) — categories: .*feasibility$' \
  "러너: block 목록 중간 빈 줄 → 끝 항목(feasibility)까지 읽는다(안 잘림, 리뷰 F-5 항목 2)"

# 항목 3 — block 목록 중간의 주석 줄 → 끝까지 읽는다
mutate_case block-comment
assert_file_grep "$TMPD/shape-block-comment-cap.txt" '^Layer 1 \(big-picture coherence\) — categories: .*feasibility$' \
  "러너: block 목록 중간 주석 줄 → 끝 항목(feasibility)까지 읽는다(안 잘림, 리뷰 F-5 항목 3)"

# 항목 4 — `web: yes` 도 `web: true` 와 같은 진리값(YAML 1.1)이다
mutate_case web-yes
assert_file_grep "$TMPD/shape-web-yes-argv.txt" 'web_search="live"' \
  "러너: web: yes → true 와 동치로 웹 live(리뷰 F-5 항목 4)"

# 항목 5 — 중복 `web:` 키(true 먼저, false 나중) → PyYAML 처럼 **마지막** 값이
# 이긴다(false) — 순서가 이래야 "진리값 패턴만 검색"하는 파서의 우연한
# 정답(그 패턴엔 true 줄 하나만 걸리므로 값과 무관하게 last-match 서치가
# 우연히 맞는다)과 실제 "web: 줄 자체의 마지막" 판정이 갈린다.
mutate_case dup-web
assert_file_absent "$TMPD/shape-dup-web-argv.txt" 'web_search="live"' \
  "러너: 중복 web: 키(true, false 순) → 마지막(false)이 이긴다, 첫 값(true) 아님(리뷰 F-5 항목 5)"

# 항목 6 — 중복 `layer1:` 키 → 마지막 선언의 카테고리가 이긴다
mutate_case dup-layer1
assert_file_grep "$TMPD/shape-dup-layer1-cap.txt" '^Layer 1 \(big-picture coherence\) — categories: marker_last_wins_category$' \
  "러너: 중복 layer1: 키 → 층 1 줄은 마지막 선언(marker_last_wins_category)이다(리뷰 F-5 항목 6)"
assert_file_absent "$TMPD/shape-dup-layer1-cap.txt" '^Layer 1 \(big-picture coherence\) — categories: .*goal_fit' \
  "러너: 중복 layer1: 키 → 첫 선언(goal_fit 등)은 층 1 줄에 안 실린다(first-match 회귀 방지)"

# 리뷰 F-6 — `ground_truth:` 의 block scalar 안에 layer1/layer2/allowed_
# dispositions 처럼 보이는 decoy 줄이 있어도(frontmatter 상 진짜 필드
# «뒤»에 와서 스코프 안 된 last-match 라면 진짜를 이겼을 것) 진짜 값만
# 읽는다 — `layer_rubric:` 블록 밖의 내용은 애초에 검색 범위에 안 들어온다.
#
# decoy 의 부재는 **범주 줄에서** 잰다 — ground_truth 가 프롬프트에 실리므로 decoy 문구는
# 이제 정답의 출처 블록 안에 정당하게 나타난다(Task 3c). 전체 캡처에서 부재를 재면 그
# 정당한 등장이 RED 가 되고, 범주 줄을 잘못 읽는 회귀는 여전히 이 줄 단위 부재가 잡는다.
mutate_case ground-truth-decoy
DECOY_CAP="$TMPD/shape-ground-truth-decoy-cap.txt"
assert_file_grep "$DECOY_CAP" '^Layer 1 \(big-picture coherence\) — categories: goal_fit,' \
  "러너: ground_truth: block scalar 안 decoy → 층 1 줄은 진짜 layer1(goal_fit…)을 읽는다(리뷰 F-6)"
assert_file_absent "$DECOY_CAP" '^Layer 1 \(big-picture coherence\) — categories: .*decoy_layer1' \
  "러너: ground_truth: 안 decoy_layer1 은 층 1 줄에 안 실린다(F-6 회귀 방지)"
assert_file_grep "$DECOY_CAP" '^Layer 2 \(detail completeness\) — categories: placeholder,' \
  "러너: ground_truth: block scalar 안 decoy → 층 2 줄은 진짜 layer2(placeholder…)를 읽는다(F-6)"
assert_file_absent "$DECOY_CAP" '^Layer 2 \(detail completeness\) — categories: .*decoy_layer2' \
  "러너: ground_truth: 안 decoy_layer2 는 층 2 줄에 안 실린다(F-6 회귀 방지)"
assert_file_grep "$DECOY_CAP" 'assign a disposition from: decide, ask, fix, defer, drop' \
  "러너: ground_truth: 안 decoy(allowed_dispositions: [decide]) 대신 진짜 다섯 처분을 읽는다(F-6)"
assert_file_grep "$DECOY_CAP" '^Ground truth \(the source the document is judged against\): decoy block scalar deliberately mimicking field headers$' \
  "러너: block scalar(|) ground_truth → 첫 내용 줄이 정답의 출처 머리에 실린다"
assert_file_grep "$DECOY_CAP" '^end of decoy$' \
  "러너: block scalar(|) ground_truth → 마지막 내용 줄까지 실린다(안 잘림)"

# ── ground_truth 모양 — Task 3c. 러너가 스칼라 ground_truth 를 PyYAML 과 같은 값으로
#    읽는지(평문의 기대값은 profile-check), 목록·빔·null·부재면 게이트와 **같은 판정**
#    (`ground_truth_empty`)으로 fail-closed 하는지(R36 — 두 파서가 한 프로필에 다른 판정을
#    내지 않는다). 중복 키는 게이트가 거절한다(R37, test_docreview_profile_schema.sh) —
#    여기서는 러너 단독 호출의 last-wins 만 잰다 ─────────────────────────────────
gt_expect_pc() {  # gt_expect_pc <shape> → 그 모양 프로필을 profile-check 가 읽은 ground_truth
  python3 "$SCRIPTS/docreview_state.py" profile-check "$TMPD/shape-$1.md" > "$TMPD/shape-$1.json" 2>/dev/null
  pc_get "$TMPD/shape-$1.json" ground_truth
}

mutate_case gt-dup
cmp_line "$TMPD/shape-gt-dup-cap.txt" "$GT_PREFIX" "marker_gt_last_wins" \
  "러너 단독 호출: 중복 ground_truth: → 마지막 선언이 이긴다(게이트는 R37 로 중복 키 자체를 거절)"
assert_file_absent "$TMPD/shape-gt-dup-cap.txt" '^Ground truth \(the source the document is judged against\): 인터뷰 브리프' \
  "러너: 중복 ground_truth: → 첫 선언은 정답의 출처 줄에 안 실린다(first-match 회귀 방지)"

mutate_case gt-plain
cmp_line "$TMPD/shape-gt-plain-cap.txt" "$GT_PREFIX" "$(gt_expect_pc gt-plain)" \
  "러너: 따옴표 없는 평문 ground_truth(+ 꼬리 주석) → PyYAML 과 같은 값"

mutate_case gt-dup-mixed
cmp_line "$TMPD/shape-gt-dup-mixed-cap.txt" "$GT_PREFIX" "marker_gt_second" \
  "러너 단독 호출: 모양이 다른 중복 ground_truth:(flow 목록 먼저 · 스칼라 나중) → 나중 선언이 이긴다"

for shape in gt-flow-list gt-block-list gt-empty gt-bare gt-null gt-absent; do
  mutate_case "$shape"
  assert_file_grep "$TMPD/shape-$shape.yaml" 'reason: ground_truth_empty' \
    "러너: ground_truth 가 문자열이 아니거나 비었거나 없음($shape) → 게이트와 같은 이름의 fail-closed 사유"
  if [ ! -e "$TMPD/shape-$shape-cap.txt" ]; then
    ok "러너: $shape → codex 를 부르지 않는다(빈 정답의 출처로 프롬프트가 나가지 않는다)"
  else
    no "러너: $shape → codex 가 불렸다(캡처 파일이 있다)"
  fi
  if python3 "$SCRIPTS/docreview_state.py" profile-check "$TMPD/shape-$shape.md" >/dev/null 2>&1; then
    no "게이트 전제: profile-check 가 $shape 를 받았다 — 러너가 이 모양을 다시 막지 않는 근거가 무너졌다"
  else
    ok "게이트 전제: profile-check 가 $shape 를 거절한다(엔진 경로에서는 러너까지 오지 않는다)"
  fi
done

# ── 빈 본문 — R34. 본문은 codex 가 받는 루브릭이다: 공백뿐이면 빈 절을 싣지 않고 게이트와
#    같은 이름(profile_body_empty)으로 fail-closed 한다 ──────────────────────────
mutate_case body-empty
assert_file_grep "$TMPD/shape-body-empty.yaml" 'reason: profile_body_empty' \
  "러너: 본문이 공백뿐 → 이름 붙은 fail-closed 사유(profile_body_empty)"
if [ ! -e "$TMPD/shape-body-empty-cap.txt" ]; then
  ok "러너: body-empty → codex 를 부르지 않는다(빈 프로필 절로 프롬프트가 나가지 않는다)"
else
  no "러너: body-empty → codex 가 불렸다(캡처 파일이 있다)"
fi
python3 "$SCRIPTS/docreview_state.py" profile-check "$TMPD/shape-body-empty.md" >/dev/null 2>"$TMPD/body-empty.err"
assert_file_grep "$TMPD/body-empty.err" 'profile_body_empty' \
  "게이트: 같은 프로필을 같은 이름(profile_body_empty)으로 거절한다(한 판정)"

# ── 한 판정 — Task 3c 리뷰 I1·M1·M2·M3 (R38 b). 게이트가 받는 프로필이면 러너는 **같은 값을
#    읽거나 이름 붙은 사유(profile_parse_ambiguous)로 멈춘다** — 다른 값으로 codex 를 부르는 셋째
#    결과는 없다. 모양마다 게이트 전제 · 러너 결과를 적고, 게이트가 받았는데 러너가 진행했으면
#    러너가 읽은 필드 전부와 웹 인자를 게이트 값과 대조한다 ─────────────────────────────
VN=0
variant() {  # variant <shape> <src-profile> <gate accept|reject> <runner ambiguous|faithful> <label>
  local tag mp pj out cap argv pout grc
  VN=$((VN + 1)); tag="variant-$VN"
  mp="$TMPD/$tag.md"; pj="$TMPD/$tag.json"; out="$TMPD/$tag.yaml"
  cap="$TMPD/$tag-cap.txt"; argv="$TMPD/$tag-argv.txt"; pout="$TMPD/$tag-parsed.json"
  if ! PYTHONDONTWRITEBYTECODE=1 python3 "$MUTATE" "$1" "$2" "$mp" 2>/dev/null; then
    no "$5 — 픽스처가 적용되지 않았다(전제 실패)"; return
  fi
  python3 "$SCRIPTS/docreview_state.py" profile-check "$mp" > "$pj" 2>/dev/null; grc=$?
  if [ "$3" = accept ]; then
    assert_eq "$grc" "0" "$5 — 게이트 전제: profile-check 가 받는다"
  elif [ "$grc" != 0 ]; then
    ok "$5 — 게이트 전제: profile-check 가 거절한다"
  else
    no "$5 — 게이트 전제: profile-check 가 받았다(거절을 기대)"
  fi
  env -u DEVBREW_SPEC_DISTILL_DISABLE_WEB -u DEVBREW_QUALITY_GATES_DISABLE_WEB \
    DOCREVIEW_CODEX_CAPTURE="$cap" DOCREVIEW_CODEX_ARGV_FILE="$argv" DOCREVIEW_CODEX_PARSED_OUT="$pout" \
    CLAUDE_PLUGIN_ROOT="$HOST_PLUGIN_ROOT" \
    bash "$RUNNER" "$mp" "$FX/design-sample.md" "$REPO_ROOT" "$out" 2>/dev/null
  if [ "$4" = ambiguous ]; then
    assert_file_grep "$out" 'reason: profile_parse_ambiguous' "$5 — 러너: 이름 붙은 사유(profile_parse_ambiguous)로 fail-closed"
    if [ ! -e "$cap" ]; then ok "$5 — 러너: codex 를 부르지 않는다"; else no "$5 — 러너: codex 가 불렸다"; fi
  else
    assert_file_grep "$out" 'codex_failed: false' "$5 — 러너: 멈추지 않고 읽는다(과잉 fail-closed 아님)"
  fi
  if [ "$grc" = 0 ] && ! grep -q 'reason: profile_parse_ambiguous' "$out" 2>/dev/null; then
    assert_contains "$(parsed_eq "$pout" "$pj")" "ALL_EQUAL" "$5 — 한 판정: 러너가 읽은 필드 전부가 게이트 값과 같다"
    web_effect "$argv" "$pj" "$5 — 한 판정: codex 웹 인자가 게이트의 web 과 같다"
  fi
}
SD_PROF="$REPO_ROOT/plugins/spec-distill/references/docreview-profiles"
QG_PROF="$REPO_ROOT/plugins/quality-gates/references/docreview-profiles"
# I1 — 따옴표·flow 연속줄의 컬럼-0 키. 셋째·넷째가 리뷰의 배포 seed·generic 편집(게이트 web=False
# 인데 러너가 codex 웹을 켰다 — 락 전부 GREEN 이던 자리).
variant qcont-gt "$SD_PROF/design-doc.md" accept ambiguous "I1: immutable 항목 큰따옴표 연속줄에 숨긴 ground_truth(design-doc)"
variant qcont-all "$SD_PROF/design-doc.md" accept ambiguous "I1: decision_log.heading 연속줄에 숨긴 네 필드(design-doc)"
variant qcont-all "$SD_PROF/seed.md" accept ambiguous "I1: decision_log.heading 연속줄에 숨긴 네 필드(seed)"
variant flow-web "$SD_PROF/seed.md" accept ambiguous "I1 리뷰 재현: seed 의 defer_target flow 연속줄 컬럼-0 web: true"
variant flow-web "$QG_PROF/generic.md" accept ambiguous "I1 리뷰 재현: generic 의 defer_target flow 연속줄 컬럼-0 web: true"
# M3 — 게이트는 받는데 러너가 틀린 사유(ground_truth_empty)를 내던 모양.
variant gt-spacecolon "$SD_PROF/design-doc.md" accept ambiguous "M3: ground_truth : (콜론 앞 공백)"
variant gt-u2028 "$SD_PROF/design-doc.md" accept ambiguous "M3: U+2028 뒤의 ground_truth"
# M1 — 게이트가 거절하는 문자열 아닌 ground_truth.
variant 'gt-value= 123' "$SD_PROF/design-doc.md" reject ambiguous "M1: ground_truth: 123"
variant 'gt-value= true' "$SD_PROF/design-doc.md" reject ambiguous "M1: ground_truth: true"
variant 'gt-value= 2026-09-11' "$SD_PROF/design-doc.md" reject ambiguous "M1: ground_truth: 2026-09-11"
variant 'gt-value= {a: b}' "$SD_PROF/design-doc.md" reject ambiguous "M1: ground_truth: {a: b}"
variant 'gt-value=\n  sub: val' "$SD_PROF/design-doc.md" reject ambiguous "M1: ground_truth: block 매핑"
# M2 — 게이트가 받는 스칼라. 같은 값을 읽을 수 있으면 읽고(faithful), 아니면 멈춘다.
variant 'gt-value= &x "anch"' "$SD_PROF/design-doc.md" accept ambiguous "M2: 앵커 &x"
variant 'gt-value= !!str tagged' "$SD_PROF/design-doc.md" accept ambiguous "M2: 태그 !!str"
variant 'gt-value= "esc \"q\" x"' "$SD_PROF/design-doc.md" accept ambiguous "M2: 큰따옴표 escape"
variant 'gt-value= >-\n  para one\n\n  para two' "$SD_PROF/design-doc.md" accept ambiguous "M2: folded 의 빈 줄 문단"
variant "gt-value= 'it''s'" "$SD_PROF/design-doc.md" accept faithful "M2: 작은따옴표의 '' → '"
variant 'gt-value= |\n  para one\n\n  para two' "$SD_PROF/design-doc.md" accept faithful "M2: literal 의 빈 줄 문단"
[ "$VN" -ge 18 ] && ok "한 판정 모양 ${VN}개 (vacuous 아님)" || no "한 판정 모양이 ${VN}개뿐이다"

finish
