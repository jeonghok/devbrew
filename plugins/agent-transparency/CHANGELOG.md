# Changelog

## [0.3.1] — 2026-09-04

### Fixed
- **Task 14 수정 라운드 1** — `tools/adjudication/check_slots.py`(L3 판정기,
  `plugins/*/agents/*.md` 전부를 검사)의 dispatch 펜스 스캐너가 들여쓴 펜스를
  구조적으로 못 보고, 한 펜스에 subagent_type 둘이면 조용히 첫 번째로만
  귀속하던 결함을 고쳤다 — 상세는 quality-gates CHANGELOG v6.6.1 참조. 이
  플러그인은 이 판정기의 검사 대상(transcript-reader)이라 선례대로 함께
  bump. 이 라운드에서 이 플러그인의 파일 자체는 변경 없음.

## [0.3.0] — 2026-09-04

### Added
- **transcript-reader 에 frontmatter `input_slots:` 선언 — L3(adjudication-topology
  Task 14).** dispatch 는 `briefing-current-state/SKILL.md` 의 frontmatter
  `context: fork` + `agent:` 필드가 만든다 — `Agent({subagent_type: "..."})` JS
  펜스가 아니라 skill 본문 전체가 그대로 프롬프트가 되는 harness 기능이라,
  `shared/tests/test_agent_input_slots.sh` 의 `.md`-only dispatch 코퍼스(`subagent_type:`
  펜스 스캔)가 이 채널 자체를 구조적으로 못 본다 — 슬롯 `optional: true`(미전달이
  아니라 관찰 불가).

## [0.2.4] — 2026-08-23

### Added
- dispatch 자리(1곳)에 처분 앵커 — `**처분** — consumer=… · fail-… [· disclosure=…]`. `shared/tests/test_dispatch_disposition.sh` 축 A①②③④·B·C 가 집행한다.

## [0.2.3] — 2026-08-22

기준선 RED 해소 ③/4 — 테스트가 아닌 것을 `tests/` 밖의 수집 제외 자리로 옮긴다.
측정 러너 동작 무변경.

**Changed**
- **`tests/ab_gate.sh` → `tests/harness/ab_gate.sh`** (`git mv`). 이 파일은 테스트가
  아니라 **AC29 의 A/B 측정 러너**다 — 헤더가 스스로 그렇게 말하고,
  `AB_MODEL`·`AB_EFFORT`·`AB_JUDGE_MODEL`·`AB_JUDGE_EFFORT` 를 요구하며 없으면
  `parameter null or not set` 으로 죽는다. 모델을 호출하므로 **비용이 나간다.**
  회귀 스위트에서 이 파일이 RED 였던 이유는 결함이 아니라 *"env 를 안 줬다"* 였다.
  - **선례**: `plugins/quality-gates/tests/harness/` 가 같은 이유로 존재한다
    (`test_skill_orchestration_behavior.sh` · `run_consent_gate.sh`).
  - **이동 전 실측 — 수집기 세 곳**: ⑴ 회귀 러너는 `*/tests/*.sh` 로 모으고
    `*harness*` 를 제외한다 → 이동으로 수집 밖. ⑵ `/plugin-audit` 의
    `run-own-tests.sh` 는 `find … -name 'test_*.sh'` 라 **이동 전에도 이 파일을 못
    봤고**, 추가로 `*/harness/*` 도 제외한다 → 이동은 그쪽에서 no-op(회귀 없음).
    ⑶ quality-gates `run-test-selection.sh` 의 셸 어댑터는 **diff 스코프** 러너로
    `tests/*.sh|*/tests/*.sh` 를 쓰고 `harness/` 를 제외하지 않는다 — 즉 이 파일이
    diff 에 직접 실릴 때만 돈다. 그 잔여는 기존 선례
    (`quality-gates/tests/harness/test_skill_orchestration_behavior.sh`)와 **정확히
    같으며**, env 미설정 시 러너가 첫 줄에서 죽으므로 비용도 나가지 않는다.
  - 스위트 수집기 **둘 다** `harness/` 를 제외하므로 이동으로 충분하다.
  - `ROOT` 도출 깊이를 `../../..` → `../../../..` 로 함께 고쳤다(디렉토리가 한 단계
    깊어졌다). 나머지 경로는 전부 `$ROOT` 에서 파생되므로 무변경.
  - 경로 리터럴 전수 갱신: `REFERENCE.md` 의 「AC ↔ 검증 산출물」 배정표 + 그 위
    산출물 정의 문장, `tests/test_ab_runner_contract.py` 의 `RUNNER` 상수.
    AC47 락(`TestAssignedArtifactsExist`)이 배정 경로의 실재를 재므로 이 셋이
    어긋나면 즉시 RED 다.
  - **부수 효과**: `plugins/agent-transparency/tests/` 에 남는 `.sh` 가 0 이 된다.
    감사 리포트 `docs/audits/2026-08-21-skill-split-lock-corpus-shrink.md` §7-11 이
    기록한 *"`/plugin-audit` 의 접두 도출이 `ab_gate.sh` 를 못 본다"* 의 실재
    인스턴스가 1 → 0 이 된다. 그 §7-11 의 도출-술어 결함 **자체는 그대로 남아
    있다** — 여기서 고친 것은 술어가 아니라, 애초에 테스트가 아닌 파일이 `tests/`
    최상위에 있던 배치다.

