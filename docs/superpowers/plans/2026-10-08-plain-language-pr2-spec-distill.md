# 쉬운 말 출력 PR 2 — spec-distill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill 의 모든 게이트(승인 · 리뷰 라운드 · request-framing 확정)가 질문 본문에 결정 하나와 상태 한 줄만 담고, 경고 목록은 질문 앞 글에 쉬운 말로 쓰게 한다. 사람이 보는 고정 경고와 출력 예시 문구, README, 소개 문구를 쉬운 말로 다듬는다. 착수 전 기준선과 비교해 새 실패는 0 이어야 한다.

**Architecture:** 지시문(모델이 읽는 글)은 그대로 두고, 그 안에서 **사용자에게 그대로 내라고 적힌 문구**와 **질문 틀**만 고친다(설계 §4 · §6). 「채널을 이름으로 밝히고 읽은 뒤에만 없음을 쓴다」는 계약은 그대로이고, 보이는 자리만 질문 본문에서 앞 글로 옮긴다. 그 자리 이름을 쓰는 처분 앵커와 락을 함께 옮긴다.

**Tech Stack:** bash(macOS 3.2 호환), Python 3.9+, git.

**Spec:** `docs/superpowers/specs/2026-10-08-plain-language-output-design.md` (brief: `docs/superpowers/interview/2026-10-03-plain-language-output-interview.md`). 선행: PR 1(`2026-10-08-plain-language-pr1-common.md`)이 머지돼 있어야 한다 — 규칙 블록과 새 렌더 첫 줄(「이상 없음」·「경고 없음」)이 이 PR 의 전제다.

## Global Constraints

- **재결정 규약** — confirmed 항목은 근거가 있으면 보고한 뒤 재결정할 수 있고, 임의 변경은 금지다. 설계의 B1~B10 · D1.1~D2.10 과 PR 1 계획의 「계획이 정한 것」 P1~P13 이 제약이다. 이 계획이 새로 정한 것은 아래 표에 있다.
- **작업 위치** — 워크트리 절대경로 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice`, 브랜치 `feature/plain-language-voice`. subagent 에게 이 절대경로를 매번 못 박아 준다.
- **git** — merge(rebase 금지). 경로를 지정해 커밋한다(`git add -A` 금지). Conventional Commits, **설명은 한국어**, 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. 스태시를 건드리지 않는다.
- **테스트 실행** — 셸 테스트는 리포 루트에서 `bash <경로>`, 하나씩(동시 실행 금지 — 고정 경로 `/tmp/sd_auth_stderr.txt` 가 경쟁한다). Python 은 그 `tests/` 디렉토리에서 `python3 -m unittest -v <모듈>`.
- **변이** — 커밋한 뒤 변이하고, `git checkout HEAD -- <파일>` 로 되돌린 뒤 `git diff HEAD --stat` 가 빈 출력인지 본다.
- **Bash 도구** — 호출마다 새 셸. 계산된 값이 든 복합 명령은 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/` 아래 스크립트 파일로 쓰고 `bash <파일>` 로 돌린다.
- **버전** — spec-distill minor(게이트 틀이 바뀐다). 번호는 머지 직전 origin/main 기준으로 다시 정한다. `.claude-plugin/marketplace.json` 의 spec-distill 소개 문구도 같은 커밋에서 바꾼다.
- **지시문은 그대로** — 찾는 지시·판정 규칙·kill switch 문장은 한 글자도 바꾸지 않는다. 바꾸는 것은 사용자에게 보이는 문구와 그 문구의 자리다. 모델에게 쓰는 실패 안내(「플러그인 루트 미해석 — …」 · `RETURN_MSG` 꼬리의 「…하라」)는 그대로 둔다.
- **산출 보존** — `~/.claude/sdd-mirror/plain-language-output/pr2/`.
- **줄 번호** — 이 계획의 줄 번호는 2026-10-08(PR 1 이전) 기준이다. PR 1 이 모든 `plugins/*/skills/*/SKILL.md` · `plugins/*/commands/*.md` 의 H1 뒤에 14줄(빈 줄 + 블록 13줄)을 넣었으므로 그 파일들의 줄 번호는 +14 다. 다른 파일(references · scripts · tests)은 그대로다. 편집은 줄 번호가 아니라 「옛」 문구로 찾는다.

## 계획이 정한 것

| # | 정한 것 | 근거 |
|---|---|---|
| Q1 | 승인 게이트 앞 글의 마지막 줄 규칙: 경고 채널을 다 읽었고 경고가 없으며 **남은 항목도 없으면** 「이상 없음」, 남은 항목이 있으면 「경고 없음」. 읽지 못한 채널은 「알 수 없음」 줄로 따로 쓴다. | 설계 표 `7874b3bb#r2.1` · 설계 §1 의 「이상 없음」 뜻(1라운드 답). |
| Q2 | 리뷰 라운드 게이트는 한 번에 최대 4개를 유지한다. 렌더 첫 줄은 첫 호출 **앞 글에 한 번** 쓰고, 질문에는 그 질문의 결정과 경고가 있으면 「경고 N개 — 위에 적었다」 한 줄만 둔다. 한 호출에 묶는 질문은 서로의 답에 기대지 않는 결정이다 — 다른 결정의 답에 따라 달라지는 결정은 다음 호출로 미룬다. | 설계 Deferred 6 — 2026-10-08 사용자 답 「지금처럼 4개씩」. |
| Q3 | framing-requests 의 degrade 채널 이름 「proceed 게이트 질문 텍스트」 → 「proceed 게이트 앞 글」. 고치는 자리 넷: 처분 앵커(L810) · `## degrade 채널` 다섯째 채널(L832) · `test_framing_review_contract.sh:535` 리터럴 · `test_dispatch_disposition.sh` 축 C(앵커 리터럴이 같은 파일 본문에 있어야 한다 — L832 가 그것을 만족시키므로 둘을 같은 글자로). | 설계 표 `3b4b8396#r3.1` + 조사가 찾은 넷째 자리. |
| Q4 | 질문 본문에 그대로 남는 것(Goal 4 의 예외 — 규칙 블록의 「따로 정한 자리」): framing-requests 의 저자 편집 덩어리 본문(분량 상한 없음), 기준 사본이 없을 때 보이는 seed 전문, steelman 질문. 냉독 출력 전문은 앞 글로 간다. | 설계 표 `3b4b8396#r3.1` ②③ · 설계 §1 D1.7. |
| Q5 | 핸드오프 `/compact` 틀: finishing.md 는 지금 있는 한 줄(물리적으로 한 줄 — `test_review_handoff_order.sh` 가 그 한 줄과 꺾쇠 자리표 집합 `<brief-path>` 를 잰다)에 규칙 유지 문장을 끼운다. reviewing-spec 에는 지금 `/compact` 문구 틀이 없다 — 이 PR 이 ① 행 아래에 틀을 새로 쓴다. framing-requests 의 ② `/compact` 는 다음 단계가 `/interview` 의 새 세션이라 블록이 다시 실리므로 손대지 않는다. | 설계 「알려진 한계」 D1.6 · 조사(2026-10-08). |
| Q6 | spec-distill 에는 「(Recommended)」가 없다(이미 「(권장)」). steelman 질문의 「(권장)」 금지는 그대로다. | 조사 · `steelman.md:91` 락. |
| Q7 | 고치는 고정 문구는 아래 Task 4 의 표에 있는 것뿐이다. 나머지 `[spec-distill]` 줄은 셋 중 하나라 그대로 둔다: 모델에게 쓰는 지시(「…하라」로 끝나는 꼬리), 프로그램이 읽는 줄(`review-entry:` · rc 줄 · `PAIRS`), 이미 쉬운 한국어인 줄. 분류 표는 PR 본문에 붙인다(원자료: `~/.claude/sdd-mirror/plain-language-output/research/research-c/`). | 설계 표 `1cdda836#r1.1`(고정 문구 전수). |
| Q8 | `seed_review_log.py` 의 사람용 줄(「같은 기록 줄이 이미 있다 — 다시 적지 않는다」)은 이미 쉬운 말이라 고치지 않는다. | 설계 Files to Modify 가 이 파일을 적었다 — 확인 결과. |

