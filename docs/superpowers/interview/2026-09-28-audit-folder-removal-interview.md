---
name: audit-folder-removal
type: interview-brief
created_at: 2026-09-28
session_id: f278073e-5f32-44d1-b2ae-7280d1420a25
source: spec-distill conducting-interview v0.23.0
next_phase: superpowers:brainstorming
contract: v2
audit_file: 2026-09-28-audit-folder-removal-interview.audit.md
user_sourced_items:
  - id: C1
    source: verbatim
    status: confirmed
    statement: "끝 상태는 docs/audits/ 와 docs/archive/audits/ 가 리포에서 사라지고 그로 인해 깨지는 테스트·플러그인이 하나도 없는 것"
    evidence: S1
  - id: C2
    source: verbatim
    status: confirmed
    statement: "CLAUDE.md 의 ## Audits 절이 말하는 축적 관례는 끝난다"
    evidence: S1
  - id: C3
    source: verbatim
    status: confirmed
    statement: "감사 문서의 재사용 지식과 버리는 열린 항목은 다른 곳으로 옮기지 않고 git 이력을 유일한 보존처로 둔다"
    evidence: S1
  - id: C4
    source: verbatim
    status: confirmed
    statement: "검사기의 docs/audits/ README 링크·CLAUDE.md 포인터 요구는 없앤다"
    evidence: S1
  - id: C5
    source: verbatim
    status: confirmed
    statement: "AC6 기준선 json 은 plugins/plugin-audit/tests/fixtures/ 로 옮겨 회귀 테스트를 그대로 유지한다"
    evidence: S1
  - id: C6
    source: verbatim
    status: confirmed
    statement: "CHANGELOG 와 docs/superpowers 의 역사 기록 속 감사 경로 참조는 고치지 않고, 활성 코드·테스트·상시 문서 속 참조만 고친다"
    evidence: S1
  - id: C15
    source: verbatim
    status: confirmed
    statement: "실제 구멍은 지금 발동 중인 결함(검사가 실제로 비어 있거나 배포된 동작이 틀린 것)이고, 발동 조건이 아직 성립하지 않은 잠재 항목은 고치지 않고 버린다"
    evidence: S1
  - id: D7
    source: chosen
    status: confirmed
    statement: "폴더에 매달린 활성 의존(경로·존재 단언·개념 인용·plugin-audit 산출 경로)을 끊어 두 폴더를 지우고, 그 길에 지금 터져 있는 결함만 고친다 — 결함의 정의는 C15"
    evidence: S2
  - id: D8
    source: chosen
    status: confirmed
    statement: "검사가 못 보는 대상이 지금 리포에 실재하면 발동 중인 결함으로 치고, 대상·인스턴스가 0 인 검사 공백은 버린다"
    evidence: S3
  - id: D9
    source: chosen
    status: confirmed
    statement: "감사 문서 존재 단언은 부재 락으로 뒤집어 락 순감 0 으로 둔다 — 락의 모양은 D16"
    evidence: S4
  - id: D10
    source: chosen
    status: confirmed
    statement: "plugin-audit 리포트·data.json·journal 은 state 가 아닌 산출물로 규정해 자동 삭제하지 않고 경로를 사용자에게 보고한다"
    evidence: S5
  - id: D11
    source: chosen
    status: confirmed
    statement: "깨지는 테스트 0 은 착수 전 기준선 대비 새 실패 0 으로 판정한다"
    evidence: S6
  - id: D12
    source: chosen
    status: confirmed
    statement: "활성 개념 인용은 괄호만 지우고 둘레 근거 문장은 남기며, 공유 계약에 §8·§9 번호 인용을 새로 들이지 않는다"
    evidence: S7
  - id: D13
    source: chosen
    status: confirmed
    statement: "premortem 제약(폴더 존재를 잰다 · 경로 이동으로 공허해지는 락은 새 경로로 재앵커 · P21 스캔 유지)을 받고, 마무리에서 auto-memory 의 docs/audits 포인터를 갱신한다"
    evidence: S8
  - id: D14
    source: chosen
    status: confirmed
    statement: "남은 Open Questions 는 설계 단계로 넘기고, 범위 밖 3건(harness 선재 FAIL 2 · qg 밖 100644 테스트 17 · §7-7)은 이유와 함께 기록만 한다"
    evidence: S9
  - id: D16
    source: chosen
    status: confirmed
    statement: "부재 락은 두 폴더 부재 단언 한 줄이고 활성 표면 참조 스캔·면제 설계는 두지 않는다 — 참조가 다시 들어온 사례가 관측되면 참조 스캔으로 올린다"
    evidence: S10
  - id: D17
    source: chosen
    status: confirmed
    statement: "기준선 대조는 실패 항목의 식별자·내용으로 하고, 파일별 rc·실패 줄 수는 보조 지표로 둔다"
    evidence: S12
  - id: D18
    source: chosen
    status: confirmed
    statement: "OQ8 은 README 문구가 아니라 plugin-audit 이 Law 3 을 어떻게 지키는지의 결정으로 연다 — (가) 리포트는 ephemeral 이고 compounding 은 수정 커밋이 맡는다고 공시 · (나) 갭 목록을 사용자가 고른 커밋 위치로 넘기는 단계"
    evidence: S11
  - id: D20
    source: chosen
    status: confirmed
    statement: "plugin-audit 산출 경로는 .claude/plugin-audit/<date>-<target>/ 이고 세션 id 세그먼트를 두지 않는다"
    evidence: S17
  - id: D21
    source: chosen
    status: confirmed
    statement: "산출 디렉토리가 git-ignored 인 것은 devbrew 에서만 보장된다 — 사용자 리포에서의 ignore 보장은 OQ12 로 연다"
    evidence: S16
  - id: D22
    source: chosen
    status: confirmed
    statement: "C4 로 검사기의 README·CLAUDE.md 요구를 RED 로 재는 테스트 3개가 빠진다 — 요구 제거를 사용자가 명시했으므로 이 락 순감을 수용한다"
    evidence: S22
