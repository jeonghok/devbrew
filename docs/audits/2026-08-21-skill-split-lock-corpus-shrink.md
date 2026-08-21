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

### §7-3 `test_skill_reference_pointers.sh` 는 **플러그인 레벨** `references/` 를 다룰 수 없다

- 정방향: 추출한 `references/…md` 접미사를 **그 포인터를 담은 SKILL.md 자신의 디렉터리
  기준**으로 해석한다. 그래서 `plugins/<name>/references/x.md`(스킬 밖)를 가리키는 포인터는
  `plugins/<name>/skills/<s>/references/x.md` 를 찾다가 **false-RED** 를 낸다.
- 역방향: 코퍼스가 `git ls-files -- 'plugins/*/skills/*/references/*.md'` 라 플러그인 레벨
  파일은 **아예 보이지 않는다**(고아 검사에서 투명).

현재 `plugins/*/references/*.md` 는 **0건**이라 잠재적이다. 다만 **다음 태스크가 그런 파일을
만들 계획**이므로, 그 태스크는 이 락의 양방향 경로 해석을 함께 손봐야 한다.
