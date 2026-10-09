# 쉬운 말 출력 PR 2 — spec-distill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill 의 모든 게이트(승인 · 리뷰 라운드 · request-framing 확정)가 질문 본문에 결정 하나와 상태 한 줄만 담고, 경고 목록은 질문 앞 글에 쉬운 말로 쓰게 한다. 사람이 보는 고정 경고와 출력 예시 문구, README, 소개 문구를 쉬운 말로 다듬는다. PR 1 이 미룬 문서 리뷰 엔진 렌더 다듬기 여섯(경고 문구 · 같은 자리 표지 · 낡은 주석 · 막힌 이유 접기 · 리뷰어 문장 반복 · 「미검증」 첫 줄)도 닫는다. 착수 전 기준선과 비교해 새 실패는 0 이어야 한다.

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
- **버전** — spec-distill minor(게이트 틀이 바뀐다). quality-gates 는 patch(Task 5 가 바꾸는 엔진 스크립트가 링크로 실린다 — Q12). 번호는 머지 직전 origin/main 기준으로 다시 정한다. `.claude-plugin/marketplace.json` 의 spec-distill 소개 문구도 같은 커밋에서 바꾼다.
- **지시문은 그대로** — 찾는 지시·판정 규칙·kill switch 문장은 한 글자도 바꾸지 않는다. 바꾸는 것은 사용자에게 보이는 문구와 그 문구의 자리다. 모델에게 쓰는 실패 안내(「플러그인 루트 미해석 — …」 · `RETURN_MSG` 꼬리의 「…하라」)는 그대로 둔다.
- **산출 보존** — `~/.claude/sdd-mirror/plain-language-output/pr2/`.
- **줄 번호** — 이 계획의 줄 번호는 2026-10-08(PR 1 이전) 기준이다. PR 1 이 모든 `plugins/*/skills/*/SKILL.md` · `plugins/*/commands/*.md` 의 H1 뒤에 14줄(빈 줄 + 블록 13줄)을 넣었으므로 그 파일들의 줄 번호는 +14 다. 다른 파일(references · scripts · tests)은 그대로다. 편집은 줄 번호가 아니라 「옛」 문구로 찾는다.
- **드라이런** — 2026-10-09 abc70f66 복사본에서 이 계획을 끝까지 실행해 불일치 13건을 고쳐 반영했다(보고서: `/Users/jeonghokim/.claude/sdd-mirror/plain-language-output/research/dryrun-pr2-report.md`). Task 5 는 4d325819 복사본에서 따로 실행했다(보고서: `/Users/jeonghokim/.claude/sdd-mirror/plain-language-output/research/dryrun-pr2-task5-report.md`).

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
| Q9 | 렌더 첫 줄의 경고는 advisory 원문을 **렌더에서만** 쉬운 줄로 바꾼다(`docreview_state.WARN_GLOSS` · `_plain_warns`). 원문(`fin.json` · `gate` JSON · 원장 · `adjudication.reasons()`)은 그대로다. 같은 사실을 두 출처가 말한 원문(「codex 없음」+「입력 실패(보조): codex」, 「기각 경로 0」+「입력 실패(보조): doc-recritic」, 「상세 미검증」+「셀 수 없음: layer2」)은 한 줄로 합치고 두 사유 토큰을 모두 그 줄 괄호에 싣는다. 표에 없는 원문은 그대로 싣는다. 그래서 「경고 N개」의 N 은 원문 수가 아니라 사실 수다 — P6(전부 싣는다)은 「모든 원문이 어느 한 줄에 대응한다」로 읽는다(재결정 보고 — 사용자 승인 2026-10-09 「합친다」). | 설계 §3 원칙 1(사람용과 기계용을 가른다) · 규칙 블록(쉬운 문장 먼저, 내부 용어는 괄호에). 소비자 조사: 원문을 글자로 읽는 단언이 `cases.sh` 다섯 자리 · qg `test_synthesize_findings_adjudication.py:209` · golden 에 있다(Task 5 머리). |
| Q10 | 「미검증」·라운드 미완이면 첫 줄에 「남은 것 없음」도 쓰지 않는다 — 「…. 리뷰 N라운드.」로 끝난다. 남은 항목이 있으면 「…가 남았다.」는 그대로 쓴다. | 설계 §3 「「미검증」·라운드 미완이면 그 공시가 맨 앞이고 두 문구(이상 없음 · 경고 없음) 어느 것도 쓰지 않는다」와 같은 이유 — 세지 못한 라운드에 「없음」을 쓰지 않는다. PR 1 이연 (g). |
| Q11 | 「┆ 같은 자리」 표지는 묶음(GATE_ROWS 한 행) 안에서만 앞 항목을 가리킨다 — 묶음마다 새로 센다. | D24 「묶음은 표시일 뿐」. golden T22 실측: 「다른 결정으로 넘어간 것 1개」 제목 바로 아래 표지가 앞 묶음의 항목을 가리켰다. |
| Q12 | quality-gates 도 patch 를 올리고 CHANGELOG 에 한 줄 쓴다. | 엔진 스크립트(`docreview_state.py`)가 `plugins/quality-gates/scripts/` 에 링크로 실린다 — 내용이 바뀌면 그 플러그인의 cache key 도 바뀌어야 한다(CLAUDE.md 「모든 PR마다 SemVer bump」). PR 1 도 네 플러그인을 올렸다. |

## Review Focus

1. **경고가 있는데 질문만 보고 고른다** — 질문에 경고가 하나도 없으면 사용자는 앞 글을 건너뛰고 고를 수 있다. 사람은 「경고가 있으면 질문에서도 그 사실이 보이기」를 기대한다. → Task 2 의 락: 질문에 `경고 <N>개 — 위에 적었다 | 경고 없음 | 이상 없음` 자리가 있다.
2. **경고 채널을 못 읽었는데 「이상 없음」** — 원장 `get` 이 실패한 세션. 사람은 「알 수 없음」을 기대한다. → 기존 락 `test_reviewing_brief_skill.sh` 의 「알 수 없는」 단언이 그대로 GREEN 인지 Task 3 에서 확인하고, 새 락이 `실제로 읽었다는 주장` 문장을 채택 skill 넷 전부에서 잰다.
3. **이름을 바꾼 채널이 처분 앵커에는 옛 이름으로 남는다** — 축 C 락은 이름의 실재만 잰다(CLAUDE.md 가 그 한계를 적는다). → Task 3 Step 4 가 앵커와 본문을 같은 글자로 바꾸고, 옛 이름이 FR 어디에도 없음을 잰다.
4. **압축 명령에 새 꺾쇠 자리표가 끼어든다** — 사용자가 그대로 붙여 넣는 명령이 `<…>` 를 품으면 그대로 실행된다. → Task 2 Step 1 의 단언은 기존 `test_review_handoff_order.sh` 가 이미 잰다(자리표 집합 = `<brief-path>`). reviewing-spec 새 틀도 자리표를 `<spec_path>` 하나로 제한하고 그것을 잰다.
5. **codex 건너뜀 줄의 사유 토큰이 사라진다** — 사람은 「왜 건너뛰었는지」를 원문 토큰으로 보기를 기대한다(`kill_switch` · `detector_not_runnable`). → Task 4 의 새 문구가 `(reason: <x>)` 를 그대로 품고, 14곳의 단언이 그 토큰까지 계속 잰다.
6. **경고를 합치다 경고 하나가 사라진다** — 합치는 행이 서로 다른 사실을 같은 키로 묶거나, 표에 없는 원문을 버리면 첫 줄에서 경고가 조용히 빠진다. 사람은 「경고 수가 줄어도 빠진 사실은 없다」를 기대한다. → Task 5 의 락: 원문 여섯 → 줄 셋과 각 줄의 사유 토큰(`case_plain_warns_first_line`), 표에 없는 원문은 그대로(`case_plain_warns_unknown_kept`), 변이 넷(`warns_*`). 엔진 원문의 글자가 바뀌면 그 행이 안 맞아 원문이 그대로 나온다 — 쉬운 말은 잃어도 경고는 안 잃는다.

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

`/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr2_anchor_check.sh` 를 쓰고 돌린다 — 아래 Task 들이 바꾸는 옛 문구가 그 파일에 정확히 한 번 있는지(`grep -cF`) 센다. 대상은 각 Task 의 「옛」 블록 첫 줄이다. 기대 개수와 다른 것이 있으면 멈춰 보고한다(기본 기대값은 1 이고, 아래 `c` 의 셋째 인자로 따로 준 것은 그 값이다).