## Review Focus

1. **경고가 있는데 질문만 보고 고른다** — 질문에 경고가 하나도 없으면 사용자는 앞 글을 건너뛰고 고를 수 있다. 사람은 「경고가 있으면 질문에서도 그 사실이 보이기」를 기대한다. → Task 2 의 락: 질문에 `경고 <N>개 — 위에 적었다 | 경고 없음 | 이상 없음` 자리가 있다.
2. **경고 채널을 못 읽었는데 「이상 없음」** — 원장 `get` 이 실패한 세션. 사람은 「알 수 없음」을 기대한다. → 기존 락 `test_reviewing_brief_skill.sh` 의 「알 수 없는」 단언이 그대로 GREEN 인지 Task 3 에서 확인하고, 새 락이 `실제로 읽었다는 주장` 문장을 채택 skill 넷 전부에서 잰다.
3. **이름을 바꾼 채널이 처분 앵커에는 옛 이름으로 남는다** — 축 C 락은 이름의 실재만 잰다(CLAUDE.md 가 그 한계를 적는다). → Task 3 Step 4 가 앵커와 본문을 같은 글자로 바꾸고, 옛 이름이 FR 어디에도 없음을 잰다.
4. **압축 명령에 새 꺾쇠 자리표가 끼어든다** — 사용자가 그대로 붙여 넣는 명령이 `<…>` 를 품으면 그대로 실행된다. → Task 2 Step 1 의 단언은 기존 `test_review_handoff_order.sh` 가 이미 잰다(자리표 집합 = `<brief-path>`). reviewing-spec 새 틀도 자리표를 `<spec_path>` 하나로 제한하고 그것을 잰다.
5. **codex 건너뜀 줄의 사유 토큰이 사라진다** — 사람은 「왜 건너뛰었는지」를 원문 토큰으로 보기를 기대한다(`kill_switch` · `detector_not_runnable`). → Task 4 의 새 문구가 `(reason: <x>)` 를 그대로 품고, 14곳의 단언이 그 토큰까지 계속 잰다.

---

## Task 0: 착수 준비

- [ ] **Step 1: PR 1 머지를 받는다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice
mkdir -p ~/.claude/sdd-mirror/plain-language-output/pr2
git status --porcelain
git fetch origin main
git merge-base --is-ancestor "$(git log --format=%H -1 --grep='사람에게 쓰는 글 규칙 블록의 정본')" origin/main && echo PR1-MERGED || echo PR1-NOT-MERGED
git merge-tree --write-tree HEAD origin/main >/dev/null && echo clean || echo CONFLICT
git merge --no-edit origin/main
```

`PR1-NOT-MERGED` 나 `CONFLICT` 면 멈춰 보고한다.

- [ ] **Step 2: 이 계획의 옛 문구가 그대로인지 본다**

`/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr2_anchor_check.sh` 를 쓰고 돌린다 — 아래 Task 들이 바꾸는 옛 문구가 그 파일에 정확히 한 번 있는지(`grep -cF`) 센다. 대상은 각 Task 의 「옛」 블록 첫 줄이다. 1 이 아닌 것이 있으면 멈춰 보고한다.

```bash
#!/usr/bin/env bash
set -u
R=/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice
c() { printf '%s\t%s\t%s\n' "$(grep -cF -- "$2" "$R/$1")" "$1" "$2"; }
c plugins/spec-distill/skills/conducting-interview/references/finishing.md '    header: "Proceed",'
c plugins/spec-distill/skills/conducting-interview/references/finishing.md '그리고 `question` 텍스트에 **모든 degrade record를 한 줄씩** 싣습니다 — 옵션 description이'
c plugins/spec-distill/skills/conducting-interview/references/finishing.md '**그리고 아래 '"'"'재결정 규약'"'"' 문장**을 유지하고,'
c plugins/spec-distill/skills/reviewing-spec/SKILL.md '질문에 묶으면 그 결정의 선택지가 사라지기 때문이다. 매 호출 첫 질문의 첫 줄은 렌더 첫 줄(degrade'
c plugins/spec-distill/skills/reviewing-brief/SKILL.md '질문에 묶으면 그 결정의 선택지가 사라지기 때문이다. 매 호출 첫 질문의 첫 줄은 렌더 첫 줄(degrade'
c plugins/spec-distill/skills/framing-requests/SKILL.md '냅니다. 그 묶음은 **`AskUserQuestion` 최대 4개씩 연속 호출**로 나눠 띄우고, 매 호출 첫 질문의 첫 줄은 렌더'
c shared/docreview/references/reviewing-document.md '선택지가 사라지기 때문이다. 매 호출 첫 질문의 첫 줄은 렌더 첫 줄(degrade 공시)과 같다. 사용자'
c plugins/spec-distill/skills/framing-requests/SKILL.md '// **처분** — consumer=human · fail-open · disclosure=proceed 게이트 질문 텍스트'
c plugins/spec-distill/skills/reviewing-spec/SKILL.md '텍스트의 `degrade:` 슬롯에도 싣는다. 셋 다 비었을 때만 `degrade 없음` 이다 — 그 문구는 **채널을'
c plugins/spec-distill/skills/reviewing-brief/SKILL.md 'Step B 게이트를 띄우기 **직전에** 이 채널들을 읽어 하나도 빠뜨리지 않고 게이트 `question` 텍스트에'
```

- [ ] **Step 3: 기준선**

```bash
bash ~/.claude/sdd-mirror/plain-language-output/run-suite.sh pr2/baseline
```

PR 1 최종(`pr1/final`)과 비교해 새 RED 가 있으면 `pr2/baseline/NOTE.md` 에 적는다(머지된 main 이 가져온 것).

---

## Task 1: 게이트 틀의 새 규칙을 재는 락 (실패하는 테스트 먼저)

**Files:**
- Create: `plugins/spec-distill/tests/test_plain_gate_templates.sh`
- Modify: `shared/tests/test_docreview_round_gate_split.sh`(새 문장 양의 단언 · 옛 문장 부재)

**Interfaces:**
- Produces: `bash plugins/spec-distill/tests/test_plain_gate_templates.sh` — AC7 의 락. 단언 여덟(아래).

- [ ] **Step 1: 락을 쓴다**

`plugins/spec-distill/tests/test_plain_gate_templates.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/*/SKILL.md plugins/spec-distill/skills/conducting-interview/references/finishing.md plugins/spec-distill/references/proceed-gate.md
#
# 쉬운 말 출력 설계 §4 · AC7 — 모든 게이트 질문은 결정 하나와 상태 한 줄만 담고, 경고 목록은 앞 글에 쓴다.
# 「채널을 읽은 뒤에만 없음을 쓴다」 계약은 그대로 남는다.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  git -C "$REPO_ROOT" ls-files -- 'plugins/spec-distill/skills/*/SKILL.md' \
    plugins/spec-distill/skills/conducting-interview/references/finishing.md plugins/spec-distill/references/proceed-gate.md
  exit 0