---

# 감사 폴더 제거 — Interview Brief

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming 해답공간으로
> 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다. 텔레메트리는 `audit_file`에 있다.

## 0. 한눈에

**무엇.** devbrew 의 `docs/audits/`(8파일)와 `docs/archive/audits/`(감사 5건 + codex 측정 디렉토리 4개)를
리포에서 없앤다.

**왜 — 재구성된 문제.** 문제는 폴더가 있다는 것이 아니다. 아무도 쓰지 않는 기록 저장소에 **활성 코드·테스트·배포
문서가 아직 매달려 있다**는 것이다. 지금까지 찾은 끈은 이렇다. 경로 하드코딩(plugin-audit 산출 경로·AC6 기준선 경로), 존재 단언
(spec-distill 테스트 하나), 경로 없는 개념 인용(「감사문서 §3」 식 10곳 — 배포되는 공유 계약 포함), CLAUDE.md
`## Audits` 절, 그리고 테스트 속 경로 인용·표본 셋(`shared/tests/test_no_new_duplication.sh` 주석 ·
`test_review_hook_removed.py` 의 역사 면제 정규식 · `shared/tests/test_presence_corpus_behavior.sh` 의 합성 경로 표본).
이 목록은 전수가 아니다 — 설계의 검증 절차가 활성 표면(`plugins` · `shared` · `CLAUDE.md`)을 두 폴더 경로로 한 번
grep 해 0건 또는 역사 면제만 남았는지 확인한다(영구 락이 아니라 착수 1회 점검). 끈을 끊어 폴더를 안전하게 지우고,
그 길에 **지금 터져 있는** 결함만 고친다. backlog 청산이 아니다.

**고칠 것(발동 중 — 실측 확인).**
- project-init trunk-based 템플릿 Pattern B 가 legacy release 를 현재 main 에서 자른다 → 릴리스 태그에서 자르도록 고친다.
- project-init S4(i) 가 갈라진 CLAUDE.md 를 내용 이관 없이 한 줄 포인터로 덮는다. 같은 절의 「비-관리 컨텐츠 보존」 불변식과 모순이다.
- qg `test_cancel_all_fence.sh` 인덱스 모드가 100644 다. 이 한 건이 `test_runner_adapters.sh` 와 `test_codex_backward_compat.sh` 를 사슬로 RED 로 만든다.
- spec-distill 리포 전수 락이 Bash matcher ≥2 를 기대한다. qg v7.0.0 이 훅을 의도적으로 지운 뒤로 낡았다. 틀린 쪽은 테스트다.
- qg P21 secret 스캔 glob 이 플러그인 레벨 `references/` 를 못 본다(하위 `docreview-profiles/` 포함). 지금 새는 위반은 0 이다.
- framing-requests(세 번째 proceed 게이트 채택자)에는 degrade 채널을 이름으로 재는 자기 락이 없다.

**결정 목록**