## [0.2.2] — 2026-08-20

### Changed

- **`transcript-reader` agent의 `tools:` 어순을 형제 agent들과 통일**(devbrew
  weight-reduction Task 29 축 1). `Read, Glob, Grep` → `Read, Grep, Glob` —
  다른 17개 agent가 이미 쓰던 "읽기 → 검색 → 열거 → 그 외" 순서에 맞췄다.
  **집합은 불변** — allowlist에서 도구가 추가되거나 빠지지 않았다(Law 2 경계
  무변경, `test_agent_tools_lock_differential.sh` / `test_agent_tools_lock_mutation.sh`
  green으로 확인).
- **`test_plugin_contract.py`의 mutation-lock 3개를 리터럴 앵커에서 파싱된
  집합(set) 기반으로 재작성.** `TestDedicatedAgent.
  test_mutation_tools_line_emptied` · `test_mutation_write_tool_added` ·
  `TestAgentTrustBoundary.test_tools_allowlist_is_unchanged_by_the_boundary`가
  옛 문자열 `"tools: Read, Glob, Grep"`을 리터럴로 찾고 있어 위 어순 통일
  직후 RED였다. **fix round 1**은 처음엔 그 리터럴을 새 문자열
  `"tools: Read, Grep, Glob"`로 바꿔 넣는 것으로 green을 만들었지만, 이
  branch에서 같은 계열의 재발(Task 25의 `major == "3"`, Task 28의
  non-strict `ranks == sorted(ranks)`)이 이미 두 번 있었던 뒤라 리뷰가
  "재anchoring일 뿐 치료가 아니다"로 정확히 짚었다 — 다음 정당한 `tools:`
  편집이 같은 이유로 또 RED가 된다. **진짜 수정**: 이미 이 모듈에 있던
  order-agnostic 파서 `TestDedicatedAgent.tools_of()`를 세 곳 다 재사용하도록
  다시 썼다. mutation 두 개(`_emptied` · `_write_tool_added`)는 이제
  `tools_line()`(새 헬퍼 — frontmatter에서 실제 `tools:` 원문 줄을 읽어
  온다)으로 실제 줄을 찾아 그 값으로 치환하므로 어순과 무관하게 항상
  맞는다. `test_tools_allowlist_is_unchanged_by_the_boundary`는 문자열
  포함이 아니라 `tools_of(self.text) == ALLOWED`(집합 등치)로 바뀌었다.
  **계측기 자체의 무결성 가드도 추가**: `.replace()`가 대상을 못 찾으면
  조용히 원문을 그대로 돌려주므로(no-op), 두 mutation 테스트 모두
  `assertNotEqual(mutated, self.text)`로 "실제로 변형됐는가"를 먼저
  확인한 뒤에야 mutation의 효과를 판정한다 — 그렇지 않으면 다음 리팩터가
  이 계측기를 거짓 **green**으로 만들 수 있었다(지금은 거짓 RED로만
  드러났지만). **mutation 증명**: 실제 `tools:` 줄을 다른 순열(`Glob,
  Read, Grep`)로 바꿔도 세 테스트 모두 green을 유지했고(order-blind 확인),
  거기에 `Write`를 더하자 셋 중 직접-검사 두 개(`test_tools_are_
  dominated_by_allowlist` · `test_tools_allowlist_is_unchanged_by_the_
  boundary`)가 정확히 red로 전환했다(권한 위반 감지 확인) — 검증 뒤 원본
  파일로 복원, `git diff` clean 확인.

### Documented (devbrew weight-reduction Task 30)
- **`tests/oracle/test_add_contract.py`가 `python3 -m unittest discover -s
  plugins/agent-transparency/tests` 스윕에 안 잡히는 이유를 docstring에
  명시.** 결함이 아니라 설계다 — `src.calc`/`src.util`는 피검체 트리
  (`AT_SUBJECT_DIR`)에만 있어 원본 위치에서 discover 하면
  `ModuleNotFoundError`이고, `__init__.py`를 추가해 discover 대상으로 만드는
  것은 신뢰 사본(`$VER`) 분리라는 Law 2 경계 자체를 없앤다. 이 파일의
  5개 assertion이 옳게 가르는지는 `test_ab_runner_contract.py`의
  `TestOracleHasTeeth`(정답/미완성 피검체로 실행 확인)·`TestOracleSignal`이
  이미 대신 검증하며, 그 파일은 top-level discover 대상이다(283 baseline에
  포함). `ab_driver.py run --subject <ab-project fixture> --expect 5
  test_add_contract`로 직접 재현: 미수정 baseline fixture(음수를 거부하는
  `add`)로는 5개 중 3개가 의도대로 fail, `TestOracleHasTeeth.
  test_a_correct_solution_passes`의 합성 정답 fixture로는 5개 전부 pass.