fi
. "$REPO_ROOT/shared/tests/assert.sh"
SD="$REPO_ROOT/plugins/spec-distill"
FIN="$SD/skills/conducting-interview/references/finishing.md"
RS="$SD/skills/reviewing-spec/SKILL.md"
RB="$SD/skills/reviewing-brief/SKILL.md"
FR="$SD/skills/framing-requests/SKILL.md"
PG="$SD/references/proceed-gate.md"

# ① 머리글 「Proceed」가 없다(spec-distill 어디에도).
n="$(grep -rF -- 'header: "Proceed"' "$SD/skills" "$SD/references" | grep -c . || true)"
assert_eq "$n" "0" "AC7: 게이트 머리글이 「Proceed」가 아니다"
assert_file_grep "$FIN" 'header: "다음 단계"' "AC7 양의 짝: B-2 머리글이 「다음 단계」다"

# ② B-2 질문 한 줄이 경고 목록 대신 개수 한 줄만 싣는다.
QLINE="$(awk '/^#### B-2/{f=1} f && /^[[:space:]]*question:/{print; exit}' "$FIN")"
[ -n "$QLINE" ] && ok "B-2 question 줄을 찾았다" || no "B-2 question 줄이 없다 — 아래 단언이 공허하다"
assert_contains "$QLINE" '위에 적었다' "AC7: B-2 질문이 경고를 「경고 N개 — 위에 적었다」 한 줄로 가리킨다"
assert_not_contains "$QLINE" 'degrade:' "AC7: B-2 질문이 degrade 줄 목록 자리를 싣지 않는다"
assert_not_contains "$QLINE" '게이트 advisory:' "AC7: B-2 질문이 advisory 목록 자리를 싣지 않는다"

# ③ 경고는 앞 글로 — 채택 skill 의 degrade 자리가 「게이트 앞 글」을 이름으로 댄다.
for f in "$FIN" "$RS" "$RB" "$FR" "$PG"; do
  assert_file_grep "$f" '게이트 앞 글' "AC7: $(basename "$(dirname "$f")")/$(basename "$f") 가 경고를 게이트 앞 글에 쓰라고 지시한다"
done

# ④ 「채널을 읽은 뒤에만 없음」 문장이 넷 모두에 남는다.
for f in "$FIN" "$RS" "$RB" "$FR"; do
  assert_file_grep "$f" '실제로 읽었다는 주장' "AC7: $(basename "$(dirname "$f")") 에 「채널을 실제로 읽었다는 주장」 문장이 있다"
done

# ⑤ 「이상 없음」·「경고 없음」 구분(설계 표 7874b3bb#r2.1).
assert_file_grep "$PG" '남은 항목도 없으면 「이상 없음」' "Q1: 정본이 「이상 없음」을 남은 항목도 없을 때로 한정한다"
assert_file_grep "$PG" '「경고 없음」' "Q1: 정본이 「경고 없음」을 말한다"

# ⑥ 핸드오프 /compact 틀 둘이 규칙 유지 문장을 싣는다.
for f in "$FIN" "$RS"; do
  assert_eq "$(grep -c '/compact .*사람에게 쓰는 글 규칙' "$f" || true)" "1" "AC7: $(basename "$(dirname "$f")") 의 /compact 틀이 규칙 유지 문장을 싣는다"
done
RSC="$(grep '/compact 설계문서' "$RS" || true)"
assert_eq "$(printf '%s' "$RSC" | grep -oE '<[^>]+>' | sort -u | tr '\n' ' ')" "<spec_path> " "Review Focus 4: reviewing-spec /compact 틀의 꺾쇠 자리표가 <spec_path> 하나다"

# ⑦ framing-requests 의 옛 채널 이름이 남지 않는다(처분 앵커 포함).
assert_eq "$(grep -c '게이트 질문 텍스트' "$FR" || true)" "0" "Q3: framing-requests 에 옛 채널 이름 「게이트 질문 텍스트」가 없다"
assert_file_grep "$FR" 'disclosure=proceed 게이트 앞 글' "Q3 양의 짝: 처분 앵커가 새 이름을 댄다"

# ⑧ 질문에 그대로 남는 예외가 명시돼 있다(Q4).
assert_file_grep "$FR" '규칙 블록의 「따로 정한 자리」' "Q4: 저자 편집 덩어리를 질문에 그대로 싣는 것이 예외라고 적혀 있다"
finish
```

`shared/tests/test_docreview_round_gate_split.sh` 의 `--emit-scanned` 블록(36-40행)의 두 `echo` 뒤에 두 줄을 더한다 — 읽는 파일이 늘었다:

```bash
  echo "plugins/spec-distill/skills/reviewing-brief/SKILL.md"
  echo "plugins/spec-distill/skills/framing-requests/SKILL.md"
```

그리고 `finish`(108행) 앞에 넣는다(`REF` · `SKILL` 은 그 파일 45-46행이 정의한 절차서 · reviewing-spec 경로다):

```bash
# 쉬운 말 출력 PR 2 (계획 Q2) — 렌더 첫 줄은 첫 호출 앞 글에 한 번, 질문엔 결정 하나와 경고 개수 한 줄.
NEWRULE='렌더 첫 줄(상태와 경고)은 첫 호출 **앞 글**에 한 번 쓴다'
OLDRULE='매 호출 첫 질문의 첫 줄은 렌더'
for f in "$REF" "$SKILL" "$REPO_ROOT/plugins/spec-distill/skills/reviewing-brief/SKILL.md" "$REPO_ROOT/plugins/spec-distill/skills/framing-requests/SKILL.md"; do
  assert_eq "$(grep -cF -- "$NEWRULE" "$f" || true)" "1" "Q2: $f 가 렌더 첫 줄을 앞 글에 한 번 쓴다고 적는다"
  assert_eq "$(tr '\n' ' ' < "$f" | grep -cF -- "$OLDRULE" || true)" "0" "Q2: $f 에 옛 규칙(매 호출 첫 줄 = 렌더 첫 줄)이 없다"
  assert_eq "$(grep -cF -- '다른 결정의 답에 따라 달라지는 결정은 다음 호출로 미룬다' "$f" || true)" "1" "Q2: $f 가 「무관한 결정」의 뜻을 적는다"
done
```

옛 규칙의 부재는 줄바꿈을 지운 본문에서 잰다 — 옛 문장이 두 줄에 걸쳐 있어 줄 단위 grep 은 공허하다.

- [ ] **Step 2: 실패하는지 확인한다**

Run:
```bash
bash plugins/spec-distill/tests/test_plain_gate_templates.sh | tail -1
bash shared/tests/test_docreview_round_gate_split.sh | tail -1
```
Expected: 둘 다 `Fail:` 이 0 보다 크다.

- [ ] **Step 3: 커밋**

```bash
git add plugins/spec-distill/tests/test_plain_gate_templates.sh shared/tests/test_docreview_round_gate_split.sh
git commit -m "test(spec-distill): 게이트 질문에 결정 하나와 경고 개수만 싣는지 재는 락

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 2: interview 승인 게이트(B-2)와 핸드오프

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/references/finishing.md:296-340, :360`
- Modify: `plugins/spec-distill/tests/test_brief_review_entry.sh:221-223, :252-253, :261-275`

- [ ] **Step 1: 앞 글 목록에 경고 항목을 더하고 채널 문단을 고친다**

finishing.md 304-306 의 목록 끝(`3. **열린 채 남은 항목과 미반영 findings** — …` 두 줄) 바로 뒤에 넣는다:

```markdown
4. **경고** — 아래 「이 skill 의 degrade 채널」을 읽고 경고를 한 줄씩 쉬운 말로 쓴다(원문 사유 토큰은 괄호에).
   `check_brief.py gate` 의 `advisories` 도 여기 쓴다. 채널을 다 읽었는데 경고가 없으면, 남은 항목(위 3)도
   없을 때만 「이상 없음」, 남은 항목이 있으면 「경고 없음」 한 줄이다. 읽지 못한 채널은 「알 수 없음 — <사유>」
   로 따로 한 줄 쓴다.
