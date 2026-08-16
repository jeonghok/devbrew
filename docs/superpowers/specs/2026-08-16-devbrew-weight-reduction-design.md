---
name: devbrew-weight-reduction
type: design
date: 2026-08-16
interview_brief: docs/superpowers/interview/2026-08-16-devbrew-weight-reduction-interview.md
next_phase: superpowers:writing-plans
---

# devbrew 무게 감축 — Design

> 리포가 무겁다. 무게는 셋이다 — 정본 트리의 줄 수, 모델이 매번 읽는 줄 수, 지켜야 할 규약의 가짓수.
> 이 설계는 셋을 각각 다른 수단으로 친다: **이동**(정본 트리) · **조건부 로드**(모델 표면) · **통합**(규약).
> 그리고 통합한 것이 다시 갈라지지 않도록 `copy-of` 계약 하나를 남긴다.

## 목차

- [0. 한눈에](#0-한눈에)
- [1. 문제 — 측정된 것](#1-문제--측정된-것)
- [2. 접근 — 경계선](#2-접근--경계선)
- [3. 대상 전수 — census와 분류 규칙](#3-대상-전수--census와-분류-규칙)
- [4. 작업 A — 아카이브 이동](#4-작업-a--아카이브-이동)
- [5. 작업 B — 영향 매핑 수리 (OQ1의 답)](#5-작업-b--영향-매핑-수리-oq1의-답)
- [6. 작업 C — 사본 통합](#6-작업-c--사본-통합)
- [7. 작업 D — 규약 축소](#7-작업-d--규약-축소)
- [8. 작업 E — SKILL 분할](#8-작업-e--skill-분할)
- [9. 작업 F — 테스트 공유 lib](#9-작업-f--테스트-공유-lib)
- [10. 작업 G — /compact 게이트 통일](#10-작업-g--compact-게이트-통일)
- [11. 작업 H — 폴더 구조와 `shared/`](#11-작업-h--폴더-구조와-shared)
- [12. 락 — `copy-of` 계약과 20줄 검사](#12-락--copy-of-계약과-20줄-검사)
- [13. 실행 순서 · PR 분할](#13-실행-순서--pr-분할)
- [14. 검증 · 완료 측정](#14-검증--완료-측정)
- [15. 위험](#15-위험)
- [16. 기각한 대안](#16-기각한-대안)
- [17. 목표 대조표](#17-목표-대조표)

## Handoff Context

> 이 설계를 처음 보는 사람(또는 `/compact` 후 자기 자신)이 30초에 핵심을 잡게 하는 블록.
> 대화 컨텍스트를 가정하지 않는다.

**TL;DR** — devbrew 5플러그인 리포의 무게를 줄인다. 여덟 작업(A 아카이브 이동 · B 영향 매핑
수리 · C 사본 통합 · D 규약 축소 · E SKILL 분할 · F 테스트 공유 lib · G `/compact` 통일 ·
H 폴더 구조+`shared/`), PR 여섯 개. 통합한 것은 `copy-of` 락이 지키고 새 중복은 20줄 블록
검사가 잡는다. 파일 크기·개수·폴더 모양은 재지 않는다.

**이 설계가 서 있는 실측** — 리포에 CI·git 훅이 없다. 러너는 둘(`run-own-tests.sh`는
python만, `run-test-selection.sh`는 실행비트 선 셸을 영향 선택으로). **결함은 러너가 아니라
영향 매핑에 있다** — `.sh`·`.md`에 src→test 매핑이 없어 락이 지키는 대상이 바뀔 때 그 락이
선택되지 않는다. 중복은 전수 census로 셌다(같은 basename 16종 · 유사 쌍 5 · 함수 이름 119종).

**암묵 컨텍스트 (문서 밖 근거)**

| 무엇 | 어디서 왔나 |
|---|---|
| 제약 C1~C21 | `docs/superpowers/interview/2026-08-16-devbrew-weight-reduction-interview.md` §2 |
| C11(원장 연기)을 **유지**한다는 결정 | 리뷰 라운드 1에서 사용자가 "작업 I 빼고 원장은 지금 만들지 않고 모으기만" |
| 락을 개수·크기 강제가 아닌 형태로 만든 이유 | 사용자 지시 — "기계적으로 구조나 크기 개수를 강제하는 형태는 아니었으면" |
| `shared/` 중립 위치 | 사용자 제안 — "중립 위치에서 통합을 관리하는 건 가능할까" |
| 스크립트 17개 분할을 미룬 이유 | §16에 실측 근거 셋 |

**plan으로 넘기는 미결** — ① severity 3척도 → 1의 **매핑 방향**(§7, 머지 차단 임계가 이동한다)
② 테스트 이관 시 `parents[N]` 재앵커 대상 목록(§11.1) ③ PR1 기준선 캡처 결과에 따른 PR1 범위
④ `# guards:` 선언이 없는 기존 셸 테스트의 기본 동작(§5.3).

## 0. 한눈에

**무엇** — devbrew(143,584줄 / 715파일)의 무게를 줄인다. 여덟 작업 A~H, PR 여섯 개.

**세 축과 각각의 수단**

| 축 | 수단 | 작업 |
|---|---|---|
| 정본 트리 줄 수 | 완료 산출물을 아카이브로 **이동**(삭제 아님) | A |
| 모델이 매번 읽는 줄 수 | 조건부로만 필요한 섹션을 `references/`로 **분리** | E |
| 규약 가짓수 | 같은 책임의 사본을 **통합** + 이름·형식을 하나로 | C · D · F · G · H |

**통합의 자리** — 리포 루트 `shared/`. 정본이 어느 플러그인 소유도 아니다(§11.4).

**통합을 지키는 장치 둘**(§12) — `copy-of` 동일성 락(이미 통합한 것의 재분열)과 20줄 블록 검사(새 중복 유입). 파일 크기·개수·폴더 모양은 재지 않는다.

**미룬 것** — 이 문서 §15.1에 **모으기만** 한다. 원장 파일·메커니즘은 만들지 않는다(C11 유지).

**선행 조건** — 작업 B(영향 매핑 수리)가 먼저다. 락은 **자기 파일이 diff에 있을 때만** 선택되고,
`.sh`·`.md`에는 src→test 영향 매핑이 없어 **락이 지키는 대상이 바뀔 때 그 락은 돌지 않는다**(§1.4).
매핑을 고치기 전에 락을 더 다는 것은 Law 3이 말하는 theater다.

**범위 밖** — 스크립트 파일 분할(§16에 실측 근거) · `docs/superpowers` 삭제 · 아카이브 내부 정리 ·
`scripts/` 하위 분류 · 실행 지점 신설 · **backlog 원장 구축**(§15.1에 모으기만 한다 — C11 유지).

## 1. 문제 — 측정된 것

2026-08-16 실측, `main` = `0154666`. 인터뷰 brief의 수치 중 넷이 어긋나 있어 재측정했다.

### 1.1 리포 구성

| 영역 | 줄 | 비중 |
|---|---:|---:|
| `plugins/` (비테스트) | 32,122 | 22.4% |
| `plugins/**/tests/` | 52,606 | 36.6% |
| `docs/superpowers/` | 54,526 | 38.0% |
| `docs/audits/` | 3,362 | 2.3% |
| 나머지 | 968 | 0.7% |
| **합계** | **143,584** | |

### 1.2 모델이 읽는 표면 — 6,562줄

`SKILL.md` 8개 + `agents/*.md` 18개 + `commands/*.md` 7개 + `CLAUDE.md`.
그중 `quality-gates/skills/quality-pipeline/SKILL.md` 한 파일이 **2,049줄(31%)**, 그 안의
`## Runtime gate` 한 섹션이 **1,190줄(그 파일의 58%)** 이다.

### 1.3 중복 인구조사 (전수)

`git ls-files` 402파일을 결정론 스크립트로 전수 대조했다. 표본이 아니다.

| 축 | 실측 |
|---|---|
| 같은 basename이 2곳 이상 | 16종 (바이트 동일 1 / 갈라짐 15) |
| basename이 다른데 유사도 ≥60%인 파일 쌍 | 5쌍 |
| 2곳 이상에서 정의된 함수 이름 | 119종 · 정의 609개 · 본문 430변형 |
| — 본문이 전부 같음 | 16종 / 34정의 |
| — 일부만 같음 | 17종 / 350정의 |
| — **전부 다름 (같은 이름이 다른 뜻)** | **86종 / 225정의** |
| 2파일 이상이 공유하는 동일 텍스트 블록 | §12.7 표 참조 (파라미터가 다르므로 그곳에 한 번만 싣는다) |

**측정 파라미터 (재현용).** 유사도 임계 60%는 이 조사가 정한 값이며 그 아래는 잡히지 않는다.
파일 유사도는 `difflib.SequenceMatcher` 비율이고, 정규화는 공백줄·주석줄 제거다.
함수 본문 경계는 중괄호 깊이(셸)·들여쓰기(파이썬)로 자르고 주석·공백 정규화 후 해시했다.
코퍼스는 `git ls-files` 402파일 — `fixtures/`·`mocks/`·`docs/superpowers/`·`docs/audits/`·
`CHANGELOG.md` 제외. **블록 검사만 코퍼스가 다르다**(§12.7: `plugins/**` 399파일) —
그 검사의 대상이 배포되는 코드이기 때문이며, 두 수치를 같은 표에 나란히 두지 않는 이유다.

### 1.4 검증이 도는 곳 — 그리고 안 도는 곳

리포에 CI·스케줄러·git 훅이 하나도 없다(`.github/` 부재 · Makefile 부재 · `.git/hooks`에 `*.sample`만 · `core.hooksPath` 재지정 없음). 자동 발화하는 것은 플러그인 훅 10개뿐이다.

러너는 **둘**이고 성격이 다르다.

| 러너 | 무엇을 돌리나 | 언제 |
|---|---|---|
| `plugin-audit/scripts/run-own-tests.sh` | `python3 -m unittest discover` — **`test*.py`만** | `/plugin-audit <target>` 실행 시 |
| `quality-gates/scripts/run-test-selection.sh` | shell 어댑터 — `tests/*.sh`\|`*/tests/*.sh` 중 **실행비트가 선 것** (`:383` `has_exec_shell_tests` · `:661` `claimed=shell` · `:825` `shell_unit_in_scope`) | `/qg` Runtime gate, **영향 선택된 후보에 한해** |

셸 테스트 165개 중 **150개가 실행비트를 갖고 있어** qg shell 어댑터 자격이 있다. 크로스-플러그인
락 7개도 전부 실행비트를 갖고 있다. **잠들어 있지 않다.**

**그런데 락은 자기가 편집될 때만 깨어난다.** 후보 집합은
`compute-test-scope-candidates.sh`가 diff에서 만드는데, 그 안의 src→test 매핑이
`# Heuristic src→test mapping (Python, JS, TS only)`(`:120`)로 한정돼 있고
`# Other languages: no heuristic; only CHANGED_TESTS counts`(`:143`)로 끝난다.

| 무엇이 바뀌면 | 그 락이 후보에 들어가나 |
|---|---|
| `plugins/*/agents/*.md` | ❌ `test_agent_frontmatter_keys.sh` 미선택 |
| `detect_codex.sh` (`.sh`) | ❌ `test_detect_codex.sh` 미선택 |
| `SKILL.md` | ❌ `test_law2_prose.sh` 미선택 |
| 락 파일 자신 | ✅ 선택 |

즉 **락이 지키는 대상이 바뀔 때 그 락은 돌지 않는다.** 이것이 이 설계가 고쳐야 할 실제 결함이며,
brief의 OQ1("잔여 락을 무엇이 돌리는가")의 답이 여기서 나온다(§5).

| 그 밖의 사실 | 근거 |
|---|---|
| `/plugin-audit project-init`이 **0개를 수집하고 `ran=true`를 보고한다** | `run-own-tests.sh:57`의 `break` — `tests/`에서 멈춰 `hooks/tests/`의 파이썬 3개를 안 봄 |
| `marketplace.json` description **4/5가 drift** | 감지 검사는 `check-staleness.py:393-413`에 **이미 있다** — 실행되지 않을 뿐 |
| `discover-plan.sh`가 이미 머지된 plan을 이번 계획으로 고른다 | plan 15/15가 미체크 `- [ ]`를 보유 — 그 술어가 아무것도 구분하지 못함 |

### 1.5 진단

무게의 원인은 셋이 아니라 하나로 수렴한다. **쓰인 것과 도는 것이 갈라져 있다.**
락은 쓰였지만 **자기가 편집될 때만** 돌고, 사본은 같아야 한다고 선언됐지만 갈라졌고
(`test_codex_prompt_untrusted_clause.sh:19`가 "plugin-audit의 preamble과 같은 것을 쓴다"고
선언했는데 실제 사본은 동일한 쌍이 0이다), 규약은 문서화됐지만 (`CLAUDE.md:47`의 state 배치
규약처럼) 어느 플러그인에서도 실현되지 않았다.

## 2. 접근 — 경계선

사본을 물리적으로 하나로 만들 수단이 이 플랫폼에 있는가가 갈림길이다.

### 2.1 설치 트리 실측

```
~/.claude/plugins/
  marketplaces/devbrew/          ← 리포 전체 git 클론 (docs/·plugins/·CLAUDE.md 포함)
                                    실측: branch main, HEAD b28b88e
  cache/devbrew/<plugin>/<version>/   ← 플러그인 서브트리만
                                    (CHANGELOG·README·agents·commands·hooks·scripts·skills·tests)
                                    docs/ 없음, 리포 루트 파일 없음
                                    qg 4버전 · sd 5버전 공존
```

`${CLAUDE_PLUGIN_ROOT}`는 **cache 쪽**을 가리킨다. 그러므로 런타임 스크립트에게는:

- 리포 루트의 `shared/`가 **없다**
- 옆 플러그인은 `../../<name>/<version>/`인데 **어느 버전인지 알 수 없다**(다중 버전 공존)

### 2.2 경계선

| | 리포에서만 도는 것 | **배포되는** 것 |
|---|---|---|
| 무엇 | `tests/` · `docs/` · `marketplace.json` | `plugins/*/{scripts,hooks,skills,agents}` |
| 조치 | **`shared/`의 파일 하나를 직접 쓴다** (사본 없음) | **`shared/`의 정본을 바이트 동일 사본으로 + `copy-of` 락** |
| 근거 | 실행 시 cwd = 리포 루트 | `${CLAUDE_PLUGIN_ROOT}` = cache 서브트리, `shared/` 부재 |

경계의 기준은 "리포를 떠나는가"가 아니라 **"`${CLAUDE_PLUGIN_ROOT}`에서 도달 가능한가"** 이다.
`docs/`는 마켓플레이스 클론에 함께 복제되므로 리포를 떠나기는 한다 — 다만 런타임 스크립트가
그것을 가리키는 경로가 계약에 없다.

`run-own-tests.sh:18`이 `plugins/quality-gates/scripts/qg-worktree.sh`를 리포-상대로 부르는 것이
"리포에서만 도는 것"의 선례다.

**정본은 중립 위치에 둔다.** 사본 중 하나를 정본으로 삼으면 소유 관계가 왜곡된다 —
`spec-distill`이 `quality-gates`의 파일을 베끼는 모양이 되고, 새 플러그인이 생기면 다시 애매해진다.
`shared/`는 어느 플러그인 소유도 아니며 배포되지 않는다(§11.4).

**공유되는 것은 파일로 만든다.** 지금 잡히지 않는 중복은 전부 파일의 *일부*(함수·문단·블록)다.
파일로 승격시키면 같은 플러그인 안에서는 중복이 소멸하고, 플러그인 사이에서는 파일 전체가
동일해져 §12의 락이 완전히 커버한다. 이 방식은 새로 만드는 것이 아니라
`plugin-audit/scripts/codex-prompt-preamble.md`가 이미 쓰고 있는 것을 나머지에 넓히는 일이다.

## 3. 대상 전수 — census와 분류 규칙

census는 **후보**를 낸다. 유사도가 높다고 곧 중복인 것은 아니다. 각 후보는 셋 중 하나다.

| 분류 | 판정 기준 | 조치 |
|---|---|---|
| **진짜 사본** | 같은 책임을 독립으로 저술. 한쪽 버그 수정이 다른 쪽에 안 가면 결함 | 통합 |
| **템플릿-인스턴스** | 한쪽에 치환 표식(`{{...}}`)이 있거나 한쪽이 다른 쪽의 생성 산출물 | 재적용 + 동일성 표시 |
| **우연** | 같은 이름·구조를 쓰지만 책임이 다름 | 조치 없음 |

이 규칙을 후보 전체에 적용한 결과:

**같은 basename 16종** → 진짜 사본 2 · 부분 사본 3 · 템플릿-인스턴스 3 · 우연 8

| 분류 | 항목 |
|---|---|
| 진짜 사본 | `detect_codex.sh` ×3 · `codex_findings_to_yaml.py` ×2 |
| 부분 사본 | `session-end-cleanup.py` ×2 · `test_detect_codex.sh` ×2 · `test_session_end_cleanup.py` ×2 |
| 템플릿-인스턴스 | `pr-process.md` · `commit-conventions.md` · `branch-strategy.md` |
| 우연 | `__init__.py`(빈 파일) · `hooks.json` · `post-tool-use.py`(12.6%) · `plugin.json` ×5 · `agents-md-section.md` · `.gitignore` · `SKILL.md` ×8 · `README.md` ×6 |

**basename이 다른 유사 쌍 5** → 전부 부분 사본, 4군:
frontmatter 검사 3종(81.4% / 76.4%) · codex 러너 2벌(74.0%) · artifact frontmatter 2종(72.6%) ·
`discover-plan.sh` ↔ `discover-spec.sh`(63.8%)

**함수 119종** → 위 파일군의 하위 증상 + 독립 항목 4개:
`kill_switch_active` ×5 · `_degrade_if_empty` ×5 · `emit` ×6 · `run_hook` ×7

### 3.1 템플릿-인스턴스의 판정 근거

`docs/git-workflow/*`는 project-init이 devbrew 자신에게 적용해 만든 산출물이고
`plugins/project-init/templates/*`가 그 원본이다. 근거는 원본 쪽의 치환 표식이다 —
`templates/shared/commit-conventions.md:39`의 `{{SCOPE_CONVENTION}}`,
`templates/shared/pr-process.md:41`의 `{{MERGE_STRATEGY}}`. 낮은 유사도는 치환 결과다.

**규칙 자체가 다른 곳은 한 군데뿐이다.** `docs/git-workflow/branch-strategy.md:63`은
"rebase 절대 금지"이고 `templates/github-flow/branch-strategy.md:63`은
"공유된 브랜치만 금지, 아직 공유되지 않은 로컬 브랜치 정리는 각자 판단"이다.
전자가 이 리포 소유자의 명시적 규칙이고 `test_branch_strategy_rebase_clause.sh`가 이미 지킨다.
**의도된 차이이므로 통합하지 않는다.**

## 4. 작업 A — 아카이브 이동

### 4.1 무엇을 옮기나

```
docs/audits/                  (14파일 · 3,362줄)  →  docs/archive/audits/
docs/superpowers/plans/       (15파일 · 39,904줄) →  docs/archive/plans/
docs/superpowers/specs/       (19파일 · 12,641줄) →  docs/archive/specs/
docs/superpowers/interview/   (완료 9파일)        →  docs/archive/interview/
```

이번 사이클의 활성 산출물(이 설계 문서, 그 인터뷰 brief, 그리고 뒤이어 나올 plan)은 제자리에 남는다.

**삭제가 아니라 이동이다.** 아카이브 내부의 해소와 최종 제거는 다음 사이클이다.

### 4.2 완료 판정의 진리원천

파일 안이 아니라 git 이력이다. plan 15개 중 완료 배너를 가진 것은 4개뿐이고
**15/15 전부가 미체크 `- [ ]`를 보유**한다 — 체크박스는 아무도 채우지 않았다.

```bash
git log --first-parent --diff-filter=A --format='%h %s' -- <파일> | tail -1
```

이 명령이 그 파일을 `main`에 들여온 PR 머지 커밋을 돌려준다. 실측 결과 plans 15/15 · specs 19/19가
전부 PR 머지를 통해 들어왔고, 진행 중인 것은 0개다.

### 4.3 부수 효과 — 두 발견 스크립트가 고쳐진다

`discover-plan.sh:97`과 `discover-spec.sh:91`이 둘 다 `find "$dir" -maxdepth 1`이다.
완료분이 `docs/archive/` 아래로 나가면 두 스크립트의 후보 집합에서 자동으로 빠진다.
**스크립트 수정 0줄로 plan 오선택이 닫힌다.**

### 4.4 참조 수정

`docs/audits`를 하드코딩한 참조는 **127건 / 24파일**이다.

| 계층 | 파일 | 건 | 성격 |
|---|---:|---:|---|
| plugins 테스트 | 5 | 18 | **살아 있음** — 경로가 바뀌면 RED |
| plugins skill | 2 | 8 | **살아 있음** — 모델이 읽음 |
| plugins 스크립트 | 2 | 4 | **살아 있음** — 실행 |
| `CLAUDE.md` | 1 | 1 | **살아 있음** — `validate-audit-data.py:147`이 이 문자열의 존재를 검사 |
| plugins README·CHANGELOG | 3 | 6 | 역사 |
| `docs/superpowers/plans` | 4 | 55 | 역사 |
| `docs/superpowers/specs` | 6 | 34 | 역사 |
| `docs/superpowers/interview` | 1 | 1 | 역사 |

**살아 있는 31건은 반드시 함께 고친다.** 누락하면 동작하는 게이트 둘이 죽는다 —
spec-distill 리뷰 파이프라인의 시작 선결 조건(`reviewing-brief/SKILL.md:104`)과
plugin-audit의 산출 경로 계약(`auditing-plugins/SKILL.md` 7개소).

**역사 96건은 인용을 정리한다.** 정의부만 옮기고 인용부를 남기면 없는 경로를 근거로 내세우는
서술이 되어 이동 전보다 나쁘다. 이 리포는 같은 판단을 커밋 `0154666`에서 이미 내렸다.

**fail-closed 확인 지점**: `validate-audit-data.py:147`이 `CLAUDE.md` 본문에 `docs/audits/`
문자열이 있는지 검사한다. 새 경로 `docs/archive/audits/`는 이 부분문자열을 포함하지 않으므로
검사가 RED로 간다 — 누락이 조용히 지나가지 않는다.

## 5. 작업 B — 영향 매핑 수리 (OQ1의 답)

### 5.1 고쳐야 할 것 — 결함은 러너가 아니라 매핑이다

락은 실행 가능하고 러너도 있다(§1.4). 결함은 **무엇이 후보로 뽑히는가**에 있다.

| # | 지금 | 고친 뒤 |
|---|---|---|
| **1** | `compute-test-scope-candidates.sh:120`의 src→test 매핑이 `Python, JS, TS only`. `.sh`·`.md`가 바뀌어도 그것을 검사하는 셸 락이 후보에 안 들어간다 | **`.sh`·`.md` 축을 매핑에 추가** |
| 2 | `run-own-tests.sh:45`가 `python3 -m unittest discover`만 실행 — `/plugin-audit` 경로에서 `.sh`가 안 돈다 | 셸 테스트도 수집·실행 |
| 3 | `run-own-tests.sh:57`의 `break`가 첫 히트 디렉토리 하나만 돌게 함 | `break` 제거 (작업 H가 원인도 제거) |

**1번이 본체다.** 2·3은 `/plugin-audit` 경로의 별개 결함이며, 3번의 실제 피해는
`plugins/project-init/tests/`에 셸 1개뿐이고 파이썬 3개가 `hooks/tests/`에 있어
`unittest discover`가 0개 수집 → exit 0 → `ran=true; why=""` 경로를 타는 것이다.
**아무것도 안 돌린 채 돌렸다고 보고한다.**

### 5.2 1번 매핑이 무엇을 살리나

아래 락들은 실행 가능하지만 **자기 파일이 편집될 때만** 후보가 된다. 매핑이 추가되면
**지키는 대상이 바뀔 때** 후보가 된다.

| 락 | 검사 스코프 | 매핑이 필요한 축 |
|---|---|---|
| `test_agent_model_inherit_sweep.sh:26` | `plugins/*/agents/*.md` 전량 `model: inherit` | `.md` |
| `test_agent_frontmatter_keys.sh:103,109` | `plugins/*/agents/*.md` frontmatter 키 규칙 | `.md` |
| `test_law2_prose.sh:18-19` | `plugins/*/README.md` + 모든 `SKILL.md` | `.md` |
| `test_codex_gate_observation.sh:43` | 모든 `SKILL.md`의 codex 게이트 형태 | `.md` |
| `test_codex_runner_no_effort_pin.sh:52` | `plugins/*/` 전체 러너 | `.sh` |
| `test_codex_prompt_untrusted_clause.sh:229` | `plugins/*/scripts/build_*codex*prompt.py` | `.py`(이미 있음) |
| `test_codex_extractor_positive_marker.sh:40` | `codex exec` 호출자 전량 | `.sh` |

여기에 `check-staleness.py:393-413`의 marketplace description drift 검사가 더해진다
(그건 `/plugin-audit` 경로이므로 2번이 살린다).

### 5.3 매핑의 모양 — 결정 사항

`.py`/`.js`의 heuristic은 이름 기반(`test_<base>.py`)이다. `.sh`·`.md`에는 그 관례가 없다
(`test_law2_prose.sh`는 `law2_prose.md`를 검사하지 않는다). 그래서 **이름이 아니라
스코프 선언**으로 매핑한다.

각 크로스-플러그인 락 파일 첫머리에 자기가 검사하는 경로 글롭을 선언하고, 매핑은 그 선언을 읽어
diff의 변경 파일과 대조한다.

```bash
# guards: plugins/*/agents/*.md
```

이 방식을 택한 이유: 이름 기반 heuristic을 `.sh`에 억지로 만들면 어떤 락이 무엇을 지키는지
추측해야 하는데, 그 추측이 틀리면 락이 **조용히** 선택되지 않는다. 선언은 락 저자가 쓰고
diff와 기계적으로 대조된다.

**미결**: 선언이 없는 기존 셸 테스트(150개 중 7개를 뺀 나머지)의 처리. 후보 산정에서
`CHANGED_TESTS`(자기 편집 시)만으로 남기는 것이 현행 동작과 같으므로 회귀가 없다.
plan이 이 기본값을 명시해야 한다.

### 5.4 왜 새 실행 지점이 아닌가

`compute-test-scope-candidates.sh`와 `run-own-tests.sh` 둘 다 이미 존재하고 이미 호출된다.
이 작업은 **기존 선택기가 이미 있는 테스트를 옳은 시점에 뽑게 만드는 것**이며, 새 러너·CI·
pre-commit·훅을 만들지 않는다.

**단 작업 B-2는 실행 표면을 넓힌다.** `run-own-tests.sh`의 헤더가 스스로 기록한 연기된
CRITICAL이 있다 — *"샌드박스는 `git worktree add --detach HEAD`일 뿐 프로세스/네트워크/uid
격리가 없어 미신뢰 대상 감사 시 ACE가 가능하다"*. python 실행에서 셸 실행으로 넓히는 것은
그 표면을 키운다. 현재 devbrew는 자기 자신만 감사하므로 실무 위험은 낮으나, **이 설계는 그
위험을 줄이지 않으며 헤더의 연기 상태를 그대로 승계한다**(§15).

### 5.5 선행 작업 — 기준선 캡처

셸 테스트가 **`/qg` 영향 선택 밖에서 전량 실행된 적이 없으므로** 몇 개가 이미 RED인지 모른다.
PR1의 첫 태스크는 수리 전 기준선을 캡처하는 것이다:

```bash
for f in $(git ls-files | grep -E '(^|/)tests?/.*\.sh$'); do
  [ -x "$f" ] || continue
  bash "$f" >/dev/null 2>&1; echo "$? $f"
done | sort -rn > baseline-sh.txt
```

이 기준선 없이는 이후 PR의 RED가 회귀인지 선재인지 가려낼 수 없다.

## 6. 작업 C — 사본 통합

### 6.1 방식

각 항목에서 **다른 부분을 밖으로 빼내** 파일 전체를 동일하게 만든다. 남는 차이는 인자·옵션·별도 파일로 이동한다.

| 대상 | 지금 갈라지는 이유 | 밖으로 빼는 것 |
|---|---|---|
| `detect_codex.sh` ×3 | kill switch 변수명 (`DEVBREW_DISABLE_QG_CODEX` / `..._SPEC_DISTILL_CODEX` / `..._PLUGIN_AUDIT_CODEX`) | 호출 인자 |
| `codex_findings_to_yaml.py` ×2 | emit keyset (`category`·`target_section` 유무) | 명령행 플래그 |
| `session-end-cleanup.py` ×2 | qg만 worktree 정리를 추가로 함 | 공통 골격을 파일로, 차이는 그 뒤 |
| `qg-gc.py` ↔ `spec-distill-gc.py` | state root 해석 방식(cwd 고정 vs git 인식) · 세션 마커 검사 · `.gc-pending-*` 청소 | 공통을 파일로. **git 인식 쪽이 정본** (worktree 호환) |
| codex 러너 2벌 | 골격은 같고 세부가 다름 | 공통 골격을 파일로 |
| `_degrade_if_empty` ×5 | 출력 스키마 4종 · 가드 3종 · 실패 처리 3종 | 위 공통 파일에 포함 |
| `kill_switch_active` ×5 | 받는 토큰 별칭 수가 다름 | 공통 파일로 |
| P21 문구 10~18곳 | 4개 빌더가 코드 안에 문자열로 박음 | `codex-prompt-preamble.md` 방식으로 |
| `discover-plan.sh` ↔ `discover-spec.sh` | 같은 발견 알고리즘을 각자 보유 | **같은 플러그인 안** → 파일 하나, 사본 없음 |

### 6.2 통합 과정에서 함께 고치는 결함

전수 대조가 드러낸 것들이다. 통합하면 어느 쪽으로든 정해야 하므로 결정을 명시한다.

| 결함 | 위치 | 결정 |
|---|---|---|
| 가드에 `-n` 검사 누락 — `OUTPUT_PATH`가 빈 문자열이면 빈 경로에 쓰기를 시도 | `run_codex_reviewer.sh:92` | 나머지 4개와 같이 `-n` 검사를 넣는다 |
| 출력 스키마 4종 (JSON / 평면 YAML 키2개 / `agent:` 포함 중첩 / `agent:` 없는 중첩) | `_degrade_if_empty` 5곳 | 중첩 YAML + `findings: []` + `meta:`로 통일. `run_artifact_codex_reviewer.sh:81`의 평면 형태가 가장 멀다 |
| kill switch 토큰 별칭 수 불일치 — spec-distill 훅은 이벤트명·훅명 둘 다 받고 project-init은 훅명만 받는다 | `kill_switch_active` 5곳 | **둘 다 받는 쪽으로 통일.** kill switch는 보안 컨트롤이며(`CLAUDE.md:48`), 한 플러그인에서 배운 형태가 다른 곳에서 조용히 안 먹는 것은 결함이다 |
| marketplace description 4/5 drift — `quality-gates`는 없어진 게이트를 광고("3-gate"), `spec-distill`은 없어진 산출물을 광고("spec.md 생성") | `marketplace.json` | `plugin.json`을 정본으로 동기화 |

### 6.3 P21 문구 — 이미 있는 방식을 넓힌다

```
지금:
  plugin-audit/scripts/codex-prompt-preamble.md        ← 파일로 존재
  plugin-audit/scripts/run_audit_codex_reviewer.sh:62  ← 읽어서 씀
  quality-gates/scripts/build_codex_prompt.py:51       ← 코드 안에 박음
  quality-gates/scripts/build_artifact_codex_prompt.py:44  ← 코드 안
  spec-distill/scripts/build_spec_codex_prompt.py:63       ← 코드 안
  spec-distill/scripts/build_brief_codex_prompt.py:51      ← 코드 안

바꾼 뒤:
  각 플러그인 scripts/codex-prompt-preamble.md   ← 바이트 동일, copy-of 표시
  빌더 4개는 그 파일을 읽는다
```

현재 이 문구의 사본은 **byte-identical한 쌍이 하나도 없다.** 태스크별 명사(`감사 계획` / `리뷰 계획` /
`비평 계획`)와 목적어가 각자 다르고, 꼬리 영문 문단의 길이도 6줄 / 5줄 / 4줄 / 3줄로 갈렸다.
통합 시 태스크별로 달라야 하는 부분은 빌더가 치환한다.

`test_codex_prompt_untrusted_clause.sh:19`가 이미 *"plugin-audit의 `codex-prompt-preamble.md`와
같은 것을 쓴다"* 고 선언하고 있다 — 계약은 있었고 실현이 없었다.

## 7. 작업 D — 규약 축소

| 축 | 지금 | 뒤 |
|---|---|---|
| 환경변수 어순 | **7패턴** + 플러그인 토큰 2표기 (`QG` / `QUALITY_GATES`가 같은 플러그인을 두 이름으로) | 1패턴 |
| 좀비 환경변수 | 5건 — README에 광고되나 코드 없음 2(`DEVBREW_DISABLE_QG_SECURITY_REVIEWER`·`DEVBREW_QG_DISABLE_RUNTIME_TEST_VALIDATION`), 정의만 있고 참조 0 3건 | 0 |
| `.claude/` state 배치 | live 4모양 + legacy 3모양. **`CLAUDE.md:47`의 규약을 실현한 플러그인이 0개** | 1모양 + 규약 문서를 코드에 맞춤 |
| severity 어휘 | 3척도 (`CRITICAL/IMPORTANT/SUGGESTION` · `block/high/medium` · `CRITICAL/HIGH/MEDIUM/LOW`) | 1척도 |
| agent `tools:` 순서 | Read/Grep/Glob 상대순서 3가지 · 표기 2종(CSV / YAML flow) | 1가지 |
| SKILL kill switch 섹션 | 헤딩 4종 + 헤딩 없음 3(굵은 산문 1 · 번호목록 1 · 부재 1) | 1종 |
| commands `allowed-tools` | 3/7 부재, 표기 2종 | 통일 |
| python 테스트 실행 | pytest 5개가 문서화된 `-m unittest` 밖 · `encoding="utf-8"` 40/58 | 통일 |

**환경변수 rename 방식**: 옛 이름 fallback을 두지 않고 즉시 rename하며 CHANGELOG의
Deprecated에 기재한다. 이 방식의 근거는 "현재 제3자 설치가 없다"는 조건이며,
`CLAUDE.md:36`(제거 전 one-minor deprecation window)과의 충돌을 그 조건 아래 수용한 것이다.
**제3자 설치가 생기면 근거가 바뀐다.**

**severity 통일의 위험**: 무손실 rename이 아니다. `synthesize_findings.py:388`이 미지 severity를
`SUGGESTION`으로 강등하므로, 매핑을 잘못 잡으면 **머지 차단 임계가 이동한다.** 매핑을
PR4에서 명시적으로 결정하고 그 매핑 자체에 락을 건다.

## 8. 작업 E — SKILL 분할

분할 기준은 크기가 아니라 **조건부로만 필요한가**이다. 항상 함께 필요한 것을 쪼개면
파일만 늘고 읽는 양은 같다.

SKILL 8개 전부에 이 기준을 적용한 결과 대상은 둘이다.

| 대상 | 섹션 줄 | 파일 내 비중 | 조건 |
|---|---:|---:|---|
| `quality-pipeline/SKILL.md` `## Runtime gate` | 1,190 | 58% | Runtime 게이트를 실제로 돌 때만 필요 (`/qg review`면 불필요) |
| `conducting-interview/SKILL.md` `## 종료 — brief 작성 + optional handoff` | 233 | 38% | 인터뷰 종료 시에만 필요 |

**분할하지 않는 것과 이유**: `reviewing-brief ## 2단계`(31%) · `reviewing-spec ## Steps`(48%) ·
`critiquing-artifacts ## 루프`(46%) · `auditing-plugins ## pre-1`(40%) ·
`briefing-current-state ## 할 일`(51%) — 전부 그 skill의 본체이며 항상 함께 필요하다.

**대가**: `quality-pipeline`을 앵커로 잡는 테스트가 26파일이다. 같은 조작이 같은 파일에서
이미 락 하나의 이빨을 없앤 선례가 있다(`test_skill_codex_skip_prose.sh` — 프로즈가 사라져
AC19~AC21이 무력화). 그래서 이 작업은 PR5로 격리하고, 분할 전후 앵커를 전수 대조한다.

**효과**: 모델이 읽는 표면 6,562 → 5,139줄 (−22%).

## 9. 작업 F — 테스트 공유 lib

셸 테스트 149개 중 **130개가 자체 판정 헬퍼를 정의**하고 공유 lib를 source하는 것은 7개뿐이다.
헬퍼 이름은 50종, 본문은 91변형이다.

같은 이름이 다른 뜻인 실증: `field()`가 6곳에서 정의되며 구현이 3종(awk 2종 · sed 1종)이고
**인자 순서까지 다르다** — `test_resolve_baseline.sh:14`는 `field <key> <text>`,
`test_qg_mutation_guard.sh:23`은 `field <text> <key>`.

### 9.1 위치 — `shared/tests/`

테스트는 리포에서만 도므로 **사본조차 필요 없다.** 각 테스트가 `shared/tests/assert.sh`를
직접 source한다.

`plugins/quality-gates/tests/lib/`를 쓰지 않는 이유는 소유 관계다 — 판정 헬퍼는 어느 한
플러그인의 것이 아니다. 지금 `plugins/spec-distill/tests/test_web_kill_switch.sh:73`이
quality-gates의 lib를 source하고 있는 것이 그 왜곡의 실증이다.

리포 루트 `.gitignore:17`의 `lib/` 규칙이 `tests/lib/` 하위를 조용히 untracked로 만들며
`quality-gates`만 `:20-21`의 negation으로 구제돼 있다. 이 사실은
`plugins/spec-distill/tests/arm_test_helpers.sh:15-16`에 기록돼 있다. `shared/tests/`는
`lib/` 규칙에 걸리지 않으므로 negation을 하나 더 추가하지 않는다.

### 9.2 C10 — 락 순감 금지의 검증

헬퍼 통일은 곧 의미 변경이다. 일부 헬퍼는 실패 시 `exit`하고 일부는 계속한다.
"assertion을 줄이지 않는다"는 제약은 검증 방법이 있어야 제약이다.

**검증**: 통합 전후로 각 테스트 파일의 assertion 호출 수를 세어 대조한다. 파일별로
통합 후 호출 수가 통합 전보다 적으면 그 파일은 완료되지 않은 것이다. 이 대조를 PR3의
완료 조건에 넣는다.

## 10. 작업 G — /compact 게이트 통일

`/compact`를 언급하는 살아 있는 표면은 10파일이다. 그중 **골격이 같은데 독립 저술된 것은
proceed 게이트 2벌뿐**이다.

| 대상 | 위치 |
|---|---|
| 인터뷰 종료 게이트 | `conducting-interview/SKILL.md` Step B |
| spec 리뷰 종료 게이트 | `reviewing-spec/SKILL.md` Phase 5 |

`conducting-interview/SKILL.md:430`이 스스로 두 벌의 관계를 *"대칭 … 독립 저술"* 이라 기록한다.
공통 골격은 `/compact <종류> at <경로> 보존 — <유지목록> 유지하고 <drop목록> drop. 다음 단계: Skill <스킬>` 이다.

**통일하지 않는 것**: `publishing-pr-understanding/SKILL.md:206-209`(compact 후 session-id 갈림
주의)는 리포에 1건뿐이라 통일할 짝이 없다. `spec-template.md:23`과 `spec-reviewer.md:97`은
2건이지만 서로 다른 것을 말한다.

**hook 구현은 배제한다.** `PreCompact`는 리포 전체에 바인딩 0개이므로 새 훅을 다는 것이
곧 실행 지점 신설이다. spec-distill v0.11.0이 `hooks/compact-induction.py`를 폐기한 사유는
"hook은 AskUserQuestion을 띄울 수 없음"이었고, 그 사유와 별개로 실행 지점 제약이 이 안을 막는다.

## 11. 작업 H — 폴더 구조와 `shared/`

측정으로 도출된 세 건이다. 파일 크기 규칙은 만들지 않는다.

### 11.1 테스트 위치를 하나로

```
지금:
  plugin-audit/scripts/tests/     (파이썬 21)
  project-init/tests/             (셸 1)
  project-init/hooks/tests/       (파이썬 3)      ← 같은 플러그인에 두 곳
  quality-gates/tests/            (파이썬 18 · 셸 97)
  spec-distill/tests/             (파이썬 10 · 셸 49)
  agent-transparency/tests/       (파이썬 5)

뒤:
  plugins/<모든 플러그인>/tests/
```

이것이 §5.1의 `break` 버그가 발현할 조건을 없앤다. 후보 디렉토리가 하나면 `break`는 무해하다.
버그를 고치는 것(작업 B)과 버그가 발현할 조건을 없애는 것(작업 H)을 **둘 다** 한다 —
미래에 누가 다시 `scripts/tests/`를 만들면 고친 코드만 남기 때문이다.

**재앵커 주의**: 이관 대상 테스트는 `REPO = Path(__file__).resolve().parents[N]` 형태로
경로를 도출한다. 디렉토리 깊이가 바뀌면 `N`도 바뀐다.

### 11.2 라이브러리를 제자리로

```
spec-distill/hooks/state_path.py   →   spec-distill/scripts/state_path.py
```

`plugins/*/hooks/*.py` 11개 중 이 파일만 `hooks.json` 등록이 0이고, 6곳에서 라이브러리로 불린다.
나머지 10개는 전부 등록된 훅이다.

### 11.3 손대지 않는 것

플러그인마다 `hooks/`·`templates/`·`output-styles/`의 유무가 다른 것은 필요한 것이 달라서이며
드리프트가 아니다. `agent-transparency`가 훅 0개인 것은 라이브 probe 결과에 따른 설계 결정으로
`README.md:45-58`에 기록돼 있다.

`scripts/` 하위 분류도 이번에는 하지 않는다. `quality-gates/scripts/`는 46개 파일이 평평하고
군집(codex 7 · artifact 6 · 테스트선택 6 · publish 5 · 세션/GC 4 · 검사 6)이 실재하지만,
`scripts/<파일>` 형태의 **살아 있는 참조가 348건**(테스트 209 · skill 101 · 코드 38)이고
그중 skill 참조 101건이 작업 E와 같은 파일 표면을 흔든다. §16에 다음 사이클 후보로 기록한다.

`src/` 구조는 채택하지 않는다. 플러그인에는 빌드 단계가 없어 "빌드 전 소스"라는 의미가 성립하지
않고, 상위 폴더 이름은 Claude Code 플러그인 규격이 정한다.

### 11.4 `shared/` — 통합의 자리

```
shared/
  codex/detect_codex.sh                 정본
  codex/codex_findings_to_yaml.py       정본
  codex/runner_common.sh                정본 (_degrade_if_empty 포함)
  codex/prompt-preamble.md              정본 (P21)
  killswitch/kill_switch_active.py      정본
  gc/gc_common.py                       정본
  tests/assert.sh                       테스트 헬퍼 — 사본 없이 직접 source
```

배포되는 사본은 `plugins/*/scripts/` 아래에 두고 `copy-of`로 정본을 가리킨다(§12).
`shared/`는 설치본에 들어가지 않으므로 플러그인 크기에 영향이 없고, **사본이 정본과 바이트가
같으므로 사본을 검증하는 테스트가 곧 정본을 검증한다** — 실행되지 않는 정본이 방치되는 문제가 없다.

리포 루트에 새 최상위 폴더가 하나 생긴다. 이것이 `CLAUDE.md`가 금지하는 "새 규약 문서"가
아니라는 근거는 C14다 — 공유 lib는 명시적으로 허용된다.

## 12. 락 — `copy-of` 계약과 20줄 검사

장치는 둘이고 서로 다른 것을 지킨다.

| 락 | 무엇을 지키나 | 어느 파일 | 무엇이 언제 돌리나 |
|---|---|---|---|
| **`copy-of` 동일성** (§12.1) | 이미 통합한 것의 재분열 | `plugins/quality-gates/tests/test_copy_of_contract.sh` | `/qg` Runtime gate — 작업 B-1의 `.sh`·`.md` 매핑이 붙으면 **사본이나 정본이 바뀔 때** 선택된다. 그리고 `/plugin-audit quality-gates`가 작업 B-2 이후 직접 돌린다 |
| **20줄 블록 검사** (§12.7) | 새 중복 유입 | `plugins/quality-gates/tests/test_no_new_duplication.sh` | 같음 |

**이것이 brief OQ1("잔여 락을 무엇이 돌리는가")의 답이다.** 실행 지점을 새로 만들지 않는다 —
두 락은 셸 테스트이고, 이 리포에는 셸 테스트를 돌리는 지점이 이미 둘 있다(§1.4).

**정직한 한계**: 두 지점 모두 **사용자가 명령을 칠 때** 돈다(`/qg`, `/plugin-audit`). 상시 자동
실행되는 것이 아니다. C16이 실행 지점 신설을 금했으므로 이것이 이 제약 아래의 최선이며,
§17의 "기계적으로 강제된다"는 *"그 명령이 돌 때 기계적으로 판정된다"*로 읽어야 한다.

**§14의 census 스크립트와 무엇이 다른가**: 락은 **테스트 파일**이라 기존 러너가 발견·실행한다.
반면 census 스크립트는 러너가 발견하지 못하는 독립 도구라 누군가 따로 불러야 하고, 그 "따로
부르는 자리"가 곧 새 실행 지점이 된다. 그래서 락은 상주시키고 census는 상주시키지 않는다.

### 12.1 계약 — 기계가 읽을 수 있는 규격

**마커 정규식**

```
^[[:space:]]*(#|//|<!--)[[:space:]]*copy-of:[[:space:]]*(?P<path>\S+)
```

**허용 위치** — 파일의 **처음 5줄 안**. shebang(`#!`)·인코딩 선언(`# -*- coding:`)·
`from __future__ import`보다 뒤여야 하며, 그 셋 외의 코드보다는 앞이어야 한다. 5줄로 정한 이유는
이 세 전치 요소의 최대 조합이 3줄이고 빈 줄 하나를 허용해도 4줄이기 때문이다.

**파일 종류별 주석 문법**

| 종류 | 마커 |
|---|---|
| `.sh` · `.py` | `# copy-of: <경로>` |
| `.js` · `.mjs` | `// copy-of: <경로>` |
| `.md` | `<!-- copy-of: <경로> -->` |

**`.md` 정본의 마커 누출 문제.** `codex-prompt-preamble.md`는 프롬프트 본문으로 읽히므로
마커가 모델에게 그대로 전달되면 안 된다. 두 조치를 함께 한다 — HTML 주석이라 마크다운 렌더에
안 보이고, **그 파일을 읽는 빌더가 첫 5줄의 마커 줄을 제거한 뒤 프롬프트에 넣는다**(현재
`run_audit_codex_reviewer.sh:62`가 파일을 통째로 읽으므로 이 stripping을 추가해야 한다).

**락은 이 한 문장이다:**

> `copy-of` 줄이 있는 파일은, 그 줄이 가리키는 파일과 그 줄만 제외하고 바이트가 같아야 한다.

**비교 대상 정규화**: 마커 줄만 양쪽에서 제거하고 나머지는 바이트 그대로 비교한다.
줄 끝 공백·개행 코드도 포함한다.

**부수 조건 셋**: 정본은 `copy-of` 줄을 갖지 않는다(순환 금지) · `copy-of`가 가리키는 경로는
존재해야 한다 · 정본은 `shared/` 아래여야 한다(정본 위치를 구조로 고정).

### 12.2 재지 않는 것

두 락 모두 아래를 재지 않는다.

- 파일의 줄 수
- 파일·폴더의 개수
- 폴더의 모양
- 함수를 몇 개로 쪼갰는지
- **유사도 퍼센트** — §12.7은 "얼마나 비슷한가"가 아니라 "완전히 같은 구간이 얼마나 긴가"를 본다

모듈화는 보안도 정확성도 아닌 판단의 영역이므로 결정론 게이트를 걸지 않는다.
크기와 책임 경계는 `/qg` Review gate와 `plugin-audit` 6축 감사가 본다 — 둘 다 모델 판단이다.

§12.7의 창 크기 20은 조정 가능한 값이므로 손잡이다. 그 손잡이가 당겨지지 않는 근거는 §12.7에 있다.

### 12.3 왜 `copy-of` 형태인가

| 앞선 안 | 왜 버렸나 |
|---|---|
| 갈라진 사본 **개수** ≤ N | 임계값이 손잡이가 된다. 그리고 개수 강제다 |
| 같은 **이름**이면 같은 내용 | 이름을 바꾸면 통과한다. 완전 사본이 이름만 다르면 자유통과 — 락이 거꾸로 작동한다. 그리고 이름이 다른 중복(`qg-gc.py` ↔ `spec-distill-gc.py` 등)을 절반 이상 놓친다 |

`copy-of`는 **찾아내지 않고 약속을 지킨다.** 앵커가 파일 이름이 아니라 파일 안의 표시이므로
이름을 바꾸거나 파일을 옮겨도 따라간다. 찾아내는 일은 §12.7이 맡는다 — 역할이 나뉘어 있어
각 락이 자기가 잘하는 것만 한다.

### 12.4 커버 범위 — 지금 있는 중복

정본은 전부 `shared/` 아래에 둔다(§11.4). 아래 표의 `copy-of`는 그 정본을 가리킨다는 뜻이다.

**커버는 두 등급이다.** 파일 전체가 동일해지는 것과, 공통 조각만 빠지고 **잔여가 남는** 것은
보호 수준이 다르다. 앞선 판본은 둘을 한 열에 적어 커버리지를 과대 표시했다.

#### ① 파일 전체가 동일 — `copy-of`가 완전 커버

| 중복 | 어떻게 |
|---|---|
| `detect_codex.sh` ×3 | 차이가 kill switch 변수명 한 줄뿐 → 인자로 빼면 바이트 동일 |
| `codex_findings_to_yaml.py` ×2 | 차이가 emit keyset 한 곳뿐 → 플래그로 빼면 바이트 동일 |
| P21 문구 | `shared/codex/prompt-preamble.md` 하나를 각 플러그인에 동일 사본으로 |
| `kill_switch_active` | `shared/killswitch/` 파일 하나를 동일 사본으로. 플러그인별 토큰은 **인자** |
| `_degrade_if_empty` | `shared/codex/runner_common.sh`에 포함, 동일 사본 |

#### ② 공통 조각만 추출 — 잔여는 `copy-of` 밖

| 중복 | 왜 바이트 동일이 불가능한가 | 잔여의 보호 |
|---|---|---|
| `session-end-cleanup.py` ×2 | 각자 자기 kill switch 토큰(`spec-distill:SessionEnd` vs `quality-gates:...`)과 `sys.path.insert` + `from state_path import`를 본문에 갖는다. qg는 worktree 정리까지 한다 | **20줄 검사**(§12.7)가 잔여 중복을 잡는다 |
| `qg-gc.py` ↔ `spec-distill-gc.py` | state root 해석 방식이 다르고(cwd 고정 vs git 인식) 세션 마커 검사·`.gc-pending-*` 청소가 한쪽에만 있다 | 같음 |
| codex 러너 2벌 | 각자 다른 프롬프트 빌더·산출 스키마를 부른다 | 같음 |

②의 잔여가 **무보호가 아닌 이유**는 §12.7이 코퍼스 전체를 훑기 때문이다 — 추출 후에도 20줄
이상 겹치는 구간이 남으면 RED가 되어 추가 추출을 요구한다. 다만 20줄 미만의 잔여는 남는다(§15).

#### ③ 중복 자체가 소멸 — 락 불필요

| 중복 | 어떻게 |
|---|---|
| `discover-plan.sh` ↔ `discover-spec.sh` | 같은 플러그인 안 → 파일 하나를 source |
| 판정 헬퍼 130곳 · frontmatter 검사 3종 · artifact 2종 | 리포에서만 돌므로 `shared/tests/`를 직접 source |

#### ④ 별도 장치

| 중복 | 장치 |
|---|---|
| `marketplace.json` ↔ `plugin.json` description | `check-staleness.py:393-413`의 기존 검사 (작업 B-2가 되살림) |
| `docs/git-workflow` ↔ `templates` | 템플릿-인스턴스. 치환 표식(`{{...}}`)과 의도된 차이 1곳(`branch-strategy.md:63`)을 제외한 동일성 검사 |

### 12.5 이빨 증명 — `copy-of`

락이 통과하는 것은 이빨의 증거가 아니다. mutation 3종으로 증명한다.

| # | 변이 | 기대 |
|---|---|---|
| 1 | 사본 하나의 본문 한 줄을 바꾼다 | RED |
| 2 | 사본 하나의 파일 이름을 바꾼다 (`copy-of`는 그대로) | **여전히 GREEN** — 이름 무관을 증명 |
| 3 | `copy-of`가 존재하지 않는 경로를 가리키게 한다 | RED |

변이는 맨 앞·중간·맨 끝 세 위치에서 각각 수행한다.

### 12.6 왜 `copy-of` 만으로는 부족한가

`copy-of` 줄 없이 **새로** 만들어지는 중복은 이 락이 모른다. 그래서 §12.7이 필요하다.

### 12.7 20줄 블록 검사 — 새 중복 유입

> **20줄 이상 완전히 같은 블록이 2개 이상 파일에 있는데, 그 파일들이 `copy-of` 관계로
> 설명되지 않으면 RED.**

#### 스캔 코퍼스와 제외 (규격)

| 항목 | 값 |
|---|---|
| 코퍼스 | `git ls-files` 중 `plugins/**` — **399파일** |
| 제외 | `*/fixtures/*` · `*/mocks/*` (의도적으로 같은 입력을 담는 곳) |
| 정규화 | 공백만인 줄 제거. 그 외 바이트 그대로 |
| 최소 블록 크기 | 200자 (짧은 줄 20개가 우연히 겹치는 것을 배제) |
| 창 | 20줄 |
| 면제 | 두 파일이 `copy-of` 관계(한쪽이 다른 쪽을 가리킴)이면 그 쌍의 블록은 세지 않는다 |

**`docs/`는 코퍼스에 없다.** 작업 A가 `docs/archive/`로 39,904줄을 들여와도 이 락은 반응하지
않는다 — 검사 대상이 배포되는 코드이기 때문이다. 이 제외가 없으면 락이 도입 즉시 아카이브
때문에 대량 RED가 된다.

#### 창 크기 20의 근거 — 임의값이 아니다

위 파라미터를 고정하고 창만 바꿔 전수로 셌다.

| 창(줄) | 블록 수 | 관련 파일 수 |
|---:|---:|---:|
| 5 | 153 | 51 |
| 10 | 240 | 40 |
| 15 | 140 | 28 |
| **20** | **91** | **9** |
| 25 | 71 | 9 |
| 30 | 56 | 5 |

(창 5줄이 10줄보다 블록이 적은 것은 200자 하한 때문이다 — 짧은 줄 5개는 200자에 못 미친다.)

**20에서 관련 파일이 28 → 9로 급락하고 25까지 9로 유지된다.** 그 9개가 무엇인지 전수로 확인했다:

| 블록 | 파일 | 정체 |
|---:|---|---|
| 39 | `detect_codex.sh` ×3 | 진짜 사본 |
| 20 | `detect_codex.sh` (qg ↔ plugin-audit 쌍) | 같음 |
| 17 | `codex_findings_to_yaml.py` ×2 | 진짜 사본 |
| 8 | `pending-review-reminder.py` ↔ `review-dispatch.py` | 진짜 사본 (같은 플러그인 안) |
| 7 | `test_adversarial_persona.sh` ↔ `test_security_reviewer_persona.sh` | 진짜 사본 |

**오탐이 0이다.** shebang·import·`set -u` 같은 보일러플레이트가 전부 걸러진다.

#### 뜨면 어디로 가는지가 명확하다

기계적 검사가 억울하지 않으려면 해소 경로가 있어야 한다. `shared/`가 그 자리다.

| 상황 | 해소 |
|---|---|
| 같은 플러그인 안 | 파일 하나로 합친다 |
| 플러그인 사이 | `shared/`에 정본, 사본에 `copy-of` |
| 테스트끼리 | `shared/tests/`에서 source |

#### 임계값에 대해 정직하게

20은 손잡이다 — 낮추면 엄격, 높이면 느슨. 두 가지가 완화한다. **20에서 오탐이 0**이므로
낮출 이유가 없어 완화 압력이 생기지 않고, 값을 바꾸면 diff에 한 줄로 드러난다.

#### 이빨 증명 — 20줄 검사

| # | 변이 | 기대 |
|---|---|---|
| 1 | 20줄짜리 동일 블록을 두 파일에 새로 넣는다 (`copy-of` 없이) | RED |
| 2 | 같은 블록을 19줄로 줄인다 | GREEN — 창 경계가 실제로 20인지 확인 |
| 3 | `copy-of`로 설명된 사본 쌍을 그대로 둔다 | GREEN — 설명된 것은 통과함을 확인 |
| 4 | `copy-of` 줄을 지운다 | RED — 설명이 사라지면 잡힘 |

변이 2·3이 없으면 이 검사가 무엇이든 RED로 만드는 것과 구분되지 않는다.

## 13. 실행 순서 · PR 분할

| PR | 내용 | 왜 이 자리 |
|---|---|---|
| **1** | 기준선 캡처 + 영향 매핑 수리 (B) | 이것이 없으면 이후 모든 락이 대상 변경 시 안 돈다. 셸 테스트가 전량 실행된 적이 없으므로 선재 RED를 먼저 확정해야 한다 |
| **2** | 아카이브 이동 (A) | 독립적. 참조 31+96건 스윕 |
| **3** | `shared/` 신설 + 사본 통합 (C) + 테스트 공유 lib (F) + 폴더 구조 (H) | 본체. PR1의 락이 여기서 일한다. H가 러너 버그의 원인을 없앤다 |
| **4** | 규약 축소 (D) | C가 끝나야 규약이 한곳에 모인다 |
| **5** | SKILL 분할 (E) + `/compact` 통일 (G) | 앵커 26파일 — 가장 위험해서 마지막 |
| **6** | `copy-of` 락 + 20줄 검사 + mutation 증명 (§12) | 최종 형태가 나와야 표시를 달고 임계를 박을 수 있다 |

각 PR마다 건드린 플러그인의 `plugin.json` 버전을 같은 커밋에서 bump한다.
bump하지 않으면 설치 캐시 키가 조용히 stale이 된다.

## 14. 검증 · 완료 측정

| 축 | 지금 | 목표 | 재는 법 |
|---|---:|---|---|
| 정본 트리 줄 수 (아카이브 제외) | 143,584 | **−57,887** | `git ls-files \| grep -v '^docs/archive/' \| xargs wc -l`. 내역: audits 3,362 + plans 39,904 + specs 완료분 12,640 + interview 완료분 1,981. **이번 사이클 산출물은 제자리**(이 설계 915줄이 specs에, brief 2개 649줄이 interview에) — 그래서 각 폴더 총계가 아니라 완료분만 센다 |
| **on-demand 로드 표면** (skill+agent+command) | 6,482 | **5,059 (−22%)** | 지표 이름 정정: 매 세션 자동 로드되는 것은 `CLAUDE.md` 80줄뿐이고 나머지는 호출될 때 읽힌다. 그래서 "매번 읽는"이 아니라 "**한 번 읽힐 때 읽는 양**"이다 |
| 크로스-플러그인 락이 **대상 변경 시** 선택됨 | **0 / 7** | 7 / 7 | 각 락의 `# guards:` 글롭에 걸리는 파일을 하나 수정하고 `compute-test-scope-candidates.sh` 출력에 그 락이 나오는지 확인 |
| `/plugin-audit`에서 도는 셸 테스트 | 0 | 대상 플러그인 전량 | `run-own-tests.sh` 출력 |
| `/plugin-audit project-init`의 수집 수 | **0 (ran=true 오보)** | 파이썬 3 + 셸 1 | 같음 |
| 갈라진 사본 (진짜 + 부분) | 5군 | 0 |
| `marketplace.json` description drift | 4 / 5 | 0 |
| 환경변수 어순 패턴 | 7 (+ 플러그인 토큰 2표기) | 1 |
| 좀비 환경변수 | 5 | 0 |
| 테스트 위치 규약 | 3 | 1 |
| `hooks/`에 있는 비-훅 파일 | 1 | 0 | `plugins/*/hooks/*.py` 중 `hooks.json` 미등록 수 |
| 20줄 동일 블록 (`copy-of` 미설명) | **91블록 / 9파일** | 0 | §12.7 락 자신 |
| 파일별 assertion 호출 수 (C10) | 기준선 | 어느 파일도 감소하지 않음 | 통합 전후 각 테스트 파일의 판정 헬퍼 호출 수 대조 |

**작업 D의 8축 — 각각의 판정 기준** (앞선 판본은 2축만 있어 나머지를 "했는지" 판정할 수 없었다)

| 축 | 지금 | 목표 | 재는 법 |
|---|---|---|---|
| env 어순 | 7패턴 + 토큰 2표기 | 1패턴 | `git grep -oh 'DEVBREW_[A-Z_]*' \| sort -u`를 어순별로 분류 |
| 좀비 env var | 5 | 0 | README·CHANGELOG에만 있고 실행 코드에 없는 것 수 |
| `.claude/` state 배치 | live 4모양 | **1모양** | `.claude/<plugin>/<session-id>/<file>`(S1)로 통일. `CLAUDE.md:47`이 규정한 `.claude/<plugin>.local.md`(S5)는 **qg에서 legacy 삭제 대상**이므로 규약 문서를 코드에 맞춘다 |
| severity 어휘 | 3척도 | 1척도 | `CRITICAL/IMPORTANT/SUGGESTION`으로. 매핑은 §7 위험 항목 참조 |
| agent `tools:` 순서 | 상대순서 3 · 표기 2 | 1 · 1 | 18개 agent의 `tools:` 라인 distinct 수 |
| SKILL kill switch 섹션 | 헤딩 4종 + 헤딩 없음 3 | `## kill switch` 1종, 8/8 보유 | `grep -c '^## kill switch'` per SKILL |
| commands `allowed-tools` | 3/7 부재 · 표기 2종 | 7/7 · 1종 | frontmatter 검사 |
| python 테스트 실행 | pytest 5개가 `-m unittest` 밖 · `encoding="utf-8"` 40/58 | 전량 통일 | 러너 수집 결과 · `grep -c 'encoding="utf-8"'` |

측정 도구는 이번 조사에 쓴 census 스크립트를 before/after 자로만 쓴다. 리포에 상주시키지 않는다 —
상주하면 실행 시점이 필요해지고 그것이 곧 실행 지점 신설이다. 상시 강제는 `copy-of` 락이 맡는다.

## 15. 위험

| 위험 | 완화 | 잔여 |
|---|---|---|
| **계측기와 피검체를 같은 사이클에 바꾼다** — PR3가 테스트 헬퍼를 통합하면 회귀를 잡을 그물이 동시에 다시 짜인다 | §9.2의 assertion 수 대조 + PR1의 기준선 | 완전 해소 아님 |
| **SKILL 분할이 앵커 26개를 흔든다** — 같은 조작이 같은 파일에서 이미 락 하나의 이빨을 없앤 선례 | PR5로 격리 + 분할 전후 앵커 전수 대조 | 앵커가 프로즈를 가리키면 대조가 어렵다 |
| **severity 통일이 머지 차단 임계를 이동시킨다** | PR4에서 매핑을 명시 결정 + 매핑에 락 | 매핑 자체가 판단이다 |
| **`docs/audits` 이동이 게이트 둘을 죽인다** | PR2에서 동반 수정. `validate-audit-data.py:147`이 fail-closed로 즉시 알린다 | 역사 참조 96건의 누락은 즉시 발현하지 않는다 |
| **선재 RED 수 미상** — 셸 149개가 실행된 적이 없다 | PR1의 첫 태스크가 기준선 캡처 | 캡처 결과가 크면 PR1이 커진다 |
| **테스트 이관 시 `parents[N]` 재앵커** | §11.1에 명시 | 깊이 변화에 self-correct하는 패턴도 있어 케이스별 확인이 필요하다 |
| **아카이브 재성장** — 사이클당 산출물 4개를 만드는 파이프라인에 제동이 없다. 선행 사이클(2026-07-09) 이후 38일간 약 1,400줄/일로 재성장했다 | 없음 | **미해소.** 이번 사이클은 이동만 한다. §15.1에 기록 |
| **20줄 미만의 새 중복** — 검사 창 아래로 들어오는 중복 | 없음 | 창을 낮추면 오탐이 들어온다(15줄에서 파일 28개). 리뷰가 본다 |
| **작업 B-2가 ACE 표면을 넓힌다** — `run-own-tests.sh` 헤더가 스스로 기록한 연기된 CRITICAL(샌드박스는 git worktree일 뿐 프로세스/네트워크/uid 격리 없음)의 실행 대상을 python에서 셸로 확장한다 | 없음 — 이 설계는 그 격리를 개선하지 않는다 | **승계.** 현재 devbrew가 자기 자신만 감사하므로 실무 위험은 낮으나, 미신뢰 플러그인을 감사하게 되면 이 확장이 위험을 키운다. §15.1에 기록 |
| **락 둘 다 사용자 명령에 의존** — `/qg`·`/plugin-audit`을 안 치면 안 돈다 | C16이 실행 지점 신설을 금함 | **미해소.** §12의 "기계적 강제"는 그 명령이 돌 때에 한한다 |

### 15.1 이번 사이클이 남기는 것 — 모아만 둔다

원장(파일·메커니즘)은 만들지 않는다(C11 유지). 다음 사이클이 이 목록을 원장으로 만든다.
**흩어진 위치를 여기 한곳에 적는 것이 이번 사이클의 기여다** — 그중 하나는 git 밖이라
다른 세션이 찾지 못한다.

| 출처 | 남은 것 | 확인 |
|---|---|---|
| `docs/audits/2026-08-13-codex-unification-branch-review.md` §2·§3 | IMPORTANT 11 (17건 중 6건만 §8에서 닫힘) + SUGGESTION 32. §5에 수정 순서 제약·grep 함정 | 리포 |
| `docs/audits/2026-07-28-agent-tools-lock-value-path-gaps.md` | Law 2 락 값 경로 선행 결함 4건 — README 인덱스에 "기록 전용, 미수정" | 리포 |
| `docs/audits/2026-08-02-harness-capability-suppression-census.md` | 억제 census 110 + 14 findings | 리포 |
| **`~/.claude/qg-reports/2026-08-15-agent-transparency-branch-review/`** | IMPORTANT 8 + SUGGESTION 23 + A/B 게이트 실측 실행 | **git 밖** — 디렉토리 실재만 확인 |
| 억제 sweep (PR #112 이후) | 라운드3 IMPORTANT 11 + SUGGESTION 20 · 설계 §11 별건 7행 fail-open | 세션 기록 |
| plugin-audit (PR #106 이후) | adversarial-input 3종 · 수동 GC8 · e2e | 세션 기록 |
| qg empty-scope guard | Option 1까지 설계 합의, 사용자 판단으로 연기 | 세션 기록 |
| spec-distill 다수 PR | e2e 수동 검증 다수 | 세션 기록 |
| **이번 사이클** | 아카이브 내부 해소·제거 · 스크립트 17개 분할(PR1 기준선 확정 후) · `scripts/` 하위 분류 · 아카이브 재성장 제동 · `run-own-tests.sh` 격리 CRITICAL | 이 문서 |
| **환경변수 즉시 rename** — fallback 없음 | 근거가 "현재 제3자 설치 없음"이라는 조건 | 제3자 설치가 생기면 근거가 무너진다 |
| **심볼릭 링크 제약이 이 리포에서 실측되지 않았다** | A안이 심볼릭 링크에 의존하지 않는다 | 문서와 외부 사례에만 근거한다 |

## 16. 기각한 대안

| 대안 | 기각 사유 |
|---|---|
| **심볼릭 링크로 전부 물리 통합** | `--plugin-dir` 설치에서 skip된다. devbrew의 자기 검증 경로가 그 모드이므로, 회귀를 잡을 그물을 먼저 끊는 셈이다 |
| **생성기로 사본을 만들어 커밋** | 생성기를 언제 돌릴지가 곧 실행 지점 신설이다 |
| **플러그인 병합** — codex 사본 3벌이 존재하는 이유가 codex를 부르는 플러그인이 3개라서이므로 병합하면 사본이 구조적으로 사라진다 | 세 플러그인의 책임이 다르다. 이번 요청은 무게 감축이지 제품 재편이 아니다 |
| **통합 없이 락만 강화** | 지금 상태가 그것이며 이미 4건이 drift했다 — 반증된 안이다 |
| **스크립트 17개(300줄 초과) 분할 — 이번 사이클** | 실측 셋이 막는다. ① **PR3(사본 통합) 대상과 교집합이 0이다** — PR3가 건드리는 파일은 최대 245줄로 전부 300줄 미만이라 "통합하면서 같이 쪼갠다"가 성립하지 않는다. ② 셸 테스트 149개가 한 번도 안 돌아 **선재 RED 수를 모르므로**, 쪼갠 뒤의 RED가 회귀인지 선재인지 가릴 수 없다. ③ 하위 폴더로 옮기면 살아 있는 경로 참조 348건을 고쳐야 하고 그중 skill 101건이 작업 E와 같은 표면을 흔든다. **PR1이 기준선을 확정한 뒤 별도 사이클로 한다** — §15.1에 기록 |
| **`scripts/` 하위 분류** | 위와 같은 348건 참조 문제. 군집은 실재하므로 다음 사이클 후보로 §15.1에 기록 |
| **`src/` 구조** | 플러그인에 빌드 단계가 없어 의미가 성립하지 않고, 상위 폴더 이름은 플랫폼 규격이 정한다 |
| **크기·개수 래칫** | 임계값이 손잡이가 된다. 그리고 줄 수 압력은 책임 분리로도, 코드를 빽빽하게 쓰기로도 해소되며 후자가 더 싸다 — 락이 가독성을 깎는 쪽에 상을 준다 |
| **"같은 이름이면 같은 내용" 락** | 이름을 바꾸면 통과한다. 완전 사본이 이름만 다르면 자유통과하므로 락이 거꾸로 작동하고, 이름이 다른 중복(`qg-gc.py` ↔ `spec-distill-gc.py` 등)을 절반 이상 놓친다 |
| **정본을 사본 중 하나로 삼기** | 소유 관계가 왜곡된다. `shared/`가 중립 위치다(§11.4) |
| **마켓플레이스 클론을 상대경로로 도달** — `${CLAUDE_PLUGIN_ROOT}/../../../../marketplaces/devbrew/shared/`. 실측하면 `~/.claude/plugins/marketplaces/devbrew/`에 `docs/`·`plugins/`를 포함한 리포 전체 클론이 있으므로 경로상 도달은 가능하다 | **리비전이 어긋난다.** 실측: 클론은 `main` `b28b88e`, 캐시는 플러그인별 버전(qg 4개·sd 5개 공존). 런타임이 읽는 `shared/`가 지금 도는 플러그인과 다른 리비전일 수 있고, 그 어긋남을 감지할 방법이 없다. 게다가 `--plugin-dir` 모드에서는 이 경로가 존재하지 않는다. 사본+`copy-of`는 리비전이 정의상 일치한다(같은 커밋에 함께 있다) |
| **`docs/git-workflow`와 `templates` 통합** | 사본이 아니라 템플릿-인스턴스다. 치환 표식이 원본 쪽에 있다 |
| **CI 또는 pre-commit 도입** | 실행 지점 신설이다 |

## 17. 목표 대조표

| 목표 | 반영 |
|---|---|
| 요청 1행 — 전역 모듈화 | C(사본을 모듈로) · E(SKILL 분할) · H(폴더 구조) |
| 요청 2행 앞절 — 기존부분 모듈화 | 같음 |
| 요청 2행 뒷절 — 원장에 추가 | **범위 밖 (C11 유지).** 원장 파일·메커니즘을 만들지 않는다. 다만 흩어진 미해결 항목을 §15.1에 **모아만** 둔다 — 다음 사이클이 그것을 원장으로 만든다 |
| 요청 3행 — 중복 통합 + stale 방지 | C + §12 락 둘 |
| 요청 4행 — `/compact` 점검·통일 | G (점검은 전수 완료, 통일은 게이트 2벌) |
| Goal 1 — 아카이브 | A |
| Goal 2 — 모델이 읽는 표면 축소 | E (6,562 → 5,139) |
| Goal 3 — 같은 책임의 사본 통합 + stale 방지 | C + §12 |
| Goal 4 — 규약 가짓수 축소 | D + H |
| Goal 5 — `/compact` 통일 | G |
| Goal 6 — 테스트 공유 lib | F (`shared/tests/`) |
| Goal 7 — 다시 무거워지지 않게 | §12 락 둘 — `copy-of`가 재분열을, 20줄 검사가 새 중복 유입을 막는다 |

**Goal 7은 중복에 한해 기계적으로 판정된다.** 세 가지 한정을 함께 읽어야 한다.

1. **강제 대상은 중복뿐이다.** 파일 크기·개수·폴더 모양·책임 경계는 재지 않는다 — 판단의
   영역이므로 `/qg` Review gate와 `plugin-audit` 6축 감사가 본다.
2. **"상시"가 아니다.** 두 락은 `/qg` 또는 `/plugin-audit`이 돌 때 판정된다. C16이 실행 지점
   신설을 금했으므로 이 제약 아래의 최선이다(§12 표).
3. **20줄 미만의 중복은 잡지 못한다.** 창을 낮추면 오탐이 들어온다(§15).

기계적 판정이 성립하는 근거는 **해소 경로가 있다**는 것이다. 20줄 검사가 뜨면 `shared/`로 가면
되고, 현재 코퍼스에서 오탐이 0이므로 "이건 무시해도 되는 경고"라는 학습이 생기지 않는다.

### 제약 반영

| 제약 | 반영 |
|---|---|
| C1 산재된 것 통일 | C · D · F · G · H |
| C2 ST1 기각 (통일 원안 유지) | 전 작업 |
| C3 앞으로의 개발에도 적용 | §12 계약 + 이 설계 문서 자체 |
| C4 통합·분리 판정, 장치 부재한 곳 많음 | §3 분류 규칙 + §12.4 커버 표 |
| C5 호환을 목표로 두지 않음 | §7 즉시 rename |
| C6 · C7 무게 세 축 | §0 수단 표 |
| C8 새 규약 문서 0 · `CLAUDE.md` 순증 0 · 새 파일 0 | 새 규약 문서 없음. `CLAUDE.md`는 §7에서 **수정**만(순증 아님) |
| C9 · C12 · C13 `docs/audits` 이동 | A |
| C10 락 순감 금지 | §9.2 검증 방법 |
| C11 원장은 아직 없다 — 향후 개발 | **유지.** 원장을 만들지 않는다. 흩어진 항목을 §15.1에 모아만 두고 원장 구축은 다음 사이클이다 |
| C14 새 파일은 `references/`·공유 lib만 | E의 `references/` · `shared/`(§11.4, 공유 lib) · 락 테스트 2개(§12, 테스트는 규약·강제 문서가 아님) |
| C15 LD8 파기 | 승계하지 않음 |
| C16 실행 지점 신설 없음 | B는 기존 러너 수리. `PreCompact` 훅 배제(§10) |
| C17 사본 제거 우선, 락은 잔여에만 | C가 먼저, §12가 잔여에만 |
| C18 kill switch 이름은 fallback 없이 즉시 rename | §7 |
| C20 중복도 포함 | §1.3 · C |
| C21 stale 방지 | §12 |