## [0.2.1] — 2026-08-15

CRITICAL 을 닫은 뒤 남은 IMPORTANT 중 **게이트를 거짓말하게 만드는 것들**. 그중 하나는
**v0.2.0 이 남긴 구멍**이었다 — `-I` 로 `PYTHONPATH` 를 껐으면서 같은 순서를 코드로
다시 만들고 있었다.

### Security

- **피검체 트리가 여전히 stdlib 앞에 있었다(A3).** v0.2.0 은 `PYTHONPATH` 를 없애고
  `-I` 로 그 경로를 껐지만, 드라이버가 `sys.path.insert(0, subject_dir)` 를 해서
  **같은 구멍을 다른 문으로 열어** 두었다 — `$FX/mimetypes.py` 같은 가짜 stdlib 이
  검증 프로세스 안에서 이긴다. 피검체 트리는 이제 `append` 로 **stdlib 뒤**에 붙는다.
  락은 구조(경로 순서)와 행동(심어 놓은 가짜가 지는가)을 둘 다 잰다.
- **피검체가 자기 인벤토리를 제조할 수 있었다(B2).** 게이트 5b 가 표지를 담은 *아무*
  레코드나 인벤토리로 취했다. 준비 스크립트가 강등해 헤더를 못 냈을 때 표지를 흉내 낸
  **모델 자신의 답변 레코드**가 유일한 매치가 되고, 그 매치 때문에 「인벤토리 없음」
  가드는 발동조차 못 한다 — 루브릭 C 의 Q2(*"총수 대비 몇 개를 읽었나"*)가 피검체가
  지어낸 총수 위에서 채점됐다. `find_inventory` 가 어시스턴트 레코드를 배제한다.
- **숨김 오라클이 작업 (b) 의 후반부를 안 재고 있었다(A4).** `total` 이 `int` 를
  돌려주는지만 봐서 `def total(p): return 0` 이 CSV 를 **한 번도 열지 않고** 통과했다.
  값을 못박으면 빈 칸 정책(게이트 6 의 판정 축)이 죽으므로, 값 대신 **파일 의존성**을
  잰다 — 빈 칸 없는 행을 더하면 결과가 달라져야 한다. 어떤 정책을 골라도 참이고 파일을
  안 읽는 구현에만 거짓이다.

### Fixed — `/standup` 이 사용자에게 내는 답 (이 릴리스의 유일한 **제품** 수정)

여기까지의 모든 수정은 검증 하니스였다. 아래 넷은 사용자가 실제로 읽는 출력이다.

- **git 호출 하나가 만료되면 `/standup` 이 사용자 파일에 대해 거짓을 단언했다**(H1).
  `git_common_dir` 이 timeout(rc 124) · `OSError`(rc 127) · 권한 오류를 전부 `None` 으로
  뭉개고, `classify` 가 *"디렉토리는 있는데 해소 불가"* 를 `other-repo` 로 확정 서술해
  `main()` 이 *"all N candidate file(s) rejected (other-repo: N)"* 로 렌더했다. 거절
  자체는 유지한다(해소 불가 후보를 받아들이면 남의 리포 기록이 답변에 들어온다) —
  바뀐 것은 **사유의 이름**이다. 이 리포에서 실제로 `other-repo: 0, unresolved: 1` 이
  나온다: 그 1건은 앞선 판에서 *"다른 리포다"* 로 보고되던 것이다.
- **리포 경로 밖 워크트리에서는 `/standup` 이 현재 세션조차 못 찾았다**(H3).
  후보 수집이 **메인 리포 경로**의 slug 접두 하나로만 glob 했다 — 같은 파일의
  `classify` 는 *"워크트리는 리포 밖 어디에나 놓인다"* 를 근거로 path-containment 판정을
  **명시적으로 기각**해 놓고, 후보 수집은 path-containment 로 하고 있었다.
  `git worktree list --porcelain` 으로 등록된 워크트리를 열거해 각각에 대해 glob 한다.
  열거가 실패하면 메인 리포만 남는다(crash 아님).
- **답변된 결정이 `(미답)` 으로 렌더될 수 있었다**(H5). `count` 가 넘겨받은 집합 **안에서만**
  호출-결과를 짝지었는데 `collect` 는 브랜치로 거른 부분집합을 넘겼다. 한 세션이 메인
  리포 → 워크트리로 이동하면 `AskUserQuestion` 과 그 `tool_result` 가 갈려 짝이 깨지고,
  SKILL.md 규칙 4-1 이 사용자가 **고른** 질문에 `(미답)` 을 찍는다. 짝짓기는 파일 전체에서
  하고 계수만 범위 안에서 한다.