- OQ1 [해결 ⟨S2⟩] — 진짜 문제·goal: 끈 끊기 + 터진 결함만 → 근거 RC14 · RC15
- OQ2 [해결 ⟨S3⟩] — 「검사가 비어 있음」의 발동 경계: 대상 실재 기준 → 근거 RC1 · RC2 · RC3 · RC4 · RC5 · RC6 · RC8 · RC9 · RC10 · RC16 · RC19 · RC20 · RC21
- OQ3 [해결 ⟨S4⟩] — 감사 문서 존재 단언의 처리: 부재 락(모양은 OQ11 에서 두 폴더 부재 단언 한 줄로 줄었다) → 근거 RC11 · RC23 · RC27
- OQ4 [해결 ⟨S5⟩] — state 자동 삭제 규약과 사람이 읽을 리포트의 공존: 산출물로 규정 → 근거 RC12 · RC13 · RC17 · RC25 · RC26 · RC31
- OQ5 [해결 ⟨S7⟩] — 지식 무이관 vs 개념 인용이 가리키는 지식(ST1): 유지 → 근거 RC32 · RC34 · RC36 · RC39
- OQ6 [해결 ⟨S6⟩] — 깨지는 테스트 0 의 기준선: 착수 전 기준선 대비, 실패 항목 식별자로 대조(S12) → 근거 RC7
- OQ7 [해결 ⟨S8⟩] — premortem 처분: 제약 수용 + memory 갱신 → 근거 RC22 · RC28 · RC30
- OQ8 [열림] — plugin-audit 이 산출을 git-ignored 산출 디렉토리로 옮긴 뒤 Law 3 을 어떻게 지키나(ephemeral 공시 · 갭 목록 인계 단계) → 근거 RC12
- OQ9 [열림] — plugin-audit 리포트 경로(`.claude/plugin-audit/<date>-<target>/`)를 사용자에게 보고하는 방식, 그리고 `run-own-tests.sh` 가 여전히 필수로 받는 sid 인자의 출처 — 산출 경로에서만 sid 가 빠졌다(S17) → 근거 RC25
- OQ10 [열림] — PR 분할 여부와 플러그인별 version bump 범위
- OQ11 [해결 ⟨S10⟩] — 부재 락의 스코프·면제 설계: 두지 않는다 — 두 폴더 부재 단언 한 줄, 참조 재유입이 관측되면 참조 스캔으로 → 근거 RC27 · RC28
- OQ12 [열림] — 사용자 리포에서 plugin-audit 산출 디렉토리의 ignore 보장 → 근거 RC31

**다음 stage.** superpowers:brainstorming 이 OQ8 · OQ9 · OQ10 · OQ12 를 풀고 설계문서를 쓴다.

## 1. Goal · Non-goal

- Goal: 두 폴더가 리포에 없고, 그로 인해 깨지는 테스트·플러그인이 0 이며(착수 전 기준선 대비), 폴더가 되살아나면 락이 RED 를 낸다.
- Goal: 위 「고칠 것」 여섯이 고쳐지고, 고친 RED 가 GREEN 이 된다.
- Goal: plugin-audit 이 새 산출 위치에서 끝까지 돈다(출력 디렉토리 생성 · 새 경로로 재앵커된 락 · P21 스캔 유지).
- Non-goal: 감사 backlog 청산. 잠재 항목(대상·인스턴스 0)은 고치지 않고 문서와 함께 버린다.
- Non-goal: 재사용 지식을 다른 곳(issue·memory·코드 옆)으로 옮기는 것. git 이력이 유일한 보존처다.
- Non-goal: CHANGELOG·docs/superpowers 역사 기록 속 경로를 고치는 것.
- Non-goal: 감사 문서 밖의 RED(qg harness 선재 FAIL 2)와 qg 밖 100644 테스트 스크립트를 고치는 것.

## 2. 제약