```bash
#!/usr/bin/env bash
set -u
R=/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice
c() { n="$(grep -cF -- "$2" "$R/$1")"; e="${3:-1}"; [ "$n" = "$e" ] && s=ok || s=STOP; printf '%s\t%s\t%s\t%s\t%s\n' "$s" "$n" "$1" "$2" "(기대 $e)"; }
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
# Task 4 Step 2 표의 옛 문구(첫 줄)
c plugins/spec-distill/skills/reviewing-spec/SKILL.md '[spec-distill] codex co-review SKIPPED (reason: ${skip_reason:-unknown}) — Claude-only, 이 리뷰에는 모델 다양성이 없었다 (degraded).'
c plugins/spec-distill/skills/reviewing-brief/SKILL.md '[spec-distill] codex co-review SKIPPED (reason: ${skip_reason:-unknown}) — Claude-only, 이 리뷰에는 codex 쪽의 모델 다양성과 웹 근거가 없었다 (degraded).'
c plugins/spec-distill/skills/framing-requests/SKILL.md '[spec-distill] codex co-review SKIPPED (reason: ${skip_reason:-unknown}) — seed 리뷰에 codex 쪽 모델 다양성이 없었다 (degraded).'
c plugins/spec-distill/skills/framing-requests/SKILL.md '[spec-distill] 기준 사본이 없다(${SEED_BASE:-}) — 저자 편집을 비교할 수 없다.' 2
c plugins/spec-distill/skills/reviewing-brief/SKILL.md '[spec-distill] brief 리뷰 SKIPPED (DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW=1)'
c plugins/spec-distill/skills/conducting-interview/references/finishing.md '[spec-distill] 확정 확인 재제시 상한(2회) 초과 — 전 항목 provisional 강등'
c plugins/spec-distill/skills/conducting-interview/references/finishing.md '[spec-distill] interview brief 완결: docs/superpowers/interview/<file>. superpowers 설치 시'
c plugins/spec-distill/scripts/check_brief.py '그 판단은 Step B 게이트에서 "'
c plugins/spec-distill/scripts/check_brief.py 'coverage-mapper 0 ({reason}) — dispatch 없이 통과 (advisory, 사람이 확인)'
# Task 5 의 옛 문구(첫 줄)
c shared/docreview/scripts/docreview_state.py '            warns.insert(0, cl)'
c shared/docreview/scripts/docreview_state.py '    s = head + (" — %s가 남았다." % " · ".join(left) if left else " — 남은 것 없음.")'
c shared/docreview/scripts/docreview_state.py '% (_one(st["findings"][fid].get("summary")), why, fid)]'
c shared/docreview/scripts/docreview_state.py '        for fid in g[row.name]:'
c shared/docreview/agents/doc-critic.md '는 사용자가 게이트에서 그대로 읽는다 — 처음 보는 사람이 읽는다 —'
c shared/tests/fixtures/docreview/cases.sh '# ── 게이트 머리의 순서 뜻 한 줄 + 같은 anchor 묶음'
c shared/tests/fixtures/docreview/cases.sh '  # 「] <fid>」로 시작한다(그 뒤 구분자만 「—」/「→」로 갈린다 — `_rg_superseded`'
```
`STOP` 이 하나라도 나오면 그 줄의 Task(Task 4 · Task 5)로 가기 전에 멈춰 보고한다. 옛 문구가 파이썬 문자열 리터럴 둘로 나뉜 자리(check_brief.py)는 한 물리적 줄 안의 조각만 센다.

- [ ] **Step 3: 기준선**

```bash
bash ~/.claude/sdd-mirror/plain-language-output/run-suite.sh pr2/baseline
```

PR 1 최종(`pr1/final`)과 비교해 새 RED 가 있으면 `pr2/baseline/NOTE.md` 에 적는다(머지된 main 이 가져온 것).

---

## Task 1: 게이트 틀의 새 규칙을 재는 락 (실패하는 테스트 먼저)

**Files:**
- Create: `plugins/spec-distill/tests/test_plain_gate_templates.sh`
- Modify: `shared/tests/test_docreview_round_gate_split.sh`(새 문장 양의 단언 · 옛 문장 부재 · 2행 `# guards:` 머리줄 넓힘)

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

같은 파일 2행의 `# guards:` 를 `# guards: shared/docreview/references/reviewing-document.md plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/skills/framing-requests/SKILL.md` 로 바꾼다. 읽는 파일이 늘면 선언도 같이 넓힌다(`test_guards_coverage_bidirectional.sh` 가 두 방향으로 잰다).

옛 규칙의 부재는 줄바꿈을 지운 본문에서 잰다 — 옛 문장은 파일마다 줄바꿈 자리가 달라 다시 쓰일 때 OLDRULE 이 줄을 넘을 수 있다.

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
Expected: `test_plain_gate_templates` 는 아직 RS · RB · FR · PG 단언이 RED(다음 Task 들), 나머지는 `Fail: 0`. `test_docreview_procedure_paths.sh:176` 은 지금 GREEN 이다(B-1 의 282행도 `interview brief 완결:` 을 품는다). Task 4 가 282행을 바꾸면 RED 가 된다. B-2 에만 있는 리터럴로 바꾼다: `assert_contains "$FIN_STEPB" 'header: "다음 단계"'`(지키는 뜻: 창이 B-2 질문 펜스까지 닿는다).

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/skills/conducting-interview/references/finishing.md plugins/spec-distill/tests/test_brief_review_entry.sh shared/tests/test_docreview_procedure_paths.sh
git commit -m "feat(spec-distill): interview 다음 단계 게이트가 경고를 앞 글에 쓰고 질문엔 개수만 싣는다

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 3: 리뷰 라운드 게이트 · 승인 게이트 · 확정 게이트 (reviewing-spec · reviewing-brief · framing-requests · 정본)

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/references/finishing.md:241, :252, :253`(Step 4 의 경고 위치 행)
- Modify: `shared/docreview/references/reviewing-document.md:27-30`
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md:363-366, :422, :427-436, :431-432, :490-492`
- Modify: `plugins/spec-distill/skills/reviewing-brief/SKILL.md:458-461, :580-583, :585`
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