- **스크립트 버그가 데이터 문제로 렌더됐다**(H6). `except Exception` 이 `str(exc)` 만 내서
  `KeyError('blocks')` 가 `internal error ('blocks')` 가 되고, `scope:` 줄이 없으니
  SKILL.md 규칙 7 이 에이전트에게 *"기록을 가져오지 못했다"* 를 보고하게 했다 — 사용자는
  원인을 자기 트랜스크립트에서 찾는다. 예외 **종류**를 메시지에 넣고 traceback 은
  stderr 로 보낸다(stdout 한 줄 계약 유지 — fork 답변을 오염시키지 않는다).

### Fixed — 검증 하니스

- 판정자가 `rc=0` 으로 끝났는데 stdout 이 비거나 파싱 불가면 표가 조용히 전부 `no` 가
  됐다(I1) — 마커도 stderr 도 없어 *"판정자가 형식을 어겼다"* 와 *"산출물이 루브릭에
  떨어졌다"* 가 같은 표로 보고됐다. `vote_or_reason` 이 사유를 내고 `_error` 로 남는다.
- `ab_judge.read_records` 가 손상된 트랜스크립트 줄을 **카운터 없이** 버렸다(I2).
  형제인 `scripts/prepare_standup.read_records` 는 같은 형식에 대해 정반대 결정을 내리고
  그것을 *"유일한 손상 신호"* 라 부른다 — 판정이 부분 기록 위에서 도는 줄 아무도 몰랐다.
- 빈 판정 구간이 `_preserve` **앞에서** 반환돼, REFERENCE.md 가 *"흔한 경우"* 라 이름
  붙인 실패가 아무 아티팩트도 안 남기는 **유일한** 실패가 됐다(I4).
- **락의 창(窓)이 잘못돼 있던 여덟 자리.** 전부 같은 모양이다 — 락이 자기가 지킨다고
  적어 둔 것보다 **넓은 코퍼스**를 스캔해서, 규칙을 없애고 문자열만 남기면 통과했다.
  - `.gitignore` 락이 전문 substring 이라 `# tests/out/` 로 주석 처리해도 통과(F1).
    파싱한 **규칙 목록에 대한 정확한 줄 일치**로 바꿨다.
  - SKILL.md 사실 락이 파일 전문을 스캔해, 규칙 본문을 지우고 조각을
    `<!-- 폐기된 규칙 -->` 주석에 인용해 두면 통과(F5). **절 윈도우 + HTML 주석 제거.**
  - 파리티 락이 `<!-- rule:… -->` 앵커 다섯 개만 봐서, 절 본문을 통째로 지우고 앵커만
    한 줄 남기면 통과(F6). 이 파일은 *"규칙이 통째로 사라지는 것"* 을 잡는다고 적었지만
    실제로 잡던 것은 **HTML 주석이 사라지는 것**뿐이었다. 절 본문 분량을 함께 잰다.
  - 오라클 락 셋이 전부 오라클 **모듈 docstring** 으로 충족됐다(F4) — `from src.util
    import total` 과 그 테스트 클래스를 통째로 지워도 GREEN 이었다. 오라클이 가시 다리
    대비 더하는 **유일한 신호**가 잠기지 않은 상태였다.
  - `unparsed` 필드가 음의 락 하나로만 지켜져, 포맷 문자열에서 필드를 지우면 통과(F9).
  - `AC16①` 이 맨 `AC16` 언급으로 충족됐다(G5) — `or <번호 매치>` 갈래 때문에 조각 id 는
    **언제나** 번호로 만족됐고, 그것이 docstring 의 *"조각 id 는 정확히"* 와 어긋났다.
  - 계측기가 프로덕션 술어 대신 **자기 리터럴**에 `re.search` 를 돌렸다(G3) — 사실상
    `re` 모듈 테스트라, 검사를 `base in body` 로 헐겁게 고쳐도 GREEN 이었다.
  - 계측기가 `code_only()` 자신만 확인하고 **긍정 검사들이 그것을 소비하는지**는 안
    쟀다(G4) — 구성상 참인 테스트였다. 이제 검사들을 변이한 본문 위에서 직접 실행한다.
  - 창 종결자가 **피검 파일이 통제하는 산문**(`"Example,"`)이었다(G7). 파일이 *"For
    example,"* 로 리워딩하면 창이 파일 끝까지 벌어져 위치 축이 조용히 죽는다.
    종결자를 문단 구분(빈 줄)으로 바꿨다.