- 🗣 confirmed **C1** — 끝 상태는 docs/audits/ 와 docs/archive/audits/ 가 리포에서 사라지고 그로 인해 깨지는 테스트·플러그인이 하나도 없는 것 ⟨S1⟩
- 🗣 confirmed **C2** — CLAUDE.md 의 ## Audits 절이 말하는 축적 관례는 끝난다 ⟨S1⟩
- 🗣 confirmed **C3** — 감사 문서의 재사용 지식과 버리는 열린 항목은 다른 곳으로 옮기지 않고 git 이력을 유일한 보존처로 둔다 ⟨S1⟩
- 🗣 confirmed **C4** — 검사기의 docs/audits/ README 링크·CLAUDE.md 포인터 요구는 없앤다 ⟨S1⟩
- 🗣 confirmed **C5** — AC6 기준선 json 은 plugins/plugin-audit/tests/fixtures/ 로 옮겨 회귀 테스트를 그대로 유지한다 ⟨S1⟩
- 🗣 confirmed **C6** — CHANGELOG 와 docs/superpowers 의 역사 기록 속 감사 경로 참조는 고치지 않고, 활성 코드·테스트·상시 문서 속 참조만 고친다 ⟨S1⟩
- 🗣 confirmed **C15** — 실제 구멍은 지금 발동 중인 결함(검사가 실제로 비어 있거나 배포된 동작이 틀린 것)이고, 발동 조건이 아직 성립하지 않은 잠재 항목은 고치지 않고 버린다 ⟨S1⟩
- ☑ confirmed **D7** — 폴더에 매달린 활성 의존(경로·존재 단언·개념 인용·plugin-audit 산출 경로)을 끊어 두 폴더를 지우고, 그 길에 지금 터져 있는 결함만 고친다 — 결함의 정의는 C15 ⟨S2⟩
- ☑ confirmed **D8** — 검사가 못 보는 대상이 지금 리포에 실재하면 발동 중인 결함으로 치고, 대상·인스턴스가 0 인 검사 공백은 버린다 ⟨S3⟩
- ☑ confirmed **D9** — 감사 문서 존재 단언은 부재 락으로 뒤집어 락 순감 0 으로 둔다 — 락의 모양은 D16 ⟨S4⟩
- ☑ confirmed **D10** — plugin-audit 리포트·data.json·journal 은 state 가 아닌 산출물로 규정해 자동 삭제하지 않고 경로를 사용자에게 보고한다 ⟨S5⟩
- ☑ confirmed **D11** — 깨지는 테스트 0 은 착수 전 기준선 대비 새 실패 0 으로 판정한다 ⟨S6⟩
- ☑ confirmed **D12** — 활성 개념 인용은 괄호만 지우고 둘레 근거 문장은 남기며, 공유 계약에 §8·§9 번호 인용을 새로 들이지 않는다 ⟨S7⟩
- ☑ confirmed **D13** — premortem 제약(폴더 존재를 잰다 · 경로 이동으로 공허해지는 락은 새 경로로 재앵커 · P21 스캔 유지)을 받고, 마무리에서 auto-memory 의 docs/audits 포인터를 갱신한다 ⟨S8⟩
- ☑ confirmed **D14** — 남은 Open Questions 는 설계 단계로 넘기고, 범위 밖 3건(harness 선재 FAIL 2 · qg 밖 100644 테스트 17 · §7-7)은 이유와 함께 기록만 한다 ⟨S9⟩
- ☑ confirmed **D16** — 부재 락은 두 폴더 부재 단언 한 줄이고 활성 표면 참조 스캔·면제 설계는 두지 않는다 — 참조가 다시 들어온 사례가 관측되면 참조 스캔으로 올린다 ⟨S10⟩
- ☑ confirmed **D17** — 기준선 대조는 실패 항목의 식별자·내용으로 하고, 파일별 rc·실패 줄 수는 보조 지표로 둔다 ⟨S12⟩
- ☑ confirmed **D18** — OQ8 은 README 문구가 아니라 plugin-audit 이 Law 3 을 어떻게 지키는지의 결정으로 연다 — (가) 리포트는 ephemeral 이고 compounding 은 수정 커밋이 맡는다고 공시 · (나) 갭 목록을 사용자가 고른 커밋 위치로 넘기는 단계 ⟨S11⟩
- ☑ confirmed **D20** — plugin-audit 산출 경로는 .claude/plugin-audit/<date>-<target>/ 이고 세션 id 세그먼트를 두지 않는다 ⟨S17⟩
- ☑ confirmed **D21** — 산출 디렉토리가 git-ignored 인 것은 devbrew 에서만 보장된다 — 사용자 리포에서의 ignore 보장은 OQ12 로 연다 ⟨S16⟩
- ☑ confirmed **D22** — C4 로 검사기의 README·CLAUDE.md 요구를 RED 로 재는 테스트 3개가 빠진다 — 요구 제거를 사용자가 명시했으므로 이 락 순감을 수용한다 ⟨S22⟩

✎ 전 항목은 Step B proceed 게이트에서 사용자가 확정했다 — 확정 시점을 그 게이트로 정한 것은 S13 · S23 이다.

✎ 산출물을 옮기는 것 자체와 옮길 자리는 S1 에서 사용자가 확인했다(원문 경로 `.claude/plugin-audit/<session-id>/`,
git-ignored). 하위 경로는 D20 이 재결정했고, ignore 가 devbrew 밖에서 보장되지 않는다는 점은 D21 이 연다.
plugin-audit 플러그인을 남긴다는 것은 seed 의 확인되지 않은 저자 문장이다 — 제거안은 인터뷰에서 고르지 않았다.

✎ ☑ 항목의 근거 범위는 고른 선택지의 라벨과 그때 보인 선택지 설명 전체다(S14). 설명 원문은 audit 의
프로세스 로그에 라운드별로 있다 — D12 의 §8·§9 번호 금지, D13 의 제약 목록, D14 의 범위 밖 3건이 거기서 온다.

✎ D16 은 S4·S8 이 정한 부재 락의 모양(활성 표면 참조 스캔 + 면제 + 코퍼스 하한 + 두 패턴 + rc 구분 + 양성 짝)을
리뷰 라운드 1 에서 사용자가 줄인 재결정이다. 두 폴더 부재 단언 한 줄이 폴더 부활(다른 브랜치 병합 · 옛 plugin-audit
캐시의 재기록)은 잡는다. 활성 코드에 경로 참조가 다시 들어오는 것은 잡지 못한다 — 그것이 천장의 조건이다.
「양성 짝」도 함께 빠졌다 — 폴더 부재 단언은 대상 경로가 고정이라 공허 통과의 여지가 없다.