framing-requests 577-579(옛): `냅니다. 그 묶음은 **`AskUserQuestion` 최대 4개씩 연속 호출**로 나눠 띄우고, 매 호출 첫 질문의 첫 줄은 렌더` / `첫 줄(degrade 공시)과 같습니다. ` → 새: `냅니다. 그 묶음은 **`AskUserQuestion` 최대 4개씩 연속 호출**로 나눠 띄웁니다.` 다음 줄에 위 새 문장(두 줄)을 그대로 둔다(「~다」체 그대로 — 이 문장은 네 파일에서 글자가 같아야 락이 같은 리터럴로 잰다). 옛 593행은 `첫 줄(degrade 공시)과 같습니다. ` 뒤에 `` `approval_gate_open` 이면 승인 게이트입니다 — 1단계(열린 항목 · 「추가 `` 가 이어진다 — 그 줄의 나머지(`` `approval_gate_open` 이면 승인 게이트입니다 — … ``)는 새 둘째 줄 다음 줄로 이어 둔다.

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

위 표 아래에 행을 더한다 — 경고를 질문 텍스트에 싣으라는 옛 지시가 새 규칙(경고는 앞 글에, 경고가 없을 때의 문구는 「이상 없음」·「경고 없음」)과 어긋나는 자리다. 이 문구를 고정한 단언은 없다.

| 파일 · 줄 | 옛 | 새 |
|---|---|---|
| reviewing-spec 422 · 431 · 432 | `2단계 질문 텍스트에 싣는다` | `2단계 게이트 앞 글에 싣는다` (432 의 `목록 본문 없음을 2단계 질문 텍스트에 싣는다` 도 같은 글자라 같이 바뀐다) |
| finishing.md 241 · 252 · 253 | `게이트 텍스트에` | `게이트 앞 글에` |
| framing-requests 867 (「…없는 세션에 「degrade 없음」이라고 쓰지 않습니다」) | `「degrade 없음」이라고` | `「이상 없음」·「경고 없음」이라고` |
| reviewing-brief 585 | `(그 라운드의 degrade 한 줄 — 「미검증」` | `(그 라운드의 상태와 경고(렌더 첫 줄) — 「미검증」` |
| framing-requests 844 | `(그 라운드의 degrade 한 줄 — 「미검증」` | `(그 라운드의 상태와 경고(렌더 첫 줄) — 「미검증」` |

마지막 두 행은 Step 1 이 「(degrade 공시)」를 지운 것과 같은 정리다 — 렌더 첫 줄을 「상태와 경고」로 부른다. 줄 번호는 abc70f66 실측이고, 착수 때 `grep -n 'degrade 한 줄'` 로 다시 찾는다. 이 두 문구를 고정한 단언은 없다. README 의 같은 꼴 한 자리(`게이트 질문에 표시된다`)는 Task 6 이 고친다.

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
grep -c 'degrade 한 줄' plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/skills/framing-requests/SKILL.md
bash shared/tests/test_dispatch_disposition.sh | tail -1
```
Expected: `0`, 각 `:0`, `Fail: 0`(축 C — 앵커 리터럴 「proceed 게이트 앞 글」이 같은 파일 본문 832 행에 있다).

- [ ] **Step 5: 테스트를 돈다**

Run:
```bash
for t in test_plain_gate_templates test_framing_review_contract test_reviewing_brief_skill test_reviewing_spec_disclosure test_proceed_gate_adopters test_review_handoff_order test_reviewing_spec_entry_fence test_seed_review_log; do printf '%s ' "$t"; bash plugins/spec-distill/tests/$t.sh 2>&1 | tail -1; done
for t in test_docreview_round_gate_split test_dispatch_disposition test_docreview_procedure_paths; do printf '%s ' "$t"; bash shared/tests/$t.sh 2>&1 | tail -1; done
bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh | tail -1
```
Expected: 전부 `Fail: 0`.

- [ ] **Step 6: 커밋**

```bash
git add shared/docreview/references/reviewing-document.md plugins/spec-distill/skills/conducting-interview/references/finishing.md plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/skills/framing-requests/SKILL.md plugins/spec-distill/references/proceed-gate.md plugins/spec-distill/tests/test_framing_review_contract.sh plugins/spec-distill/tests/test_reviewing_brief_skill.sh
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
for lit in 'codex co-review SKIPPED' '기준 사본이 없다' 'brief 리뷰 SKIPPED' '확정 확인 재제시 상한(2회) 초과' 'superpowers 설치 시 brainstorming' 'Step B 게이트에서 ' 'dispatch 없이 통과 (advisory, 사람이 확인)' 'SKIPPED'; do
  printf '== %s\n' "$lit"
  /usr/bin/grep -rnF -- "$lit" plugins shared tools 2>/dev/null | grep -v '/golden/' | cut -c1-180
done > ~/.claude/sdd-mirror/plain-language-output/pr2/fixed-string-hits.txt
cat ~/.claude/sdd-mirror/plain-language-output/pr2/fixed-string-hits.txt | grep -c .
```

맨 낱말 `SKIPPED` 는 문구 전체가 아니라 낱말로 잡는 단언을 찾기 위해 더했다(`test_reviewing_brief_skill.sh:112` 가 그렇다). 조사(2026-10-08) 때 `codex co-review SKIPPED` 의 테스트 자리는 14곳(`test_reviewing_brief_residue.sh` 7 · `test_reviewing_spec_residue.sh` 5 · `test_seed_gate_wiring.sh` 2)이었다. 다른 플러그인(quality-gates · plugin-audit)의 같은 꼴 문구는 그 PR 이 다룬다 — 여기서는 `plugins/spec-distill` 과 그 문구를 읽는 `shared/tests` 만 고친다.

- [ ] **Step 2: 문구를 바꾼다**

| 자리 | 옛 | 새 |
|---|---|---|
| reviewing-spec 277 (codex-gate 펜스) | `[spec-distill] codex co-review SKIPPED (reason: ${skip_reason:-unknown}) — Claude-only, 이 리뷰에는 모델 다양성이 없었다 (degraded).` | `[spec-distill] codex 리뷰를 건너뛰었다 (reason: ${skip_reason:-unknown}) — 이번 리뷰는 Claude 만 봤다. 다른 모델의 시각이 없다 (degraded).` |
| reviewing-brief 287 | `[spec-distill] codex co-review SKIPPED (reason: ${skip_reason:-unknown}) — Claude-only, 이 리뷰에는 codex 쪽의 모델 다양성과 웹 근거가 없었다 (degraded).` | `[spec-distill] codex 리뷰를 건너뛰었다 (reason: ${skip_reason:-unknown}) — 이번 리뷰는 Claude 만 봤다. 다른 모델의 시각과 codex 쪽 웹 근거가 없다 (degraded).` |
| framing-requests 533 | `[spec-distill] codex co-review SKIPPED (reason: ${skip_reason:-unknown}) — seed 리뷰에 codex 쪽 모델 다양성이 없었다 (degraded).` | `[spec-distill] codex 리뷰를 건너뛰었다 (reason: ${skip_reason:-unknown}) — 이번 seed 리뷰는 Claude 만 봤다. 다른 모델의 시각이 없다 (degraded).` |
| framing-requests 717 · 1011 | `[spec-distill] 기준 사본이 없다(${SEED_BASE:-}) — 저자 편집을 비교할 수 없다.` | `[spec-distill] 기준 사본이 없다(${SEED_BASE:-}) — 저자가 seed 를 고쳤는지 대조할 수 없다.` (뒤의 모델 지시 꼬리는 그대로) |
| reviewing-brief 70 | `[spec-distill] brief 리뷰 SKIPPED (DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW=1) — 엔진 라운드·냉독 전부 미검증. Step B 게이트에서 확인하세요.` | `[spec-distill] brief 리뷰를 건너뛰었다 (DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW=1) — 리뷰 라운드도 냉독도 돌지 않았다. 다음 단계 게이트에서 확인하라.` |
| finishing.md 216 | `[spec-distill] 확정 확인 재제시 상한(2회) 초과 — 전 항목 provisional 강등` | `[spec-distill] 확정 목록을 두 번 다시 보여 줬는데도 정하지 못했다 — 모든 항목을 잠정(provisional)으로 둔다` |
| finishing.md 282 | `[spec-distill] interview brief 완결: docs/superpowers/interview/<file>. superpowers 설치 시 brainstorming 해답공간 단계로 이어집니다. 미설치 시 이 brief를 직접 다음 작업의 입력으로 사용하세요.` | `[spec-distill] interview brief 를 만들었다: docs/superpowers/interview/<file>. superpowers 가 있으면 brainstorming 으로 이어지고, 없으면 이 brief 를 다음 작업의 입력으로 쓴다.` |
| `check_brief.py` 945행 `INTERNAL_RESEARCH_ZERO_ADVISORY` | `"…— 그 판단은 Step B 게이트에서 "`(946행 `"사람이 한다."` 로 이어진다) | `"…— 그 판단은 다음 단계 게이트에서 "` |
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
| `test_conducting_interview_stage.sh:139` | `'[spec-distill] 확정 확인 재제시 상한(2회) 초과 — 전 항목 provisional 강등'` | `'[spec-distill] 확정 목록을 두 번 다시 보여 줬는데도 정하지 못했다 — 모든 항목을 잠정(provisional)으로 둔다'` | 재제시 상한 도달 시 고정 문구로 강등을 알린다 |
| `test_reviewing_brief_skill.sh:112` | `has "$W_KS" 'SKIPPED'` | `has "$W_KS" '건너뛰었다'` | BRIEF_REVIEW 를 건너뛴 사실이 고정 문구로 공시된다 |

`superpowers 설치 시` · `Step B 게이트에서 사람이 한다` · `dispatch 없이 통과` 세 문구를 고정한 테스트 단언은 없다(원본 파일에서만 나온다 — golden 에도 없다). 손으로 고칠 단언은 `test_conducting_interview_stage.sh:139` 와 `test_reviewing_brief_skill.sh:112` 둘이다. (같은 줄의 `has "$W_KS" 'Step B'` 는 「Step B 로 돌아간다」에 남아 통과한다.)

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

## Task 5: PR 1 이 미룬 렌더 다듬기 여섯 (쉬운 말 출력 설계 §3 · §5 · Q9~Q11)

PR 1 이 미룬 항목 (b)~(g) 를 닫는다(근거: `/Users/jeonghokim/.claude/sdd-mirror/plain-language-output/research/dryrun-pr2-report.md` 「PR 1 이연 항목 대조」). (a) 는 Task 3 Step 4 가 닫는다. 이 Task 가 고치는 파일은 Task 1~4 가 건드리지 않는다(2026-10-09 4d325819 대조).

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py`(`WARN_GLOSS` · `_plain_warns` 새로, `_first_line` · `_rg_escalated_fix` · `render_gate` 의 묶음 루프)
- Modify: `shared/docreview/agents/doc-critic.md` · `shared/docreview/agents/doc-critic-web.md` · `plugins/spec-distill/agents/doc-critic.md` · `plugins/spec-distill/agents/doc-critic-web.md`(문장 하나)
- Modify: `shared/tests/fixtures/docreview/cases.sh`(새 케이스 다섯 · T40 단언 하나 · 낡은 주석 넷 · `case_gate_grouping_marker` 의 전제 계산)
- Modify: `shared/tests/test_docreview_route.sh`(케이스 등록) · `shared/tests/test_docreview_mutations.sh`(셀 일곱 · ㊷ 주석) · `shared/tests/test_docreview_agent_fields.sh`(단언 하나)
- Modify: `shared/tests/fixtures/docreview/golden/case_T11_permit_keeps_disposition.gate.txt` · `case_T22_reraise_appears_in_next_round.gate.txt`(재캡처)
- Modify: `tools/plain-language/test_measure_output.py`(「미검증」 첫 줄 표본 한 줄)

**Interfaces:**
- Consumes: advisory 원문 — `docreview_route.py` `_build_report` 의 다섯 줄(`codex 없음 — …` · `기각 경로 0 — …` · `상세 미검증 — …` · `앵커 불가 — …` · `critic 시점 판별 불가 (…)`)과 `shared/adjudication/adjudication.py` `reasons()` 의 네 꼴(`보류:` · `셀 수 없음:` · `입력 실패(주|보조):` · `강제(게이트 변경):`).
- Produces: `docreview_state._plain_warns(warns) -> list` — 원문 목록을 첫 줄에 싣는 쉬운 줄 목록으로. 기계가 읽는 값(`fin.json` · `gate` JSON 의 `advisory` · 원장 `route_report` · `pending_recritic.events`)은 바뀌지 않는다(Q9). golden 의 `*.gate.json` · `*.fin.json` · `*.state.md` 는 diff 0 이다.

**소비자 조사(2026-10-09, 이 Task 의 근거):** advisory 원문은 기계가 읽는다 — `cases.sh` 의 `startswith("입력 실패(주): doc-critic")`(:1382) · `"기각 경로 0" in a`(:1396) · `"critic 시점 판별 불가 (…)" in d["advisory"]`(:1724 · :1732) · T40 의 `d["advisory"][0].startswith("codex 없음")`, qg 가 같이 쓰는 `adjudication.reasons()`(`plugins/quality-gates/tests/test_synthesize_findings_adjudication.py:209` 의 `"입력 실패(주)"`), 이벤트 원장(`cases.sh:933` · `:1562` 의 `'layer1 block …'`), golden `*.fin.json` · `*.state.md`. 그래서 원문은 그대로 두고 렌더만 바꾼다. `plugins/*` 의 SKILL · references 에는 이 원문을 글자로 적은 자리가 없다(`docs/` 의 옛 설계·계획만 있다).

- [ ] **Step 1: 실패하는 케이스를 쓴다**

새 케이스 다섯 — (b) 경고 쉬운 말 둘(첫 줄 · 표의 두 성질), (c) 묶음 안 표지, (e) 막힌 이유 접기, (g) 「미검증」의 「남은 것 없음」. 단언마다 양의 짝이 같은 케이스 안에 있다. `gfirst` · `gsum` · `critic_dead_twice` · `item_prev_line` 은 `cases.sh` 의 기존 헬퍼다.

`shared/tests/fixtures/docreview/cases.sh` 의 아래 줄 바로 앞에 넣는다(`case_I4_anchor_newline_collapsed` 다음, `case_state_gloss_covers_gate_rows` 위). 기준 줄:

```bash
# STATE_GLOSS 의 ∀ 커버리지 — 행 이름은 `gate-rows` 에서 도출한다(CATEGORY_GLOSS 락과 같은 모양).
```

넣을 글:

```bash
# 렌더 첫 줄 경고의 쉬운 말(계획 Q9) — advisory 원문은 기계가 읽는 값이라 그대로 두고 렌더만 바꾼다. 같은 사실을
# 두 출처가 말한 원문(「codex 없음」 + 「입력 실패(보조): codex」 등)은 한 줄로 합치고, 사유 토큰은 그 줄 괄호에 모은다.
case_plain_warns_first_line() {
  local d f raw; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-nolayer2.txt" "$FX/codex-failed.yaml" --skip)" \
    || { no "경고 쉬운 말: route_r1 실패"; return; }
  f="$(gfirst "$d")"
  assert_eq "$(jget "$d/fin.json" 'len(d["advisory"])')" "6" "경고 쉬운 말 전제: 이 라운드의 advisory 원문은 여섯이다"
  assert_contains "$f" "경고 3개: " "경고 쉬운 말: 원문 여섯이 가리키는 사실 셋이 한 줄씩 실린다"
  assert_contains "$f" "codex 리뷰가 없어 다른 모델의 시각이 빠졌다 (codex: exit_nonzero)" \
    "경고 쉬운 말: codex 부재가 쉬운 문장 한 줄이고 사유 토큰은 괄호에 있다"
  assert_contains "$f" "재비판이 돌지 않아 잘못된 지적을 걸러 내지 못했다 (doc-recritic: kill switch, skipped)" \
    "경고 쉬운 말: 재비판 부재가 한 줄이고 두 출처의 사유를 모두 싣는다"
  assert_contains "$f" "세부 검토 결과(층 2)가 없어 세부 지적을 셀 수 없다 (layer2: block missing)" \
    "경고 쉬운 말: 층 2 부재가 한 줄이고 셀 수 없다고 말한다"
  assert_eq "$(printf '%s' "$f" | grep -o 'codex 리뷰가 없어' | grep -c .)" "1" "경고 쉬운 말: codex 부재가 첫 줄에 한 번만 나온다"
  for raw in '모델 다양성 0' '입력 실패(' '셀 수 없음:' '기각 경로 0' '상세 미검증'; do
    assert_not_contains "$f" "$raw" "경고 쉬운 말: 첫 줄에 엔진 원문 「${raw}」이 없다"
  done
  assert_eq "$(jget "$d/fin.json" 'd["advisory"][0], d["advisory"][1]')" \
    "('codex 없음 — 모델 다양성 0 (exit_nonzero)', '셀 수 없음: layer2 — block missing')" \
    "경고 쉬운 말 양의 짝: 기계가 읽는 advisory 원문은 그대로다"
  rm -rf "$d"
}
# 쉬운 말 경고 표의 두 성질 — 표에 없는 원문은 버리지 않고 그대로 싣는다(계획 P6) · 원문 속 개행은 한 줄로 접는다.
case_plain_warns_unknown_kept() {
  local got; got="$(PYTHONPATH="$SCRIPTS" python3 -c '
from docreview_state import _plain_warns
print(_plain_warns(["표에 없는 경고 하나", "보류: recritic:f9 — 항목 파손:\nunknown f"]))')"
  assert_eq "$got" "['표에 없는 경고 하나', '판정하지 못하고 보류한 지적이 있다 (recritic:f9 — 항목 파손: unknown f)']" \
    "경고 쉬운 말: 표에 없는 원문은 그대로 싣고, 표에 있는 원문은 쉬운 문장 뒤 괄호에 나머지를 한 줄로 싣는다"
}
# 「같은 자리」 표지는 한 묶음 안에서만 앞 항목을 가리킨다(계획 Q11) — 묶음 제목 너머의 항목을 가리키지 않는다.
case_gate_marker_stays_in_group() {
  local d gr; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local F_DEC2='{"id":"aaaa0002#r1.1","lineage":"aaaa0002#r1.1","bucket":"aaaa0002","origin":"reviewer","layer":2,"category":"ambiguity","anchor":"#12-files-to-modify","edit_scope":"#12-files-to-modify","disposition":"decide","summary":"파일 순서가 정해지지 않았다","evidence":"12행","blocks":[],"kind":"pre"}'
  seed_findings "$d" "[$F_DEC,$F_DEC2,$F_FIX]" || { no "묶음 안 표지: seed 실패"; rm -rf "$d"; return; }
  gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_grep "$(item_prev_line "$gr" 'aaaa0002#r1.1')" '^  ┆ 같은 자리\(#12-files-to-modify\)$' \
    "묶음 안 표지 양의 짝: 같은 묶음에서 같은 자리가 이어지면 표지가 선다"
  assert_eq "$(item_prev_line "$gr" 'bbbb0001#r1.1')" "아직 안 고친 곳 1개" \
    "묶음 안 표지: 다른 묶음의 첫 항목 바로 앞은 묶음 제목이다(같은 자리 표지가 제목 너머를 가리키지 않는다)"
  assert_eq "$(printf '%s\n' "$gr" | grep -c '^  ┆ 같은 자리')" "1" "묶음 안 표지: 표지는 묶음 안의 한 번뿐이다"
  rm -rf "$d"
}
# 같은 구멍의 막힌 이유 칸 — escalate 사유(사용자·엔진이 쓴 값)에 개행이 있으면 다음 줄 열 0 에 가짜 항목
# 머리가 선다. 렌더가 접는다(원장 값은 그대로).
case_I4_escalate_reason_newline_collapsed() {
  local d gr; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  py docreview_state.py fix --state-dir "$d" --id 'bbbb0001#r1.1' --event escalate --reason $'anchor_protected\n- 가짜 항목 (zz#r1.7)' >/dev/null
  gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_not_grep "$gr" '^- 가짜' "I4 막힌 이유: 사유 속 항목 머리 모양이 렌더의 열 0 에 서지 않는다"
  assert_grep "$gr" '^- c\.py 가 빠졌다 — 막힌 이유: anchor_protected - 가짜 항목 \(zz#r1\.7\)\. 버리면\(drop\) 이 차단이 풀린다 \(bbbb0001#r1\.1\)$' \
    "I4 막힌 이유 양의 짝: 그 사유는 항목 머리 안에 한 줄로 산다"
  assert_eq "$(st_yaml "$d" '"\n" in st["fixes"]["bbbb0001#r1.1"]["escalate_reason"]')" "True" \
    "I4 막힌 이유: 원장 값은 그대로다(접기는 렌더에서만)"
  rm -rf "$d"
}
# 「미검증」 라운드의 첫 줄은 「남은 것 없음」을 쓰지 않는다(계획 Q10) — 셀 것이 없는 것과 세지 못한 것은 다르다.
# 「미검증」이 아닌 라운드의 「남은 것 없음」은 case_T40_codex_absent_nothing_left_first_line 이 잰다(양의 짝).
case_T46_unverified_no_nothing_left() {
  local d f; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  critic_dead_twice "$d"
  assert_eq "$(gsum "$d" 'd["unverified"]')" "critic_dead" "T46 전제: 이 라운드는 「미검증」(critic 사망)"
  f="$(gfirst "$d")"
  assert_not_contains "$f" "남은 것 없음" "T46: 「미검증」 첫 줄이 「남은 것 없음」을 쓰지 않는다"
  assert_eq "$f" "「미검증」 리뷰어(doc-critic)가 결과를 내지 못해 이 라운드는 리뷰되지 않았다. 리뷰 1라운드." \
    "T46 양의 짝: 첫 줄은 「미검증」 공시와 라운드 번호다"
  rm -rf "$d"
}
```

셋째 케이스의 `item_prev_line` 은 항목 머리 바로 앞 줄을 낸다 — 다른 묶음의 첫 항목이면 그 줄은 묶음 제목이다. 첫째 케이스의 `「${raw}」` 는 중괄호를 쓴다 — macOS bash 3.2 는 `$raw` 바로 뒤의 비ASCII 글자 바이트를 변수 이름으로 먹어 `set -u` 에서 죽는다(드라이런 실측).

`case_T40_codex_absent_first_line` 의 첫 줄 단언을 새 문구로(지키는 뜻 그대로 — 첫 줄이 codex 부재와 사유 토큰을 공시한다). 옛:

```bash
  assert_contains "$f" "codex 없음 — 모델 다양성 0 (exit_nonzero)" "T40·AC8: 첫 줄이 codex 부재와 사유를 공시한다"
```

새:

```bash
  assert_contains "$f" "codex 리뷰가 없어 다른 모델의 시각이 빠졌다 (codex: exit_nonzero)" "T40·AC8: 첫 줄이 codex 부재와 사유를 공시한다"
```

`shared/tests/test_docreview_route.sh` 에 등록한다 — 아래 줄 바로 뒤에 넣는다. 기준 줄:

```bash
case_I4_anchor_newline_collapsed
```

넣을 글:

```bash
case_plain_warns_first_line
case_plain_warns_unknown_kept
case_gate_marker_stays_in_group
case_I4_escalate_reason_newline_collapsed
case_T46_unverified_no_nothing_left
```

(f) 의 락 — `shared/tests/test_docreview_agent_fields.sh` 의 `PLAIN_LINE` 루프 안, 아래 줄 바로 뒤에 넣는다. 같은 루프의 `PLAIN_LINE` 단언이 양의 짝이다(「처음 보는 사람이 읽는다 — 내부 번호 없이 쉬운 말로 쓴다」는 일곱 파일에 남는다). 기준 줄:

```bash
  assert_file_grep "$f" 'evidence`? ?는 문서 인용이라 원문 그대로' "쉬운 말 칸: $f 가 근거는 원문 그대로라고 적는다"
```

넣을 글:

```bash
  assert_file_absent "$f" '그대로 읽는다 — 처음 보는 사람이 읽는다' "쉬운 말 칸: $f 가 「읽는다」를 두 번 잇지 않는다"
```

- [ ] **Step 2: 실패하는지 확인한다**

Run:
```bash
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_route.sh | tail -1
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_agent_fields.sh | tail -1
```
Expected: `Total: 307 | Pass: 289 | Fail: 18` · `Total: 53 | Pass: 49 | Fail: 4`. RED 는 새 케이스 다섯의 단언(T40 하나 포함 18)과 doc-critic 넷의 반복 문장이다. stderr 에 `ImportError: cannot import name '_plain_warns'` traceback 이 한 번 나온다 — 그 함수는 Step 3 이 만든다. 숫자는 4d325819 기준이다 — Task 0 의 merge 가 엔진 케이스를 더 가져왔으면 Total 은 달라도 `Fail` 은 같아야 한다(Task 1~4 는 이 두 파일을 건드리지 않는다).

- [ ] **Step 3: 엔진과 리뷰어 문장을 고친다**

(b) 경고 표 — `NEXT_MODE_GLOSS` 줄 바로 뒤에 넣는다(Q9). 기준 줄:

```python
NEXT_MODE_GLOSS = {"budget": "재리뷰 횟수 안에서", "extra_approval": "사용자가 연 추가 라운드"}
```

넣을 글:

```python
# 렌더 첫 줄 경고의 사람말(쉬운 말 출력 설계 §3 · 계획 Q9). advisory 원문은 기계가 읽는 값이라(`fin.json` · 원장의
# `route_report` · 테스트) 그대로 두고 렌더에서만 바꾼다. 행: (원문 정규식, 괄호 이름, 쉬운 문장) — 위에서부터 첫 일치.
# 괄호 이름과 문장이 같은 행은 같은 사실을 두 출처가 말한 것이라 한 줄로 합치고, 사유(`why`)는 그 줄 괄호에 모은다.
# 괄호 이름이 None 인 행은 원문의 나머지(`why`)를 괄호에 그대로 싣는다. 어느 행에도 안 맞는 원문은 그대로 낸다 —
# 버리지 않는다(계획 P6).
WARN_GLOSS = (
    (r"codex 없음 — 모델 다양성 0 \((?P<why>.*)\)", "codex", "codex 리뷰가 없어 다른 모델의 시각이 빠졌다"),
    (r"입력 실패\(보조\): codex — (?P<why>.*)", "codex", "codex 리뷰가 없어 다른 모델의 시각이 빠졌다"),
    (r"기각 경로 0 — 오탐이 걸러지지 않았다 \(doc-recritic (?P<why>.*)\)", "doc-recritic",
     "재비판이 돌지 않아 잘못된 지적을 걸러 내지 못했다"),
    (r"입력 실패\(보조\): doc-recritic — (?P<why>.*)", "doc-recritic", "재비판이 돌지 않아 잘못된 지적을 걸러 내지 못했다"),
    (r"셀 수 없음: layer2 — (?P<why>.*)", "layer2", "세부 검토 결과(층 2)가 없어 세부 지적을 셀 수 없다"),
    (r"상세 미검증 — 층 2 블록 없음", "layer2", "세부 검토 결과(층 2)가 없어 세부 지적을 셀 수 없다"),
    (r"앵커 불가 — .*", "앵커 불가", "문서에 제목이 없어 지적의 자리를 가리지 못한다 — 모든 수정이 문서 전체 범위다"),
    (r"critic 시점 판별 불가 \((?P<why>.*)\)", "critic 시점", "리뷰어 결과가 이번 라운드 것인지 확인하지 못했다"),
    (r"입력 실패\(주\): (?P<why>.*)", None, "꼭 있어야 할 리뷰어 결과를 읽지 못했다"),
    (r"입력 실패\(보조\): (?P<why>.*)", None, "보조 리뷰어 결과를 읽지 못했다"),
    (r"셀 수 없음: (?P<why>.*)", None, "셀 수 없는 것이 있다"),
    (r"보류: (?P<why>.*)", None, "판정하지 못하고 보류한 지적이 있다"),
    (r"강제\(게이트 변경\): (?P<why>.*)", None, "판정 값을 강제로 바꿨고 그 때문에 게이트 결과가 달라졌다"),
)
```

`_one` 함수 바로 뒤에 빈 줄 둘을 두고 넣는다. 기준(`_one` 함수 전체):

```python
def _one(s) -> str:
    """렌더용 한 줄 — 열 0 의 「- 」 항목 머리는 렌더러만 만든다(요약 속 개행이 가짜 머리를 세우지 않게)."""
    return " ".join(str(s).split())
```

넣을 글:

```python
def _plain_warns(warns) -> list:
    """advisory 원문 목록 → 첫 줄에 싣는 쉬운 경고 줄 목록(WARN_GLOSS). 순서는 원문이 처음 나온 순서다."""
    lines, why_of = [], {}
    for w in map(str, warns):
        m = row = None
        for row in WARN_GLOSS:
            m = re.fullmatch(row[0], w, re.S)
            if m:
                break
        if not m:
            k = w
        elif row[1] is None:
            k = "%s (%s)" % (row[2], m.group("why"))
        else:
            k = (row[1], row[2])
        if k not in why_of:
            why_of[k] = []
            lines.append(k)
        why = m.groupdict().get("why") if m and row[1] else None
        if why and why not in why_of[k]:
            why_of[k].append(why)
    out = []
    for k in lines:
        if isinstance(k, tuple):
            k = "%s (%s)" % (k[1], k[0] + (": " + ", ".join(why_of[k]) if why_of[k] else ""))
        out.append(_one(k))
    return out
```

변이 셀(Step 6)이 겨누는 줄 넷 — `            k = w` · `            k = (row[1], row[2])` · `        if why and why not in why_of[k]:` · `    warns = _plain_warns(warns)` — 은 각각 한 물리적 줄로 둔다.

`_first_line` docstring 끝 — 옛:

```python
    경고는 advisory 를 전부 싣는다 — codex 부재만 싣고 나머지를 버리지 않는다."""
```

새:

```python
    경고는 advisory 를 전부 싣는다 — codex 부재만 싣고 나머지를 버리지 않는다. 원문은 `_plain_warns` 가 쉬운 줄로
    바꾸고, 같은 사실을 두 출처가 말한 원문은 한 줄로 합친다(계획 Q9). 「미검증」·라운드 미완이면 「남은 것 없음」도
    쓰지 않는다 — 세지 못한 라운드다(계획 Q10)."""
```

(b) 호출 — 옛(codex 줄을 끼운 바로 뒤):

```python
            warns.insert(0, cl)
```

새:

```python
            warns.insert(0, cl)
    warns = _plain_warns(warns)
```

`cl not in warns` 는 그대로 둔다 — 원문이 이미 있으면 끼우지 않고, 사유가 달라도 `_plain_warns` 가 같은 사실 키로 한 줄에 합친다. `    if warns:` 줄은 그대로다(기존 셀 `warns_hidden_as_clean` · `warns_need_left` 의 앵커).

(g) 「미검증」·라운드 미완이면 「남은 것 없음」을 쓰지 않는다(Q10) — 옛:

```python
    s = head + (" — %s가 남았다." % " · ".join(left) if left else " — 남은 것 없음.")
```

새:

```python
    s = head + (" — %s가 남았다." % " · ".join(left) if left else ("." if lead else " — 남은 것 없음."))
```

(e) 막힌 이유를 한 줄로 접는다 — `_rg_escalated_fix` 의 return, 옛:

```python
    return ["- %s — 막힌 이유: %s. 버리면(drop) 이 차단이 풀린다 (%s)" % (_one(st["findings"][fid].get("summary")), why, fid)]
```

새:

```python
    return ["- %s — 막힌 이유: %s. 버리면(drop) 이 차단이 풀린다 (%s)" % (_one(st["findings"][fid].get("summary")), _one(why), fid)]
```

㊷ 셀의 sed(`s/\. 버리면(drop) 이 차단이 풀린다 (%s)" % (/ (%s)" % (/`)는 새 줄에도 그대로 맞는다.

(c) 묶음마다 새로 센다 + D24 주석 복원(Q11) — `render_gate` 의 묶음 루프, 옛:

```python
            out.append("  ↳ 상태 이름에 사람말이 없다: %s — 원래 이름 그대로 낸다" % row.name)
        for fid in g[row.name]:
```

새:

```python
            out.append("  ↳ 상태 이름에 사람말이 없다: %s — 원래 이름 그대로 낸다" % row.name)
        # 묶음은 «표시»다 — 질문 수도 항목별 선택권도 안 바꾼다(D24). 같은 자리를 건드리는 항목이 한 묶음 안에서
        # 연달아 오면 그 사실만 한 줄로 보인다. 묶음마다 새로 센다 — 표지가 묶음 제목 너머를 가리키지 않는다(계획 Q11).
        prev_anchor = None
        for fid in g[row.name]:
```

루프 앞의 `    prev_anchor = None`(들여쓰기 넷)은 그대로 둔다 — 변이 셀 `marker_crosses_group` 이 안쪽 줄(들여쓰기 여덟)만 지운다. 바깥 줄까지 지우면 첫 항목에서 `UnboundLocalError` 가 나 셀이 「측정 불가」가 된다. 복원한 주석의 옛 글은 `65102910^:shared/docreview/scripts/docreview_state.py` 의 `[Task 9 ⓓ] 묶음은 «표시»다 — 질문 수도 항목별 선택권도 안 바꾼다 (D24). 같은 자리를 건드리는 항목이 연달아 오면 그 사실만 한 줄로 보인다.` 이다(`git log -S 'D24' -- shared/docreview/scripts/docreview_state.py` 가 찾는다. 「묶음은 표시일 뿐」은 같은 뜻의 `cases.sh` 주석 글자다 — 엔진 쪽 옛 글자는 「묶음은 «표시»다」였다).

(f) 리뷰어 문장 — 네 파일(`shared/docreview/agents/doc-critic.md` · `doc-critic-web.md` 정본과 `plugins/spec-distill/agents/` 의 같은 이름 사본 둘)에서 같은 문장을 같은 글자로 바꾼다. 재비판자(`doc-recritic.md` 셋)에는 이 반복이 없다 — 그대로 둔다. 옛:

```markdown
`summary`·`if_unfixed`·`replacement` 는 사용자가 게이트에서 그대로 읽는다 — 처음 보는 사람이 읽는다 — 내부 번호 없이 쉬운 말로 쓴다.
```

새:

```markdown
`summary`·`if_unfixed`·`replacement` 는 게이트에 그대로 실려 처음 보는 사람이 읽는다 — 내부 번호 없이 쉬운 말로 쓴다.
```

지우는 것은 반복 「사용자가 게이트에서 그대로 읽는다 — 」 뿐이다. 「게이트에 그대로 실린다」(사용자가 원문 그대로 본다)와 「처음 보는 사람이 읽는다 — 내부 번호 없이 쉬운 말로 쓴다」(락 `PLAIN_LINE`)는 남는다. 규칙·임계치는 바뀌지 않는다(CLAUDE.md — persona 편집은 보안 민감). 사본은 정본과 표지 줄만 다르다는 락(`test_docreview_agents.sh` · `test_copy_of_contract.sh`)이 있으므로 네 파일을 한 번에 바꾼다.

- [ ] **Step 4: 낡은 주석과 묶음 표지 락의 전제**

(d) 옛 항목 머리(`[decide] <id>` · `] <fid>` · 「순서:」 머리 줄)를 설명하는 주석을 지금 모양으로 고친다. (c) 와 맞춰 `case_gate_grouping_marker` 의 전제 계산도 묶음 안의 인접 쌍만 센다 — 지금은 GATE_ROWS 전체를 한 줄로 펴서 묶음 제목 너머의 쌍도 인접으로 센다(오늘 픽스처의 첫 쌍은 한 묶음 안이라 우연히 맞는다).

`shared/tests/fixtures/docreview/cases.sh` — 옛:

```bash
# ── 게이트 머리의 순서 뜻 한 줄 + 같은 anchor 묶음 (AC18 · AC18') ────────────
```

새:

```bash
# ── 묶음 제목의 순서 + 같은 anchor 묶음 (AC18 · AC18') ──────────────────────
```

`shared/tests/fixtures/docreview/cases.sh` — 옛:

```bash
  # [리뷰 fix round 2] 원래는 첫 세 어절만(`열린 결정 먼저`) 단언했다 — 다섯
  # 구절 중 하나만 살아 있으면 통과하고, 순서가 뒤섞여도 통과한다. AC18 이
  # 재는 것은 「GATE_ROWS 순서의 뜻」이므로 다섯 구절 «전부» + 그 «순서» 를
  # 한 번에 잰다: 머리 줄 전체를 뽑아 기대 리터럴과 정확히 같은지 본다(한
  # 등식이 내용과 순서를 동시에 고정한다 — 독립된 다섯 substring 단언은
  # 뒤섞인 줄에서도 전부 통과하므로 쓰지 않는다).
```

새:

```bash
  # 옛 렌더는 「순서:」 머리 줄 하나로 순서의 뜻을 말했다. 쉬운 말 출력 PR 1 이 그 줄을 묶음 제목으로
  # 흡수했으므로, 이제는 묶음 제목(「<STATE_GLOSS> N개」)이 렌더에 선 자리를 뽑아 GATE_ROWS 순서인지 잰다.
  # 묶음이 둘 이상이어야 순서 비교가 공허하지 않다.
```

`shared/tests/fixtures/docreview/cases.sh` — 옛:

```bash
  # [리뷰] 접두사만 보면 `_rg_held_decide` 의 「[decide 보류]」도 "^\[decide" 에 걸린다 —
  # held_decide 는 n_items(세 버킷)에 안 들어가므로 그 오탐이 등식을 조용히 깬다.
  # 닫는 대괄호까지 앵커해 정확히 세 렌더러의 리터럴 형태만 잡는다.
```

새:

```bash
  # 항목 머리는 열 0 의 「- 」로 시작하고 id 괄호(「(<id>)」 · 「(<id> · 자동)」)로 끝난다 — 그 모양만 센다.
  # 묶음 제목과 「  그대로 두면:」 같은 이어지는 줄은 열 0 의 「- 」가 아니라 안 걸린다. n_items 는 GATE_ROWS
  # 전 행의 합이므로 두 값이 같으면 렌더가 항목을 빼거나 더하지 않았다는 뜻이다.
```

`shared/tests/fixtures/docreview/cases.sh` — 옛:

```bash
#  ① 전제 — 이 상태에 같은 anchor 를 가진 «열린»(row.open) 항목이 N≥2 있다.
```

새:

```bash
#  ① 전제 — 이 상태의 한 묶음(GATE_ROWS 한 행) 안에 같은 anchor 를 가진 항목이 N≥2 이어진다.
#     표지는 묶음마다 새로 센다(계획 Q11) — 묶음 제목을 사이에 둔 두 항목은 인접 쌍이 아니다.
```

`shared/tests/fixtures/docreview/cases.sh` — 옛:

```bash
order = []
for r in rows:
    order.extend(g[r["name"]])
anchors = [(fid, (st["findings"].get(fid) or {}).get("anchor")) for fid in order]
same_pairs = [(anchors[i - 1][0], anchors[i][0], anchors[i][1])
              for i in range(1, len(anchors))
              if anchors[i][1] and anchors[i][1] == anchors[i - 1][1]]
diff_pairs = [(anchors[i - 1][0], anchors[i][0])
              for i in range(1, len(anchors))
              if anchors[i][1] and anchors[i - 1][1] and anchors[i][1] != anchors[i - 1][1]]
group_size = 0
if same_pairs:
    target_anchor = same_pairs[0][2]
    group_size = sum(1 for _, a in anchors if a == target_anchor)
```

새:

```bash
groups = [[(fid, (st["findings"].get(fid) or {}).get("anchor")) for fid in g[r["name"]]] for r in rows]
same_pairs = [(a[i - 1][0], a[i][0], a[i][1], gi)
              for gi, a in enumerate(groups) for i in range(1, len(a))
              if a[i][1] and a[i][1] == a[i - 1][1]]
diff_pairs = [(a[i - 1][0], a[i][0])
              for a in groups for i in range(1, len(a))
              if a[i][1] and a[i - 1][1] and a[i][1] != a[i - 1][1]]
group_size = 0
if same_pairs:
    target_anchor = same_pairs[0][2]
    group_size = sum(1 for _, x in groups[same_pairs[0][3]] if x == target_anchor)
```

`shared/tests/fixtures/docreview/cases.sh` — 옛:

```bash
  # 인접 쌍의 둘째 항목이 렌더에서 «자기 헤더로» 처음 나오는 줄 바로 앞줄을
  # 뽑는다 — [리뷰 fix round 2] bare fid 매치(예전 코드)는 그 fid 가 «다른»
  # 항목의 헤더보다 먼저, 참조로 나오면(예: `_rg_blocking_ask` 의 「→ 전제인
  # fix: <fid>」) 그 참조 줄을 헤더로 오인한다 — 오늘 쓰는 두 쌍(decide ·
  # unapplied_fix)엔 안 걸리지만 일반적으로 안전하지 않다. `choices_match`
  # (cases.sh:490)와 같은 헤더 앵커 방식으로 좁힌다: 모든 렌더러가 헤더를
  # 「] <fid>」로 시작한다(그 뒤 구분자만 「—」/「→」로 갈린다 — `_rg_superseded`
  # 가 유일하게 「→」다) — 참조 문구엔 그 앞의 「]」가 없으므로 이 접두로
  # 헤더와 참조가 갈린다.
```

새:

```bash
  # 인접 쌍의 둘째 항목이 렌더에서 «자기 항목 머리로» 나오는 줄 바로 앞줄을 뽑는다(`item_prev_line`).
  # bare fid 매치는 그 fid 가 다른 항목 안에 참조로 나오면(예: `_rg_blocking_ask` 의 「이 답을 기다리는
  # 수정: <fid>」) 그 줄을 머리로 오인한다. `item_prev_line` 은 열 0 의 「- 」로 시작하고 「(<fid>)」·
  # 「(<fid> · 자동)」으로 끝나는 줄만 머리로 본다 — 참조 줄은 그 끝 괄호 모양이 아니라 갈린다.
```

`shared/tests/test_docreview_mutations.sh` — 옛:

```bash
# ㊷ I2 — `_rg_escalated_fix` 의 렌더 문구에서 「drop 하면 이 차단이 풀린다」 힌트를
```

새:

```bash
# ㊷ I2 — `_rg_escalated_fix` 의 렌더 문구에서 「버리면(drop) 이 차단이 풀린다」 힌트를
```

`tools/plain-language/test_measure_output.py` — 옛:

```python
                         "「미검증」 리뷰어(doc-critic)가 결과를 내지 못해 이 라운드는 리뷰되지 않았다. 리뷰 1라운드 — 남은 것 없음.",
```

새:

```python
                         "「미검증」 리뷰어(doc-critic)가 결과를 내지 못해 이 라운드는 리뷰되지 않았다. 리뷰 1라운드.",
```

마지막 둘: ㊷ 셀 주석은 렌더 문구가 PR 1 에서 「버리면(drop)」으로 바뀐 것을 따른다. `test_measure_output.py` 표본은 Step 3 (g) 뒤의 실제 「미검증」 첫 줄이다(그 단언 `v2_status_first_line` 은 「「미검증」」 머리로 세므로 값은 그대로다).

- [ ] **Step 5: 통과하는지 보고 golden 을 다시 뜬다**

Run:
```bash
for t in test_docreview_route test_docreview_state test_docreview_agent_fields test_docreview_golden; do printf '%s ' "$t"; PYTHONDONTWRITEBYTECODE=1 bash shared/tests/$t.sh 2>&1 | tail -1; done
```
Expected: 앞 셋은 `Fail: 0`. `test_docreview_golden` 은 `Fail: 2`(`case_T11_permit_keeps_disposition.gate.txt` · `case_T22_reraise_appears_in_next_round.gate.txt` 불일치 — 의도한 렌더 변경).

```bash
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/fixtures/docreview/capture_finalize_golden.sh >/dev/null 2>&1; echo "capture rc=$?"
git status --porcelain shared/tests/fixtures/docreview/golden/
git diff -U0 -- shared/tests/fixtures/docreview/golden/ | grep '^[+-][^+-]'
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_golden.sh | tail -1
```
Expected: `capture rc=0`. 바뀐 파일은 ` M …/case_T11_permit_keeps_disposition.gate.txt` · ` M …/case_T22_reraise_appears_in_next_round.gate.txt` 둘뿐이다(`*.gate.json` · `*.fin.json` · `*.state.md` 가 바뀌었으면 멈춘다 — 렌더 수정이 기계 경로를 건드렸다). diff 는 첫 줄 둘과 T22 의 `-  ┆ 같은 자리(#3-non-goals)` 한 줄이다 — 이 표지가 「다른 결정으로 넘어간 것 1개」 제목 바로 아래에서 앞 묶음의 항목을 가리키던 (c) 의 실례다. 새 첫 줄:

```text
리뷰 2라운드를 마쳤다 — 정할 것 4개 · 아직 안 고친 곳 4개 · 수정의 전제가 되는 질문 1개가 남았다. 경고 2개: codex 리뷰가 없어 다른 모델의 시각이 빠졌다 (codex: exit_nonzero) · 재비판이 돌지 않아 잘못된 지적을 걸러 내지 못했다 (doc-recritic: missing)
리뷰 2라운드를 마쳤다 — 정할 것 5개 · 다른 결정으로 넘어간 것 1개 · 아직 안 고친 곳 3개 · 수정의 전제가 되는 질문 1개가 남았다. 경고 3개: codex 리뷰가 없어 다른 모델의 시각이 빠졌다 (codex: exit_nonzero) · 세부 검토 결과(층 2)가 없어 세부 지적을 셀 수 없다 (layer2: block missing) · 재비판이 돌지 않아 잘못된 지적을 걸러 내지 못했다 (doc-recritic: missing)
```
옛 첫 줄은 원문 넷 · 여섯을 그대로 늘어놓았다(codex 부재가 두 번, 재비판 부재가 두 번, 층 2 부재가 두 번). 마지막 줄 Expected: `Fail: 0`.

- [ ] **Step 6: 변이 셀**

`shared/tests/test_docreview_mutations.sh` 의 PR 1 셀 묶음 끝(`warns_need_left` 셀) 바로 뒤에 넣는다. 기준 줄:

```bash
mut 1/1 warns_need_left case_T40_codex_absent_nothing_left_first_line sed_state \
  's/^    if warns:$/    if warns and left:/'
```

넣을 글:

```bash
# ── 쉬운 말 출력 PR 2 Task 5 (PR 1 이연 항목) ─────────────────────────────────
# 경고 원문을 쉬운 줄로 바꾸는 호출을 떼기 — 첫 줄에 엔진 원문이 그대로 선다.
mut 1/1 warns_plain_gloss_off case_plain_warns_first_line sed_state \
  's/^    warns = _plain_warns(warns)$//'
# 같은 사실의 합치기를 끄기 — 원문마다 키가 따로 생겨 codex 부재가 첫 줄에 두 번 나온다.
mut 1/1 warns_same_fact_not_merged case_plain_warns_first_line sed_state \
  's/^            k = (row\[1\], row\[2\])$/            k = (row[1], row[2], w)/'
# 사유 토큰 모으기를 끄기 — 괄호에 이름만 남고 왜 빠졌는지가 사라진다.
mut 1/1 warns_reason_dropped case_plain_warns_first_line sed_state \
  's/^        if why and why not in why_of\[k\]:$/        if False:/'
# 표에 없는 원문을 버리기 — 모르는 경고가 첫 줄에서 조용히 사라진다(P6 위반).
mut 1/1 warns_unknown_dropped case_plain_warns_unknown_kept sed_state \
  's/^            k = w$/            continue/'
# 묶음마다 새로 세기를 지우기 — 같은 자리 표지가 묶음 제목 너머의 항목을 가리킨다.
mut 1/1 marker_crosses_group case_gate_marker_stays_in_group sed_state \
  's/^        prev_anchor = None$//'
# 막힌 이유의 한 줄 접기를 떼기 — 사유 속 개행이 열 0 에 가짜 항목 머리를 세운다.
mut 1/1 escalate_reason_unfolded case_I4_escalate_reason_newline_collapsed sed_state \
  's/ % (_one(st\["findings"\]\[fid\]\.get("summary")), _one(why), fid)\]$/ % (_one(st["findings"][fid].get("summary")), why, fid)]/'
# 「미검증」 첫 줄에 「남은 것 없음」을 되살리기.
mut 1/1 unverified_nothing_left case_T46_unverified_no_nothing_left sed_state \
  's/ if left else ("\." if lead else " — 남은 것 없음\."))$/ if left else " — 남은 것 없음.")/'
```

셀마다 선언한 churn 은 sed 프로그램에서 도출했다 — 한 줄을 다른 한 줄로(또는 빈 줄로) 바꾸므로 전부 `1/1` 이다. 바깥 `    prev_anchor = None` 은 들여쓰기가 넷이라 `marker_crosses_group` 의 `^        prev_anchor = None$`(여덟)에 안 걸린다.

Run:
```bash
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_mutations.sh > /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr2-t5-mut.log 2>&1; tail -1 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr2-t5-mut.log
grep -E "warns_plain_gloss_off|warns_same_fact_not_merged|warns_reason_dropped|warns_unknown_dropped|marker_crosses_group|escalate_reason_unfolded|unverified_nothing_left" /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr2-t5-mut.log
```
Expected: `Fail: 0`(셀 일곱이 늘어 Total 이 7 커진다 — 4d325819 에서 111 → 118), 그리고 일곱 줄이 전부 `✓ … (규칙에 이빨이 있다) [churn 1/1]` 이다. 드라이런 실측:

```text
변이 'warns_plain_gloss_off' → case_plain_warns_first_line RED(10) 생존(2)
변이 'warns_same_fact_not_merged' → case_plain_warns_first_line RED(3) 생존(9)
변이 'warns_reason_dropped' → case_plain_warns_first_line RED(3) 생존(9)
변이 'warns_unknown_dropped' → case_plain_warns_unknown_kept RED(1) 생존(0)
변이 'marker_crosses_group' → case_gate_marker_stays_in_group RED(2) 생존(1)
변이 'escalate_reason_unfolded' → case_I4_escalate_reason_newline_collapsed RED(2) 생존(1)
변이 'unverified_nothing_left' → case_T46_unverified_no_nothing_left RED(2) 생존(1)
```

- [ ] **Step 7: 커밋**

```bash
git add shared/docreview/scripts/docreview_state.py shared/docreview/agents/doc-critic.md shared/docreview/agents/doc-critic-web.md plugins/spec-distill/agents/doc-critic.md plugins/spec-distill/agents/doc-critic-web.md shared/tests/fixtures/docreview/cases.sh shared/tests/fixtures/docreview/golden/case_T11_permit_keeps_disposition.gate.txt shared/tests/fixtures/docreview/golden/case_T22_reraise_appears_in_next_round.gate.txt shared/tests/test_docreview_route.sh shared/tests/test_docreview_mutations.sh shared/tests/test_docreview_agent_fields.sh tools/plain-language/test_measure_output.py
git status --porcelain
git commit -m "fix(docreview): 렌더 첫 줄 경고를 쉬운 말 한 줄씩으로, 같은 자리 표지는 묶음 안에서만

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
`git status --porcelain` 은 커밋 전 `M ` 으로 시작하는 열두 줄(위 열두 파일)만 내야 한다 — ` M` · `??` 줄이 있으면 멈춘다(다른 파일이 바뀌었다).

- [ ] **Step 8: 커밋 뒤에만 도는 락과 이웃 락**

`test_agent_model_mutation.sh` 는 `agents/` 에 미커밋 변경이 있으면 RED 다 — 커밋 뒤에 돈다.

Run:
```bash
for t in plugins/quality-gates/tests/test_agent_model_mutation.sh plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh shared/tests/test_dispatch_disposition.sh shared/tests/test_docreview_agents.sh shared/tests/test_copy_of_contract.sh shared/tests/test_variant_of_contract.sh shared/tests/test_docreview_gate_visibility.sh shared/tests/test_adjudication_behavior.sh plugins/spec-distill/tests/test_brief_agents.sh plugins/spec-distill/tests/test_reviewing_brief_skill.sh; do printf '%s ' "$t"; PYTHONDONTWRITEBYTECODE=1 bash "$t" 2>&1 | tail -1; done
(cd tools/plain-language && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_measure_output 2>&1 | tail -1)
(cd plugins/quality-gates/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_synthesize_findings_adjudication 2>&1 | tail -1)
```
Expected: 전부 `Fail: 0`, 두 unittest 는 `OK`.

---

## Task 6: README · 소개 문구 · 버전 (설계 §8 · AC10)

**Files:**
- Modify: `plugins/spec-distill/README.md`
- Modify: `plugins/spec-distill/tests/test_brief_review_meta.sh`(`section '^## Flow'` 두 자리 → `'^## 흐름'` · `section '^## Kill switches'` → `'^## 끄는 법'`)
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`(description · version) · `.claude-plugin/marketplace.json`(spec-distill 항목 description)
- Modify: `plugins/spec-distill/CHANGELOG.md`
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`(version) · `plugins/quality-gates/CHANGELOG.md`(Q12)

- [ ] **Step 1: README 를 새 규칙대로 다시 쓴다**

구조(이 순서):

1. 첫 문단 — 이 플러그인이 무엇을 해 주는지 세 문장 안에. 「흐릿한 요청을 → 인터뷰로 brief 로 → 설계문서 리뷰까지」. 내부 번호·약어는 첫 등장에 풀어 쓴다.
2. `## 쓰는 법` — 명령 둘(`/request-framing` · `/interview`)과 skill 하나(`reviewing-spec`)를 한 줄씩. 각 줄은 「언제 쓰나 — 무엇이 나오나」.
3. `## 흐름` — 지금 README 의 흐름 그림(33 · 48 행의 게이트 줄 포함)을 유지하되 머리글과 설명 문장을 쉬운 말로. `test_brief_review_meta.sh` 의 `section '^## Flow'` 두 자리(43 · 62행)를 `section '^## 흐름'` 으로 같은 커밋에서 바꾼다.
4. `## 끄는 법` — kill switch 표(지금 있는 스위치 전부, 이름은 영어 그대로). 같은 파일의 `section '^## Kill switches'`(50행)를 `section '^## 끄는 법'` 으로 같은 커밋에서 바꾼다. 하위 `### 은퇴한 스위치` 는 이 절 아래에 머리글 글자 그대로 남긴다.
5. `## Principles Instantiated` — 제목·하위 제목(`### Three Laws` · `### Principles 흡수` · `### Roadmap absorption (C-numbers)` · `### Anti-pattern 회피`)과 불릿 형식(`- **Law N (…) — … (vX)** — …`)은 그대로 둔다. 불릿 본문만 쉬운 문장으로 다듬되, 아래 낱말은 지우지 않는다.
6. 나머지 절 — `## External source absorption` · `## Hooks Installed` · `## Prerequisites` · `## License` — 은 지우지 않고 뒤에 그대로 둔다. `### 은퇴한 스위치` 는 `## 끄는 법` 아래 하위 절로 남긴다(머리글 글자 그대로). 지우면 CLAUDE.md 의 「Hooks Installed」 · prerequisites 요구와 `test_review_hook_removed.py` 의 은퇴 절 예외가 무너진다.

README 끝 줄 「스위치 목록」의 `게이트 질문에 표시된다` 는 `다음 단계 게이트 앞 글에 표시된다` 로 바꾼다(Task 3 의 경고 위치 규칙과 맞춘다).

지워지면 안 되는 낱말(README 락 — 조사 2026-10-08):
- `test_readme_sync.sh:62-64`: `DEVBREW_SPEC_DISTILL_DISABLE_WEB` · `spec-distill:review-entry` · `review_entry.py` · `interview-brief` · `steelman-builder` · `DEVBREW_SPEC_DISTILL_DISABLE_CODEX` · `model diversity` · `coverage-mapper` · `blind-spot-prober` · `user_sourced_items` · `audit_file` · `user_statements` · `bijection`.
- `test_readme_sync.sh:68`(Principles 창): `라운드별 잠금|라운드마다 결정` · `일괄 확인|사용자 확인` · `payload.*audit|2파일|두 파일` · `user_sourced_items`.
- `test_readme_sync.sh:81-82`: `2파일 쌍` · `.audit.md` · `8섹션`.
- `test_brief_review_meta.sh`: 머리글 `## 흐름` · `## 끄는 법` 으로 절을 자른다. 지켜야 할 것 — 흐름 그림 펜스가 10줄 이상이다 · 그림에 `interview brief` → `reviewing-brief` → `Step B proceed 게이트` 가 이 순서로 나온다 · 흐름 절에 `^[0-9]+\.` 로 시작하는 번호 줄이 없다 · 끄는 법 절에 `DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW` 가 있다 · `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1` 줄 하나가 `reviewing-spec` · `reviewing-brief` · `run_docreview_codex_reviewer.sh` · `codex-gate` 를 모두 대고 `3곳|세 곳|세 지점` 은 쓰지 않는다 · Principles 절에 `Law 2` 가 있고 Principles 절과 흐름 절에 `doc-critic` · `doc-recritic` · `brief-readback` · `reviewing-brief` 가 있다.
- `test_seed_at_path_handoff.sh:151 · :164`: README 에 `/interview @<seed 경로>` 가 있어야 하고, `다음 세션 첫 턴에 붙여넣는 메시지` 는 없어야 한다.
- `test_review_hook_removed.py`: 은퇴한 토큰은 `### 은퇴한 스위치` 머리글 아래에서만 허용된다.
- `test_handoff_kill_switch.sh` · `test_no_wall_clock.sh` · `test_stale_terms.sh`: README 를 검사 대상에 넣는다.
- `plugins/quality-gates/tests/test_law2_prose.sh`: `plugins/*/README.md` 를 전부 훑는다.
- `test_reviewing_brief_skill.sh`(README 의 `G1..G<N>` 범위 = SKILL 표 끝), `test_rereview_cap_consistency.sh`, `test_conducting_interview_stage.sh:1431-1455`(`<n>-path` 개수, 살아 있는 `5-type` 없음), `shared/tests/test_python_floor.sh` 의 spec-distill README 단언.

쓰고 나서 위 락을 모두 돌린다:

```bash
for t in test_readme_sync test_brief_review_meta test_seed_at_path_handoff test_handoff_kill_switch test_no_wall_clock test_stale_terms test_reviewing_brief_skill test_rereview_cap_consistency test_conducting_interview_stage; do printf '%s ' "$t"; bash plugins/spec-distill/tests/$t.sh 2>&1 | tail -1; done
(cd plugins/spec-distill/tests && python3 -m unittest -v test_review_hook_removed 2>&1 | tail -3)
bash shared/tests/test_python_floor.sh | tail -1
bash plugins/quality-gates/tests/test_law2_prose.sh | tail -1
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

origin/main 의 spec-distill 버전을 다시 보고 minor 를 올린다. quality-gates 는 patch 를 올린다(Q12). spec-distill CHANGELOG 맨 위 항목 앞:

```markdown
## [<새 버전>] — <YYYY-MM-DD>

### Changed
- 모든 게이트(interview 다음 단계 · 설계문서 승인 · 리뷰 라운드 · request-framing 확정)가 경고 목록을 질문 앞 글에 쓰고, 질문에는 결정 하나와 「경고 N개 — 위에 적었다」 한 줄만 싣는다. 머리글 「Proceed」는 「다음 단계」다. 「이상 없음」은 남은 것도 경고도 없을 때만, 남은 것이 있으면 「경고 없음」이다.
- framing-requests 의 degrade 채널 이름이 「proceed 게이트 앞 글」이다(처분 앵커 포함).
- 핸드오프 `/compact` 명령이 사람에게 쓰는 글 규칙도 유지하게 한다. reviewing-spec 에 그 명령 틀이 생겼다.
- codex 건너뜀 · brief 리뷰 건너뜀 · 기준 사본 부재 · 확정 재제시 상한 문구가 쉬운 말이다(사유 토큰은 그대로).
- README 와 소개 문구를 쉬운 말로 다시 썼다.
- 문서 리뷰 게이트 첫 줄의 경고가 쉬운 말 한 줄씩이다. 같은 사실을 두 번 말하던 원문(codex 부재 · 재비판 부재 · 층 2 부재)은 한 줄로 합치고 사유 토큰은 괄호에 남긴다. `fin.json` · `gate` JSON 의 `advisory` 원문은 그대로다.
- 「미검증」·라운드 미완 첫 줄이 「남은 것 없음」을 쓰지 않는다.
- 탐지 리뷰어(`doc-critic` · `doc-critic-web`)의 사람이 읽는 칸 안내 문장에서 「읽는다」 반복을 뺐다(규칙은 그대로).

### Fixed
- 「┆ 같은 자리」 표지가 묶음 제목 너머의 앞 묶음 항목을 가리키던 것 — 이제 묶음마다 새로 센다.
- 고치려다 막힌 곳의 사유에 줄바꿈이 있으면 다음 줄에 가짜 항목 머리가 서던 것 — 한 줄로 접는다.
```

quality-gates CHANGELOG 맨 위 항목 앞(엔진 링크가 같은 변경을 싣는다):

```markdown
## [<새 버전>] — <YYYY-MM-DD>

### Changed
- 엔진 링크 `scripts/docreview_state.py` 가 바뀌었다 — 문서 리뷰 게이트 첫 줄의 경고가 쉬운 말 한 줄씩이고(같은 사실의 원문 둘은 한 줄로, 사유 토큰은 괄호에), 「┆ 같은 자리」 표지는 묶음 안에서만 앞 항목을 가리키며, 막힌 이유는 한 줄로 접힌다. `advisory` 원문은 그대로다.
```

- [ ] **Step 4: 최종 스위트와 대조**

```bash
bash ~/.claude/sdd-mirror/plain-language-output/run-suite.sh pr2/final
comm -13 ~/.claude/sdd-mirror/plain-language-output/pr2/baseline/failures.txt ~/.claude/sdd-mirror/plain-language-output/pr2/final/failures.txt
```
Expected: 빈 출력.

- [ ] **Step 5: 커밋 · /qg · PR**

```bash
git add plugins/spec-distill/README.md plugins/spec-distill/tests/test_brief_review_meta.sh plugins/spec-distill/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/spec-distill/CHANGELOG.md plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md
git commit -m "docs(spec-distill): README 와 소개 문구를 쉬운 말로, 버전 올림(quality-gates patch 포함)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

`/qg branch` 를 돌리고 리뷰어에게 명시해 묻는다: 「경고를 앞 글로 옮긴 뒤에도 사용자가 고르기 전에 경고를 보는가 · 배치 락(`test_brief_review_entry.sh`)이 옮긴 뜻을 지키는가 · 처분 앵커와 본문 채널 이름이 같은 글자인가」.

PR 본문(한국어): 첫 줄에 바뀐 것 한 문장 · 「계획이 정한 것」 Q1~Q12 · 문구 고정 테스트 표(Task 2 Step 4, Task 4 Step 3 — 옛 → 새 · 지키는 뜻) · 고정 문구 분류 표(Q7) · 변이 결과 · 할 일 하나: 「`/request-framing` 으로 작은 요청 하나를 넣고 `/interview` 끝의 다음 단계 질문까지 가서, 경고가 질문 앞에 있고 질문은 짧은지 봐 주세요」(Verification Plan 4). 맨 끝 `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

머지는 사용자가 `! gh pr merge <n> --merge`. 머지 뒤 main 을 merge 로 받고 PR 3 계획으로 간다.
