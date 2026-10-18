# R2a 계획 1 — 결함 셋 · 테스트 실행 공유본 · qg 진입 이름 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 공유 리뷰 엔진이 같은 이름 지적 블록을 버리지 않게 하고, qg 의 거짓 문장 둘을 고치고, qg 테스트 실행 스크립트를 `shared/test-selection/` 공유본으로 옮기고, qg 진입을 `commands/qg.md` 에서 진입 skill 둘(`/quality-gates:quality-pipeline` · `/quality-gates:artifact-critique`)로 바꾼다.

**Architecture:** 라우터(`docreview_route.py`)에 목록 블록 전용 `extract_blocks` + `merge_list_blocks` 를 더하고 층 1 · 층 2 만 그것으로 읽는다. 재비판 매핑 블록은 지금처럼 마지막 블록을 읽되 개수를 공시한다(아래 「설계와 다른 점」). 테스트 실행 넷(셋 + 형제 `resolve-baseline.sh`)은 닫힌 묶음으로 `git mv` 하고 qg 에는 같은 이름 상대 링크를 둔다(`shared/docreview/` 와 같은 방식). 진입은 `shared/entry/` 의 사전 검사 줄 계약을 그대로 따르고, 호출 표면 락의 qg 보고 모드를 지운다.

**Tech Stack:** bash 3.2 호환 셸 · Python 3(표준 라이브러리 + PyYAML) · git 심볼릭 링크(모드 120000) · 레포 셸 테스트 하네스(`shared/tests/assert.sh`).

**Spec:** `docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md` (§2 · AC1~AC9 · 공통 AC36 · AC37)

## Global Constraints