✎ plugin-audit 산출 경로의 원문(S1)은 `.claude/plugin-audit/<session-id>/` 였다. 리뷰 라운드 2 에서 사용자가 `<date>-<target>` 로
재결정했다(S17) — sid 세그먼트는 auto-delete 되는 state 자리와 모양이 같고 /clear 마다 바뀌기 때문이다. 같은
라운드에서 「git-ignored」가 devbrew 에서만 참이라는 점이 열린 질문으로 옮겨졌다(S16).

✎ 실행비트는 워킹트리 `chmod` 로는 인덱스에 실리지 않는다. 인덱스 모드를 재는 락이 요구하는 것은 100755 다.

✎ plugin-audit 산출 이동으로 거짓이 되는 문장·코드는 README Law 3 줄 · SKILL 의 clean-tree 선결조건 ·
`render-audit-report.py --readme` 필수 인자 · `validate-audit-data.py` 의 README/CLAUDE.md 요구 · SKILL 의 journal
커밋 절차다. journal 의 P21 secret 스캔은 근거 문장만 바꾸고 유지한다. 사용자 리포에서는 `.claude/` 가 무시된다는
보장이 없다.

✎ 앞 사이클의 C10 「락 순감 금지」는 설계 §9.2 에서 헬퍼 통일의 파일별 assertion 수 검증으로 정의돼 있다.
인터뷰 문장은 일반형이다. D9 는 두 읽기 모두에서 순감 0 이다. C4 가 만드는 순감(검사기 테스트 3개)은 D22 가
명시적으로 수용한다.

## 3. Open Questions

- OQ8: 산출을 git-ignored 산출 디렉토리(`.claude/plugin-audit/<date>-<target>/`)로 옮긴 뒤 plugin-audit 이 Law 3(다음 세션이 실제로 찾는 곳에 capture)을 어떻게 지키나. (가) 리포트는 ephemeral 이고 compounding 은 감사가 낳은 수정·persona 편집 커밋이 맡는다고 README 에 공시한다. (나) 감사를 끝낼 때 갭 목록을 사용자가 고른 커밋 위치(예: 수정 PR 본문)로 넘기는 한 단계를 둔다 → 근거 RC12
- OQ9: 리포트 경로(`.claude/plugin-audit/<date>-<target>/`)를 사용자에게 어떻게 보고하는지. 같은 날 같은 대상을 두 번 감사할 때의 충돌 처리도 포함한다. 그리고 `run-own-tests.sh` 가 필수로 받는 sid 인자(격리 sandbox 이름에 쓰인다)의 출처를 어디서 정하는지 → 근거 RC25
- OQ10: PR 을 하나로 할지 나눌지(폴더 제거 + plugin-audit 이전 / project-init 두 결함 / 테스트 RED 수정), 그리고 플러그인별 version bump 범위(plugin-audit · spec-distill · quality-gates · project-init)

- OQ12: 사용자 리포에서는 `.claude/` 가 무시된다는 보장이 없다. 리포트·data.json·journal 이 `git add -A` 한 번에 커밋되지 않게 어떻게 할지(예: 출력 디렉토리 안에 `*` 한 줄짜리 .gitignore 를 함께 쓴다, 또는 devbrew 한정 전제로 공시한다) → 근거 RC31

## 4. External Landscape

- archive 폴더를 통째로 지우면서 「History belongs in Git」 원칙과 은퇴 대상의 부재 음성 회귀 테스트를 함께 둔 사례 «dvt-archive-removal» — [취함] — 존재 단언을 부재 락으로 뒤집는 근거 [→ OQ3]
- 태그에서 릴리스하는 팀은 패치가 필요할 때 릴리스 태그에서 브랜치를 사후에 자른다 «tbd-branch-for-release» — [취함] — CX-2 수정 방향 [→ OQ2]
- 잠재 결함은 커버리지 공백으로 새고, 드러나면 비용이 크다 «latent-active-defects» — [중립] — 경계는 S3 가 정했다 [→ OQ2]
- 결정의 동기는 가장 잃기 쉬운 정보이니 리포 안에 남기라 «nygard-adr» — [피함] — 인용 10곳이 이미 이유를 자기완결로 담아, 흡수하면 중복이 된다 [→ OQ5]
- 주석이 「왜」를 담으면 외부 문서 포인터는 필수가 아니다 «google-eng-practices» — [취함] — 괄호만 지우는 근거 [→ OQ5]
- 낡은 문서를 가리키는 포인터는 없는 것보다 해롭다 «outdated-docs» — [취함] — §7-5·「계측기」 인용이 그 형태 [→ OQ5]
- git grep 은 작업 트리만 보고, 삭제된 내용은 pickaxe 로만 찾는다 «git-grep-worktree» — [취함] — memory 포인터를 갱신하는 이유 [→ OQ7]
- GitHub 코드 검색은 기본 브랜치의 현재 트리만 색인한다 «gh-code-search» — [중립] — git 이력만 보존처인 것의 발견성 한계 [→ OQ7]
- 로컬 플러그인은 name+version 키로 캐시되고, bump 가 없으면 옛 사본이 서빙된다 «cc-plugin-cache» — [취함] — 플러그인마다 version bump [→ OQ10]
- /clear 가 session_id 를 재발급한다 «cc-clear-session-id» — [취함] — sid 로 만든 경로는 세션을 넘으면 찾기 어렵다 [→ OQ9]
- core.fileMode=false 면 실행비트 차이를 무시한다 «git-core-filemode» — [취함] — 모드는 인덱스에 직접 실어야 한다 [→ OQ7]