- 죽은 단언 둘. `assertIsNotNone(base_ref(...) or True)` 는 어떤 구현으로도 실패
  불가였고(G1, 리뷰어 3명 독립 수렴), `addCleanup(setattr, module, "subprocess",
  module.subprocess)` 는 인자가 즉시 평가돼 같은 객체를 자기 자신에 재대입하는
  no-op 이었다(G2) — 실제로 복원한 것은 `finally` 뿐이었다.
- `ab_judge.main()` 이 파일 핸들을 안 닫아 `ResourceWarning` 이 스위트 출력을 덮었다.
  `main()` 에 커버리지가 생기면서 드러났다.

### Added

- `ab_judge.main()` 을 **실제로 돌리는** 테스트(C2) — 완전한 27-실행 산출물을 만들어
  넣고 판정자 호출만 가로챈다. 게이트 5a 의 인용 대조 · 인벤토리 출처 · 종료 코드를 이
  함수가 소유하는데 호출하는 테스트가 하나도 없었다.
- **숨김 오라클을 실행하는** 테스트(A4 의 짝) — 그 전까지 오라클 락은 전부 파일 문자열만
  봤다. 정답 구현은 통과 · 파일을 안 읽는 `total` 은 실패 · 음수를 거부하는 `add` 는 실패 ·
  **빈 칸 정책 두 가지 다 통과**(게이트 6 의 결정 축이 살아 있는지를 실행으로 잰다).
- 봉인이 픽스처 **원본**과 루브릭을 실제로 덮는지 경로 이름으로 확인하는 락(NF-2) —
  `cp -R "$SRC/."` 가 24 회 반복마다 템플릿을 다시 읽는데 해시 다리는 두 파일만 덮는다.
- `REJECT_REASONS` 에 `unresolved` 추가 — 강등 내역에 한 줄로 나온다. 사유가 그 튜플에
  없으면 어디에도 안 나타난다.
- 오라클 락이 `ast` 노드(`ImportFrom` · `Call`)에 대고 단언한다(F4) — 산문은 `total` 을
  몇 번이든 인용할 수 있지만 노드를 만들지는 못한다.
- `mentions_ac` — 배정표 언급 판정을 한 함수로 모았다. 계측기 테스트가 **그 술어를
  직접** 부르므로, 술어를 헐겁게 고치면 계측기가 red 가 된다(G3).
- 회귀 락 41개 추가. 이 릴리스에서 새로 이빨을 잰 것 28건 전부 RED — 삭제 축뿐 아니라
  **반대 축**(전부 `unresolved` 로 뒤집기 · `unpaired` 를 0 으로 고정)과 **무력화 축**
  (실행 줄을 주석으로 · 규칙 본문을 주석 인용으로)까지 흔들었다. 한 방향만 흔들면
  *"모두 판정 실패"* 나 *"짝은 언제나 맞음"* 인 구현이 통과한다.

### Notes

- `.gitignore` 락의 **주석 걸러내기는 이빨이 없다** — `"# tests/out/" != "tests/out/"`
  라 정확 일치가 이미 가른다(mutation 으로 확인: 필터를 지워도 두 테스트 다 GREEN).
  gitignore 파서로서 옳은 동작일 뿐이므로 남기되, 없는 보호를 근거로 삼지 않도록
  docstring 에 적었다. v0.2.0 의 봉인 개수 접두와 같은 모양이다.
- **mutation 하니스 자체가 두 번 고장 났다.** 한 번은 픽스처가 재려던 축을 안 태웠고
  (주석을 절 밖에 두어 주석-제거 축이 아예 안 걸렸다), 한 번은 **같은 길이의 치환이
  stale `.pyc` 를 무효화하지 못해 변이 전 코드가 돌았다** — `.pyc` 유효성은
  (mtime, size) 뿐이다. 후자는 거짓 GREEN 뿐 아니라 **거짓 RED** 도 만든다(앞 케이스의
  변이 캐시가 다음 케이스에 남는다). 하니스에 `__pycache__` 삭제 +
  `PYTHONDONTWRITEBYTECODE=1` 을 넣고 앞선 세 라운드를 전부 재검증했다(48건 전부 RED).
- 남은 것: IMPORTANT 약 8 · SUGGESTION 23. 대부분 문서 정합(J1~J8)과 하향된 항목이다.
  이 릴리스에서 세 번 드러난 *"있지도 않은 보호"*(봉인 개수 접두 · gitignore 주석 필터 ·
  파리티 앵커)는 전부 같은 계열이고, 셋 다 위장하는 대신 문서에 적었다.

## [0.2.0] — 2026-08-15

브랜치 `/qg` 리뷰의 **CRITICAL 4건** — 전부 *"A/B 머지 게이트 자체가 위조 가능하다"*
는 하나의 사실이었다. 착수 전 실측에서 **그보다 앞서는 문제**가 나왔다: 러너가 권한
플래그 없이 워커를 불러 편집 과업이 아무 일도 없이 통과 형태로 끝나고 있었다.
게이트의 PASS 는 이 릴리스 전까지 아무것도 뜻하지 않았다.

