#!/usr/bin/env bash
# Spec B T7 (+ T21의 Bash 부재 절) — 신규 3 에이전트 도구·모델 표면 락.
# AC4(쓰기·실행·위임 도구 0) · AC5(model: inherit) · AC2b(probe 판정과 tools: 정합)
# Run: bash plugins/spec-distill/tests/test_brief_agents.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
AUDIT="$REPO_ROOT/docs/audits/2026-07-27-spec-distill-zero-tool-probe.md"
ISOLATED=("brief-critic" "brief-readback")
ALL=("brief-critic" "brief-readback" "brief-direction-reviewer")

SKILL_BRIEF="$SD/skills/reviewing-brief/SKILL.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
fm_of() { awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$1"; }

# probe 판정을 읽는다 — 없으면 fail-closed (구현 진행 금지 신호)
test -f "$AUDIT" || { no "probe 감사 문서 부재: $AUDIT (AC2b — probe 미실행)"; \
  echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"; exit 1; }
VERDICT="$(grep -m1 '^\*\*분기 판정:\*\*' "$AUDIT" | sed 's/^\*\*분기 판정:\*\*[[:space:]]*//' | tr -d '[:space:]')"
case "$VERDICT" in
  ZERO_TOOL_OK|ZERO_TOOL_UNAVAILABLE) ok "probe 판정 인식: $VERDICT" ;;
  *) no "probe 판정을 읽을 수 없다 (값: '$VERDICT')"; \
     echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"; exit 1 ;;
esac

for a in "${ALL[@]}"; do
  f="$SD/agents/$a.md"
  test -f "$f" || { no "에이전트 파일 부재: $a.md"; continue; }
  FM="$(fm_of "$f")"

  # AC5 — model: inherit (리터럴 핀 금지, E10 선제 적용)
  grep -qE '^model: inherit$' <<<"$FM" \
    && ok "$a: model: inherit" || no "$a: model이 inherit이 아님 (E10 위반)"

  # AC4 — 쓰기·실행·위임 물리적 부재
  # tools: 값을 정규화한 뒤 토큰 단위 정확 일치(대소문자 무시)로 비교한다.
  # 정규화 파이프라인(round 1→2 누적):
  #   1) `tools:` 접두어 제거
  #   2) 트레일링 `# ...` 코멘트 절단 — split 이전에 잘라내므로 주석 안의 문자열은
  #      아예 토큰 후보에 들어오지 않는다(주석에 금지어를 적어도 오탐하지 않음 — round 2 probe)
  #   3) `[`/`]` 제거 (flow-sequence 대괄호)
  #   4) 콤마로 split
  #   5) 각 요소: 앞뒤 공백/탭 trim → 앞뒤 `"`/`'` 1겹 제거 → 다시 trim (quoted element 대응)
  #   6) 전부 소문자로 casefold — fail-closed: `write`도 잡아야 한다. 레지스트리가 소문자
  #      토큰을 실제로 resolve하는지는 이 락의 책임이 아니다. 이 방향이 정당한 allowlist
  #      (Read/Grep/Glob/WebSearch/WebFetch)와 금지 목록 사이에 대소문자 무시 충돌을 만들지
  #      않음을 확인했다 — 두 집합의 이름이 애초에 겹치지 않는다.
  #   7) 빈 줄 제거
  # 이전(raw-line grep) 방식은 bracket-form에서 경계 문자(`]`)를 인식 못 해 뚫렸다(round 1).
  # round 2 리뷰가 이 정규화-비교 자체도 quote·trailing comment·case에 아직 blind함을
  # 추가 적발해(quoted `["Write", Read]`, 코멘트 `Read, Write  # note`, 대소문자
  # `[read, write]`가 전부 회피) 5·6단계를 더했다. `WriteFile` 같은 상위 문자열에 `Write`가
  # 우연히 포함되는 substring collision은 여전히 배제된다(줄 단위 완전 일치이므로).
  #
  # YAML block-sequence(`tools:` 단독 헤더 줄 + 다음 줄부터 `- Read`/`- Write` 나열)는 이
  # 루프가 직접 파싱하지 **않는다** — 의도적 결정이다. 이 레포의 모든 agent frontmatter
  # 관례가 단일 줄 inline 선언(`tools: []` / `tools: Read` / `tools: Read, Grep, ...`)이고
  # block-sequence를 쓰는 기존 파일이 하나도 없다. block-sequence를 쓰면 헤더 줄이
  # `tools:`만 있고 값이 없는 형태가 되므로, 아래 bare-`tools:` guard가 그 줄 자체를
  # YAML null(fail-open 위험)로 fail-closed 처리해 잡는다 — AC4 루프에 별도 YAML
  # block-sequence 파서를 추가하지 않고 이 guard 하나로 충분하다고 판단했다(round 2).
  tools_line="$(grep -E '^tools:' <<<"$FM" | head -1)"
  tools_val="${tools_line#tools:}"
  tools_val="${tools_val%%#*}"
  tools_val="${tools_val//[/}"
  tools_val="${tools_val//]/}"
  tools_norm="$(tr ',' '\n' <<<"$tools_val" \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
          -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'\$//" \
          -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | tr '[:upper:]' '[:lower:]' \
    | grep -v '^$')"
  for t in Write Edit MultiEdit NotebookEdit Bash Agent Monitor Task; do
    t_lc="$(tr '[:upper:]' '[:lower:]' <<<"$t")"
    if grep -qxF "$t_lc" <<<"$tools_norm"; then
      no "$a: tools:에 $t 가 있다 (Law 2 위반, 대소문자 무시)"
    else
      ok "$a: tools:에 $t 없음"
    fi
  done
  grep -qE '^tools:.*mcp__' <<<"$FM" && no "$a: tools:에 MCP grant" || ok "$a: MCP 없음"

  # 죽은 필드 금지 (allowedTools는 비공식 — 조용히 무시된다)
  grep -qE '^(allowedTools|disallowedTools):' <<<"$FM" \
    && no "$a: allowedTools/denylist 잔존" || ok "$a: allowedTools·disallowedTools 없음"

  # bare `tools:` 금지 — YAML null = "키 미지정"으로 읽혀 조용한 fail-open이 된다.
  # 이 guard는 YAML block-sequence 헤더 줄(`tools:`만 있고 값이 다음 줄부터 `- Read`로
  # 이어지는 형태)도 겸해서 잡는다 — 위 AC4 정규화 파이프라인의 의도적 scope 결정 참조.
  grep -qE '^tools:[[:space:]]*$' <<<"$FM" \
    && no "$a: bare 'tools:' (YAML null → 전체 허용 fail-open 위험; block-sequence 헤더도 이 경로로 잡힌다)" \
    || ok "$a: bare 'tools:' 아님"

  grep -qE '^cost_class: (low|medium|high|variable)$' <<<"$FM" \
    && ok "$a: cost_class 선언" || no "$a: cost_class 없음"