## 5. 기각 · Blind Spots

- 기각 — 감사 문서 속 잠재 항목을 이번에 함께 고치는 방향(zero-tool 회귀 부재 · §7-6 · §7-10 · §7-11 등) → 대상·인스턴스가 0 이라 S3 기준 밖, 문서와 함께 버린다
- 기각 — Law 2 agent tools: 락의 null 동의어·flow mapping·locale 없는 sed 갭을 막기 → 그렇게 쓴 agent 가 0 이다 [RC8 → OQ2]
- 기각 — codex 감사 러너의 live 웹 검색을 결함으로 보고 고치기 → 주석이 의도와 kill switch 를 밝힌 설계 선택이다 [RC9 → OQ2]
- 기각 — §7-2 codex-gate 마커 발견 락을 넓히기 → 마커 넷이 전부 SKILL.md 안에 있다 [RC20 → OQ2]
- 기각 — §7-7 요약·정본 정합 락 신설 → 기존 검사의 빈 정의역이 아니라 검사 부재이고, 요약은 지금 정합한다 [RC21 → OQ2]
- 기각 — seam·adjudication 핸드오프의 잔여 설계 항목 → 근거로 든 스크립트가 이미 없다 [RC16 → OQ2]
- 기각 — 원래: proceed 게이트 채택자 락의 갭을 「넷째 채택자 때 열리는 잠재」로 분류 / 재결정: 실제 구멍(주석이 정한 발동 조건 「세 번째 채택자」가 성립) / 근거 RC10 반증 [RC10 → OQ2]
- 기각 — 원래: 「감사 문서는 근거 기록으로 남긴다」(spec-distill CHANGELOG 의 앞 사이클 결정) / 재결정: 두 폴더째 삭제하고 존재 단언은 부재 락으로 뒤집음 / 근거 S1 · S4 [RC11 → OQ3]
- 기각 — plugin-audit 리포트에 성공 시 자동 삭제 GC 를 새로 만들기 → 리포트는 사람이 읽는 산출물이다 [RC13 → OQ4]
- 기각 — 원래: 부재 락 = 활성 표면 전수 참조 스캔 + 면제 설계 + 코퍼스 하한 + 두 패턴 + rc 구분 + 양성 짝(S4·S8) / 재결정: 두 폴더 부재 단언 한 줄, 참조 재유입이 관측되면 참조 스캔으로 올림(S10) / 근거: 리뷰 라운드 1 이 goal 대비 과함을 지적하고 사용자가 채택
- 기각 — 활성 개념 인용이 가리키는 감사 문서 절을 인용 파일 곁으로 흡수한 뒤 삭제 → 인용 10곳이 모두 자기완결이고, 흡수는 중복과 Self-narrating artifact 를 키운다 — verdict: kept — ST1 — 부착 5/5
- 위험 — 발동 중 | trunk-based Pattern B 가 현재 main 에서 legacy release 브랜치를 자른다 [RC3 → OQ2]
- 위험 — 발동 중 | project-init S4(i) 가 갈라진 CLAUDE.md 를 내용 이관 없이 덮어 비-관리 컨텐츠 보존 불변식과 모순된다 [RC2 → OQ2]
- 위험 — 발동 중 | test_cancel_all_fence.sh 인덱스 모드 100644 가 셸 어댑터 claim 락을 RED 로 만든다 [RC4 → OQ2]
- 위험 — 발동 중 | test_codex_backward_compat.sh 의 RED 는 위 한 건이 전파된 것이다 [RC6 → OQ2]
- 위험 — 발동 중 | 리포 전수 락의 Bash matcher ≥2 기대가 qg v7.0.0 의 훅 제거 뒤로 낡았다 [RC5 → OQ2]
- 위험 — 발동 중 | qg P21 secret 스캔 glob 밖에 플러그인 레벨 references/ 파일 둘이 있다 [RC1 → OQ2]
- 위험 — 발동 중 | framing-requests 의 degrade 채널을 이름으로 재는 락이 없다 [RC19 → OQ2]
- 위험 — 숨은 가정 | 「읽히지 않는 저장소」라도 경로 없는 개념 인용 10곳이 경로 grep 밖에 있다 [RC14 → OQ1]
- 위험 — 숨은 가정 | 상시 문서의 경로 참조는 CLAUDE.md 한 절뿐이다 [RC15 → OQ1]
- 위험 — 실패 양식 | 산출 경로를 옮기면 README Law 3 줄 · clean-tree 선결조건 · render 의 필수 인자 · validate 의 요구가 거짓이 된다 [RC12 → OQ4 · OQ8]
- 위험 — 실패 양식 | 조립기가 출력 디렉토리를 만들지 않아 새 경로 첫 실행이 죽는다 [RC17 → OQ4]
- 위험 — 숨은 가정 | `<sid>` 출처가 정의돼 있지 않은데 run-own-tests.sh 는 그 값을 필수로 받는다 [RC25 → OQ4 · OQ9]
- 위험 — 실패 양식 | journal P21 스캔의 근거가 「커밋 디렉토리」라, 옮긴 뒤 근거만 보고 스캔을 완화할 유인이 생긴다 [RC26 → OQ4]
- 위험 — 숨은 가정 | `.claude/` 가 무시되는 것은 devbrew 의 .gitignore 에서만 참이다 [RC31 → OQ4]
- 위험 — 실패 양식 | 뒤집을 파일의 `grep … && no || ok` 모양은 읽기 실패를 통과로 만든다 [RC27 → OQ3 · OQ11]
- 위험 — 실패 양식 | validate-audit-data.py 는 경로를 조립해 리터럴 grep 에 걸리지 않는다 [RC23 → OQ3]
- 위험 — 실패 양식 | bare-directory 회귀 정규식이 옛 경로 리터럴에 고정돼 경로 이동 시 공허해진다 [RC22 → OQ7]
- 위험 — 실패 양식 | AC6 기준선 json 을 plugins/ 로 옮기면 역사 면제를 잃고 부재 스캔 코퍼스에 들어간다 [RC28 → OQ7 · OQ11]
- 위험 — 실패 양식 | 인덱스 모드 락은 qg 에만 있고, spec-distill·shared 에 100644 테스트 스크립트 17개가 있다(범위 밖) [RC30 → OQ7]
- 위험 — 숨은 가정 | 선재 RED 는 seed 목록보다 많다 — qg harness 의 선재 FAIL 2 는 기준선에 기록한다 [RC7 → OQ6]
- 위험 — 숨은 가정 | 삭제로 잃는 것에는 재사용 절차(분할 시 락 독자 열거법, 리포에 사본 없음)도 있다 — S1 이 이미 수용했다 [RC39 → OQ5]
- 위험 — 숨은 가정 | 개념 인용은 둘레 문장이 메커니즘을 다 말한 뒤 붙은 출처 괄호다 [RC32 → OQ5]
- 위험 — 실패 양식 | presence_corpus.sh 의 「계측기」 절 인용은 원래부터 사례가 없는 절을 가리켰다 [RC34 → OQ5]
- 위험 — 실패 양식 | 채택자 락 주석이 가리키는 감사 항목은 활성 주석보다 낡았다 [RC36 → OQ5]
- 위험 — 숨은 가정 | 리포 밖 독자: auto-memory 13파일 22건이 docs/audits 를 가리키고 MEMORY.md 가 재측정 전 grep 을 지시한다 — 마무리에서 갱신한다
- 위험 — 실패 양식 | 다른 브랜치가 docs/audits/ 에 파일을 더하면 충돌 없이 병합돼 폴더가 되살아난다 — 폴더 존재도 잰다
- 위험 — 실패 양식 | 설치 캐시의 옛 plugin-audit 이 옛 경로로 계속 쓰거나 CLAUDE.md 포인터 부재로 RED 를 낸다 — version bump
- 위험 — 실패 양식 | 개념 인용을 고치며 공유 계약에 §8·§9 번호를 들이면 V11 스캔이 거짓 RED 를 낸다

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > ---
  > type: interview-seed
  > date: 2026-09-28
  > audit_file: 2026-09-28-resolve-audits-interview.audit.md
  > ---
  >
  > devbrew 리포의 감사 기록 폴더 두 곳, `docs/audits/` 와 `docs/archive/audits/` 를 정리해 없애는 일을
  > 맡기고 싶다. 이 폴더는 이제 쓰지 않는다. 이번 작업의 끝 상태는 docs/audits/ 와 docs/archive/audits/ 가 리포에서 사라지고 그로 인해 깨지는 테스트·플러그인이 하나도 없는 것이다. (사용자 확인)
  > docs/audits/ 에는 앞으로 새 기록을 쌓지 않으므로 CLAUDE.md 의 `## Audits` 절이 말하는 축적 관례도 함께 끝난다. (사용자 확인)
  > docs/archive/audits/ 도 같은 기준으로 실제 구멍만 고치고 폴더째 없앤다. (사용자 확인)
  > 2026-08-16 weight-reduction 사이클이 이미 이 폴더를 «해결 후 제거»하기로 정해 두었고, 이번이 그 마무리다.
  >
  > 문서 속 열린 항목을 다루는 기준은 하나다. 실제 구멍은 지금 발동 중인 결함(검사가 실제로 비어 있거나 배포된 동작이 틀린 것)이고, 발동 조건이 아직 성립하지 않은 잠재 항목은 고치지 않고 버린다. (사용자 확인)
  > 감사 문서의 재사용 지식과 버리는 열린 항목은 다른 곳으로 옮기지 않고 git 이력을 유일한 보존처로 둔다. (사용자 확인)
  > 그러니 이번 일은 backlog 를 다른 곳으로 이관하는 작업이 아니다. 고칠 것은 고치고 나머지는 문서와 함께 사라진다.
  >
  > 폴더에 묶인 활성 코드가 있다. `/plugin-audit` 은 산출물을 이 폴더에 커밋하고, 검사기는 인덱스 링크와
  > CLAUDE.md 포인터를 요구한다. plugin-audit 산출물은 git-ignored 인 `.claude/plugin-audit/<session-id>/` 에 쓰고, 검사기의 docs/audits/ README 링크·CLAUDE.md 포인터 요구는 없앤다. (사용자 확인)
  > 플러그인 자체는 남긴다 — 제거하는 안은 고르지 않았다.
  > AC6 기준선 json 은 plugins/plugin-audit/tests/fixtures/ 로 옮겨 회귀 테스트를 그대로 유지한다. (사용자 확인)
  > CHANGELOG 와 docs/superpowers 의 역사 기록 속 감사 경로 참조는 고치지 않고, 활성 코드·테스트·상시 문서 속 참조만 고친다. (사용자 확인)
  >
  > 다시 검증할 것 — 첫째, 어느 열린 항목이 «실제 구멍»인지의 분류는 Phase 0 이 파일과 git 이력만 읽고
  > 만든 후보일 뿐 확정이 아니다. 테스트는 한 번도 돌리지 않았다. 발동 중으로 보인 후보는 다섯이다.
  > quality-gates 의 `references/` 가 P21 secret 스캔 glob 밖에 있는 것, project-init 이 갈라진 CLAUDE.md 를
  > 내용 이관 없이 한 줄 포인터로 재작성하는 것, trunk-based 템플릿이 legacy release 브랜치를 현재 main 에서
  > 자르는 것, 그리고 선재 RED 두 개(`test_cancel_all_fence.sh` 의 실행비트, `test_no_write_matcher_hooks_repo.sh`
  > 의 Bash matcher 개수 기대)다. 경계에 있는 후보도 있다. Law 2 agent `tools:` 락이 null 동의어·flow
  > mapping·locale 없는 sed 를 못 막는 것은, 지금 그렇게 쓴 agent 가 없으니 잠재로도, 검사가 비어 있으니
  > 실제로도 읽힌다. codex 감사 러너가 웹 검색을 live 로 켜는 것, proceed 게이트 채택자 락이 라벨만 보는 것,
  > `test_codex_backward_compat.sh` 가 이미 고쳐졌는지도 같은 경계에 있다. 각 후보가 지금 정말 발동 중인지
  > 실측해야 한다. 둘째, 선재 RED 두 개는 코드가 틀린 것인지 테스트가 낡은 것인지 아직 모른다. 셋째,
  > `test_brief_review_no_external_precondition.sh` 는 zero-tool-probe 감사 문서의 존재를 단언한다. 문서를 지우면
  > 그 단언도 빠져야 하는데, 같은 weight-reduction 사이클이 확정한 «락 순감 금지»와 부딪혀 보일 수 있다.
  > 넷째, 산출을 state 로 옮기면 plugin-audit README 가 Law 3 을 «커밋된 감사 기록»으로 설명하는 줄이
  > 거짓이 된다. 또 state 의 «성공 시 자동 삭제» 규약이 사람이 읽어야 하는 감사 리포트를 읽기 전에 지울 수 있다.

## 7. Next Action

이 brief 를 context 로 `superpowers:brainstorming` 을 호출해 남은 OQ(OQ8 · OQ9 · OQ10 · OQ12)를 풀고 `-design.md` 를 쓰고 커밋한다.
brainstorming 의 사용자 리뷰 게이트 자리에서 그 설계문서 경로로 `spec-distill:reviewing-spec` 을 부른다. 그 승인
게이트에서 진행을 고른 뒤 `superpowers:writing-plans` 로 간다. superpowers 가 없으면 이 brief 자체가 완결 산출물이다.