### Security

- **워커에 권한 플래그가 없어 측정이 무엇도 재지 않았다.** 헤드리스 `claude -p` 는
  기본값에서 파일을 하나도 못 쓰면서 `rc=0` 과 *"완료되었습니다"* 를 낸다(2026-08-15
  실측: 플래그 없음=차단 · `acceptEdits`=허용 · `--dangerously-skip-permissions`=허용).
  편집 과업 (a)·(b) 는 **아무 편집도 일어나지 않은 채** 통과 형태로 끝났고 게이트 2 는
  구조적으로 통과 불가였다. `--permission-mode acceptEdits` 로 부른다 — 최소 권한
  쪽이다.
- **완주 증거를 피검체가 만들 수 있었다(게이트 2 의 두 다리).** 두 다리 모두 검증
  프로세스의 **종료 코드만** 봤는데, 오라클은 정의상 피검체 코드를 import 하므로 그
  코드가 import 시점에 `os._exit(0)` 하면 코드 0 이 난다. 오라클 쪽 완주 센티널은
  경로를 **환경변수로 피검체에게 알려주고** 있어 자기가 써 놓고 죽으면 그만이었다.
  실측: 수정 전 러너 + 과업 **0%** 인 피검체 → `visible=0 oracle=0 hash=ok` ·
  `gate 2: PASS`. 수정 후 같은 입력 → `visible=1 oracle=1` · `gate 2: FAIL`,
  과업을 제대로 한 피검체 → `gate 2: PASS`(양방향 실측).
- **판정 원장이 피검체에게 건네진 트리 안에 있었다.** 산출물이
  `plugins/agent-transparency/tests/out/<RUN>/` 였고 `tests/out/latest` 가 현재 RUN 을
  광고했다. 게다가 판정이 `"on 1 visible=0" in tests_text` 로 **부분 문자열 포함**을
  봤고 `parse_index` 는 last-line-wins 라, 진짜 실패 아래에 한 줄 덧붙이는 것만으로
  세 다리가 전부 뒤집혔다.
- **피검체가 자기 채점 기준을 쓸 수 있었다.** `--plugin-dir` 로 플러그인 **원본**을
  건넸는데 그 트리에 숨김 오라클 · 판정 스크립트 · 루브릭 원본(`REFERENCE.md`)이 다
  있었다. 루브릭은 판정 프롬프트에서 데이터 경계 **밖**(지시 위치)에 들어간다.

### Added

- `tests/ab_driver.py` — 신뢰 드라이버. `result.testsRun` 이 **원본 픽스처**에서 AST 로
  센 기대치와 같고 `wasSuccessful()` 일 때만 완주 센티널을 쓴다. 센티널 경로는
  **stdin 한 줄로만** 들어오고, 피검체 코드를 import 하기 전에 `sys.argv` 를 지운다 —
  `os.environ` 과 `sys.argv` 는 피검체가 한 줄로 읽는 표면이다.
- `tests/ab_seal.py` — 신뢰 기반 봉인. 첫 반복 **전에** 뜨고 매 반복 뒤와 판정 직전에
  다시 맞춘다. 어긋나면 그 반복만이 아니라 앞선 반복 전부가 의심스러우므로 재시도
  없이 중단한다. 0-파일 트리는 크게 실패한다 — 빈 트리끼리는 항상 일치하므로 경로를
  잘못 넘긴 실행이 *"아무것도 안 바뀌었다"* 로 읽힌다.
- 회귀 락 28개. **전부 mutation 으로 이빨을 확인했다**(20건 시도, 20건 RED). 삭제
  축만이 아니라 **치환**(권한 플래그를 전권 플래그로 · 사본을 원본으로) 과
  **재사용**(1회용 사본을 다리 사이에 돌려쓰기) 축으로도 흔들었다.
- REFERENCE.md 「측정의 신뢰 경계」 절 — 무엇을 막고 **무엇을 못 막는지**.

### Changed

- 산출물이 `~/.claude/agent-transparency-ab/<RUN>/` 로 이동(`AB_OUT_ROOT` 로 재지정).
  플러그인 트리 밖이다.
- 피검체는 플러그인의 **1회용 사본**을 받는다(`tests/` 와 `REFERENCE.md` 제외). 배포
  표면 중 어느 것도 `REFERENCE.md` 를 참조하지 않으므로 피검체가 보는 동작은 같다.
- 검증은 **다리마다 새로 만드는** 1회용 사본에서 `-I -S` 로 돈다. 사본을 다리 사이에
  재사용하면, 가시 다리에서 `__file__` 로 경로를 알아낸 피검체가 오라클 파일을 자기
  것으로 갈아 끼운다. 오라클은 오라클 다리에만 동봉한다(가시 다리에 두면 숨김
  테스트가 숨김이 아니게 된다).