done

# probe 판정에 따른 격리 에이전트의 tools: 정합
for a in "${ISOLATED[@]}"; do
  FM="$(fm_of "$SD/agents/$a.md")"
  if [[ "$VERDICT" == "ZERO_TOOL_OK" ]]; then
    grep -qE '^tools: \[\]$' <<<"$FM" \
      && ok "$a: tools: [] (probe 통과 분기)" || no "$a: probe 통과인데 tools: [] 가 아님"
  else
    grep -qE '^tools: Read$' <<<"$FM" \
      && ok "$a: tools: Read (probe 실패 분기 — inert)" || no "$a: probe 실패인데 tools: Read 가 아님"
  fi
done

# 방향성 리뷰어는 분기 무관 — 웹·repo 도구 둘 다, Bash는 없다 (T21)
FM="$(fm_of "$SD/agents/brief-direction-reviewer.md")"
grep -qE '^tools: Read, Grep, Glob, WebSearch, WebFetch$' <<<"$FM" \
  && ok "direction-reviewer: tools 정확 일치" || no "direction-reviewer: tools 표면이 다름"
for t in WebSearch WebFetch; do
  grep -qE "^tools:.*${t}" <<<"$FM" && ok "direction-reviewer: $t 보유 (E10 — 둘 다)" \
    || no "direction-reviewer: $t 없음 (외부 근거 축 축소)"
done