```

308-315(옛):

```markdown
**이 skill 의 degrade 채널** (정본 Step B 가 각 skill 에 이름을 대라고 요구하는 그것):
`reviewing-brief` 의 `## degrade 채널` 다섯 — 엔진의 `fin.json` `advisory[]`·`blocks`·`gate --render` 첫 줄 +
state 의 `brief_review_degradations` 원장(BRIEF_REVIEW skip record 포함)·두 번째 채널 파일 — 과 웹 한 줄.
`degrade 없음`은 **그 채널들을 실제로 읽었다는 주장**이므로, 조회하지 않은 채 쓰지 않습니다.

그리고 `question` 텍스트에 **모든 degrade record를 한 줄씩** 싣습니다 — 옵션 description이
아니라 question 본문이어야 사용자가 옵션을 고르기 *전에* 봅니다. record가 없으면
`degrade 없음`을 한 줄로 명시합니다(침묵과 구분).
```

새:

```markdown
**이 skill 의 degrade 채널** (정본 Step B 가 각 skill 에 이름을 대라고 요구하는 그것):
`reviewing-brief` 의 `## degrade 채널` 다섯 — 엔진의 `fin.json` `advisory[]`·`blocks`·`gate --render` 첫 줄 +
state 의 `brief_review_degradations` 원장(BRIEF_REVIEW skip record 포함)·두 번째 채널 파일 — 과 웹 한 줄.
「이상 없음」·「경고 없음」은 **그 채널들을 실제로 읽었다는 주장**이므로, 조회하지 않은 채 쓰지 않습니다.

모든 degrade record 는 **게이트 앞 글**(위 목록 4)에 한 줄씩 씁니다 — 옵션 description 에 싣지 않습니다.
사용자가 옵션을 고르기 *전에* 읽도록 질문 바로 앞에 둡니다. 질문 본문에는 결정 하나와 그 개수 한 줄
(「경고 N개 — 위에 적었다」 또는 「경고 없음」·「이상 없음」)만 둡니다.
```

317-319 의 첫 문장 `` `check_brief.py gate` 의 `advisories` 도 이 텍스트에 싣습니다 — `` 를 `` `check_brief.py gate` 의 `advisories` 도 게이트 앞 글(목록 4)에 씁니다 — `` 로 바꾼다(나머지 문장과 아래 두 불릿 `내부 조사 0건` · `신 계약 미적용 brief` 는 그대로 — B-2 창 락이 그 두 낱말을 잰다).

- [ ] **Step 2: 질문 틀을 고친다**

329-335(옛 질문·머리글·옵션 넷)를 이것으로 바꾼다:

```javascript
    question: "interview brief 를 만들었다: <brief-path> (구조 검사 통과 · 리뷰 <게이트 결과 한 줄 — 왜 여기서 멈췄는지 · 남은 항목 수 · 리뷰를 마치지 못했으면 그 사유(unreviewed_reason)>). 경고 <N>개 — 위에 적었다 | 경고 없음 | 이상 없음. 다음 단계는?",
    header: "다음 단계",
    options: [
      {label: "확정하고 /compact 후 brainstorming (권장)", description: "확정 후보를 확정으로 바꿔 저장하고, 붙여 넣을 /compact 명령을 보여 준다. 긴 인터뷰 기록이 정리된 뒤 brainstorming 을 시작한다."},
      {label: "확정하고 바로 brainstorming", description: "확정 후보를 확정으로 바꿔 저장하고, 이 대화 그대로 brainstorming 을 시작한다(기록 정리 없음)."},
      {label: "확정 목록 수정", description: "확정 후보를 고쳐 다시 보여 준다(최대 2번). 아직 아무것도 확정되지 않는다."},
      {label: "brief만 종료", description: "brief 를 여기서 끝낸다. 모든 항목이 잠정으로 남고 다음 단계로 넘기지 않는다."}
    ],
```

라벨 넷은 그대로다(`test_conducting_interview_stage.sh:105-125` 가 잰다).

- [ ] **Step 3: `/compact` 틀에 규칙 유지 문장을 끼운다**

360행 안의 `**그리고 아래 '재결정 규약' 문장**을 유지하고,` 를 이것으로 바꾼다(같은 물리적 한 줄 안 — 줄을 나누지 않는다. 꺾쇠를 더하지 않는다):

```text
**그리고 아래 '재결정 규약' 문장**과 사람에게 쓰는 글 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 첫 줄에 상태, 끝에 할 일 하나)을 유지하고,
```

- [ ] **Step 4: 배치 락을 새 자리로 옮긴다**

`test_brief_review_entry.sh`:

| 자리 | 옛 | 새 | 지키는 뜻 |
|---|---|---|---|
| 221-223 | `for tok in 'readback' 'gap' 'degrade'; do` … `"B-2 question에 '$tok' 실림 …"` | 그대로 두고 메시지만 `"B-2 절에 '$tok' 이 있다 (느슨한 substring, defense-in-depth)"` | 산출물 셋이 B-2 에서 다뤄진다 |
| 252-253 | `grep -qE 'question 텍스트\|question 본문' …` · `"degrade가 question 텍스트에 렌더 …"` · `"렌더 위치(question 텍스트) 명시 부재"` | `grep -qF '게이트 앞 글' "${CI_FILES[@]}"` · `"degrade 가 게이트 앞 글에 쓰인다 (프로즈 서술)"` · `"degrade 의 자리(게이트 앞 글) 명시 부재"` | 사용자가 고르기 전에 경고를 본다 |
| 261-274 | `QLINE_CODE` 에 `degrade` 가 있어야 한다 | `QLINE_CODE` 에 `위에 적었다` 가 있어야 하고(`grep -qF '위에 적었다'`), `degrade:` 가 없어야 한다(`grep -qF 'degrade:'` 이면 `no`). 메시지: `"B-2 question: 라인이 경고를 개수 한 줄로 가리킨다 (placement, load-bearing)"` · `"B-2 question: 라인에 degrade 목록 자리가 남았다 — 목록은 게이트 앞 글로 갔다"` | 경고가 옵션 description 으로 숨지 않고, 질문은 결정 하나에 집중한다 |
| 275 | `grep -qE 'degrade 없음' …` · `"빈 배열도 명시"` | `grep -qE '「경고 없음」' "${CI_FILES[@]}" && grep -qE '「이상 없음」' "${CI_FILES[@]}"` · `"빈 배열도 명시(경고 없음 · 이상 없음)"` | 침묵과 「없음」을 가른다 |

261-274 의 주석(fix round 1 · Decoy 2 의 근거)은 그대로 둔다 — 「펜스 안 question: 줄만 잰다」는 근거는 바뀌지 않았다.

- [ ] **Step 5: 테스트를 돈다**

Run:
```bash
for t in test_brief_review_entry test_conducting_interview_stage test_review_handoff_order test_plain_gate_templates; do printf '%s ' "$t"; bash plugins/spec-distill/tests/$t.sh 2>&1 | tail -1; done
bash shared/tests/test_docreview_procedure_paths.sh | tail -1
```
Expected: `test_plain_gate_templates` 는 아직 RS · RB · FR · PG 단언이 RED(다음 Task 들), 나머지는 `Fail: 0`. `test_docreview_procedure_paths.sh:176` 은 B-2 창에 `interview brief 완결:` 을 찾는다 — 새 질문은 「interview brief 를 만들었다:」라 RED 가 된다. 그 단언을 `'interview brief 를 만들었다:'` 로 고친다(지키는 뜻: 창이 질문까지 닿는다).

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/skills/conducting-interview/references/finishing.md plugins/spec-distill/tests/test_brief_review_entry.sh shared/tests/test_docreview_procedure_paths.sh
git commit -m "feat(spec-distill): interview 다음 단계 게이트가 경고를 앞 글에 쓰고 질문엔 개수만 싣는다

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 3: 리뷰 라운드 게이트 · 승인 게이트 · 확정 게이트 (reviewing-spec · reviewing-brief · framing-requests · 정본)

**Files:**
- Modify: `shared/docreview/references/reviewing-document.md:27-30`
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md:363-366, :427-436, :490-492`
- Modify: `plugins/spec-distill/skills/reviewing-brief/SKILL.md:458-461, :580-583`
- Modify: `plugins/spec-distill/skills/framing-requests/SKILL.md`(577-579 · 593 · 722-727 · 810 · 814 · 821 · 831-833 · 850-858 · 873 · 879 · 936 · 956-968 · 1018 · 137 · 382)
- Modify: `plugins/spec-distill/references/proceed-gate.md:39-41`
- Modify: `plugins/spec-distill/tests/test_framing_review_contract.sh:535` · `plugins/spec-distill/tests/test_reviewing_brief_skill.sh:277-282`

