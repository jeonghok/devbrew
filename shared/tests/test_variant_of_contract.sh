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
#      비-자유 키의 여러 줄 값은 둘째 줄 이후만 달라도 FAIL 이고, 줄마다 같으면 OK(양의 짝).
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
# 키 인식 — YAML 은 셋 다 최상위 키로 읽는다(Task 3b 재리뷰 P4: `"maxTurns": 1` 이 tools 블록에 흡수돼
# 관계가 OK 였다).
neg fm_dq_key.md base.md frontmatter_keys_differ:maxTurns
neg fm_sq_key.md base.md frontmatter_keys_differ:hooks
neg fm_spacecolon_key.md base.md frontmatter_keys_differ:permissionMode
# 값 블록 — 여러 줄 값의 둘째 줄 이후만 다른 쌍(키 줄만 비교하는 퇴행이 GREEN 이던 축).
neg ml_value.md base_ml.md frontmatter_value_differs:input_slots
[ "$n_neg" -ge 12 ] && ok "V2: 판정기 음성 ${n_neg}건을 태웠다" || no "V2: 음성이 ${n_neg}건뿐 — 셀이 사라졌다"
res_ml="$(python3 "$VO" check "$FX/ml_ok.md" "$FX/base_ml.md")"
assert_eq "$res_ml" "OK${TAB}4" "V2(양성 대조 — 여러 줄 값): 비-자유 키 input_slots 블록이 줄마다 같으면 관계가 선다"

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
finish