# 역할 프롬프트가 X / NOT Z를 명시한다 (CLAUDE.md 컴포넌트 격리 규약)
# /qg iter-1: 이전 형태 `grep -q "NOT"`는 **"NOTE"·"NOTHING"으로 충족**됐다 — 세 `**NOT**`
# 불릿을 "NOTE: 자유롭게 쓰세요."로 바꿔 역할 경계를 뒤집어도 green이었다. 마커 형태와
# 열거 크기를 함께 핀하고, 대상도 세 agent 전부로 넓힌다(direction-reviewer가 빠져 있었다).
for a in brief-critic brief-readback brief-direction-reviewer; do
  n_not="$(grep -cE '^[[:space:]]*-[[:space:]]+\*\*NOT\*\* ' "$SD/agents/$a.md" || true)"
  # `-ge 2`는 3개 중 **어느 하나를 지워도** 통과한다(iter-2가 맨앞·중간·맨끝 3곳 모두
  # 실증했고, 맨끝은 Law 2 역할 경계 불릿이었다). 실제 출하 개수로 핀한다.
  [[ "$n_not" -eq 3 ]] \
    && ok "$a: NOT 불릿 정확히 3개 (마커 형태 + 열거 크기 핀)" \
    || no "$a: '- **NOT** …' 불릿이 ${n_not}개 — 3개여야 한다(하나만 지워도 역할 경계가 깨진다)"
done

# --- /qg iter-1 IMPORTANT : 출력 계약이 **생산자 쪽에서도** 락된다 ------------
# 결함: `brief-critic-issues` 펜스명과 `**Status:**`는 merge_brief_review.py가 리터럴로
# 핀하는데 agent 파일 쪽에는 아무 assert가 없었다 — 생산자에서 rename하면 10개 스위트가
# 전부 green인 채로 매 라운드 critic_verdict=None + malformed → 영구 needs_revise →
# cap에서 강제 escalate가 난다(테스트 신호 0). 형제 agent엔 이 락이 이미 있다
# (test_spec_reviewer_design_checklist.sh). 리터럴을 여기 박지 않고 **소비자 코드에서
# 추출**해 대조한다 — 어느 쪽에서 rename해도 red가 되도록.
MERGE_PY="$SD/scripts/merge_brief_review.py"
SENTINEL_LIT="$(grep -oE '```brief-[a-z-]+' "$MERGE_PY" | head -1 | sed 's/^```//')"
[[ -n "$SENTINEL_LIT" ]] \
  && ok "PRODUCER: 소비자에서 sentinel 리터럴 추출 ($SENTINEL_LIT)" \
  || no "PRODUCER: merge_brief_review.py에서 sentinel 리터럴을 못 뽑았다 — 이 락이 vacuous하다"
# 빈 문자열이면 `grep -qF ""`가 모든 파일에 매치해 **가짜 PASS**가 난다(iter-2 실증).
# 추출 실패 시 이 assert 자체를 FAIL로 떨어뜨린다.
if [[ -n "$SENTINEL_LIT" ]] && grep -qF "$SENTINEL_LIT" "$SD/agents/brief-critic.md"; then
  ok "PRODUCER: critic 파일이 소비자가 핀한 sentinel($SENTINEL_LIT)을 실제로 emit"
else
  no "PRODUCER: critic sentinel이 소비자 리터럴과 불일치(또는 추출 실패) — 매 라운드 malformed로 강제 escalate된다"
fi
grep -qE '\*\*Status:\*\*' "$SD/agents/brief-critic.md" \
  && ok "PRODUCER: critic 파일에 **Status:** 마커 실재 (소비자 STATUS_RE와 정합)" \
  || no "PRODUCER: critic 파일에 **Status:** 가 없다 — verdict 파싱이 항상 실패한다"

# direction-reviewer 본문도 락한다 — SKILL이 이 출력 위에 결정 표를 세우는데 지금까지
# frontmatter만 검사됐고 본문 전체(센티널 포함)가 무테스트였다.
# SKILL은 이 센티널을 **인라인 코드 스팬**(`brief-…-findings`)으로 참조한다(펜스가 아니다).
# 소비자 표기에서 뽑아 생산자(agent 본문)와 대조하므로, 어느 쪽에서 rename해도 red가 된다.
DIR_SENT="$(grep -oE '`brief-[a-z-]+-findings`' "$SKILL_BRIEF" | head -1 | tr -d '`')"
[[ -n "$DIR_SENT" ]] \
  && ok "PRODUCER: SKILL이 direction sentinel을 참조 ($DIR_SENT)" \
  || no "PRODUCER: SKILL에서 direction sentinel을 못 찾았다 — 아래 대조가 vacuous하다"
[[ -n "$DIR_SENT" ]] && grep -qF "$DIR_SENT" "$SD/agents/brief-direction-reviewer.md" \
  && ok "PRODUCER: direction-reviewer 본문이 SKILL이 기대하는 sentinel을 emit" \
  || no "PRODUCER: direction-reviewer sentinel이 SKILL 기대와 불일치 — 결정 표가 'unavailable'로만 떨어진다"