- [ ] **Step 1: 라운드 게이트 문장 넷(Q2)**

네 파일의 옛 문장 — reviewing-document.md(30행 안), reviewing-spec(365-366), reviewing-brief(460-461):

```markdown
매 호출 첫 질문의 첫 줄은 렌더 첫 줄(degrade
공시)과 같다.
```

(줄바꿈 자리는 파일마다 다르다 — reviewing-document.md 는 `… 매 호출 첫 질문의 첫 줄은 렌더 첫 줄(degrade 공시)과 같다.` 가 한 줄 안에 있다.) 각 파일에서 그 문장을 이것으로 바꾼다:

```markdown
렌더 첫 줄(상태와 경고)은 첫 호출 **앞 글**에 한 번 쓴다. 질문 본문에는 그 질문의 결정 하나와, 경고가 있으면
「경고 N개 — 위에 적었다」 한 줄만 둔다. 한 호출에 묶는 질문은 서로의 답에 기대지 않는 결정이다 — 다른 결정의 답에 따라 달라지는 결정은 다음 호출로 미룬다.
```

락이 `렌더 첫 줄(상태와 경고)은 첫 호출 **앞 글**에 한 번 쓴다` 와 `다른 결정의 답에 따라 달라지는 결정은 다음 호출로 미룬다` 를 **한 줄 안에서** 찾으므로 이 둘은 각각 한 물리적 줄 안에 두고 그 사이에서만 줄을 나눈다.

framing-requests 577-579(옛): `냅니다. 그 묶음은 **`AskUserQuestion` 최대 4개씩 연속 호출**로 나눠 띄우고, 매 호출 첫 질문의 첫 줄은 렌더` / `첫 줄(degrade 공시)과 같습니다. ` → 새: `냅니다. 그 묶음은 **`AskUserQuestion` 최대 4개씩 연속 호출**로 나눠 띄웁니다.` 다음 줄에 위 새 문장(두 줄)을 그대로 둔다(「~다」체 그대로 — 이 문장은 네 파일에서 글자가 같아야 락이 같은 리터럴로 잰다).

- [ ] **Step 2: 정본의 승인 게이트 문장(Q1)**

proceed-gate.md 39-41(옛):

```markdown
게이트를 띄우기 **전에** 판정 결과와, 이번 라운드에 실제로 일어난 **degrade 를 하나도
빠뜨리지 않고** 프로즈로 출력한다. 하나도 없으면 그 사실을 한 줄로 명시한다 — 침묵과
구분되어야 한다.
```

새:

```markdown
게이트를 띄우기 **전에** 판정 결과와, 이번 라운드에 실제로 일어난 **degrade 를 하나도
빠뜨리지 않고** 게이트 앞 글에 쉬운 말로 쓴다(원문 사유 토큰은 괄호에). 채널을 다 읽었는데 경고가 없으면,
남은 항목도 없으면 「이상 없음」, 남은 항목이 있으면 「경고 없음」 한 줄이다 — 침묵과 구분되어야 한다.
읽지 못한 채널은 「알 수 없음 — <사유>」로 따로 쓴다. 질문 본문에는 결정 하나와 「경고 N개 — 위에 적었다」
(또는 「경고 없음」·「이상 없음」) 한 줄만 둔다. 머리글은 「다음 단계」다.
```

- [ ] **Step 3: reviewing-spec · reviewing-brief 의 degrade 채널과 reviewing-spec 핸드오프 틀**

reviewing-spec 490-492(옛):

```markdown
게이트를 띄우기 **직전에** 이 셋을 읽어 하나도 빠뜨리지 않고 프로즈로 내고, 승인 게이트 질문
텍스트의 `degrade:` 슬롯에도 싣는다. 셋 다 비었을 때만 `degrade 없음` 이다 — 그 문구는 **채널을
실제로 읽었다는 주장**이므로, 읽지 않은 채 쓰지 않는다.
```

새:

```markdown
게이트를 띄우기 **직전에** 이 셋을 읽어 하나도 빠뜨리지 않고 게이트 앞 글에 쓰고, 승인 게이트 질문에는
「경고 N개 — 위에 적었다」 한 줄만 둔다. 셋 다 비었으면 남은 항목도 없을 때 「이상 없음」, 있을 때 「경고 없음」이다
— 그 문구는 **채널을 실제로 읽었다는 주장**이므로, 읽지 않은 채 쓰지 않는다.
```

reviewing-brief 580-583(옛):

```markdown
Step B 게이트를 띄우기 **직전에** 이 채널들을 읽어 하나도 빠뜨리지 않고 게이트 `question` 텍스트에
싣는다. 전부 비었을 때만 `degrade 없음` 이다 — 그 문구는 **채널을 실제로 읽었다는 주장**이므로 읽지
않은 채 쓰지 않는다. `get` 이 실패하면(`ok: false`) 원장은 비어 있는 것이 아니라 **알 수 없는** 것이므로
`degrade 원장 판독 불가 — <get 이 낸 reason>` 을 한 줄로 쓴다.
```

새:

```markdown
Step B 게이트를 띄우기 **직전에** 이 채널들을 읽어 하나도 빠뜨리지 않고 게이트 앞 글에 쓴다(질문 본문에는
「경고 N개 — 위에 적었다」 한 줄). 전부 비었으면 남은 항목도 없을 때 「이상 없음」, 있을 때 「경고 없음」이다 — 그 문구는
**채널을 실제로 읽었다는 주장**이므로 읽지 않은 채 쓰지 않는다. `get` 이 실패하면(`ok: false`) 원장은 비어 있는
것이 아니라 **알 수 없는** 것이므로 `degrade 원장 판독 불가 — <get 이 낸 reason>` 을 한 줄로 쓴다.
```

