# SKILL.md 분할이 락 코퍼스를 줄인다 — 실패 클래스와 열거 방법

- **일자**: 2026-08-21
- **대상**: `plugins/*/skills/*/SKILL.md` 의 한 섹션을 `references/*.md` 로 분리할 때, 그
  SKILL.md 를 읽던 락들에게 일어나는 일
- **근거 작업**: 무게 감축 Task 31(`quality-pipeline`) · Task 32(`conducting-interview`),
  브랜치 `feature/devbrew-weight-reduction`
- **왜 이 기록이 필요한가**: 이 실패는 **두 번 연속으로, 같은 모양으로** 일어났고 영향 집합의
  크기는 누가 다시 셀 때마다 커졌다(4 → 5 → 6 → 12 → 15). 매번 커진 이유는 하나다 —
  **앞사람의 숫자를 물려받고 다시 도출하지 않았기 때문이다.** 이 문서는 그 숫자를 물려주려는
  것이 아니라 **도출 방법**을 물려주려는 것이다. 다음 분할에서 이 문서만 읽고 바로 착수할 수
  있어야 한다.

## 목차

- [§1 실패 클래스](#1-실패-클래스)
- [§2 독자 열거 방법](#2-독자-열거-방법)
- [§3 무엇이 독자를 면역으로 만드는가](#3-무엇이-독자를-면역으로-만드는가)
- [§4 거울 클래스 — 포인터가 presence 락을 header-satisfiable 하게 만든다](#4-거울-클래스--포인터가-presence-락을-header-satisfiable-하게-만든다)
- [§5 차분 실증의 계측기 위생](#5-차분-실증의-계측기-위생)
- [§6 알려진 독자 목록 (2026-08-21 기준)](#6-알려진-독자-목록-2026-08-21-기준)
- [§7 이월된 미해결 항목](#7-이월된-미해결-항목)
- [§8 공유 참조 파일 — 처방을 거꾸로 적용하지 않기](#8-공유-참조-파일--처방을-거꾸로-적용하지-않기)

---

## §1 실패 클래스

섹션을 SKILL.md 밖으로 옮기면 **그 파일의 코퍼스가 줄어든다.** 그 파일을 읽던 락은 세 부류로
갈리고, 위험한 것은 셋째뿐이다.

| 부류 | 분할 후 | 위험 |
|---|---|---|
| **positive (존재)** — "X 가 있어야 한다" | 대상이 사라져 **즉시 RED** | 없음 — 시끄럽다 |
| **windowed (윈도우)** — `awk '/^#### B-2/…'` | 창이 비어 **즉시 RED** (빈-창 가드가 있으면) | 없음 — 시끄럽다 |
| **absence (부재)** — "X 가 없어야 한다" | **GREEN 유지, 더 적은 범위를 지킴** | **여기** |

부재 락은 코퍼스가 줄어도 실패하지 않는다. **조용해질 뿐이다.** 그래서 분할 직후 테스트가
전부 GREEN 이어도 그것은 "안전하다"가 아니라 **"positive 락만 확인했다"** 를 뜻한다.

실측:

| | Task 31 | Task 32 |
|---|---|---|
| 대상 | `quality-pipeline/SKILL.md` | `conducting-interview/SKILL.md` |
| 축소 | 2,079 → 906줄 (**57%**) | 614 → 396줄 (**38%**, 232줄 이동) |
| 즉시 RED 로 드러난 락 | positive·window 다수 | 45건 (19 + 26) |
| **조용히 약해진 부재 락** | P21 secret 스캔 등 | **4파일 / 10단언** |

Task 31 의 사례가 이 클래스의 성격을 가장 잘 보여준다: 잃은 구간이 하필 **실제 서비스를
부팅하는 절차**였고, 그래서 *"사용자에게 `DATABASE_URL` 을 물어봐라"* 같은 지시가 새로 들어올
**가장 그럴듯한 자리**가 P21 스캔 밖으로 나가 있었다. 위험은 "지금 숨은 위반"이 아니라
**"앞으로 그 파일에 들어올 편집"** 이다 — 두 사이클 모두 이동 구간의 금지어는 0건이었다.

## §2 독자 열거 방법

**dispatcher·앞선 보고서의 숫자를 신뢰하지 말 것.** 매번 직접 도출한다. 도달 경로는 여섯 가지다.

1. **경로 리터럴** — `SKILL="$ROOT/plugins/<p>/skills/<s>/SKILL.md"`
2. **글롭** — `"$SD"/skills/*/SKILL.md`
3. **`find`** — `find plugins/*/skills -name 'SKILL.md'`, `find "$SD" -type f`
4. **`git ls-files`** — `git ls-files -- 'plugins/*/skills/*/SKILL.md'`
5. **재귀 `grep -r`** — `grep -rl <pat> "$P/skills"` (경로를 한 번도 쓰지 않고 도달한다)
6. **위 중 하나로 만든 코퍼스 변수** — `CORPUS=` · `FILES=` · `prod_files=` · `scan_roots=`

여기에 두 개의 축을 더한다.

- **`.py` 도 본다.** Task 31 의 6번째(그리고 최악의) 인스턴스가 `.py` 였다
  (`test_no_secret_prompts.py`). `--include='*.sh'` 만 쓰면 놓친다.
- **플러그인 경계를 넘는다.** A 플러그인이 소유한 락이 B 플러그인의 skills 를 훑을 수 있다.
  이것이 가장 놓치기 쉬운 축이고, **알려진 인스턴스가 둘**이다(§6 의 ★).

실행 가능한 시작점:

```bash
# 축 1·2·6 — SKILL.md 를 언급하는 모든 테스트와 그 경로 구성 방식
grep -rln 'SKILL\.md' --include='*.sh' --include='*.py' plugins/*/tests shared/tests

# 축 3·4 — 플러그인 경계를 넘는 글롭 (가장 놓치기 쉬움)
grep -rn "plugins/\*/skills" --include='*.sh' --include='*.py' plugins/*/tests shared/tests

# 축 5 — 경로를 안 쓰고 재귀로 도달하는 독자
grep -rln 'grep -r' --include='*.sh' plugins/*/tests

# 도달 여부 최종 확인 — 옮긴 파일에만 있는 문자열로 역방향 probe
grep -rl '<분리한 파일에만 있는 문구>' plugins/ | sort
```

마지막 probe 가 결정적이다. **정적 분석으로 "닿는다"고 판정하지 말고, 옮긴 파일에만 있는
문자열로 실제로 닿는지 재라.** (실측 함정: 새 파일에 없는 문자열로 probe 하면 도달 가능한
독자도 0건으로 나온다 — 이 사이클에서 실제로 한 번 오판할 뻔했다.)

그리고 각 독자마다 단언을 **absence / presence / windowed** 로 분류한다. 분류가 곧 작업
목록이다 — **absence 만 수리 대상**이다.

## §3 무엇이 독자를 면역으로 만드는가

한 가지뿐이다. **코퍼스를 도출했는가, 열거했는가.**

- **면역 (도출)** — 글롭·`find`·`git ls-files`·`grep -r` 로 만든 코퍼스는 새 파일을 **자동으로**
  삼킨다. 손댈 필요가 없다.
  - 예: `spec-distill/tests/test_stale_terms.sh` 의 `find "$SD" -type f`. Task 32 에서
    **손대지 않았고**, `interview_round`·`locked_directions`·`재논쟁 금지` 를 새 파일에
    주입하니 그대로 3건 RED — 자동 커버를 실측으로 확인했다.
- **취약 (열거)** — 하드코딩 배열·경로 리터럴은 새 파일을 절대 못 본다.
  - 반례: `spec-distill/tests/test_no_wall_clock.sh` 의 분할 전 3원소 배열.

    ```bash
    SURFACES=(
      "$PLUGIN_ROOT/skills/conducting-interview/SKILL.md"
      "$PLUGIN_ROOT/skills/reviewing-spec/SKILL.md"
      "$PLUGIN_ROOT/README.md"
    )
    ```

    순수 부재 락인데 분리분이 배열에 없어, 금지 토큰을 새 파일에 넣어도 **9/9 GREEN** 이었다.

**수리 처방은 항상 같다**: 열거를 도출로 바꾸고(`references/*.md` 글롭을 더한다),
**도출이 0건이면 loud FAIL 하는 vacuity 단언**을 함께 넣는다. `0건 검사`를 `문제 없음`으로
읽으면 락은 조용히 원래대로 돌아간다.

주의 — **글롭을 넓히는 것만으로 부족한 경우가 있다.** 부재 검사가 조기 `continue` 뒤에 있으면
새 파일은 코퍼스에 들어와도 검사 전에 빠져나간다. `test_web_kill_switch.sh` 가 그랬다:
두 부재 검사가 `[[ -n "$dispatch_lines" ]] || continue` **뒤에** 있어, dispatch 가 없는
분리분은 영영 검사되지 않았다. 부재 검사를 `continue` **위로** 올려야 했다.

`set -u` + macOS bash 3.2 주의: 빈 배열에 `"${arr[@]}"` 를 확장하면 `unbound variable` 로
죽는다. 도출 코퍼스는 비어 있을 수 있으므로 `"${arr[@]+"${arr[@]}"}"` 로 가드한다 — 그래야
글롭이 깨졌을 때 크래시가 아니라 vacuity 단언이 발화한다.

## §4 거울 클래스 — 포인터가 presence 락을 header-satisfiable 하게 만든다

§1 은 "부재 락이 조용해진다"였다. 그 **거울**이 있다.

포인터 블록은 옮긴 섹션과 **같은 헤딩을 유지하고 같은 어휘를 반복한다**(그게 포인터의 일이다).
그래서 전-파일 presence 락이 **포인터만 보고 통과**할 수 있다 — 지키려던 대상은 파일을 떠났는데도.
이것은 이 리포가 이미 이름을 가진 함정의 변종이다(`feedback_grep_lock_header_satisfiable`).

분할 시 점검 순서:

1. 포인터 블록이 쓰는 모든 명사·헤딩·식별자를 뽑는다.
2. 각각에 대해, 그 문자열을 앵커로 쓰는 presence 락이 있는지 본다.
3. 있으면 **포인터만 남기고 본문을 지운 mutation** 으로 그 락이 RED 인지 확인한다.
   GREEN 이면 그 락은 이제 포인터를 지키고 있다 — body-unique 문구로 다시 앵커하거나
   스킬 표면 전체를 보게 고친다.

Task 32 실측: presence 패턴 16종을 이 방식으로 검사해 **새 decoy 0건**. 이 사이클에서는
문제가 없었지만, 그것은 포인터 문구가 짧았던 덕이지 구조적 보장이 아니다.

**Task 33 이 이 클래스를 한 칸 키웠다.** 포인터가 아니라 **공유 참조 파일 자체**가 decoy 가
될 수 있다 — 상세와 처방은 §8.

## §5 차분 실증의 계측기 위생

수리한 부재 락은 **차분(differential)** 으로만 증명된다.

> 금지 문자열을 분리된 파일에 주입한다 → **수정 전 판본 GREEN**(fail-open 실증) ·
> **수정본 RED** → 주입 제거 → 다시 GREEN + 원본 해시 일치.

"수정본이 RED 다"만으로는 부족하다. 그건 락이 작동함을 보일 뿐 **분할이 무엇을 깨뜨렸는지**를
보이지 못한다. 수정 전 GREEN 이 fail-open 의 증거다.

계측기가 고장 나는 두 방식 — **둘 다 이 사이클에서 실제로 밟았다**:

1. **수정 전 판본을 임시 디렉터리에서 돌리면 안 된다.** 리포의 테스트는 `assert.sh` 를
   `$0`/`BASH_SOURCE` 기준 상대경로로 가져온다. `/tmp` 사본은 그걸 못 찾아
   `finish: command not found` 로 죽고 **rc≠0** 을 낸다 — 주입과 무관하게 "RED" 처럼 보인다.
   이것은 결과가 아니라 **깨진 계측기**다. 수정 전 판본은 반드시 **리포의 원래 경로에
   되돌려 놓고**(`cp -p` 백업 교체) 실행한다.
2. **다른 독립 스캔이 이미 잡는 토큰을 고르면 차분이 오염된다.** 주입 토큰이 우연히 다른
   락에도 걸리면 "수정 전 RED" 가 나오는데, 그 RED 는 내가 고친 락이 낸 것이 아니다.
   실례: `test_web_kill_switch.sh` 를 증명할 때 `web_budget` 을 쓰면 안 된다 — 같은 파일의
   AC7a 가 `grep -rln … "$SD"` 로 **이미** 재귀 스캔해 잡는다. 그래서 그 락의 per-file 검사만
   보는 **`SWEEP_CAP`** 을 골랐다. 주입 토큰은 **증명하려는 그 검사에만 걸리는 것**으로 고른다.

## §6 알려진 독자 목록 (2026-08-21 기준)

`conducting-interview/SKILL.md` 기준 **독자 15 + 버전영향(비독자) 1**. 이 목록은 물려받을
값이 아니라 §2 도출의 **출발 체크리스트**다 — 다음 분할에서는 반드시 다시 도출할 것.

〔Task 33 재도출 실측〕 대상을 `reviewing-spec/SKILL.md` 까지 넓혀 다시 세니 **21 + 비독자 1**
이 나왔다. 늘어난 것은 대부분 `reviewing-spec` 을 경로 리터럴로 여는 테스트들이고, 그중
`tests/test_arm_ledger_timing.sh` 는 **헬퍼(`arm_test_helpers.sh`)를 source 하는 실행 파일**이라
헬퍼만 세면 놓친다. 숫자가 아니라 그 함정을 물려받을 것 — 코퍼스 변수를 만드는 파일과 그것을
**실행하는** 파일이 다를 수 있다.

★ = 플러그인 경계를 넘는 repo-wide 부재 스캔(가장 놓치기 쉬운 클래스, 알려진 인스턴스 2).

| 파일 | 도달 방식 | 클래스 | 상태 |
|---|---|---|---|
| `spec-distill/tests/test_conducting_interview_stage.sh` | 리터럴 | absence 7 + presence + window 11 | Task 32 수리 |
| `spec-distill/tests/test_brief_review_entry.sh` | 리터럴 | presence + window | Task 32 수리 |
| `spec-distill/tests/test_no_wall_clock.sh` | **하드코딩 배열** | 순수 absence | Task 32 수리 |
| `spec-distill/tests/test_web_kill_switch.sh` | 글롭 | absence 2(조기 `continue` 뒤) + 줄번호 근접 | Task 32 수리 |
| ★ `quality-gates/tests/test_law2_prose.sh` | `find plugins/*/skills` | absence 3그룹 | Task 32 수리 |
| ★ `quality-gates/tests/test_governance_no_capability_caps.sh` | `find plugins -name '*.md'` | absence | **면역(도출)** |
| `spec-distill/tests/test_stale_terms.sh` | `find "$SD" -type f` | absence 중심 | **면역(도출)** |
| `spec-distill/tests/test_reviewing_spec_design_only.sh` | `grep -rl … "$P/skills"` | absence | **면역(도출)** |
| `spec-distill/tests/test_brief_review_meta.sh` | `grep -rnE … "$SD/skills"` | absence | **면역(도출)** |
| `quality-gates/tests/test_codex_runner_no_effort_pin.sh` | `plugins/*/` 재귀 | absence | **면역(도출)** |
| `spec-distill/tests/test_check_verbatim_coverage.sh` | 리터럴 | presence + 줄번호 창 | 무영향 |
| `spec-distill/tests/test_conducting_interview_internal.sh` | 리터럴 | presence(frontmatter) | 무영향 |
| `quality-gates/tests/test_codex_gate_observation.sh` | `find plugins/*/skills` | 발견 + ratchet | 무영향(§7-2) |
| `shared/tests/test_skill_reference_pointers.sh` | `git ls-files` | 양방향 presence | 무영향(§7-3) |
| `shared/tests/test_copy_of_contract.sh` | `git ls-files plugins/*` | 중복·심링크 도출 | 무영향 |
| `shared/tests/test_changelog_integrity.sh` | — **SKILL.md 를 읽지 않는다** | **비독자** | 버전영향만 |

마지막 줄을 독자로 세지 말 것 — `plugin.json` + `CHANGELOG.md` 만 읽는다. 분할이 아니라
**버전 bump** 가 이 락을 건드린다.

## §7 이월된 미해결 항목

### §7-1 `test_changelog_integrity.sh` 는 **중간 헤딩 삭제**를 못 잡는다

Task 31 에서 실제로 일어났고 사람의 diff 리뷰까지 통과한 실패다. 현재 락은 최상단 헤딩 ↔
`plugin.json` 일치 · 헤딩 형식 · 단조 감소를 보지만, 중간 한 줄이 사라지면 남은 목록은
여전히 형식에 맞고 여전히 감소한다.

검토한 두 하드닝:

- **"건너뛴 버전이 파일 어딘가에 언급돼 있어야 한다"** → **측정으로 죽었다.**
  `plugins/quality-gates/CHANGELOG.md` 에서 `## [4.1.1]` 헤딩 줄만 지워도 문자열 `4.1.1` 은
  **10회** 남는다(삭제 전 11회). 남은 언급이 규칙을 만족시키므로 탐지기가 되지 못한다.
- **역사적 gap 2건을 backfill 한 뒤 순수 gap-freedom 을 잠근다** → 작동은 한다. 대상은
  `project-init` 1.7.1 · `spec-distill` 0.11.1(둘 다 실재하지 않는 버전). 다만 이 작업이
  달리 건드릴 이유가 없는 **두 플러그인을 건드려야** 한다.

착수하는 사람이 위 트레이드오프를 놓고 결정할 것.

### §7-2 `test_codex_gate_observation.sh` — 보안 컨트롤의 자기 테스트가 fail-open 할 수 있다

이 락은 **발견 메커니즘**이다: `find "$ROOT"/plugins/*/skills -name SKILL.md` 로 훑어
`<!-- codex-gate:begin runner=… -->` 블록을 잘라내 실행한다. 게이트 블록이 언젠가
`references/*.md` 로 옮겨가면, 그 러너의 시나리오가 **조용히 그것을 덮지 않게 된다** —
보안 컨트롤 자신의 테스트에서 나는 fail-open 이다.

현재는 **잠재적**이다. 마커 3개가 전부 아직 분할되지 않은 SKILL.md 에 있다:

- `plugins/plugin-audit/skills/auditing-plugins/SKILL.md` — `run_audit_codex_reviewer.sh`
- `plugins/spec-distill/skills/reviewing-brief/SKILL.md` — `run_brief_codex_reviewer.sh`
- `plugins/spec-distill/skills/reviewing-spec/SKILL.md` — `run_spec_codex_reviewer.sh`

**이 세 스킬 중 하나를 분할하는 태스크는 이 락을 반드시 먼저 확장할 것.**

### §7-3 〔해소 — Task 33〕 `test_skill_reference_pointers.sh` 의 플러그인 레벨 `references/`

- 정방향: 추출한 `references/…md` 접미사를 **그 포인터를 담은 SKILL.md 자신의 디렉터리
  기준**으로 해석한다. 그래서 `plugins/<name>/references/x.md`(스킬 밖)를 가리키는 포인터는
  `plugins/<name>/skills/<s>/references/x.md` 를 찾다가 **false-RED** 를 낸다.
- 역방향: 코퍼스가 `git ls-files -- 'plugins/*/skills/*/references/*.md'` 라 플러그인 레벨
  파일은 **아예 보이지 않는다**(고아 검사에서 투명).

〔2026-08-21 Task 33 에서 해소〕 `plugins/spec-distill/references/proceed-gate.md` 가 생기면서
위 정방향 false-RED 가 **실제로 발화**했고(실측), 역방향 투명도 확인됐다. 수리 방향은 "접미사를
재해석"이 아니라 **쓰여 있는 그대로 해석**이다 — 매치에 앵커 접두사를 함께 캡처해 접두사 →
해석 루트를 1:1 로 만들고, 알아보지 못하는 접두사는 **절단하지 않고 거부**한다. 역방향은
정방향이 만든 `(SKILL.md, 해석된 대상)` 쌍을 되쓴다.

**여기서 배운 두 가지**(둘 다 fix round 1 리뷰가 잡았다):

1. **접두사를 열거해 골라 받는 정규식은 "폴백 없음"이 아니다.** 열거 밖 접두사는 거부되는 게
   아니라 **잘린다** — 정규식이 접두사 위치에서 실패하고 문자열 *중간*의 맨몸 접미사에서
   매치가 시작돼, 그 표기가 조용히 "가장 관대한 형태"로 재해석된다. 토큰을 통째로 삼키는
   넓은 클래스로 잡은 뒤 형태를 판정해야 거부가 가능해진다.
2. **한쪽 방향만 엄격하게 만들면 다른 방향이 구멍이 된다.** 정방향을 as-written 으로 조인
   뒤에도 역방향이 접미사 비교로 남아 있어, 플러그인 레벨과 skill 레벨에 동명 파일이 있을 때
   skill 레벨 파일이 **아무도 안 가리키는데도** 고아로 안 잡혔다. 해석기는 한 벌이어야 한다.

### §7-4 `quality-gates/tests/test_no_secret_prompts.py` 는 **한 칸 위**를 못 본다

§1 의 헤드라인 P21 인스턴스인 바로 그 스캔이 이제 **자기 플러그인에 대해 같은 맹점을 갖는다.**

`test_no_secret_prompts.py:12,24` 의 코퍼스는 `ROOT = <plugins/quality-gates>` 아래
`ROOT.glob("skills/*/references/*.md")` 다. Task 31 이 열거를 도출로 바꾼 그 수리인데,
도출 범위가 `skills/` **아래**로 한정돼 있다. spec-distill 은 안 읽으므로 Task 33 의
`plugins/spec-distill/references/` 와는 무관하다 — 그러나 **`plugins/quality-gates/references/`
가 생기는 순간** 그 파일은 P21 secret 스캔 밖이다.

- **발동 조건**: `plugins/quality-gates/references/*.md` 가 처음 만들어질 때.
- **처방**: `ROOT.glob("references/*.md")` 를 코퍼스에 더하고, §3 대로 도출 0건이면 loud FAIL
  하는 vacuity 단언을 함께 둔다. 다만 **플러그인 레벨 개수 0 은 정당한 상태**이므로
  (그런 파일이 없는 리포) 합집합에 vacuity 를 걸고, 디렉터리가 **있는데** 도출이 0이면
  따로 FAIL 하는 형태가 맞다 — Task 33 의 네 수리가 쓴 모양이다.
- **오늘은 손대지 않는다**: 대상 파일이 0건이라 지금 고치면 측정 없는 코드가 된다. 이
  항목이 그 결정을 재발견 없이 하도록 남긴 기록이다.

### §7-5 degrade 채널의 **형태**는 아직 검증되지 않는다 (라벨은 검증된다)

Task 33 fix round 1 이 `proceed-gate.md` 에 의무를 넣었다 — *"각 skill 은 자기 degrade
채널을 자기 어휘 절에 이름으로 대야 한다"*. **round 3 에서 두 조각으로 갈랐다:**

- **라벨(절의 존재) — 기계화됐다.** `test_proceed_gate_adopters.sh` 의 채택자 루프가
  `grep -cF 'degrade 채널'` 로 잰다. 이것이 계약이 두려워한 실패를 정확히 잡는다: 새 채택자가
  이 의무를 **"해당 없음"으로 넘기는 것**. 채널 형태를 전혀 건드리지 않고 잡힌다.
- **형태(그 채널이 실제로 그 skill 의 degrade 를 나른다는 것) — **미해결**.** 채널의 모양은
  채택자마다 다르다(`brief_review_degradations` 원장 vs `merge_review` 플래그 + `advisory:`).
  둘로 일반화하면 둘에 과적합한 정규식이 된다.

〔round 3 이 이 항목을 좁힌 이유〕 앞 판본은 *"의무 전체가 기계화되지 않았다"* 고 적었는데,
그 근거(형태가 skill 마다 다르다)는 **형태 검증에만** 해당한다. 라벨 검사는 그 근거의 적용
대상이 아니었고, 실제로 한 줄로 가능했다. **연기의 사유가 연기의 범위보다 좁으면 그 차이만큼이
공짜로 미뤄진다** — 이월 항목을 쓸 때 사유와 범위를 맞춰 적을 것.

- **발동 조건**: 세 번째 skill 이 `references/proceed-gate.md` 를 채택할 때. 세 형태가 모이면
  공통 모양이 보이고, 그때 채택자 루프에 형태 단언을 더한다(도출·라벨 단언은 이미 있다).
- **그때까지의 상태**: 형태는 사람이 읽어 확인. 두 채택자 모두 실제 채널을 대고 있다.

### §7-6 포인터 락의 접두사 거부는 **리포 전역**이고 산문이 방아쇠다

Task 33 fix round 1 의 F6 수리는 인식 못 하는 접두사를 **절단하지 않고 거부(loud FAIL)** 한다.
방향은 옳다(fail-closed). 다만 방아쇠가 넓다: `shared/tests/test_skill_reference_pointers.sh`
는 **어떤 SKILL.md 든** `references/<name>.md` 로 끝나는 토큰을 만나면 형태를 판정하고, 세
인식 형태 중 하나가 아니면 FAIL 한다.

그래서 미래의 SKILL.md 가 **포인터 의도가 전혀 없이**
`https://github.com/<org>/<repo>/blob/main/references/foo.md` 같은 URL 이나 `docs/` 아래
`/references/` 를 포함하는 경로를 **인용만 해도** 이 공유 락이 리포 전역에서 RED 가 된다.
그 사람에게는 **자기 편집과 무관해 보이는 RED** 로 나타난다 — 원인이 "포인터 표기 규약"이라는
것을 헤더를 읽어야 알 수 있다.

- **오늘 상태**: 살아 있는 인스턴스 0. 헤더가 인식 형태 셋을 명시하고 실패 메시지가 그 셋을
  그대로 나열하므로, 걸린 사람이 이유를 알 수는 있다.
- **발동 조건**: 어떤 SKILL.md 가 포인터가 아닌 맥락에서 `…/references/*.md` 문자열을 처음
  담을 때(외부 URL 인용이 가장 그럴듯하다).
- **선택지(그때 결정할 것)**: ⑴ URL 스킴(`https://` 등)을 토큰 클래스에서 배제해 인용을
  포인터로 보지 않기 · ⑵ 거부를 advisory 로 낮추기(fail-open 이므로 비추천) ·
  ⑶ 그대로 두고 저자에게 표기를 고치게 하기. ⑴ 이 가장 좁은 수정이다.

## §8 공유 참조 파일 — 처방을 거꾸로 적용하지 않기

§3 의 처방은 **"열거를 도출로 바꾸고 코퍼스를 넓혀라"** 다. Task 33 이 그 처방에
**적용 범위가 있다**는 것을 실측으로 배웠다.

두 skill 이 공유하는 계약을 `plugins/<p>/references/<f>.md` 로 빼면, 그 파일은 계약을
서술하기 위해 **각 skill 의 앵커 어휘를 그대로 담는다**(담지 않으려면 계약을 약하게 써야
하므로 피할 수 없다). 그러면:

| 검사 종류 | 코퍼스를 넓히면 | 넓혀야 하나 |
|---|---|---|
| **absence** (금지 토큰 0건) | 새 파일에 들어온 금지 토큰을 **잡게 된다** | **예** |
| **presence** (앵커 어휘 실재) | 각 skill 이 자기 어휘를 잃어도 **공유 파일이 대신 만족시킨다** | **아니오** |

즉 **넓히는 방향과 좁히는 방향이 검사 종류마다 반대다.** §3 의 처방을 presence 락에 그대로
적용하면 그 락의 이빨이 0이 된다 — §4 거울 클래스의 한 칸 위 버전이고, 위험한 것은 그 편집이
**정당해 보인다**는 점이다(바로 앞 커밋이 네 코퍼스에 같은 편집을 했으므로).

**처방**:

1. 두 배열을 나눈다 — `CI_FILES`(그 skill 소유 표면: `skills/<s>/SKILL.md` +
   `skills/<s>/references/*.md`)는 presence 용, `CI_ALL`(+ 플러그인 레벨 공유 파일)은 absence 용.
2. presence 배열에 skill 소유 밖 파일이 들어오면 **즉시 FAIL 하는 구조적 가드**를 둔다.
   주석만으로는 부족하다 — 이 편집을 하는 사람은 §3 을 근거로 삼고 있어서, 주석을 읽어도
   "여기엔 해당 없음"으로 넘길 이유가 이미 있다. 〔실측〕 가드 없이 코퍼스를 넓힌 상태에서
   `finishing.md` 의 옵션 ① 정지 어휘와 `polite stop` 을 통째로 지워도 두 락이 GREEN 이었다.
3. 공유 파일 안에 **"이 파일은 그 스캔의 코퍼스가 아니다"** 를 근거와 함께 적는다. 근거는
   *자제*가 아니라 **코퍼스 경계**여야 한다 — "여기엔 리터럴을 두지 않는다" 같은 자제 규칙은
   지켜지지 않으며(Task 33 의 첫 판본이 그 문장을 쓴 채 리터럴 4개를 담고 있었다), 무엇보다
   **틀린 이유를 알려주면 진짜 위험 경로를 가린다.**

〔부수 확인〕 구조적 가드는 `assert.sh` 를 source 한 **뒤**에 두어야 한다. Task 33 의 첫
배치는 source 앞이라 `no` 가 미정의였고, 가드가 **아무것도 하지 않으면서 GREEN** 이었다
(양성 통제 mutation 으로만 드러났다 — §5 의 "계측기가 고장 난다"의 또 한 형태).