# AC3 — readback 프롬프트에 출력 스키마 어휘와 '금지 문구'가 둘 다 없다
RB="$SD/agents/brief-readback.md"
for tok in "category" "severity" "sentinel" "JSON"; do
  grep -qF "$tok" "$RB" && no "AC3: readback에 스키마 어휘 '$tok'" || ok "AC3: readback에 '$tok' 없음"
done
for tok in "audit" "readback 기준" "red-flag"; do
  grep -qiF "$tok" "$RB" && no "AC3: readback에 '$tok' 언급 (존재 누설)" || ok "AC3: readback에 '$tok' 없음"
done
for tok in "G1" "gap 클래스" "미결을 확정으로"; do
  grep -qF "$tok" "$RB" && no "AC25: readback에 gap 클래스 어휘 '$tok'" || ok "AC25: readback에 '$tok' 없음"
done

# critic 프롬프트는 category 6종 전부를 명시한다 (spec §5.3 최소 필수)
CR="$SD/agents/brief-critic.md"
for cat in distortion omission insertion provenance_mislabel authority_syntax evidence_unsupported; do
  grep -qF "$cat" "$CR" && ok "critic: category '$cat' 명시" || no "critic: category '$cat' 누락"
done
# F3 (task-10 fix round 2, security) — round 1's lock only required '비신뢰' to sit near
# ONE label (<<<AUDIT-VERBATIM>>>). The bundle critic actually receives has **two**
# untrusted-verbatim locations — payload's own `## 6. 사용자 원문` (S1, carried through
# byte-for-byte since redact_frontmatter() only touches frontmatter) and the
# `<<<AUDIT-VERBATIM>>>` block (S2+) — and wording that names only one of the two
# satisfied round 1's lock while leaving the other location's injection boundary gone
# (round-2 finding: exactly the wording shipped in 024bc9a).
#
# The set of locations is **derived from the producer**, not handed to this test as a
# list: build_brief_bundle.py now exports `UNTRUSTED_VERBATIM_MARKERS`, the tuple its own
# assemble() actually uses to emit the audit label (single source of truth — changing the
# constant changes the real bundle bytes, so this isn't a parallel literal that can drift
# silently). We still pin an EXPECTED contract here (same idiom as T12's REDACT_KEYS
# cross-check in test_brief_bundle.sh) and verify it against the module in **both**
# directions (missing / extra) — so a change to the module's real marker set is caught
# even if nobody remembers to update this test.
#
# Coverage is checked against **paragraphs containing '비신뢰'** specifically (not "does
# the marker appear anywhere in the file" — `<<<AUDIT-VERBATIM>>>` already appears
# elsewhere as a "Ground truth" pointer with no security framing, so a bare substring
# check would be satisfied without ever calling that block untrusted). This does NOT read
# its checklist out of brief-critic.md — the EXPECTED contract and coverage logic live
# entirely in this test and in the producer module, so a change to brief-critic.md's
# prose is exactly what this lock can detect.
#
# 이 리포트는 **양성 대조를 달고** 읽는다 — 아래 "F3(양성대조)" 블록 참조. 리포트가
# 비면 grep 기반 단언 셋이 전부 「금지 태그 없음」으로 통과하고 COVERED 순회는 아예
# 돌지 않아, 요구가 깨진 채로 스위트가 초록을 낸다.
#
# F14 (최종 리뷰 I2) — 같은 두 위치를 **ground truth** 문장도 이름으로 대야 한다.
# 비대칭이 결함의 신호였다: F3 는 *비신뢰 경계* 문장에 두 곳을 강제하는데, *ground
# truth* 문장에는 아무 강제가 없어 세 지시 자리(critic 정의 · codex 체크리스트 ·
# 2-a dispatch 프롬프트)가 전부 `<<<AUDIT-VERBATIM>>>` 한 곳만 지목하고 있었다.
# 그런데 번들의 payload 부분은 `## 6. 사용자 원문`(S1)을 그 라벨 **앞에** 싣는다 —
# 출하된 dogfood payload 만 해도 `evidence: S1` 항목이 4건이라, 그 항목들에 대한
# distortion·evidence_unsupported 판정이 「대조할 원문이 코퍼스 밖」인 채로 났다.
# 세 자리는 같은 EXPECTED 튜플(= 산출자 상수)에서 파생된다.
F3_ERR="$(mktemp -t sdF3err)"
F3_REPORT="$(python3 - "$SD/scripts/build_brief_bundle.py" "$CR" \
    "$SD/scripts/brief-codex-fidelity-checklist.md" "$SKILL_BRIEF" 2>"$F3_ERR" <<'PYEOF'