`test_reviewing_brief_skill.sh:277-282` 의 `'degrade 없음'` 단언을 `'「경고 없음」'` 으로 바꾼다(같은 줄의 `'실제로 읽었다는 주장'` · `'알 수 없는'` 은 그대로 — 뜻: 「없음」은 읽었다는 주장이고 판독 실패는 「알 수 없음」이다).

reviewing-spec 436행(`- **① 의 정지 요건** — …`) 바로 앞에 틀을 넣는다(Q5):

```markdown
① 에서 노출하는 명령(`<spec_path>` 를 실제 경로로 바꾼 뒤 그대로 보인다):

> `/compact 설계문서 <spec_path> 보존 — 문서 경로, 결정 기록, Deferred to plan 목록을 유지하고 리뷰 라운드별 대화·지적 원문·엔진 출력은 drop. 재결정 규약: confirmed 항목은 근거 있으면 보고 후 재결정 가능하고 임의 변경은 금지다. 사람에게 쓰는 글 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 첫 줄에 상태, 끝에 할 일 하나)을 유지한다. 다음 단계: Skill superpowers:writing-plans <spec_path>.`

```

- [ ] **Step 4: framing-requests 의 채널 이름과 자리(Q3 · Q4)**

이름 바꾸기 — 아래 줄의 옛 글자를 새 글자로(줄 번호는 착수 시점에 `grep -n` 으로 다시 찾는다):

| 줄 | 옛 | 새 |
|---|---|---|
| 810 | `disclosure=proceed 게이트 질문 텍스트` | `disclosure=proceed 게이트 앞 글` |
| 832 | `proceed 게이트 질문 텍스트(**항상**). 원장이 없거나 개별 기록이 실패하면 게이트 텍스트가 유일한 채널이고,` | `proceed 게이트 앞 글(**항상**). 원장이 없거나 개별 기록이 실패하면 게이트 앞 글이 유일한 채널이고,` |
| 873 | `게이트 질문 텍스트에도 그렇게` | `게이트 앞 글에도 그렇게` |
| 879 | `게이트를 띄우고, 게이트 질문 텍스트에 degrade 를 **하나도 빠뜨리지 않고** 싣습니다.` | `게이트를 띄우고, 게이트 앞 글에 degrade 를 **하나도 빠뜨리지 않고** 씁니다. 질문 본문에는 결정 하나와 「경고 N개 — 위에 적었다」(또는 「경고 없음」·「이상 없음」) 한 줄만 둡니다. 경고가 없을 때의 두 문구는 **채널을 실제로 읽었다는 주장**이라 읽지 않은 채 쓰지 않습니다.` |
| 137 · 382 · 593 · 722 · 814 · 821 · 850 · 852 · 858 · 936 · 956 · 961 · 963 · 968 · 1018 | `게이트 텍스트` | `게이트 앞 글` (조사 「…에」·「…를」은 그대로 붙는다 — 예: `게이트 텍스트에` → `게이트 앞 글에`) |

`593` 은 고친 뒤 `게이트 앞 글에 \`ask_open\` 개수를 처분과 무관하게 싣는다.` 가 된다 — `test_framing_review_contract.sh:85` 가 잡는 부분 문자열 `` `ask_open` 개수를 처분과 무관하게 싣는다 `` 는 그대로다.

203 행의 `**질문 텍스트**에 싣는다` 와 725 행의 `덩어리 본문(\`render\`)은 질문 텍스트에 줄임 없이 싣는다` 는 그대로 둔다 — 앞엣것은 형성 라운드의 질문 자체이고, 뒤엣것이 Q4 의 예외다. 725 행 문장 끝에 덧붙인다:

```markdown
 이 덩어리 본문은 규칙 블록의 「따로 정한 자리」다 — 질문 하나에 결정 하나라는 규칙의 예외로, 결정의 대상 자체라 질문에 그대로 싣는다.
```

727 행 `그 사실을 게이트 텍스트에 싣고 seed 전문을 한 질문으로` → `그 사실을 게이트 앞 글에 쓰고 seed 전문을 한 질문으로`(seed 전문은 결정의 대상이라 질문에 남는다 — Q4).

`test_framing_review_contract.sh:535` — `'게이트 질문 텍스트'` → `'게이트 앞 글'`(지키는 뜻: 다섯째 채널을 이름으로 댄다).

바꾼 뒤 확인:

```bash
grep -c '게이트 질문 텍스트\|게이트 텍스트' plugins/spec-distill/skills/framing-requests/SKILL.md
bash shared/tests/test_dispatch_disposition.sh | tail -1
```
Expected: `0`, `Fail: 0`(축 C — 앵커 리터럴 「proceed 게이트 앞 글」이 같은 파일 본문 832 행에 있다).

- [ ] **Step 5: 테스트를 돈다**

Run:
```bash
for t in test_plain_gate_templates test_framing_review_contract test_reviewing_brief_skill test_reviewing_spec_disclosure test_proceed_gate_adopters test_review_handoff_order test_reviewing_spec_entry_fence test_seed_review_log; do printf '%s ' "$t"; bash plugins/spec-distill/tests/$t.sh 2>&1 | tail -1; done
for t in test_docreview_round_gate_split test_dispatch_disposition test_docreview_procedure_paths; do printf '%s ' "$t"; bash shared/tests/$t.sh 2>&1 | tail -1; done
```
Expected: 전부 `Fail: 0`.

- [ ] **Step 6: 커밋**

```bash
git add shared/docreview/references/reviewing-document.md plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/skills/framing-requests/SKILL.md plugins/spec-distill/references/proceed-gate.md plugins/spec-distill/tests/test_framing_review_contract.sh plugins/spec-distill/tests/test_reviewing_brief_skill.sh
git commit -m "feat(spec-distill): 모든 게이트가 경고를 앞 글에 쓰고 질문엔 결정 하나만 싣는다

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 7: 변이(AC7)**

각 변이 뒤 `bash plugins/spec-distill/tests/test_plain_gate_templates.sh | tail -1` 이 `Fail: 0` 이 아니어야 한다. 복원은 `git checkout HEAD -- <파일>`.

1. reviewing-brief 의 「실제로 읽었다는 주장」 문장 지우기 → ④ RED(`test_reviewing_brief_skill.sh` 도 RED).
2. finishing.md 질문 줄에 `degrade: <record 한 줄씩>.` 되살리기 → ② RED.
3. framing-requests 810 행을 옛 이름으로 되돌리기 → ⑦ RED, `test_dispatch_disposition.sh` 는 GREEN 일 수 있다(축 C 는 이름의 실재만 잰다 — 옛 이름이 본문에 없어 RED 가 날 수도 있다. 어느 쪽이든 기록한다).
4. reviewing-spec `/compact` 틀에 `<doc>` 를 더하기 → ⑥ RED.
5. proceed-gate.md 의 「남은 항목도 없으면 「이상 없음」」 지우기 → ⑤ RED.

결과를 `~/.claude/sdd-mirror/plain-language-output/pr2/mutations.txt` 에 적는다.

---

## Task 4: 사람이 보는 고정 문구 (설계 §3 · §6 · Q7)

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md` · `reviewing-brief/SKILL.md` · `framing-requests/SKILL.md`(codex 건너뜀 줄 · 기준 사본 줄 · brief 리뷰 건너뜀 줄)
- Modify: `plugins/spec-distill/skills/conducting-interview/references/finishing.md`(216 · 282 행 문구)
- Modify: `plugins/spec-distill/scripts/check_brief.py`(advisory 두 줄의 「Step B 게이트」, coverage-mapper 줄)
- Modify: 그 문구를 고정한 테스트(아래 표)