- `PYTHONPATH` 를 쓰지 않는다 — 드라이버가 `sys.path` 를 직접 조립한다.
- 판정의 게이트 2 원장 읽기가 **키당 한 번**이 됐다. 같은 키가 두 번 나오면 값이
  같든 다르든 **충돌**이고, `False`(떨어졌다)가 아니라 `None`(위조 의심)으로 구분해
  보고한다. `index.txt` 도 키당 `worker_rc` 줄이 둘이면 그 키를 fail 로 표시한다.

### Removed

- `tests/oracle/test_add_contract.py` 의 `tearDownModule` 완주 센티널 — 증거를 만드는
  쪽과 증거의 대상이 같은 파일이면 안 된다. 드라이버가 소유한다.

### Notes

- **이 릴리스가 막지 못하는 것.** 사본은 *"건네받은 경로를 그냥 고치는"* 길만 막는다.
  피검체 코드는 검증 프로세스 안에서 사용자 권한으로 돌고 `acceptEdits` 아래에서
  `Bash` 도 쓸 수 있으므로(실측), 파일시스템을 훑어 신뢰 기반을 찾아내는 것은 막지
  못한다 — 봉인이 **탐지**할 뿐이다. 완전한 차단은 OS 수준 격리가 필요하며 이
  하니스의 범위가 아니다.
- 봉인 다이제스트 앞의 파일 수는 **계측용이지 무결성 장치가 아니다** — 이미 해시에 든
  경로들에서 도출되므로 아무것도 더 잡지 못한다. mutation 이 그것을 드러냈고(지워도
  전부 GREEN), 없는 보호를 락으로 위장하는 대신 그 사실을 문서에 적었다.
- 리뷰 60건 중 이 릴리스가 닫는 것은 CRITICAL 4건 + 실측으로 나온 권한 문제다.
  IMPORTANT 33 · SUGGESTION 23 은 열려 있다:
  `~/.claude/qg-reports/2026-08-15-agent-transparency-branch-review/`.

## [0.1.1] — 2026-08-15

브랜치 `/qg` 리뷰(리뷰어 7명 + adversarial)가 낸 60건 중 **저위험 네 묶음**. 각 결함마다
그것을 놓친 락도 함께 고쳤다 — 코드만 패치하면 같은 것이 다시 빠져나간다.

### Fixed
- **`if __name__ == "__main__":` 가드가 파일 중간에 있어 테스트 10개가 조용히 사라졌다.**
  `unittest.main()` 이 `sys.exit()` 를 부르므로 그 아래는 파싱조차 되지 않는다.
  `tests/test_plugin_contract.py`(58→65) · `tests/test_ab_runner_contract.py`(63→66) —
  **exit 0 · 무경고**였고, 사라진 것 중에 신뢰 경계(P21) 락과 오라클 신호 락이 있었다.
  `-m unittest` 와 `discover` 는 모듈을 import 하므로 초록이라 CI 가 없는 이 리포에서
  사람이 `python3 <file>` 로 돌리는 습관과 정확히 어긋났다.
- **`tests/test_prepare_standup.py` 에서 `class TestSubagentExclusion(unittest.TestCase):`
  줄이 통째로 사라져 있었다.** AC49 의 docstring 이 맨몸 표현식이 되고 멤버가
  `TestDegradationCarriesAReason` 으로 재부모화되어 그 클래스의 `setUp` 을 조용히
  override 했다. 스위트는 초록이었고 skip 도 0 이라 **테스트 개수로도 드러나지 않았다.**
- **`.claude-plugin/marketplace.json` 이 존재하지 않는 `SubagentStop` 훅을 광고했다.**
  훅은 2026-08-13 에 제거됐고 `plugin.json` · `README.md` · `REFERENCE.md` 는 전부 그렇게
  적는데, 사용자가 설치 **전**에 읽는 유일한 문장만 갱신되지 않았다(리뷰어 5명 독립 적발).
- **`README.md` 의 설치 전 경고 세 문장이 훅을 살아 있는 부품으로 서술했다** — 끄면 "훅과
  `/standup` 이 함께" 꺼진다 · `/standup` 의 "주재료는 훅과 output style" · 표면 셋을
  열거하고 "두 경로". 둘째 것은 **훅 제거 이전에도 거짓**이었다: 훅의 `additionalContext`
  는 메인 대화에 배달된 적이 없어 `/standup` 이 읽는 블록에 한 번도 기여하지 않았다.
- `scripts/prepare_standup.py` 의 주석이 제거된 훅의 `_degraded()` 를 가리켰다 — 리포
  어디에도 없는 심볼이다.
- `TestReadme` 의 docstring 과 메서드 이름이 항목을 아직 **다섯**이라 불렀다(`README_ITEMS`
  는 넷). 테스트 **이름**이 계약을 잘못 말하면 다음 편집자가 훅 없는 플러그인에 훅 문서를
  다시 요구하게 된다. `test_all_five_items_present` → `test_all_required_items_present`.