- 브랜치는 `feature/shared-review-engine-devices`(이 계획의 브랜치). HEAD 를 뒤로 옮기지 않는다. 커밋은 pathspec 으로(`git commit -- <경로…>`) — 워크트리를 공유할 때 남의 staged 작업을 쓸어 담지 않는다.
- 커밋 메시지: Conventional Commits, `type(scope)` 영어 · 설명 한국어. 끝에 `Co-Authored-By` · `Claude-Session` 두 줄(세션이 주는 값 그대로).
- 플러그인 버전: 건드린 플러그인마다 bump — quality-gates 는 major(호출 이름이 바뀐다), spec-distill(공유 라우터를 싣는다) · plugin-audit · project-init(옛 이름 문면)은 patch. **번호는 머지 직전에 정한다** — 이 계획 안에서는 bump 자리만 표시하고 숫자는 `<머지 때>` 로 둔다.
- 새 셸 테스트는 실행 비트 100755(`chmod +x` 후 `git ls-files -s` 로 확인). 스크립트의 파일 읽기는 UTF-8 명시. 플러그인 `.py` 에 `"python3"` 리터럴을 박지 않는다. 인라인 python 은 `python3 -I`(스크립트 파일 호출에는 `-I` 금지).
- bash 3.2: `$var` 뒤에 한글 글자가 붙으면 `${var}` 로 쓴다. `$( )` 안 heredoc 금지.
- 사용자에게 보이는 새 문면(안내 줄 · 공시 줄 · README · CHANGELOG)은 레포 `shared/style/plain-language.md` 규칙: 첫 줄 상태, 번호 · 내부 기호는 괄호 안.
- 레포 전용 값을 박지 않는다(기본 브랜치 이름 · 절대 경로 · `main`).
- 이 계획은 기본 브랜치의 R5 계획 1(#222)을 merge 한 트리(7d716d66) 위에서 점검했다. 로드맵 `roadmap.md` 의 결정 줄은 역사 기록이라 고치지 않고, R5 에 넘길 것은 Task 6 Step 6 에 적었다.

## 설계와 다른 점 · 설계에 없던 결정

이 계획은 설계 문면과 레포 사실이 부딪히는 세 곳에서 레포 사실 쪽으로 정했다. 실행 전에 사용자 확인을 받는다(재결정 규약 — 근거를 대고 사용자가 정한다).

1. **재비판 블록은 합치지 않는다.** 설계 §2 는 「재비판 블록도 같은 함수라 같이 바뀐다」고 한다. 그러나 qg 의 재비판 합성기가 같은 함수를 쓰고(`plugins/quality-gates/scripts/synthesize_findings.py:466-467`), 그 테스트가 「펜스가 둘이면 마지막이 이긴다 — 인용한 예시가 판정이 되지 않는다」를 잠근다(`plugins/quality-gates/tests/test_synthesize_recritic.sh:705-712`). 매핑 블록을 합치면 인용 예시의 판정이 실제 판정과 섞인다. 그래서 목록 블록(층 1 · 층 2)만 합치고, 재비판 매핑 블록은 마지막 블록을 읽되 「재비판 블록 N개 — 마지막만 읽었다」를 공시한다(버림이 아니라 알려진 선택으로 드러낸다).
2. **qg 의 인자 확인은 사전 검사 줄이 아니라 본문 P2 가 한다.** 설계 §2 는 「`## 진입 단계` 에 `!` 사전 검사(지금 `setup-qg.sh` 가 하던 인자 확인 · 없어진 인자 안내)」라고 한다. 그러나 사전 검사 줄은 상수 인자 두 개만 받고(`shared/entry/entry_preflight.py` 머리 docstring), 호출 표면 락이 그 줄의 모양을 고정하며(`shared/entry/check_invocation_surface.py:47-48 · :213-218`) 사용자 인자 토큰을 금지한다(같은 파일 `axis_d`, `USER_ARG_RE`). 인자 확인은 이미 본문 P2 의 일반 Bash 펜스(`setup-qg.sh --ensure $ARGUMENTS`, `quality-pipeline/SKILL.md:92-93`)가 한다 — 그 자리를 그대로 둔다(참고 a9ec064b).
3. **`resolve-baseline.sh` 도 공유 묶음으로 옮긴다.** 설계 §2 는 「닫힌 묶음째 옮기거나 소비 플러그인이 형제까지 링크하게 한다 — 어느 쪽인지는 측정이 정하고」라고 열어 두었다. 측정: `compute-test-scope-candidates.sh:18,54` 가 링크를 풀지 않은 자기 폴더에서 `resolve-baseline.sh` 를 부르고, `diff-test-results.py:142` 는 링크를 푼 폴더에서 `run-test-selection.sh` 를 찾는다. `resolve-baseline.sh` 에는 형제가 없다. 다른 플러그인이 qg 안 파일을 링크하면 설치본에서 닿을 수 없으므로 닫힌 묶음(넷)으로 옮긴다. 설계 §6 온톨로지의 「qg 범위 → `resolve-baseline.sh` | qg」 행은 이제 공유본을 가리킨다 — 계획 3 의 범위 기준 변경은 공유본 변경이고 R5 소비자 스위트까지 잰다(참고 6e3a3bff).

참고(`### Deferred to plan`) 21건 중 이 계획이 닿는 것: 6e3a3bff(위 3) · a9ec064b(위 2) · 4175608a(AC7 「역사 기록」 범위 — Task 6 에서 정의) · 같은 이름 블록 합치기의 경계 사례(Task 1). 나머지는 계획 2~4 몫이다.

## Review Focus

1. **리뷰어가 설명용 예시 펜스를 먼저 인용하고 실제 블록을 뒤에 낸다(목록 블록).** 합치면 예시 항목도 지적으로 들어간다 — 사람은 「합쳤다」 공시 줄을 보고 재비판이 예시를 기각하길 기대한다. Task 1 `case_same_name_blocks_disclosed` 가 공시 줄을 잠근다.
2. **두 블록이 같은 임시 번호(`c1`)를 쓰고, 둘째 블록의 질문(ask)이 자기 블록의 `c1` 을 막는다.** 질문은 자기 블록의 항목을 막아야 한다. Task 1 `case_same_name_blocks_ref_collision` 이 잠근다.
3. **재비판 응답에 펜스가 둘(예시 + 실제).** 마지막 블록이 판정이고, 개수가 공시된다. qg 쪽 기존 잠금(`case_last_block_wins`)도 그대로 GREEN. Task 1 `case_recritic_two_blocks_last_wins_disclosed` 가 잠근다.
4. **설치본은 링크를 실제 파일로 풀어 둔다.** 캐시 사본에서 `diff-test-results.py` 는 자기 폴더의 `run-test-selection.sh` 를, `compute-test-scope-candidates.sh` 는 자기 폴더의 `resolve-baseline.sh` 를 찾아야 한다. Task 3 `case_dereferenced_copy_runs` 가 `cp -RL` 사본에서 잰다.
5. **사용자가 `/quality-gates:quality-pipeline critique docs/x.md` 를 부른다.** 파이프라인은 돌지 않고, 문서 비평의 새 이름을 안내하는 한 줄을 낸 뒤 끝난다(아무것도 쓰지 않음). Task 4 의 `test_qg_critique_routing.sh` 재작성이 잠근다.

---

### Task 0: 기준선 스위트를 잰다

**Files:**
- Create: `$HOME/.claude/sdd-mirror/r2a-plan1/baseline.sh` (레포 밖 — git 이 추적하지 않는다)

- [ ] **Step 1: 기준 스위트 스크립트를 쓴다**

`$HOME/.claude/sdd-mirror/r2a-plan1/baseline.sh`:

````bash
#!/usr/bin/env bash
# 스위트 전체를 돌려 테스트별 rc · 실패 줄 수와 실패 줄 이름을 남긴다. 리포 루트에서: bash baseline.sh <출력 접두>
set -u
out="$1"; : > "$out.tsv"; : > "$out.names"
run_capped() { perl -e 'alarm shift; exec @ARGV' 900 "$@"; }
for t in plugins/*/tests/test_*.sh shared/tests/test_*.sh; do
  log="$(PYTHONDONTWRITEBYTECODE=1 run_capped bash "$t" 2>&1)"; rc=$?
  nf="$(printf '%s\n' "$log" | grep -c -E '✗|^FAIL|^not ok' || true)"
  printf '%s\t%s\t%s\n' "$t" "$rc" "$nf" >> "$out.tsv"
  printf '%s\n' "$log" | grep -E '✗|^FAIL|^not ok' | awk -v t="$t" '{print t "\t" $0}' >> "$out.names"
done
for t in plugins/*/tests/test_*.py; do
  log="$(cd "$(dirname "$t")" && PYTHONDONTWRITEBYTECODE=1 run_capped python3 -m unittest -q "$(basename "$t" .py)" 2>&1)"; rc=$?
  nf="$(printf '%s\n' "$log" | grep -c -E '^(FAIL|ERROR):' || true)"
  printf '%s\t%s\t%s\n' "$t" "$rc" "$nf" >> "$out.tsv"
  printf '%s\n' "$log" | grep -E '^(FAIL|ERROR):' | awk -v t="$t" '{print t "\t" $0}' >> "$out.names"
done
````

- [ ] **Step 2: 기준을 잰다(오래 걸린다 — 백그라운드로, 다른 스위트와 동시에 돌리지 않는다)**

Run (리포 루트에서): `bash "$HOME/.claude/sdd-mirror/r2a-plan1/baseline.sh" "$HOME/.claude/sdd-mirror/r2a-plan1/before"`
Expected: `before.tsv` 에 테스트마다 한 줄, `before.names` 에 실패 줄. 비교는 rc 가 아니라 실패 줄 «이름» 집합으로 한다(이미 RED 인 파일 안의 새 실패는 rc 로 안 보인다).

- [ ] **Step 3: 호출 표면 락의 현재 qg 보고 표를 남긴다**

Run: `python3 shared/entry/check_invocation_surface.py --report > "$HOME/.claude/sdd-mirror/r2a-plan1/surface-before.md"`
Expected: 표에 qg 행 15개(축 A 1 · C 8 · H 1 · I 5). 이 계획 끝에 그 행이 전부 사라져야 한다.

---

### Task 1: 같은 이름 지적 블록을 버리지 않는다 (AC1)

**Files:**
- Modify: `shared/docreview/scripts/docreview_route.py:1-10` (머리 docstring), `:37-44` (블록 추출), `:150-190` (`cmd_prepare` 의 층 1 · 층 2 읽기), `:280-297` (`_read_recritic`), `:728-738` (advisory 조립)
- Create: `shared/tests/fixtures/docreview/critic-dupblocks.txt`, `shared/tests/fixtures/docreview/recritic-two-blocks.txt.tmpl`
- Modify: `shared/tests/fixtures/docreview/cases.sh` (케이스 셋 추가), `shared/tests/test_docreview_route.sh` (호출 줄 추가)

**Interfaces:**
- Produces: `extract_blocks(text: str, name: str) -> tuple[list | None, str | None]` — 같은 이름 블록 전부를 YAML 로 읽은 목록. 블록이 없으면 `(None, "missing")`, 하나라도 파손이면 `(None, "broken")`.
- Produces: `merge_list_blocks(blocks: list, name: str, ev) -> tuple[list | None, str | None]` — 목록 블록 여럿을 하나로. 목록이 아닌 블록이 있으면 `(None, "not a list")`. `ev(name, *args)` 는 `cmd_prepare` 의 원장 기록 함수.
- 바뀌지 않음: `extract_block(text, name)`(마지막 블록 — qg `synthesize_findings.py` 가 쓴다).

- [ ] **Step 1: 실패하는 픽스처와 케이스를 쓴다**

`shared/tests/fixtures/docreview/critic-dupblocks.txt`:

````text
리뷰를 마쳤다. 층 1.

```docreview-layer1
- ref: c0
  category: scope
  anchor: "#3-non-goals"
  disposition: decide
  summary: "Non-goals 가 브리프의 범위 항목 하나를 조용히 뺐다"
  evidence: "브리프 §2 C3 vs 문서 §3"
```

빠뜨린 것을 덧붙인다.

```docreview-layer1
- ref: c0
  category: scope
  anchor: "#3-non-goals"
  disposition: decide
  summary: "Non-goals 가 브리프의 범위 항목 하나를 조용히 뺐다"
  evidence: "브리프 §2 C3 vs 문서 §3"
- ref: c5
  category: goal_fit
  anchor: "#2-goals"
  disposition: decide
  summary: "목표가 브리프와 다른 문제를 겨눈다"
  evidence: "브리프 §1 vs 문서 §2"
```

층 2.

```docreview-layer2
- ref: c1
  category: placeholder
  anchor: "#12-files-to-modify"
  disposition: fix
  summary: "c.py 가 목록에 없다"
```

```docreview-layer2
- ref: c1
  category: ambiguity
  anchor: "#2-goals"
  disposition: fix
  summary: "목표 B 가 두 가지로 읽힌다"
- ref: c2
  category: ambiguity
  anchor: "#2-goals"
  disposition: ask
  summary: "목표 B 를 둘로 나누나?"
  blocks: [c1]
```
````

`shared/tests/fixtures/docreview/recritic-two-blocks.txt.tmpl`:

````text
예시(프로필에서 인용):

```docreview-recritic
verdicts:
  - f: "{{F:c.py 가 목록에 없다}}"
    verdict: reject
    evidence: "예시일 뿐"
```

실제 판정:

```docreview-recritic
verdicts:
  - f: "{{F:c.py 가 목록에 없다}}"
    verdict: confirm
```
````

`shared/tests/fixtures/docreview/cases.sh` 끝에 덧붙인다:

```bash
case_same_name_blocks_disclosed() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-dupblocks.txt" "$FX/codex-failed.yaml" "$FX/recritic-missing.txt")"
  # 층 1: 블록 둘의 c0 은 글자까지 같아 하나로 흡수 → c0 · c5 둘. 층 2: c1 · c1@b2 · c2 셋. codex 는 실패 픽스처라 0.
  assert_eq "$(jget "$d/prep.json" 'len(d["items"])')" "5" "같은 이름 블록: 겹친 항목 하나만 빠지고 5건이 남는다"
  assert_eq "$(jget "$d/fin.json" 'd["degrade"].get("blocks_merged")')" "{'docreview-layer1': 2, 'docreview-layer2': 2}" "같은 이름 블록: 합친 개수가 degrade 에 남는다"
  assert_eq "$(jget "$d/fin.json" 'any("같은 이름 블록을 합쳤다" in a for a in d["advisory"])')" "True" "같은 이름 블록: 공시 줄"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_absorbed"] >= 3, d["blocks"]')" "(True, False)" "같은 이름 블록: 블록 둘 + 겹친 항목 하나가 흡수로 세지고 막지 않는다"
  rm -rf "$d"
}
case_same_name_blocks_ref_collision() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-dupblocks.txt" "$FX/codex-failed.yaml" "$FX/recritic-missing.txt")"
  # 둘째 층 2 블록의 ask(c2)는 같은 블록의 c1(「목표 B 가 두 가지로」)을 막는다 — 첫 블록의 c1(「c.py 가 목록에 없다」)이 아니다.
  assert_eq "$(jget "$d/prep.json" '[i["blocks"] for i in d["items"] if "둘로 나누나" in i["summary"]][0] == [[i["f"] for i in d["items"] if "두 가지로 읽힌다" in i["summary"]][0]]')" "True" "같은 이름 블록: 겹친 임시 번호는 자기 블록 안에서 풀린다"
  rm -rf "$d"
}
case_recritic_two_blocks_last_wins_disclosed() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-r1.txt" "$FX/codex-failed.yaml" "$FX/recritic-two-blocks.txt.tmpl")"
  assert_eq "$(fsum "$d" 'c.py 가 목록에 없다' '["disposition"]')" "fix" "재비판 블록 둘: 마지막(confirm)이 판정 — 인용 예시(reject)가 판정이 되지 않는다"
  assert_eq "$(jget "$d/fin.json" 'any("재비판 블록 2개" in a for a in d["advisory"])')" "True" "재비판 블록 둘: 마지막만 읽었다는 공시"
  rm -rf "$d"
}
case_same_name_block_broken_kills_critic() {
  local d f; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; f="$d/critic-in.txt"
  { cat "$FX/critic-r1.txt"; printf '\n```docreview-layer1\n- ref: c9\n  summary: [깨진\n```\n'; } > "$f"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$f")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep.json"; local rc=$?
  assert_eq "$rc" "4" "같은 이름 블록 하나라도 파손 → 출력 전체가 탐지 사망(rc 4)"
  rm -rf "$d"
}
```

`shared/tests/test_docreview_route.sh` 의 케이스 호출 목록 끝(`case_T46_critic_dead_twice_unverified` 다음)에 넷을 더한다:

```bash
case_same_name_blocks_disclosed
case_same_name_blocks_ref_collision
case_recritic_two_blocks_last_wins_disclosed
case_same_name_block_broken_kills_critic
```

- [ ] **Step 2: 실패를 확인한다**

Run (리포 루트에서): `bash shared/tests/test_docreview_route.sh 2>&1 | grep -E '같은 이름 블록|재비판 블록 둘' | head`
Expected: `case_same_name_blocks_*` 줄이 ✗(지금은 층 1 의 마지막 블록만 읽어 항목 수가 다르고 `blocks_merged` 가 없다). `case_recritic_two_blocks_last_wins_disclosed` 의 처분 단언은 이미 ✓, 공시 단언은 ✗. `case_same_name_block_broken_kills_critic` 은 ✗(지금은 마지막 블록만 보므로 rc 0).

- [ ] **Step 3: 라우터를 고친다**

`shared/docreview/scripts/docreview_route.py` 머리 docstring 의 마지막 문장을 바꾼다:

```python
리뷰어 산출물: 펜스 ```docreview-layer1 / ```docreview-layer2 (YAML 리스트) · ```docreview-recritic
(YAML 매핑 {verdicts, added}). 리스트 블록은 같은 이름이 여럿이면 전부 읽어 합친다(합친 개수 공시 ·
회계 흡수). 매핑 블록(재비판)은 마지막 블록을 읽고 개수를 공시한다 — 인용 예시가 판정이 되지 않게.
"""
```

`extract_block` 바로 아래에 둘을 더한다(`extract_block` 은 그대로 둔다):

```python
def extract_blocks(text: str, name: str):
    """같은 이름 블록 전부 — (값 목록, 오류). 없으면 (None, "missing"), 하나라도 파손이면 (None, "broken")."""
    ms = re.findall(BLOCK_RE % re.escape(name), text, re.S)
    if not ms:
        return None, "missing"
    out = []
    for m in ms:
        try:
            out.append(scrub(yaml.safe_load(m)))
        except Exception:  # yaml.YAMLError 계열 전부 — 블록 하나의 파손은 출력 전체의 파손이다
            return None, "broken"
    return out, None


def merge_list_blocks(blocks, name, ev):
    """목록 블록 여럿을 하나로 — (항목 목록, 오류).

    - 목록이 아닌 블록이 하나라도 있으면 (None, "not a list").
    - 글자까지 같은 항목(정렬한 JSON 이 같다)은 처음 것만 남기고 나머지를 흡수로 센다.
    - 블록 k(2 이상)가 앞 블록에서 이미 쓴 임시 번호(ref)를 다시 쓰면 그 블록 안에서 `<ref>@b<k>` 로
      바꾸고, 같은 블록 안의 `blocks` 도 따라 바꾼다 — 질문은 자기 블록의 항목을 막는다.
    - 블록이 둘 이상이면 둘째부터 블록마다 흡수 한 건(`<name>#b<k>` → `<name>#b1`)을 센다.
    """
    if not all(isinstance(b, list) for b in blocks):
        return None, "not a list"
    merged, seen_refs, seen_items = [], set(), {}
    for k, blk in enumerate(blocks, 1):
        local = {}
        if k > 1:
            for it in blk:
                if isinstance(it, dict) and it.get("ref") is not None and str(it["ref"]) in seen_refs:
                    local[str(it["ref"])] = "%s@b%d" % (it["ref"], k)
        for it in blk:
            key = json.dumps(it, sort_keys=True, ensure_ascii=False, default=str)
            if key in seen_items:
                ev("absorbed", "%s#b%d:%s" % (name, k, (it.get("ref") if isinstance(it, dict) else "?")), seen_items[key])
                continue
            seen_items[key] = "%s#b%d:%s" % (name, k, (it.get("ref") if isinstance(it, dict) else "?"))
            if isinstance(it, dict) and local:
                it = dict(it)
                if it.get("ref") is not None and str(it["ref"]) in local:
                    it["ref"] = local[str(it["ref"])]
                if it.get("blocks") is not None:
                    it["blocks"] = [local.get(r, r) for r in _refs(it["blocks"])]
            merged.append(it)
        for it in merged:
            if isinstance(it, dict) and it.get("ref") is not None:
                seen_refs.add(str(it["ref"]))
        if k > 1:
            ev("absorbed", "%s#b%d" % (name, k), "%s#b1" % name)
    return merged, None
```

`_refs` 는 `extract_block` 아래(지금 `:47`)에 이미 있다 — `merge_list_blocks` 를 `_refs` 정의 **뒤**에 둔다.

`cmd_prepare` 의 층 1 · 층 2 읽기(지금 `:173-190`)를 바꾼다:

```python
    l1s, e1 = extract_blocks(text, "docreview-layer1")
    l1, e1m = (merge_list_blocks(l1s, "docreview-layer1", ev) if l1s is not None else (None, None))
    critic_why = critic_why or e1 or e1m
    if l1s is not None and len(l1s) > 1:
        degrade.setdefault("blocks_merged", {})["docreview-layer1"] = len(l1s)
    if critic_why or not isinstance(l1, list):
        degrade["critic_dead"] = True
        ev("source_failed", "doc-critic", "layer1 block %s" % (critic_why or "not a list"), True)
    else:
        for i, it in enumerate(l1, 1):
            n1 = normalize(it, 1, "c", i, rec)
            if n1:
                items.append(("critic", n1))
        l2s, e2 = extract_blocks(text, "docreview-layer2")
        l2, e2m = (merge_list_blocks(l2s, "docreview-layer2", ev) if l2s is not None else (None, None))
        e2 = e2 or e2m
        if l2s is not None and len(l2s) > 1:
            degrade.setdefault("blocks_merged", {})["docreview-layer2"] = len(l2s)
        if e2 == "broken":
            degrade["critic_dead"] = True
            ev("source_failed", "doc-critic", "layer2 block broken", True)
        elif e2 or not isinstance(l2, list):
            if prof["layer_rubric"].get("layer2"):
                degrade["layer2_missing"] = True
                ev("uncountable", "layer2", "block %s" % (e2 or "not a list"))
        else:
            for i, it in enumerate(l2, 1):
                n2 = normalize(it, 2, "c", 100 + i, rec)
                if n2:
                    items.append(("critic", n2))
```

주의: 층 2 블록이 «파손»이면 설계 §2(「블록 하나라도 YAML 로 읽을 수 없으면 그 출력 전체를 탐지 사망」)대로 탐지 사망이다. 층 2 블록이 «없거나 목록이 아니면» 지금처럼 `layer2_missing` 이다. 층 2 파손 분기를 탄 뒤에도 층 1 항목은 이미 `items` 에 들어가 있다 — `critic_dead` 가 참이면 `cmd_prepare` 는 rc 4 를 내고 엔진이 재dispatch → 「미검증」으로 간다(지금 경로 그대로).

`_read_recritic`(지금 `:292`)에서 블록 개수를 센다:

```python
    text = Path(a.recritic).read_text(encoding="utf-8") if a.recritic and Path(a.recritic).is_file() else ""
    n_blocks = len(re.findall(BLOCK_RE % re.escape("docreview-recritic"), text, re.S))
    if n_blocks > 1:
        degrade["recritic_blocks"] = n_blocks
    blk, err = extract_block(text, "docreview-recritic")
```

advisory 조립(지금 `:737-738` 의 `critic_freshness_unknown` 줄 다음)에 두 줄을 더한다:

```python
    if degrade.get("blocks_merged"):
        adv.append("같은 이름 블록을 합쳤다 — %s" % " · ".join(
            "%s %d개" % (k, v) for k, v in sorted(degrade["blocks_merged"].items())))
    if degrade.get("recritic_blocks"):
        adv.append("재비판 블록 %d개 — 마지막만 읽었다(앞 블록은 인용 예시로 본다)" % degrade["recritic_blocks"])
```

`degrade` 는 `pending_recritic` 에 담겨 `finalize` 까지 간다(`:222`). `finalize` 가 `pend["degrade"]` 를 이어받는 자리에서 `blocks_merged` 키가 지워지지 않는지 확인한다(`grep -n 'pend\["degrade"\]\|degrade = ' shared/docreview/scripts/docreview_route.py`) — 이어받지 않으면 그 자리에서 `degrade.update({k: v for k, v in pend["degrade"].items() if k in ("blocks_merged",)})` 로 잇는다.

- [ ] **Step 4: 통과를 확인한다**

Run: `bash shared/tests/test_docreview_route.sh 2>&1 | tail -3`
Expected: 새 케이스 넷이 ✓, 기존 케이스 전부 ✓(결과 줄 `finish` 의 실패 0).

Run: `bash shared/tests/test_docreview_golden.sh 2>&1 | tail -3 && bash plugins/quality-gates/tests/test_synthesize_recritic.sh 2>&1 | tail -3`
Expected: 골든(블록 하나짜리 입력)은 바이트 그대로 GREEN, qg 의 `case_last_block_wins` 도 GREEN(`extract_block` 무변경).

- [ ] **Step 5: 변이로 이빨을 잰다(커밋 뒤)**

먼저 커밋한다(Step 6) — 변이 복원은 `git checkout HEAD -- <파일>` + `git diff HEAD --stat` 이 비었는지로 확인한다. 변이 둘:
1. `merge_list_blocks` 의 `local[...] = "%s@b%d"` 줄을 지운다 → `case_same_name_blocks_ref_collision` 이 ✗ 여야 한다.
2. `cmd_prepare` 의 `extract_blocks(text, "docreview-layer1")` 를 `extract_block` 로 되돌리고 `merge_list_blocks` 호출을 지운다 → `case_same_name_blocks_disclosed` 가 ✗ 여야 한다.
양성 대조: 변이 없이 같은 명령이 ✓ 인지 먼저 본다. `PYTHONDONTWRITEBYTECODE=1` 로 돌린다(같은 길이 변이의 stale `.pyc`).

- [ ] **Step 6: 커밋한다**

```bash
git add shared/tests/fixtures/docreview/critic-dupblocks.txt shared/tests/fixtures/docreview/recritic-two-blocks.txt.tmpl
git commit -m "fix(docreview): 같은 이름 지적 블록을 버리지 않고 합쳐 공시한다" -- shared/docreview/scripts/docreview_route.py shared/tests/fixtures/docreview/cases.sh shared/tests/test_docreview_route.sh shared/tests/fixtures/docreview/critic-dupblocks.txt shared/tests/fixtures/docreview/recritic-two-blocks.txt.tmpl
```

---

### Task 2: 문서 비평의 거짓 문장 · README 의 지운 게이트 인용 (AC2)

**Files:**
- Modify: `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md:207-211` (egress 문장)
- Modify: `plugins/quality-gates/README.md:16` (「authoring-time hard-review」 인용)
- Create: `plugins/quality-gates/tests/test_artifact_critique_truths.sh`

**Interfaces:** 없음(문면만).

- [ ] **Step 1: 실패하는 락을 쓴다**

`plugins/quality-gates/tests/test_artifact_critique_truths.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/*/SKILL.md plugins/quality-gates/README.md plugins/quality-gates/agents/artifact-adversarial.md
# AC2 — 문서 비평 skill 의 adversarial 도구 서술이 실제 tools: 와 맞고, README 에 지운 게이트 인용이 없다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SK="$(ls "$ROOT"/plugins/quality-gates/skills/*/SKILL.md | xargs grep -l 'artifact-adversarial' | head -1)"
tools="$(sed -n 's/^tools: //p' "$ROOT/plugins/quality-gates/agents/artifact-adversarial.md")"
assert_eq "$tools" "Read, Grep, Glob" "artifact-adversarial 의 tools 는 읽기 셋뿐이다(전제)"
assert_not_contains "$(cat "$SK")" "egress 도구를 가지므로" "adversarial 이 egress 도구를 가진다는 거짓 문장이 없다"
assert_contains "$(cat "$SK")" "adversarial 은 egress 도구가 없다" "고친 문장이 실제 tools 를 말한다(양성 짝)"
assert_not_contains "$(cat "$ROOT/plugins/quality-gates/README.md")" "hard-review" "README 에 지운 게이트(authoring-time hard-review) 인용이 없다"
finish
```

`chmod +x plugins/quality-gates/tests/test_artifact_critique_truths.sh`

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/quality-gates/tests/test_artifact_critique_truths.sh`
Expected: FAIL — 거짓 문장 · 양성 짝 · README 인용 셋이 ✗.

- [ ] **Step 3: 문면을 고친다**

`critiquing-artifacts/SKILL.md` 의 3번 단계 문장(지금 `:209-211`)에서
`(raw \`<path>\` 아님 — adversarial도 산출물을 read하고 egress 도구를 가지므로 critic/codex와 동일하게 canonical로 freeze)`
를 다음으로 바꾼다:
`(raw \`<path>\` 아님 — adversarial 은 egress 도구가 없다(\`tools: Read, Grep, Glob\`). 그래도 산출물을 read 하므로, 읽는 대상이 E2c 가 인가한 그 파일로 고정되도록 critic/codex 와 같은 canonical 로 freeze)`

그 문장이 근거로 받치던 판단(canonical freeze)은 egress 와 무관하게 유효하다 — 읽는 경로가 인가 뒤 바뀌지 않게 하는 장치라서다. freeze 자체는 그대로 둔다.

`README.md:16` 의 `+ authoring-time hard-review로 subagent spray를 억제` 를 `+ 시작 줄의 리뷰어 구성 공시로 subagent spray를 드러낸다` 로 바꾼다. 같은 줄의 「≤ 8」 상한 문구는 계획 3(D1.3 — 상한 제거)이 고친다 — 이 계획에서는 손대지 않는다.

- [ ] **Step 4: 통과를 확인한다**

Run: `bash plugins/quality-gates/tests/test_artifact_critique_truths.sh`
Expected: PASS(전부 ✓).

- [ ] **Step 5: 커밋한다**

```bash
git add plugins/quality-gates/tests/test_artifact_critique_truths.sh
git commit -m "fix(qg): 문서 비평 adversarial 의 도구 서술과 README 의 지운 게이트 인용을 바로잡는다" -- plugins/quality-gates/skills/critiquing-artifacts/SKILL.md plugins/quality-gates/README.md plugins/quality-gates/tests/test_artifact_critique_truths.sh
```

---

### Task 3: 테스트 실행 공유본 (AC3 · AC4 · AC5)

**Files:**
- Move (`git mv`, 바이트 그대로): `plugins/quality-gates/scripts/{run-test-selection.sh,diff-test-results.py,compute-test-scope-candidates.sh,resolve-baseline.sh}` → `shared/test-selection/`
- Create: 같은 이름 상대 심볼릭 링크 넷 `plugins/quality-gates/scripts/<이름> -> ../../../shared/test-selection/<이름>`
- Create: `shared/test-selection/README.md`, `shared/tests/test_test_selection_bundle.sh`
- Modify: `shared/tests/test_inline_python_isolated.sh:193, :321` (경로 목록), `shared/README.md` (디렉토리 표에 한 행)

**Interfaces:**
- Produces: 정본 경로 `shared/test-selection/<이름>` 넷. qg 의 기존 경로(`${CLAUDE_PLUGIN_ROOT}/scripts/<이름>`)는 링크로 그대로 쓸 수 있다 — 호출하는 쪽(SKILL · references · qg 테스트)은 바꾸지 않아도 같은 결과다.
- 소비자 규칙(README): 다른 플러그인은 넷을 «전부» 자기 `scripts/` 에 같은 이름 링크로 둔다.

- [ ] **Step 1: 옮기기 전 blob 해시를 남긴다**

Run:
```bash
for f in run-test-selection.sh diff-test-results.py compute-test-scope-candidates.sh resolve-baseline.sh; do printf '%s\t%s\n' "$f" "$(git rev-parse HEAD:plugins/quality-gates/scripts/$f)"; done > "$HOME/.claude/sdd-mirror/r2a-plan1/blobs-before.tsv"
cat "$HOME/.claude/sdd-mirror/r2a-plan1/blobs-before.tsv"
```
Expected: 네 줄, 각각 40자 해시.

- [ ] **Step 2: 실패하는 묶음 락을 쓴다**

`shared/tests/test_test_selection_bundle.sh`:

```bash
#!/usr/bin/env bash
# guards: shared/test-selection/* plugins/quality-gates/scripts/run-test-selection.sh plugins/quality-gates/scripts/diff-test-results.py plugins/quality-gates/scripts/compute-test-scope-candidates.sh plugins/quality-gates/scripts/resolve-baseline.sh
# AC3 · AC4 — 테스트 실행 넷이 공유본에 바이트 그대로 있고, qg 는 상대 링크를 두며, 링크 · 다른 플러그인 링크 · 링크를 푼 사본이 같은 결과를 낸다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
cd "$ROOT" || exit 1
NAMES="run-test-selection.sh diff-test-results.py compute-test-scope-candidates.sh resolve-baseline.sh"
for n in $NAMES; do
  mode="$(git ls-files -s -- "plugins/quality-gates/scripts/$n" | awk '{print $1}')"
  assert_eq "$mode" "120000" "qg 의 ${n} 는 심볼릭 링크다"
  assert_eq "$(readlink "plugins/quality-gates/scripts/$n")" "../../../shared/test-selection/$n" "qg 의 ${n} 는 공유본으로 가는 상대 링크다"
  assert_eq "$(git ls-files -s -- "shared/test-selection/$n" | awk '{print $1}')" "100755" "공유본 ${n} 는 실행 비트를 지킨다"
done
B="$HOME/.claude/sdd-mirror/r2a-plan1/blobs-before.tsv"
if [ -f "$B" ]; then
  while IFS="$(printf '\t')" read -r n h; do
    assert_eq "$(git hash-object "shared/test-selection/$n")" "$h" "공유본 ${n} 는 이동 전 blob 과 바이트가 같다"
  done < "$B"
else
  ok "이동 전 blob 기록이 이 기계에 없다 — 바이트 대조는 Step 1 을 돈 기계에서만"
fi
assert_contains "$(cat shared/test-selection/README.md)" "넷을 전부" "소비자 규칙: 묶음 전체를 링크한다"
# 세 경로가 같은 결과를 낸다: qg 링크 · 다른 플러그인 폴더의 링크 · 링크를 푼 사본(설치본 모양)
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/other/scripts" "$T/deref/scripts"
for n in $NAMES; do ln -s "$ROOT/shared/test-selection/$n" "$T/other/scripts/$n"; cp -L "$ROOT/plugins/quality-gates/scripts/$n" "$T/deref/scripts/$n"; done
g1="$(bash plugins/quality-gates/scripts/run-test-selection.sh granularity shell 2>&1)"
g2="$(bash "$T/other/scripts/run-test-selection.sh" granularity shell 2>&1)"
g3="$(bash "$T/deref/scripts/run-test-selection.sh" granularity shell 2>&1)"
assert_eq "$g2|$g3" "$g1|$g1" "run-test-selection.sh: 세 경로가 같은 결과"
r1="$(cd "$ROOT" && { bash plugins/quality-gates/scripts/compute-test-scope-candidates.sh 2>/dev/null; echo "rc=$?"; })"
r2="$(cd "$ROOT" && { bash "$T/other/scripts/compute-test-scope-candidates.sh" 2>/dev/null; echo "rc=$?"; })"
r3="$(cd "$ROOT" && { bash "$T/deref/scripts/compute-test-scope-candidates.sh" 2>/dev/null; echo "rc=$?"; })"
assert_eq "$r2|$r3" "$r1|$r1" "compute-test-scope-candidates.sh: 세 경로가 같은 결과(형제 resolve-baseline.sh 를 자기 폴더에서 찾는다)"
d1="$(python3 plugins/quality-gates/scripts/diff-test-results.py --help 2>&1 | head -3)"
d3="$(python3 "$T/deref/scripts/diff-test-results.py" --help 2>&1 | head -3)"
assert_eq "$d3" "$d1" "diff-test-results.py: 링크를 푼 사본도 같은 결과"
finish
```

`chmod +x shared/tests/test_test_selection_bundle.sh`

(실행 비트 단언의 기대값은 넷 다 `100755` 다. 이동 전 모드를 `git ls-files -s plugins/quality-gates/scripts/<이름>` 로 먼저 보고, 다른 것이 있으면 그 값으로 바꾼다 — 바이트 그대로 옮기므로 모드도 그대로여야 한다.)

- [ ] **Step 3: 실패를 확인한다**

Run: `bash shared/tests/test_test_selection_bundle.sh`
Expected: FAIL — 모드 `100755` 가 `120000` 이 아니다, 공유본 파일 없음.

- [ ] **Step 4: 옮기고 링크를 둔다**

```bash
mkdir -p shared/test-selection
for n in run-test-selection.sh diff-test-results.py compute-test-scope-candidates.sh resolve-baseline.sh; do
  git mv "plugins/quality-gates/scripts/$n" "shared/test-selection/$n"
  ln -s "../../../shared/test-selection/$n" "plugins/quality-gates/scripts/$n"
  git add "plugins/quality-gates/scripts/$n"
done
git ls-files -s -- plugins/quality-gates/scripts/run-test-selection.sh shared/test-selection/
```
Expected: qg 쪽 넷이 `120000`, 공유본 넷이 이동 전 모드.

`shared/test-selection/README.md`:

```markdown
# `shared/test-selection/` — 차등 테스트 실행 공유본

qg 차등 테스트가 쓰는 스크립트 넷의 정본이다. 플러그인은 이 파일들을 자기 `scripts/` 에 같은 이름의 상대 심볼릭 링크로 둔다(`shared/docreview/` 와 같은 방식). 설치할 때 링크가 실제 내용으로 풀린다.

## 소비자 규칙

- **넷을 전부 링크한다** — `run-test-selection.sh` · `diff-test-results.py` · `compute-test-scope-candidates.sh` · `resolve-baseline.sh`. 셋만 링크하면 설치본에서 형제를 못 찾는다: `compute-test-scope-candidates.sh` 는 링크를 풀지 않은 자기 폴더에서 `resolve-baseline.sh` 를 부르고(`:18 · :54`), `diff-test-results.py` 는 링크를 푼 자기 폴더에서 `run-test-selection.sh` 를 찾는다(`:142`).
- 링크는 `ln -s ../../../shared/test-selection/<이름> plugins/<플러그인>/scripts/<이름>` 꼴의 상대 경로다.
- 바이트 그대로 옮긴 파일이라 qg 이름이 계약에 들어 있다. 차등 테스트를 끄는 변수는 어느 플러그인에서 불러도 `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` 이다(`run-test-selection.sh:22`). 배정 · 행 파일의 꼬리 줄 `#qg-assign` · `#qg-rows`(`:13` · `:15`)는 소유자 이름이 아니라 형식 표지로 읽는다. 이름을 바꾸려면 kill switch 는 옛 이름을 별칭으로 계속 읽어야 한다.
- 이 파일들의 동작을 바꾸는 변경은 공유본 변경이다 — 링크한 모든 플러그인의 스위트로 잰다.
```

`shared/README.md` 의 디렉토리 표 `entry/` 행 다음에 한 행을 더한다:

```markdown
| `test-selection/` | qg 차등 테스트 실행 공유본(스크립트 넷 · 소비자 규칙은 그 폴더 README) |
```

`shared/tests/test_inline_python_isolated.sh:193` 과 `:321` 의 `plugins/quality-gates/scripts/run-test-selection.sh` 를 `shared/test-selection/run-test-selection.sh` 로 바꾼다(정본을 스캔한다 — 링크 쪽은 같은 내용이다).

- [ ] **Step 5: 통과를 확인한다**

Run: `bash shared/tests/test_test_selection_bundle.sh && bash shared/tests/test_copy_of_contract.sh 2>&1 | tail -2 && bash shared/tests/test_inline_python_isolated.sh 2>&1 | tail -2 && bash plugins/quality-gates/tests/test_guards_declaration_mapping.sh 2>&1 | tail -2`
Expected: 넷 다 실패 0. `test_copy_of_contract.sh` 는 새 링크 넷을 git 인덱스(모드 120000)에서 도출해 «존재하는 정본을 가리킨다»를 잰다.

Run: `for t in test_run_test_selection.sh test_compute_test_scope_candidates.sh test_resolve_baseline.sh test_runner_adapters.sh test_differential_procedure.sh test_impact_runtime_docs.sh; do bash plugins/quality-gates/tests/$t 2>&1 | tail -1; done; (cd plugins/quality-gates/tests && python3 -m unittest -q test_diff_test_results)`
Expected: 각 파일이 Task 0 기준선과 같은 실패 이름 집합(새 실패 0).

- [ ] **Step 6: 설치본 두 방식을 잰다(AC5 · Verification Plan)**

1. `--plugin-dir` 격리(AC5 의 통과 기준): 헤드리스 `claude -p --plugin-dir plugins/quality-gates` 로 차등 테스트 스크립트를 부르는 대신, 링크가 살아 있는 소스 트리 경로에서 `bash plugins/quality-gates/scripts/run-test-selection.sh detect "$PWD"` 를 돌려 rc 0 과 어댑터 출력을 기록한다.
2. `CLAUDE_CONFIG_DIR` 격리 설치(캐시 사본): 빈 폴더로 격리를 먼저 증명한다(`ls -A "$TMPCFG"` 가 빈 출력). 그 폴더로 marketplace 설치를 하고, 캐시 안 `quality-gates/<버전>/scripts/run-test-selection.sh` 가 «일반 파일»(`test -L` 거짓)이며 `bash <그 경로> detect "$PWD"` 가 1번과 같은 출력임을 기록한다. 설치 · 로그인 절차는 메모리 「격리 설치로 진짜 배포 경로 측정」을 따른다.
둘의 출력이 다르면 차이를 PR 본문에 적는다. 결과는 `$HOME/.claude/sdd-mirror/r2a-plan1/install-measure.md` 에 남기고 PR 본문으로 옮긴다.

- [ ] **Step 7: 커밋한다**

```bash
git add shared/test-selection/README.md shared/tests/test_test_selection_bundle.sh
git commit -m "refactor(qg): 차등 테스트 실행 넷을 shared/test-selection 공유본으로 옮기고 qg 는 링크로 쓴다" -- shared/test-selection plugins/quality-gates/scripts/run-test-selection.sh plugins/quality-gates/scripts/diff-test-results.py plugins/quality-gates/scripts/compute-test-scope-candidates.sh plugins/quality-gates/scripts/resolve-baseline.sh shared/README.md shared/tests/test_inline_python_isolated.sh shared/tests/test_test_selection_bundle.sh
```

커밋 뒤 `git show --stat HEAD` 의 파일 수가 이 pathspec 의 수와 같은지 본다(남의 staged 작업을 쓸어 담지 않았나).

---

### Task 4: 문서 비평을 `artifact-critique` 진입 skill 로 (AC7 의 개명 · AC6 의 진입 조건)

**Files:**
- Move: `plugins/quality-gates/skills/critiquing-artifacts/` → `plugins/quality-gates/skills/artifact-critique/` (`git mv`)
- Modify: `plugins/quality-gates/skills/artifact-critique/SKILL.md` (frontmatter `name` · `description` · `allowed-tools`, `## 진입 단계` 신설, 옛 이름 `reviewing-spec` 줄 `:176`)
- Create: `plugins/quality-gates/scripts/entry_preflight.py -> ../../../shared/entry/entry_preflight.py`
- Modify: `plugins/quality-gates/scripts/run_codex_reviewer.sh:42` (옛 이름 `reviewing-spec`), `plugins/quality-gates/agents/artifact-critic.md` · `artifact-adversarial.md` (skill 이름 언급), `plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh` · `plugins/quality-gates/tests/lib/reconstruct-skill.sh:106-107` · `plugins/quality-gates/tests/test_codex_gate_observation.sh:70` (경로 · 옛 이름)
- Modify: `plugins/quality-gates/tests/test_artifact_critique_truths.sh` (Task 2 — SK 를 새 경로로 찾는다; `ls … | xargs grep -l` 도출이라 변경 없이 통과해야 한다)

**Interfaces:**
- Produces: 진입 skill `quality-gates:artifact-critique`, 호출 `/quality-gates:artifact-critique <경로>`.
- Consumes: `shared/entry/check_invocation_surface.py --print-head quality-gates artifact-critique` 가 내는 머리 세 줄(allowed-tools 한 줄 · 사전 검사 줄 · `## 진입 단계`).

- [ ] **Step 1: 개명한다**

```bash
git mv plugins/quality-gates/skills/critiquing-artifacts plugins/quality-gates/skills/artifact-critique
ln -s ../../../shared/entry/entry_preflight.py plugins/quality-gates/scripts/entry_preflight.py
git add plugins/quality-gates/scripts/entry_preflight.py
python3 shared/entry/check_invocation_surface.py --print-head quality-gates artifact-critique
```
Expected: 마지막 명령이 `allowed-tools:` 한 항목 · `!` 사전 검사 줄 · `## 진입 단계` 를 낸다 — 이 글자를 그대로 쓴다.

- [ ] **Step 2: 머리를 고친다**

`plugins/quality-gates/skills/artifact-critique/SKILL.md` frontmatter:
- `name: artifact-critique`
- `description:` 첫 문장의 `Triggered by \`/qg critique <path>\` or a natural-language critique intent` 를 `Called as \`/quality-gates:artifact-critique <path>\` or on a natural-language critique intent` 로. 끝의 `code targets route to the normal /qg pipeline` 을 `code targets route to /quality-gates:quality-pipeline` 으로.
- `allowed-tools:` 목록 전체를 Step 1 이 낸 한 항목으로 바꾼다(`Bash(python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" quality-gates artifact-critique)`). `allowed-tools` 는 제한이 아니다(레포 CLAUDE.md) — 나머지 도구 호출은 그대로 된다.

frontmatter 닫는 `---` 바로 뒤, 본문 첫 제목 앞에 Step 1 이 낸 사전 검사 줄과 `## 진입 단계` 절을 둔다. 절 본문은 spec-distill 진입 skill 의 표(`plugins/spec-distill/skills/roadmap-status/SKILL.md` 의 `## 진입 단계` 표)를 그대로 옮기되 플러그인 이름과 복귀 문장을 이 skill 의 것으로 쓴다:

```markdown
## 진입 단계

이 절이 다른 모든 절보다 먼저 돈다. 이 제목 바로 위, 사전 검사 줄이 남긴 자리를 읽는다.

| 그 자리의 내용 | 동작 |
|---|---|
| `[devbrew-entry] ok …` | 아래 절차로 간다. 그 줄의 `root=` 값을 `project_dir` 로 쓴다 |
| `[devbrew-entry] disabled …` | 그 줄을 그대로 보이고 멈춘다 |
| `[devbrew-entry] error …` | `[quality-gates] artifact-critique 사전 검사 실패 — <reason= 값>.` 을 내고 멈춘다 |
| `[shell command execution disabled by policy]` | `[quality-gates] artifact-critique 사전 검사 불가(정책) — disableSkillShellExecution 이 사전 검사를 막았다.` 를 내고 멈춘다 |
| 감시줄 없음 · 그 밖 | `[quality-gates] artifact-critique 사전 검사 결과 없음 — 그 자리에 감시줄이 없다(치환 실패 · 출력 소실).` 을 내고 멈춘다 |
```

본문의 `E0 kill switch` 단계는 그대로 둔다(사전 검사의 `disabled` 는 플러그인 전체 스위치만 본다).

`SKILL.md:176` 근처의 `reviewing-spec` 을 지금 이름(`spec-distill:spec-review`)으로 바꾼다. `run_codex_reviewer.sh:42` 도 같다. 바꾸기 전에 그 줄이 무엇을 가리키는지 읽고, 옛 skill 이름을 «설명»하는 줄이면 지금 이름으로, «호출»하는 줄이면 지금 호출 꼴로 쓴다.

- [ ] **Step 3: 참조를 고친다**

Run: `git grep -n "critiquing-artifacts\|reviewing-spec" -- plugins/quality-gates ':!*CHANGELOG.md'`
나오는 줄을 전부 고친다 — 경로(`skills/critiquing-artifacts/`)는 `skills/artifact-critique/` 로, 이름은 `artifact-critique` 로, `reviewing-spec` 은 `spec-review` 로. `tests/lib/reconstruct-skill.sh:106-107` 의 `conducting-interview` 도 축 I 의 옛 이름이다 — 지금 이름(`spec-interview`)으로 바꾼다.
Expected(고친 뒤 같은 명령): 출력 없음.

- [ ] **Step 4: 문서 비평 스위트를 돌린다**

Run: `for t in plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh plugins/quality-gates/tests/test_artifact_metadata.sh plugins/quality-gates/tests/test_codex_gate_observation.sh plugins/quality-gates/tests/test_artifact_critique_truths.sh; do bash "$t" 2>&1 | tail -1; done`
Expected: Task 0 기준선 대비 새 실패 0.

- [ ] **Step 5: 커밋한다**

```bash
git commit -m "feat(qg)!: 문서 비평을 진입 skill artifact-critique 로 개명한다" -- plugins/quality-gates/skills plugins/quality-gates/scripts/entry_preflight.py plugins/quality-gates/scripts/run_codex_reviewer.sh plugins/quality-gates/agents plugins/quality-gates/tests
```

---

### Task 5: `quality-pipeline` 을 진입 skill 로 · `commands/qg.md` 삭제 · 락의 qg 예외 제거 (AC6 · AC8)

**Files:**
- Delete: `plugins/quality-gates/commands/qg.md`
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md:1-35` (frontmatter · 진입 단계), `:43-60` (P1 · P2 문면)
- Modify: `plugins/quality-gates/scripts/setup-qg.sh:8-12` (`critique` 분기 → 안내 · exit 2)
- Modify: `shared/entry/check_invocation_surface.py:20-24, :26-33, :81-90, :141, :322-363` (qg 보고 모드 삭제 · `ENTRY_SKILLS` 에 qg 둘)
- Modify: `shared/tests/test_invocation_surface.sh:47, :156-164` (보고 모드 케이스 → 「commands/ 가 생기면 RED」 케이스)
- Rewrite: `plugins/quality-gates/tests/test_qg_critique_routing.sh`

**Interfaces:**
- Produces: 진입 skill `quality-gates:quality-pipeline`, 호출 `/quality-gates:quality-pipeline [branch|--paths <glob>...]`. 인자 확인은 본문 P2(`setup-qg.sh --ensure $ARGUMENTS`)가 한다(「설계와 다른 점」 2).
- Produces: `setup-qg.sh critique …` → stdout 한 줄 `> [quality-gates] 문서 비평은 이제 /quality-gates:artifact-critique <경로> 로 부른다 — 파이프라인은 실행하지 않는다.` · exit 2 · 아무것도 쓰지 않음.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/quality-gates/tests/test_qg_critique_routing.sh` 를 통째로 바꾼다:

```bash
#!/usr/bin/env bash
# guards: plugins/quality-gates/scripts/setup-qg.sh plugins/quality-gates/skills/quality-pipeline/SKILL.md
# AC6 — 명령 층이 없고, 파이프라인에 문서 비평 인자가 오면 새 이름을 안내하고 실행하지 않는다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
assert_eq "$(ls "$ROOT/plugins/quality-gates/commands" 2>/dev/null | wc -l | tr -d ' ')" "0" "commands/ 층이 없다"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
( cd "$T" && git init -q . && git commit -q --allow-empty -m init )
out="$(cd "$T" && CLAUDE_SESSION_ID=s1 bash "$ROOT/plugins/quality-gates/scripts/setup-qg.sh" critique docs/x.md 2>&1)"; rc=$?
assert_eq "$rc" "2" "critique 인자: exit 2(실행하지 않는다)"
assert_contains "$out" "/quality-gates:artifact-critique" "critique 인자: 새 이름을 안내한다"
assert_eq "$(find "$T/.claude" -type f 2>/dev/null | wc -l | tr -d ' ')" "0" "critique 인자: 아무것도 쓰지 않는다"
SK="$ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"
assert_contains "$(cat "$SK")" '## 진입 단계' "quality-pipeline 은 진입 단계 절을 가진다"
assert_contains "$(cat "$SK")" 'setup-qg.sh" --ensure $ARGUMENTS' "인자 확인은 본문 P2 가 한다(사전 검사 줄이 아니다)"
finish
```

`setup-qg.sh` 가 세션 id 를 어디서 읽는지(`CLAUDE_SESSION_ID` 인지 다른 변수인지) 먼저 `sed -n 1,40p plugins/quality-gates/scripts/setup-qg.sh` 로 보고 테스트의 환경 변수를 맞춘다.

`shared/tests/test_invocation_surface.sh:160-164` 의 `variant q1` 보고 모드 케이스를 다음으로 바꾼다(같은 자리, 같은 헬퍼):

```bash
variant q1; put "$TMP/v-q1/plugins/quality-gates/commands/qg.md" "---
description: qg
---"
expect_red "$TMP/v-q1" "H" "qg 도 예외 없다 — commands/qg.md 가 다시 생기면 RED"
```

`expect_red` 헬퍼가 없으면 같은 파일의 RED 기대 케이스 꼴(예: 축 H 케이스)을 그대로 따른다. 그리고 `:47` 의 픽스처 쓰기(`w("plugins/quality-gates/commands/qg.md", …)`)를 지운다 — 기본 픽스처에 명령 층이 있으면 이제 그 자체가 RED 다.

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/quality-gates/tests/test_qg_critique_routing.sh; bash shared/tests/test_invocation_surface.sh 2>&1 | tail -3`
Expected: 첫 테스트 FAIL(commands/ 있음 · critique 가 exit 0). 둘째는 q1 케이스 ✗.

- [ ] **Step 3: 락에서 qg 예외를 지운다**

`shared/entry/check_invocation_surface.py`:
- 머리 docstring 의 「quality-gates 파일의 위반은 `plugins/quality-gates/commands/` 가 있는 동안 보고 모드다 …」 두 줄과 `--report` 사용법 줄을 지운다.
- `QG` · `QG_COMMANDS` · `SCOPE_ON` · `SCOPE_OFF` 상수를 지운다.
- `ENTRY_SKILLS` 에 두 줄을 더한다: `("quality-gates", "quality-pipeline"),` · `("quality-gates", "artifact-critique"),`
- `Ledger.__init__(self, report_mode)` 를 인자 없는 `__init__(self)` 로, `add` 는 언제나 `self.red.append(row)`. `rep` 와 `report_mode` 를 지운다. `Scan.__init__` 의 `Ledger(any(…QG_COMMANDS…))` 를 `Ledger()` 로.
- `render_report` 와 `--report` 인자 · 분기를 지운다. 끝 줄 둘을 `print("[invocation-surface] RED %d건 — 축 A~I (설계 2026-10-09 §4)." % len(L.red))` · `print("[invocation-surface] GREEN.")` 로.
- `axis_h` 의 메시지 「commands/ 층은 qg 밖에 두지 않는다」를 「commands/ 층은 두지 않는다」로.

`git grep -n "\-\-report\|SCOPE_ON\|SCOPE_OFF\|QG_COMMANDS" -- shared plugins docs/plugin-authoring.md` 로 이 플래그 · 상수를 부르는 다른 자리를 찾아 함께 고친다(문서의 사용법 줄 포함).

- [ ] **Step 4: 진입 skill 로 바꾸고 명령을 지운다**

```bash
python3 shared/entry/check_invocation_surface.py --print-head quality-gates quality-pipeline
git rm -q plugins/quality-gates/commands/qg.md
```

`quality-pipeline/SKILL.md` frontmatter:
- `description:` 의 `Triggered by \`/qg\`, "run quality gates", …` 를 `Called as \`/quality-gates:quality-pipeline\` or on "run quality gates", …` 로.
- `argument-hint: "[branch|--paths <glob>...]"` 를 더한다(옛 `qg.md` 의 것에서 `critique` 를 뺀 값).
- `allowed-tools:` 목록 전체를 print-head 의 한 항목으로 바꾼다.

frontmatter 뒤, `# Quality Gates — In-Turn Orchestrator` 제목 앞에 사전 검사 줄과 `## 진입 단계` 절을 둔다(Task 4 Step 2 의 표를 `quality-pipeline` 이름으로). `ok` 행의 동작은 「아래 `## Preflight` 로 간다」.

`## Preflight` 의 P1(kill switch) 문단은 그대로 둔다(사전 검사가 `disabled` 를 먼저 내지만, 이 skill 을 진입 단계 없이 부르는 길이 없다는 보장이 없다 — 두 번 보는 비용이 없다). P2 문단 끝의 「`--ensure` keeps this session's folder … when the `/qg` command's setup already made it」를 「when an earlier step of this run already made it」로 바꾼다 — 명령 층이 없어졌다.

`qg.md` 에만 있던 사용자 안내(Quick Reference 표 · Scope 설명 · Cost guidance)는 `plugins/quality-gates/README.md` 로 옮긴다(이미 같은 내용이 있으면 README 쪽을 남긴다). 표의 `/qg …` 꼴은 `/quality-gates:quality-pipeline …` 로, `/qg critique <path>` 행은 `/quality-gates:artifact-critique <path>` 로.

`setup-qg.sh:8-12` 의 `critique` 분기를 바꾼다:

```bash
# --- 문서 비평은 이 파이프라인의 인자가 아니다 — 새 진입 이름을 안내하고 실행하지 않는다.
if [[ "${1:-}" == "critique" ]]; then
  echo "> [quality-gates] 문서 비평은 이제 /quality-gates:artifact-critique <경로> 로 부른다 — 파이프라인은 실행하지 않는다."
  exit 2
fi
```

(이 분기는 세션 폴더를 만들기 «전»에 있어야 한다 — 지금 자리(`:10`)가 그렇다. 옮기지 않는다.)

- [ ] **Step 5: 통과를 확인한다**

Run: `bash plugins/quality-gates/tests/test_qg_critique_routing.sh && bash shared/tests/test_invocation_surface.sh 2>&1 | tail -2 && python3 shared/entry/check_invocation_surface.py`
Expected: 앞 둘 실패 0. 락은 qg 의 축 A · C · H 행이 사라진 상태다 — 남는 RED 는 Task 6 이 지울 축 I(옛 이름) 행뿐이어야 한다. 그 밖의 행이 남으면 이 Task 에서 고친다.

- [ ] **Step 6: 변이로 이빨을 잰다(AC8, 커밋 뒤)**

Step 7 커밋 뒤, 지운 명령 파일을 직전 커밋에서 되살린다: `mkdir -p plugins/quality-gates/commands && git show HEAD~1:plugins/quality-gates/commands/qg.md > plugins/quality-gates/commands/qg.md` → `python3 shared/entry/check_invocation_surface.py` 가 rc 1 과 `RED H plugins/quality-gates/commands/qg.md` 줄을 낸다. 지우고(`rm -r plugins/quality-gates/commands`) `git status --short` 가 비었는지 본다. 양성 대조: 변이 전 같은 명령의 축 H 행 0.

- [ ] **Step 7: 커밋한다**

```bash
git commit -m "feat(qg)!: commands/qg.md 를 지우고 quality-pipeline 을 진입 skill 로 세운다 — 호출 표면 락의 qg 예외 제거" -- plugins/quality-gates/commands plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/scripts/setup-qg.sh plugins/quality-gates/README.md plugins/quality-gates/tests/test_qg_critique_routing.sh shared/entry/check_invocation_surface.py shared/tests/test_invocation_surface.sh
```

---

### Task 6: 옛 이름을 레포에서 지우고 락이 잡게 한다 (AC7 · D10.22)

**Files:**
- Modify: `shared/entry/check_invocation_surface.py:71-74` (`OLD_NAME_RE` · `OLD_CALL_RE`)
- Modify: 아래 Step 2 명령이 내는 파일 전부(지금 약 80개 — qg README · SKILL · e2e-scenarios · 테스트 · plugin-audit 스크립트와 테스트 · spec-distill 테스트 · project-init README · 템플릿 · `docs/git-workflow/pr-process.md` · `shared/README.md` · `shared/tests/*`)
- Modify: `shared/tests/test_invocation_surface.sh` (옛 이름 케이스 둘)

**Interfaces:**
- 「역사 기록」의 정의(AC7 의 제외 범위, 참고 4175608a): 호출 표면 락의 살아 있는 표면(`LIVE_TOP` · `LIVE_PREFIX` — `CLAUDE.md` · `README.md` · `docs/plugin-authoring.md` · `plugins/` · `shared/` · `docs/philosophy/`)과 `docs/git-workflow/` 밖은 역사 기록이다. 그 안에서는 `CHANGELOG.md` 와 `*/tests/fixtures/*` 만 역사 기록이다. 그래서 `docs/superpowers/**`(설계 · 계획 · 로드맵) · `docs/archive/**` 는 고치지 않는다.

- [ ] **Step 1: 락에 옛 이름을 더하는 실패 케이스를 쓴다**

`shared/tests/test_invocation_surface.sh` 의 축 I 케이스 근처(`framing-requests` 를 심는 케이스 꼴)에 둘을 더한다:

```bash
variant i_qg; put "$TMP/v-i_qg/plugins/spec-distill/scripts/q.py" "# 브랜치 전체는 /qg branch 로"
expect_red "$TMP/v-i_qg" "I" "축 I: 옛 호출 /qg(뒤에 인자가 붙은 꼴 포함)"
variant i_ca; put "$TMP/v-i_ca/plugins/spec-distill/scripts/q.py" "# critiquing-artifacts 를 부른다"
expect_red "$TMP/v-i_ca" "I" "축 I: 옛 이름 critiquing-artifacts"
variant i_ok; put "$TMP/v-i_ok/plugins/spec-distill/scripts/q.py" "# .claude/quality-gates/<id> 와 /quality-gates:quality-pipeline 은 옛 이름이 아니다"
expect_green "$TMP/v-i_ok" "축 I 음성 대조: 새 이름과 상태 경로는 걸리지 않는다"
```

Run: `bash shared/tests/test_invocation_surface.sh 2>&1 | grep '축 I'`
Expected: 앞 둘 ✗, 음성 대조 ✓.

- [ ] **Step 2: 락을 고친다**

```python
OLD_NAME_RE = re.compile(
    r"conducting-interview|framing-requests|reviewing-spec|auditing-plugins|critiquing-artifacts"
    r"|commands/(?:interview|request-framing|plugin-audit|project-init|qg)\.md")
OLD_CALL_RE = re.compile(_LEAD + r"/(?:interview|qg)" + _TRAIL)
```

축 I 메시지 「옛 호출 토큰 '/interview'」를 `"옛 호출 토큰 '%s'" % _m.group(0).strip()` 로(어느 토큰인지 보인다). `_TRAIL` 은 `$` · 공백 · 따옴표 · `@` · `)` · `」` 만 받는다 — `/qg` 뒤의 `.` · `,` · `:` 는 지금 꼴에서 잡히지 않는다. Step 3 의 스윕 명령(아래)은 그 꼴까지 넓게 찾는다. 락의 `_TRAIL` 을 넓힐지는 Step 3 결과를 보고 정한다 — 넓혀서 음성 대조(`/quality-gates:` · `.claude/quality-gates/`)가 RED 가 되면 넓히지 않는다.

- [ ] **Step 3: 레포를 쓸어 고친다**

Run (리포 루트):

```bash
git grep -nP '(?:^|(?<=[\s`'"'"'"(「]))/qg(?=$|[\s`'"'"'"@)」.,:;])|critiquing-artifacts|qg critique' -- CLAUDE.md README.md docs/plugin-authoring.md 'plugins/' 'shared/' 'docs/philosophy/' 'docs/git-workflow/' ':!*CHANGELOG.md' ':!*/tests/fixtures/*'
```

나오는 줄을 다음 규칙으로 고친다(줄마다 문맥을 읽고):
- 호출을 안내하는 `/qg` → `/quality-gates:quality-pipeline`. `/qg branch` → `/quality-gates:quality-pipeline branch`. `/qg --paths …` 도 같은 꼴.
- 옛 동작을 «설명»하는 `/qg`(예: 「`/qg` 시작마다 폴더를 다시 만든다」) → 「qg 파이프라인(`/quality-gates:quality-pipeline`)」.
- `/qg critique <path>` · `qg critique` → `/quality-gates:artifact-critique <path>`.
- `critiquing-artifacts` → `artifact-critique`(경로면 `skills/artifact-critique/`).
- 테스트 안의 «부재를 잠그는» 리터럴(예: 「`/qg critique` 가 없다」를 재는 줄)은 리터럴을 조각으로 나눠 쓴다(`'/q''g critique'`) — 락의 코퍼스가 줄 단위라서다. 그런 줄을 고친 테스트는 고친 뒤에도 같은 것을 재는지 변이로 확인한다(그 리터럴을 문서에 되살리면 RED).
- plugin-audit · spec-distill · project-init 파일도 같은 규칙이다(이 세 플러그인은 patch bump 대상이 된다 — Task 7).

Expected(고친 뒤 같은 명령): 출력 없음. 그리고 `python3 shared/entry/check_invocation_surface.py` 가 `GREEN.`

- [ ] **Step 4: 건드린 플러그인 스위트를 돌린다**

Run: `for t in plugins/quality-gates/tests/test_*.sh plugins/plugin-audit/tests/test_*.sh plugins/project-init/tests/test_*.sh plugins/spec-distill/tests/test_*.sh shared/tests/test_*.sh; do bash "$t" >/dev/null 2>&1 || echo "RC≠0 $t"; done` 를 돌려 목록을 Task 0 의 `before.tsv` 와 대조한다(새로 rc≠0 이 된 파일만 연다).
Expected: 새 RED 0. 새 RED 가 있으면 그 파일의 실패 줄을 읽고 Step 3 규칙대로 고친다(대부분 문면 단언이 옛 이름을 찾는 경우다).

- [ ] **Step 5: 커밋한다**

`git status --short` 로 바뀐 파일 목록을 보고 그 목록을 pathspec 으로 넘긴다:

```bash
git commit -m "refactor(qg): 옛 이름 /qg · qg critique · critiquing-artifacts 를 레포에서 지우고 호출 표면 락이 잡게 한다" -- $(git status --short | awk '{print $2}')
```

(이 Task 는 파일이 많다 — 커밋 뒤 `git show --stat HEAD | tail -1` 의 파일 수가 `git status --short` 로 본 수와 같은지 확인한다.)

- [ ] **Step 6: 이 브랜치 밖의 옛 이름을 넘긴다**

R5 설계문서(`docs/superpowers/specs/2026-10-17-epic-conductor-design.md`, #222 로 기본 브랜치에 들어왔다)는 `/qg` 리터럴을 쓰지 않는다(2026-10-18 확인) — 고칠 옛 이름이 없다. 로드맵 `roadmap.md` 의 결정 줄은 역사 기록이라 고치지 않는다. PR 본문 「넘김」 절에 두 줄을 적는다:
- 「R5 계획 셋째(합친 사본 스위트 대조)는 공유본 «넷»을 링크한다 — R5 설계 §5 · §변경표는 「스크립트 셋」이라 적었지만 `compute-test-scope-candidates.sh` 가 형제 `resolve-baseline.sh` 를 자기 폴더에서 부르므로 넷째도 링크해야 설치본에서 돈다(`shared/test-selection/README.md` 소비자 규칙)」 — 받는 곳 R5.
- 「qg 의 새 진입 이름 — `/quality-gates:quality-pipeline` · `/quality-gates:artifact-critique`(R5 끝 단계의 qg 호출 꼴은 계획 3 의 범위 모드에서 정해진다)」 — 받는 곳 R5.

---

### Task 7: 버전 · CHANGELOG · README (AC9)

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` (major), `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/plugin-audit/.claude-plugin/plugin.json` · `plugins/project-init/.claude-plugin/plugin.json` (patch — Task 1 · 6 이 이 플러그인들이 싣는 파일을 바꿨을 때만)
- Modify: 각 플러그인 `CHANGELOG.md`, `plugins/quality-gates/README.md`
- Modify: `.claude-plugin/marketplace.json` (qg 설명에 `/qg` 가 있으면)

- [ ] **Step 1: bump 대상을 도출한다**

Run: `git diff --name-only "$(git merge-base HEAD origin/HEAD 2>/dev/null || git merge-base HEAD origin/main)"..HEAD -- plugins/ | cut -d/ -f2 | sort -u`
Expected: 이 계획이 건드린 플러그인 목록. 링크(`docreview_route.py` 를 싣는 spec-distill)는 diff 에 안 나타날 수 있다 — `shared/docreview/` 가 바뀌었으면 그 정본을 링크하는 플러그인(`git ls-files -s -- 'plugins/*' | awk '$1=="120000"' | …` 로 도출)을 더한다.

- [ ] **Step 2: 버전과 CHANGELOG 를 쓴다**

- quality-gates: major. 번호 칸에는 `<머지 때>` 를 쓰고 PR 본문에 「번호는 머지 직전에 정한다」를 적는다(먼저 머지되는 쪽이 이긴다).
- CHANGELOG `## [<머지 때>] — <날짜>`:
  - `### Removed` — `commands/qg.md` · 호출 `/qg` · `/qg critique`(alias 없이 즉시 — 호출 이름 변경 예외, 레포 CLAUDE.md).
  - `### Changed` — 진입이 `/quality-gates:quality-pipeline` · `/quality-gates:artifact-critique`; `critiquing-artifacts` → `artifact-critique`; 차등 테스트 실행 넷이 `shared/test-selection/` 공유본(링크); 문서 비평 adversarial 도구 서술 정정; README 인용 정정.
  - `### Fixed` — 같은 이름 지적 블록을 버리던 라우터(spec-distill · qg 가 함께 싣는다).
- spec-distill · plugin-audit · project-init: patch, `### Changed` 한 줄씩(무엇이 바뀌었는지).
- `plugins/quality-gates/README.md`: 진입 이름 표(Task 5 가 옮긴 Quick Reference)와 「Principles Instantiated」의 `/qg` 언급이 새 이름인지 확인한다.

- [ ] **Step 3: 락과 메타 테스트를 돌린다**

Run: `bash shared/tests/test_invocation_surface.sh 2>&1 | tail -1; for t in plugins/*/tests/test_*changelog*.sh plugins/*/tests/test_*version*.sh shared/tests/test_*changelog*.sh; do [ -f "$t" ] && bash "$t" 2>&1 | tail -1; done`
Expected: 새 실패 0(CHANGELOG 연속성 · 버전 형식 락).

- [ ] **Step 4: 커밋한다**

```bash
git commit -m "chore(qg): 버전 bump 자리와 CHANGELOG — 진입 이름 · 공유본 · 블록 합치기" -- plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md plugins/quality-gates/README.md plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/plugin-audit/.claude-plugin/plugin.json plugins/plugin-audit/CHANGELOG.md plugins/project-init/.claude-plugin/plugin.json plugins/project-init/CHANGELOG.md .claude-plugin/marketplace.json
```

(건드리지 않은 경로가 pathspec 에 있으면 git 이 오류를 낸다 — 그때는 그 경로를 빼고 다시 부른다.)

---

### Task 8: 끝 검증 (AC36 · AC37 · Verification Plan)

**Files:** 없음(측정 · 기록만). 기록은 `$HOME/.claude/sdd-mirror/r2a-plan1/` 아래.

- [ ] **Step 1: 스위트를 기준선과 대조한다(AC36)**

Run: `bash "$HOME/.claude/sdd-mirror/r2a-plan1/baseline.sh" "$HOME/.claude/sdd-mirror/r2a-plan1/after"` (다른 스위트와 동시에 돌리지 않는다)
그다음: `comm -13 <(sort -u "$HOME/.claude/sdd-mirror/r2a-plan1/before.names") <(sort -u "$HOME/.claude/sdd-mirror/r2a-plan1/after.names")`
Expected: 출력 없음(새 실패 이름 0). 이름이 바뀐 테스트(Task 4 의 경로 변경)로 생긴 차이는 내용을 열어 같은 실패인지 확인하고 PR 본문에 적는다.

- [ ] **Step 2: 대화형에서 진입 이름을 부른다(Verification Plan)**

헤드리스가 아니라 대화형 세션에서 `/quality-gates:quality-pipeline` 과 `/quality-gates:artifact-critique docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md` 를 부른다. 둘 다 사전 검사 줄의 `[devbrew-entry] ok …` 감시줄이 진입 단계에 보이는지만 확인하고 멈춘다(파이프라인을 끝까지 돌리지 않는다). 결과를 PR 본문 「확인」 절에 적는다. 이 단계는 사람이 한다 — 실행 agent 는 이 단계를 PR 본문의 미확인 항목으로 남긴다.

- [ ] **Step 3: AC37 대조표를 쓴다**

PR 본문에 표 하나: 설계 §1 처분표 행마다 「이 계획이 닫는가 · 아니면 어느 계획이」. 이 계획이 닫는 것은 §1 아래 「결함」 셋(같은 이름 블록 · egress 문장 · README 인용)뿐이고 처분표 행은 계획 2~4 몫이다. 구현 중 새로 찾은 장치가 있으면 그 행을 적고 설계 §1 에 더할지 지휘자에게 묻는다.

- [ ] **Step 4: 설계문서 대조 스크립트를 돌린다**

Run: `python3 plugins/spec-distill/scripts/check_bundle_coverage.py --plan docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md docs/superpowers/plans/2026-10-18-r2a-plan1-defects-test-selection-qg-entry.md --acs "AC1~AC9 · AC36 · AC37"`
Expected: 계획 1 몫 AC 중 빠진 것이 없다는 줄. 빠진 AC 가 나오면 그 AC 를 닫는 단계를 이 계획에 더한다.