- [ ] **Step 1: 고칠 문구의 고정 단언을 전수로 찾는다(Deferred 2)**

```bash
for lit in 'codex co-review SKIPPED' '기준 사본이 없다' 'brief 리뷰 SKIPPED' '확정 확인 재제시 상한(2회) 초과' 'superpowers 설치 시 brainstorming' 'Step B 게이트에서 사람이 한다' 'dispatch 없이 통과 (advisory, 사람이 확인)'; do
  printf '== %s\n' "$lit"
  /usr/bin/grep -rnF -- "$lit" plugins shared tools 2>/dev/null | grep -v '/golden/' | cut -c1-180
done > ~/.claude/sdd-mirror/plain-language-output/pr2/fixed-string-hits.txt
cat ~/.claude/sdd-mirror/plain-language-output/pr2/fixed-string-hits.txt | grep -c .
```

조사(2026-10-08) 때 `codex co-review SKIPPED` 의 테스트 자리는 14곳(`test_reviewing_brief_residue.sh` 7 · `test_reviewing_spec_residue.sh` 5 · `test_seed_gate_wiring.sh` 2)이었다. 다른 플러그인(quality-gates · plugin-audit)의 같은 꼴 문구는 그 PR 이 다룬다 — 여기서는 `plugins/spec-distill` 과 그 문구를 읽는 `shared/tests` 만 고친다.

- [ ] **Step 2: 문구를 바꾼다**

| 자리 | 옛 | 새 |
|---|---|---|
| reviewing-spec 277 · framing-requests 519 (codex-gate 펜스) | `[spec-distill] codex co-review SKIPPED (reason: ${skip_reason:-unknown}) — Claude-only, 이 리뷰에는 모델 다양성이 없었다 (degraded).` | `[spec-distill] codex 리뷰를 건너뛰었다 (reason: ${skip_reason:-unknown}) — 이번 리뷰는 Claude 만 봤다. 다른 모델의 시각이 없다 (degraded).` |
| reviewing-brief 287 | `[spec-distill] codex co-review SKIPPED (reason: ${skip_reason:-unknown}) — Claude-only, 이 리뷰에는 codex 쪽의 모델 다양성과 웹 근거가 없었다 (degraded).` | `[spec-distill] codex 리뷰를 건너뛰었다 (reason: ${skip_reason:-unknown}) — 이번 리뷰는 Claude 만 봤다. 다른 모델의 시각과 codex 쪽 웹 근거가 없다 (degraded).` |
| framing-requests 516(있으면 — 같은 꼴의 다른 줄) | `codex co-review SKIPPED` | `codex 리뷰를 건너뛰었다` (그 줄의 나머지는 위 줄과 같은 방식으로) |
| framing-requests 717 · 1011 | `[spec-distill] 기준 사본이 없다(${SEED_BASE:-}) — 저자 편집을 비교할 수 없다.` | `[spec-distill] 기준 사본이 없다(${SEED_BASE:-}) — 저자가 seed 를 고쳤는지 대조할 수 없다.` (뒤의 모델 지시 꼬리는 그대로) |
| reviewing-brief 70 | `[spec-distill] brief 리뷰 SKIPPED (DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW=1) — 엔진 라운드·냉독 전부 미검증. Step B 게이트에서 확인하세요.` | `[spec-distill] brief 리뷰를 건너뛰었다 (DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW=1) — 리뷰 라운드도 냉독도 돌지 않았다. 다음 단계 게이트에서 확인하라.` |
| finishing.md 216 | `[spec-distill] 확정 확인 재제시 상한(2회) 초과 — 전 항목 provisional 강등` | `[spec-distill] 확정 목록을 두 번 다시 보여 줬는데도 정하지 못했다 — 모든 항목을 잠정(provisional)으로 둔다` |
| finishing.md 282 | `[spec-distill] interview brief 완결: docs/superpowers/interview/<file>. superpowers 설치 시 brainstorming 해답공간 단계로 이어집니다. 미설치 시 이 brief를 직접 다음 작업의 입력으로 사용하세요.` | `[spec-distill] interview brief 를 만들었다: docs/superpowers/interview/<file>. superpowers 가 있으면 brainstorming 으로 이어지고, 없으면 이 brief 를 다음 작업의 입력으로 쓴다.` |
| check_brief.py `INTERNAL_RESEARCH_ZERO_ADVISORY` | `… 그 판단은 Step B 게이트에서 사람이 한다.` | `… 그 판단은 다음 단계 게이트에서 사람이 한다.` |
| check_brief.py 1268 행 | `coverage-mapper 0 ({reason}) — dispatch 없이 통과 (advisory, 사람이 확인)` | `coverage-mapper 0 ({reason}) — 범위 조사 에이전트를 부르지 않고 통과했다 (사람이 확인할 것)` |

`reason:` 토큰과 `(degraded)` 표지는 남는다(Review Focus 5). `codex co-review SKIPPED` 를 대상 줄에서만 바꾸고, 같은 펜스의 다른 글자(가용성 판정 · 잔존물 중화)는 건드리지 않는다.

- [ ] **Step 3: 고정 단언을 새 문구로**

Step 1 의 목록에서 **단언**인 자리를 새 문구로 고친다. 기계적 치환 둘은 job tmp 스크립트로 한다:

`/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr2_fix_pins.py`:

```python
import io, subprocess
ROOT = "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice/"
PAIRS = [("codex co-review SKIPPED", "codex 리뷰를 건너뛰었다"),
         ("brief 리뷰 SKIPPED", "brief 리뷰를 건너뛰었다")]
files = subprocess.run(["git", "-C", ROOT, "ls-files", "--", "plugins/spec-distill/tests", "shared/tests"],
                       capture_output=True, text=True, check=True).stdout.split()
for rel in files:
    p = ROOT + rel
    try:
        t = io.open(p, encoding="utf-8").read()
    except (UnicodeDecodeError, IsADirectoryError):
        continue
    n = t
    for a, b in PAIRS:
        n = n.replace(a, b)
    if n != t:
        io.open(p, "w", encoding="utf-8").write(n)
        print("fixed", rel)
```

나머지는 손으로 고친다:

| 자리 | 옛 | 새 | 지키는 뜻 |
|---|---|---|---|
| `test_conducting_interview_stage.sh:134` | `'[spec-distill] 확정 확인 재제시 상한(2회) 초과 — 전 항목 provisional 강등'` | `'[spec-distill] 확정 목록을 두 번 다시 보여 줬는데도 정하지 못했다 — 모든 항목을 잠정(provisional)으로 둔다'` | 재제시 상한 도달 시 고정 문구로 강등을 알린다 |
| Step 1 목록의 `superpowers 설치 시` · `Step B 게이트에서 사람이 한다` · `dispatch 없이 통과` 단언 | 옛 문구 | 새 문구 | 각 단언이 말하는 뜻 |

- [ ] **Step 4: 테스트를 돈다**

Run:
```bash
bash ~/.claude/sdd-mirror/plain-language-output/run-suite.sh pr2/after-task4 plugins/spec-distill
bash shared/tests/test_plugin_root_no_cwd_fallback.sh | tail -1
```
Expected: `pr2/baseline` 의 spec-distill 실패 목록과 같다(`comm -13` 이 빈 출력).

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/skills plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/tests shared/tests
git status --porcelain
git commit -m "feat(spec-distill): 사람이 보는 고정 경고를 쉬운 말로

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 5: README · 소개 문구 · 버전 (설계 §8 · AC10)