import importlib.util, re, sys

bundle_script, critic_path, checklist_path, skill_path = sys.argv[1:5]
spec = importlib.util.spec_from_file_location("brief_bundle_mod", bundle_script)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

EXPECTED = ("## 6. 사용자 원문", "<<<AUDIT-VERBATIM>>>")  # task-10 fix round 2 contract:
# the two locations the bundle actually carries untrusted verbatim under.
actual = tuple(mod.UNTRUSTED_VERBATIM_MARKERS)
missing = [m for m in EXPECTED if m not in actual]
extra = [m for m in actual if m not in EXPECTED]
if missing:
    print("MISSING\t" + ",".join(missing))
if extra:
    print("EXTRA\t" + ",".join(extra))

def paras(path):
    return re.split(r"\n\s*\n", open(path, encoding="utf-8").read())


critic_paras = paras(critic_path)
untrusted_paragraphs = [p for p in critic_paras if "비신뢰" in p]
if not untrusted_paragraphs:
    print("NO_BOUNDARY_PARAGRAPH")
for marker in EXPECTED:
    covered = any(marker in p for p in untrusted_paragraphs)
    print(("COVERED" if covered else "UNCOVERED") + "\t" + marker)

# ── F14 — ground truth 문장도 두 위치를 이름으로 댄다 ────────────────────────
GT_ANCHOR = re.compile(r"ground\s+truth", re.IGNORECASE)


def dispatch_block(path):
    """SKILL.md 의 2-a critic dispatch 를 **구조로** 잘라낸다.

    산문 문단을 앵커로 잡으면 그 파일 다른 곳의 'ground truth' 문단(3-b readback
    설명)이 대신 검사를 만족시킬 수 있다. subagent_type 리터럴을 감싸는 Agent({ …
    }) 호출만 본다 — dispatch 가 사라지거나 개명되면 빈 목록이 되어 red 다.
    """
    text = open(path, encoding="utf-8").read()
    i = text.find('subagent_type: "spec-distill:brief-critic"')
    if i < 0:
        return []
    start, end = text.rfind("Agent({", 0, i), text.find("\n})", i)
    if start < 0 or end < 0:
        return []
    return [text[start:end]]


GT_SITES = (
    ("critic 정의", [p for p in critic_paras if GT_ANCHOR.search(p)]),
    ("codex 체크리스트", [p for p in paras(checklist_path) if GT_ANCHOR.search(p)]),
    ("2-a dispatch", dispatch_block(skill_path)),
)
for label, blocks in GT_SITES:
    for marker in EXPECTED:
        covered = any(marker in b for b in blocks)
        print(("GT_COVERED" if covered else "GT_UNCOVERED") + "\t" + label + "\t" + marker)
PYEOF
)"
F3_RC=$?
# ── F3(양성대조) — 「리포트가 있다」를 먼저 증명한다 ────────────────────────────
# 부재 술어만으로 짜인 락은 **대상이 사라지면 공허하게 통과한다.** 실측: 리뷰어가
# build_brief_bundle.py 의 `UNTRUSTED_VERBATIM_MARKERS` 를 다른 이름으로 rename하자
# (정의 + 유일 사용처, 2 insertions / 2 deletions) 위 블록이 AttributeError로 죽어
# 트레이스백은 stderr 로 가고 `$F3_REPORT` 는 **빈 문자열**이 됐다. 그러자
#   · `^MISSING` 없음 → ok        · `^EXTRA` 없음 → ok
#   · `^NO_BOUNDARY_PARAGRAPH` 없음 → ok  (셋 다 「없어야 할 것이 없다」로 통과)
#   · COVERED 순회는 한 번도 돌지 않아 단언 2개가 **조용히 사라졌다**
# 스위트는 rc 0 · 77/77 을 냈다 — 기준선 79/79 와의 차이는 총계뿐이라 초록만 보면
# 안 보인다. 형제 락 T12(test_brief_bundle.sh 의 `n_pairs -eq 3`)는 같은 함정을
# 행 수 리터럴로 이미 막고 있었고, F3 는 그 관용구를 베끼면서 이 가드만 빠뜨렸다.
#
# 행 수는 **리터럴 2** 로 못 박는다. `len(EXPECTED)` 로 유도하면 EXPECTED 가 빈
# 튜플이 되는 변형에서 `0 == 0` 으로 다시 공허해진다(피검자에서 기대값을 끌어오는
# 바로 그 실패형). 계약이 세 곳으로 늘면 위 EXPECTED 와 이 숫자를 **함께** 고친다.
[[ "$F3_RC" -eq 0 ]] \
  && ok "F3(양성대조): 계약 추출기가 정상 종료했다 (rc=0)" \
  || no "F3(양성대조): 계약 추출기가 rc=$F3_RC 로 죽었다 — 아래 F3 단언들은 무의미하다: $(tr '\n' ' ' < "$F3_ERR" | tail -c 200)"