### Added
- `tests/ab_judge.py` 에 `INVENTORY_MARKER` 상수 — 게이트 5b 가 인벤토리 레코드를 찾는
  `"scope:   repo="`(공백 세 칸)가 `scripts/prepare_standup.py` 의 렌더 포맷과 **두 변을
  묶는 것 없이** 중복돼 있었다. 공백 하나만 어긋나도 `inventory` 가 영구히 빈 문자열이 되어
  게이트 5b 가 **영원히 FAIL 하면서 사유를 "인벤토리 없음" 이라 말한다** — 포맷 드리프트가
  산출물 결함으로 읽힌다.
- 회귀 락 7개, 전부 mutation 으로 이빨을 확인했다:
  - `TestMainGuardIsLast` — 모든 테스트 모듈에서 `__main__` 가드가 마지막 최상위 문인지
    AST 로 검사. **파일 앞쪽에 둔다** — 뒤에 두면 가드가 다시 중간으로 옮겨질 때 이 락
    자신이 사라져 재발을 못 잡는다.
  - `TestClassBodiesAreWellFormed` — 클래스 본문에 떠 있는 문자열(원인: `class` 줄 소실)과
    메서드 중복 정의(증상: 재부모화된 `setUp`)를 AST 로 검사.
  - `TestMarketplaceEntry.test_description_matches_the_manifest` — marketplace 설명은
    `plugin.json` 의 세 번째 사본이다. 문장 하나가 아니라 두 사본의 동일성을 잠가 이
    클래스를 닫는다. 기존 `test_no_hook_event_key_anywhere_in_plugin` 이 이것을 못 본 것도
    구조적이다 — `PLUGIN_DIR.rglob` 이라 리포 루트 파일을 창 안에 담지 못한다.
  - `TestRender.test_rendered_scope_line_carries_the_judge_marker` — 렌더 실출력이
    `ab_judge.INVENTORY_MARKER` 를 담는지. 기존 `test_scope_line_has_three_fields` 는
    `startswith("scope:")` 와 필드 존재만 보므로 공백 축을 재지 않는다(mutation 으로 확인:
    같은 편집에 새 락 RED · 기존 락 GREEN).

### Notes
- 이 릴리스는 리뷰 60건 중 **4묶음만** 닫는다. 남은 것 중 가장 무거운 것은 **A/B 머지
  게이트 자체가 위조 가능**하다는 것이다(CRITICAL 4건, 독립 메커니즘 5개). 고치기 전에
  돌린 게이트의 PASS 는 아무것도 뜻하지 않는다. 전체 목록:
  `~/.claude/qg-reports/2026-08-15-agent-transparency-branch-review/`.

## [0.1.0] — 2026-08-13

### Added
- `output-styles/agent-transparency.md` — 일곱 순간에 무엇을 담아야 하는지 규정하고 내장 `Explanatory` 스타일을 흡수한다(`force-for-plugin: true`).
- `/standup` (`commands/standup.md` · `skills/briefing-current-state/` · `agents/transcript-reader.md` · `scripts/prepare_standup.py`) — 트랜스크립트에 쌓인 설명과 git 산출물로 "지금 상태"에 답한다.
- 머지 게이트(AC29, `tests/ab_gate.sh` + `tests/ab_judge.py`) — 워커 24회 + `/standup` 3회 + 판정 36회, 일곱 게이트 전부 통과해야 머지 가능.
- AC1–AC51 (삭제된 AC12–15·17–19·21–24·30 과 AC6–AC9·AC36·AC37·AC44·AC50 제외, 총 31건)의 배정은 `REFERENCE.md`의 「AC ↔ 검증 산출물」 표에 못박혀 있다 — 대부분은 `tests/*.py` 다섯 파일과 `tests/ab_gate.sh` · `tests/oracle/` · `tests/ab_judge.py`가 검증하고, AC16②는 비대화형 실행에 답변 채널이 없어 실물로 측정되지 않아 `없음 — OQ-AA`로 등재돼 있다(전량이 아니다 — M6).

### Notes
- **훅을 두지 않는다.** 개발 중(2026-08-13) `SubagentStop` 훅을 설계에서 제거했다 — 라이브
  probe 가 그 `additionalContext` 는 메인 대화가 아니라 **방금 끝난 subagent** 로 배달되고
  그 subagent 를 계속 돌게 만든다는 것을 보였다. 이 버전은 미출시 상태에서 개정됐으므로
  별도 릴리스로 기록하지 않는다 — 훅이 실린 버전은 어떤 사용자에게도 배포된 적이 없다.
  근거 전량은 설계 문서 §11, 사용자용 요약은 `README.md` 의 「훅을 두지 않는다」 절.
- 그래서 **kill switch 가 없다** — 걸 지점이 없다. 끄는 방법은 `claude plugin disable` 뿐이다.