**Files:**
- Modify: `plugins/spec-distill/README.md`
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`(description · version) · `.claude-plugin/marketplace.json`(spec-distill 항목 description)
- Modify: `plugins/spec-distill/CHANGELOG.md`

- [ ] **Step 1: README 를 새 규칙대로 다시 쓴다**

구조(이 순서):

1. 첫 문단 — 이 플러그인이 무엇을 해 주는지 세 문장 안에. 「흐릿한 요청을 → 인터뷰로 brief 로 → 설계문서 리뷰까지」. 내부 번호·약어는 첫 등장에 풀어 쓴다.
2. `## 쓰는 법` — 명령 둘(`/request-framing` · `/interview`)과 skill 하나(`reviewing-spec`)를 한 줄씩. 각 줄은 「언제 쓰나 — 무엇이 나오나」.
3. `## 흐름` — 지금 README 의 흐름 그림(33 · 48 행의 게이트 줄 포함)을 유지하되 머리글과 설명 문장을 쉬운 말로.
4. `## 끄는 법` — kill switch 표(지금 있는 스위치 전부, 이름은 영어 그대로).
5. `## Principles Instantiated` — 제목·하위 제목(`### Three Laws` · `### Principles 흡수` · `### Roadmap absorption (C-numbers)` · `### Anti-pattern 회피`)과 불릿 형식(`- **Law N (…) — … (vX)** — …`)은 그대로 둔다. 불릿 본문만 쉬운 문장으로 다듬되, 아래 낱말은 지우지 않는다.

지워지면 안 되는 낱말(README 락 — 조사 2026-10-08):
- `test_readme_sync.sh:62-64`: `DEVBREW_SPEC_DISTILL_DISABLE_WEB` · `spec-distill:review-entry` · `review_entry.py` · `interview-brief` · `steelman-builder` · `DEVBREW_SPEC_DISTILL_DISABLE_CODEX` · `model diversity` · `coverage-mapper` · `blind-spot-prober` · `user_sourced_items` · `audit_file` · `user_statements` · `bijection`.
- `test_readme_sync.sh:68`(Principles 창): `라운드별 잠금|라운드마다 결정` · `일괄 확인|사용자 확인` · `payload.*audit|2파일|두 파일` · `user_sourced_items`.
- `test_readme_sync.sh:81-82`: `2파일 쌍` · `.audit.md` · `8섹션`.
- `test_reviewing_brief_skill.sh`(README 의 `G1..G<N>` 범위 = SKILL 표 끝), `test_rereview_cap_consistency.sh`, `test_conducting_interview_stage.sh:1431-1455`(`<n>-path` 개수, 살아 있는 `5-type` 없음), `shared/tests/test_python_floor.sh` 의 spec-distill README 단언.

쓰고 나서 위 락을 모두 돌린다:

```bash
for t in test_readme_sync test_reviewing_brief_skill test_rereview_cap_consistency test_conducting_interview_stage; do printf '%s ' "$t"; bash plugins/spec-distill/tests/$t.sh 2>&1 | tail -1; done
bash shared/tests/test_python_floor.sh | tail -1
```
Expected: 전부 `Fail: 0`.

- [ ] **Step 2: 소개 문구를 두 파일에서 같게**

새 문장(영어 — 설계 §8):

```text
Turns a rough request into a ready-to-plan design: a short interview (with web research and a devil's-advocate check) writes a brief for brainstorming, and each design doc gets an independent reviewer that cannot edit it.
```

`plugins/spec-distill/.claude-plugin/plugin.json` 의 `"description"` 과 `.claude-plugin/marketplace.json` 의 `"name": "spec-distill"` 항목 `"description"` 을 이 문장으로 바꾼다. 확인:

```bash
python3 -c 'import json; a=json.load(open("plugins/spec-distill/.claude-plugin/plugin.json",encoding="utf-8"))["description"].strip(); b=[p for p in json.load(open(".claude-plugin/marketplace.json",encoding="utf-8"))["plugins"] if p["name"]=="spec-distill"][0]["description"].strip(); print("same" if a==b else "DIFF")'
bash shared/tests/test_charter_citations.sh | tail -1
```
Expected: `same`, `Fail: 0`(마켓플레이스 금지 표현 「two gates」류가 없다).

- [ ] **Step 3: 버전과 CHANGELOG**

origin/main 의 spec-distill 버전을 다시 보고 minor 를 올린다. CHANGELOG 맨 위 항목 앞:

```markdown
## [<새 버전>] — <YYYY-MM-DD>

### Changed
- 모든 게이트(interview 다음 단계 · 설계문서 승인 · 리뷰 라운드 · request-framing 확정)가 경고 목록을 질문 앞 글에 쓰고, 질문에는 결정 하나와 「경고 N개 — 위에 적었다」 한 줄만 싣는다. 머리글 「Proceed」는 「다음 단계」다. 「이상 없음」은 남은 것도 경고도 없을 때만, 남은 것이 있으면 「경고 없음」이다.
- framing-requests 의 degrade 채널 이름이 「proceed 게이트 앞 글」이다(처분 앵커 포함).
- 핸드오프 `/compact` 명령이 사람에게 쓰는 글 규칙도 유지하게 한다. reviewing-spec 에 그 명령 틀이 생겼다.
- codex 건너뜀 · brief 리뷰 건너뜀 · 기준 사본 부재 · 확정 재제시 상한 문구가 쉬운 말이다(사유 토큰은 그대로).
- README 와 소개 문구를 쉬운 말로 다시 썼다.
```

- [ ] **Step 4: 최종 스위트와 대조**

```bash
bash ~/.claude/sdd-mirror/plain-language-output/run-suite.sh pr2/final
comm -13 ~/.claude/sdd-mirror/plain-language-output/pr2/baseline/failures.txt ~/.claude/sdd-mirror/plain-language-output/pr2/final/failures.txt
```
Expected: 빈 출력.

- [ ] **Step 5: 커밋 · /qg · PR**

```bash
git add plugins/spec-distill/README.md plugins/spec-distill/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/spec-distill/CHANGELOG.md
git commit -m "docs(spec-distill): README 와 소개 문구를 쉬운 말로, 버전 올림

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

`/qg branch` 를 돌리고 리뷰어에게 명시해 묻는다: 「경고를 앞 글로 옮긴 뒤에도 사용자가 고르기 전에 경고를 보는가 · 배치 락(`test_brief_review_entry.sh`)이 옮긴 뜻을 지키는가 · 처분 앵커와 본문 채널 이름이 같은 글자인가」.

PR 본문(한국어): 첫 줄에 바뀐 것 한 문장 · 「계획이 정한 것」 Q1~Q8 · 문구 고정 테스트 표(Task 2 Step 4, Task 4 Step 3 — 옛 → 새 · 지키는 뜻) · 고정 문구 분류 표(Q7) · 변이 결과 · 할 일 하나: 「`/request-framing` 으로 작은 요청 하나를 넣고 `/interview` 끝의 다음 단계 질문까지 가서, 경고가 질문 앞에 있고 질문은 짧은지 봐 주세요」(Verification Plan 4). 맨 끝 `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

머지는 사용자가 `! gh pr merge <n> --merge`. 머지 뒤 main 을 merge 로 받고 PR 3 계획으로 간다.