f3_rows="$(grep -cE '^(COVERED|UNCOVERED)'$'\t' <<<"$F3_REPORT" || true)"
[[ "$f3_rows" -eq 2 ]] \
  && ok "F3(양성대조): 커버리지 행이 정확히 2다 (단언이 실재한다)" \
  || no "F3(양성대조): 커버리지 행이 2가 아니라 $f3_rows — 리포트가 비었거나 잘렸다(F3 단언 소실)"
# 3 지시 자리 × 2 위치 = 6. 여기도 리터럴이다(같은 이유 — 위 주석 참조).
gt_rows="$(grep -cE '^GT_(UN)?COVERED'$'\t' <<<"$F3_REPORT" || true)"
[[ "$gt_rows" -eq 6 ]] \
  && ok "F14(양성대조): ground truth 행이 정확히 6다 (3 자리 × 2 위치)" \
  || no "F14(양성대조): ground truth 행이 6이 아니라 $gt_rows — 리포트가 비었거나 잘렸다(F14 단언 소실)"
rm -f "$F3_ERR"
missing_line="$(grep '^MISSING' <<<"$F3_REPORT" || true)"
[[ -z "$missing_line" ]] && ok "F3: UNTRUSTED_VERBATIM_MARKERS 계약이 필수 2곳을 전부 포함한다" \
  || no "F3: build_brief_bundle.py의 UNTRUSTED_VERBATIM_MARKERS 에서 빠졌다 — ${missing_line#MISSING$'\t'}"
extra_line="$(grep '^EXTRA' <<<"$F3_REPORT" || true)"
[[ -z "$extra_line" ]] && ok "F3: UNTRUSTED_VERBATIM_MARKERS 계약이 예상한 2곳과 정확히 일치한다" \
  || no "F3: UNTRUSTED_VERBATIM_MARKERS 에 예상 밖 표지가 있다 — ${extra_line#EXTRA$'\t'} (이 테스트를 갱신해야 한다)"
if grep -q '^NO_BOUNDARY_PARAGRAPH' <<<"$F3_REPORT"; then
  no "F3: critic agent 정의 어디에도 '비신뢰' 문단이 없다 — injection 경계 자체가 없다"
else
  ok "F3: critic agent 정의에 '비신뢰' 문단이 실재한다"
fi
while IFS=$'\t' read -r tag marker extra_field; do
  case "$tag" in
    COVERED)   ok "F3: 비신뢰 문단이 '${marker}' 위치를 지목한다" ;;
    UNCOVERED) no "F3: 비신뢰 문단이 '${marker}' 위치를 지목하지 않는다 — 그 원문에는 injection 경계가 없다" ;;
    GT_COVERED)   ok "F14: ${marker}의 ground truth 문장이 '${extra_field}' 위치를 지목한다" ;;
    GT_UNCOVERED) no "F14: ${marker}의 ground truth 문장이 '${extra_field}' 위치를 지목하지 않는다 — 그 위치의 원문은 판정 코퍼스 밖이다" ;;
  esac
done <<< "$F3_REPORT"

# critic 프롬프트에 payload 경로/디렉토리가 실리지 않는다 (AC2의 정적 절)
grep -qF "docs/superpowers/interview/" "$CR" \
  && no "AC2: critic 프롬프트에 interview 디렉토리 문자열" || ok "AC2: critic에 interview 디렉토리 없음"
grep -qF "docs/superpowers/interview/" "$RB" \
  && no "AC3: readback 프롬프트에 interview 디렉토리 문자열" || ok "AC3: readback에 interview 디렉토리 없음"

# E10 — 신규 에이전트에 단일 호출 상한 표현 없음 (T28의 agent 절)
for a in "${ALL[@]}"; do
  if grep -qE '최대 [0-9]+회|[0-9]+회까지|max_[a-z_]+ *= *[0-9]' "$SD/agents/$a.md"; then
    no "E10: ${a}에 단일 호출 상한 표현"
  else
    ok "E10: ${a}에 상한 표현 없음"
  fi
done
finish
